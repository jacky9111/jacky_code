function out = TestEpfdOneSample(root, satName, gsName, geoName, beamIdx, tStr, opts)
% TestEpfdOneSample
% Decompose one beam->one GS EPFD term at one epoch.
%
% Purpose:
% - explain why EPFD may look very low
% - print each factor in dB:
%   (Pbeam/BWref), free-space term, Gt, Gr/Gmax
% - compare two conventions:
%   A) with /BWref   => dB(W/m^2/BWref)
%   B) without /BWref => dB(W/m^2)
%
% Inputs:
%   satName: e.g. 'P01_S69'
%   gsName : facility only, e.g. 'GSO_GS_geo_16_4'
%   geoName: e.g. 'geo_16_4' (for GS discrimination angle alpha)
%   beamIdx: 1..16 (north->south numbering)
%   tStr   : 'dd mmm yyyy HH:MM:SS'
%   opts (optional):
%     .beamHalfNS_deg (default 25/16)
%     .beamHalfEW_deg (default 24.5)
%     .params (default ku_epfd_params())

if nargin < 7 || isempty(opts), opts = struct(); end
if ~isfield(opts, 'beamHalfNS_deg'), opts.beamHalfNS_deg = 25/16; end
if ~isfield(opts, 'beamHalfEW_deg'), opts.beamHalfEW_deg = 24.5; end
if ~isfield(opts, 'params') || isempty(opts.params), opts.params = ku_epfd_params(); end
P = opts.params;

% --- Read STK states ---
rSat_km = getXYZFixed(root, ['*/Satellite/' char(satName)], tStr, 'Cartesian Position');
vSat_kmps = getXYZFixed(root, ['*/Satellite/' char(satName)], tStr, 'Cartesian Velocity');
rGs_km  = getXYZNoTime(root, ['*/Facility/' char(gsName)], 'Cartesian Position');
rGeo_km = getXYZFixed(root, ['*/Satellite/' char(geoName)], tStr, 'Cartesian Position');

rSat_m = rSat_km * 1000;
vSat_mps = vSat_kmps * 1000;
vSG_m = (rGs_km - rSat_km) * 1000; % sat -> GS
d_m = norm(vSG_m);
dHat = vSG_m / max(d_m, eps);

% --- Build 16 beams and reorder north->south (same as main code) ---
pitchOffsets_deg = (8.5 - (1:16)) * (2*opts.beamHalfNS_deg);
[bAll, cAxis] = beamBoresights(rSat_m, vSat_mps, pitchOffsets_deg);
bAll = reorderBoresightsNorthToSouth(rSat_m, bAll);

if beamIdx < 1 || beamIdx > 16
    error('beamIdx must be 1..16');
end
bHat = bAll(:, beamIdx);
tAxis = cross(cAxis, bHat);
tAxis = tAxis / max(norm(tAxis), eps);

thH = atan2d(dot(dHat, cAxis), dot(dHat, bHat));
thV = atan2d(dot(dHat, tAxis), dot(dHat, bHat));
inBeam = (abs(thH) <= opts.beamHalfEW_deg) && (abs(thV) <= opts.beamHalfNS_deg);

phi_t = acosd(max(-1, min(1, dot(bHat, dHat))));
Gt_lin = max(P.A_fit * exp(P.beta_fit * phi_t), 1e-30);
Gt_dBi = 10*log10(Gt_lin);

alpha = acosd(max(-1, min(1, dot((rSat_km-rGs_km), (rGeo_km-rGs_km)) / ...
    (norm(rSat_km-rGs_km)*norm(rGeo_km-rGs_km) + eps))));
Gr_dBi = gso_rx_gain_itu1428(alpha, P.GSO_D_m, P.lambda_m);
Gmax_dBi = P.GSO_Gmax_dBi;
Gr_rel_dB = Gr_dBi - Gmax_dBi;
Gr_rel_lin = 10^(Gr_rel_dB/10);

Pbeam_W = P.Ptotal_W / 16;
Pbeam_dBW = 10*log10(Pbeam_W);
Pdens_dBW = 10*log10(Pbeam_W / P.BWref_Hz); % dBW/Hz ref-band form
fs_dB = -10*log10(4*pi*d_m^2);
Gt_max_lin = max(P.A_fit, eps);

