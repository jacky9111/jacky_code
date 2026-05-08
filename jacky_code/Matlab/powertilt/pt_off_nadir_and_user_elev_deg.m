function [off_deg, elev_u_deg] = pt_off_nadir_and_user_elev_deg(r_sat_km, r_user_km)
v_nadir = -r_sat_km;
v_su = r_user_km - r_sat_km; % sat->user
off_deg = pt_angle_deg(v_nadir, v_su);

v_us = r_sat_km - r_user_km; % user->sat
zenith_u = r_user_km / norm(r_user_km);
ang = acosd( max(-1, min(1, dot(v_us, zenith_u) / (norm(v_us)*norm(zenith_u))) ) );
elev_u_deg = 90 - ang;
end
