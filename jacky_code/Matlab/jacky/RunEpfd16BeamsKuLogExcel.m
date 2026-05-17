function [Tdetail, Tsum] = RunEpfd16BeamsKuLogExcel(root, opts)
% Pure MATLAB 16-beam EPFD scheduler (no STK beam sensors needed).
%
% Uses STK only for LEO/GEO/GS states, then:
% - builds 16 north->south beam boresights in MATLAB
% - computes per-beam EPFD term to each GSO earth station
% - greedily turns off beams with highest contribution until EPFD is below threshold
% - logs per-second detail + summary to Excel

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
if ~isfield(opts,'minOnBeams') || ~isfinite(opts.minOnBeams), opts.minOnBeams = 0; end
if ~isfield(opts,'controlMode') || strlength(string(opts.controlMode)) == 0
    opts.controlMode = "aggregate";
end
if ~isfield(opts,'excelPath') || strlength(string(opts.excelPath)) == 0
    opts.excelPath = fullfile(here, '..', '..', 'Matlab_data', 'LEO16_EPFD_Ku_log.xlsx');
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
if ~isfield(P,'useEIRPDensityModel'), P.useEIRPDensityModel = false; end
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
pitchOffsets_deg = (8.5 - (1:Nbeam)) * (2*opts.beamHalfNS_deg); % beam 1 north side

[leoPosDP, leoVelDP, leoLlaDP] = preloadLeo(root, leoList);
geoPosDP = preloadGeo(root, geoList);
gsObjMap = preloadGs(root, geoList);

P_gs_all = zeros(3, Ngeo);
for j = 1:Ngeo
    P_gs_all(:,j) = gsXYZ(gsObjMap(geoList{j}));
end

