function beam = calibrate_beam_for_half_orbit_overlap(common, refConstellation, beam)
% calibrate_beam_for_half_orbit_overlap
% Resize the shared rectangular 16-beam fan so that, under THIS module's
% MATLAB spherical-Earth + ray/Earth footprint model and the OneWeb-like
% reference geometry, same-orbit ±1 neighbours produce exact half N/S
% coverage of the middle satellite:
%   the middle sub-satellite point lies on each neighbour's footprint edge
%   (neighbour footprints meet at the middle SSP — N/S halves).
%
% EW is scaled with NS to keep the thesis -5 dB aspect ratio
% (34.0 : 33.5). The calibrated half-angles are then reused for every
% constellation geometry (Starlink-like / Lightspeed-like included).

aspectEW = beam.halfEW_ref_deg;
aspectNS = beam.halfNS_total_ref_deg;
Nbeam = beam.Nbeam;

geom = generate_constellation_geometry(refConstellation, common);
[geom, ~] = align_reference_satellite_over_gs(geom, common);
state = propagate_satellites(geom, common, 0);

iRef = geom.refIndex;
plane = geom.sats(iRef).plane;
shell = geom.sats(iRef).shell;
idx = geom.sats(iRef).idxInPlane;
nS = refConstellation.shells{shell}.satellites_per_plane;

iNext = 0;
iPrev = 0;
for i = 1:geom.nSat
    if geom.sats(i).shell ~= shell || geom.sats(i).plane ~= plane
        continue;
    end
    if geom.sats(i).idxInPlane == mod(idx, nS) + 1
        iNext = i;
    end
    if geom.sats(i).idxInPlane == mod(idx - 2, nS) + 1
        iPrev = i;
    end
end
if iNext == 0 || iPrev == 0
    error('calibrate_beam_for_half_orbit_overlap: in-plane neighbours not found.');
end

spacing_km = great_circle_km( ...
    state.subLat_deg(iRef), state.subLon_deg(iRef), ...
    state.subLat_deg(iNext), state.subLon_deg(iNext), common.Re_km);

cLat = state.subLat_deg(iRef);
cLon = state.subLon_deg(iRef);
posN = state.pos_ecef_km(:, iNext);
velN = state.vel_ecef_kmps(:, iNext);
posS = state.pos_ecef_km(:, iPrev);
velS = state.vel_ecef_kmps(:, iPrev);
nLat = state.subLat_deg(iNext);
nLon = state.subLon_deg(iNext);
sLat = state.subLat_deg(iPrev);
sLon = state.subLon_deg(iPrev);

% Binary search: middle SSP just inside BOTH neighbour footprints.
lo = 15;
hi = 45;
nIter = 30;
for it = 1:nIter
    mid = 0.5 * (lo + hi);
    trial = pack_beam(beam, mid, aspectEW, aspectNS, Nbeam);
    fpN = generate_beam_footprints(posN, velN, trial, common.Re_km);
    fpS = generate_beam_footprints(posS, velS, trial, common.Re_km);
    inN = point_in_sat_footprints(cLat, cLon, fpN, nLat, nLon, common.Re_km);
    inS = point_in_sat_footprints(cLat, cLon, fpS, sLat, sLon, common.Re_km);
    if inN && inS
        hi = mid;   % still covered by both -> shrink toward boundary
    else
        lo = mid;   % missing at least one -> grow
    end
end

beam = pack_beam(beam, hi, aspectEW, aspectNS, Nbeam);
fpN = generate_beam_footprints(posN, velN, beam, common.Re_km);
fpS = generate_beam_footprints(posS, velS, beam, common.Re_km);
fpC = generate_beam_footprints(state.pos_ecef_km(:, iRef), ...
    state.vel_ecef_kmps(:, iRef), beam, common.Re_km);
inN = point_in_sat_footprints(cLat, cLon, fpN, nLat, nLon, common.Re_km);
inS = point_in_sat_footprints(cLat, cLon, fpS, sLat, sLon, common.Re_km);
inC_fromN = point_in_sat_footprints(nLat, nLon, fpC, cLat, cLon, common.Re_km);
inC_fromS = point_in_sat_footprints(sLat, sLon, fpC, cLat, cLon, common.Re_km);

beam.halfOverlapCalib = struct( ...
    'refConstellation', string(refConstellation.name), ...
    'spacing_km', spacing_km, ...
    'centerInNorthFP', inN, ...
    'centerInSouthFP', inS, ...
    'northInCenterFP', inC_fromN, ...
    'southInCenterFP', inC_fromS, ...
    'halfNS_total_deg', beam.halfNS_total_deg, ...
    'halfEW_deg', beam.halfEW_deg, ...
    'halfNS_total_ref_deg', aspectNS, ...
    'halfEW_ref_deg', aspectEW);

fprintf(['[beam calib] %s half-overlap: spacing=%.2f km | ', ...
    'center in N/S FP = %d/%d | N/S SSP in center FP = %d/%d | ', ...
    'halfNS_total=%.3f deg (ref %.1f), halfEW=%.3f deg (ref %.1f)\n'], ...
    refConstellation.name, spacing_km, inN, inS, inC_fromN, inC_fromS, ...
    beam.halfNS_total_deg, aspectNS, beam.halfEW_deg, aspectEW);
end

% ----------------------------------------------------------------------
function beam = pack_beam(beam, halfNS_total, aspectEW, aspectNS, Nbeam)
beam.halfNS_total_deg = halfNS_total;
beam.halfNS_deg = halfNS_total / Nbeam;
beam.halfEW_deg = halfNS_total * (aspectEW / aspectNS);
beam.pitchOffsets_deg = (8.5 - (1:Nbeam)) * (2 * beam.halfNS_deg);
end

function tf = point_in_sat_footprints(lat, lon, fp, originLat, originLon, Re_km)
[e0, n0] = latlon_to_enu_km(lat, lon, originLat, originLon, Re_km);
for b = 1:numel(fp)
    if ~fp(b).valid || numel(fp(b).polyLat) < 3
        continue;
    end
    [e, n] = latlon_to_enu_km(fp(b).polyLat, fp(b).polyLon, originLat, originLon, Re_km);
    if inpolygon(e0, n0, e, n)
        tf = true;
        return;
    end
end
tf = false;
end

function [e, n] = latlon_to_enu_km(lat, lon, lat0, lon0, Re_km)
dLat = deg2rad(lat - lat0);
dLon = deg2rad(wrap180(lon - lon0));
n = Re_km * dLat;
e = Re_km * cosd(lat0) * dLon;
end

function km = great_circle_km(lat1, lon1, lat2, lon2, Re_km)
a = sind((lat2 - lat1) / 2)^2 + cosd(lat1) * cosd(lat2) * sind((lon2 - lon1) / 2)^2;
km = Re_km * 2 * asin(min(1, sqrt(a)));
end

function x = wrap180(x)
x = mod(x + 180, 360) - 180;
end
