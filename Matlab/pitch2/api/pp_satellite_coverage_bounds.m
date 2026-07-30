function [psi_up_deg, psi_down_deg, alpha_up_deg, alpha_down_deg] = pp_satellite_coverage_bounds(P, psi_deg, chi_deg, K)
%PP_SATELLITE_COVERAGE_BOUNDS Coverage bounds in orbit plane (Eq. (7)-(10)).
%
% K: number of closed beams (integer, 0..Nbeam)

alpha_up_deg = chi_deg + (2*K - P.Nbeam) * P.mu_b_deg; % Eq. (7)
alpha_down_deg = chi_deg + P.Nbeam * P.mu_b_deg;      % Eq. (8)

psi_up_deg = pp_lat_from_elevation(P, psi_deg, alpha_up_deg);     % Eq. (9)
psi_down_deg = pp_lat_from_elevation(P, psi_deg, alpha_down_deg); % Eq. (10)
end

