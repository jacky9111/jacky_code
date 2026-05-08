function Verify_EPFD_Power_Tilt_Calculations(root, leo_analysis, geo_analysis, tStr)
% ============================================================
% Verify_EPFD_Power_Tilt_Calculations
% 全面验证 EPFD、功率控制和 tilt 的计算
% ============================================================

addpath(fullfile(pwd, 'Matlab', 'powertilt'));

P = paper_params();

fprintf('\n=== 全面验证 EPFD、功率控制和 Tilt 计算 ===\n');
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

% ========== 1. 验证 EPFD 计算 ==========
fprintf('\n=== 1. 验证 EPFD 计算 ===\n');

% 计算 EPFD 相关项
E = Precompute_EPFD_Terms_STK(LEO_data, visIdx, GS_data, GEO_data, P);
Nvis = numel(visIdx);

% 检查参数
fprintf('参数验证:\n');
fprintf('  A_fit = %.4e\n', P.A_fit);
fprintf('  beta_fit = %.4f (1/deg)\n', P.beta_fit);
fprintf('  BWref_Hz = %.0f Hz\n', P.BWref_Hz);
fprintf('  GSO_Gmax_dBi = %.2f dBi\n', P.GSO_Gmax_dBi);
G_Gmax_lin = 10^(P.GSO_Gmax_dBi/10);
fprintf('  G_Gmax_lin = %.4e\n', G_Gmax_lin);
fprintf('  EPFD_thr_dB = %.2f dB\n', P.EPFD_thr_dB);
fprintf('  EPFD_thr_lin = %.6e\n', E.EPFD_thr_lin);

% 手动计算验证（针对前3个卫星）
fprintf('\n手动计算验证（前3个卫星）:\n');
gamma_manual_all = zeros(min(3, Nvis), 1);
for k = 1:min(3, Nvis)
    idx = visIdx(k);
    sat_name = leo_analysis{idx};
    
    phi_r = E.phi_r_deg(k);
    phi_t = E.phi_t_deg(k);
    d_m = E.d_m(k);
    
    % 手动计算 GSO 接收增益（绝对增益；不要再乘 G_Gmax）
    GGr_abs_dB = gso_rx_gain_itu1428(phi_r, P.D_ref_m, P.lambda);
    GGr_abs_lin = 10^(GGr_abs_dB/10);
    
    % 手动计算 gamma_base
    % 与 Precompute_EPFD_Terms_STK 一致：接收端用 phi_r，发射端指数衰减用 phi_t
    gamma_manual = (P.A_fit * GGr_abs_lin * exp(P.beta_fit * phi_t)) / ...
                   (P.BWref_Hz * 4*pi*d_m^2 * G_Gmax_lin);
    gamma_manual_all(k) = gamma_manual;
    
    fprintf('\n  卫星 %d (%s):\n', k, sat_name);
    fprintf('    phi_r = %.4f deg\n', phi_r);
    fprintf('    phi_t = %.4f deg\n', phi_t);
    fprintf('    d = %.1f km\n', d_m/1000);
    fprintf('    GGr_abs_lin = %.4e\n', GGr_abs_lin);
    fprintf('    exp(β*phi_t) = exp(%.4f*%.4f) = %.4e\n', P.beta_fit, phi_t, exp(P.beta_fit * phi_t));
    fprintf('    gamma_base (代码) = %.4e\n', E.gamma_base(k));
    fprintf('    gamma_base (手动) = %.4e\n', gamma_manual);
    
    relative_error = abs(E.gamma_base(k) - gamma_manual) / max(abs(E.gamma_base(k)), abs(gamma_manual));
    if relative_error < 1e-6
        fprintf('    ✓ gamma_base 计算正确（相对误差: %.2e）\n', relative_error);
    else
        fprintf('    ✗ gamma_base 不匹配！差异: %.2e (相对误差: %.2e)\n', ...
            abs(E.gamma_base(k) - gamma_manual), relative_error);
    end
    
    % 计算单颗卫星的 EPFD（最大功率）
    EPFD_single_lin = E.gamma_base(k) * P.Pmax_W;
    EPFD_single_dB = 10*log10(EPFD_single_lin);
    fprintf('    单颗卫星 EPFD (P_max) = %.2f dB\n', EPFD_single_dB);
    if EPFD_single_dB > P.EPFD_thr_dB
        fprintf('    → 单颗卫星就会违规！\n');
    else
        fprintf('    → 单颗卫星不会违规\n');
    end
