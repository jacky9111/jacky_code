function ep = Step6B_Compute_EPFD_WithTilt_Paper(geom, antCfg, Ptx_i_dBW)
% ============================================================
% Step 6-B (Paper version)
% Recompute EPFD after tilt
% ============================================================

c = 299792458;
lambda = c / antCfg.f_Hz;

% antenna diameter from beamwidth
theta3 = 2 * antCfg.leo_half3dB_deg;
D_leo = 70 * lambda / theta3;

Gt_dBi = itur_sat_pattern_dBi(geom.phi_r_deg, D_leo, lambda, "LEO");

Gt = 10.^(Gt_dBi(:)/10);
Gr = 10.^(antCfg.Gr_gs_dBi(:)/10);
Grmax = 10.^((antCfg.Gr_gs_max_dBi)/10);
d = geom.d_gs_m(:);

Ptx_W = 10.^(Ptx_i_dBW(:)/10);

epfd_i_Wm2 = (Ptx_W .* Gt) ./ (4*pi*d.^2) .* (Grmax ./ max(Gr,1e-12));

ep = struct();
ep.EPFD_total_dBWm2 = 10*log10(sum(epfd_i_Wm2));
end
