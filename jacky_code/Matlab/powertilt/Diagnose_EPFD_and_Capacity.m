function Diagnose_EPFD_and_Capacity(root, leo_analysis, geo_analysis, tStr)
% ============================================================
% Diagnose_EPFD_and_Capacity
% 诊断 EPFD 和容量计算，检查是否有问题
% ============================================================

addpath(fullfile(pwd, 'Matlab', 'powertilt'));

P = paper_params();

fprintf('\n=== EPFD 和容量诊断 ===\n');
fprintf('时间点: %s\n', tStr);

% 设置时间
root.ExecuteCommand(['Animate * SetTime "' tStr '"']);

% 提取位置信息
[LEO_data, GEO_data, GS_data] = Extract_Positions_From_STK(root, leo_analysis, geo_analysis, tStr);

% 计算可见卫星
visIdx = Find_Visible_LEOs_To_GS_STK(LEO_data, GS_data, P.min_elev_deg);
fprintf('可见卫星数: %d\n', numel(visIdx));

if isempty(visIdx)
    error('没有可见的 LEO 卫星');
end

% 计算 EPFD 相关项
E = Precompute_EPFD_Terms_STK(LEO_data, visIdx, GS_data, GEO_data, P);
Nvis = numel(visIdx);

% ========== 0. 验证 gamma_base 计算 ==========
fprintf('\n=== 0. 验证 gamma_base 计算 ===\n');
Verify_Gamma_Base_Calculation(E, P, visIdx, leo_analysis, GS_data, GEO_data);

% ========== 1. EPFD 诊断 ==========
fprintf('\n=== 1. EPFD 诊断 ===\n');
Ecs = max(E.gamma_base(:), 1e-30);
Pi_max_all = P.Pmax_W * ones(Nvis, 1);
EPFD_max_lin = sum(Ecs .* Pi_max_all);
EPFD_max_dB = 10*log10(EPFD_max_lin);

fprintf('EPFD 阈值: %.2f dB\n', P.EPFD_thr_dB);
fprintf('实际 EPFD (最大功率): %.2f dB\n', EPFD_max_dB);
fprintf('差异: %.2f dB\n', EPFD_max_dB - P.EPFD_thr_dB);

if EPFD_max_dB > P.EPFD_thr_dB
    fprintf('状态: 违规\n');
    fprintf('需要降低功率或使用 tilt 来满足约束\n');
    
    % 计算需要降低的功率倍数
    power_reduction_factor = 10^((EPFD_max_dB - P.EPFD_thr_dB) / 10);
    fprintf('需要将功率降低 %.2f 倍（或 %.2f dB）才能满足约束\n', ...
        power_reduction_factor, EPFD_max_dB - P.EPFD_thr_dB);
else
    fprintf('状态: 不违规\n');
end

% 找出贡献最大的卫星
contributions = Ecs .* Pi_max_all;
[~, max_idx] = max(contributions);
fprintf('贡献最大的卫星: 索引 %d, EPFD 贡献 = %.2f dB\n', ...
    max_idx, 10*log10(contributions(max_idx)));

% ========== 2. 容量诊断 ==========
fprintf('\n=== 2. 容量诊断 ===\n');

% 生成用户
U = 5;
users = Make_Users_For_Visible_Sats_STK(LEO_data, visIdx, GS_data, U, P);

% 计算容量常数
Kc = Precompute_Capacity_Constants_STK(LEO_data, visIdx, users, GS_data, GEO_data, P);

% 计算理论最大容量（使用最大功率，零 tilt）
fprintf('计算理论最大容量（使用最大功率 P_max = %.1f W，零 tilt）...\n', P.Pmax_W);

N0 = P.kB * P.user_noise_temp_K;  % W/Hz
theoretical_capacity = zeros(U, Nvis);

for i = 1:Nvis
    if isfield(Kc, 'U_per_sat')
        U_actual = Kc.U_per_sat(i);
    else
        U_actual = U;
    end
    
    for u = 1:U_actual
        % 根据论文 Eq.(15): C_i,u = B * log2(1 + (k_i,u * P_i) / v_u)
        % 使用最大功率 P_max，零 tilt
        SINR_lin = (Kc.k(u, i) * P.Pmax_W) / Kc.v(u, i);
        theoretical_capacity(u, i) = P.B_Hz * log2(1 + SINR_lin);
    end
