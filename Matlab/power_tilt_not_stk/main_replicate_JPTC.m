function main_replicate_JPTC()
% Replicate: "Joint Power and Tilt Control in Satellite Constellation for NGSO-GSO Interference Mitigation"
% Faithful assumptions: single-beam per satellite, Walker-star 36x49, Ka 19.7GHz, EPFD-down constraint.
%
% Requires: CVX (http://cvxr.com/cvx/)
%
% Author: (generated) - you can integrate into your STK workflow later.

clc; close all;

%% ===================== 0) Parameters (Table 1) =====================
P = paper_params();

% Monte Carlo (Fig.10 style)
MC_iters = 200;   % paper uses up to 1000; start with 200 to verify pipeline
rng(7);

%% ===================== 1) Build constellation snapshot =====================
% We create a Walker-star like constellation (36 planes x 49 sats)
% Paper does not fully specify Walker phasing; we use evenly-spaced RAAN & mean anomaly.

t0 = 0; % seconds since epoch (snapshot)

LEO = build_walker_star(P, t0);

%% ===================== 2) Define GSO satellite & ground station =====================
% Paper: GSO sat lon=30.6E, lat=0; ground station varies in lon/lat for Fig.11-13.
gso = make_gso(P.gso_lon_deg, P.gso_lat_deg, P);

% Choose one scenario: ground station at longitude 30.6E, latitude 0 (equator)
gs = make_ground_station(P.gso_lon_deg, 0.0, P);

%% ===================== 3) Visible satellites to GS (min elev 10 deg) =====================
[visIdx, geom] = visible_leo_to_gs(LEO, gs, P.min_elev_deg);
fprintf("Visible LEO sats: %d\n", numel(visIdx));

% Precompute geometry terms needed by EPFD constraint for visible sats
E = precompute_epfd_terms(LEO, visIdx, gs, gso, P);

%% ===================== 4) Run Problem (16) and Problem (18) in Monte Carlo =====================
% Paper Fig.10: average demand satisfaction of visible satellites over random user positions and demands.
% They consider 5 users per satellite, demands in [4,6] Gbps.
U = 5;
demand_min = 4e9; % bps
demand_max = 6e9;

ds16 = zeros(MC_iters,1);
ds18 = zeros(MC_iters,1);
epfd16 = zeros(MC_iters,1);
epfd18 = zeros(MC_iters,1);
nTilt16 = zeros(MC_iters,1);
nTilt18 = zeros(MC_iters,1);

for k = 1:MC_iters
    % For each visible satellite, generate U users inside footprint (single beam)
    users = make_users_for_visible_sats(LEO, visIdx, gs, U, P);

    % demands for each user (equal split among 5 users per sat, per paper text)
    demands = demand_min + (demand_max-demand_min)*rand(size(users.lat_deg));
    % reshape: [U x Nvis]
    demands = reshape(demands, U, []);
    
    % Compute per-user constants for convex capacity expression
    Kconst = precompute_capacity_constants(LEO, visIdx, users, gs, gso, P);

    % ---- Solve Problem (16): tilt all visible satellites ----
    sol16 = solve_problem_16(E, Kconst, demands, P);

    % ---- Solve Problem (18): tilt only critical satellites ----
    sol18 = solve_problem_18(E, Kconst, demands, P);

    ds16(k) = sol16.avg_sat_demand_satisfaction;
    ds18(k) = sol18.avg_sat_demand_satisfaction;
    epfd16(k) = sol16.EPFD_dB;
    epfd18(k) = sol18.EPFD_dB;
    nTilt16(k) = sol16.num_tilted;
    nTilt18(k) = sol18.num_tilted;

    if mod(k,25)==0
        fprintf("Iter %d/%d | DS16=%.2f%% DS18=%.2f%% | EPFD16=%.2f EPFD18=%.2f | nTilt16=%d nTilt18=%d\n", ...
            k, MC_iters, ds16(k), ds18(k), epfd16(k), epfd18(k), nTilt16(k), nTilt18(k));
    end
end

%% ===================== 5) Plot Fig.10-like curve =====================
figure;
plot(1:MC_iters, ds16, 'b'); hold on;
plot(1:MC_iters, ds18, 'r');
grid on;
xlabel('Iteration');
ylabel('Demand Satisfaction (%)');
legend('Problem (16)','Problem (18)');

fprintf("\nSummary over %d iters:\n", MC_iters);
fprintf("Avg DS16=%.2f%% | Avg DS18=%.2f%%\n", mean(ds16), mean(ds18));
fprintf("Avg nTilt16=%.2f | Avg nTilt18=%.2f\n", mean(nTilt16), mean(nTilt18));

end
