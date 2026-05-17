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
leo = CreateWalkerConstellation_HPOP( ...
    root, sc, alt_km, inc_deg, numPlanes, satsPerPlane, tEpochStr);

% 只對指定軌道面建 RectBeam：衛星命名為 Pxx_Syy，只保留 P02_*, P03_*, P17_*, P18_*
rectBeamPlanes = [1,2,3,4,5];
maskRect = false(size(leo));
for kp = 1:numel(rectBeamPlanes)
    maskRect = maskRect | startsWith(leo, sprintf('P%02d_', rectBeamPlanes(kp)));
end
leoRectBeam = leo(maskRect);
% CreateWalkerConstellation_HPOP 使用 p=2:numPlanes；要有 P17/P18 須 numPlanes >= 18
if isempty(leoRectBeam)
    warning('jacky:RectBeamEmpty', 'leoRectBeam is empty; raise numPlanes (need >=18 for P17/P18) or check plane list.');
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


%% ================== Ku EPFD：16 束（純 MATLAB）+ 每秒 Excel ==================
% STK 端只保留上面單一 RectBeam（快速看 seamless / relay）；不在 STK 建 16 個 sensor。
% 下列僅從 STK 讀 LEO / GEO / GSO 地面站位置與速度，16 束北→南在 MATLAB 內模擬（RunEpfd16BeamsKuLogExcel）。
% 地面站命名：*/Facility/GSO_GS_<GEO衛星名>（與 SystemWide16 一致）
leo_part = [
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

geo_part = [
    "GS_01"
];

optsEpfd = struct();
optsEpfd.leoList = cellstr(leo_part);
optsEpfd.geoList = cellstr(geo_part);
optsEpfd.stepSec = 1;
optsEpfd.excelPath = char(fullfile(file_path, 'Matlab_data', 'LEO16_EPFD_Ku_log.xlsx'));
optsEpfd.params = ku_epfd_params(); % 物理/鏈路參數見 ku_epfd_params.m
optsEpfd.beamHalfEW_deg = 36;
optsEpfd.beamHalfNS_deg = 36.5/16;
optsEpfd.controlMode = "aggregate"; % "aggregate" or "per_beam"
% optsEpfd.minOnBeams = 4; % 先關閉保底限制，觀察純干擾驅動的關束規律
% 直接指定 EPFD 模擬起訖時間（UTCG 格式）：dd mmm yyyy HH:MM:SS
% optsEpfd.tStartStr = char(sc.StartTime);  % 例: '24 Mar 2026 00:00:00'
% optsEpfd.tEndStr   = char(sc.StopTime);   % 例: '24 Mar 2026 00:10:00'
% 若你想手動寫死時間，可改成：
optsEpfd.tStartStr = '16 Dec 2025 12:21:53';
optsEpfd.tEndStr   = '16 Dec 2025 12:29:33';
% RunEpfd16BeamsKuLogExcel(root, optsEpfd);

%% ================== Ku 16-beam baseline observation (no EPFD power backoff) ==================
optsBase = optsEpfd;
optsBase.excelPath = char(fullfile(file_path, 'Matlab_data', 'LEO16_Ku_Baseline_Observation.xlsx'));
optsBase.usersPerSat = 12;
optsBase.satTotalDemandGbps =0.3; % fixed per-satellite total demand
optsBase.enablePowerControl = false; % no uniform scale-down vs EPFD_thr; compare agains
optsBase.useGsoNoiseInQualityMetric = true;
optsBase.excelSatelliteIds = {'P01_S62', 'P01_S61', 'P01_S60'}; % Excel only; full leoList still used in physics
RunKu16BeamBaselineObservationLogExcel(root, optsBase);

%% ================== Ku 16-beam baseline observation + EPFD power control ==================
optsBasePC_simple = optsBase;
optsBasePC_simple.excelPath = char(fullfile(file_path, 'Matlab_data', 'LEO16_Ku_Baseline_Observation_PC.xlsx'));
optsBasePC_simple.enablePowerControl = true;
optsBasePC_simple.enablePowerRedistribution = false;
RunKu16BeamBaselineObservationLogExcel(root, optsBasePC_simple);

%% ================== Ku 16-beam baseline observation + PC + bidirectional relay ==================
optsBasePC_relay = optsBase;
optsBasePC_relay.excelPath = char(fullfile(file_path, 'Matlab_data', 'LEO16_Ku_Baseline_Observation_PC_BidirectionalRelay.xlsx'));
optsBasePC_relay.enablePowerControl = true;
optsBasePC_relay.enablePowerRedistribution = false;
optsBasePC_relay.enableBidirectionalRelay = true;
optsBasePC_relay.relaySourceSatelliteId = "P01_S61";
optsBasePC_relay.relayDistressedSatisfactionFloor = 0.6;
RunKu16BeamBaselineObservationLogExcel(root, optsBasePC_relay);

%% ================== Ku 16-beam baseline observation + PC + baseline tilt ==================
optsBasePC_tilt = optsBase;
optsBasePC_tilt.excelPath = char(fullfile(file_path, 'Matlab_data', 'LEO16_Ku_Baseline_Observation_PC_BaselineTilt.xlsx'));
optsBasePC_tilt.enablePowerControl = true;
optsBasePC_tilt.enablePowerRedistribution = false;
optsBasePC_tilt.enableBaselineTilt = true;
optsBasePC_tilt.baselineTiltSatelliteId = "P01_S61";
optsBasePC_tilt.baselineTiltMaxDeg = 10;
optsBasePC_tilt.baselineTiltStepDeg = 0.5;
RunKu16BeamBaselineObservationLogExcel(root, optsBasePC_tilt);

%% ================== Plot method comparison for P01_S61 over latitude-0 GS ==================
optsPlot = struct();
optsPlot.targetSatelliteId = "P01_S61";
optsPlot.baselineExcelPath = optsBase.excelPath;
optsPlot.pcExcelPath = optsBasePC_simple.excelPath;
optsPlot.tiltExcelPath = optsBasePC_tilt.excelPath;
optsPlot.relayExcelPath = optsBasePC_relay.excelPath;
optsPlot.figurePath = char(fullfile(file_path, 'Matlab_data', 'LEO16_Ku_MethodComparison_S61_GS0.png'));
optsPlot.tablePath = char(fullfile(file_path, 'Matlab_data', 'LEO16_Ku_MethodComparison_S61_GS0.xlsx'));
optsPlot.latitudeWindowDeg = 4;
PlotS61MethodComparisonVsLatitude(root, optsPlot);




























%% ================== 目前時間點 beam 對 GS 的 EPFD 貢獻 ==================
optsBeamEpfd = struct();
optsBeamEpfd.satList = satUserTargets;
optsBeamEpfd.geoList = "IdealGSO_GS01";
optsBeamEpfd.useIdealGsoAtGs = true;
optsBeamEpfd.gsName = "GS_01";
optsBeamEpfd.tStr = tEpochStr;
optsBeamEpfd.areaSide_km = 1888;
optsBeamEpfd.params = optsEpfd.params;
optsBeamEpfd.params.useEIRPDensityModel = true; % OneWeb filing EIRP density (see ku_epfd_params.m)
optsBeamEpfd.params.EIRPdens_dBW_per_4kHz = -13.4;
optsBeamEpfd.params.Ptotal_W = 16.8; % used only when useEIRPDensityModel is false
optsBeamEpfd.userDemand_Mbps = 50;
optsBeamEpfd.limitPowerToDemand = true;
optsBeamEpfd.beamHalfEW_deg = 36.5;
optsBeamEpfd.beamHalfNS_deg = 36.0 / 16;
optsBeamEpfd.allocatePowerByUsers = true;
optsBeamEpfd.enforceBeamPowerMax = true;
optsBeamEpfd.maxBeamPower_W = 1.05;
optsBeamEpfd.distressSatellite = "P03_S01";
optsBeamEpfd.distressXi1 = 0.5;
optsBeamEpfd.distressXi2 = 0.5;
optsBeamEpfd.helperEta1 = 0.4;
optsBeamEpfd.helperEta2 = 0.3;
optsBeamEpfd.helperEta3 = 0.3;
optsBeamEpfd.userPrefix = "User_";
optsBeamEpfd.prioritySatellite = "P03_S01";
optsBeamEpfd.priorityCoverageFirst = true;
optsBeamEpfd.priorityBeamRange = 3:14;
% EPFD backoff: target worst-user satisfaction after a step (rate/demand, same as User_State); power is solved by bisection, not P*0.2.
optsBeamEpfd.previousBeamPowerScale = 0.2;
% Only backoff beams whose worst-user satisfaction before the step is at least this (default 0.9 ~= "fully served").
% optsBeamEpfd.epfdBackoffMinInitialUserSat = 0.9;
optsBeamEpfd.excelPath = char(fullfile(file_path, 'Matlab_data', 'Beam_EPFD_GS01_CurrentEpoch.xlsx'));
ComputeBeamEpfdToGsExcel(root, optsBeamEpfd);

satShutdownPlotTargets = ["P03_S01", "P03_S49", "P03_S48"];

optsFullPowerSweep = struct();
optsFullPowerSweep.satList = satUserTargets;
optsFullPowerSweep.geoList = "IdealGSO_GS01";
optsFullPowerSweep.useIdealGsoAtGs = true;
optsFullPowerSweep.gsName = "GS_01";
optsFullPowerSweep.gsLat_deg = 0;
optsFullPowerSweep.gsLon_deg = 120;
optsFullPowerSweep.gsAlt_km = 0;
optsFullPowerSweep.tStartStr = "16 Dec 2025 12:11:13";
optsFullPowerSweep.tEndStr = "16 Dec 2025 12:13:19";
optsFullPowerSweep.stepSec = 2;
optsFullPowerSweep.beamHalfEW_deg = optsBeamEpfd.beamHalfEW_deg;
optsFullPowerSweep.beamHalfNS_deg = optsBeamEpfd.beamHalfNS_deg;
optsFullPowerSweep.fullBeamPower_W = 1.05; % ignored when useEIRPDensityModel is true
optsFullPowerSweep.params = optsEpfd.params;
optsFullPowerSweep.params.useEIRPDensityModel = false;
optsFullPowerSweep.params.EIRPdens_dBW_per_4kHz = -13.4;
optsFullPowerSweep.userDemand_Mbps = optsBeamEpfd.userDemand_Mbps;
optsFullPowerSweep.satisfactionSatList = satShutdownPlotTargets;
optsFullPowerSweep.excelPath = char(fullfile(file_path, 'Matlab_data', 'FullPower_BeamShutdownSweep_GS01.xlsx'));
RunFullPowerAggregateShutdownSweepExcel(root, optsFullPowerSweep);


%% ================== User field 平面圖 ==================

PlotUserFieldPlanarMap(root, satUserTargets, "GS_01", optsBeamEpfd.areaSide_km, tEpochStr, "User_", optsBeamEpfd.excelPath);
PlotUserFieldPlanarMapServedUsers(root, satUserTargets, "GS_01", optsBeamEpfd.areaSide_km, tEpochStr, "User_", optsBeamEpfd.excelPath);

optsShutdownFrames = struct();
optsShutdownFrames.showFigures = false;
optsShutdownFrames.savePng = true;
optsShutdownFrames.skipUnchanged = false;
optsShutdownFrames.useSimulatedGs = true;
% Plot GS (map marker / fixed axes); independent from sweep EPFD GS in optsFullPowerSweep
optsShutdownFrames.plotGsLat_deg = 0;
optsShutdownFrames.plotGsLon_deg = 122;
optsShutdownFrames.fixedAxesOnGs = true;
optsShutdownFrames.showMotionTrail = true;
optsShutdownFrames.snapSatellitesToGroundTrack = true;
optsShutdownFrames.plotEveryTimeSlot = true;
optsShutdownFrames.tStartStr = optsFullPowerSweep.tStartStr;
optsShutdownFrames.tEndStr = optsFullPowerSweep.tEndStr;
optsShutdownFrames.stepSec = optsFullPowerSweep.stepSec;
PlotFullPowerShutdownSweepFrames(root, satShutdownPlotTargets, "GS_01", optsBeamEpfd.areaSide_km, optsFullPowerSweep.excelPath, optsShutdownFrames);








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