end

% 显示每个卫星的总容量
fprintf('\n各卫星的理论最大容量（P_max，零 tilt）:\n');
for i = 1:Nvis
    if isfield(Kc, 'U_per_sat')
        U_actual = Kc.U_per_sat(i);
    else
        U_actual = U;
    end
    
    sat_capacity = sum(theoretical_capacity(1:U_actual, i));
    fprintf('  卫星 %d: %.2f Gbps (%.2f Gbps/用户, %d 用户)\n', ...
        i, sat_capacity/1e9, sat_capacity/(U_actual*1e9), U_actual);
end

% 计算平均容量
avg_capacity_per_sat = mean(sum(theoretical_capacity, 1));
avg_capacity_per_user = mean(theoretical_capacity(theoretical_capacity > 0));

fprintf('\n平均容量:\n');
fprintf('  每卫星: %.2f Gbps\n', avg_capacity_per_sat/1e9);
fprintf('  每用户: %.2f Gbps\n', avg_capacity_per_user/1e9);

% ========== 3. 根据论文设置合理需求 ==========
fprintf('\n=== 3. 根据论文设置合理需求 ===\n');
fprintf('根据论文 Eq.(6): C_{i,u} = B * log2(1 + SINR_{i,u})\n');
fprintf('带宽 B = %.0f MHz\n', P.B_Hz/1e6);

% 根据理论容量范围设置需求
% 需求应该略小于理论最大容量，以确保在优化后能够满足
capacity_per_user_min = min(theoretical_capacity(theoretical_capacity > 0));
capacity_per_user_max = max(theoretical_capacity(:));

% 设置需求为理论容量的 50-80%（考虑到优化后功率可能降低）
demand_per_user_min = capacity_per_user_min * 0.5;
demand_per_user_max = capacity_per_user_max * 0.8;

fprintf('理论容量范围（每用户）: %.2f - %.2f Gbps\n', ...
    capacity_per_user_min/1e9, capacity_per_user_max/1e9);
fprintf('建议需求范围（每用户）: %.2f - %.2f Gbps\n', ...
    demand_per_user_min/1e9, demand_per_user_max/1e9);

% 如果需求范围不合理，使用保守值
if demand_per_user_min < 0.1e9
    demand_per_user_min = 0.1e9;  % 最小 100 Mbps
end
if demand_per_user_max > 1.0e9
    demand_per_user_max = 1.0e9;  % 最大 1 Gbps
end

fprintf('最终需求范围（每用户）: %.2f - %.2f Gbps\n', ...
    demand_per_user_min/1e9, demand_per_user_max/1e9);

% ========== 4. 检查优化后的容量 ==========
fprintf('\n=== 4. 检查优化后的容量 ===\n');

% 使用固定的合理需求（根据典型通信系统需求）
demand_per_user_min = 0.5e9;  % 500 Mbps
demand_per_user_max = 1.0e9;  % 1 Gbps

fprintf('使用固定需求范围（每用户）: %.2f - %.2f Gbps\n', ...
    demand_per_user_min/1e9, demand_per_user_max/1e9);

% 生成需求
demands_vec = demand_per_user_min + (demand_per_user_max - demand_per_user_min) * rand(U * Nvis, 1);
demands = reshape(demands_vec, U, Nvis);

% 识别关键卫星
Pi_for_crit = P.Pmax_W * ones(Nvis, 1);
critIdx = find_critical_satellites(E.gamma_base, Pi_for_crit, E.EPFD_thr_lin, P.zeta_thr, E.phi_r_deg);

% 求解 Problem 18
fprintf('求解 Problem 18（关键卫星 tilt）...\n');
sol18 = solve_problem_18(E, Kc, demands, P, critIdx);

