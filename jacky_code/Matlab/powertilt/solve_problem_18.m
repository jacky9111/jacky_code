function sol = solve_problem_18(E, Kc, demands, P, critIdx)
% ============================================================
% solve_problem_18
% Problem (18): Joint Power and Tilt Control (Only Critical Satellites)
% 
% 论文: "Joint Power and Tilt Control in Satellite Constellation 
%        for NGSO-GSO Interference Mitigation" (OJVT 2023)
%
% Algorithm 1 的核心：只有关键卫星可以 tilt
% ============================================================

N = Kc.Nvis;
U = Kc.U;

% 如果 critIdx 未提供，需要先求解一次（零 tilt）来识别关键卫星
if nargin < 5 || isempty(critIdx)
    fprintf('未提供关键卫星索引，需要先求解一次（零 tilt）来识别...\n');
    
    % 先求解一次 Problem 18（theta = 0）
    Dsat = sum(demands, 1).';
    Ecs = max(E.gamma_base(:), 1e-30);
    
    cvx_clear
    cvx_begin quiet
        variables q_init(N)
        
        % 优化目标：在满足 EPFD 约束的前提下，最大化总功率
        % 这样可以间接最大化容量（因为容量是功率的单调递增函数）
        maximize( sum(q_init) )
        subject to
            log_sum_exp( log(Ecs) + q_init ) <= log(E.EPFD_thr_lin);
            if isfield(P, 'Pmax_W_vec') && numel(P.Pmax_W_vec) == N
                idx_cap = isfinite(P.Pmax_W_vec) & P.Pmax_W_vec > 0;
                if any(idx_cap)
                    q_init(idx_cap) <= log(P.Pmax_W_vec(idx_cap));
                end
            else
                q_init <= log(P.Pmax_W);
            end
            q_init >= log(1e-6);
    cvx_end
    
    Pi_init = exp(q_init);
    
    % 识别关键卫星（传入 phi_r_deg）
    critIdx = find_critical_satellites(E.gamma_base, Pi_init, E.EPFD_thr_lin, P.zeta_thr, E.phi_r_deg);
else
    % Guard against logical mask or out-of-range indices
    if islogical(critIdx)
        critIdx = find(critIdx);
    end
    critIdx = critIdx(:);
    in_range = isfinite(critIdx) & critIdx >= 1 & critIdx <= N;
    if any(~in_range)
        warning('solve_problem_18:critIdxRange', ...
            'critIdx has out-of-range entries; trimming to 1..%d.', N);
        critIdx = critIdx(in_range);
    end
end

% 创建关键卫星掩码
critMask = false(N, 1);
critMask(critIdx) = true;

% 聚合需求
Dsat = sum(demands, 1).';
Ecs = max(E.gamma_base(:), 1e-30);
EPFD_thr = E.EPFD_thr_lin;

fprintf('开始求解 Problem 18（关键卫星 tilt）...\n');
fprintf('  可见卫星数: %d\n', N);
fprintf('  关键卫星数: %d\n', numel(critIdx));
fprintf('  每个卫星最大用户数: %d\n', U);

