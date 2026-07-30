function ep_pc = Step5B_PowerControl_Paper(geom, ant, crit, cfg)
% ============================================================
% Step 5-B (Paper version)
% Power control applied ONLY to critical satellites
%
% INPUT
%   geom, ant : from Step 3 / 4
%   crit.idx  : critical satellite indices
%   cfg.Ptx_base_dBW
%   cfg.Ptx_crit_dBW
%
% OUTPUT
%   ep_pc.epfd_i_dBWm2
%   ep_pc.EPFD_total_dBWm2
%   ep_pc.Ptx_i_dBW
% ============================================================

N = geom.N;

Ptx_i_dBW = cfg.Ptx_base_dBW * ones(N,1);
Ptx_i_dBW(crit.idx) = cfg.Ptx_crit_dBW;

Gt = 10.^(ant.Gt_leo_dBi(:)/10);
Gr = 10.^(ant.Gr_gs_dBi(:)/10);
Grmax = 10.^((ant.Gr_gs_max_dBi)/10);
d = geom.d_gs_m(:);

Ptx_W = 10.^(Ptx_i_dBW/10);

epfd_i_Wm2 = (Ptx_W .* Gt) ./ (4*pi*d.^2) .* (Grmax ./ max(Gr,1e-12));
epfd_tot_Wm2 = sum(epfd_i_Wm2);

ep_pc = struct();
ep_pc.epfd_i_dBWm2 = 10*log10(epfd_i_Wm2);
ep_pc.EPFD_total_dBWm2 = 10*log10(epfd_tot_Wm2);
ep_pc.Ptx_i_dBW = Ptx_i_dBW;

fprintf("\n========== Step 5-B (Paper) ==========\n");
fprintf("Baseline Ptx = %.1f dBW\n", cfg.Ptx_base_dBW);
fprintf("Critical Ptx = %.1f dBW\n", cfg.Ptx_crit_dBW);
fprintf("EPFD_total   = %.2f dBW/m^2\n", ep_pc.EPFD_total_dBWm2);
fprintf("=====================================\n\n");
end
