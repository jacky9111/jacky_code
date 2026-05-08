function T = SimOneWeb16Beams_ProgressivePitch(root, leoList, geoList, stepSec, opts)
% SimOneWeb16Beams_ProgressivePitch
% Simulate OneWeb progressive pitch + 16-beam ON/OFF purely in MATLAB.
%
% - STK is used ONLY to read positions (LEO/GEO/GS) and to sync time.
% - Beams are NOT created in STK. The output is a MATLAB table of beam states.
%
% Beam indexing convention (MATLAB-side only):
% - Default: beamOrder="northToSouth"
%   Beam 1 is the northernmost beam (away from equator when phiS>0),
%   Beam 16 is the southernmost beam (away from equator when phiS<0).
% - If you prefer the opposite numbering, set opts.beamOrder="southToNorth".
%
% Inputs
% - root: STK root (actx)
% - leoList: cellstr of LEO satellite names (e.g. {'ow1_3','ow1_30'})
% - geoList: cellstr of GEO names used to bind a GS facility (e.g. {'geo_4_1'})
% - stepSec: simulation time step in seconds
% - opts (optional struct):
%     .tStartStr (default=sc.StartTime)
%     .tEndStr   (default=sc.StopTime)
%     .saveExcel (default=true)
%     .excelPath (default='C:\Users\jacky\Desktop\jacky_code\Matlab_data\OneWeb16Beam_MatlabSim.xlsx')
%     .beamOrder (default="northToSouth")  % or "southToNorth"
%     .metric (default="epfd")            % "epfd" or "alpha"
%     .epfd_thr_dB (default=-173.4)       % dB(W/m^2/1MHz)
%     .BWref_Hz (default=1e6)             % reference bandwidth for EPFD
%     .leo_psd_dBW_per_4kHz (default=-13.4) % OneWeb PSD (Table 2)
%     .gs_diameter_m (default=0.6)        % GSO earth station dish diameter (Table 1)
%     .freq_GHz (default=12.7)            % GSO downlink freq for rx pattern wavelength (Table 1)
%     .rx_pattern (default="rec465")      % "rec465" (approx) or "itu1428"
%
% Output
% - T: table with per-time, per-LEO, per-beam results.

if nargin < 5 || isempty(opts)
    opts = struct();
end

sc = root.CurrentScenario;

% Accept string array / char / cellstr uniformly
leoList = cellstr(string(leoList));
geoList = cellstr(string(geoList));

cfg = defaultPaperConfig();
cfg.stepSec = stepSec;

if ~isfield(opts, 'tStartStr') || strlength(string(opts.tStartStr)) == 0
    opts.tStartStr = sc.StartTime;
end
if ~isfield(opts, 'tEndStr') || strlength(string(opts.tEndStr)) == 0
    opts.tEndStr = sc.StopTime;
end
if ~isfield(opts, 'saveExcel')
    opts.saveExcel = true;
end
if ~isfield(opts, 'excelPath') || strlength(string(opts.excelPath)) == 0
    opts.excelPath = 'C:\Users\jacky\Desktop\jacky_code\Matlab_data\OneWeb16Beam_MatlabSim.xlsx';
end
if ~isfield(opts, 'beamOrder') || strlength(string(opts.beamOrder)) == 0
    opts.beamOrder = "northToSouth";
end
beamOrder = string(opts.beamOrder);

% ---- EPFD-based shutoff config (defaults follow OneWeb progressive pitch paper tables) ----
if ~isfield(opts, 'metric') || strlength(string(opts.metric)) == 0
    opts.metric = "epfd";
end
metric = lower(string(opts.metric));

if ~isfield(opts, 'epfd_thr_dB') || ~isfinite(opts.epfd_thr_dB)
    opts.epfd_thr_dB = -173.4; % dB(W/m^2/1MHz) (default aligns with your EPFD codebase)
end
epfd_thr_dB = double(opts.epfd_thr_dB);

if ~isfield(opts, 'BWref_Hz') || ~isfinite(opts.BWref_Hz) || opts.BWref_Hz <= 0
    opts.BWref_Hz = 1e6;
end
BWref_Hz = double(opts.BWref_Hz);

