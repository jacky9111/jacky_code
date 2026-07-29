function [geom, alignInfo] = align_reference_satellite_over_gs(geom, common)
% align_reference_satellite_over_gs
% Rotate the whole constellation (rigid RAAN + phase offset) so that at
% t = 0 s the reference satellite's sub-satellite point coincides with the
% ground station.
%
% With GMST(0) = 0 the ECEF longitude of a satellite at argument of latitude
% u = 0 (ascending node, on the equator) equals its RAAN. Therefore:
%   - set the reference satellite's argument of latitude to 0 at t = 0
%     (sub-latitude = 0 = GS latitude), and
%   - set its RAAN to the GS longitude (sub-longitude = GS longitude).
% Both offsets are applied rigidly to every satellite to preserve the Walker
% pattern.
%
% Inputs:
%   geom   : output of generate_constellation_geometry
%   common : cfg.common (GS lat/lon, Earth constants, alignment tolerance)
%
% Outputs:
%   geom       : same struct with adjusted RAAN_deg / u0_deg fields
%   alignInfo  : struct with applied offsets and the verification distance
%
% The verification distance between the reference sub-point and the GS is
% checked against common.alignTol_km; a warning is issued if it is exceeded.

sats = geom.sats;
ref  = sats(geom.refIndex);

% Rigid offsets that map the reference satellite onto (u = 0, RAAN = gsLon).
uOffset_deg    = -ref.u0_deg;
raanOffset_deg = common.gsLon_deg - ref.RAAN_deg;

for k = 1:numel(sats)
    sats(k).u0_deg   = mod(sats(k).u0_deg + uOffset_deg, 360);
    sats(k).RAAN_deg = mod(sats(k).RAAN_deg + raanOffset_deg, 360);
end
geom.sats = sats;

% Verify: propagate only the reference satellite at t = 0 and measure the
% great-circle distance between its sub-point and the GS.
state0 = propagate_satellites(geom, common, 0);
subLat = state0.subLat_deg(geom.refIndex, 1);
subLon = state0.subLon_deg(geom.refIndex, 1);
dist_km = great_circle_distance_km(subLat, subLon, ...
    common.gsLat_deg, common.gsLon_deg, common.Re_km);

alignInfo = struct();
alignInfo.uOffset_deg    = uOffset_deg;
alignInfo.raanOffset_deg = raanOffset_deg;
alignInfo.refSubLat_deg  = subLat;
alignInfo.refSubLon_deg  = subLon;
alignInfo.refDistToGs_km = dist_km;
alignInfo.tol_km         = common.alignTol_km;
alignInfo.withinTol      = dist_km <= common.alignTol_km;

if ~alignInfo.withinTol
    warning('align_reference_satellite_over_gs:Tolerance', ...
        ['[%s] reference sub-satellite point is %.3f km from the GS at ', ...
         't = 0 s (tolerance %.3f km). Alignment may be inaccurate.'], ...
        geom.name, dist_km, common.alignTol_km);
else
    fprintf('[%s] reference sub-point aligned over GS at t=0: dist=%.4f km (tol=%.3f km).\n', ...
        geom.name, dist_km, common.alignTol_km);
end
end

function d_km = great_circle_distance_km(lat1, lon1, lat2, lon2, Re_km)
dlat = deg2rad(lat2 - lat1);
dlon = deg2rad(lon2 - lon1);
a = sin(dlat/2)^2 + cosd(lat1) * cosd(lat2) * sin(dlon/2)^2;
d_km = Re_km * 2 * atan2(sqrt(a), sqrt(max(0, 1 - a)));
end
