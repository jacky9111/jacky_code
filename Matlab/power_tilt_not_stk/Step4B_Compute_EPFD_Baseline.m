function ep = Step4B_Compute_EPFD_Baseline(geom, ant, cfg)
% ============================================================
% Step 4-B (Baseline EPFD, no tilt / no power control)
%
% We compute per-satellite EPFD contribution at the victim GS using
% an ITU-style "equivalent" weighting by GS antenna discrimination:
%
%   EPFD_i = ( P_i * Gt_i / (4*pi*d_i^2) ) * ( Gr_max / Gr_i )
%
% where
%   P_i     : LEO transmit power toward its served user (W) [baseline: same]
%   Gt_i    : LEO Tx gain toward GS direction (linear)  -> from ant.Gt_leo_dBi
%   d_i     : sat->GS distance (m)                      -> from geom.d_gs_m
%   Gr_i    : GS Rx gain toward sat direction (linear)  -> from ant.Gr_gs_dBi
%   Gr_max  : GS max Rx gain (linear)                   -> from ant.Gr_gs_max_dBi
%
% OUTPUT:
%   ep.epfd_i_dBWm2    [N x 1]  per-sat EPFD contribution
%   ep.epfd_tot_dBWm2  scalar   total EPFD (sum in linear, then dB)
%   ep.rank            table-like struct for top contributors
%
% NOTE:
% - This is the "baseline" to verify your chain is correct before
%   you implement Algorithm 1 + joint power/tilt optimization.
% ============================================================

arguments
    geom struct
    ant struct
    cfg struct
end

% ---- defaults ----
if ~isfield(cfg,'Ptx_dBW'), cfg.Ptx_dBW = 10; end      % baseline per-sat Tx power (dBW)
if ~isfield(cfg,'do_plot'), cfg.do_plot = true; end
if ~isfield(cfg,'topK'), cfg.topK = 10; end
if ~isfield(cfg,'epfd_th_dBWm2'), cfg.epfd_th_dBWm2 = []; end % optional

N = geom.N;

% ---- check inputs ----
assert(numel(geom.d_gs_m)==N, "geom.d_gs_m size mismatch");
assert(numel(ant.Gt_leo_dBi)==N, "ant.Gt_leo_dBi size mismatch");
assert(numel(ant.Gr_gs_dBi)==N,  "ant.Gr_gs_dBi size mismatch");

% ---- convert to linear ----
P_W       = 10.^((cfg.Ptx_dBW)/10);              % W
Gt_lin    = 10.^(ant.Gt_leo_dBi(:)/10);
Gr_lin    = 10.^(ant.Gr_gs_dBi(:)/10);
Grmax_lin = 10.^((ant.Gr_gs_max_dBi)/10);

d = geom.d_gs_m(:);

% ---- guard: avoid division by ~0 (should not happen) ----
Gr_lin = max(Gr_lin, 1e-12);

% ---- EPFD per satellite (W/m^2) ----
epfd_i_Wm2 = (P_W .* Gt_lin) ./ (4*pi*(d.^2)) .* (Grmax_lin ./ Gr_lin);

% ---- total EPFD (sum linear) ----
epfd_tot_Wm2 = sum(epfd_i_Wm2);
epfd_i_dBWm2 = 10*log10(epfd_i_Wm2);
epfd_tot_dBWm2 = 10*log10(epfd_tot_Wm2);

% ---- rank contributors ----
[~, idxSort] = sort(epfd_i_Wm2, 'descend');
K = min(cfg.topK, N);
topIdx = idxSort(1:K);

rank = struct();
rank.idx = topIdx;
rank.epfd_i_dBWm2 = epfd_i_dBWm2(topIdx);
rank.d_gs_km = d(topIdx)/1e3;
rank.el_gs_deg = geom.el_gs_deg(topIdx);
rank.phi_t_deg = geom.phi_t_deg(topIdx);
rank.phi_r_deg = geom.phi_r_deg(topIdx);

