function [Tdetail, Tsum] = RunEpfd16BeamsKuPowerBackoffLogExcel(root, opts)
% RunEpfd16BeamsKuPowerBackoffLogExcel
% Power-backoff baseline (no tilt control, no handover):
% 1) compute 16-beam EPFD terms to GS
% 2) if aggregate EPFD exceeds threshold, reduce beam power first
% 3) keep per-satellite "satisfaction" >= target (default 0.5)
% 4) if even at min satisfaction still exceeds threshold -> turn off beams
%
% Satisfaction model (surrogate users, no handover):
%   sat_satisfaction = sum_b( users_b * pScale_b * active_b ) / sum_b(users_b)
%
% User weights vs Joint Power & Tilt (OJVT 2023): that paper uses one LEO beam
% and U users per visible satellite (Plot_Figure14_LEO_Passing.m uses U=5);
% satisfaction there is capacity/demand (Shannon), not power scaling.
% Here we only need nonnegative weights; default aligns order-of-magnitude with
% the paper by sum(users)==opts.totalUsersPerSat (default 5), split uniformly
% across 16 beams. Override with opts.usersPerBeam for uniform integer weights.

if nargin < 2 || isempty(opts), opts = struct(); end
if ~isfield(opts,'leoList') || isempty(opts.leoList), error('opts.leoList required'); end
if ~isfield(opts,'geoList') || isempty(opts.geoList), error('opts.geoList required'); end

sc = root.CurrentScenario;
if isempty(sc), error('No current STK scenario'); end

here = fileparts(mfilename('fullpath'));
addpath(fullfile(here, '..', 'powertilt'));

leoList = cellstr(string(opts.leoList));
geoList = cellstr(string(opts.geoList));

if ~isfield(opts,'stepSec') || ~isfinite(opts.stepSec), opts.stepSec = 1; end
if ~isfield(opts,'beamHalfEW_deg') || ~isfinite(opts.beamHalfEW_deg), opts.beamHalfEW_deg = 24.5; end
if ~isfield(opts,'beamHalfNS_deg') || ~isfinite(opts.beamHalfNS_deg), opts.beamHalfNS_deg = 25/16; end
if ~isfield(opts,'targetSatisfaction') || ~isfinite(opts.targetSatisfaction), opts.targetSatisfaction = 0.5; end
% Progressive-pitch tilt (Ren 2021) + beam gating (paper-like), optional.
if ~isfield(opts,'useProgressivePitchTilt') || isempty(opts.useProgressivePitchTilt), opts.useProgressivePitchTilt = false; end
if ~isfield(opts,'motionDeltaSec') || ~isfinite(opts.motionDeltaSec), opts.motionDeltaSec = 1; end
if ~isfield(opts,'alpha_th_deg') || ~isfinite(opts.alpha_th_deg), opts.alpha_th_deg = 10.0; end
% GEO orbital radius used in Ren 2021 Noff computation (km).
if ~isfield(opts,'RG_km') || ~isfinite(opts.RG_km), opts.RG_km = 42164; end
% totalUsersPerSat: paper-style total load per satellite (default 5). Split /Nbeam.
if ~isfield(opts,'totalUsersPerSat'), opts.totalUsersPerSat = []; end
if ~isfield(opts,'usersPerBeam'), opts.usersPerBeam = []; end
if ~isfield(opts,'excelPath') || strlength(string(opts.excelPath)) == 0
    opts.excelPath = fullfile(here, '..', '..', 'Matlab_data', 'LEO16_EPFD_Ku_power_backoff.xlsx');
end
if ~isfield(opts,'tStartStr') || strlength(string(opts.tStartStr)) == 0, opts.tStartStr = sc.StartTime; end
if ~isfield(opts,'tEndStr') || strlength(string(opts.tEndStr)) == 0, opts.tEndStr = sc.StopTime; end

if isfield(opts,'params') && ~isempty(opts.params)
    P = opts.params;
else
    P = ku_epfd_params();
end
if ~isfield(P,'Nbeam'), P.Nbeam = 16; end
if ~isfield(P,'min_elev_deg'), P.min_elev_deg = 10; end
if ~isfield(P,'BWref_Hz'), P.BWref_Hz = 1e6; end
if ~isfield(P,'EPFD_thr_dB'), P.EPFD_thr_dB = -160.0; end
if ~isfield(P,'useEIRPDensityModel'), P.useEIRPDensityModel = true; end
if ~isfield(P,'EIRPdens_dBW_per_4kHz'), P.EIRPdens_dBW_per_4kHz = -13.4; end
if P.Nbeam ~= 16, error('This function assumes 16 beams'); end

