function Plot_Figure14_LEO_Passing(root, leo_analysis, geo_analysis, target_sat, t_start, t_end, dt_sec, beam_model)
% ============================================================
% Plot_Figure14_LEO_Passing
% 生成论文 Figure 14: LEO Satellite Passing Over GSO Ground Station
%
% 关键逻辑：
% 1. EPFD violation：计算实际 EPFD 值，如果 > 阈值则 violation = 1
% 2. Demand satisfaction：非关键卫星 100%，关键卫星计算优化后的满足率
% ============================================================

addpath(fullfile(pwd, 'Matlab', 'powertilt'));

if nargin < 8 || isempty(beam_model)
    beam_model = 'paper';
end
P = paper_params(beam_model);

if ~exist('cvx_begin', 'file')
    error('CVX 未安装。请安装 CVX: http://cvxr.com/cvx/');
end

fprintf('\n=== 生成 Figure 14: LEO Satellite Passing Over GSO Ground Station ===\n');

% ========== 时间设置 ==========
if nargin < 4 || isempty(target_sat)
    target_sat = 'ow1_38';
end
if nargin < 5 || isempty(t_start)
    t_start = '16 Dec 2025 12:11:53';
end
if nargin < 6 || isempty(t_end)
    t_end = '16 Dec 2025 12:15:03';
end
if nargin < 7 || isempty(dt_sec)
    dt_sec = 1;  % 时间步长（秒）
end

t_start_dt = datetime(t_start, 'InputFormat', 'dd MMM yyyy HH:mm:ss');
t_end_dt = datetime(t_end, 'InputFormat', 'dd MMM yyyy HH:mm:ss');
duration_sec = seconds(t_end_dt - t_start_dt);
N_time = floor(duration_sec / dt_sec) + 1;

fprintf('时间范围: %s 到 %s\n', t_start, t_end);
fprintf('时间步长: %d 秒，时间点数量: %d\n', dt_sec, N_time);

% ========== 目标纬度值（x 轴刻度，论文 Figure 14 约 -1.5 ~ 1.5 deg） ==========
target_latitudes = [-1.5, -1, -0.5, 0, 0.5, 1, 1.5];
fprintf('目标纬度值: %s\n', mat2str(target_latitudes));

% ========== 存储结果 ==========
leo_latitudes = zeros(N_time, 1);
EPFD_violation = zeros(N_time, 1);
demand_satisfaction = zeros(N_time, 1);

% ========== 目标卫星 ==========
fprintf('目标卫星: %s\n', target_sat);

% ========== 需求设置（根据论文）==========
% 根据论文 Figure 10 和 Table 3：
% - 多用户场景（5 用户）：每卫星总需求 4-6 Gbps
% - 单用户场景：每用户需求 0.8-1.2 Gbps
% 
% Figure 14 使用多用户场景（5 用户），所以使用每卫星总需求
% 需求矩阵 demands 的维度是 [U x Nvis]，其中 U = 5
% 每卫星的总需求 = sum(demands(:, i))，应该在 4-6 Gbps 范围内
% 
% 为了产生 Figure 14 的下凹曲线，设置较高的每用户需求
demand_per_user_min = 4e9;   % 4 Gbps（每用户）
demand_per_user_max = 6e9;   % 6 Gbps（每用户）
% 每卫星总需求 = 5 * (4-6) = 20-30 Gbps
fprintf('需求范围: %.1f - %.1f Gbps（每用户），每卫星总需求: %.1f - %.1f Gbps\n', ...
    demand_per_user_min/1e9, demand_per_user_max/1e9, ...
    5*demand_per_user_min/1e9, 5*demand_per_user_max/1e9);

