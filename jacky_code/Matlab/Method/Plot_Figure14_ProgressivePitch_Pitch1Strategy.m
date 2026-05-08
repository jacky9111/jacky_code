function out = Plot_Figure14_ProgressivePitch_Pitch1Strategy(root, geoName, target_sat, t_start, t_end, dt_sec, opts)
% Plot_Figure14_ProgressivePitch_Pitch1Strategy
% Figure14-like plot for Ren 2021 progressive pitch baseline using pitch1.m strategy:
% - progressive pitch (theta, NOFF)
% - beam forced-off away from equator (by NOFF)
% - EPFD-based shutoff (per-beam, if GS is in beam coverage)
%
% IMPORTANT: does NOT read Excel; runs STK time slices directly (like Plot_Figure14_LEO_Passing).
%
% Inputs:
% - root: STK root
% - geoName: e.g. "geo_16_4" (assumes Facility/GSO_GS_<geoName> exists)
% - target_sat: e.g. "ow1_30"
% - t_start, t_end: '16 Dec 2025 12:10:03'
% - dt_sec: time step in seconds
% - opts (optional struct):
%   .user_lat_deg (default=linspace(-0.1,0.1,5)')
%   .beamOrder (default="northToSouth")
%   .alpha_th_deg (default=10)
%   .beta0_deg (default=24.5)
%   .betaEllipse_deg (default=1.56)
%   .theta_max_deg (default=10)
%   .Nellipse (default=16)
%   .epfd_thr_dB (default=-173.4)          % dB(W/m^2/1MHz)
%   .BWref_Hz (default=1e6)
%   .leo_psd_dBW_per_4kHz (default=-13.4)
%   .gs_diameter_m (default=0.6)
%   .freq_GHz (default=12.7)
%   .rx_pattern (default="rec465")         % "rec465" (approx) or "itu1428"
%
% Output:
% - out struct with vectors and computed table

if nargin < 7 || isempty(opts)
    opts = struct();
end

geoName = string(geoName);
target_sat = string(target_sat);

% Defaults
if ~isfield(opts, 'user_lat_deg'), opts.user_lat_deg = linspace(-0.1, 0.1, 5).'; end
if ~isfield(opts, 'beamOrder'), opts.beamOrder = "northToSouth"; end
if ~isfield(opts, 'alpha_th_deg'), opts.alpha_th_deg = 10.0; end
if ~isfield(opts, 'beta0_deg'), opts.beta0_deg = 24.5; end
if ~isfield(opts, 'betaEllipse_deg'), opts.betaEllipse_deg = 1.56; end
if ~isfield(opts, 'theta_max_deg'), opts.theta_max_deg = 10.0; end
if ~isfield(opts, 'Nellipse'), opts.Nellipse = 16; end
if ~isfield(opts, 'epfd_thr_dB'), opts.epfd_thr_dB = -173.4; end
if ~isfield(opts, 'BWref_Hz'), opts.BWref_Hz = 1e6; end
if ~isfield(opts, 'leo_psd_dBW_per_4kHz'), opts.leo_psd_dBW_per_4kHz = -13.4; end
if ~isfield(opts, 'gs_diameter_m'), opts.gs_diameter_m = 0.6; end
if ~isfield(opts, 'freq_GHz'), opts.freq_GHz = 12.7; end
if ~isfield(opts, 'rx_pattern'), opts.rx_pattern = "rec465"; end

user_lat_deg = opts.user_lat_deg(:);
beamOrder = string(opts.beamOrder);
alpha_th_deg = double(opts.alpha_th_deg);
beta0_deg = double(opts.beta0_deg);
betaEllipse_deg = double(opts.betaEllipse_deg);
theta_max_deg = double(opts.theta_max_deg);
Nellipse = double(opts.Nellipse);

epfd_thr_dB = double(opts.epfd_thr_dB);
BWref_Hz = double(opts.BWref_Hz);
leo_psd_dBW_per_4kHz = double(opts.leo_psd_dBW_per_4kHz);
gs_diameter_m = double(opts.gs_diameter_m);
freq_GHz = double(opts.freq_GHz);
rx_pattern = lower(string(opts.rx_pattern));
lambda_m = 3e8/(freq_GHz*1e9);

% Convert PSD -> EIRP in BWref
EIRP_ref_dBW = leo_psd_dBW_per_4kHz + 10*log10(BWref_Hz/4000);
EIRP_ref_W = 10^(EIRP_ref_dBW/10);

% Earth + GEO radii (km)
RE_km = 6378.137;
RG_km = 42164;

% Time axis
t_start_dt = datetime(t_start, 'InputFormat', 'dd MMM yyyy HH:mm:ss');
t_end_dt = datetime(t_end, 'InputFormat', 'dd MMM yyyy HH:mm:ss');
N_time = floor(seconds(t_end_dt - t_start_dt)/dt_sec) + 1;

leo_latitudes = nan(N_time,1);
user_satisfaction = nan(N_time,1); % [%], 0..100 in steps of 20 for 5 users
Noff_vec = nan(N_time,1);
thetaSigned_vec = nan(N_time,1);

% Preload STK objects/providers
satObj = root.GetObjectFromPath(['*/Satellite/' char(target_sat)]);
dpSatPos = satObj.DataProviders.Item('Cartesian Position').Group.Item('Fixed');
dpSatLLA = satObj.DataProviders.Item('LLA State').Group.Item('Fixed');

geoObj = root.GetObjectFromPath(['*/Satellite/' char(geoName)]);
dpGeoPos = geoObj.DataProviders.Item('Cartesian Position').Group.Item('Fixed');

gsObj = root.GetObjectFromPath(['*/Facility/GSO_GS_' char(geoName)]);
res = gsObj.DataProviders.Item('Cartesian Position').Exec;
P_gs = stkGetXYZ_FromArray(res.DataSets.ToArray); % km, fixed
phiES = facility_lat_deg(gsObj, P_gs);

% Cache progressive pitch param vs phiS for speed
pp_cache = containers.Map('KeyType','char','ValueType','any');

fprintf('\n=== Figure14-like (pitch1 baseline) ===\n');
fprintf('Target=%s | GEO=%s | GS lat=%.2f deg | t=[%s..%s], dt=%ds\n', ...
    target_sat, geoName, phiES, t_start, t_end, dt_sec);
fprintf('metric=EPFD | thr=%.1f dB | EIRPref=%.2f dBW | users=%d\n', ...
    epfd_thr_dB, EIRP_ref_dBW, numel(user_lat_deg));

for i = 1:N_time
    t_current_dt = t_start_dt + seconds((i-1)*dt_sec);
    tStr = datestr(t_current_dt, 'dd mmm yyyy HH:MM:SS');
    root.ExecuteCommand(['Animate * SetTime "' tStr '"']);

    % Positions
    P_leo = stkGetXYZ_ExecSingle(dpSatPos, tStr);      % km
    phiS = stkGetLat_ExecSingle(dpSatLLA, tStr);       % deg
    leo_latitudes(i) = phiS;

    P_geo = stkGetXYZ_ExecSingle(dpGeoPos, tStr);      % km

    % Motion direction for tilt sign
    tStr2 = datestr(t_current_dt + seconds(1), 'dd mmm yyyy HH:MM:SS');
    phiS2 = stkGetLat_ExecSingle(dpSatLLA, tStr2);
    dphi = phiS2 - phiS;

    % Progressive pitch NOFF + thetaAbs (thetaAbs uses breakpoint approx; NOFF uses Ren 2021 numeric phi_th1)
    key = sprintf('%.3f', round(phiS, 3));
    if isKey(pp_cache, key)
        v = pp_cache(key);
        thetaAbs = v.thetaAbs;
        Noff = v.Noff;
    else
        thetaAbs = thetaAbs_breakpoint(phiS, theta_max_deg);
        Noff = Noff_ren2021(phiS, alpha_th_deg, norm(P_leo), RG_km, RE_km, beta0_deg, betaEllipse_deg, theta_max_deg, Nellipse);
        pp_cache(key) = struct('thetaAbs', thetaAbs, 'Noff', Noff);
    end
    thetaSigned = signedThetaFromMotion(phiS, dphi, thetaAbs);
    Noff_vec(i) = Noff;
    thetaSigned_vec(i) = thetaSigned;

    % Discrimination angle at GS (for rx gain)
    vLEO = P_leo - P_gs;  % GS->LEO
    vGEO = P_geo - P_gs;  % GS->GEO
    alpha_deg = angleDeg(vLEO, vGEO);

    % Force-off beams away from equator
    forceOff = false(1, Nellipse);
    if Noff > 0
        Noff_eff = min(Nellipse, max(0, round(Noff)));
        if beamOrder == "southToNorth"
            if phiS >= 0
                forceOff((Nellipse - Noff_eff + 1):Nellipse) = true;
            else
                forceOff(1:Noff_eff) = true;
            end
        else
            if phiS >= 0
                forceOff(1:Noff_eff) = true;
            else
                forceOff((Nellipse - Noff_eff + 1):Nellipse) = true;
            end
        end
    end

    % Beam ON/OFF and user served
    beamOn = false(1, Nellipse);
    phiB1_all = nan(1, Nellipse);
    phiB2_all = nan(1, Nellipse);

    RS_km = norm(P_leo);
    for b = 1:Nellipse
        bp = Nellipse - b + 1;
        beta_b = beta0_deg - (2*bp - 1)*betaEllipse_deg;

        psi_upper = deg2rad(beta_b - thetaSigned);
        psi_lower = deg2rad(beta0_deg + thetaSigned);

        delta_upper = rad2deg(acos(g_func(psi_upper, RE_km, RS_km)));
        delta_lower = rad2deg(acos(g_func(psi_lower, RE_km, RS_km)));

        phiB1 = phiS + delta_upper;
        phiB2 = phiS - delta_lower;
        phiB1_all(b) = phiB1;
        phiB2_all(b) = phiB2;

        inCov = (phiES >= phiB2) && (phiES <= phiB1);
        violate = false;
        if inCov
            d_m = norm((P_leo - P_gs)) * 1000;
            Gr_dBi = rx_gain(rx_pattern, alpha_deg, gs_diameter_m, lambda_m);
            Gmax_dBi = 20*log10(gs_diameter_m/lambda_m) + 7.7;
            Gr_rel_lin = 10^((Gr_dBi - Gmax_dBi)/10);

            epfd_lin = (EIRP_ref_W / (4*pi*d_m^2)) * Gr_rel_lin;
            epfd_dB = 10*log10(max(epfd_lin, 1e-300));
            violate = epfd_dB > epfd_thr_dB;
        end

        beamOn(b) = ~(forceOff(b) || violate);
    end

    served = false(numel(user_lat_deg), 1);
    for u = 1:numel(user_lat_deg)
        lat_u = user_lat_deg(u);
        served(u) = any(beamOn & (lat_u >= phiB2_all) & (lat_u <= phiB1_all));
    end
    user_satisfaction(i) = sum(served) / max(numel(served), 1) * 100;
end

% Filter to [-1.5, 1.5] and sort by latitude (like Figure 14 style)
valid = isfinite(leo_latitudes) & isfinite(user_satisfaction);
lat = leo_latitudes(valid);
sat = user_satisfaction(valid);
Noff_v = Noff_vec(valid);
theta_v = thetaSigned_vec(valid);

inRange = lat >= -1.5 & lat <= 1.5;
lat = lat(inRange);
sat = sat(inRange);
Noff_v = Noff_v(inRange);
theta_v = theta_v(inRange);

[lat_s, idx] = sort(lat);
sat_s = sat(idx);

figure('Name','Figure14-like: pitch1 baseline');
plot(lat_s, sat_s, 'LineWidth', 1.8);
grid on;
xlabel('LEO Satellite Latitude \phi_S (deg)');
ylabel('User Satisfaction (%)');
ylim([0 105]);
title(sprintf('Baseline (progressive pitch + EPFD shutoff) | %s over GS(%s)', target_sat, geoName));

T = table(lat, sat, Noff_v, theta_v, 'VariableNames', {'phiS_deg','user_satisfaction_pct','Noff','thetaSigned_deg'});

out = struct();
out.phiS_deg = lat_s;
out.user_satisfaction_pct = sat_s;
out.table = T;
out.raw = table(leo_latitudes, user_satisfaction, Noff_vec, thetaSigned_vec, 'VariableNames', ...
    {'phiS_deg','user_satisfaction_pct','Noff','thetaSigned_deg'});

% ---- Save figure + data (Matlab_data) ----
matlab_data_dir = fullfile(pwd, 'Matlab_data');
if ~exist(matlab_data_dir, 'dir')
    mkdir(matlab_data_dir);
end

safeName = @(s) regexprep(char(s), '[^\w]+', '_');
pngName = sprintf('Figure14_Pitch1_Baseline_%s_over_%s.png', safeName(target_sat), safeName(geoName));
matName = sprintf('Figure14_Pitch1_Baseline_%s_over_%s.mat', safeName(target_sat), safeName(geoName));

figure_path = fullfile(matlab_data_dir, pngName);
saveas(gcf, figure_path);
fprintf('  ✓ Baseline figure saved: %s\n', figure_path);

data_path = fullfile(matlab_data_dir, matName);
save(data_path, 'leo_latitudes', 'user_satisfaction', 'Noff_vec', 'thetaSigned_vec', ...
    't_start', 't_end', 'dt_sec', 'target_sat', 'geoName', 'user_lat_deg', ...
    'epfd_thr_dB', 'BWref_Hz', 'leo_psd_dBW_per_4kHz', 'gs_diameter_m', 'freq_GHz', 'rx_pattern');
fprintf('  ✓ Baseline data saved: %s\n', data_path);
end

% ---------------- helpers ----------------
function thetaAbs = thetaAbs_breakpoint(phiS_deg, theta_max_deg)
% Keep consistent with earlier baseline: ramp then clamp
aphi = abs(phiS_deg);
if aphi >= 30
    thetaAbs = 0;
elseif aphi > 21.96
    thetaAbs = theta_max_deg * (30 - aphi) / (30 - 21.96);
    thetaAbs = max(0, min(theta_max_deg, thetaAbs));
else
    thetaAbs = theta_max_deg;
end
end

function Noff = Noff_ren2021(phiS_deg, alpha_th_deg, RS_km, RG_km, RE_km, beta0_deg, betaEllipse_deg, theta_max_deg, Nellipse)
phi_th1 = solve_phi_th1_numeric(phiS_deg, alpha_th_deg, RS_km, RG_km, RE_km);
delta = deg2rad(phi_th1 - phiS_deg);
c = (RE_km * sin(delta)) / max(RS_km - RE_km * cos(delta), 1e-9);
atan_c_deg = rad2deg(atan(c));
thetaStar = min(theta_max_deg, beta0_deg - atan_c_deg);
if thetaStar < theta_max_deg - 1e-6
    Noff = 0;
else
    Noff = ceil((beta0_deg - thetaStar - atan_c_deg) / (2 * betaEllipse_deg));
    Noff = max(0, min(Nellipse, Noff));
end
end

function phi_th1 = solve_phi_th1_numeric(phiS_deg, alpha_th_deg, RS_km, RG_km, RE_km)
Ax = RS_km * cosd(phiS_deg);
Ay = RS_km * sind(phiS_deg);
Bx = RG_km; By = 0;
f = @(phi) angle_at_station_deg(phi, Ax, Ay, Bx, By, RE_km) - alpha_th_deg;
grid = linspace(-89.9, 89.9, 721);
vals = arrayfun(f, grid);
sgn = sign(vals);
idx = find(sgn(1:end-1) == 0 | sgn(1:end-1).*sgn(2:end) < 0);
if isempty(idx)
    [~, imax] = min(abs(vals));
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
cc = dot(vA, vB) / (norm(vA)*norm(vB) + eps);
cc = min(1, max(-1, cc));
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

function lat = facility_lat_deg(gsObj, P_gs_km)
lat = NaN;
try
    res = gsObj.DataProviders.Item('LLA State').Exec;
    arr = res.DataSets.ToArray;
    lat = stkGetLat_FromArray(arr);
catch
    lat = atan2d(P_gs_km(3), sqrt(P_gs_km(1)^2 + P_gs_km(2)^2));
end
end

function a = angleDeg(v1, v2)
cc = dot(v1, v2) / (norm(v1)*norm(v2) + eps);
cc = min(1, max(-1, cc));
a = acosd(cc);
end

function val = g_func(psi_rad, RE_km, RS_km)
s = sin(psi_rad);
c = cos(psi_rad);
under = RE_km^2 - (RS_km^2)*(s.^2);
under = max(under, 0);
val = (RS_km*(s.^2) + c.*sqrt(under)) / RE_km;
val = min(1, max(-1, val));
end

function Gr_dBi = rx_gain(rx_pattern, alpha_deg, D_m, lambda_m)
switch rx_pattern
    case "itu1428"
        Gr_dBi = rx_gain_itu1428(alpha_deg, D_m, lambda_m);
    otherwise
        Gr_dBi = rx_gain_rec465_approx(alpha_deg, D_m, lambda_m);
end
end

function G_dBi = rx_gain_itu1428(phi_deg, D_m, lambda_m)
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
Gmax = 20*log10(D_m/lambda_m) + 7.7;
phi = max(0, phi_deg);
phi_r = 95*lambda_m/D_m;
G1 = 29 - 25*log10(max(phi_r, 1e-6));
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

