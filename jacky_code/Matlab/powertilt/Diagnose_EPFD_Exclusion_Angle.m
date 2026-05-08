function Diagnose_EPFD_Exclusion_Angle(root, leo_analysis, geo_analysis, tStr)
% ============================================================
% Diagnose_EPFD_Exclusion_Angle
% 诊断 EPFD 计算并确定排除角
%
% 分析不同 phi_r 值下的 EPFD，找出使得 EPFD = 阈值的 phi_r（排除角）
% ============================================================

addpath(fullfile(pwd, 'Matlab', 'powertilt'));

P = paper_params();

fprintf('\n=== EPFD 诊断：确定排除角 ===\n');

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

fprintf('\n=== 当前状态分析 ===\n');
fprintf('EPFD 阈值: %.2f dB\n', P.EPFD_thr_dB);
fprintf('最大功率: %.2f W\n', P.Pmax_W);

% 计算当前所有卫星使用最大功率时的 EPFD
Ecs = max(E.gamma_base(:), 1e-30);
Pi_max_all = P.Pmax_W * ones(Nvis, 1);
EPFD_max_lin = sum(Ecs .* Pi_max_all);
EPFD_max_dB = 10*log10(EPFD_max_lin);

fprintf('\n所有可见卫星使用最大功率时的 EPFD:\n');
fprintf('  EPFD = %.2f dB (阈值: %.2f dB)\n', EPFD_max_dB, P.EPFD_thr_dB);
fprintf('  EPFD 超过阈值: %.2f dB\n', EPFD_max_dB - P.EPFD_thr_dB);

% 显示每个卫星的贡献
fprintf('\n各卫星的 EPFD 贡献（使用最大功率）:\n');
fprintf('%-8s %-12s %-15s %-12s %-12s %-15s\n', ...
    'Sat', 'phi_r(deg)', 'gamma_base', '距离(km)', '贡献(dB)', '累积EPFD(dB)');
cumulative_EPFD_lin = 0;
for k = 1:Nvis
    idx = visIdx(k);
    sat_name = leo_analysis{idx};
    contribution_lin = Ecs(k) * P.Pmax_W;
    cumulative_EPFD_lin = cumulative_EPFD_lin + contribution_lin;
    cumulative_EPFD_dB = 10*log10(cumulative_EPFD_lin);
    
    fprintf('%-8d %-12.2f %-15.4e %-12.1f %-12.2f %-15.2f\n', ...
        k, E.phi_r_deg(k), E.gamma_base(k), E.d_m(k)/1000, ...
        10*log10(contribution_lin), cumulative_EPFD_dB);
end

% ===== 分析单个卫星的 EPFD 贡献 =====
fprintf('\n=== 单个卫星的 EPFD 贡献分析 ===\n');
fprintf('假设只有一颗卫星，使用最大功率，分析不同 phi_r 下的 EPFD:\n');

% 选择一个典型的卫星作为参考
ref_idx = 1;
ref_d = E.d_m(ref_idx);  % 参考距离
ref_phi_t = E.phi_t_deg(ref_idx);  % 参考 phi_t

fprintf('参考参数:\n');
fprintf('  距离: %.1f km\n', ref_d/1000);
fprintf('  phi_t: %.2f deg\n', ref_phi_t);

% 计算不同 phi_r 下的 EPFD
phi_r_test = 0:0.1:10;  % 0 到 10 度
EPFD_single = zeros(size(phi_r_test));

fprintf('\nphi_r 与 EPFD 的关系（单颗卫星，最大功率）:\n');
fprintf('%-10s %-15s %-15s %-15s %-15s\n', ...
    'phi_r(deg)', 'G_r_rel(dB)', 'G_r_abs(dB)', 'kappa', 'EPFD(dB)');

for i = 1:length(phi_r_test)
    phi_r = phi_r_test(i);
    
    % 计算接收增益
    GGr_rel_dB = gso_rx_gain_itu672(phi_r, P.D_ref_m, P.lambda);
    GGr_rel_lin = 10^(GGr_rel_dB/10);
    GGr_max_lin = 10^(P.GSO_Gmax_dBi/10);
    GGr_abs_lin = GGr_max_lin * GGr_rel_lin;
    
    % 计算 kappa
    G_t_max_lin = 10^(P.LEO_Gmax_dBi/10);
    kappa = (G_t_max_lin * GGr_abs_lin) / (P.BWref_Hz * 4*pi*ref_d^2);
    
    % 计算 gamma_base
    gamma_base = kappa * exp(P.beta_fit * ref_phi_t);
    
    % 计算 EPFD（单颗卫星，最大功率）
    EPFD_lin = gamma_base * P.Pmax_W;
    EPFD_dB = 10*log10(EPFD_lin);
    EPFD_single(i) = EPFD_dB;
    
    if mod(i, 5) == 1 || abs(EPFD_dB - P.EPFD_thr_dB) < 1
        fprintf('%-10.1f %-15.2f %-15.2f %-15.4e %-15.2f', ...
            phi_r, GGr_rel_dB, 10*log10(GGr_abs_lin), kappa, EPFD_dB);
        if EPFD_dB > P.EPFD_thr_dB
            fprintf(' [违规]\n');
        else
            fprintf(' [OK]\n');
        end
    end