if ~isfield(opts, 'leo_psd_dBW_per_4kHz') || ~isfinite(opts.leo_psd_dBW_per_4kHz)
    opts.leo_psd_dBW_per_4kHz = -13.4; % Table 2
end
leo_psd_dBW_per_4kHz = double(opts.leo_psd_dBW_per_4kHz);

if ~isfield(opts, 'gs_diameter_m') || ~isfinite(opts.gs_diameter_m) || opts.gs_diameter_m <= 0
    opts.gs_diameter_m = 0.6; % Table 1
end
gs_diameter_m = double(opts.gs_diameter_m);

if ~isfield(opts, 'freq_GHz') || ~isfinite(opts.freq_GHz) || opts.freq_GHz <= 0
    opts.freq_GHz = 12.7; % Table 1
end
freq_GHz = double(opts.freq_GHz);
lambda_m = 3e8 / (freq_GHz * 1e9);

if ~isfield(opts, 'rx_pattern') || strlength(string(opts.rx_pattern)) == 0
    opts.rx_pattern = "rec465";
end
rx_pattern = lower(string(opts.rx_pattern));

% Convert PSD (dBW/4kHz) -> EIRP spectral power in BWref (W/BWref)
EIRP_ref_dBW = leo_psd_dBW_per_4kHz + 10*log10(BWref_Hz / 4000);
EIRP_ref_W = 10^(EIRP_ref_dBW/10);

% Cache for progressive pitch parameters vs phiS (speed)
pp_cache = containers.Map('KeyType', 'char', 'ValueType', 'any');

tStart = datenum(char(opts.tStartStr));
tEnd   = datenum(char(opts.tEndStr));
step   = cfg.stepSec / 86400;

fprintf("\n=== MATLAB beam simulation (NO STK sensors) ===\n");
fprintf("time: %s -> %s | step=%d sec | alpha_th=%.2f deg\n", ...
    datestr(tStart), datestr(tEnd), cfg.stepSec, cfg.alpha_th_deg);
fprintf("metric=%s | EPFD_thr=%.1f dB(W/m^2/%.0fHz) | EIRPref=%.2f dBW | rx_pattern=%s\n", ...
    metric, epfd_thr_dB, BWref_Hz, EIRP_ref_dBW, rx_pattern);

% ---- Preload STK providers (FIXED frame) ----
[leoPosDPs, leoLlaDPs] = preloadLeoProviders(root, leoList);
[geoPosDPs, gsObjMap, gsLatMap] = preloadGeoAndGS(root, geoList);

% ---- Buffers ----
Time = strings(0,1);
LEO = strings(0,1);
Beam = zeros(0,1);
State = strings(0,1);         % "ON"/"OFF"
ForcedOff = zeros(0,1);       % 0/1
InCovCount = zeros(0,1);
WorstGS = strings(0,1);
MinAlpha_deg = nan(0,1);
WorstEPFD_dB = nan(0,1);
EPFD_thr_out_dB = nan(0,1);
phiS_deg = nan(0,1);
thetaSigned_deg = nan(0,1);
thetaAbs_deg = nan(0,1);
Noff = zeros(0,1);
phiB1_deg = nan(0,1);
phiB2_deg = nan(0,1);
phiES_deg = nan(0,1);

% Pre-resolve GS fixed XYZ & latitude (facilities are fixed)
Ngeo = numel(geoList);
P_gs_all  = zeros(3, Ngeo);
phiES_all = zeros(1, Ngeo);
for j = 1:Ngeo
    geoName = geoList{j};
    gsObj   = gsObjMap(geoName);
    res = gsObj.DataProviders.Item('Cartesian Position').Exec;
    arr = res.DataSets.ToArray;
    P_gs_all(:,j) = stkGetXYZ_FromArray(arr);
    phiES_all(j) = gsLatMap(geoName);
end

