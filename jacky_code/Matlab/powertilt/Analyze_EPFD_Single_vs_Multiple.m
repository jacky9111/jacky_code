function Analyze_EPFD_Single_vs_Multiple(root, leo_analysis, geo_analysis, tStr)
    % ============================================================
    % Analyze_EPFD_Single_vs_Multiple
    % 分析单颗卫星 vs 多颗卫星的 EPFD 计算和排除角
    %
    % 目的：
    % 1. 验证单颗卫星的排除角是否接近 1.20 度
    % 2. 分析多颗卫星叠加时的 EPFD 和排除角
    % 3. 找出为什么多颗卫星叠加时排除角会变小（从 1.20 度变为约 0.75 度）
    % ============================================================
    
    addpath(fullfile(pwd, 'Matlab', 'powertilt'));
    
    P = paper_params();
    
    fprintf('\n=== EPFD 分析：单颗 vs 多颗卫星 ===\n');
    fprintf('EPFD 阈值: %.2f dB (论文 Table 1)\n', P.EPFD_thr_dB);
    
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
    
    % ========== 分析 1: 单颗卫星的排除角 ==========
    fprintf('\n=== 分析 1: 单颗卫星的排除角 ===\n');
    
    % 选择一个典型的卫星作为参考
    ref_idx = 1;
    ref_d = E.d_m(ref_idx);  % 参考距离
    ref_phi_t = E.phi_t_deg(ref_idx);  % 参考 phi_t
    
    fprintf('参考参数:\n');
    fprintf('  距离: %.1f km\n', ref_d/1000);
    fprintf('  phi_t: %.2f deg\n', ref_phi_t);
    
    % 计算不同 phi_r 下的 EPFD（单颗卫星）
    phi_r_test = 0:0.01:2;  % 0 到 2 度，更精细
    EPFD_single = zeros(size(phi_r_test));
    
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
    end
    
    % 找出单颗卫星的排除角
    violation_idx_single = find(EPFD_single > P.EPFD_thr_dB);
    if ~isempty(violation_idx_single)
        if violation_idx_single(end) < length(phi_r_test)
            ok_idx_single = find(EPFD_single <= P.EPFD_thr_dB);
            if ~isempty(ok_idx_single)
                exclusion_angle_single = phi_r_test(ok_idx_single(1));
                fprintf('单颗卫星排除角: %.2f 度\n', exclusion_angle_single);
            else
                exclusion_angle_single = NaN;
                fprintf('单颗卫星排除角: 不存在（所有角度都违规）\n');
            end
        else
            exclusion_angle_single = NaN;
            fprintf('单颗卫星排除角: 不存在（所有角度都违规）\n');
        end
    else
        exclusion_angle_single = NaN;
        fprintf('单颗卫星排除角: 不存在（所有角度都不违规）\n');
    end
    
    % ========== 分析 2: 多颗卫星叠加的排除角 ==========
    fprintf('\n=== 分析 2: 多颗卫星叠加的排除角 ===\n');
    
    % 假设目标卫星在不同 phi_r 位置，其他卫星保持当前位置
    % 分析当目标卫星在不同 phi_r 时，总 EPFD 的变化
    
    target_sat = 'ow1_30';
    target_idx = find(strcmp(LEO_data.names, target_sat));
    if isempty(target_idx) || ~ismember(target_idx, visIdx)
        error('未找到目标卫星 %s', target_sat);
    end
    
    vis_target_idx = find(visIdx == target_idx);
    target_d = E.d_m(vis_target_idx);
    target_phi_t = E.phi_t_deg(vis_target_idx);
    
    fprintf('目标卫星: %s\n', target_sat);
    fprintf('  距离: %.1f km\n', target_d/1000);
    fprintf('  phi_t: %.2f deg\n', target_phi_t);
    
    % 计算其他卫星的贡献（固定）
    other_sat_indices = setdiff(1:Nvis, vis_target_idx);
    EPFD_other_lin = 0;
    if ~isempty(other_sat_indices)
        for k = other_sat_indices
            EPFD_other_lin = EPFD_other_lin + E.gamma_base(k) * P.Pmax_W;
        end
        EPFD_other_dB = 10*log10(EPFD_other_lin);
        fprintf('其他 %d 颗卫星的总 EPFD: %.2f dB\n', numel(other_sat_indices), EPFD_other_dB);
    else
        fprintf('没有其他可见卫星\n');
    end
    
    % 分析目标卫星在不同 phi_r 时的总 EPFD
    EPFD_total = zeros(size(phi_r_test));
    
    for i = 1:length(phi_r_test)
        phi_r = phi_r_test(i);
        
        % 计算目标卫星在当前 phi_r 下的贡献
        GGr_rel_dB = gso_rx_gain_itu672(phi_r, P.D_ref_m, P.lambda);
        GGr_rel_lin = 10^(GGr_rel_dB/10);
        GGr_max_lin = 10^(P.GSO_Gmax_dBi/10);
        GGr_abs_lin = GGr_max_lin * GGr_rel_lin;
        
        G_t_max_lin = 10^(P.LEO_Gmax_dBi/10);
        kappa_target = (G_t_max_lin * GGr_abs_lin) / (P.BWref_Hz * 4*pi*target_d^2);
        gamma_base_target = kappa_target * exp(P.beta_fit * target_phi_t);
        
        EPFD_target_lin = gamma_base_target * P.Pmax_W;
        
        % 总 EPFD = 目标卫星 + 其他卫星
        EPFD_total_lin = EPFD_target_lin + EPFD_other_lin;
        EPFD_total(i) = 10*log10(EPFD_total_lin);
    end
    
    % 找出多颗卫星叠加的排除角
    violation_idx_total = find(EPFD_total > P.EPFD_thr_dB);
    if ~isempty(violation_idx_total)
        if violation_idx_total(end) < length(phi_r_test)
            ok_idx_total = find(EPFD_total <= P.EPFD_thr_dB);
            if ~isempty(ok_idx_total)
                exclusion_angle_total = phi_r_test(ok_idx_total(1));
                fprintf('多颗卫星叠加排除角: %.2f 度\n', exclusion_angle_total);
            else
                exclusion_angle_total = NaN;
                fprintf('多颗卫星叠加排除角: 不存在（所有角度都违规）\n');
            end
        else
            exclusion_angle_total = NaN;
            fprintf('多颗卫星叠加排除角: 不存在（所有角度都违规）\n');
        end
    else
        exclusion_angle_total = NaN;
        fprintf('多颗卫星叠加排除角: 不存在（所有角度都不违规）\n');
    end
    
    % ========== 对比分析 ==========
    fprintf('\n=== 对比分析 ===\n');
    fprintf('单颗卫星排除角: %.2f 度\n', exclusion_angle_single);
    fprintf('多颗卫星叠加排除角: %.2f 度\n', exclusion_angle_total);
    fprintf('论文中的排除角: 约 ±0.75 度\n');
    fprintf('差异: %.2f 度\n', exclusion_angle_total - 0.75);
    
    % 绘制对比图
    figure('Name', 'EPFD: 单颗 vs 多颗卫星', 'Position', [100, 100, 1000, 600]);
    
    subplot(1, 2, 1);
    plot(phi_r_test, EPFD_single, 'b-', 'LineWidth', 2);
    hold on;
    plot([0, max(phi_r_test)], [P.EPFD_thr_dB, P.EPFD_thr_dB], 'r--', 'LineWidth', 1.5);
    if ~isnan(exclusion_angle_single)
        plot([exclusion_angle_single, exclusion_angle_single], [min(EPFD_single), max(EPFD_single)], 'g--', 'LineWidth', 1);
    end
    xlabel('phi_r (度)', 'FontSize', 12);
    ylabel('EPFD (dB)', 'FontSize', 12);
    title('单颗卫星 EPFD', 'FontSize', 12);
    legend('EPFD', '阈值', '排除角', 'Location', 'best');
    grid on;
    
    subplot(1, 2, 2);
    plot(phi_r_test, EPFD_total, 'r-', 'LineWidth', 2);
    hold on;
    plot([0, max(phi_r_test)], [P.EPFD_thr_dB, P.EPFD_thr_dB], 'r--', 'LineWidth', 1.5);
    if ~isnan(exclusion_angle_total)
        plot([exclusion_angle_total, exclusion_angle_total], [min(EPFD_total), max(EPFD_total)], 'g--', 'LineWidth', 1);
    end
    xlabel('phi_r (度)', 'FontSize', 12);
    ylabel('EPFD (dB)', 'FontSize', 12);
    title('多颗卫星叠加 EPFD', 'FontSize', 12);
    legend('总 EPFD', '阈值', '排除角', 'Location', 'best');
    grid on;
    
    fprintf('\n=== 分析完成 ===\n');
    
    end