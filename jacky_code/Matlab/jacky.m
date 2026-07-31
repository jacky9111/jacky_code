% =====================================================================
% jacky.m — 論文主流程（EABR：EPFD-Aware Beam Reassociation for Service Recovery）
% ---------------------------------------------------------------------
% 本檔是「一鍵驅動」腳本，用 MATLAB cell（%%）分段，請用 Ctrl+Enter 逐段執行，
% 不要整支按 F5（前段要開 STK、後段純 MATLAB，混跑會出錯）。
%
% 段落順序與論文 Evaluation（chapter6）的對應：
%   1. 連線 STK → 建 Walker 星座 → 建 beam / 地面站 / user   （Simulation Setup）
%   2. 四方法 sweep → Excel                                  （Compared Schemes）
%   3. Evaluation 區：讀 Excel 畫圖一～圖六                    （Evaluation Results）
%   4. Helper availability（不用 STK）                        （不同星座密度的 helper 可用性）
%   5. Worst-EPFD 場景圖（不用 STK）                          （最壞 EPFD 時刻 SSP+16 beam 圖）
%   6. Computational overhead（不用 STK）                     （線上計算負擔）
%
% 詳細操作與參數說明請看專案根目錄的 README.md。
% =====================================================================

%% 重置 Command window 與 Workspace
clear;
clc;

%% 與STK連線
% 需先手動開啟 STK 12 並載入/新建場景，本段只是抓取已在執行的 STK COM 物件。
disp("連接STK");
con = actxGetRunningServer('STK12.application');
root = con.Personality2;
con.Visible = 10;
disp("---------------------- done");

%% 初始化
addpath(fullfile(pwd,'jacky_code', 'Matlab', 'jacky'));
disp("初始化");
% Satellite_Name() 主要用於 OneWeb/TLE 命名對應，Walker 建星本身不依賴它。
% Satellite_Name();
file_path = "C:\Users\jacky\Desktop\jacky_code\jacky_code\";
if ~exist(file_path + 'STK','dir')
    mkdir(file_path);
end
if ~exist(file_path + 'Matlab_data','dir')
    mkdir(file_path);
end
try
    sc = root.CurrentScenario;
catch
    sc = [];
end
disp("---------------------- done");

% ------------------------------------------------------------
% Walker Star / near-polar shell constellation (LEO)
% Create only Plane 1 (48 satellites) per your request.
% ------------------------------------------------------------

%% ================== 建立衛星================== 
alt_km = 1200;
inc_deg = 87.9;
% Walker 內建 p=2..numPlanes；要含 P17/P18 軌道面請設 numPlanes >= 18
numPlanes = 12;
beamProfile = "-5dB"; % "-3dB" or "-5dB"
% Only one variable to control satellites per plane.
satsPerPlane = 49;

satPrefix = "WalkerStar";

% If scenario already exists, prefer using its StartTime as epoch (more consistent).
tEpochStr = datestr(datetime('now','TimeZone','UTC'), 'dd mmm yyyy HH:MM:SS');
try
    tEpochStr = char(sc.StartTime);
catch
end
CreateWalkerConstellation_HPOP( ...
    root, sc, alt_km, inc_deg, numPlanes, satsPerPlane, tEpochStr);

% 只對指定軌道面建 RectBeam：從 STK 場景讀衛星（Pxx_Syy），不依賴建星回傳的 leo
rectBeamPlanes = [3];
leoRectBeam = GetStkSatelliteNamesByPlane(root, rectBeamPlanes);
if isempty(leoRectBeam)
    warning('jacky:RectBeamEmpty', ...
        'leoRectBeam is empty; check rectBeamPlanes or satellites in the STK scenario.');
end

%% ================== 建立 beam（STK 僅單一大矩形）==================
% 16 束 EPFD 在後段 RunEpfd16BeamsKuLogExcel 用 MATLAB 模擬，不在此建 16 個 sensor。
CreateOneWebRectBeam(root, leoRectBeam, "RectBeam", beamProfile);

%% ================== 建立地面站（範例）==================
AddGroundStationToSTK(root, "GS_01", 0, 121);

