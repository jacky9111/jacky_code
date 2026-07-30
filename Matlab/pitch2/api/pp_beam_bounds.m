function B = pp_beam_bounds(P, psi_deg, chi_deg, iBeam)
%PP_BEAM_BOUNDS Beam i orbit-plane coverage bounds (Eq. (13)-(14) + Eq. (11)).
%
% Returns struct with:
% - alpha_up_deg, alpha_down_deg, alpha_c_deg
% - psi_up_deg, psi_down_deg, psi_c_deg
% - width_deg

B.alpha_up_deg = chi_deg + (2*iBeam - 2 - P.Nbeam) * P.mu_b_deg; % Eq. (13)
B.alpha_down_deg = chi_deg + (2*iBeam - P.Nbeam) * P.mu_b_deg;  % Eq. (14)
B.alpha_c_deg = chi_deg + (2*iBeam - P.Nbeam - 1) * P.mu_b_deg; % text under Fig.1

B.psi_up_deg = pp_lat_from_elevation(P, psi_deg, B.alpha_up_deg);
B.psi_down_deg = pp_lat_from_elevation(P, psi_deg, B.alpha_down_deg);
B.psi_c_deg = (B.psi_up_deg + B.psi_down_deg)/2;

B.width_deg = abs(B.psi_down_deg - B.psi_up_deg);
end

