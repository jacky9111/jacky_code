function Plot_Figure11_EPFD_vs_GS_Latitude(root, leo_analysis, geo_analysis, geoName, geoLongitudes, OneWeb_OMNet_geo)
% ============================================================
% Plot_Figure11_EPFD_vs_GS_Latitude
% 生成論文 Figure 11：
%   「Resulting EPFD for different GSO ground station latitudes」
%
% - 固定功率 (Fixed power)：所有可見 LEO 以 Pmax 發射，不做控制
% - Power+Tilt：對關鍵衛星做功率 + tilt 聯合最佳化 (Problem 18)
%
% GSO 地面站命名規則：
%   Create_GSO_GS_Multiple_Latitudes 會建立
%   GSO_GS_geo_16_4_m0_5, GSO_GS_geo_16_4_0_0, ...
% ============================================================

addpath(fullfile(pwd, 'Matlab', 'powertilt'));

P = paper_params();

if ~exist('cvx_begin', 'file')
    error('CVX 未安裝。請先安裝 CVX: http://cvxr.com/cvx/');
end

fprintf('\n=== 生成 Figure 11: EPFD vs GSO Ground Station Latitude ===\n');

% ---------- 1. 參數與時間設定 ----------
% 論文中圖 11 沒有特別標註時間，這裡沿用 Figure 14 的時間點
tStr = '16 Dec 2025 12:11:21';
root.ExecuteCommand(['Animate * SetTime "' tStr '"']);
fprintf('時間點: %s\n', tStr);

% 只針對單一 GEO 衛星，例如 'geo_16_4'
if nargin < 4 || isempty(geoName)
    geoName = 'geo_16_4';
end

fprintf('※ 假設對應的 GSO 地面站 (GSO_GS_%s_...) 已經在 STK 中建立完畢。\n', geoName);


% ---------- 2. 建立多緯度 GSO 地面站 ----------
latRange = [-0.5, 0.5];   % 對應 Figure 11 x 軸約 -0.5 ~ 0.5 度
latStep  = 0.1;           % 刻度約每 0.1 度

latList = latRange(1):latStep:latRange(2);
N_lat = numel(latList);

% ---------- 3. 先提取 LEO / GEO 位置（與 GS 無關，可共用） ----------
[LEO_data, GEO_data, ~] = Extract_Positions_From_STK(root, leo_analysis, geo_analysis, tStr);

% 只保留目標 GEO 衛星
geoIdx = find(strcmp(geo_analysis, geoName));
if isempty(geoIdx)
    error('geo_analysis 中找不到 GEO 衛星 %s', geoName);
end

GEO_data.pos_ecef_km = GEO_data.pos_ecef_km(:, geoIdx);
GEO_data.names = {geoName};
GEO_data.N = 1;

% ---------- 4. 為每個 GSO 緯度計算 EPFD ----------
EPFD_fixed_dB   = nan(N_lat, 1);  % 固定功率
EPFD_tilt_dB    = nan(N_lat, 1);  % Power + Tilt
gs_latitudes    = nan(N_lat, 1);  % 實際從 STK 讀出的緯度（驗證用）

for idxLat = 1:N_lat
    lat = latList(idxLat);
    
    % 與 Create_GSO_GS_Multiple_Latitudes 一致的命名
    latStr = sprintf('%.1f', lat);
    latStr = strrep(latStr, '-', 'm');
    latStr = strrep(latStr, '.', '_');
    gsName = sprintf('GSO_GS_%s_%s', geoName, latStr);
    
    fprintf('\n--- [%d/%d] GS = %s ---\n', idxLat, N_lat, gsName);
    
    % 從 STK 讀取該地面站位置
    [r_gs_km, gs_lat] = get_gs_position(root, gsName);
    gs_latitudes(idxLat) = gs_lat;
    fprintf('  STK 回報緯度: %.4f° (目標: %.4f°)\n', gs_lat, lat);
    
    % 組成 GS_data 給 EPFD / 可見性函式使用
    GS_data.pos_ecef_km = r_gs_km(:);
    GS_data.lat_deg     = gs_lat;
    GS_data.names       = {gsName};
    GS_data.N           = 1;
    
    % 4.1 可見衛星
    visIdx = Find_Visible_LEOs_To_GS_STK(LEO_data, GS_data, P.min_elev_deg);
    if isempty(visIdx)
        warning('  沒有可見 LEO，跳過該地面站');
        continue;
    end
    Nvis = numel(visIdx);
    
    % 4.2 EPFD 相關項
    E = Precompute_EPFD_Terms_STK(LEO_data, visIdx, GS_data, GEO_data, P);
    Ecs = max(E.gamma_base(:), 1e-30);
    
    % ---------- (a) 固定功率：所有可見 LEO 以 Pmax 發射 ----------
    Pi_max_all = P.Pmax_W * ones(Nvis, 1);
    EPFD_fixed_lin = sum(Ecs .* Pi_max_all);
    EPFD_fixed_dB(idxLat) = 10*log10(EPFD_fixed_lin);
    fprintf('  EPFD (Fixed power) = %.2f dB (limit = %.2f dB)\n', ...
        EPFD_fixed_dB(idxLat), P.EPFD_thr_dB);
    
    % ---------- (b) Power + Tilt：對關鍵衛星做最佳化 ----------
    % 產生使用者與需求（5 users / sat, 4~6 Gbps）
    U = 5;
    users = Make_Users_For_Visible_Sats_STK(LEO_data, visIdx, GS_data, U, P);
    
    demand_min = 4e9;
    demand_max = 6e9;
    demands_vec = demand_min + (demand_max - demand_min) * rand(U * Nvis, 1);
    demands = reshape(demands_vec, U, Nvis);
    
    % 容量常數
    Kc = Precompute_Capacity_Constants_STK(LEO_data, visIdx, users, GS_data, GEO_data, P);
    
    % 關鍵衛星識別（使用最大功率）
    Pi_for_crit = P.Pmax_W * ones(Nvis, 1);
    critIdx = find_critical_satellites(E.gamma_base, Pi_for_crit, ...
        E.EPFD_thr_lin, P.zeta_thr, E.phi_r_deg);
    
    fprintf('  關鍵衛星數: %d / %d\n', numel(critIdx), Nvis);
    
    % 求解 Problem 18
    sol18 = solve_problem_18(E, Kc, demands, P, critIdx);
    
    if strcmp(sol18.cvx_status, 'Solved')
        EPFD_tilt_dB(idxLat) = sol18.EPFD_dB;
        fprintf('  EPFD (Power+Tilt) = %.2f dB (limit = %.2f dB)\n', ...
            EPFD_tilt_dB(idxLat), P.EPFD_thr_dB);
    else
        warning('  Problem 18 求解失敗: %s', sol18.cvx_status);
        EPFD_tilt_dB(idxLat) = NaN;
    end
