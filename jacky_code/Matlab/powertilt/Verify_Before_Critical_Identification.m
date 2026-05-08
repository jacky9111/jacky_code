function Verify_Before_Critical_Identification(E, Pi_init, P, visIdx, leo_analysis)
% ============================================================
% Verify_Before_Critical_Identification
% 验证识别关键卫星之前的所有计算
% ============================================================

fprintf('\n=== 验证识别关键卫星之前的计算 ===\n');

Nvis = numel(visIdx);

%% ========== 1. 验证 EPFD_thr_lin ==========
fprintf('\n1. EPFD 阈值验证:\n');
EPFD_thr_lin_calc = 10^(P.EPFD_thr_dB/10);
fprintf('  EPFD_thr_dB = %.2f dB\n', P.EPFD_thr_dB);
fprintf('  EPFD_thr_lin (计算) = 10^(%.2f/10) = %.6e\n', P.EPFD_thr_dB, EPFD_thr_lin_calc);
fprintf('  EPFD_thr_lin (从E) = %.6e\n', E.EPFD_thr_lin);
if abs(EPFD_thr_lin_calc - E.EPFD_thr_lin) < 1e-20
    fprintf('  ✓ EPFD_thr_lin 计算正确\n');
else
    fprintf('  ✗ EPFD_thr_lin 不匹配！差异: %.2e\n', abs(EPFD_thr_lin_calc - E.EPFD_thr_lin));
end

%% ========== 2. 验证 gamma_base 计算 ==========
fprintf('\n2. gamma_base 验证:\n');
fprintf('  参数:\n');
fprintf('    A_fit = %.4e\n', P.A_fit);
fprintf('    beta_fit = %.4f (1/deg)\n', P.beta_fit);
fprintf('    BWref_Hz = %.0f Hz\n', P.BWref_Hz);
fprintf('    GSO_Gmax_dBi = %.2f dBi\n', P.GSO_Gmax_dBi);
G_Gmax_lin = 10^(P.GSO_Gmax_dBi/10);
fprintf('    G_Gmax_lin = %.4e\n', G_Gmax_lin);

fprintf('\n  各卫星的 gamma_base:\n');
for k = 1:min(3, Nvis)  % 只显示前3个
    idx = visIdx(k);
    sat_name = leo_analysis{idx};
    
    % 手动计算 gamma_base 验证
    phi_r = E.phi_r_deg(k);
    phi_t = E.phi_t_deg(k);
    d_m = E.d_m(k);
    
    % GSO 接收增益（绝对增益；不要再乘 G_Gmax）
    GGr_abs_dB = gso_rx_gain_itu1428(phi_r, P.D_ref_m, P.lambda);
    GGr_abs_lin = 10^(GGr_abs_dB/10);
    
    % gamma_base（与 Precompute_EPFD_Terms_STK 一致：exp 使用 phi_t）
    gamma_manual = (P.A_fit * GGr_abs_lin * exp(P.beta_fit * phi_t)) / ...
                    (P.BWref_Hz * 4*pi*d_m^2 * G_Gmax_lin);
    
    fprintf('    卫星 %d (%s):\n', k, sat_name);
    fprintf('      phi_r = %.2f deg, phi_t = %.2f deg, d = %.1f km\n', phi_r, phi_t, d_m/1000);
    fprintf('      GGr_abs_dB = %.2f dB, GGr_abs_lin = %.4e\n', GGr_abs_dB, GGr_abs_lin);
    fprintf('      exp(beta*phi_t) = %.4f\n', exp(P.beta_fit * phi_t));
    fprintf('      gamma_base (代码) = %.4e\n', E.gamma_base(k));
    fprintf('      gamma_base (手动) = %.4e\n', gamma_manual);
    if abs(E.gamma_base(k) - gamma_manual) / max(abs(E.gamma_base(k)), abs(gamma_manual)) < 1e-6
        fprintf('      ✓ gamma_base 计算正确\n');
    else
        fprintf('      ✗ gamma_base 不匹配！差异: %.2e\n', abs(E.gamma_base(k) - gamma_manual));
    end