if strcmp(sol18.cvx_status, 'Solved')
    fprintf('优化成功！\n');
    
    % 显示优化后的功率和 tilt
    fprintf('\n优化后的功率和 tilt:\n');
    for i = 1:Nvis
        fprintf('  卫星 %d: Power = %.2e W (%.2f dBW), Tilt = %.2f deg\n', ...
            i, sol18.Pi(i), 10*log10(sol18.Pi(i)), sol18.theta(i));
    end
    
    % 计算每个卫星的需求满足率
    fprintf('\n各卫星的需求满足率:\n');
    for i = 1:Nvis
        if isfield(Kc, 'U_per_sat')
            U_actual = Kc.U_per_sat(i);
        else
            U_actual = U;
        end
        
        sat_demand = sum(demands(1:U_actual, i));
        sat_capacity = sum(sol18.Cap_val(1:U_actual, i));
        sat_satisfaction = min(sat_capacity / sat_demand, 1) * 100;
        
        % 显示详细的容量信息（特别是关键卫星）
        if ismember(i, critIdx)
            fprintf('  卫星 %d (关键): 需求 = %.2f Gbps, 容量 = %.2f Gbps, 满足率 = %.1f%%\n', ...
                i, sat_demand/1e9, sat_capacity/1e9, sat_satisfaction);
            fprintf('     功率 = %.2e W, Tilt = %.2f deg\n', sol18.Pi(i), sol18.theta(i));
            
            % 显示每个用户的容量
            fprintf('     各用户容量: ');
            for u = 1:U_actual
                fprintf('%.2f Gbps ', sol18.Cap_val(u, i)/1e9);
            end
            fprintf('\n');
            
            % 检查容量计算
            fprintf('     容量计算验证:\n');
            for u = 1:U_actual
                SINR_lin = (Kc.k(u, i) * sol18.Pi(i) * exp(P.beta_fit * Kc.s(u, i) * sol18.theta(i))) / Kc.v(u, i);
                cap_calc = P.B_Hz * log2(1 + SINR_lin);
                fprintf('       用户 %d: SINR = %.2e, 容量 = %.2f Gbps\n', ...
                    u, SINR_lin, cap_calc/1e9);
            end
        else
            fprintf('  卫星 %d: 需求 = %.2f Gbps, 容量 = %.2f Gbps, 满足率 = %.1f%%\n', ...
                i, sat_demand/1e9, sat_capacity/1e9, sat_satisfaction);
        end
    end
    
    fprintf('\n平均需求满足率: %.1f%%\n', sol18.avg_sat_demand_satisfaction);
    fprintf('EPFD: %.2f dB (阈值: %.2f dB)\n', sol18.EPFD_dB, P.EPFD_thr_dB);
    
    % 检查关键卫星的功率是否过低
    if ~isempty(critIdx)
        fprintf('\n关键卫星功率分析:\n');
        for i = 1:numel(critIdx)
            idx = critIdx(i);
            fprintf('  卫星 %d: Power = %.2e W (%.2f dBW), Tilt = %.2f deg\n', ...
                idx, sol18.Pi(idx), 10*log10(sol18.Pi(idx)), sol18.theta(idx));
            
            % 计算 tilt 对有效功率的影响
            % exp(β*θ) = exp(-0.0671*10) = 0.511
            tilt_factor = exp(P.beta_fit * sol18.theta(idx));
            effective_power = sol18.Pi(idx) * tilt_factor;
            fprintf('    Tilt 因子: %.4f (exp(β*θ) = exp(%.4f*%.2f))\n', ...
                tilt_factor, P.beta_fit, sol18.theta(idx));
            fprintf('    有效功率（考虑 tilt）: %.2e W\n', effective_power);
            
            % 计算 EPFD 贡献
            Ecs = max(E.gamma_base(:), 1e-30);
            EPFD_contrib_lin = Ecs(idx) * sol18.Pi(idx) * exp(P.beta_fit * sol18.theta(idx));
            EPFD_contrib_dB = 10*log10(EPFD_contrib_lin);
            fprintf('    EPFD 贡献: %.4e (线性) = %.2f dB\n', EPFD_contrib_lin, EPFD_contrib_dB);
            
            % 如果使用最大功率会如何
            EPFD_contrib_max_lin = Ecs(idx) * P.Pmax_W;
            EPFD_contrib_max_dB = 10*log10(EPFD_contrib_max_lin);
            fprintf('    如果使用最大功率 P_max = %.1f W，EPFD 贡献 = %.2f dB\n', ...
                P.Pmax_W, EPFD_contrib_max_dB);
            
            % 计算功率降低倍数
            power_reduction = P.Pmax_W / sol18.Pi(idx);
            fprintf('    功率降低倍数: %.2f 倍 (%.2f dB)\n', ...
                power_reduction, 10*log10(power_reduction));
            
            % 分析：如果只降低关键卫星的功率，需要降低多少？
            % 其他卫星的 EPFD 贡献
            other_contrib_lin = sum(Ecs(setdiff(1:Nvis, idx)) .* sol18.Pi(setdiff(1:Nvis, idx)));
            other_contrib_dB = 10*log10(other_contrib_lin);
            fprintf('    其他卫星的 EPFD 贡献: %.2f dB\n', other_contrib_dB);
            
            % 关键卫星允许的最大 EPFD 贡献
            max_allowed_contrib_lin = E.EPFD_thr_lin - other_contrib_lin;
            max_allowed_contrib_dB = 10*log10(max_allowed_contrib_lin);
            fprintf('    关键卫星允许的最大 EPFD 贡献: %.2f dB\n', max_allowed_contrib_dB);
            
            % 计算关键卫星需要的功率（考虑 tilt）
            % EPFD_contrib = Ecs * P * exp(β*θ)
            % 所以 P = EPFD_contrib / (Ecs * exp(β*θ))
            required_power_lin = max_allowed_contrib_lin / (Ecs(idx) * exp(P.beta_fit * sol18.theta(idx)));
            required_power_dB = 10*log10(required_power_lin);
            fprintf('    关键卫星需要的功率（考虑 tilt）: %.2e W (%.2f dBW)\n', ...
                required_power_lin, required_power_dB);
            fprintf('    实际功率: %.2e W (%.2f dBW)\n', ...
                sol18.Pi(idx), 10*log10(sol18.Pi(idx)));
            
            if sol18.Pi(idx) < 1e-3
                fprintf('    ⚠ 警告：功率过低，可能导致容量接近 0\n');
                fprintf('    原因：EPFD 约束太严格，关键卫星的功率必须大幅降低\n');
                fprintf('    建议：检查 EPFD 阈值是否正确，或考虑调整优化目标\n');
            end
            
            % 检查容量计算中的各项
            fprintf('    容量计算分析:\n');
            if isfield(Kc, 'U_per_sat')
                U_actual = Kc.U_per_sat(idx);
            else
                U_actual = U;
            end
            
            for u = 1:min(2, U_actual)  % 只显示前2个用户
                k_val = Kc.k(u, idx);
                v_val = Kc.v(u, idx);
                s_val = Kc.s(u, idx);
                
                % 计算有效功率（考虑 tilt）
                effective_power_user = sol18.Pi(idx) * exp(P.beta_fit * s_val * sol18.theta(idx));
                SINR_lin = (k_val * effective_power_user) / v_val;
                cap_calc = P.B_Hz * log2(1 + SINR_lin);
                
                fprintf('      用户 %d: k=%.4e, v=%.4e, s=%.0f\n', u, k_val, v_val, s_val);
                fprintf('        有效功率 = %.2e W (考虑 tilt)\n', effective_power_user);
                fprintf('        SINR = %.4e, 容量 = %.4f Gbps\n', SINR_lin, cap_calc/1e9);
            end
            
            % 如果使用需要的功率，容量会是多少？
            fprintf('    如果使用需要的功率 (%.2e W)，容量会是多少？\n', required_power_lin);
            for u = 1:min(2, U_actual)
                k_val = Kc.k(u, idx);
                v_val = Kc.v(u, idx);
                s_val = Kc.s(u, idx);
                effective_power_user = required_power_lin * exp(P.beta_fit * s_val * sol18.theta(idx));
                SINR_lin = (k_val * effective_power_user) / v_val;
                cap_calc = P.B_Hz * log2(1 + SINR_lin);
                fprintf('      用户 %d: SINR = %.4e, 容量 = %.4f Gbps\n', u, SINR_lin, cap_calc/1e9);
            end
        end
    end
else
    fprintf('优化失败: %s\n', sol18.cvx_status);
end

fprintf('\n=== 诊断完成 ===\n');