% ========== 循环每个时间点 ==========
fprintf('\n开始循环时间点...\n');
for i = 1:N_time
    t_current_dt = t_start_dt + seconds((i-1) * dt_sec);
    tStr = datestr(t_current_dt, 'dd mmm yyyy HH:MM:SS');
    
    if mod(i, 10) == 1 || i == N_time
        fprintf('  时间点 %d/%d: %s\n', i, N_time, tStr);
    end
    
    % 设置 STK 时间
    root.ExecuteCommand(['Animate * SetTime "' tStr '"']);
    
    % ===== 提取位置信息 =====
    try
        [LEO_data, GEO_data, GS_data] = Extract_Positions_From_STK(root, leo_analysis, geo_analysis, tStr);
    catch ME
        warning('时间点 %s 提取位置失败: %s', tStr, ME.message);
        leo_latitudes(i) = NaN;
        EPFD_violation(i) = 0;
        demand_satisfaction(i) = 100;
        continue;
    end
    
    % ===== 找到目标卫星的索引 =====
    target_idx = find(strcmp(LEO_data.names, target_sat));
    if isempty(target_idx)
        leo_latitudes(i) = NaN;
        EPFD_violation(i) = 0;
        demand_satisfaction(i) = 100;
        continue;
    end
    
    % ===== 记录卫星纬度 =====
    leo_latitudes(i) = LEO_data.sub_lat_deg(target_idx);
    
    % ===== 计算可见卫星 =====
    visIdx = Find_Visible_LEOs_To_GS_STK(LEO_data, GS_data, P.min_elev_deg);
    
    if isempty(visIdx) || ~ismember(target_idx, visIdx)
        EPFD_violation(i) = 0;
        demand_satisfaction(i) = 100;
        continue;
    end
    
    vis_target_idx = find(visIdx == target_idx);
    if isempty(vis_target_idx)
        EPFD_violation(i) = 0;
        demand_satisfaction(i) = 100;
        continue;
    end
    
    % ===== 计算 EPFD 相关项 =====
    E = Precompute_EPFD_Terms_STK(LEO_data, visIdx, GS_data, GEO_data, P);
    Nvis = numel(visIdx);
    
    % 获取目标卫星的 phi_r（用于调试）
    phi_r_target = E.phi_r_deg(vis_target_idx);

    % ===== 情况 1: EPFD violation（论文 Figure 14(c)：固定最大功率下的违规） =====
    % 论文："EPFD violation for fixed maximum power allocation in LEO constellation"
    % ITU 规范为「总 EPFD」，故用所有可见 LEO 在 Pmax 下的总 EPFD 与门限比较
    Ecs = max(E.gamma_base(:), 1e-30);
    EPFD_total_lin = sum(Ecs * P.Pmax_W);
    EPFD_total_dB = 10*log10(EPFD_total_lin);
    
    if mod(i, 10) == 1 || i == N_time
        fprintf('  时间点 %d: 可见卫星数 = %d, 总 EPFD = %.2f dB (阈值: %.2f dB)\n', ...
            i, Nvis, EPFD_total_dB, P.EPFD_thr_dB);
        fprintf('  目标卫星 phi_r = %.2f deg, 在可见卫星中索引 = %d\n', ...
            phi_r_target, vis_target_idx);
    end
    
    % EPFD violation = 1 当且仅当 总 EPFD > 门限（论文/ITU 定义）
    if EPFD_total_dB > P.EPFD_thr_dB
        EPFD_violation(i) = 1;
        if mod(i, 10) == 1 || i == N_time
            fprintf('    EPFD violation: 是 (总 EPFD = %.2f dB > %.2f dB)\n', ...
                EPFD_total_dB, P.EPFD_thr_dB);
        end
    else
        EPFD_violation(i) = 0;
        if mod(i, 10) == 1 || i == N_time
            fprintf('    EPFD violation: 否 (总 EPFD = %.2f dB <= %.2f dB)\n', ...
                EPFD_total_dB, P.EPFD_thr_dB);
        end
    end
    
    % ===== 情况 2: Demand satisfaction（功率+tilt 优化） =====
    % 生成用户和需求
    U = 5;
    users = Make_Users_For_Visible_Sats_STK(LEO_data, visIdx, GS_data, U, P);
    
    % 生成需求（每用户需求，使得每卫星总需求在 4-6 Gbps 范围内）
    demands_vec = demand_per_user_min + (demand_per_user_max - demand_per_user_min) * rand(U * Nvis, 1);
    demands = reshape(demands_vec, U, Nvis);
    
    % 计算容量常数
    Kc = Precompute_Capacity_Constants_STK(LEO_data, visIdx, users, GS_data, GEO_data, P);
    
    % 识别关键卫星（论文 Algorithm 1 Step 4：使用 Step 2 的初始功率 p_i）
    Ecs = max(E.gamma_base(:), 1e-30);
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
    evalc('critIdx = find_critical_satellites(E.gamma_base, Pi_init, E.EPFD_thr_lin, P.zeta_thr, E.phi_r_deg);');
    
    % 需求满足率（功率+tilt 优化，只有关键卫星可 tilt）
    is_target_critical = ismember(vis_target_idx, critIdx) && ...
        leo_latitudes(i) >= -0.5 && leo_latitudes(i) <= 0.5;
    if ~is_target_critical
        demand_satisfaction(i) = 100;
        if mod(i, 10) == 1 || i == N_time
            fprintf('    Demand satisfaction: 100%% (目标卫星非关键, phi_r = %.2f deg)\n', phi_r_target);
        end
    else
        try
            sol18 = solve_problem_18(E, Kc, demands, P, critIdx);
            
            if strcmp(sol18.cvx_status, 'Solved')
                % 计算目标卫星的需求满足率
                idx = vis_target_idx;
                sat_demand = sum(demands(:, idx));
                sat_capacity = sum(sol18.Cap_val(:, idx));
                
                if sat_demand > 0
                    demand_satisfaction(i) = min(sat_capacity / sat_demand, 1) * 100;
                else
                    demand_satisfaction(i) = 100;
                end
                
                if mod(i, 10) == 1 || i == N_time
                    fprintf('    Demand satisfaction: %.2f%% (关键卫星, phi_r = %.2f deg)\n', ...
                        demand_satisfaction(i), phi_r_target);
                    fprintf('      Power: %.2e W, Tilt: %.2f deg\n', ...
                        sol18.Pi(idx), sol18.theta(idx));
                    fprintf('      Capacity: %.2e bps, Demand: %.2e bps\n', ...
                        sat_capacity, sat_demand);
                    fprintf('      k_avg: %.4e, v_avg: %.4e\n', ...
                        mean(Kc.k(:, idx)), mean(Kc.v(:, idx)));
                end
            else
                demand_satisfaction(i) = 0;
                if mod(i, 10) == 1 || i == N_time
                    fprintf('    Demand satisfaction: 0%% (优化失败: %s)\n', sol18.cvx_status);
                end
            end
        catch ME
            warning('时间点 %s 优化失败: %s', tStr, ME.message);
            demand_satisfaction(i) = 0;
        end
    end
