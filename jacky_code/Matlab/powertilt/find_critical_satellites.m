function critIdx = find_critical_satellites(gamma_base, Pi, EPFD_thr_lin, zeta_thr, phi_r_deg)
% ============================================================
% find_critical_satellites
% Algorithm 1 Step 4: 找到关键卫星集合
%
% 根据论文 Algorithm 1 Step 4:
% 如果 γ_i * p_i / 10^(EPFD_thr/10) >= ζ_thr，则卫星 i 是关键卫星
% ============================================================

% 计算每个卫星的归一化贡献
normalized_contrib = (gamma_base .* Pi) / EPFD_thr_lin;

% 显示所有卫星的归一化贡献（用于调试）
fprintf('  所有卫星的归一化贡献 (γ_i*p_i/EPFD_thr):\n');
for k = 1:numel(gamma_base)
    fprintf('    卫星 %d: %.6e (gamma=%.4e, Pi=%.2e W)\n', ...
        k, normalized_contrib(k), gamma_base(k), Pi(k));
end

% 找出满足条件的卫星
critIdx = find(normalized_contrib >= zeta_thr);

% 如果找到多个关键卫星，进一步筛选：
% 只保留归一化贡献远大于其他卫星的卫星（例如，贡献最大的卫星的贡献至少是第二大的 10 倍）
if numel(critIdx) > 1
    contrib_sorted = sort(normalized_contrib(critIdx), 'descend');
    if length(contrib_sorted) >= 2
        % 如果最大贡献至少是第二大的 10 倍，则只保留最大贡献的卫星
        if contrib_sorted(1) >= 10 * contrib_sorted(2)
            [~, max_idx_in_crit] = max(normalized_contrib(critIdx));
            critIdx = critIdx(max_idx_in_crit);
            fprintf('  筛选后：只保留贡献最大的卫星（贡献 = %.2e，是第二大的 %.1f 倍）\n', ...
                contrib_sorted(1), contrib_sorted(1) / contrib_sorted(2));
        end
    end
end

fprintf('[关键卫星] zeta_thr=%.2f | 关键卫星数: %d / %d\n', ...
    zeta_thr, numel(critIdx), numel(gamma_base));

% 显示关键卫星的详细信息
if ~isempty(critIdx)
    fprintf('  关键卫星索引: ');
    fprintf('%d ', critIdx);
    fprintf('\n');
    fprintf('  关键卫星归一化贡献 (γ_i*p_i/EPFD_thr): ');
    for k = 1:numel(critIdx)
        fprintf('%.4f ', normalized_contrib(critIdx(k)));
    end
    fprintf('\n');
    fprintf('  关键卫星功率 (W): ');
    for k = 1:numel(critIdx)
        fprintf('%.2e ', Pi(critIdx(k)));
    end
    fprintf('\n');
    if nargin >= 5 && ~isempty(phi_r_deg)
        fprintf('  关键卫星 phi_r: ');
        fprintf('%.2f ', phi_r_deg(critIdx));
        fprintf('deg\n');
    end
else
    % 如果没有找到关键卫星，显示最大归一化贡献
    [max_contrib, max_idx] = max(normalized_contrib);
    fprintf('  未找到关键卫星。最大归一化贡献: %.6e (卫星 %d, 需要 >= %.2f)\n', ...
        max_contrib, max_idx, zeta_thr);
    if nargin >= 5 && ~isempty(phi_r_deg)
        phi_r_str = sprintf('%.2f', phi_r_deg(max_idx));
    else
        phi_r_str = 'N/A';
    end
    fprintf('  最大贡献卫星: gamma=%.4e, Pi=%.2e W, phi_r=%s deg\n', ...
        gamma_base(max_idx), Pi(max_idx), phi_r_str);
end

end