tStart = datenum(char(opts.tStartStr));
tEnd = datenum(char(opts.tEndStr));
if isfield(opts,'maxDurationHours') && ~isempty(opts.maxDurationHours)
    tEnd = min(tEnd, tStart + double(opts.maxDurationHours)/24);
end
step = double(opts.stepSec)/86400;

Nleo = numel(leoList);
Ngeo = numel(geoList);
Nbeam = 16;
thr_lin = 10^(P.EPFD_thr_dB/10);
Pbeam_W = P.Ptotal_W / Nbeam;
Gmax_lin = 10^(P.GSO_Gmax_dBi/10);
Gt_max_lin = max(P.A_fit, eps);
basePitchOffsets_deg = (8.5 - (1:Nbeam)) * (2*opts.beamHalfNS_deg);

% Ren 2021 progressive pitch config (aligns with SimOneWeb16Beams_ProgressivePitch).
pp_cfg.RE_km = P.Re_km;
pp_cfg.RG_km = opts.RG_km;
pp_cfg.alpha_th_deg = opts.alpha_th_deg;
pp_cfg.beta0_deg = 24.5;
pp_cfg.betaEllipse_deg = 1.56;
pp_cfg.theta_max_deg = 10.0;
pp_cfg.phi_theta0_deg  = 30.0;
pp_cfg.phi_thetaMax_deg = 21.96;

% Cache progressive pitch params vs latitude (speed).
pp_cache = containers.Map('KeyType', 'char', 'ValueType', 'any');

% Min allowed power scale from satisfaction target (uniform users)
minScale = max(0, min(1, opts.targetSatisfaction));
if ~isempty(opts.usersPerBeam) && isfinite(opts.usersPerBeam)
    users = double(opts.usersPerBeam) * ones(Nbeam, 1);
elseif ~isempty(opts.totalUsersPerSat) && isfinite(opts.totalUsersPerSat)
    users = (double(opts.totalUsersPerSat) / Nbeam) * ones(Nbeam, 1);
else
    users = (5 / Nbeam) * ones(Nbeam, 1);
end
usersTot = sum(users);
if ~isempty(opts.usersPerBeam) && isfinite(opts.usersPerBeam)
    fprintf('[RunEpfd16BeamsKuPowerBackoffLogExcel] user weights: usersPerBeam=%g (sum=%g)\n', opts.usersPerBeam, usersTot);
elseif ~isempty(opts.totalUsersPerSat) && isfinite(opts.totalUsersPerSat)
    fprintf('[RunEpfd16BeamsKuPowerBackoffLogExcel] user weights: totalUsersPerSat=%g split/%d beams (sum=%g)\n', opts.totalUsersPerSat, Nbeam, usersTot);
else
    fprintf('[RunEpfd16BeamsKuPowerBackoffLogExcel] user weights: default total=5 split/%d beams (paper-scale surrogate, sum=%g)\n', Nbeam, usersTot);
end

[leoPosDP, leoVelDP] = preloadLeo(root, leoList);
geoPosDP = preloadGeo(root, geoList);
gsObjMap = preloadGs(root, geoList);

P_gs_all = zeros(3, Ngeo);
for j = 1:Ngeo
    P_gs_all(:,j) = gsXYZ(gsObjMap(geoList{j}));
end

% detail buffers
Time = strings(0,1); LEO = strings(0,1); Beam = zeros(0,1); State = strings(0,1);
WorstGS = strings(0,1); epfd = nan(0,1); powerScale = nan(0,1);
satSatisfaction = nan(0,1);
inBeamCol = zeros(0,1);
thetaSignedCol = nan(0,1);
gateOffCol = zeros(0,1); % forced off by progressive pitch gate (0/1)

% summary buffers
TimeS = strings(0,1); GeoName = strings(0,1); EPFD_total_dB = nan(0,1); N_LEO_active = zeros(0,1);

