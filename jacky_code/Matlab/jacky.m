%% 重置 Command window 與 Workspace
clear;
clc;

%% 與STK連線
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
% (1) Beam shutdown only   (2) PC + Tilt (Ren et al., Ku16)
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
evalEpfdThr_dB_Matrix = [-173.4, -169, -164.5, -160.0];  % 幾個 EPFD → 圖六幾條線

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
% 只重畫 Evaluation 時，EPFD 矩陣預設如下（應與上方 sweep 一致）：
if ~exist('evalEpfdThr_dB_Baseline', 'var')
    evalEpfdThr_dB_Baseline = -173.4;
end
if ~exist('evalEpfdThr_dB_Matrix', 'var')
    evalEpfdThr_dB_Matrix = [-173.4, -169, -164.5, -160.0];
end
numUsersPerSatPlot = 50;
% --- 圖上標題（顯示在座標軸上方；設 "" 則不顯示）---
evalFigureTitles = struct();
evalFigureTitles.fig1 = "Aggregate EPFD Compliance over Time";
evalFigureTitles.fig2 = "Number of closed beams over time";
evalFigureTitles.fig3 = sprintf("Average User Satisfaction under %d User Loads", numUsersPerSatPlot);
evalFigureTitles.fig4 = sprintf("Number of Relayed Critical Users under %d User Loads", numUsersPerSatPlot);
evalFigureTitles.fig5 = sprintf("Satisfaction CDF at Worst EPFD Slot under %d User Loads", numUsersPerSatPlot);
evalFigureTitles.fig6 = sprintf("SAPR-R Average User Satisfaction under %d User Loads", numUsersPerSatPlot);
evalFigureTitleFontSize = 13;
fprintf('Evaluation: read/write tag U%d (*_U%d_*.xlsx / figures)\n', ...
    numUsersPerSatPlot, numUsersPerSatPlot);
evalPlotParams = evalEnv.params;
evalExcelPaths = resolveEvalExcelPathsLocal(file_path, numUsersPerSatPlot);

% --- 圖一：關束後 EPFD vs 相對時間；t=0 = 全束開、backoff 前 EPFD 最高 slot ---
optsFig1 = struct();
optsFig1.sweepExcelPath = evalExcelPaths.saprR;
optsFig1.sheetName = "Slot_EPFD";
optsFig1.plotEpfdField = "after";
optsFig1.epfdThreshold_dB = evalPlotParams.EPFD_thr_dB;
optsFig1.relTimeWindowSec = [-60, 60];
optsFig1.yLim_dB = [-176, -173];
optsFig1.figureTitle = evalFigureTitles.fig1;
optsFig1.titleFontSize = evalFigureTitleFontSize;
optsFig1.figurePath = char(FullPowerSweepDataPathLocal(file_path, ...
    numUsersPerSatPlot, 'P03S49_EPFD_afterShutdown_vsRelTime', '.png'));
optsFig1.tablePath = char(FullPowerSweepDataPathLocal(file_path, ...
    numUsersPerSatPlot, 'P03S49_EPFD_afterShutdown_vsRelTime', '.xlsx'));
PlotFullPowerSweepEpfdVsRelativeTime(root, optsFig1);

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
PlotFullPowerSweepClosedCriticalBeamsVsTime(root, optsFig2);

% --- 圖三：四方法比較（P03_S49 平均 user 滿意度 vs 時間）；t=0 同圖一 ---
% 單獨重跑本 cell 時，先依 numUsersPerSatPlot 重建 excel 路徑（避免 U30/U50 混用）。
evalExcelPaths = resolveEvalExcelPathsLocal(file_path, numUsersPerSatPlot);
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
optsFig3.methodDefs(2) = struct('label', "PC + Tilt (Ren et al.)", ...
    'excelPath', evalExcelPaths.pcTilt, 'sourceType', "ku16_pc_tilt");
optsFig3.methodDefs(3) = struct('label', "Only BPLR", ...
    'excelPath', evalExcelPaths.relayOnly, 'sourceType', "fullpower");