end

% 找出排除角（EPFD = 阈值时的 phi_r）
fprintf('\n=== 排除角分析 ===\n');
% 找到 EPFD 刚好等于或小于阈值的 phi_r
violation_idx = find(EPFD_single > P.EPFD_thr_dB);
if ~isempty(violation_idx)
    if violation_idx(end) < length(phi_r_test)
        % 找到第一个不违规的 phi_r
        ok_idx = find(EPFD_single <= P.EPFD_thr_dB);
        if ~isempty(ok_idx)
            exclusion_angle = phi_r_test(ok_idx(1));
            fprintf('排除角（单颗卫星）: 约 %.2f 度\n', exclusion_angle);
            fprintf('  当 phi_r >= %.2f 度时，单颗卫星使用最大功率不会导致 EPFD 违规\n', exclusion_angle);
        else
            fprintf('警告：即使 phi_r = %.1f 度，单颗卫星的 EPFD 仍然违规\n', phi_r_test(end));
            fprintf('  排除角不存在（或非常大）\n');
            fprintf('  可能原因：EPFD 阈值设置过严，或增益模型需要调整\n');
        end
    else
        fprintf('警告：即使 phi_r = %.1f 度，单颗卫星的 EPFD 仍然违规\n', phi_r_test(end));
        fprintf('  排除角不存在（或非常大）\n');
        fprintf('  可能原因：EPFD 阈值设置过严，或增益模型需要调整\n');
    end
else
    fprintf('即使 phi_r = 0，单颗卫星的 EPFD 也不会违规\n');
    fprintf('  可能需要检查 EPFD 计算或参数设置\n');
end

% ===== 分析多颗卫星的情况 =====
fprintf('\n=== 多颗卫星的 EPFD 分析 ===\n');
fprintf('当前可见卫星数: %d\n', Nvis);
fprintf('总 EPFD: %.2f dB (阈值: %.2f dB)\n', EPFD_max_dB, P.EPFD_thr_dB);

% 分析如果只有目标卫星（ow1_30）的情况
target_sat = 'ow1_30';
target_idx = find(strcmp(LEO_data.names, target_sat));
if ~isempty(target_idx) && ismember(target_idx, visIdx)
    vis_target_idx = find(visIdx == target_idx);
    phi_r_target = E.phi_r_deg(vis_target_idx);
    
    % 计算只有目标卫星时的 EPFD
    EPFD_target_only_lin = Ecs(vis_target_idx) * P.Pmax_W;
    EPFD_target_only_dB = 10*log10(EPFD_target_only_lin);
    
    fprintf('\n如果只有目标卫星 %s:\n', target_sat);
    fprintf('  phi_r: %.2f deg\n', phi_r_target);
    fprintf('  EPFD: %.2f dB (阈值: %.2f dB)\n', EPFD_target_only_dB, P.EPFD_thr_dB);
    if EPFD_target_only_dB > P.EPFD_thr_dB
        fprintf('  → 单颗卫星就会违规！\n');
    else
        fprintf('  → 单颗卫星不会违规，但多颗卫星叠加会违规\n');
    end
end

% ===== 建议 =====
fprintf('\n=== 诊断建议 ===\n');
if EPFD_max_dB > P.EPFD_thr_dB
    fprintf('问题：EPFD 始终超过阈值\n');
    fprintf('可能原因：\n');
    fprintf('  1. 可见卫星数量过多（当前: %d 颗）\n', Nvis);
    fprintf('  2. EPFD 计算可能有问题（gamma_base 或 kappa）\n');
    fprintf('  3. EPFD 阈值设置可能过严\n');
    fprintf('  4. 距离或增益计算可能有误\n');
    
    fprintf('\n建议：\n');
    fprintf('  1. 检查 gamma_base 值是否合理\n');
    fprintf('  2. 检查距离 d_m 是否合理（LEO 高度约 1200 km）\n');
    fprintf('  3. 检查接收增益 G_r 是否合理\n');
    fprintf('  4. 考虑只分析单颗卫星的情况\n');
end

fprintf('\n=== 诊断完成 ===\n');

end