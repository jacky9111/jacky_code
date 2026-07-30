%% =========================================================
% Joint Power & Tilt Control (NO STK)
% Faithful replication of paper (OJVT 2023)
% =========================================================
%% 初始化
addpath(fullfile(pwd, 'Matlab', 'power_tilt_not_stk'));

%% ===================== Step 0: Parameters (Table 1) =====================
P = paper_params();

%% ===================== Step 1: Build Walker-star constellation =====================
t0 = 0;  % snapshot time
LEO = build_walker_star(P, t0);

disp("Step 1 done: Walker constellation built");

%% ===================== Step 2: GSO satellite & ground station =====================
gso = make_gso(P.gso_lon_deg, P.gso_lat_deg, P);
gs  = make_ground_station(P.gso_lon_deg, 0.0, P);  % equator case

disp("Step 2 done: GSO & GS defined");

%% ===================== Step 3: Visible LEO satellites =====================
[visIdx, geom] = visible_leo_to_gs(LEO, gs, P.min_elev_deg);
fprintf("Visible LEO satellites = %d\n", numel(visIdx));

disp("Step 3 done: visibility computed");

%% ===================== Step 4: EPFD geometry precomputation =====================
E = precompute_epfd_terms(LEO, visIdx, gs, gso, P);

N = numel(E.gamma_base);

q_test     = log(ones(N,1));   % 1 W per satellite
theta_test = zeros(N,1);       % no tilt

EPFD_test_lin = sum( E.gamma_base .* exp(q_test + P.beta_fit*theta_test) );
EPFD_test_dB  = 10*log10(EPFD_test_lin);

fprintf('EPFD sanity (1 W, no tilt) = %.2f dB\n', EPFD_test_dB);
fprintf('EPFD threshold            = %.2f dB\n', P.EPFD_thr_dB);

disp("Step 4 done: EPFD terms ready");

%% ===================== Step 5: Generate users & demands =====================
U = 5;                 % paper: 5 users per satellite
users = make_users_for_visible_sats(LEO, visIdx, gs, U, P);

demand_min = 4e9;      % 4 Gbps (paper range: 4-6 Gbps)
demand_max = 6e9;      % 6 Gbps
demands = demand_min + (demand_max-demand_min)*rand(size(users.lat_deg));
demands = reshape(demands, U, []);  % [U x N] matrix

fprintf('Generated %d users (%d per satellite)\n', numel(users.lat_deg), U);
fprintf('Demand range: [%.2f, %.2f] Gbps\n', demand_min/1e9, demand_max/1e9);

disp("Step 5 done: users & demands generated");

%% ===================== Step 6: Capacity constants =====================
Kc = precompute_capacity_constants(LEO, visIdx, users, gs, gso, P);

fprintf('Capacity constants: k[%dx%d], v[%dx%d], s[%dx%d]\n', ...
    size(Kc.k,1), size(Kc.k,2), size(Kc.v,1), size(Kc.v,2), ...
    size(Kc.s,1), size(Kc.s,2));

disp("Step 6 done: capacity constants ready");

%% ===================== Step 7: Solve Problem (16) =====================
% Problem (16): Joint power and tilt control for ALL visible satellites
fprintf('\n--- Solving Problem (16): All satellites can tilt ---\n');
cvx_clear
sol16 = solve_problem_16(E, Kc, demands, P);

fprintf('\n[Problem 16 Results]\n');
fprintf('  Power range: [%.4f, %.4f] W\n', min(sol16.Pi), max(sol16.Pi));
fprintf('  EPFD: %.2f dB (threshold: %.2f dB)\n', sol16.EPFD_dB, P.EPFD_thr_dB);
fprintf('  Tilted satellites: %d / %d\n', sol16.num_tilted, N);
fprintf('  Avg demand satisfaction: %.2f%%\n', sol16.avg_sat_demand_satisfaction);

disp("Step 7 done: Problem (16) solved");  

%% ===================== Step 8: Solve Problem (18) =====================
% Problem (18): Joint power and tilt control, but ONLY critical satellites can tilt
fprintf('\n--- Solving Problem (18): Only critical satellites can tilt ---\n');
sol18 = solve_problem_18(E, Kc, demands, P);

fprintf('\n[Problem 18 Results]\n');
fprintf('  Power range: [%.4f, %.4f] W\n', min(sol18.Pi), max(sol18.Pi));
fprintf('  EPFD: %.2f dB (threshold: %.2f dB)\n', sol18.EPFD_dB, P.EPFD_thr_dB);
fprintf('  Critical satellites: %d / %d\n', numel(sol18.critIdx), N);
fprintf('  Tilted satellites: %d / %d\n', sol18.num_tilted, N);
fprintf('  Avg demand satisfaction: %.2f%%\n', sol18.avg_sat_demand_satisfaction);
fprintf('  CVX status: %s\n', sol18.cvx_status);

disp("Step 8 done: Problem (18) solved");

%% ===================== Step 9: Compare Results =====================
fprintf('\n========================================\n');
fprintf('=== COMPARISON: Problem (16) vs (18) ===\n');
fprintf('========================================\n');
fprintf('Metric                    | Problem (16) | Problem (18) | Difference\n');
fprintf('--------------------------|--------------|--------------|------------\n');
fprintf('Demand Satisfaction (%%)   | %11.2f  | %11.2f  | %+8.2f\n', ...
    sol16.avg_sat_demand_satisfaction, sol18.avg_sat_demand_satisfaction, ...
    sol18.avg_sat_demand_satisfaction - sol16.avg_sat_demand_satisfaction);
fprintf('EPFD (dB)                 | %11.2f  | %11.2f  | %+8.2f\n', ...
    sol16.EPFD_dB, sol18.EPFD_dB, sol18.EPFD_dB - sol16.EPFD_dB);
fprintf('Tilted Satellites        | %11d  | %11d  | %+8d\n', ...
    sol16.num_tilted, sol18.num_tilted, sol18.num_tilted - sol16.num_tilted);
fprintf('Avg Power (W)            | %11.4f  | %11.4f  | %+8.4f\n', ...
    mean(sol16.Pi), mean(sol18.Pi), mean(sol18.Pi) - mean(sol16.Pi));
fprintf('Max Power (W)            | %11.4f  | %11.4f  | %+8.4f\n', ...
    max(sol16.Pi), max(sol18.Pi), max(sol18.Pi) - max(sol16.Pi));
fprintf('========================================\n');

% Additional analysis: EPFD constraint satisfaction
fprintf('\n[EPFD Constraint Check]\n');
fprintf('  Threshold: %.2f dB(W/m^2/1MHz)\n', P.EPFD_thr_dB);
fprintf('  Problem (16) EPFD: %.2f dB (%.2f dB below threshold)\n', ...
    sol16.EPFD_dB, P.EPFD_thr_dB - sol16.EPFD_dB);
fprintf('  Problem (18) EPFD: %.2f dB (%.2f dB below threshold)\n', ...
    sol18.EPFD_dB, P.EPFD_thr_dB - sol18.EPFD_dB);

if sol16.EPFD_dB > P.EPFD_thr_dB
    warning('Problem (16) violates EPFD constraint!');
end
if sol18.EPFD_dB > P.EPFD_thr_dB
    warning('Problem (18) violates EPFD constraint!');
end

disp("Step 9 done: Comparison completed");

fprintf('\n=== All steps completed successfully! ===\n');

