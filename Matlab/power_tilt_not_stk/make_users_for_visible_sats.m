function users = make_users_for_visible_sats(LEO, visIdx, gs, U, P)
% Paper: single beam per satellite. We sample users uniformly inside a nadir cone
% whose half-angle equals HPBW/2 (approx footprint).
%
% Output users.lat_deg and users.lon_deg as vectors of length U*Nvis,
% and mapping users.sat_k that indicates which visible-sat index it belongs to.

Nvis = numel(visIdx);
tot = U*Nvis;

lat = zeros(tot,1);
lon = zeros(tot,1);
sat_k = zeros(tot,1);

halfCone = P.hpbw_deg/2;

t = 0;
for k=1:Nvis
    i = visIdx(k);
    sat_lat = LEO.sub_lat_deg(i);
    sat_lon = LEO.sub_lon_deg(i);

    % sample random points in a cone on the sphere (approx using small-angle lat/lon)
    for u=1:U
        t = t+1;
        % random radius in [0, halfCone] with area-uniform
        r = halfCone*sqrt(rand());
        ang = 360*rand();
        dlat = r*cosd(ang);
        dlon = r*sind(ang)/max(cosd(sat_lat),1e-3);

        lat(t) = sat_lat + dlat;
        lon(t) = wrapTo180(sat_lon + dlon);
        sat_k(t) = k;
    end
end

users.lat_deg = lat;
users.lon_deg = lon;
users.sat_k = sat_k;
end