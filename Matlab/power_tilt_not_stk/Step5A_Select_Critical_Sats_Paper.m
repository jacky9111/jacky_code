function crit = Step5A_Select_Critical_Sats_Paper(ep, cfg)
% ============================================================
% Step 5-A (Paper version)
% Critical satellite selection by EPFD threshold
%
% Definition (per paper Algorithm 1):
%   Satellite i is critical if EPFD_i > EPFD_th
%
% INPUT
%   ep.epfd_i_dBWm2   [N x 1]
%   cfg.EPFD_th_dBWm2 threshold (dBW/m^2)
%
% OUTPUT
%   crit.idx          indices of critical satellites
%   crit.n            number of critical satellites
% ============================================================

assert(isfield(cfg,'EPFD_th_dBWm2'), ...
    'cfg.EPFD_th_dBWm2 must be provided');

epfd_i = ep.epfd_i_dBWm2(:);
EPFD_th = cfg.EPFD_th_dBWm2;

idx = find(epfd_i > EPFD_th);

crit = struct();
crit.idx = idx;
crit.n   = numel(idx);
crit.epfd_i_dBWm2 = epfd_i(idx);

fprintf("\n========== Step 5-A (Paper) ==========\n");
fprintf("EPFD threshold = %.2f dBW/m^2\n", EPFD_th);
fprintf("Critical satellites: %d\n", crit.n);
if crit.n > 0
    for k = 1:crit.n
        fprintf("  idx=%d | EPFD_i=%.2f dBW/m^2\n", ...
            crit.idx(k), crit.epfd_i_dBWm2(k));
    end
else
    fprintf("  None (no violation)\n");
end
fprintf("=====================================\n\n");
end
