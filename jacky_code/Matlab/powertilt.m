%% 重置 Command window 與 Workspace
clear;
clc;

%% 與STK連線
disp("連接STK");
con = actxGetRunningServer('STK12.application');
root = con.Personality2;
con.Visible = 1;
disp("---------------------- done");

%% 初始化
addpath(fullfile(pwd, 'Matlab', 'powertilt'));
addpath(fullfile(pwd, 'Matlab'));
global OneWeb_leo OneWeb_geo  OneWeb_OMNet_leo OneWeb_OMNet_geo beam_config geoLongitudes OneWeb_OMNet_leo_part OneWeb_OMNet_geo_part;
disp("初始化");
Satellite_Name();
file_path = "C:\Users\jacky\Desktop\jacky_code\jacky_code\";
if ~exist(file_path + 'STK','dir')
    mkdir(file_path);
end
if ~exist(file_path + 'Matlab_data','dir')
    mkdir(file_path);
end
disp("---------------------- done");

%% === 建立 Scenario（24 小時）===
scName = "OneWeb_Only";
try
    root.CloseScenario;
catch, end

% 以 UTC 建情境時間窗（現在起算 24h）
tStartUtc = datestr(datetime('now','TimeZone','UTC'), 'dd mmm yyyy HH:MM:SS');
tStopUtc  = datestr(datetime('now','TimeZone','UTC') + days(1), 'dd mmm yyyy HH:MM:SS');

root.NewScenario(scName);
sc = root.CurrentScenario;
sc.SetTimePeriod(tStartUtc, tStopUtc);
root.ExecuteCommand('Animate * Reset');
root.UnitPreferences.SetCurrentUnit('Distance', 'km'); % modify
root.UnitPreferences.SetCurrentUnit('Latitude', 'deg'); % modify
root.UnitPreferences.SetCurrentUnit('Longitude', 'deg'); % modify
disp("---------------------- done");

%% 下載最新 OneWeb LEO TLE（CelesTrak 動態查詢）

%LEO
disp("下載 OneWeb LEO TLE（CelesTrak）...");
tleURL  = 'https://celestrak.org/NORAD/elements/gp.php?GROUP=oneweb&FORMAT=tle';
outDir  = fullfile(file_path,'oneweb_tle');
if ~exist(outDir,'dir'), mkdir(outDir); end

tleFile = fullfile(outDir, datestr(now,'yyyymmdd_HHMMSS'), '_oneweb.tle');

if ~exist(fileparts(tleFile),'dir'); mkdir(fileparts(tleFile)); end

try
    websave(tleFile, tleURL);
    disp("---- 下載完成: " + tleFile);
catch ME
    error("❌ 無法從 CelesTrak 下載 TLE：%s", ME.message);
end

%GEO
disp("下載 GEO TLE（CelesTrak）...");
tleURL  = 'https://celestrak.org/NORAD/elements/gp.php?GROUP=geo&FORMAT=tle';
% 建立輸出資料夾
outDir  = fullfile(file_path, 'geo_tle');
if ~exist(outDir, 'dir')
    mkdir(outDir);
end
% 以時間戳命名的子資料夾與檔案名稱
subDir = fullfile(outDir, datestr(now, 'yyyymmdd_HHMMSS'));
if ~exist(subDir, 'dir')
    mkdir(subDir);
end
tleFile = fullfile(subDir, '_geo.tle');
% 嘗試下載
try
    websave(tleFile, tleURL);
    disp("✅ 下載完成: " + tleFile);
catch ME
    error("❌ 無法從 CelesTrak 下載 GEO TLE：%s", ME.message);
end

%% 轉tlm格式
%LEO
convert_tlm('C:\Users\jacky\Desktop\jacky_code\jacky_code\oneweb_tle\20251125_211107');

%GEO
convert_tlm('C:\Users\jacky\Desktop\jacky_code\jacky_code\geo_tle\20251125_212200');

%% Read LEO TLE Content 

disp("read TLEs");

% 開啟檔案
%LEO
filename = fullfile('C:\Users\jacky\Desktop\jacky_code\jacky_code\oneweb_tle\20251125_211107', '_oneweb.tle');
fid = fopen(filename, 'r');
if fid == -1
    error('❌ 無法開啟 TLE 檔案，請確認路徑是否正確');
end

% 讀取所有行
tle_lines = textscan(fid, '%s', 'Delimiter', '\n');
fclose(fid);
tle_lines = tle_lines{1};

% 呼叫 function 處理 TLE
tle_data = parseTLE(tle_lines);
disp("---------------------- done");

