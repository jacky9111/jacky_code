function [mu_deg, nu_deg] = pp_offaxis_angles_inline(P, psi_deg, chi_deg, iBeam, sigma_deg)
%PP_OFFAXIS_ANGLES_INLINE Compute (mu_i, nu_i) per Appendix B (A5-A11).
%
% Inputs:
% - psi_deg: NGSO satellite latitude (deg), northern hemisphere assumed (>=0)
% - chi_deg: pitch angle (deg)
% - iBeam: beam index in {1..Nbeam}
% - sigma_deg: longitude difference between GSO satellite and NGSO satellite (deg)
%
% Outputs:
% - mu_deg: off-axis angle in minor axis direction (deg)
% - nu_deg: off-axis angle in major axis direction (deg)

% Beam boresight elevation angle alpha_i (Eq. under Figure 2)
alpha_i_deg = chi_deg - (P.Nbeam - 2*iBeam + 1) * P.mu_b_deg;

% Satellite positions in Earth rectangular coordinate system (Appendix B)
Rn = P.Rn_km;
Rg = P.Rg_km;

rn = [0; Rn*cosd(psi_deg); Rn*sind(psi_deg)];
rg = [Rg*sind(sigma_deg); Rg*cosd(sigma_deg); 0];

n_GL = (rg - rn);
n_GL = n_GL ./ norm(n_GL);

% Conversion matrix from beam rectangular coordinates to earth coordinates (A10)
t = psi_deg - alpha_i_deg;
R = [ 0, -sind(t),  cosd(t);
     -1,      0,       0;
      0, -cosd(t), -sind(t)];

% Unit vector in beam coordinate system (A11)
n_LD = R * n_GL;
x = n_LD(1); y = n_LD(2); z = n_LD(3);

den_mu = max(sqrt(x^2 + z^2), eps);
den_nu = max(sqrt(y^2 + z^2), eps);
mu_deg = sign(x) * acosd( max(min(x / den_mu, 1), -1) );
nu_deg = sign(y) * acosd( max(min(y / den_nu, 1), -1) );
end