%% ================== 建立user（範例）==================
satUserTargets = [
    "P01_S01"
    "P01_S02"
    "P01_S49"
    "P01_S48"
    "P01_S47"
    "P02_S01"
    "P02_S02"
    "P02_S49"
    "P02_S48"
    "P02_S47"
    "P03_S01"
    "P03_S02"
    "P03_S49"
    "P03_S48"
    "P03_S47"
    "P04_S01"
    "P04_S02"
    "P04_S49"
    "P04_S48"
    "P04_S47"
    "P05_S01"
    "P05_S02"
    "P05_S49"
    "P05_S48"
    "P05_S47"
];
AddUsersAroundSatellitesToSTK(root, satUserTargets, 1888, 30);


%% ================== 四方法模擬 → Excel ==================
% (1) Beam shutdown only   (2) PC + Tilt (Jalali et al., Ku16)
% (3) Relay only           (4) SAPR-R (Relay + middle safe-beam swap)
% 共用 eval* / evalEnv；僅控制模型不同。下方 Evaluation 區讀這些 xlsx 畫圖一～三。

% --- 共用評估環境（改這裡四條曲線一起變）---
evalCriticalSat = "P03_S49";
evalRecordSats = ["P03_S01", "P03_S49", "P03_S48"];  % Excel 詳列：滿意度 / Ku16 Per* 只寫這三顆
evalTStartStr = "16 Dec 2025 12:11:00";
evalTEndStr = "16 Dec 2025 12:13:30";
evalStepSec = 1;
evalBeamHalfEW_deg = 34.0;        % 與 RectBeam -5 dB 一致
evalBeamHalfNS_deg = 33.5 / 16;
evalGsLat_deg = 0;
evalGsLon_deg = 120.4;            % Ideal GSO @ GS
evalUsersPerSat_Matrix = [30, 50, 70];  % 改這裡：圖一～五，一次跑多個 U、每 U 跑四方法
evalUserDemand_Mbps = 50;
evalFullBeamPower_W = 1.05;       % 開束 on-air；Ku16 Ptotal_W = ×16
evalMaxBeamPower_W = 2;           % helper relay beam 功率上限（僅 full-power）
evalEpfdThr_dB_Baseline = -173.4; % 圖一～五 EPFD 門檻

footprintEW_km = 2 * alt_km * tand(evalBeamHalfEW_deg);
footprintNS_km = 2 * alt_km * tand(33.5);
evalUserAreaSide_km = max(footprintEW_km, footprintNS_km);

for iUserSweep = 1:numel(evalUsersPerSat_Matrix)
    evalUsersPerSat = evalUsersPerSat_Matrix(iUserSweep);
    numUsersPerSatSweep = evalUsersPerSat;
    fprintf('\n===== Sweep U%d (%d/%d): four methods (fig.1-5) =====\n', ...
        numUsersPerSatSweep, iUserSweep, numel(evalUsersPerSat_Matrix));

    evalEnv = BuildEvalEnvironmentLocal(evalCriticalSat, evalTStartStr, evalTEndStr, evalStepSec, ...
        evalBeamHalfEW_deg, evalBeamHalfNS_deg, evalGsLat_deg, evalGsLon_deg, ...
        evalUsersPerSat, evalUserDemand_Mbps, evalFullBeamPower_W, evalMaxBeamPower_W, ...
        evalRecordSats, satUserTargets, satUserTargets, @ku_epfd_params);

    RunEvalFourMethodSweepsLocal(root, file_path, evalEnv, evalUserAreaSide_km, ...
        evalCriticalSat, numUsersPerSatSweep, evalEpfdThr_dB_Baseline, false);
end

% 圖六 sweep（獨立；單一 U × 多 EPFD，只跑 SAPR-R）
evalUsersPerSat_Fig6 = 70;  % 改這裡：圖六只用一個 U（畫圖時 numUsersPerSatPlot 請設相同）
evalEpfdThr_dB_Matrix = [-173.4, -172.4, -171.4, -170.4];  % 幾個 EPFD → 圖六幾條線

fprintf('\n===== Sweep fig.6: U%d, SAPR-R only =====\n', evalUsersPerSat_Fig6);
evalEnvFig6 = BuildEvalEnvironmentLocal(evalCriticalSat, evalTStartStr, evalTEndStr, evalStepSec, ...
    evalBeamHalfEW_deg, evalBeamHalfNS_deg, evalGsLat_deg, evalGsLon_deg, ...
    evalUsersPerSat_Fig6, evalUserDemand_Mbps, evalFullBeamPower_W, evalMaxBeamPower_W, ...
    evalRecordSats, satUserTargets, satUserTargets, @ku_epfd_params);

