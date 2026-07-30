function sol = solve_problem_16(E, Kc, demands, P)
% ============================================================
% Problem (16): Joint Power and Tilt Control
% CVX-stable, DCP-compliant implementation
% EPFD uses log-sum-exp and ONLY theta (additional tilt) inside exponent
% ============================================================

N = Kc.Nvis;
U = Kc.U; %#ok<NASGU>

% ---------- Aggregate demand per satellite ----------
Dsat = sum(demands, 1).';   % [N x 1]

% ---------- Safety for EPFD coefficients ----------
Ecs = max(E.gamma_base(:), 1e-30);   % avoid log(0)

cvx_clear
cvx_begin quiet

    % ---------- Variables ----------
    variables q(N) theta(N)
    
    % ---------- Capacity expressions (computed, not constrained directly) ----------
    expression C(N)
    for i = 1:N
        C(i) = sum( ...
            P.B_Hz * log( 1 + ...
            ( Kc.k(:,i) .* exp( q(i) + P.beta_fit*(Kc.s(:,i).*theta(i)) ) ) ...
            ./ Kc.v(:,i) ) ) / log(2);
    end

    % ---------- Objective ----------
    % Minimize the L2 norm of (capacity - demand) difference
    % This maximizes demand satisfaction (similar to Problem 18)
    % Using L2 norm is DCP-compliant and avoids constraint issues with convex C
    minimize( norm(C - Dsat, 2) )

    subject to
        % ---------- EPFD constraint (stable, phi_t already embedded in E.gamma_base geometry) ----------
        log_sum_exp( log(Ecs) + q + P.beta_fit*theta ) ...
            <= log(E.EPFD_thr_lin);

        % ---------- Bounds ----------
        q <= log(P.Pmax_W);      % power upper bound
        q >= log(1e-6);          % power lower bound (stability)
        theta >= 0;
        theta <= P.theta_max_deg;

cvx_end

% ---------- Post-processing ----------
Pi = exp(q);

% EPFD (consistent with constraint)
EPFD_lin = sum(Ecs .* exp(q + P.beta_fit*theta));
EPFD_dB  = 10*log10(EPFD_lin);

% True capacity (for debugging / reporting)
C_true = zeros(N,1);
for i = 1:N
    C_true(i) = sum( ...
        P.B_Hz * log2( 1 + ...
        ( Kc.k(:,i) .* exp( q(i) + P.beta_fit*(Kc.s(:,i).*theta(i)) ) ) ...
        ./ Kc.v(:,i) ) );
end

ds_true = mean( min(C_true ./ max(Dsat,1), 1) ) * 100;
ds_slack = mean( min(C ./ max(Dsat,1), 1) ) * 100;

% ---------- Output ----------
sol.q     = q;
sol.theta = theta;
sol.Pi    = Pi;
sol.EPFD_dB = EPFD_dB;
sol.avg_sat_demand_satisfaction = ds_true; % use TRUE capacity-based DS
sol.ds_slack = ds_slack;                   % keep slack-based DS for sanity
sol.num_tilted = sum(theta > 1e-6);

end