t = tStart;
while t <= tEnd
    tStr = datestr(t,'dd mmm yyyy HH:MM:SS');
    root.ExecuteCommand(['Animate * SetTime "' tStr '"']);

    % GEO positions at this time (satellite fixed frame is time-varying)
    P_geo_all = zeros(3, Ngeo);
    for j = 1:Ngeo
        geoName = geoList{j};
        P_geo_all(:,j) = stkGetXYZ_ExecSingle(geoPosDPs(geoName), tStr);
    end

    for i = 1:numel(leoList)
        leoName = leoList{i};

        P_leo = stkGetXYZ_ExecSingle(leoPosDPs(leoName), tStr);
        phiS  = stkGetLat_ExecSingle(leoLlaDPs(leoName), tStr);

        % Motion direction (ascending/descending) by latitude 1 sec later
        tStr2 = datestr(t + (1/86400), 'dd mmm yyyy HH:MM:SS');
        phiS2 = stkGetLat_ExecSingle(leoLlaDPs(leoName), tStr2);
        dphi  = phiS2 - phiS;

        % Progressive pitch parameters (Ren 2021): thetaAbs + Noff depend on phiS
        key = sprintf('%.3f', round(phiS, 3));
        if isKey(pp_cache, key)
            v = pp_cache(key);
            thetaAbs = v.thetaAbs;
            Noff_i = v.Noff;
        else
            thetaAbs = progressivePitchThetaAbs_Ren2021(phiS, cfg);
            Noff_i = progressivePitchNoff_Ren2021(phiS, norm(P_leo), cfg);
            pp_cache(key) = struct('thetaAbs', thetaAbs, 'Noff', Noff_i);
        end
        thetaSigned = signedThetaFromMotion(phiS, dphi, thetaAbs);

        RS_km = norm(P_leo);
        RE_km = cfg.RE_km;

        % Discrimination angle alpha for all GS (GS view)
        vLEO = P_leo(:,ones(1,Ngeo)) - P_gs_all;  % GS->LEO
        vGEO = P_geo_all - P_gs_all;             % GS->GEO
        alpha_all = angleDeg_columns(vLEO, vGEO);

        % Force off beams away from equator (paper rule)
        Nbeam = cfg.Nellipse;
        forceOff = false(1, Nbeam);
        if Noff_i > 0
            Noff_eff = min(Nbeam, max(0, round(Noff_i)));
            if beamOrder == "southToNorth"
                % Reverse numbering
                if phiS >= 0
                    forceOff((Nbeam - Noff_eff + 1):Nbeam) = true;
                else
                    forceOff(1:Noff_eff) = true;
                end
            else
                % Default: northToSouth
                if phiS >= 0
                    forceOff(1:Noff_eff) = true;
                else
                    forceOff((Nbeam - Noff_eff + 1):Nbeam) = true;
                end
            end
        end

        for b = 1:Nbeam
            % Beam-by-beam paper gate (same as your original control function)
            bp = Nbeam - b + 1;  % paper-equivalent index
            beta_b = cfg.beta0_deg - (2*bp - 1)*cfg.betaEllipse_deg;

            psi_upper = deg2rad(beta_b - thetaSigned);
            psi_lower = deg2rad(cfg.beta0_deg + thetaSigned);

            delta_upper = rad2deg(acos(g_func(psi_upper, RE_km, RS_km)));
            delta_lower = rad2deg(acos(g_func(psi_lower, RE_km, RS_km)));

            phiB1 = phiS + delta_upper;
            phiB2 = phiS - delta_lower;

            inCov = (phiES_all >= phiB2) & (phiES_all <= phiB1);
            inCovCount = sum(inCov);

            if any(inCov)
                alpha_b = alpha_all(inCov);
                [alphaMin, idxLocal] = min(alpha_b);
                covIdx = find(inCov);
                jWorst = covIdx(idxLocal);
                worstGS = string(geoList{jWorst});
                phiES_worst = phiES_all(jWorst);
            else
                alphaMin = NaN;
                worstGS = "NONE";
                phiES_worst = NaN;
            end

            % ---- Metric-based violation ----
            worst_epfd = NaN;
            violate = false;

            if any(inCov)
                covIdx = find(inCov);
                epfd_vals = nan(numel(covIdx), 1);

                for jj = 1:numel(covIdx)
                    j = covIdx(jj);
                    d_m = norm((P_leo - P_gs_all(:, j))) * 1000;
                    a_deg = alpha_all(j);

                    % Relative rx gain Gr(a)/Gr_max (linear)
                    switch rx_pattern
                        case "itu1428"
                            Gr_dBi = rx_gain_itu1428(a_deg, gs_diameter_m, lambda_m);
                        otherwise
                            Gr_dBi = rx_gain_rec465_approx(a_deg, gs_diameter_m, lambda_m);
                    end
                    Gmax_dBi = 20*log10(gs_diameter_m/lambda_m) + 7.7;
                    Gr_rel_lin = 10^((Gr_dBi - Gmax_dBi)/10);

                    % EPFD per BWref: (EIRP/BWref)/(4πd^2) * (Gr/Gr_max)
                    epfd_lin = (EIRP_ref_W / (4*pi*d_m^2)) * Gr_rel_lin;
                    epfd_vals(jj) = 10*log10(max(epfd_lin, 1e-300));
                end

                [worst_epfd, kmax] = max(epfd_vals);
                worstGS = string(geoList{covIdx(kmax)});
                phiES_worst = phiES_all(covIdx(kmax));

                if metric == "epfd"
                    violate = (worst_epfd > epfd_thr_dB);
                end
            end

            if metric == "alpha"
                violate = any(inCov) && (alphaMin < cfg.alpha_th_deg);
            end

            off = forceOff(b) || violate;

            Time(end+1,1) = string(tStr);
            LEO(end+1,1) = string(leoName);
            Beam(end+1,1) = b;
            ForcedOff(end+1,1) = double(forceOff(b));
            InCovCount(end+1,1) = inCovCount;
            WorstGS(end+1,1) = worstGS;
            MinAlpha_deg(end+1,1) = alphaMin;
            WorstEPFD_dB(end+1,1) = worst_epfd;
            EPFD_thr_out_dB(end+1,1) = epfd_thr_dB;
            phiS_deg(end+1,1) = phiS;
            thetaSigned_deg(end+1,1) = thetaSigned;
            thetaAbs_deg(end+1,1) = thetaAbs;
            Noff(end+1,1) = Noff_i;
            phiB1_deg(end+1,1) = phiB1;
            phiB2_deg(end+1,1) = phiB2;
            phiES_deg(end+1,1) = phiES_worst;
            State(end+1,1) = string(offIf(off));
        end
    end

    t = t + step;