% Convention A (current code): /BWref included
termA_lin = (Pbeam_W / P.BWref_Hz) * (Gt_lin/(4*pi*d_m^2)) * Gr_rel_lin;
termA_dB = 10*log10(max(termA_lin, 1e-300));

% Convention B: no /BWref
termB_lin = Pbeam_W * (Gt_lin/(4*pi*d_m^2)) * Gr_rel_lin;
termB_dB = 10*log10(max(termB_lin, 1e-300));

% Convention C (new default): PSD/EIRP-density driven
if isfield(P,'EIRPdens_dBW_per_4kHz')
    eirpRef_dBW = P.EIRPdens_dBW_per_4kHz + 10*log10(P.BWref_Hz/4000);
else
    eirpRef_dBW = NaN;
end
eirpRef_lin = 10^(eirpRef_dBW/10);
Gt_rel = Gt_lin / Gt_max_lin;
termC_lin = eirpRef_lin * Gt_rel * (1/(4*pi*d_m^2)) * Gr_rel_lin;
termC_dB = 10*log10(max(termC_lin, 1e-300));

out = struct();
out.input = struct('sat', string(satName), 'gs', string(gsName), 'geo', string(geoName), ...
    'beam', beamIdx, 'tStr', string(tStr));
out.geometry = struct('distance_m', d_m, 'alpha_deg', alpha, 'phi_t_deg', phi_t, ...
    'thH_deg', thH, 'thV_deg', thV, 'inBeam', inBeam);
out.gain = struct('Gt_dBi', Gt_dBi, 'Gr_dBi', Gr_dBi, 'Gmax_dBi', Gmax_dBi, 'Gr_rel_dB', Gr_rel_dB);
out.power = struct('Pbeam_W', Pbeam_W, 'Pbeam_dBW', Pbeam_dBW, 'Pbeam_over_BWref_dBW', Pdens_dBW, ...
    'BWref_Hz', P.BWref_Hz);
out.term = struct('withBWref_dB', termA_dB, 'withoutBWref_dB', termB_dB, ...
    'difference_dB', termB_dB - termA_dB, 'fs_term_dB', fs_dB, ...
    'eirpDensityDriven_dB', termC_dB);

fprintf('\n=== EPFD One-Sample Decomposition ===\n');
fprintf('sat=%s, gs=%s, geo=%s, beam=%d, t=%s\n', satName, gsName, geoName, beamIdx, tStr);
fprintf('inBeam=%d, thH=%.3f deg, thV=%.3f deg, alpha=%.3f deg, phi_t=%.3f deg\n', ...
    inBeam, thH, thV, alpha, phi_t);
fprintf('Pbeam=%.3f W (%.2f dBW), Pbeam/BWref=%.2f dBW\n', Pbeam_W, Pbeam_dBW, Pdens_dBW);
fprintf('Gt=%.2f dBi, Gr=%.2f dBi, Gr/Gmax=%.2f dB, FS term=%.2f dB\n', ...
    Gt_dBi, Gr_dBi, Gr_rel_dB, fs_dB);
fprintf('Term A (with /BWref)   = %.2f dB(W/m^2/BWref)\n', termA_dB);
fprintf('Term B (without /BWref)= %.2f dB(W/m^2)\n', termB_dB);
fprintf('B - A = %.2f dB (should be 10log10(BWref)=%.2f dB)\n', ...
    termB_dB - termA_dB, 10*log10(P.BWref_Hz));
fprintf('Term C (EIRP-density)  = %.2f dB(W/m^2/BWref), EIRPref=%.2f dBW\n', ...
    termC_dB, eirpRef_dBW);
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

function xyz = getXYZFixed(root, objPath, tStr, providerName)
obj = root.GetObjectFromPath(objPath);
dp = obj.DataProviders.Item(providerName).Group.Item('Fixed');
res = dp.ExecSingle(tStr);
xyz = parseXYZ(res.DataSets.ToArray);
end

function xyz = getXYZNoTime(root, objPath, providerName)
obj = root.GetObjectFromPath(objPath);
res = obj.DataProviders.Item(providerName).Exec;
xyz = parseXYZ(res.DataSets.ToArray);
end

function xyz = parseXYZ(arr)
if isnumeric(arr)
    v = arr(:); xyz = double(v(1:3)); return;
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
if numel(vals) < 3, error('parseXYZ failed'); end
xyz = vals(1:3);
end