for iEpfdSweep = 1:numel(evalEpfdThr_dB_Matrix)
    epfdThrSweep = evalEpfdThr_dB_Matrix(iEpfdSweep);
    if abs(epfdThrSweep - evalEpfdThr_dB_Baseline) < 1e-9
        continue;  % -173.4 baseline SAPR-R 已在上方四方法 sweep 產生
    end
    RunEvalSaprRSweepLocal(root, file_path, evalEnvFig6, evalUserAreaSide_km, ...
        evalUsersPerSat_Fig6, epfdThrSweep, true);
end

%% ================== Evaluation（讀 Excel 畫圖；只重畫可註解掉上方 Run*）==================
% 圖一、二預設用 SAPR-R（RelayWithMiddleSwap）；圖三用四個方法的 xlsx。
% 單獨重跑本 cell 時，下方會補齊路徑 / evalCriticalSat / EPFD 門檻等預設值。
if ~exist('file_path', 'var') || strlength(string(file_path)) == 0
    file_path = "C:\Users\jacky\Desktop\jacky_code\jacky_code\";
end
jackyPlotDir = fullfile(file_path, 'Matlab', 'jacky');
if isfolder(jackyPlotDir)
    addpath(jackyPlotDir);
end
% Excel-only replot: PlotFullPowerSweep* ignore arg-1 (no STK). Avoid bare
% "root" when STK was not opened — MATLAB may resolve it to symbolic root().
evalPlotRoot = [];
if ~exist('evalCriticalSat', 'var') || strlength(string(evalCriticalSat)) == 0
    evalCriticalSat = "P03_S49";
end
% 只重畫 Evaluation 時，EPFD 矩陣預設如下（應與上方 sweep 一致）：
if ~exist('evalEpfdThr_dB_Baseline', 'var')
    evalEpfdThr_dB_Baseline = -173.4;
end
if ~exist('evalEpfdThr_dB_Matrix', 'var')
    evalEpfdThr_dB_Matrix = [-173.4, -172.4, -171.4, -170.4];
end
numUsersPerSatPlot = 70;
% --- 圖上標題（生圖不顯示；標題寫在 LaTeX caption）---
evalFigureTitles = struct();
evalFigureTitles.fig1 = "";
evalFigureTitles.fig2 = "";
evalFigureTitles.fig3 = "";
evalFigureTitles.fig4 = "";
evalFigureTitles.fig5 = "";
evalFigureTitles.fig6 = "";
evalFigureTitleFontSize = 13;
evalLegendLocation = 'southeast';
fprintf('Evaluation: read/write tag U%d (*_U%d_*.xlsx / figures)\n', ...
    numUsersPerSatPlot, numUsersPerSatPlot);
if exist('evalEnv', 'var') && isstruct(evalEnv) && isfield(evalEnv, 'params')
    evalEpfdThrPlot_dB = evalEnv.params.EPFD_thr_dB;
else
    evalEpfdThrPlot_dB = evalEpfdThr_dB_Baseline;
end
evalExcelPaths = resolveEvalExcelPathsLocal(file_path, numUsersPerSatPlot);

% --- 圖一：關束後 EPFD vs 相對時間；t=0 = 全束開、backoff 前 EPFD 最高 slot ---
optsFig1 = struct();
optsFig1.sweepExcelPath = evalExcelPaths.saprR;
optsFig1.sheetName = "Slot_EPFD";
optsFig1.plotEpfdField = "after";
optsFig1.epfdThreshold_dB = evalEpfdThrPlot_dB;
optsFig1.relTimeWindowSec = [-60, 60];
optsFig1.yLim_dB = [-176, -173];
optsFig1.figureTitle = evalFigureTitles.fig1;
optsFig1.titleFontSize = evalFigureTitleFontSize;
optsFig1.figurePath = char(FullPowerSweepDataPathLocal(file_path, ...
    numUsersPerSatPlot, 'P03S49_EPFD_afterShutdown_vsRelTime', '.png'));
optsFig1.tablePath = char(FullPowerSweepDataPathLocal(file_path, ...
    numUsersPerSatPlot, 'P03S49_EPFD_afterShutdown_vsRelTime', '.xlsx'));
PlotFullPowerSweepEpfdVsRelativeTime(evalPlotRoot, optsFig1);