for t = tStart:step:tEnd
    tStr = datestr(t, 'dd mmm yyyy HH:MM:SS');
    root.ExecuteCommand(['Animate * SetTime "' tStr '"']);

    P_geo_all = zeros(3, Ngeo);
    for j = 1:Ngeo
        P_geo_all(:,j) = stkXYZ(geoPosDP(geoList{j}), tStr);
    end

    total_epfd_geo = zeros(1, Ngeo);
    leo_active_geo = zeros(1, Ngeo);

    for i = 1:Nleo
        leoName = leoList{i};
        P_leo = stkXYZ(leoPosDP(leoName), tStr);
        V_leo = stkXYZ(leoVelDP(leoName), tStr);

        % ===== Progressive pitch tilt (Ren 2021) =====
        thetaSigned_deg = 0;
        Noff_eff = 0;
        gateOffVec = false(Nbeam,1);
        if opts.useProgressivePitchTilt
            phiS_deg = asind(P_leo(3) / max(norm(P_leo), eps));
            tStr2 = datestr(t + opts.motionDeltaSec/86400, 'dd mmm yyyy HH:MM:SS');
            P_leo2 = stkXYZ(leoPosDP(leoName), tStr2);
            phiS2_deg = asind(P_leo2(3) / max(norm(P_leo2), eps));
            dphi_deg = phiS2_deg - phiS_deg;

            key = sprintf('%.3f', round(phiS_deg, 3));
            if isKey(pp_cache, key)
                vpp = pp_cache(key);
                thetaAbs_deg = vpp.thetaAbs_deg;
                Noff_val = vpp.Noff_val;
            else
                thetaAbs_deg = progressivePitchThetaAbs_Ren2021(phiS_deg, pp_cfg);
                RS_km = norm(P_leo);
                Noff_val = progressivePitchNoff_Ren2021(phiS_deg, RS_km, pp_cfg);
                vpp = struct('thetaAbs_deg', thetaAbs_deg, 'Noff_val', Noff_val);
                pp_cache(key) = vpp;
            end

            thetaSigned_deg = signedThetaFromMotion(phiS_deg, dphi_deg, thetaAbs_deg);
            Noff_eff = min(Nbeam, max(0, round(Noff_val)));
            if Noff_eff > 0
                if phiS_deg >= 0
                    gateOffVec(1:Noff_eff) = true;
                else
                    gateOffVec((Nbeam - Noff_eff + 1):Nbeam) = true;
                end
            end
        end

        pitchOffsets_use_deg = basePitchOffsets_deg + thetaSigned_deg;
        [b_all, c_axis] = beamBoresights(P_leo*1000, V_leo*1000, pitchOffsets_use_deg);
        b_all = reorderBoresightsNorthToSouth(P_leo*1000, b_all);

        term = zeros(Nbeam, Ngeo); % full-power beam terms
        inb = nan(Nbeam, Ngeo); % debug/report only (NaN when useInBeamFootprint is false)
        for b = 1:Nbeam
            b_hat = b_all(:,b);
            t_axis = cross(c_axis, b_hat); t_axis = t_axis / max(norm(t_axis), eps);
            for j = 1:Ngeo
                v_gs = (P_gs_all(:,j) - P_leo) * 1000;
                d_m = norm(v_gs);
                if d_m < 1, continue; end
                if gsElev(P_leo, P_gs_all(:,j)) < P.min_elev_deg, continue; end
                d_hat = v_gs / d_m;

                % inBeam definition aligned with RunEpfd16BeamsKuLogExcel:
                % thH/thV are off-nadir components in EW/NS plane.
                th_h = atan2d(dot(d_hat, c_axis), dot(d_hat, b_hat));
                th_v = atan2d(dot(d_hat, t_axis), dot(d_hat, b_hat));
                inb(b,j) = gsInBeamFootprint(th_h, th_v, opts.beamHalfEW_deg, opts.beamHalfNS_deg, P);

                phit = angleDeg(b_hat, d_hat);
                Gt_lin = max(P.A_fit * exp(P.beta_fit * phit), 1e-30);
                alpha = angleDeg(P_leo - P_gs_all(:,j), P_geo_all(:,j) - P_gs_all(:,j));
                Gr_dBi = gso_rx_gain_itu1428(alpha, P.GSO_D_m, P.lambda_m);
                Gr_lin = 10^(Gr_dBi/10);
                if P.useEIRPDensityModel
                    eirpRef_dBW = P.EIRPdens_dBW_per_4kHz + 10*log10(P.BWref_Hz/4000);
                    eirpRef_lin = 10^(eirpRef_dBW/10);
                    Gt_rel = Gt_lin / Gt_max_lin;
                    term(b,j) = eirpRef_lin * Gt_rel * (1/(4*pi*d_m^2)) * (Gr_lin/Gmax_lin);
                else
                    term(b,j) = (Pbeam_W / P.BWref_Hz) * (Gt_lin/(4*pi*d_m^2)) * (Gr_lin/Gmax_lin);
                end
            end
        end

        active = true(Nbeam,1);
        pScale = ones(Nbeam,1);
        % Apply progressive pitch gate: force-off beams away from equator.
        if opts.useProgressivePitchTilt && any(gateOffVec)
            active(gateOffVec) = false;
            pScale(gateOffVec) = 0;
        end

        % Reduce power first; if still exceeds at min satisfaction, then turn off beams
        while true
            epfd_now = ((active .* pScale).' * term); % 1 x Ngeo
            [mx, jWorst] = max(epfd_now);
            if mx <= thr_lin
                break;
            end

            contrib = (active .* pScale) .* term(:, jWorst);
            [~, bSel] = max(contrib);
            if ~isfinite(contrib(bSel)) || contrib(bSel) <= 0
                break;
            end

            % Required scale for selected beam to hit threshold (others fixed)
            others = mx - pScale(bSel) * term(bSel, jWorst);
            reqScale = (thr_lin - others) / max(term(bSel, jWorst), eps);

            if reqScale >= minScale && reqScale < pScale(bSel)
                % Can satisfy by power reduction only
                pScale(bSel) = max(minScale, reqScale);
            else
                % Cannot satisfy without going below satisfaction floor -> OFF beam
                active(bSel) = false;
                pScale(bSel) = 0;
            end

            if nnz(active) == 0
                break;
            end
        end

        epfd_final = ((active .* pScale).' * term);
        total_epfd_geo = total_epfd_geo + epfd_final;
        leo_active_geo = leo_active_geo + double(epfd_final > 0);

        [~, jWorstFinal] = max(epfd_final);
        worstName = string(geoList{jWorstFinal});
        satSat = sum(users .* active .* pScale) / max(usersTot, eps);

        for b = 1:Nbeam
            Time(end+1,1) = string(tStr);
            LEO(end+1,1) = string(leoName);
            Beam(end+1,1) = b;
            State(end+1,1) = string(ternary(active(b), 'ON', 'OFF'));
            WorstGS(end+1,1) = worstName;
            inBeamCol(end+1,1) = double(inb(b, jWorstFinal));
            thetaSignedCol(end+1,1) = thetaSigned_deg;
            gateOffCol(end+1,1) = double(gateOffVec(b));
            epfd(end+1,1) = 10*log10(max(term(b,jWorstFinal) * pScale(b), 1e-300));
            powerScale(end+1,1) = pScale(b);
            satSatisfaction(end+1,1) = satSat;
        end
    end

    for j = 1:Ngeo
        TimeS(end+1,1) = string(tStr);
        GeoName(end+1,1) = string(geoList{j});
        EPFD_total_dB(end+1,1) = 10*log10(max(total_epfd_geo(j), 1e-300));
        N_LEO_active(end+1,1) = leo_active_geo(j);
    end
end

Tdetail = table(Time, LEO, Beam, State, WorstGS, inBeamCol, thetaSignedCol, gateOffCol, ...
    powerScale, satSatisfaction, epfd, ...
    'VariableNames', {'Time','LEO','Beam','State','WorstGS','inBeam','thetaSigned_deg','gateOff','powerScale','satSatisfaction','epfd'});
Tsum = table(TimeS, GeoName, EPFD_total_dB, N_LEO_active, ...
    'VariableNames', {'Time','GeoName','EPFD_total_dB','N_LEO_active'});

excelPath = char(string(opts.excelPath));
outDir = fileparts(excelPath);
if ~isempty(outDir) && ~exist(outDir,'dir'), mkdir(outDir); end
if exist(excelPath,'file'), delete(excelPath); end
writetable(Tdetail, excelPath, 'Sheet', 'Detail');
writetable(Tsum, excelPath, 'Sheet', 'Summary');
fprintf('Saved Excel: %s\n', excelPath);
end

function [leoPosDP, leoVelDP] = preloadLeo(root, leoList)
leoPosDP = containers.Map; leoVelDP = containers.Map;
for i = 1:numel(leoList)
    nm = leoList{i};
    sat = root.GetObjectFromPath(['*/Satellite/' nm]);
    leoPosDP(nm) = sat.DataProviders.Item('Cartesian Position').Group.Item('Fixed');
    leoVelDP(nm) = sat.DataProviders.Item('Cartesian Velocity').Group.Item('Fixed');
end
end

function geoPosDP = preloadGeo(root, geoList)
geoPosDP = containers.Map;
for j = 1:numel(geoList)
    nm = geoList{j};
    geo = root.GetObjectFromPath(['*/Satellite/' nm]);
    geoPosDP(nm) = geo.DataProviders.Item('Cartesian Position').Group.Item('Fixed');
end
end

function gsObjMap = preloadGs(root, geoList)
gsObjMap = containers.Map;
for j = 1:numel(geoList)
    gn = geoList{j};
    gsObjMap(gn) = root.GetObjectFromPath(['*/Facility/GSO_GS_' gn]);
end
end

function P = gsXYZ(gsObj)
res = gsObj.DataProviders.Item('Cartesian Position').Exec;
P = xyzFromArray(res.DataSets.ToArray);
end

function P = stkXYZ(dp, tStr)
res = dp.ExecSingle(tStr);
P = xyzFromArray(res.DataSets.ToArray);
end

function P = xyzFromArray(arr)
if isnumeric(arr)
    P = double(arr(1:3));
    return;
end
vals = [];
for k = 1:numel(arr)
    a = arr{k};
    if isnumeric(a) && isscalar(a)
        vals(end+1,1) = double(a); %#ok<AGROW>
    elseif ischar(a) || isstring(a)
        n = str2double(a);
        if ~isnan(n), vals(end+1,1) = n; end %#ok<AGROW>
    end
end
if numel(vals) < 3, error('cannot parse XYZ'); end
P = vals(1:3);
end

function [b_all, c_axis] = beamBoresights(r_sat_m, v_sat_mps, pitchOffsets_deg)
n_hat = r_sat_m / max(norm(r_sat_m), eps);
v_perp = v_sat_mps - dot(v_sat_mps, n_hat) * n_hat;
t_hat = v_perp / max(norm(v_perp), eps);
c_axis = cross(n_hat, t_hat);
c_axis = c_axis / max(norm(c_axis), eps);
b0 = -n_hat;
b_all = zeros(3, numel(pitchOffsets_deg));
for k = 1:numel(pitchOffsets_deg)
    b_all(:,k) = rodrigues(b0, c_axis, deg2rad(pitchOffsets_deg(k)));
end
end

function b_sorted = reorderBoresightsNorthToSouth(r_sat_m, b_all)
Re_m = 6378137.0;
nb = size(b_all, 2);
lat_deg = -inf(1, nb);
for k = 1:nb
    hit = rayEarthIntersect(r_sat_m, b_all(:,k), Re_m);
    if ~isempty(hit)
        lat_deg(k) = asind(hit(3) / max(norm(hit), eps));
    end
end
[~, idx] = sort(lat_deg, 'descend');
b_sorted = b_all(:, idx);
end

function hit = rayEarthIntersect(r_s_m, d_unit, Re_m)
a = 1; b = 2*dot(r_s_m, d_unit); c = dot(r_s_m,r_s_m)-Re_m^2;
disc = b^2 - 4*a*c;
if disc < 0, hit = []; return; end
s = sqrt(disc);
lam1 = (-b - s)/2; lam2 = (-b + s)/2;
cand = [lam1, lam2]; cand = cand(cand > 0);
if isempty(cand), hit = []; return; end
hit = r_s_m + min(cand)*d_unit;
end

function v = rodrigues(u, k, ang)
v = u*cos(ang) + cross(k,u)*sin(ang) + k*dot(k,u)*(1-cos(ang));
v = v / max(norm(v), eps);
end

function e = gsElev(P_leo_km, P_gs_km)
zen = P_gs_km(:) / max(norm(P_gs_km), eps);
v = P_leo_km(:) - P_gs_km(:);
e = 90 - acosd(max(-1, min(1, dot(v,zen)/(norm(v)+eps))));
end

function a = angleDeg(x, y)
a = acosd(max(-1, min(1, dot(x,y)/(norm(x)*norm(y)+eps))));
end

function s = ternary(c, a, b)
if c, s = a; else, s = b; end
end

% ============================================================
% Ren 2021 progressive pitch helpers (tilt + Noff gate)
% ============================================================
function thetaAbs_deg = progressivePitchThetaAbs_Ren2021(phiS_deg, cfg)
% Based on SimOneWeb16Beams_ProgressivePitch:
% theta* = min(theta_max, beta0 - atan(c)), approximated with piecewise mapping.
aphi = abs(phiS_deg);
if aphi >= cfg.phi_theta0_deg
    thetaAbs_deg = 0;
    return;
end
if aphi > cfg.phi_thetaMax_deg
    thetaAbs_deg = cfg.theta_max_deg * (cfg.phi_theta0_deg - aphi) / ...
        (cfg.phi_theta0_deg - cfg.phi_thetaMax_deg);
    thetaAbs_deg = max(0, min(cfg.theta_max_deg, thetaAbs_deg));
    return;
end
thetaAbs_deg = cfg.theta_max_deg;
end

function Noff = progressivePitchNoff_Ren2021(phiS_deg, RS_km, cfg)
% Ren 2021 Eq.(20) (numeric boundary solve), then Noff from thetaStar.
phi_th1 = solve_phi_th1_numeric(phiS_deg, cfg.alpha_th_deg, RS_km, cfg.RG_km, cfg.RE_km);
delta = deg2rad(phi_th1 - phiS_deg);
num = cfg.RE_km * sin(delta);
den = RS_km - cfg.RE_km * cos(delta);
c = num / max(den, 1e-9);
atan_c_deg = rad2deg(atan(c));
thetaStar = min(cfg.theta_max_deg, cfg.beta0_deg - atan_c_deg);
if thetaStar < cfg.theta_max_deg - 1e-6
    Noff = 0;
    return;
end
Noff = ceil((cfg.beta0_deg - thetaStar - atan_c_deg) / (2 * cfg.betaEllipse_deg));
Noff = max(0, min(16, Noff)); % keep within 16 beams (this file assumes 16)
end

function phi_th1 = solve_phi_th1_numeric(phiS_deg, alpha_th_deg, RS_km, RG_km, RE_km)
% Solve alpha(phi)=alpha_th on Earth circle; return upper-lat solution.
Ax = RS_km * cosd(phiS_deg);
Ay = RS_km * sind(phiS_deg);
Bx = RG_km;
By = 0;
f = @(phi) angle_at_station_deg(phi, Ax, Ay, Bx, By, RE_km) - alpha_th_deg;

% Grid search for sign changes
grid = linspace(-89.9, 89.9, 721); % 0.25 deg
vals = arrayfun(f, grid);
sgn = sign(vals);
idx = find(sgn(1:end-1) == 0 | sgn(1:end-1).*sgn(2:end) < 0);
if isempty(idx)
    [~, imax] = max(-abs(vals)); %#ok<ASGLU>
    phi_th1 = grid(imax);
    return;
end

roots = nan(numel(idx), 1);
for k = 1:numel(idx)
    a = grid(idx(k));
    b = grid(idx(k)+1);
    try
        roots(k) = fzero(f, [a b]);
    catch
        % ignore failed roots
    end
end
roots = roots(isfinite(roots));
if isempty(roots)
    phi_th1 = grid(idx(end));
    return;
end
phi_th1 = max(roots);
end

function a_deg = angle_at_station_deg(phi_deg, Ax, Ay, Bx, By, RE_km)
Cx = RE_km * cosd(phi_deg);
Cy = RE_km * sind(phi_deg);
vA = [Ax - Cx; Ay - Cy];
vB = [Bx - Cx; By - Cy];
num = dot(vA, vB);
den = norm(vA) * norm(vB) + eps;
cc = min(1, max(-1, num / den));
a_deg = acosd(cc);
end

function thetaSigned_deg = signedThetaFromMotion(phiS_deg, dphi_deg, thetaAbs_deg)
% Signed tilt depends on motion direction in latitude.
if abs(phiS_deg) < 1e-6
    hemiSign = sign(dphi_deg);
    if hemiSign == 0, hemiSign = 1; end
else
    hemiSign = sign(phiS_deg);
end

if dphi_deg >= 0
    thetaSigned_deg = -hemiSign * thetaAbs_deg;
else
    thetaSigned_deg = +hemiSign * thetaAbs_deg;
end
end
