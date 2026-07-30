function gs = make_ground_station(lon_deg, lat_deg, P)
r_km = P.Re_km;
gs.pos_ecef_km = latlon_to_ecef(lat_deg, lon_deg, r_km);
gs.lon_deg = lon_deg;
gs.lat_deg = lat_deg;
end

function r = latlon_to_ecef(lat_deg, lon_deg, r_km)
lat = deg2rad(lat_deg); lon = deg2rad(lon_deg);
r = [r_km*cos(lat)*cos(lon); r_km*cos(lat)*sin(lon); r_km*sin(lat)];
end