% --- 圖二：critical 衛星被關閉 beam 數（SAPR-R 單曲線）；X 軸與圖一相同 ---
optsFig2 = struct();
optsFig2.sweepExcelPath = evalExcelPaths.saprR;
optsFig2.criticalSatellite = evalCriticalSat;
optsFig2.relTimeWindowSec = [-60, 60];
optsFig2.timeSegmentEdges = [-60, -40, -20, 0, 20, 40, 60];
optsFig2.segmentAggregate = "mean";
optsFig2.yLim = [0, 16];
optsFig2.figureTitle = evalFigureTitles.fig2;
optsFig2.titleFontSize = evalFigureTitleFontSize;
optsFig2.figurePath = char(FullPowerSweepDataPathLocal(file_path, ...
    numUsersPerSatPlot, 'P03S49_ClosedCriticalBeams_vsRelTime', '.png'));
optsFig2.tablePath = char(FullPowerSweepDataPathLocal(file_path, ...
    numUsersPerSatPlot, 'P03S49_ClosedCriticalBeams_vsRelTime', '.xlsx'));
PlotFullPowerSweepClosedCriticalBeamsVsTime(evalPlotRoot, optsFig2);

% --- 圖三：四方法比較（P03_S49 平均 user 滿意度 vs 時間）；t=0 同圖一 ---
% 單獨重跑本 cell 時，先依 numUsersPerSatPlot 重建 excel 路徑（避免 U30/U50 混用）。
assertFig3ExcelPathsMatchPlotTag(numUsersPerSatPlot, ...
    {evalExcelPaths.backoffOnly, evalExcelPaths.relayOnly, ...
    evalExcelPaths.saprR, evalExcelPaths.pcTilt}, evalCriticalSat);
optsFig3 = struct();
optsFig3.referenceExcelPath = evalExcelPaths.saprR;
optsFig3.recordSatellite = evalCriticalSat;
optsFig3.relTimeWindowSec = [-60, 60];
optsFig3.yAxisPercent = true;
optsFig3.yLim = [0, 100];
optsFig3.methodDefs(1) = struct('label', "Beam shutdown only", ...
    'excelPath', evalExcelPaths.backoffOnly, 'sourceType', "fullpower");
optsFig3.methodDefs(2) = struct('label', "PC + Tilt", ...
    'excelPath', evalExcelPaths.pcTilt, 'sourceType', "ku16_pc_tilt");
optsFig3.methodDefs(3) = struct('label', "Only HBR", ...
    'excelPath', evalExcelPaths.relayOnly, 'sourceType', "fullpower");
optsFig3.methodDefs(4) = struct('label', "EABR", ...
    'excelPath', evalExcelPaths.saprR, 'sourceType', "fullpower");
optsFig3.figureTitle = evalFigureTitles.fig3;
optsFig3.titleFontSize = evalFigureTitleFontSize;
optsFig3.legendLocation = evalLegendLocation;
optsFig3.figurePath = char(FullPowerSweepDataPathLocal(file_path, ...
    numUsersPerSatPlot, 'P03S49_AvgUserSatisfaction_4MethodCompare', '.png'));
optsFig3.tablePath = char(FullPowerSweepDataPathLocal(file_path, ...
    numUsersPerSatPlot, 'P03S49_AvgUserSatisfaction_4MethodCompare', '.xlsx'));
if isfile(evalExcelPaths.pcTilt)
    PlotFullPowerSweepSatisfactionVsTimeCompare(evalPlotRoot, optsFig3);
else
    warning('jacky:MissingKu16TiltExcel', ...
        'Skip fig.3: missing %s. Re-run PC+Tilt simulation above.', evalExcelPaths.pcTilt);
end

% --- 圖四：Only BPLR vs SAPR-R relay user 數（長條圖）；t=0 同圖一 ---
% X 軸 / Excel 只記 -60,-40,-20,0,20,40,60（與圖二相同）。
evalExcelPaths = resolveEvalExcelPathsLocal(file_path, numUsersPerSatPlot);
optsFig4 = struct();
optsFig4.referenceExcelPath = evalExcelPaths.saprR;
optsFig4.recordSatellite = evalCriticalSat;
optsFig4.relTimeWindowSec = [-60, 60];
optsFig4.timeSegmentEdges = [-60, -40, -20, 0, 20, 40, 60];  % 與圖二相同
optsFig4.relayUserMetric = "satisfied";
optsFig4.relaySuccessThreshold = 0.9;
optsFig4.segmentAggregate = "mean";
optsFig4.barWidth = 1;
optsFig4.yLabel = "Number of recovered closed-beam users";
optsFig4.yLim = [0, numUsersPerSatPlot];  % Y 軸上限 = 本次 sweep 每星 user 數（U30→30, U50→50）
optsFig4.figureTitle = evalFigureTitles.fig4;
optsFig4.titleFontSize = evalFigureTitleFontSize;
optsFig4.methodDefs(1) = struct('label', "Only HBR", 'excelPath', evalExcelPaths.relayOnly);
optsFig4.methodDefs(2) = struct('label', "EABR", 'excelPath', evalExcelPaths.saprR);
optsFig4.figurePath = char(FullPowerSweepDataPathLocal(file_path, ...
    numUsersPerSatPlot, 'P03S49_RelayUserCount_OnlyBPLR_vs_SAPR-R', '.png'));