end

T = table(Time, LEO, Beam, State, ForcedOff, InCovCount, WorstGS, MinAlpha_deg, ...
    WorstEPFD_dB, EPFD_thr_out_dB, ...
    phiS_deg, thetaAbs_deg, thetaSigned_deg, Noff, phiB1_deg, phiB2_deg, phiES_deg);

if opts.saveExcel
    outDir = fileparts(opts.excelPath);
    if ~exist(outDir, 'dir')
        mkdir(outDir);
    end
    writetable(T, opts.excelPath);
    fprintf("Saved: %s\n", opts.excelPath);
end
end

function s = offIf(off)
if off
    s = "OFF";
else
    s = "ON";
end
end

% ============================================================
% Config (paper-aligned)
% ============================================================
function cfg = defaultPaperConfig()
cfg.RE_km = 6378.137;
cfg.alpha_th_deg = 10.0;
cfg.RG_km = 42164; % GEO radius (km), circular approximation

% Paper Section 2.1 / Figure 3
% Note: paper text says (horizontal, vertical) = (25, 24.5) deg.
% This model uses beta0 in the latitude-coverage gate (Eq.2).
cfg.beta0_deg       = 24.5;
cfg.betaEllipse_deg = 1.56;

% Progressive pitch mapping breakpoints (paper Figure 7)
cfg.theta_max_deg = 10.0;
cfg.phi_theta0_deg  = 30.0;
cfg.phi_thetaMax_deg = 21.96;

cfg.Nellipse = 16;
cfg.stepSec  = 30;
end

% ============================================================
% Progressive pitch params (Ren 2021, Eq.(20) via numeric phi_th1)
% ============================================================
function thetaAbs_deg = progressivePitchThetaAbs_Ren2021(phiS_deg, cfg)
% Eq.(20): theta* = min(theta_max, beta0 - atan(c))
RS_km = cfg.RE_km + 1200; %#ok<NASGU> % placeholder; thetaAbs is weakly sensitive, will be refined via Noff calc
% Use a smooth approximation for thetaAbs based on breakpoints in the paper.
% (ThetaAbs is only used for tilt sign & coverage gate shift; Noff uses Eq.(20) below.)
aphi = abs(phiS_deg);
if aphi >= cfg.phi_theta0_deg
    thetaAbs_deg = 0;
    return;