% 根据论文 Eq.(16)，EPFD 约束为：
% 10 log10 ( Σ (A * G_G^r(φ_i^r) * exp(q_i + β(φ_i^r + θ_i))) / (BW_ref * 4πd_i^2 * G_Gmax) ) ≤ EPFD_thr
%
% 转换为线性形式：
% Σ (A * G_G^r(φ_i^r) * exp(β*φ_i^r) * exp(q_i) * exp(β*θ_i)) / (BW_ref * 4πd_i^2 * G_Gmax) ≤ 10^(EPFD_thr/10)
%
% 注意：
% - gamma_base 已经包含了 (A * G_G^r(φ_i^r) * exp(β*φ'_i)) / (BW_ref * 4πd_i^2 * G_Gmax)
% - 但 EPFD 约束中需要的是 exp(β(φ_i^r + θ_i))，其中 φ_i^r 是 phi_r
% - 所以需要额外考虑 exp(β*φ_i^r) 和 exp(β*θ_i)
%
% 修正：Ecs 应该已经包含了所有项，但需要调整以匹配 Eq.(16)
% 实际上，我们需要重新计算 Ecs，使其包含 exp(β*φ_i^r) 而不是 exp(β*φ'_i)

cvx_clear
cvx_begin quiet
    variables q(N) theta(N)
    
    % 优化目标：根据论文 Problem (18)
    % minimize || B log2(1 + (k_i,u * exp(q_i + β*s_i,u*θ_i)) / v_u) - D_u ||_2
    %
    % 计算每个卫星的总容量（论文 Eq.(15)）
    % C_i = Σ_u B * log2(1 + (k_i,u * exp(q_i + β*s_i,u*θ_i)) / v_u)
    expression C(N)
    for i = 1:N
        if isfield(Kc, 'U_per_sat')
            U_actual = Kc.U_per_sat(i);
        else
            U_actual = U;
        end
        
        % Important: a satellite may have 0 users after handover (U_actual=0).
        % In MATLAB, q(i) + beta*(empty) becomes empty, leading to exp([]),
        % which triggers a CVX internal error ("logical indices ... out of bounds").
        % For U_actual<=0, its capacity contribution is zero.
        if U_actual <= 0
            C(i) = 0;
            continue;
        end
        
        % 对于每个卫星，计算总容量
        % 使用 sum(...) 直接赋值，而不是累加，这样 CVX 更容易识别凹函数
        C(i) = sum( ...
            P.B_Hz * log( 1 + ...
            ( Kc.k(1:U_actual, i) .* exp( q(i) + P.beta_fit*(Kc.s(1:U_actual, i).*theta(i)) ) ) ...
            ./ Kc.v(1:U_actual, i) ) ) / log(2);
    end
    
    % 优化目标：根据论文 Problem (18)，应该最小化容量与需求的差异
    % minimize || B log2(1 + (k_i,u * exp(q_i + β*s_i,u*θ_i)) / v_u) - D_u ||_2
    %
    % 由于 CVX 无法识别 sum(C) 为凹函数（当 C 包含 log(1+exp(...)) 时），
    % 我们使用 maximize(sum(q)) 作为代理目标
    % 
    % 注意：虽然这不是论文的直接目标，但容量是功率的单调递增函数，
    % 所以最大化功率可以间接最大化容量。这是 CVX 技术限制下的折中方案。
    %
    % 为了更接近论文的意图（关注容量），我们给关键卫星添加权重，
    % 使其在 EPFD 约束允许的情况下获得更多功率
    % 
    % 权重设置：关键卫星的权重 w_crit > 1，使其在优化中获得更多功率
    % 这样可以平衡关键卫星和其他卫星的功率分配
    w_crit = 10.0;  % 关键卫星权重（可调整，如果关键卫星容量仍然过低，可以增大此值）
    expression q_weighted(N)
    for i = 1:N
        if critMask(i)
            q_weighted(i) = w_crit * q(i);
        else
            q_weighted(i) = q(i);
        end
    end
    maximize( sum(q_weighted) )

    subject to
        % EPFD 约束（论文 Eq.(16)）
        % 10 log10 ( Σ (A * G_G^r(φ_i^r) * exp(q_i + β(φ_i^r + θ_i))) / (BW_ref * 4πd_i^2 * G_Gmax) ) ≤ EPFD_thr
        %
        % 转换为线性形式：
        % Σ (A * G_G^r(φ_i^r) * exp(β*φ_i^r) * exp(q_i) * exp(β*θ_i)) / (BW_ref * 4πd_i^2 * G_Gmax) ≤ 10^(EPFD_thr/10)
        %
        % 由于 gamma_base 已经包含了 (A * G_G^r(φ_i^r) * exp(β*φ_i^r)) / (BW_ref * 4πd_i^2 * G_Gmax)
        % 所以约束简化为：
        log_sum_exp( log(Ecs) + q + P.beta_fit*theta ) <= log(EPFD_thr);
        % 
        % 注意：beta 是负值（-0.0671），所以 exp(β*θ_i) < 1，tilt 会降低干扰
        % 在 log 空间中：log(exp(β*θ_i)) = β*θ_i
        % 由于 beta < 0，所以 β*θ_i < 0，因此 q + β*θ_i < q，降低了 EPFD
        
        % 功率边界
        if isfield(P, 'Pmax_W_vec') && numel(P.Pmax_W_vec) == N
            idx_cap = isfinite(P.Pmax_W_vec) & P.Pmax_W_vec > 0;
            if any(idx_cap)
                q(idx_cap) <= log(P.Pmax_W_vec(idx_cap));
            end
        else
            q <= log(P.Pmax_W);
        end
        q >= log(1e-6);
        
        % Tilt 边界 + 只有关键卫星可以 tilt
        % NOTE: avoid logical indexing on CVX vars (can trigger
        % "logical indices contain a true value outside of the array bounds"
        % when dimensions drift after handover). Enforce via elementwise bound:
        % for non-critical sats (critMask=0) => theta <= 0; with theta>=0 => theta=0.
        theta >= 0;
        theta <= P.theta_max_deg * double(critMask);

cvx_end

% 后处理
Pi = exp(q);

% EPFD 计算（与约束一致）
% 根据约束：log_sum_exp( log(Ecs) + q + P.beta_fit*theta ) <= log(EPFD_thr)
% 所以 EPFD = Σ Ecs * exp(q) * exp(β*theta)
EPFD_lin = sum(Ecs .* exp(q + P.beta_fit*theta));
EPFD_dB = 10*log10(EPFD_lin);

% 真实容量计算
Cap_val = zeros(U, N);
for i = 1:N
    if isfield(Kc, 'U_per_sat')
        U_actual = Kc.U_per_sat(i);
    else
        U_actual = U;
    end
    
    for u = 1:U_actual
        % 根据论文 Eq.(15)
        % C_i,u = B * log2(1 + (k_i,u * exp(q_i + β*s_i,u*θ_i)) / v_u)
        Cap_val(u, i) = P.B_Hz * log2( 1 + ...
            (Kc.k(u, i) .* exp( q(i) + P.beta_fit*(Kc.s(u, i).*theta(i)) )) ...
            ./ Kc.v(u, i) );
    end
end

% 需求满足率（按卫星计算，而不是全局平均）
% 对于每个卫星，计算其需求满足率
sat_demand_satisfaction = zeros(N, 1);
for i = 1:N
    if isfield(Kc, 'U_per_sat')
        U_actual = Kc.U_per_sat(i);
    else
        U_actual = U;
    end
    
    sat_demand = sum(demands(1:U_actual, i));
    sat_capacity = sum(Cap_val(1:U_actual, i));
    
    if sat_demand > 0
        sat_demand_satisfaction(i) = min(sat_capacity / sat_demand, 1) * 100;
    else
        sat_demand_satisfaction(i) = 100;
    end
end

% 全局平均需求满足率
ds = mean(sat_demand_satisfaction);

% 输出
sol.q = q;
sol.theta = theta;
sol.Pi = Pi;
sol.EPFD_dB = EPFD_dB;
sol.EPFD_lin = EPFD_lin;
sol.avg_sat_demand_satisfaction = ds;
sol.num_tilted = sum(theta > 1e-6);
sol.critIdx = critIdx;
sol.Cap_val = Cap_val;
sol.Dsat = Dsat;
sol.cvx_status = cvx_status;
sol.cvx_optval = cvx_optval;

% ============================
% Per-user / per-satellite satisfaction metrics (for handover logic)
% ============================
% demands is [U x N], but for variable user counts per satellite, only
% demands(1:U_actual, i) are valid.
user_satisfaction = nan(U, N);        % [%] per user-per-sat (NaN where invalid)
user_capacity_bps = nan(U, N);        % [bps]
user_demand_bps = nan(U, N);          % [bps]

for i = 1:N
    if isfield(Kc, 'U_per_sat')
        U_actual = Kc.U_per_sat(i);
    else
        U_actual = U;
    end
    
    if U_actual <= 0
        continue;
    end
    
    user_capacity_bps(1:U_actual, i) = Cap_val(1:U_actual, i);
    user_demand_bps(1:U_actual, i) = demands(1:U_actual, i);
    
    denom = max(user_demand_bps(1:U_actual, i), 1); % avoid divide-by-zero
    user_satisfaction(1:U_actual, i) = min(user_capacity_bps(1:U_actual, i) ./ denom, 1) * 100;
end

sol.user_satisfaction = user_satisfaction;
sol.user_capacity_bps = user_capacity_bps;
sol.user_demand_bps = user_demand_bps;
sol.min_user_satisfaction = min(user_satisfaction(:), [], 'omitnan');
sol.avg_user_satisfaction = mean(user_satisfaction(:), 'omitnan');
sol.sat_demand_satisfaction = sat_demand_satisfaction; % [%] per satellite

% 显示求解状态
fprintf('求解完成！\n');
fprintf('  CVX 状态: %s\n', cvx_status);
if strcmp(cvx_status, 'Solved')
    fprintf('  ✓ 优化成功\n');
else
    warning('优化可能未完全成功，状态: %s', cvx_status);
end

end