%GEO
filename = fullfile('C:\Users\jacky\Desktop\jacky_code\jacky_code\geo_tle\20251125_212200', '_geo.tle');
fid = fopen(filename, 'r');
if fid == -1
    error('❌ 無法開啟 TLE 檔案，請確認路徑是否正確');
end

% 讀取所有行
tle_lines = textscan(fid, '%s', 'Delimiter', '\n');
fclose(fid);
tle_lines = tle_lines{1};

% 呼叫 function 處理 TLE
tle_data = parseTLEgeo(tle_lines);
disp("---------------------- done");

%% Add satellite in STK through TLE file
%LEO 
addSatellitesFromTLE(root, sc, tle_data, OneWeb_leo, OneWeb_OMNet_leo);



%GEO
addSatellitesFromTLE(root, sc, tle_data, OneWeb_geo, OneWeb_OMNet_geo);


%% ================== 建立地面戰 ================== 
geo = [
    "geo_16_4"
];
latGS = 0;
GeoGroundStations(root, OneWeb_OMNet_geo, geoLongitudes, latGS);

% 在 pitch2.m 中，替换原来的 GeoGroundStations 调用：

%% ================== 建立地面站（多个纬度）================= 
geo = "geo_16_4";  % 选择一个 GEO 卫星
latRange = [-0.5, 0.5];  % 纬度范围（对应 Figure 11）
latStep = 0.1;  % 纬度步长（对应 Figure 11 的 x 轴刻度）

Create_GSO_GS_Multiple_Latitudes(root, geo, geoLongitudes, OneWeb_OMNet_geo, latRange, latStep);

%% ================== GSO 保護排除角 16 Beam (計算EPFD) ================== 
leo_1 = [
    "ow1_3"
    "ow1_30"
    "ow1_38"
    % "ow1_43"
    % "ow1_29"
    % "ow1_20"
];
leo_18 = [
    "ow18_33"
    "ow18_16"
    "ow18_26"
    "ow18_3"
    "ow18_53"
    "ow18_50"
];
leo_19 = [
    "ow19_48"
    "ow19_15"
    "ow19_18"
    "ow19_45" 
    "ow19_29" 
];

leo_part = [
    "ow1_3"
    "ow1_30"
    "ow1_38"
    "ow1_43"
    "ow1_29"
];


geo_part = [
    "geo_16_4"
];

Satellite_Name();
stepSec = 10;   

%% ================== Tilt 优化计算（基于论文） ================== 

% 加载论文参数
% beam_model:
% - "paper"      : follow paper assumption (half-3dB = 13.9 deg)
% - "oneweb_fcc"  : use public FCC filing footprint (~1140 km square) as an
%                  effective single-beam half-angle (for overlap experiments)
beam_model = "paper";
P = paper_params(beam_model);

% 设置当前时间点
tStr = '16 Dec 2025 12:12:03';
root.ExecuteCommand(['Animate * SetTime "' tStr '"']);

% 选择要分析的 LEO 和 GEO
leo_analysis = leo_part;
geo_analysis = geo_part;

% ========== 步骤 1: 从 STK 提取位置信息 ==========
fprintf('\n=== 从 STK 提取位置信息 ===\n');
[LEO_data, GEO_data, GS_data] = Extract_Positions_From_STK(root, leo_analysis, geo_analysis, tStr);

% ========== 步骤 2: 计算可见的 LEO 卫星 ==========
fprintf('\n=== 计算可见性 ===\n');
visIdx = Find_Visible_LEOs_To_GS_STK(LEO_data, GS_data, P.min_elev_deg);

if isempty(visIdx)
    warning('没有可见的 LEO 卫星，跳过 tilt 计算');