end
if aphi > cfg.phi_thetaMax_deg
    thetaAbs_deg = cfg.theta_max_deg * (cfg.phi_theta0_deg - aphi) / (cfg.phi_theta0_deg - cfg.phi_thetaMax_deg);
    thetaAbs_deg = max(0, min(cfg.theta_max_deg, thetaAbs_deg));
    return;
end
thetaAbs_deg = cfg.theta_max_deg;
end

function Noff = progressivePitchNoff_Ren2021(phiS_deg, RS_km, cfg)
% Ren 2021 Eq.(20) for Noff, using numeric solve for phi_th,1 from alpha_th.
% When theta* < theta_max, Noff = 0.

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
Noff = max(0, min(cfg.Nellipse, Noff));
end

function phi_th1 = solve_phi_th1_numeric(phiS_deg, alpha_th_deg, RS_km, RG_km, RE_km)
% Solve for phi on Earth circle where discrimination angle alpha(phi)=alpha_th.
% Return the upper-latitude solution in [-90,90] (phi_th,1 in the paper).

% 2D coordinates with co-longitude assumption (paper simplification)
Ax = RS_km * cosd(phiS_deg);
Ay = RS_km * sind(phiS_deg);
Bx = RG_km;
By = 0;

f = @(phi) angle_at_station_deg(phi, Ax, Ay, Bx, By, RE_km) - alpha_th_deg;

% Grid search for sign changes, then refine with fzero
grid = linspace(-89.9, 89.9, 721); % 0.25 deg
vals = arrayfun(f, grid);
sgn = sign(vals);
idx = find(sgn(1:end-1) == 0 | sgn(1:end-1).*sgn(2:end) < 0);
if isempty(idx)
    % Fallback: pick phi maximizing alpha (should be safe but coarse)
    [~, imax] = max(-abs(vals));
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
        % ignore
    end
end
roots = roots(isfinite(roots));
if isempty(roots)
    phi_th1 = grid(idx(end));
    return;
end

phi_th1 = max(roots); % choose upper boundary (phi_th,1)
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

% ============================================================
% Preload providers
% ============================================================
function [leoPosDPs, leoLlaDPs] = preloadLeoProviders(root, leoList)
leoPosDPs = containers.Map;
leoLlaDPs = containers.Map;
for i = 1:numel(leoList)
    leoName = leoList{i};
    satObj = root.GetObjectFromPath(['*/Satellite/' leoName]);
    leoPosDPs(leoName) = satObj.DataProviders.Item('Cartesian Position').Group.Item('Fixed');
    leoLlaDPs(leoName) = satObj.DataProviders.Item('LLA State').Group.Item('Fixed');
end
end

function [geoPosDPs, gsObjMap, gsLatMap] = preloadGeoAndGS(root, geoList)
% GEO satellites: fixed-frame cartesian provider (ExecSingle per time)
% GS facilities: assumed to be created as */Facility/GSO_GS_<geoName>
geoPosDPs = containers.Map;
gsObjMap  = containers.Map;
gsLatMap  = containers.Map;

for j = 1:numel(geoList)
    geoName = geoList{j};

    geoSat = root.GetObjectFromPath(['*/Satellite/' geoName]);
    geoPosDPs(geoName) = geoSat.DataProviders.Item('Cartesian Position').Group.Item('Fixed');

    gsObj = root.GetObjectFromPath(['*/Facility/GSO_GS_' geoName]);
    gsObjMap(geoName) = gsObj;

    % GS latitude (deg)
    lat = NaN;
    try
        res = gsObj.DataProviders.Item('LLA State').Exec;
        arr = res.DataSets.ToArray;
        lat = stkGetLat_FromArray(arr);
    catch
        res = gsObj.DataProviders.Item('Cartesian Position').Exec;
        arr = res.DataSets.ToArray;
        P = stkGetXYZ_FromArray(arr);
        lat = geoLatFromFixedXYZ(P);
    end
    gsLatMap(geoName) = lat;