optsFig4.tablePath = char(FullPowerSweepDataPathLocal(file_path, ...
    numUsersPerSatPlot, 'P03S49_RelayUserCount_OnlyBPLR_vs_SAPR-R', '.xlsx'));
if isfile(evalExcelPaths.relayOnly) && isfile(evalExcelPaths.saprR)
    PlotFullPowerSweepRelayUserCountCompare(evalPlotRoot, optsFig4);
else
    warning('jacky:MissingFig4Excel', 'Skip fig.4: need RelayOnly and RelayWithMiddleSwap U%d xlsx.', ...
        numUsersPerSatPlot);
end

% --- 圖五：t0 時刻 user 滿意度 CDF（同圖三/四：P03_S49 home cohort @ t0）---
% full-power 需含 PerUser sheet → 若舊 xlsx 無此 sheet，請重跑 RelayOnly / SAPR-R sweep。
evalExcelPaths = resolveEvalExcelPathsLocal(file_path, numUsersPerSatPlot);
optsFig5 = struct();
optsFig5.referenceExcelPath = evalExcelPaths.saprR;
optsFig5.userSetMode = "home_cohort";    % 同圖三/四：evalCriticalSat 的 home cohort
optsFig5.recordSatellite = evalCriticalSat;
optsFig5.xAxisPercent = false;
optsFig5.methodDefs(1) = struct('label', "PC + Tilt", ...
    'excelPath', evalExcelPaths.pcTilt, 'sourceType', "ku16_pc_tilt");
optsFig5.methodDefs(2) = struct('label', "Only HBR", ...
    'excelPath', evalExcelPaths.relayOnly, 'sourceType', "fullpower");
optsFig5.methodDefs(3) = struct('label', "EABR", ...
    'excelPath', evalExcelPaths.saprR, 'sourceType', "fullpower");
% 圖例順序：PC+Tilt → Only HBR → EABR；顏色固定不隨繪製順序改變
optsFig5.colors = [0.85 0.33 0.10; 0 0.45 0.74; 0.47 0.67 0.19];
optsFig5.figureTitle = evalFigureTitles.fig5;
optsFig5.titleFontSize = evalFigureTitleFontSize;
optsFig5.legendLocation = evalLegendLocation;
optsFig5.figurePath = char(FullPowerSweepDataPathLocal(file_path, ...
    numUsersPerSatPlot, 'P03S49_UserSatisfaction_CDF_3MethodCompare', '.png'));
optsFig5.tablePath = char(FullPowerSweepDataPathLocal(file_path, ...
    numUsersPerSatPlot, 'P03S49_UserSatisfaction_CDF_3MethodCompare', '.xlsx'));
if isfile(evalExcelPaths.relayOnly) && isfile(evalExcelPaths.saprR) && isfile(evalExcelPaths.pcTilt)
    try
        PlotFullPowerSweepUserSatisfactionCdfCompare(evalPlotRoot, optsFig5);
    catch ME
        if contains(ME.message, 'PerUser')
            warning('jacky:MissingPerUserSheet', ...
                ['Skip fig.5: %s. Re-run RelayOnly and SAPR-R sweeps to create PerUser sheet.'], ME.message);
        else
            rethrow(ME);
        end
    end
else
    warning('jacky:MissingFig5Excel', ...
        'Skip fig.5: need RelayOnly, SAPR-R, and Ku16/PC+Tilt U%d xlsx.', numUsersPerSatPlot);
end