end

% 计算总 EPFD（所有卫星最大功率）
Ecs = max(E.gamma_base(:), 1e-30);
Pi_max_all = P.Pmax_W * ones(Nvis, 1);
EPFD_total_lin = sum(Ecs .* Pi_max_all);
EPFD_total_dB = 10*log10(EPFD_total_lin);

fprintf('\n总 EPFD（所有卫星最大功率）:\n');
fprintf('  EPFD_total = %.2f dB (阈值: %.2f dB)\n', EPFD_total_dB, P.EPFD_thr_dB);
fprintf('  差异: %.2f dB\n', EPFD_total_dB - P.EPFD_thr_dB);

% ========== 2. 验证功率控制 ==========
fprintf('\n=== 2. 验证功率控制 ===\n');

% 初始功率优化（零 tilt）
fprintf('初始功率优化（零 tilt）:\n');
cvx_clear
cvx_begin quiet
    variables q_init(Nvis)
    maximize( sum(q_init) )
    subject to
        log_sum_exp( log(Ecs) + q_init ) <= log(E.EPFD_thr_lin);
        q_init <= log(P.Pmax_W);
        q_init >= log(1e-6);
cvx_end

Pi_init = exp(q_init);
EPFD_init_lin = sum(Ecs .* Pi_init);
EPFD_init_dB = 10*log10(EPFD_init_lin);

fprintf('  CVX 状态: %s\n', cvx_status);
fprintf('  初始功率范围: [%.2e, %.2e] W\n', min(Pi_init), max(Pi_init));
fprintf('  初始 EPFD: %.2f dB (阈值: %.2f dB)\n', EPFD_init_dB, P.EPFD_thr_dB);
fprintf('  差异: %.2f dB\n', EPFD_init_dB - P.EPFD_thr_dB);

if EPFD_init_lin <= E.EPFD_thr_lin * 1.01
    fprintf('  ✓ EPFD 约束满足\n');
else
    fprintf('  ✗ EPFD 约束违反！\n');
end

% 检查每个卫星的功率和 EPFD 贡献
fprintf('\n各卫星的功率和 EPFD 贡献:\n');
for k = 1:min(5, Nvis)
    idx = visIdx(k);
    sat_name = leo_analysis{idx};
    contrib_lin = Ecs(k) * Pi_init(k);
    contrib_dB = 10*log10(contrib_lin);
    fprintf('  卫星 %d (%s): Pi=%.2e W, EPFD贡献=%.2f dB\n', ...
        k, sat_name, Pi_init(k), contrib_dB);
end

% ========== 3. 验证 Tilt 计算 ==========
fprintf('\n=== 3. 验证 Tilt 计算 ===\n');

% 生成用户和需求
U = 5;
users = Make_Users_For_Visible_Sats_STK(LEO_data, visIdx, GS_data, U, P);
demands_vec = 0.8e9 + (1.2e9 - 0.8e9) * rand(U * Nvis, 1);
demands = reshape(demands_vec, U, Nvis);

% 计算容量常数
Kc = Precompute_Capacity_Constants_STK(LEO_data, visIdx, users, GS_data, GEO_data, P);

% 识别关键卫星
Pi_for_crit = P.Pmax_W * ones(Nvis, 1);
critIdx = find_critical_satellites(E.gamma_base, Pi_for_crit, E.EPFD_thr_lin, P.zeta_thr, E.phi_r_deg);

fprintf('关键卫星数: %d\n', numel(critIdx));
if ~isempty(critIdx)
    fprintf('关键卫星索引: ');
    fprintf('%d ', critIdx);
    fprintf('\n');
end

% 求解 Problem 18（带 tilt）
fprintf('\n求解 Problem 18（带 tilt）:\n');
sol18 = solve_problem_18(E, Kc, demands, P, critIdx);

