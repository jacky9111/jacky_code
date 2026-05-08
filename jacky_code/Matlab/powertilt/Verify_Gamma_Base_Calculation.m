function Verify_Gamma_Base_Calculation(E, P, visIdx, leo_analysis, GS_data, GEO_data)
% ============================================================
% Verify_Gamma_Base_Calculation
% 验证 gamma_base 计算是否正确
% ============================================================

fprintf('\n=== 验证 gamma_base 计算 ===\n');

Nvis = numel(visIdx);

% 获取第一个 GS 的位置
gs_idx = 1;
r_gs = GS_data.pos_ecef_km(:, gs_idx) * 1000;  % m
r_gso = GEO_data.pos_ecef_km(:, gs_idx) * 1000;  % m
v_bore = (r_gso - r_gs);

% 参数
BWref_Hz = P.BWref_Hz;
G_Gmax_lin = 10^(P.GSO_Gmax_dBi/10);

fprintf('参数验证:\n');
fprintf('  A_fit = %.4e\n', P.A_fit);
fprintf('  beta_fit = %.4f (1/deg)\n', P.beta_fit);
fprintf('  BWref_Hz = %.0f Hz\n', BWref_Hz);
fprintf('  G_Gmax_dBi = %.2f dBi\n', P.GSO_Gmax_dBi);
fprintf('  G_Gmax_lin = %.4e\n', G_Gmax_lin);
fprintf('  D_ref_m = %.2f m\n', P.D_ref_m);
fprintf('  lambda = %.6f m\n', P.lambda);

% 手动计算 gamma_base 验证（针对关键卫星）
fprintf('\n手动计算验证（针对关键卫星）:\n');

% 找出贡献最大的卫星（通常是关键卫星）
Ecs = max(E.gamma_base(:), 1e-30);
Pi_max_all = P.Pmax_W * ones(Nvis, 1);
contributions = Ecs .* Pi_max_all;
[~, max_idx] = max(contributions);

for k = 1:min(3, Nvis)  % 验证前3个，包括贡献最大的
    idx = visIdx(k);
    sat_name = leo_analysis{idx};
    
    % 从 E 结构获取值
    phi_r = E.phi_r_deg(k);
    phi_t = E.phi_t_deg(k);
    d_m = E.d_m(k);
    gamma_base_code = E.gamma_base(k);
    
    % 手动计算
    % 1. GSO 接收增益 G_G^r(φ_i^r)（绝对增益；不要再乘 G_Gmax）
    GGr_abs_dB = gso_rx_gain_itu1428(phi_r, P.D_ref_m, P.lambda);
    GGr_abs_lin = 10^(GGr_abs_dB/10);
    
    % 2. 发射端指数衰减使用 phi_t（sat->GS 离轴角）
    exp_beta_phi_t = exp(P.beta_fit * phi_t);
    
    % 3. 分母：BW_ref * 4π * d_i^2 * G_Gmax
    denominator = BWref_Hz * 4*pi*d_m^2 * G_Gmax_lin;
    
    % 4. gamma_base
    gamma_base_manual = (P.A_fit * GGr_abs_lin * exp_beta_phi_t) / denominator;
    
    % 显示结果
    fprintf('\n  卫星 %d (%s):\n', k, sat_name);
    fprintf('    phi_r = %.4f deg\n', phi_r);
    fprintf('    phi_t = %.4f deg\n', phi_t);
    fprintf('    d = %.1f km\n', d_m/1000);
    fprintf('    GGr_abs_lin = %.4e\n', GGr_abs_lin);
    fprintf('    exp(β*phi_t) = exp(%.4f*%.4f) = %.4e\n', P.beta_fit, phi_t, exp_beta_phi_t);
    fprintf('    denominator = %.4e * %.4e * %.4e = %.4e\n', ...
        BWref_Hz, 4*pi*d_m^2, G_Gmax_lin, denominator);
    fprintf('    gamma_base (代码) = %.4e\n', gamma_base_code);
    fprintf('    gamma_base (手动) = %.4e\n', gamma_base_manual);
    
    % 验证
    rel_error = abs(gamma_base_code - gamma_base_manual) / max(abs(gamma_base_code), abs(gamma_base_manual));
    if rel_error < 1e-6
        fprintf('    ✓ 计算正确（相对误差: %.2e）\n', rel_error);
    else
        fprintf('    ✗ 计算不匹配（相对误差: %.2e）\n', rel_error);
    end
    
    % 如果是贡献最大的卫星，显示更多信息
    if k == max_idx
        fprintf('    [这是贡献最大的卫星]\n');
        fprintf('    使用最大功率 P_max = %.1f W 时的 EPFD 贡献:\n', P.Pmax_W);
        contrib_lin = gamma_base_code * P.Pmax_W;
        contrib_dB = 10*log10(contrib_lin);
        fprintf('      贡献 = %.4e (线性) = %.2f dB\n', contrib_lin, contrib_dB);
        fprintf('      归一化贡献 = %.4e / %.4e = %.4e\n', ...
            contrib_lin, E.EPFD_thr_lin, contrib_lin / E.EPFD_thr_lin);
    end
end

% 验证 EPFD 公式
fprintf('\n=== 验证 EPFD 公式 ===\n');
fprintf('根据论文 Eq.(16):\n');
fprintf('  EPFD = 10 log10(Σ (A * G_G^r(φ_i^r) * exp(q_i + β(φ_i^r + θ_i))) / (BW_ref * 4πd_i^2 * G_Gmax))\n');
fprintf('\n展开为:\n');
fprintf('  EPFD = 10 log10(Σ (A * G_G^r(φ_i^r) * exp(β*φ_i^r) * exp(q_i) * exp(β*θ_i)) / (BW_ref * 4πd_i^2 * G_Gmax))\n');
fprintf('\n在本项目实现中：\n');
fprintf('  gamma_base = (A * G_G^r(phi_r) * exp(β*phi_t)) / (BW_ref * 4πd_i^2 * G_Gmax)\n');
fprintf('所以 EPFD = 10 log10(Σ gamma_base * exp(q_i) * exp(β*θ_i))\n');
fprintf('在 log 空间中: log_sum_exp(log(gamma_base) + q_i + β*θ_i) <= log(EPFD_thr)\n');

% 验证使用最大功率时的 EPFD
fprintf('\n验证使用最大功率（零 tilt）时的 EPFD:\n');
EPFD_max_lin = sum(Ecs .* Pi_max_all);
EPFD_max_dB = 10*log10(EPFD_max_lin);
fprintf('  EPFD_max = %.4e (线性) = %.2f dB\n', EPFD_max_lin, EPFD_max_dB);
fprintf('  EPFD_thr = %.4e (线性) = %.2f dB\n', E.EPFD_thr_lin, P.EPFD_thr_dB);
fprintf('  差异 = %.2f dB\n', EPFD_max_dB - P.EPFD_thr_dB);

if EPFD_max_dB > P.EPFD_thr_dB
    power_reduction_factor = 10^((EPFD_max_dB - P.EPFD_thr_dB) / 10);
    fprintf('  需要将功率降低 %.2f 倍（或 %.2f dB）才能满足约束\n', ...
        power_reduction_factor, EPFD_max_dB - P.EPFD_thr_dB);
end

fprintf('\n=== 验证完成 ===\n');

end