% ---- optional threshold check ----
if ~isempty(cfg.epfd_th_dBWm2)
    isViol = epfd_i_dBWm2 > cfg.epfd_th_dBWm2;
    nViol = nnz(isViol);
else
    isViol = false(N,1);
    nViol = 0;
end

% ---- outputs ----
ep = struct();
ep.Ptx_dBW = cfg.Ptx_dBW;
ep.epfd_i_Wm2 = epfd_i_Wm2;
ep.epfd_i_dBWm2 = epfd_i_dBWm2;
ep.epfd_tot_Wm2 = epfd_tot_Wm2;
ep.epfd_tot_dBWm2 = epfd_tot_dBWm2;
ep.rank = rank;
ep.isViol = isViol;
ep.nViol = nViol;

% ---- prints ----
fprintf("\n========== Step 4-B Baseline EPFD ==========\n");
fprintf("N visible sats: %d\n", N);
fprintf("Per-sat Ptx = %.2f dBW (%.2f W)\n", cfg.Ptx_dBW, P_W);
fprintf("EPFD_total = %.2f dBW/m^2\n", epfd_tot_dBWm2);
fprintf("EPFD_i (max) = %.2f dBW/m^2 at idx=%d | el=%.2f deg | phi_t=%.2f deg | phi_r=%.2f deg\n", ...
    epfd_i_dBWm2(topIdx(1)), topIdx(1), geom.el_gs_deg(topIdx(1)), geom.phi_t_deg(topIdx(1)), geom.phi_r_deg(topIdx(1)));

if ~isempty(cfg.epfd_th_dBWm2)
    fprintf("Threshold = %.2f dBW/m^2 | Violating sats: %d\n", cfg.epfd_th_dBWm2, nViol);
end
fprintf("Top-%d contributors printed in ep.rank\n\n", K);

% ---- plots ----
if cfg.do_plot
    figure; histogram(epfd_i_dBWm2, 15); grid on;
    xlabel('EPFD_i (dBW/m^2)'); ylabel('Count');
    title('Step 4-B: EPFD per-satellite contribution distribution');

    figure; plot(geom.phi_t_deg, epfd_i_dBWm2, '.'); grid on;
    xlabel('\phi_t (deg)  [GS off-axis]'); ylabel('EPFD_i (dBW/m^2)');
    title('Step 4-B: EPFD_i vs GS off-axis angle \phi_t');

    figure; plot(geom.phi_r_deg, epfd_i_dBWm2, '.'); grid on;
    xlabel('\phi_r (deg)  [Sat off-axis]'); ylabel('EPFD_i (dBW/m^2)');
    title('Step 4-B: EPFD_i vs Sat off-axis angle \phi_r');

    figure; plot(geom.el_gs_deg, epfd_i_dBWm2, '.'); grid on;
    xlabel('Elevation at GS (deg)'); ylabel('EPFD_i (dBW/m^2)');
    title('Step 4-B: EPFD_i vs elevation');

    % highlight top contributors
    figure; 
    scatter3(geom.phi_t_deg, geom.phi_r_deg, epfd_i_dBWm2, 18, 'filled'); grid on;
    xlabel('\phi_t (deg)'); ylabel('\phi_r (deg)'); zlabel('EPFD_i (dBW/m^2)');
    title('Step 4-B: EPFD_i in (\phi_t,\phi_r) space');

    % If threshold given, show violators
    if ~isempty(cfg.epfd_th_dBWm2)
        figure; hold on; grid on;
        plot(geom.phi_t_deg(~isViol), epfd_i_dBWm2(~isViol), '.', 'DisplayName','OK');
        plot(geom.phi_t_deg(isViol),  epfd_i_dBWm2(isViol),  'o', 'DisplayName','Viol');
        yline(cfg.epfd_th_dBWm2, '--', 'Threshold');
        xlabel('\phi_t (deg)'); ylabel('EPFD_i (dBW/m^2)');
        title('Step 4-B: Violators vs \phi_t');
        legend;
    end
end

end