% --- 圖六：SAPR-R 在不同 EPFD 門檻（同圖三格式）；matrix 幾個 EPFD 就畫幾條線 ---
optsFig6 = struct();
optsFig6.recordSatellite = evalCriticalSat;
optsFig6.relTimeWindowSec = [-60, 60];
optsFig6.yAxisPercent = true;
optsFig6.yLim = [0, 100];
optsFig6.figureTitle = evalFigureTitles.fig6;
optsFig6.titleFontSize = evalFigureTitleFontSize;
optsFig6.legendLocation = evalLegendLocation;
optsFig6.figurePath = char(FullPowerSweepDataPathLocal(file_path, ...
    numUsersPerSatPlot, 'P03S49_SAPR-R_AvgUserSatisfaction_EpfdCompare', '.png'));
optsFig6.tablePath = char(FullPowerSweepDataPathLocal(file_path, ...
    numUsersPerSatPlot, 'P03S49_SAPR-R_AvgUserSatisfaction_EpfdCompare', '.xlsx'));
nEpfdFig6 = 0;
for iEpfdPlot = 1:numel(evalEpfdThr_dB_Matrix)
    epfdThrPlot = evalEpfdThr_dB_Matrix(iEpfdPlot);
    if abs(epfdThrPlot - evalEpfdThr_dB_Baseline) < 1e-9
        pathEpfdThr = [];
    else
        pathEpfdThr = epfdThrPlot;
    end
    evalExcelPathsFig6 = resolveEvalExcelPathsLocal(file_path, numUsersPerSatPlot, pathEpfdThr);
    if ~isfile(evalExcelPathsFig6.saprR)
        warning('jacky:MissingFig6Excel', ...
            'Skip fig.6 line EPFD=%.1f dB: missing %s. Re-run SAPR-R sweep for this threshold.', ...
            epfdThrPlot, evalExcelPathsFig6.saprR);
        continue;
    end
    nEpfdFig6 = nEpfdFig6 + 1;
    optsFig6.methodDefs(nEpfdFig6) = struct( ...
        'label', sprintf("EPFD %.1f dB", epfdThrPlot), ...
        'excelPath', evalExcelPathsFig6.saprR, ...
        'referenceExcelPath', evalExcelPathsFig6.saprR, ...
        'sourceType', "fullpower");
end
if nEpfdFig6 > 0
    optsFig6.referenceExcelPath = optsFig6.methodDefs(1).excelPath;
    PlotFullPowerSweepSatisfactionVsTimeCompare(evalPlotRoot, optsFig6);
    fprintf('Fig6 done: %d EPFD curves -> %s\n', nEpfdFig6, optsFig6.figurePath);
else
    warning('jacky:MissingFig6Excel', 'Skip fig.6: no SAPR-R Excel for evalEpfdThr_dB_Matrix.');
end


%% ========= Helper availability: OneWeb polar density variants (MATLAB-only) =========
% 獨立模擬模組：三種密度皆用同一 OneWeb 極軌殼層（1200 km / 87.9° / star Walker），
% 只改 Walker 平面數 P 與每平面衛星數 S；16-beam / EPFD / helper 準則相同。
%   OneWeb-like reference : 12 x 49 =  588（論文主模擬）
%   Medium-density        : 24 x 50 = 1200（介於 reference 與 high 之間）
%   High-density          : 36 x 74 = 2664（密度程度參考 Starlink 總規模）
%   Low-density           :  8 x 36 =  288（平面與同軌間距皆比 reference 疏；總規模參考 Lightspeed）
% Footprint 半角以 reference 同軌 ±1 半覆蓋校準，三密度共用。
% 不使用 STK，也不修改上方主模擬的既有結果。
if ~exist('file_path', 'var') || strlength(string(file_path)) == 0
    file_path = "C:\Users\jacky\Desktop\jacky_code\jacky_code\";
end
addpath(fullfile(file_path, 'Matlab', 'helper_availability'));
addpath(fullfile(file_path, 'Matlab', 'jacky'));
addpath(fullfile(file_path, 'Matlab', 'powertilt'));

% --- 可調：helper 與 critical 關閉束重疊面積加總須 >= 此值 × 一條 beam 面積 ---
helperMinOverlapBeamFrac = 1;   % 例：1.0=至少一條 beam；0.5=半條；改這裡即可
helperTimeHalfWindow_s = 30;    % 對齊時刻 t=0 前後各 N 秒（共 2N+1 個 1 s slot）
% --- 可調：只跑部分密度（"all" 或單一名稱 / 名稱陣列）---
helperConstellationsToRun = "Low-density";   % 例："Low-density" 只跑低密度統計