end

%% ========== 3. 验证初始功率优化 ==========
fprintf('\n3. 初始功率优化验证:\n');
Ecs = max(E.gamma_base(:), 1e-30);
fprintf('  Ecs 范围: [%.4e, %.4e]\n', min(Ecs), max(Ecs));

% 计算总 EPFD（使用初始功率）
EPFD_total_lin = sum(Ecs .* Pi_init);
EPFD_total_dB = 10*log10(EPFD_total_lin);
fprintf('  总 EPFD (使用初始功率) = %.2f dB\n', EPFD_total_dB);
fprintf('  EPFD 阈值 = %.2f dB\n', P.EPFD_thr_dB);
fprintf('  差异 = %.2f dB\n', EPFD_total_dB - P.EPFD_thr_dB);

if EPFD_total_lin <= E.EPFD_thr_lin * 1.01  % 允许1%误差
    fprintf('  ✓ EPFD 约束满足\n');
else
    fprintf('  ✗ EPFD 约束违反！\n');
end

% 检查每个卫星的贡献
fprintf('\n  各卫星的 EPFD 贡献:\n');
for k = 1:Nvis
    idx = visIdx(k);
    sat_name = leo_analysis{idx};
    contrib_lin = Ecs(k) * Pi_init(k);
    contrib_dB = 10*log10(contrib_lin);
    normalized_contrib = contrib_lin / E.EPFD_thr_lin;
    fprintf('    卫星 %d (%s): Pi=%.2e W, 贡献=%.2f dB, 归一化=%.6e\n', ...
        k, sat_name, Pi_init(k), contrib_dB, normalized_contrib);
end

%% ========== 4. 验证归一化贡献计算 ==========
fprintf('\n4. 归一化贡献验证:\n');
fprintf('  根据论文 Algorithm 1 Step 4:\n');
fprintf('  归一化贡献 = γ_i * p_i / 10^(EPFD_thr/10)\n');
fprintf('  其中 10^(EPFD_thr/10) = EPFD_thr_lin = %.6e\n', E.EPFD_thr_lin);

normalized_contrib_all = (E.gamma_base .* Pi_init) / E.EPFD_thr_lin;
fprintf('\n  各卫星的归一化贡献:\n');
for k = 1:Nvis
    idx = visIdx(k);
    sat_name = leo_analysis{idx};
    fprintf('    卫星 %d (%s): %.6e\n', k, sat_name, normalized_contrib_all(k));
end

fprintf('\n  归一化贡献范围: [%.6e, %.6e]\n', min(normalized_contrib_all), max(normalized_contrib_all));
fprintf('  阈值 zeta_thr = %.2f\n', P.zeta_thr);
fprintf('  满足条件的卫星数: %d\n', sum(normalized_contrib_all >= P.zeta_thr));

%% ========== 5. 检查为什么所有归一化贡献都相同 ==========
fprintf('\n5. 检查归一化贡献是否异常:\n');
if std(normalized_contrib_all) < 1e-10
    fprintf('  ⚠ 警告：所有卫星的归一化贡献几乎相同！\n');
    fprintf('  这可能是因为初始功率优化将所有卫星的功率都限制得很小。\n');
    fprintf('  检查：所有卫星的 gamma_base * Pi_init 是否都接近 EPFD_thr_lin / N？\n');
    
    % 检查是否所有卫星的贡献都相等
    contrib_products = E.gamma_base .* Pi_init;
    fprintf('  gamma_base * Pi_init 范围: [%.6e, %.6e]\n', min(contrib_products), max(contrib_products));
    fprintf('  平均值: %.6e\n', mean(contrib_products));
    fprintf('  EPFD_thr_lin / N = %.6e\n', E.EPFD_thr_lin / Nvis);
    
    if abs(mean(contrib_products) - E.EPFD_thr_lin / Nvis) < 1e-20
        fprintf('  ✓ 确认：优化器将所有卫星的贡献平均分配\n');
    end
end

fprintf('\n=== 验证完成 ===\n');

end