end
end

function lat = geoLatFromFixedXYZ(P)
x = P(1); y = P(2); z = P(3);
lat = atan2d(z, sqrt(x^2 + y^2));
end

% ============================================================
% Geometry helpers + STK extraction (copied from your control code)
% ============================================================
function alpha = angleDeg_columns(v1_all, v2_all)
num = sum(v1_all .* v2_all, 1);
den = sqrt(sum(v1_all.^2,1)) .* sqrt(sum(v2_all.^2,1)) + eps;
c   = num ./ den;
c   = min(1, max(-1, c));
alpha = acosd(c);
end

function val = g_func(psi_rad, RE_km, RS_km)
s = sin(psi_rad);
c = cos(psi_rad);
under = RE_km^2 - (RS_km^2)*(s.^2);
under = max(under, 0);
val = (RS_km*(s.^2) + c.*sqrt(under)) / RE_km;
val = min(1, max(-1, val));
end

% ============================================================
% RX antenna patterns (used for EPFD metric)
% ============================================================
function G_dBi = rx_gain_itu1428(phi_deg, D_m, lambda_m)
% ITU-R S.1428-1 (used in your powertilt codebase)
G_max_dB = 20*log10(D_m/lambda_m) + 7.7;
psi_m_deg = (20 * lambda_m / D_m) * sqrt(max(G_max_dB - (29 - 25*log10(95*lambda_m/D_m)), 0));
G_1_dB = 29 - 25*log10(95*lambda_m/D_m);

phi = max(0, phi_deg);
if phi <= psi_m_deg
    G_dBi = G_max_dB - 0.0025 * (phi * D_m / lambda_m)^2;
elseif phi <= 95*lambda_m/D_m
    G_dBi = G_1_dB;
elseif phi <= 33.1
    G_dBi = 29 - 25*log10(phi);
elseif phi <= 80
    G_dBi = -9;
elseif phi <= 120
    G_dBi = -4;
else
    G_dBi = -9;
end
G_dBi = min(G_dBi, G_max_dB);
end

function G_dBi = rx_gain_rec465_approx(phi_deg, D_m, lambda_m)
% Approximation for ITU-R S.465-5 earth-station antenna pattern.
Gmax = 20*log10(D_m/lambda_m) + 7.7;
phi = max(0, phi_deg);

phi_r = 95*lambda_m/D_m;              % deg
G1 = 29 - 25*log10(max(phi_r, 1e-6)); % dBi
phi_m = (20*lambda_m/D_m) * sqrt(max(Gmax - G1, 0));

if phi <= phi_m
    G_dBi = Gmax - 0.0025 * (phi * D_m / lambda_m)^2;
elseif phi <= phi_r
    G_dBi = G1;
elseif phi <= 48
    G_dBi = 29 - 25*log10(phi);
else
    G_dBi = -10;
end

G_dBi = min(G_dBi, Gmax);
end

function P = stkGetXYZ_ExecSingle(dp, tStr)
res = dp.ExecSingle(tStr);
arr = res.DataSets.ToArray;
P = stkGetXYZ_FromArray(arr);
end

function lat = stkGetLat_ExecSingle(dpLLA, tStr)
res = dpLLA.ExecSingle(tStr);
arr = res.DataSets.ToArray;
lat = stkGetLat_FromArray(arr);
end

function P = stkGetXYZ_FromArray(arr)
vals = [];
for k = 1:numel(arr)
    a = arr{k};
    if isnumeric(a) && isscalar(a)
        vals(end+1,1) = double(a); %#ok<AGROW>
    end
end
if numel(vals) < 3
    error('STK XYZ extraction failed: found only %d numeric scalars.', numel(vals));
end
P = vals(1:3);
P = P(:);
end

function lat = stkGetLat_FromArray(arr)
vals = [];
for k = 1:numel(arr)
    a = arr{k};
    if isnumeric(a) && isscalar(a)
        vals(end+1,1) = double(a); %#ok<AGROW>
    end
end
if isempty(vals)
    error('STK LLA extraction failed: no numeric scalars found.');
end
lat = vals(1);
end