else
    % ========== 步骤 3: 生成用户位置（MATLAB 模拟，论文假设） ==========
    fprintf('\n=== 生成用户位置（每颗可见卫星 5 个用户） ===\n');
    U_init = 5;
    users = Make_Users_For_Visible_Sats_STK(LEO_data, visIdx, GS_data, U_init, P);

    % ========== 步骤 4: 计算 EPFD 相关项 ==========
    fprintf('\n=== 计算 EPFD 相关项 ===\n');
    E = Precompute_EPFD_Terms_STK(LEO_data, visIdx, GS_data, GEO_data, P);
    
    % ========== 步骤 5: 生成需求（论文：4–6 Gbps/用户） ==========
    fprintf('\n=== 生成需求 ===\n');
    demand_min = 4e9;  % 4 Gbps
    demand_max = 6e9;  % 6 Gbps
    Nvis = numel(visIdx);
    U = numel(users.lat_deg) / Nvis;
    demands_vec = demand_min + (demand_max - demand_min) * rand(size(users.lat_deg));
    demands = reshape(demands_vec, U, []);
    
    % ========== 步骤 6: 计算容量常数 ==========
    fprintf('\n=== 计算容量常数 ===\n');
    Kc = Precompute_Capacity_Constants_STK(LEO_data, visIdx, users, GS_data, GEO_data, P);
    
    % ========== 步骤 7: 实现 Algorithm 1 (Problem 18) ==========
    fprintf('\n=== 实现 Algorithm 1: 关键卫星 Tilt 策略 ===\n');

    if exist('cvx_begin', 'file') == 2
        % ------------------------------------------------------------
        % Logging mode:
        %   true  -> concise, human-readable (EPFD / thresholds / key results)
        %   false -> verbose debug prints from sub-functions
        % ------------------------------------------------------------
        log_simple = true;

        % Algorithm 1: Joint Power and Tilt Angle Optimization
        
        % Step 1: 找到可见卫星（已完成，visIdx）
        fprintf('Step 1: 可见卫星数 = %d\n', numel(visIdx));
        
        % Step 2: 设置零 tilt，求解 Problem 18（初始解）
        fprintf('\nStep 2: 初始求解（零 tilt）...\n');
        Dsat = sum(demands, 1).';  % 修正：应该是 sum(demands, 1) 而不是 sum(demands, 10)
        Ecs = max(E.gamma_base(:), 1e-30);
        
        cvx_clear
        cvx_begin quiet
            variables q_init(Nvis)
            
            % 优化目标：在满足 EPFD 约束的前提下，最大化总功率
            % 这样可以间接最大化容量（因为容量是功率的单调递增函数）
            maximize( sum(q_init) )
            subject to
                log_sum_exp( log(Ecs) + q_init ) <= log(E.EPFD_thr_lin);
                q_init <= log(P.Pmax_W);
                q_init >= log(1e-6);
        cvx_end

        Pi_init = exp(q_init);
        fprintf('  初始功率范围: [%.2e, %.2e] W\n', min(Pi_init), max(Pi_init)); 
        
        % Step 3: 计算 γ_i（已经在 E.gamma_base 中）
        fprintf('\nStep 3: gamma 值已计算（E.gamma_base）\n');
        
        % ========== 验证计算 ==========
        if log_simple
            % silence internal prints
            evalc('Verify_Before_Critical_Identification(E, Pi_init, P, visIdx, leo_analysis);');
        else
            Verify_Before_Critical_Identification(E, Pi_init, P, visIdx, leo_analysis);
        end
        
        % Step 4: 找到关键卫星集合 I_crit
        fprintf('\nStep 4: 识别关键卫星...\n');

        % 根据论文 Algorithm 1 Step 4:
        % 条件：γ_i * p_i / 10^(EPFD_thr/10) >= ζ_thr
        %
        % 注意：论文中使用的是初始功率分配 p_i，但如果优化器将所有卫星的
        % 贡献平均分配，会导致无法识别关键卫星。
        %
        % 根据论文意图，关键卫星应该是那些在最大功率下对 EPFD 贡献最大的卫星。
        % 因此，我们使用最大功率 P_max 来识别关键卫星，而不是优化后的初始功率。
        %
        % 这样更符合论文的意图：识别那些"如果使用最大功率会导致高 EPFD 贡献"的卫星。
        Pi_for_crit = P.Pmax_W * ones(Nvis, 1);  % 使用最大功率
        if log_simple
            evalc('critIdx = find_critical_satellites(E.gamma_base, Pi_for_crit, E.EPFD_thr_lin, P.zeta_thr, E.phi_r_deg);');
        else
            critIdx = find_critical_satellites(E.gamma_base, Pi_for_crit, E.EPFD_thr_lin, P.zeta_thr, E.phi_r_deg);
        end
        
        if isempty(critIdx)
            warning('未找到关键卫星，所有卫星将使用零 tilt');
            critIdx = [];
        else
            % 显示关键卫星的实际名称
            fprintf('\n关键卫星列表（基于最大功率）:\n');
            for k = 1:numel(critIdx)
                idx = critIdx(k);  % 在可见卫星中的索引
                leoIdx = visIdx(idx);  % 在 LEO_data 中的索引
                leoName = LEO_data.names{leoIdx};
                fprintf('  Sat %d → %s (gamma_base = %.4e, Pi_init = %.2e W, Pi_max = %.2e W)\n', ...
                    idx, leoName, E.gamma_base(idx), Pi_init(idx), P.Pmax_W);
            end
        end
        
        % Step 5: 求解 Problem 18（只有关键卫星可以 tilt) 
        fprintf('\nStep 5: 求解 Problem 18（关键卫星 tilt）...\n');
        if log_simple
            evalc('sol18 = solve_problem_18(E, Kc, demands, P, critIdx);');
        else
            sol18 = solve_problem_18(E, Kc, demands, P, critIdx);
        end
        fprintf('[EPFD] %.2f dB (thr=%.2f dB) | CVX=%s | crit=%d/%d\n', ...
            sol18.EPFD_dB, P.EPFD_thr_dB, sol18.cvx_status, numel(critIdx), numel(visIdx));
        
        
        % Step 6: 计算功率（已在 solve_problem_18 中完成）
        % P_i^opt = exp(q_i^opt) ✓
        
        % Step 7: 显示结果
        fprintf('\n[Algorithm 1 结果]\n');
        fprintf('  关键卫星数: %d / %d\n', numel(critIdx), numel(visIdx));
        fprintf('  功率范围: [%.2e, %.2e] W\n', min(sol18.Pi), max(sol18.Pi));
        fprintf('  EPFD: %.2f dB (阈值: %.2f dB)\n', sol18.EPFD_dB, P.EPFD_thr_dB);
        fprintf('  使用 tilt 的卫星数: %d / %d\n', sol18.num_tilted, numel(visIdx));
        fprintf('  平均需求满足率: %.2f%%\n', sol18.avg_sat_demand_satisfaction);
        fprintf('  Tilt 角度范围: [%.2f, %.2f] 度\n', min(sol18.theta), max(sol18.theta));
        
        % 显示关键卫星的详细信息
        fprintf('\n关键卫星详情:\n');
        for k = 1:numel(critIdx)
            idx = critIdx(k);
            leoIdx = visIdx(idx);
            leoName = LEO_data.names{leoIdx};
            fprintf('  %s (Sat %d): theta = %.2f deg, Power = %.3e W, gamma = %.4e\n', ...
                leoName, idx, sol18.theta(idx), sol18.Pi(idx), E.gamma_base(idx));
        end
        
        % 显示所有卫星的 tilt 角度
        fprintf('\n所有卫星的 tilt 角度:\n');
        for k = 1:numel(visIdx)
            idx = visIdx(k);
            leoName = LEO_data.names{idx};
            if ismember(k, critIdx)
                status = '关键';
            else
                status = '非关键';
            end
            fprintf('  %s: theta = %.2f deg, Power = %.3e W [%s]\n', ...
                leoName, sol18.theta(k), sol18.Pi(k), status);
        end
        
    else
        warning('CVX 未安装，无法求解优化问题。请安装 CVX: http://cvxr.com/cvx/');
    end