cfgHelper = config_helper_availability();
cfgHelper = select_helper_constellations(cfgHelper, helperConstellationsToRun);
cfgHelper.common.tStart_s = -helperTimeHalfWindow_s;
cfgHelper.common.tEnd_s = helperTimeHalfWindow_s;
cfgHelper.common.helperMinOverlapBeamFrac = helperMinOverlapBeamFrac;
cfgHelper.common.helperMinOverlapArea_km2 = ...
    helperMinOverlapBeamFrac * cfgHelper.common.oneBeamArea_km2;
fprintf('[jacky] helperMinOverlapBeamFrac=%.3g -> min overlap=%.1f km^2 (oneBeam=%.1f)\n', ...
    helperMinOverlapBeamFrac, cfgHelper.common.helperMinOverlapArea_km2, ...
    cfgHelper.common.oneBeamArea_km2);
fprintf('[jacky] time window: t=[%d,%d] s (±%d s around t=0)\n', ...
    cfgHelper.common.tStart_s, cfgHelper.common.tEnd_s, helperTimeHalfWindow_s);

[helperAvailabilitySummary, helperAvailabilityCases] = main_helper_availability(cfgHelper);
disp(helperAvailabilitySummary);

%% ========= Worst-EPFD scene: SSP + 16 beams (MATLAB-only) =========
% 不做每個 time slot 的 helper 統計圖。只搜尋各星座最危險 EPFD 時刻，
% 再於該瞬間辨識 critical / helper，畫 lon/lat 圖：每顆衛星星下點 + 16 條
% 長方形 beam footprint（critical 關閉束另標色）。存到
% helper_availability/results/figures 與 Matlab_data。
if ~exist('file_path', 'var') || strlength(string(file_path)) == 0
    file_path = "C:\Users\jacky\Desktop\jacky_code\jacky_code\";
end
addpath(fullfile(file_path, 'Matlab', 'helper_availability'));
addpath(fullfile(file_path, 'Matlab', 'jacky'));
addpath(fullfile(file_path, 'Matlab', 'powertilt'));

% --- 可調（本段獨立生效；每次重建 config，避免沿用工作區舊星座）---
helperMinOverlapBeamFrac = 1;   % 例：1.0=至少一條 beam；0.5=半條；改這裡即可
% --- 可調：只跑部分密度（"all" 或單一名稱 / 名稱陣列）---
helperPlotConstellationsToRun = "Medium-density";   % 例："Low-density" 只畫低密度 worst-EPFD 圖

cfgHelper = config_helper_availability();   % 強制用目前的 reference/high/low-density
cfgHelper = select_helper_constellations(cfgHelper, helperPlotConstellationsToRun);
% worst-EPFD 搜尋維持 config 預設全窗（±120 s），只取感擾最大那一瞬間畫圖
cfgHelper.common.helperMinOverlapBeamFrac = helperMinOverlapBeamFrac;
cfgHelper.common.helperMinOverlapArea_km2 = ...
    helperMinOverlapBeamFrac * cfgHelper.common.oneBeamArea_km2;
fprintf('[jacky plot] helperMinOverlapBeamFrac=%.3g -> min overlap=%.1f km^2\n', ...
    helperMinOverlapBeamFrac, cfgHelper.common.helperMinOverlapArea_km2);
fprintf('[jacky plot] worst-EPFD search: t=[%d,%d] s (config default)\n', ...
    cfgHelper.common.tStart_s, cfgHelper.common.tEnd_s);
fprintf('[jacky plot] geometries: %s\n', strjoin(string(cellfun(@(c) c.name, ...
    cfgHelper.constellations, 'UniformOutput', false)), ' | '));

worstSlotSchematic = main_worst_slot_schematic(cfgHelper);