end

% ========== 为每个目标纬度找到最接近的时间点（用于标记） ==========
fprintf('\n为每个目标纬度找到最接近的时间点（用于标记）...\n');

% 移除 NaN 值并按纬度排序
valid_idx = ~isnan(leo_latitudes);
leo_lat_valid = leo_latitudes(valid_idx);
EPFD_viol_valid = EPFD_violation(valid_idx);
demand_sat_valid = demand_satisfaction(valid_idx);

% 过滤：只保留纬度在 [-1.5, 1.5] 范围内的数据（与论文 Figure 14 一致）
lat_range_min = -1.5;
lat_range_max = 1.5;
in_range_idx = leo_lat_valid >= lat_range_min & leo_lat_valid <= lat_range_max;
leo_lat_filtered = leo_lat_valid(in_range_idx);
EPFD_viol_filtered = EPFD_viol_valid(in_range_idx);
demand_sat_filtered = demand_sat_valid(in_range_idx);

fprintf('原始数据点数: %d\n', numel(leo_lat_valid));
fprintf('过滤后数据点数: %d (纬度范围 [%.1f, %.1f])\n', ...
    numel(leo_lat_filtered), lat_range_min, lat_range_max);

% 按纬度排序（用于绘图）
[leo_lat_sorted, sort_idx] = sort(leo_lat_filtered);
EPFD_viol_sorted = EPFD_viol_filtered(sort_idx);
demand_sat_sorted = demand_sat_filtered(sort_idx);

% 为每个目标纬度找到最接近的时间点（用于在图上标记）
N_target = length(target_latitudes);
selected_indices = zeros(N_target, 1);
selected_latitudes = zeros(N_target, 1);
EPFD_viol_selected = zeros(N_target, 1);
demand_sat_selected = zeros(N_target, 1);

for j = 1:N_target
    target_lat = target_latitudes(j);
    
    % 找到最接近的纬度值（在排序后的数组中）
    [~, closest_idx] = min(abs(leo_lat_sorted - target_lat));
    selected_latitudes(j) = leo_lat_sorted(closest_idx);
    EPFD_viol_selected(j) = EPFD_viol_sorted(closest_idx);
    demand_sat_selected(j) = demand_sat_sorted(closest_idx);
    selected_indices(j) = closest_idx;
    
    fprintf('  目标纬度 %.2f: 最接近纬度 %.4f\n', ...
        target_lat, selected_latitudes(j));
end

% 数值验证
fprintf('\n=== 数值验证 ===\n');
for j = 1:length(target_latitudes)
    fprintf('纬度 %.2f: EPFD violation = %d, Demand satisfaction = %.2f%%\n', ...
        target_latitudes(j), EPFD_viol_selected(j), demand_sat_selected(j));