% detail buffers (simple + debug-friendly)
Time = strings(0,1); LEO = strings(0,1); Beam = zeros(0,1); State = strings(0,1);
WorstGS = strings(0,1); epfd = nan(0,1);
inBeamCol = zeros(0,1); activeCol = zeros(0,1);

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
        phiS = stkLat(leoLlaDP(leoName), tStr);
        [b_all, c_axis] = beamBoresights(P_leo*1000, V_leo*1000, pitchOffsets_deg);
        % Enforce beam numbering convention per epoch:
        % Beam 1 = northernmost strip, Beam 16 = southernmost strip.
        b_all = reorderBoresightsNorthToSouth(P_leo*1000, b_all);

        term = zeros(Nbeam, Ngeo);
        inb = nan(Nbeam, Ngeo); % debug/report only (NaN when useInBeamFootprint is false)
        offH = nan(Nbeam, Ngeo);
        offV = nan(Nbeam, Ngeo);
        phit = nan(Nbeam, Ngeo);
        elev = nan(Nbeam, Ngeo);

        for b = 1:Nbeam
            b_hat = b_all(:,b);
            t_axis = cross(c_axis, b_hat);
            t_axis = t_axis / max(norm(t_axis), eps);

            for j = 1:Ngeo
                v_gs = (P_gs_all(:,j) - P_leo) * 1000; % sat->GS
                d_m = norm(v_gs);
                if d_m < 1, continue; end
                d_hat = v_gs / d_m;

                elev(b,j) = gsElev(P_leo, P_gs_all(:,j));

                th_h = atan2d(dot(d_hat, c_axis), dot(d_hat, b_hat));
                th_v = atan2d(dot(d_hat, t_axis), dot(d_hat, b_hat));
                offH(b,j) = th_h; offV(b,j) = th_v;
                inb(b,j) = gsInBeamFootprint(th_h, th_v, opts.beamHalfEW_deg, opts.beamHalfNS_deg, P);

                phit(b,j) = angleDeg(b_hat, d_hat);
                Gt_lin = max(P.A_fit * exp(P.beta_fit * phit(b,j)), 1e-30);
                alpha = angleDeg(P_leo - P_gs_all(:,j), P_geo_all(:,j) - P_gs_all(:,j));
                Gr_dBi = gso_rx_gain_itu1428(alpha, P.GSO_D_m, P.lambda_m);
                Gr_lin = 10^(Gr_dBi/10);
                if P.useEIRPDensityModel && isfield(P,'EIRPdens_dBW_per_4kHz')
                    % EIRP density reference in BWref, then apply TX pattern relative attenuation
                    eirpRef_dBW = P.EIRPdens_dBW_per_4kHz + 10*log10(P.BWref_Hz/4000);
                    eirpRef_lin = 10^(eirpRef_dBW/10);
                    Gt_rel = Gt_lin / Gt_max_lin;
                    term(b,j) = eirpRef_lin * Gt_rel * (1/(4*pi*d_m^2)) * (Gr_lin/Gmax_lin);
                else
                    % legacy power model
                    term(b,j) = (Pbeam_W / P.BWref_Hz) * (Gt_lin/(4*pi*d_m^2)) * (Gr_lin/Gmax_lin);
                end
            end
        end

        % Beam control
        % - aggregate: sum EPFD across beams (per GS), if exceeded then greedy turn-off
        % - per_beam:  each beam independently compared with threshold
        active = true(Nbeam,1);
        minOn = max(0, min(Nbeam, round(opts.minOnBeams)));
        mode = lower(string(opts.controlMode));
        if mode == "per_beam"
            maxTermPerBeam = max(term, [], 2);       % Nbeam x 1
            active = (maxTermPerBeam <= thr_lin);    % exceed => OFF
        else
            while true
                epfd_now = (active.' * term);        % 1 x Ngeo
                [mx, jWorst] = max(epfd_now);
                if mx <= thr_lin || nnz(active) <= minOn
                    break;
                end
                contrib = term(:, jWorst);
                contrib(~active) = -inf;
                [~, bKill] = max(contrib);
                if ~isfinite(contrib(bKill)) || contrib(bKill) <= 0
                    break;
                end
                active(bKill) = false;
            end
        end

        epfd_final = (active.' * term);
        total_epfd_geo = total_epfd_geo + epfd_final;
        leo_active_geo = leo_active_geo + double(epfd_final > 0);

        [~, jWorstFinal] = max(epfd_final);
        worstName = string(geoList{jWorstFinal});
        worstVal = epfd_final(jWorstFinal);

        for b = 1:Nbeam
            Time(end+1,1) = string(tStr);
            LEO(end+1,1) = string(leoName);
            Beam(end+1,1) = b;
            State(end+1,1) = string(ternary(active(b), 'ON', 'OFF'));
            WorstGS(end+1,1) = worstName;
            inBeamNow = inb(b,jWorstFinal); % debug only
            activeNow = logical(active(b));
            inBeamCol(end+1,1) = double(inBeamNow);
            activeCol(end+1,1) = double(activeNow);
            % report computed EPFD regardless of coverage/active state.
            epfd_lin = term(b,jWorstFinal);
            epfd(end+1,1) = 10*log10(max(epfd_lin, 1e-300));
        end
    end

    for j = 1:Ngeo
        TimeS(end+1,1) = string(tStr);
        GeoName(end+1,1) = string(geoList{j});
        EPFD_total_dB(end+1,1) = 10*log10(max(total_epfd_geo(j), 1e-300));
        N_LEO_active(end+1,1) = leo_active_geo(j);
    end
end

Tdetail = table(Time, LEO, Beam, State, WorstGS, inBeamCol, activeCol, epfd, ...
    'VariableNames', {'Time','LEO','Beam','State','WorstGS','inBeam','active','epfd'});
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

function v = rodrigues(u, k, ang)
    v = u*cos(ang) + cross(k,u)*sin(ang) + k*dot(k,u)*(1-cos(ang));
    v = v / max(norm(v), eps);
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
[~, idx] = sort(lat_deg, 'descend'); % north -> south
b_sorted = b_all(:, idx);
end

function hit = rayEarthIntersect(r_s_m, d_unit, Re_m)
a = 1.0;
b = 2.0 * dot(r_s_m, d_unit);
c = dot(r_s_m, r_s_m) - Re_m^2;
disc = b^2 - 4*a*c;
if disc < 0
    hit = [];
    return;
end
s = sqrt(disc);
lam1 = (-b - s) / 2.0;
lam2 = (-b + s) / 2.0;
cand = [lam1, lam2];
cand = cand(cand > 0);
if isempty(cand)
    hit = [];
    return;
end
lam = min(cand);
hit = r_s_m + lam * d_unit;
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

function [leoPosDP, leoVelDP, leoLlaDP] = preloadLeo(root, leoList)
    leoPosDP = containers.Map; leoVelDP = containers.Map; leoLlaDP = containers.Map;
    for i = 1:numel(leoList)
        nm = leoList{i};
        sat = root.GetObjectFromPath(['*/Satellite/' nm]);
        leoPosDP(nm) = sat.DataProviders.Item('Cartesian Position').Group.Item('Fixed');
        leoVelDP(nm) = sat.DataProviders.Item('Cartesian Velocity').Group.Item('Fixed');
        leoLlaDP(nm) = sat.DataProviders.Item('LLA State').Group.Item('Fixed');
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

function lat = stkLat(dp, tStr)
    res = dp.ExecSingle(tStr);
    lat = firstNumeric(res.DataSets.ToArray);
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

function v = firstNumeric(arr)
    if isnumeric(arr), v = double(arr(1)); return; end
    for k = 1:numel(arr)
        a = arr{k};
        if isnumeric(a) && isscalar(a), v = double(a); return; end
        if ischar(a) || isstring(a)
            n = str2double(a);
            if ~isnan(n), v = n; return; end
        end
    end
    error('cannot parse scalar');
end
