function sol = solve_problem_16(E, Kc, demands, P)
% ============================================================
% solve_problem_16
% Problem (16): Joint Power and Tilt Control
% 
% 论文: "Joint Power and Tilt Control in Satellite Constellation 
%        for NGSO-GSO Interference Mitigation" (OJVT 2023)
%
% 优化问题:
%   minimize: ||C - Dsat||_2
%   subject to:
%     EPFD ≤ EPFD_threshold  (论文 Eq.(16))
%     P_min ≤ P_i ≤ P_max
%     0 ≤ θ_i ≤ θ_max
%
% INPUTS:
%   E       : EPFD 相关项（来自 Precompute_EPFD_Terms_STK）
%   Kc      : 容量常数（来自 Precompute_Capacity_Constants_STK）
%   demands : [U x Nvis] 需求矩阵（每个用户的需求）
%   P       : 参数结构（来自 paper_params）
%
% OUTPUTS:
%   sol     : 结构体，包含：
%       .q     : [Nvis x 1] 功率的对数
%       .theta : [Nvis x 1] tilt 角度（度）
%       .Pi    : [Nvis x 1] 功率（W）
%       .EPFD_dB : EPFD 值（dB）
%       .avg_sat_demand_satisfaction : 平均需求满足率（%）
%       .num_tilted : 使用 tilt 的卫星数量
% ============================================================

N = Kc.Nvis;
U = Kc.U;

% ---------- 聚合每个卫星的总需求 ----------
Dsat = sum(demands, 1).';   % [N x 1]

% ---------- EPFD 系数的安全性处理 ----------
Ecs = max(E.gamma_base(:), 1e-30);   % 避免 log(0)

% ---------- 检查 CVX 是否可用 ----------
if ~exist('cvx_begin', 'file')
    error('CVX 未安装。请安装 CVX: http://cvxr.com/cvx/');
end

fprintf('开始求解 Problem 16...\n');
fprintf('  可见卫星数: %d\n', N);
fprintf('  每个卫星最大用户数: %d\n', U);
fprintf('  总需求范围: [%.2f, %.2f] Gbps\n', min(Dsat)/1e9, max(Dsat)/1e9);

cvx_clear
cvx_begin quiet

    % ---------- 优化变量 ----------
    variables q(N) theta(N)
    
    % ---------- 容量表达式（论文 Eq.(15)） ----------
    expression C(N)
    for i = 1:N
        % 对于每个卫星，计算总容量
        % C_i = Σ_u B * log2(1 + (k_i,u * exp(q_i + β*s_i,u*θ_i)) / v_u)
        
        % 找到该卫星的实际用户数
        if isfield(Kc, 'U_per_sat')
            U_actual = Kc.U_per_sat(i);
        else
            U_actual = U;
        end
        
        C(i) = sum( ...
            P.B_Hz * log( 1 + ...
            ( Kc.k(1:U_actual, i) .* exp( q(i) + P.beta_fit*(Kc.s(1:U_actual, i).*theta(i)) ) ) ...
            ./ Kc.v(1:U_actual, i) ) ) / log(2);
    end

    % ---------- 优化目标 ----------
    % 最大化总容量（在满足约束的前提下）
    maximize( sum(C) )

    subject to
    % ---------- EPFD 约束（论文 Eq.(16)） ----------
    % Tilt 降低对 GSO 的干扰，所以应该是 q - P.beta_fit*theta
    log_sum_exp( log(Ecs) + q - P.beta_fit*theta ) ...
        <= log(E.EPFD_thr_lin);

        % ---------- 功率边界 ----------
        q <= log(P.Pmax_W);      % 功率上界
        q >= log(1e-6);          % 功率下界（稳定性）

        % ---------- Tilt 角度边界 ----------
        theta >= 0;
        theta <= P.theta_max_deg;

cvx_end

% ---------- 后处理 ----------
Pi = exp(q);

% EPFD 计算（与约束一致）
EPFD_lin = sum(Ecs .* exp(q + P.beta_fit*theta));
EPFD_dB  = 10*log10(EPFD_lin);

% 真实容量计算（用于调试/报告）
C_true = zeros(N, 1);
for i = 1:N
    if isfield(Kc, 'U_per_sat')
        U_actual = Kc.U_per_sat(i);
    else
        U_actual = U;
    end
    
    C_true(i) = sum( ...
        P.B_Hz * log2( 1 + ...
        ( Kc.k(1:U_actual, i) .* exp( q(i) + P.beta_fit*(Kc.s(1:U_actual, i).*theta(i)) ) ) ...
        ./ Kc.v(1:U_actual, i) ) );
end

% 需求满足率计算
ds_true = mean( min(C_true ./ max(Dsat, 1), 1) ) * 100;
ds_slack = mean( min(C ./ max(Dsat, 1), 1) ) * 100;

% ---------- 输出 ----------
sol.q = q;
sol.theta = theta;
sol.Pi = Pi;
sol.EPFD_dB = EPFD_dB;
sol.EPFD_lin = EPFD_lin;
sol.avg_sat_demand_satisfaction = ds_true;  % 使用真实容量计算的 DS
sol.ds_slack = ds_slack;                    % 保留 slack 计算的 DS 用于验证
sol.num_tilted = sum(theta > 1e-6);
sol.C_true = C_true;
sol.Dsat = Dsat;
sol.cvx_status = cvx_status;
sol.cvx_optval = cvx_optval;

% 显示求解状态
fprintf('求解完成！\n');
fprintf('  CVX 状态: %s\n', cvx_status);
if strcmp(cvx_status, 'Solved')
    fprintf('  ✓ 优化成功\n');
else
    warning('优化可能未完全成功，状态: %s', cvx_status);
end

end