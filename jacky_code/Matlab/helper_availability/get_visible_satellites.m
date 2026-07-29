function vis = get_visible_satellites(pos_ecef_km, P_gs_km, minElev_deg)
% get_visible_satellites
% Determine which satellites are visible from the ground station at one time
% slot, using the local elevation angle above the GS horizon.
%
% Inputs:
%   pos_ecef_km : 3 x nSat ECEF satellite positions at this slot [km]
%   P_gs_km     : 3 x 1 ECEF ground-station position [km]
%   minElev_deg : minimum elevation angle to be considered visible [deg]
%
% Output vis:
%   vis.mask       : 1 x nSat logical, true if visible
%   vis.idx        : indices of visible satellites
%   vis.elev_deg   : 1 x nSat elevation angle from GS [deg]
%
% Units: km, deg.

P_gs_km = P_gs_km(:);
nSat = size(pos_ecef_km, 2);
zenith = P_gs_km / max(norm(P_gs_km), eps);   % local up direction at GS

elev_deg = -90 * ones(1, nSat);
for k = 1:nSat
    v = pos_ecef_km(:, k) - P_gs_km;
    nv = norm(v);
    if nv < eps
        continue;
    end
    cosZen = max(-1, min(1, dot(v, zenith) / nv));
    elev_deg(k) = 90 - acosd(cosZen);
end

mask = elev_deg >= minElev_deg;

vis = struct();
vis.mask     = mask;
vis.idx      = find(mask);
vis.elev_deg = elev_deg;
end
