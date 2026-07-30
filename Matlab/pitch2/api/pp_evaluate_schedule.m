function R = pp_evaluate_schedule(P, lat_asc, chi_asc, K_asc, mu_th_deg)
%PP_EVALUATE_SCHEDULE Evaluate objective + constraints on a given schedule.
%
% lat_asc: 0..90 (ascending, degrees)
% chi_asc, K_asc: same length
%
% Returns:
% - avg_capacity
% - violations (struct with counts)
% - arrays: cap_vs_lat, minmu_vs_lat, overlap_vs_lat

if ~(numel(lat_asc) == numel(chi_asc) && numel(lat_asc) == numel(K_asc))
    error('lat_asc/chi_asc/K_asc must have same length.');
end

n = numel(lat_asc);
cap = zeros(1, n);
minmu = zeros(1, n);
psi_up = zeros(1, n);
psi_down = zeros(1, n);

eval_n_x = 11;
if isfield(P, 'eval_n_x') && ~isempty(P.eval_n_x)
    eval_n_x = P.eval_n_x;
end

for k = 1:n
    out = pp_eval_at_latitude(P, lat_asc(k), chi_asc(k), K_asc(k), struct('sigma_deg', 0, 'n_x', eval_n_x));
    cap(k) = out.total_capacity;
    minmu(k) = out.min_mu_active_deg;
    psi_up(k) = out.psi_up_deg;
    psi_down(k) = out.psi_down_deg;
end

% Overlap between neighbors separated by delta (Eq. (12))
overlap = nan(1, n);
for k = 1:(n - P.Ldelta)
    overlap(k) = psi_up(k) - psi_down(k + P.Ldelta);
end

% Constraint violations
v_chi = sum(chi_asc < -1e-9 | chi_asc > (P.chi_max_deg + 1e-9));
v_K = sum(K_asc < -1e-9 | K_asc > (P.Nbeam + 1e-9) | abs(K_asc - round(K_asc)) > 1e-9);
v_overlap = sum(overlap(1:(n-P.Ldelta)) < (P.overlap_e_deg - 1e-9));
v_mu = sum(minmu < (mu_th_deg - 1e-9));

R.avg_capacity = mean(cap);
R.cap_vs_lat = cap;
R.minmu_vs_lat = minmu;
R.overlap_vs_lat = overlap;

R.psi_up_vs_lat = psi_up;
R.psi_down_vs_lat = psi_down;

R.violations.chi = v_chi;
R.violations.K = v_K;
R.violations.overlap = v_overlap;
R.violations.mu = v_mu;
R.violations.total = v_chi + v_K + v_overlap + v_mu;
end