end


%% ================== 验证 EPFD、功率控制和 Tilt 计算 ==================
% 全面验证 EPFD、功率控制和 tilt 的计算
fprintf('\n=== 验证 EPFD、功率控制和 Tilt 计算 ===\n');
tStr_verify = '16 Dec 2025 12:12:03';  % 使用与 Figure 14 相同的时间点
Verify_EPFD_Power_Tilt_Calculations(root, leo_part, geo_part, tStr_verify);

%% ================== 生成 Figure 14 ==================
% 生成 Figure 14: LEO Satellite Passing Over GSO Ground Station
fprintf('\n=== 生成 Figure 14 ===\n');
leo_figure14_part = [
    "ow1_3"
    "ow1_30"
    "ow1_38"
    "ow1_43"
    % "ow19_48"
    % "ow19_15"
    % "ow19_18"
    % "ow19_45" 
    % "ow19_29" 
];
Plot_Figure14_LEO_Passing(root, leo_figure14_part, geo_part, "ow1_30", "16 Dec 2025 12:10:03", "16 Dec 2025 12:13:53", 1);

% 生成 Figure 11
geoName = "geo_16_4";  % 與你前面設定一致
leo_figure11_part = [
    % "ow1_3"
    "ow1_30"
    % "ow1_38"
    % "ow19_48"
    % "ow19_18"
    % "ow19_15" 
    % "ow19_18" 
];
Plot_Figure11_EPFD_vs_GS_Latitude(root, leo_figure11_part, geo_part, geoName);




Diagnose_EPFD_and_Capacity(root, leo_analysis, geo_analysis, tStr);


























%% Save STK scenario
disp("save");
root.Save;
disp("---------------------- done");

%% STK 場景另存新檔 (M)
disp("Save as");
sub_file_path = file_path + "STK2"; % modify
if ~exist(sub_file_path,'dir')
    mkdir(sub_file_path);
end
root.SaveAs(file_path + 'STK2\Scenario'); % modify
disp("---------------------- done");

%% STL 關閉後用載入的方式開啟
disp("載入舊場景");
root.LoadScenario('C:\Users\jacky\Desktop\jacky_code\jacky_code\STK\Scenario.sc');
sc = root.CurrentScenario;
disp("---------------------- done");