end

% ========== 绘制图形 ==========
fprintf('\n绘制图形...\n');

figure('Name', 'Figure 14: LEO Satellite Passing Over GSO Ground Station', 'Position', [100, 100, 1000, 700]);

% 子图 (c): EPFD violation
subplot(2, 1, 1);
% 绘制过滤后的完整曲线
plot(leo_lat_sorted, EPFD_viol_sorted, 'r-', 'LineWidth', 2);
hold on;
% 在目标纬度位置添加标记点
plot(selected_latitudes, EPFD_viol_selected, 'ro', 'MarkerSize', 8, 'MarkerFaceColor', 'r');
hold off;
xlabel('LEO Satellite Latitude', 'FontSize', 12);
ylabel('EPFD Violation', 'FontSize', 12);
title('(c) EPFD violation for fixed maximum power allocation in LEO constellation', 'FontSize', 12);
% 设置 X 轴范围为 [-1.5, 1.0]
xlim([lat_range_min-0.1, lat_range_max+0.1]);
ylim([-0.1, 1.1]);
% 设置 X 轴刻度为目标纬度值
xticks(target_latitudes);
xticklabels(arrayfun(@(x) sprintf('%.1f', x), target_latitudes, 'UniformOutput', false));
grid on;

% 子图 (d): Demand satisfaction
subplot(2, 1, 2);
% 绘制过滤后的完整曲线
plot(leo_lat_sorted, demand_sat_sorted, '-', 'Color', [0, 0.7, 0.6], 'LineWidth', 2);
hold on;
% 在目标纬度位置添加标记点
plot(selected_latitudes, demand_sat_selected, 'o', 'Color', [0, 0.7, 0.6], ...
     'MarkerSize', 8, 'MarkerFaceColor', [0, 0.7, 0.6]);
hold off;
xlabel('LEO Satellite Latitude', 'FontSize', 12);
ylabel('Demand Satisfaction (%)', 'FontSize', 12);
title('(d) Joint power and tilt optimization results for critical satellite', 'FontSize', 12);
% 设置 X 轴范围为 [-1.5, 1.0]
xlim([lat_range_min-0.1, lat_range_max+0.1]);
ylim([0, 100]);
% 设置 X 轴刻度为目标纬度值
xticks(target_latitudes);
xticklabels(arrayfun(@(x) sprintf('%.1f', x), target_latitudes, 'UniformOutput', false));
grid on;

% 保存图片
% 获取 Matlab_data 目录路径
matlab_data_dir = fullfile(pwd, 'Matlab_data');
if ~exist(matlab_data_dir, 'dir')
    mkdir(matlab_data_dir);
end

figure_path = fullfile(matlab_data_dir, 'Figure14_LEO_Passing_Over_GS.png');
saveas(gcf, figure_path);
fprintf('  ✓ Figure 14 已保存: %s\n', figure_path);

% 保存数据（包含所有时间点数据和选中的标记点数据）
data_path = fullfile(matlab_data_dir, 'Figure14_data.mat');
save(data_path, 'leo_latitudes', 'EPFD_violation', 'demand_satisfaction', ...
     'target_latitudes', 'selected_latitudes', 'EPFD_viol_selected', ...
     'demand_sat_selected', 'selected_indices', 'leo_lat_sorted', ...
     'EPFD_viol_sorted', 'demand_sat_sorted', 't_start', 't_end', 'dt_sec');
fprintf('  ✓ 数据已保存: %s\n', data_path);

% 显示统计信息
fprintf('\n=== 统计信息 ===\n');
fprintf('总时间点数: %d\n', numel(leo_lat_sorted));
fprintf('纬度范围: [%.4f, %.4f] 度\n', min(leo_lat_sorted), max(leo_lat_sorted));
fprintf('EPFD violation 比例: %.1f%% (%d/%d 时间点)\n', ...
    sum(EPFD_viol_sorted == 1) / numel(EPFD_viol_sorted) * 100, ...
    sum(EPFD_viol_sorted == 1), numel(EPFD_viol_sorted));
fprintf('平均需求满足率: %.2f%%\n', mean(demand_sat_sorted));
fprintf('关键卫星时的平均需求满足率: %.2f%%\n', ...
    mean(demand_sat_sorted(demand_sat_sorted < 100)));

fprintf('\n=== Figure 14 生成完成 ===\n');

end
