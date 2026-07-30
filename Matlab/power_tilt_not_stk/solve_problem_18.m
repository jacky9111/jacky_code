function sol = solve_problem_18(E, Kc, demands, P, critIdx)
% Problem (18): Joint power + tilt BUT only for critical satellites
% Paper-aligned EPFD using gamma_base and theta only for critIdx

N = Kc.Nvis;
U = Kc.U;

% If critIdx not provided, compute it using Algorithm 1
if nargin < 5 || isempty(critIdx)
    critIdx = find_critical_satellites(E.gamma_base, P.zeta_thr);
end

critMask = false(N,1);
critMask(critIdx) = true;

% demands: expect [U x N]
D = demands;

% Safety
gamma = max(E.gamma_base(:), 1e-50);
EPFD_thr = E.EPFD_thr_lin;

cvx_clear
cvx_begin quiet
    variables q(N) theta(N)

    % capacity matrix (expression)
    expression Cap(U,N)

    for i = 1:N
        for u = 1:U
            Cap(u,i) = P.B_Hz * log( 1 + ...
                (Kc.k(u,i) .* exp( q(i) + P.beta_fit*(Kc.s(u,i).*theta(i)) )) ./ Kc.v(u,i) ) / log(2);
        end
    end

    minimize( norm( Cap(:) - D(:), 2 ) )

    subject to
        % EPFD constraint (Eq.(16) with exp(q_i + beta*theta_i))
        log_sum_exp( log(gamma) + q + P.beta_fit*theta ) <= log(EPFD_thr);

        % power bounds
        q <= log(P.Pmax_W);
        q >= log(1e-6);

        % tilt bounds + only critical allowed
        theta >= 0;
        theta <= P.theta_max_deg;
        theta(~critMask) == 0;
cvx_end

Pi = exp(q);

% EPFD report
EPFD_lin = sum( gamma .* exp(q + P.beta_fit*theta) );
EPFD_dB  = 10*log10(EPFD_lin);

% Demand satisfaction (true, based on Cap)
Cap_val = zeros(U,N);
for i=1:N
    for u=1:U
        Cap_val(u,i) = P.B_Hz * log2( 1 + ...
            (Kc.k(u,i) .* exp( q(i) + P.beta_fit*(Kc.s(u,i).*theta(i)) )) ./ Kc.v(u,i) );
    end
end
ds = mean( min(Cap_val(:) ./ max(D(:),1e-12), 1) ) * 100;

sol.q = q;
sol.theta = theta;
sol.Pi = Pi;
sol.EPFD_dB = EPFD_dB;
sol.num_tilted = sum(theta > 1e-6);
sol.critIdx = critIdx;
sol.demand_satisfaction = ds;
sol.avg_sat_demand_satisfaction = ds;  % alias (same field name as Problem 16)
sol.cvx_status = cvx_status;
sol.cvx_optval = cvx_optval;

fprintf('[Problem18] status=%s | EPFD=%.2f dB | tilted=%d | DS=%.2f%%\n', ...
    cvx_status, EPFD_dB, sol.num_tilted, ds);
end