%% ========= Computational overhead: Only HBR / PC+Tilt vs EABR (MATLAB-only) =========
% 獨立模擬模組：不使用 STK。幾何用 OneWeb-like Walker（同 helper_availability）。
% 先找 GS 最壞 EPFD 時刻 t_worst，再取前後 N 秒（每 1 s 一個 slot）。
% 每個 slot 量一次 online execution time；圖上 bar=平均，黑 I=執行時間範圍。
%
% 三個方法都跑在同一組場景上（同幾何、同 user、同關閉束），確保公平：
%   Only HBR：runGraphSelectionPolicyLocal + onlyHbrWithInitialPower（跳過 SBR）
%   PC+Tilt ：重現的 Ku16 PC+Tilt 線上邏輯
%   EABR    ：SBR + 功率重配 + HBR
%
% 本段一次產生論文的兩張 overhead 圖（存到 results/ 與 Matlab_data/）：
%   runtime_overhead_pc_tilt_vs_eabr.{png,fig,pdf}    → 論文 Fig. PC+Tilt vs EABR
%   runtime_overhead_only_hbr_vs_eabr.{png,fig,pdf}   → 論文 ch5_overhead_only_hbr_vs_eabr
if ~exist('file_path', 'var') || strlength(string(file_path)) == 0
    file_path = "C:\Users\jacky\Desktop\jacky_code\jacky_code\";
end
addpath(fullfile(file_path, 'Matlab', 'overhead_evaluation'));
addpath(fullfile(file_path, 'Matlab', 'jacky'));
addpath(fullfile(file_path, 'Matlab', 'powertilt'));
addpath(fullfile(file_path, 'Matlab', 'helper_availability'));

% --- 可調：t_worst 前後各 N 秒（共 2N 個 1 s slot；例 N=30 → 60 slots）---
overheadSlotHalfWindow_s = 30;
% --- 可調：是否一併量測 Only HBR（多產生 Only HBR vs EABR 那張圖）---
% true  → 每個負載多跑一輪 Only HBR，總時間約增加三分之一
% false → 只量 PC+Tilt 與 EABR
overheadMeasureOnlyHbr = true;
% --- 可調：PC+Tilt 線上 tilt 搜尋（overhead 量測用；滿意度比較仍用 RunKu16）---
% 'max_only'      ：PC 有降功率時，只試 ±tiltMax（最快；候選最多 2 個）
% 'coarse_to_fine'：先粗搜再局部細搜
% 'exhaustive'    ：±tiltMax 固定步長全掃（最慢）
overheadPcTiltSearchMode = 'max_only';
overheadPcTiltCoarseStep_deg = 2.0;
overheadPcTiltFineStep_deg = 0.5;
overheadPcTiltFineHalfWidth_deg = 2.0;
overheadPcTiltStep_deg = 2.0;   % exhaustive 模式時使用

cfgOverhead = overhead_config();
cfgOverhead.slotHalfWindow_s = overheadSlotHalfWindow_s;
cfgOverhead.measureOnlyHbr = overheadMeasureOnlyHbr;
cfgOverhead.pcTiltSearchMode = overheadPcTiltSearchMode;
cfgOverhead.pcTiltCoarseStep_deg = overheadPcTiltCoarseStep_deg;
cfgOverhead.pcTiltFineStep_deg = overheadPcTiltFineStep_deg;
cfgOverhead.pcTiltFineHalfWidth_deg = overheadPcTiltFineHalfWidth_deg;
cfgOverhead.pcTiltStep_deg = overheadPcTiltStep_deg;
fprintf('[jacky overhead] measurement window: t_worst ±%d s (%d slots)\n', ...
    overheadSlotHalfWindow_s, 2 * overheadSlotHalfWindow_s);
fprintf('[jacky overhead] PC+Tilt search: %s (maxTilt=±%.1f deg)\n', ...
    overheadPcTiltSearchMode, cfgOverhead.pcTiltMax_deg);
if overheadMeasureOnlyHbr
    fprintf('[jacky overhead] methods: Only HBR + PC+Tilt + EABR (2 figures)\n');
else
    fprintf('[jacky overhead] methods: PC+Tilt + EABR (1 figure)\n');
end
overheadResults = main_overhead_evaluation(cfgOverhead);
disp(overheadResults.summaryTable);












%% ================== 場景儲存================== 
%% Save STK scenario
disp("save");
root.Save;
disp("---------------------- dick");

%% STK 場景另存新檔 (M)
disp("Save as");
sub_file_path = file_path + "jacky_STK"; % modify
if ~exist(sub_file_path,'dir')
    mkdir(sub_file_path);
end
root.SaveAs(file_path + 'jacky_STK\Scenario'); % modify
disp("---------------------- done");

%% STL 關閉後用載入的方式開啟
disp("載入剛剛 SaveAs 的 Walker 場景");
root.LoadScenario(file_path + 'jacky_STK\Scenario.sc');
sc = root.CurrentScenario;
disp("---------------------- done");
