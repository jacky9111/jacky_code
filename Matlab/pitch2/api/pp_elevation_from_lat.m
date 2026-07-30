function alpha_deg = pp_elevation_from_lat(P, psi_sat_deg, psi_ground_deg)
%PP_ELEVATION_FROM_LAT Inverse of Eq. (11) (used for capacity evaluation).
%
% From Eq. (11):
%   psi_ground = psi_sat - asin( (Re+h)/Re * sin(alpha) ) * sign(alpha)
% Let d = psi_sat - psi_ground (deg, signed). Then:
%   |d| = asin( (Re+h)/Re * sin(|alpha|) )
% => sin(|alpha|) = (Re/(Re+h)) * sin(|d|)

d = psi_sat_deg - psi_ground_deg;
ratio = P.Re_km / (P.Re_km + P.h_leo_km);
arg = ratio .* sind(abs(d));
arg = max(min(arg, 1), -1);
alpha_deg = sign(d) .* asind(arg);
end