end

% ---------- 5. 繪圖 ----------
fig = figure('Color', 'w');
hold on; grid on; box on;

% EPFD limit
plot(gs_latitudes, P.EPFD_thr_dB * ones(size(gs_latitudes)), ...
    'm--', 'LineWidth', 1.5, 'DisplayName', 'EPFD Limit');

% Fixed power
plot(gs_latitudes, EPFD_fixed_dB, 'r-o', 'LineWidth', 1.5, ...
    'MarkerSize', 6, 'DisplayName', 'Fixed power');

% Power + Tilt
plot(gs_latitudes, EPFD_tilt_dB, 'b-s', 'LineWidth', 1.5, ...
    'MarkerSize', 6, 'DisplayName', 'Power+Tilt');

xlabel('GSO ground station latitude (deg)');
ylabel('EPFD (dB(W/m^2/1MHz))');
title('Resulting EPFD for different GSO ground station latitudes');
legend('Location', 'NorthEast');

% x 軸範圍稍微放大一點
xlim([min(gs_latitudes)-0.05, max(gs_latitudes)+0.05]);

% 儲存圖與資料
outDir = fullfile(pwd, 'Matlab_data');
if ~exist(outDir, 'dir')
    mkdir(outDir);
end

pngFile = fullfile(outDir, 'Figure11_EPFD_vs_GSO_Latitude.png');
matFile = fullfile(outDir, 'Figure11_EPFD_vs_GSO_Latitude.mat');

saveas(fig, pngFile);
save(matFile, 'gs_latitudes', 'EPFD_fixed_dB', 'EPFD_tilt_dB', ...
    'latList', 'P');

fprintf('\nFigure 11 圖片已儲存至: %s\n', pngFile);
fprintf('數據已儲存至: %s\n', matFile);

end

% ============================================================
% Helper: 從 STK 讀取地面站位置與緯度
% ============================================================
function [r_gs_km, lat_deg] = get_gs_position(root, gsName)
    try
        gsObj = root.GetObjectFromPath(['*/Facility/' gsName]);
    catch ME
        error('無法在 STK 中找到地面站 %s: %s', gsName, ME.message);
    end
    
    % Cartesian 位置（固定，與時間無關）
    try
        resPos = gsObj.DataProviders.Item('Cartesian Position').Exec;
        arrPos = resPos.DataSets.ToArray;
        r_gs_km = stkGetXYZ_FromArray(arrPos);
    catch ME
        error('無法讀取 %s 的 Cartesian Position: %s', gsName, ME.message);
    end
    
    % 緯度（用 LLA State，如果失敗就由 XYZ 計算）
    try
        resLLA = gsObj.DataProviders.Item('LLA State').Exec;
        arrLLA = resLLA.DataSets.ToArray;
        lat_deg = stkGetLat_FromArray(arrLLA);
    catch
        lat_deg = geoLatFromFixedXYZ(r_gs_km);
    end
end

% 下面幾個 helper 與 Extract_Positions_From_STK 中一致，為獨立性再定義一次
function P = stkGetXYZ_FromArray(arr)
    vals = [];
    for k = 1:numel(arr)
        a = arr{k};
        if isnumeric(a) && isscalar(a)
            vals(end+1,1) = double(a); %#ok<AGROW>
        end
    end
    if numel(vals) < 3
        error('STK XYZ extraction failed: found only %d numeric scalars.', numel(vals));
    end
    P = vals(1:3);
    P = P(:);
end

function lat = stkGetLat_FromArray(arr)
    vals = [];
    for k = 1:numel(arr)
        a = arr{k};
        if isnumeric(a) && isscalar(a)
            vals(end+1,1) = double(a); %#ok<AGROW>
        end
    end
    if isempty(vals)
        error('STK LLA extraction failed: no numeric scalars found.');
    end
    lat = vals(1);
end

function lat = geoLatFromFixedXYZ(P)
    x = P(1); y = P(2); z = P(3);
    lat = atan2d(z, sqrt(x^2 + y^2)); % geocentric latitude
end