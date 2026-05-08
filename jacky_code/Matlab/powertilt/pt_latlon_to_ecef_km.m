function r = pt_latlon_to_ecef_km(lat_deg, lon_deg, Re_km)
lat = deg2rad(lat_deg);
lon = deg2rad(lon_deg);
r = [Re_km*cos(lat)*cos(lon); Re_km*cos(lat)*sin(lon); Re_km*sin(lat)];
end