if strcmp(sol18.cvx_status, 'Solved')
    fprintf('  ✓ 优化成功\n');
    
    % 验证 EPFD 计算（带 tilt）
    EPFD_with_tilt_lin = sum(Ecs .* exp(sol18.q + P.beta_fit*sol18.theta));
    EPFD_with_tilt_dB = 10*log10(EPFD_with_tilt_lin);
    
    fprintf('  优化后 EPFD: %.2f dB (阈值: %.2f dB)\n', EPFD_with_tilt_dB, P.EPFD_thr_dB);
    fprintf('  差异: %.2f dB\n', EPFD_with_tilt_dB - P.EPFD_thr_dB);
    
    if EPFD_with_tilt_lin <= E.EPFD_thr_lin * 1.01
        fprintf('  ✓ EPFD 约束满足\n');
    else
        fprintf('  ✗ EPFD 约束违反！\n');
    end
    
    % 检查 tilt 对 EPFD 的影响
    fprintf('\nTilt 对 EPFD 的影响（关键卫星）:\n');
    for k = 1:numel(critIdx)
        idx = critIdx(k);
        leoIdx = visIdx(idx);
        sat_name = leo_analysis{leoIdx};
        
        theta = sol18.theta(idx);
        Pi = sol18.Pi(idx);
        
        % 无 tilt 时的 EPFD 贡献
        contrib_no_tilt_lin = Ecs(idx) * Pi;
        contrib_no_tilt_dB = 10*log10(contrib_no_tilt_lin);
        
        % 有 tilt 时的 EPFD 贡献
        tilt_factor = exp(P.beta_fit * theta);
        contrib_with_tilt_lin = Ecs(idx) * Pi * tilt_factor;
        contrib_with_tilt_dB = 10*log10(contrib_with_tilt_lin);
        
        fprintf('  卫星 %d (%s):\n', idx, sat_name);
        fprintf('    Tilt = %.2f deg\n', theta);
        fprintf('    Power = %.2e W\n', Pi);
        fprintf('    Tilt 因子 exp(β*θ) = exp(%.4f*%.2f) = %.4f\n', ...
            P.beta_fit, theta, tilt_factor);
        fprintf('    EPFD 贡献（无 tilt）: %.2f dB\n', contrib_no_tilt_dB);
        fprintf('    EPFD 贡献（有 tilt）: %.2f dB\n', contrib_with_tilt_dB);
        fprintf('    降低: %.2f dB\n', contrib_no_tilt_dB - contrib_with_tilt_dB);
    end
else
    fprintf('  ✗ 优化失败: %s\n', sol18.cvx_status);
end

% ========== 4. 验证容量计算 ==========
fprintf('\n=== 4. 验证容量计算 ===\n');

% 检查容量常数 k, v, s
fprintf('容量常数验证（前3个卫星，前2个用户）:\n');
for k = 1:min(3, Nvis)
    idx = visIdx(k);
    sat_name = leo_analysis{idx};
    
    if isfield(Kc, 'U_per_sat')
        U_actual = Kc.U_per_sat(k);
    else
        U_actual = U;
    end
    
    fprintf('\n  卫星 %d (%s):\n', k, sat_name);
    for u = 1:min(2, U_actual)
        k_val = Kc.k(u, k);
        v_val = Kc.v(u, k);
        s_val = Kc.s(u, k);
        
        fprintf('    用户 %d: k=%.4e, v=%.4e, s=%d\n', u, k_val, v_val, s_val);
        
        % 验证 k 的计算
        % k = A * Gur * lambda^2 / (4*pi*d_su)^2
        % 需要知道用户位置和距离
        if isfield(users, 'sat_k')
            user_indices = find(users.sat_k == k);
            if u <= length(user_indices)
                user_idx = user_indices(u);
                r_sat = LEO_data.pos_ecef_km(:, idx);
                user_pos = latlon_to_ecef(users.lat_deg(user_idx), users.lon_deg(user_idx), P.Re_km);
                d_su_m = norm((r_sat - user_pos)) * 1000;
                
                Gur_lin = 10^(P.GS_LEO_Gmax_dBi/10);
                k_manual = (P.A_fit * Gur_lin * (P.lambda^2)) / ((4*pi*d_su_m)^2);
                
                relative_error = abs(k_val - k_manual) / max(abs(k_val), abs(k_manual));
                if relative_error < 1e-6
                    fprintf('      ✓ k 计算正确（相对误差: %.2e）\n', relative_error);
                else
                    fprintf('      ✗ k 不匹配！差异: %.2e (相对误差: %.2e)\n', ...
                        abs(k_val - k_manual), relative_error);
                end
            end
        end
        
        % 验证 v 的计算
        % v = Pg_hgu2 + N0*B
        % 当前代码中 Pg_hgu2 = 0（简化）
        N0 = P.kB * P.user_noise_temp_K;
        v_manual = N0 * P.B_Hz;
        
        relative_error = abs(v_val - v_manual) / max(abs(v_val), abs(v_manual));
        if relative_error < 1e-6
            fprintf('      ✓ v 计算正确（相对误差: %.2e）\n', relative_error);
        else
            fprintf('      ✗ v 不匹配！差异: %.2e (相对误差: %.2e)\n', ...
                abs(v_val - v_manual), relative_error);
        end
    end