optsFig3.methodDefs(4) = struct('label', "SAPR-R", ...
    'excelPath', evalExcelPaths.saprR, 'sourceType', "fullpower");
optsFig3.figureTitle = sprintf("Average User Satisfaction under %d User Loads", numUsersPerSatPlot);
optsFig3.titleFontSize = evalFigureTitleFontSize;
optsFig3.figurePath = char(FullPowerSweepDataPathLocal(file_path, ...
    numUsersPerSatPlot, 'P03S49_AvgUserSatisfaction_4MethodCompare', '.png'));
optsFig3.tablePath = char(FullPowerSweepDataPathLocal(file_path, ...
    numUsersPerSatPlot, 'P03S49_AvgUserSatisfaction_4MethodCompare', '.xlsx'));
if isfile(evalExcelPaths.pcTilt)
    PlotFullPowerSweepSatisfactionVsTimeCompare(root, optsFig3);
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
optsFig4.yLabel = "Number of critical closed-beam user relays";
optsFig4.yLim = [0, numUsersPerSatPlot];  % Y 軸上限 = 本次 sweep 每星 user 數（U30→30, U50→50）
optsFig4.figureTitle = sprintf("Number of Relayed Critical Users under %d User Loads", numUsersPerSatPlot);
optsFig4.titleFontSize = evalFigureTitleFontSize;
optsFig4.methodDefs(1) = struct('label', "Only BPLR", 'excelPath', evalExcelPaths.relayOnly);
optsFig4.methodDefs(2) = struct('label', "SAPR-R", 'excelPath', evalExcelPaths.saprR);
optsFig4.figurePath = char(FullPowerSweepDataPathLocal(file_path, ...
    numUsersPerSatPlot, 'P03S49_RelayUserCount_OnlyBPLR_vs_SAPR-R', '.png'));
optsFig4.tablePath = char(FullPowerSweepDataPathLocal(file_path, ...
    numUsersPerSatPlot, 'P03S49_RelayUserCount_OnlyBPLR_vs_SAPR-R', '.xlsx'));
if isfile(evalExcelPaths.relayOnly) && isfile(evalExcelPaths.saprR)
    PlotFullPowerSweepRelayUserCountCompare(root, optsFig4);
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
optsFig5.methodDefs(2) = struct('label', "Only BPLR", ...
    'excelPath', evalExcelPaths.relayOnly, 'sourceType', "fullpower");
optsFig5.methodDefs(3) = struct('label', "SAPR-R", ...
    'excelPath', evalExcelPaths.saprR, 'sourceType', "fullpower");
% 圖例順序：PC+Tilt → Only BPLR → SAPR-R；顏色固定不隨繪製順序改變
optsFig5.colors = [0.85 0.33 0.10; 0 0.45 0.74; 0.47 0.67 0.19];
optsFig5.figureTitle = sprintf("Satisfaction CDF at Worst EPFD Slot under %d User Loads", numUsersPerSatPlot);
optsFig5.titleFontSize = evalFigureTitleFontSize;
optsFig5.figurePath = char(FullPowerSweepDataPathLocal(file_path, ...
    numUsersPerSatPlot, 'P03S49_UserSatisfaction_CDF_3MethodCompare', '.png'));
optsFig5.tablePath = char(FullPowerSweepDataPathLocal(file_path, ...
    numUsersPerSatPlot, 'P03S49_UserSatisfaction_CDF_3MethodCompare', '.xlsx'));
if isfile(evalExcelPaths.relayOnly) && isfile(evalExcelPaths.saprR) && isfile(evalExcelPaths.pcTilt)
    try
        PlotFullPowerSweepUserSatisfactionCdfCompare(root, optsFig5);
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
    PlotFullPowerSweepSatisfactionVsTimeCompare(root, optsFig6);
    fprintf('Fig6 done: %d EPFD curves -> %s\n', nEpfdFig6, optsFig6.figurePath);
else
    warning('jacky:MissingFig6Excel', 'Skip fig.6: no SAPR-R Excel for evalEpfdThr_dB_Matrix.');
end








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
