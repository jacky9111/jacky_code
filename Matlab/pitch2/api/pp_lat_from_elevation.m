function psi_prime_deg = pp_lat_from_elevation(P, psi_sat_deg, alpha_deg)
%PP_LAT_FROM_ELEVATION Eq. (11): map elevation angle alpha -> ground latitude.
%
% psi' = psi - asin( (Re+h)/Re * sin(alpha) ) * sign(alpha)

ratio = (P.Re_km + P.h_leo_km) / P.Re_km;
arg = ratio .* sind(alpha_deg);
arg = max(min(arg, 1), -1);
psi_prime_deg = psi_sat_deg - asind(arg) .* sign(alpha_deg);
end