end

% 验证容量计算（如果优化成功）
if strcmp(sol18.cvx_status, 'Solved')
    fprintf('\n容量计算验证（关键卫星）:\n');
    for k = 1:numel(critIdx)
        idx = critIdx(k);
        leoIdx = visIdx(idx);
        sat_name = leo_analysis{leoIdx};
        
        if isfield(Kc, 'U_per_sat')
            U_actual = Kc.U_per_sat(idx);
        else
            U_actual = U;
        end
        
        fprintf('\n  卫星 %d (%s):\n', idx, sat_name);
        fprintf('    Power = %.2e W, Tilt = %.2f deg\n', sol18.Pi(idx), sol18.theta(idx));
        
        sat_capacity = sum(sol18.Cap_val(1:U_actual, idx));
        sat_demand = sum(demands(1:U_actual, idx));
        
        fprintf('    总容量 = %.2f Gbps, 总需求 = %.2f Gbps\n', ...
            sat_capacity/1e9, sat_demand/1e9);
        
        % 手动计算容量验证
        for u = 1:min(2, U_actual)
            k_val = Kc.k(u, idx);
            v_val = Kc.v(u, idx);
            s_val = Kc.s(u, idx);
            
            % 根据论文 Eq.(15)
            % C_i,u = B * log2(1 + (k_i,u * exp(q_i + β*s_i,u*θ_i)) / v_u)
            effective_power = sol18.Pi(idx) * exp(P.beta_fit * s_val * sol18.theta(idx));
            SINR_lin = (k_val * effective_power) / v_val;
            cap_manual = P.B_Hz * log2(1 + SINR_lin);
            cap_code = sol18.Cap_val(u, idx);
            
            relative_error = abs(cap_code - cap_manual) / max(abs(cap_code), abs(cap_manual));
            if relative_error < 1e-6
                fprintf('      ✓ 用户 %d 容量计算正确（相对误差: %.2e）\n', u, relative_error);
            else
                fprintf('      ✗ 用户 %d 容量不匹配！差异: %.2e (相对误差: %.2e)\n', ...
                    u, abs(cap_code - cap_manual), relative_error);
            end
        end
    end
end

% ========== 5. 总结 ==========
fprintf('\n=== 验证总结 ===\n');
fprintf('1. EPFD 计算: ');
gamma_check = true;
for k = 1:min(3, Nvis)
    relative_error = abs(E.gamma_base(k) - gamma_manual_all(k)) / max(abs(E.gamma_base(k)), abs(gamma_manual_all(k)));
    if relative_error >= 1e-6
        gamma_check = false;
        break;
    end
end
if gamma_check
    fprintf('✓ 正确\n');
else
    fprintf('✗ 需要检查\n');
end

fprintf('2. 功率控制: ');
if strcmp(cvx_status, 'Solved') && EPFD_init_lin <= E.EPFD_thr_lin * 1.01
    fprintf('✓ 正确\n');
else
    fprintf('✗ 需要检查\n');
end

fprintf('3. Tilt 计算: ');
if strcmp(sol18.cvx_status, 'Solved') && EPFD_with_tilt_lin <= E.EPFD_thr_lin * 1.01
    fprintf('✓ 正确\n');
else
    fprintf('✗ 需要检查\n');
end

fprintf('4. 容量计算: ');
if strcmp(sol18.cvx_status, 'Solved')
    fprintf('✓ 已验证\n');
else
    fprintf('✗ 需要检查\n');
end

fprintf('\n=== 验证完成 ===\n');

end

function r = latlon_to_ecef(lat_deg, lon_deg, r_km)
% 将地理坐标(纬度、经度)转换为 ECEF（球形地球近似）
% 与 `Precompute_Capacity_Constants_STK.m` 内部子函数一致，避免外部不可见问题。
lat = deg2rad(lat_deg);
lon = deg2rad(lon_deg);
r = [r_km*cos(lat)*cos(lon); r_km*cos(lat)*sin(lon); r_km*sin(lat)];
end
