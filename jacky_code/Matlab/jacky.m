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
addpath(fullfile(pwd, 'Matlab', 'jacky'));
disp("初始化");
% Satellite_Name() 主要用於 OneWeb/TLE 命名對應，Walker 建星本身不依賴它。
% Satellite_Name();
file_path = "C:\Users\jacky\Desktop\jacky_code\";
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
inc_deg = 55;
% Walker 內建 p=2..numPlanes；要含 P17/P18 軌道面請設 numPlanes >= 18
numPlanes = 8;
beamProfile = "-3dB"; % "-3dB" or "-5dB"
% Only one variable to control satellites per plane.
satsPerPlane = 16;

satPrefix = "WalkerStar";

switch lower(strrep(beamProfile, " ", ""))
    case {"-5db","5db","minus5db"}
        beamHalfH_deg = 36.5;
        beamHalfV_deg = 36.0;
    otherwise
        beamHalfH_deg = 25.0;
        beamHalfV_deg = 24.5;
end
% If scenario already exists, prefer using its StartTime as epoch (more consistent).
tEpochStr = datestr(datetime('now','TimeZone','UTC'), 'dd mmm yyyy HH:MM:SS');
try
    tEpochStr = char(sc.StartTime);
catch
end
leo = CreateWalkerConstellation_HPOP( ...
    root, sc, alt_km, inc_deg, numPlanes, satsPerPlane, tEpochStr);


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
rectBeamPlanes = [1,2,3];
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
AddGroundStationToSTK(root, "GS_01", 0, 59);

%% ================== 建立user（範例）==================
satUserTargets = [
    "P01_S01"
    "P01_S02"
    % "P01_S03" 
    % "P01_S48"
    "P01_S49"
    "P02_S01"
    "P02_S02"
    % "P02_S03"
    % "P02_S48"
    "P02_S49"
    "P03_S01"
    "P03_S02"
    % "P03_S03"
    % "P03_S48"
    "P03_S49"
];
AddUsersAroundSatellitesToSTK(root, satUserTargets, 1888, 20);

%% ================== 判斷seamless coverage ================== 
RunStrictRelayCheck_FromLeoPart(root, leo, tEpochStr, beamHalfH_deg, beamHalfV_deg, beamProfile);

%% ================== Ku EPFD：16 束（純 MATLAB）+ 每秒 Excel ==================
% STK 端只保留上面單一 RectBeam（快速看 seamless / relay）；不在 STK 建 16 個 sensor。
% 下列僅從 STK 讀 LEO / GEO / GSO 地面站位置與速度，16 束北→南在 MATLAB 內模擬（RunEpfd16BeamsKuLogExcel）。
% 地面站命名：*/Facility/GSO_GS_<GEO衛星名>（與 SystemWide16 一致）
leo_part = [
    "P01_S01"
    "P01_S02"
    % "P01_S03"
    % "P01_S48"
    "P01_S49"
    "P02_S01"
    "P02_S02"
    % "P02_S03"
    % "P02_S48"
    "P02_S49"
    "P03_S01"
    "P03_S02"
    % "P03_S03"
    % "P03_S48"
    "P03_S49"
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
optsBeamEpfd.params.useEIRPDensityModel = false; % use total power model, then split by user load
optsBeamEpfd.params.Ptotal_W = 16.8; % total transmit power per satellite, W
optsBeamEpfd.userDemand_Mbps = 50;
optsBeamEpfd.limitPowerToDemand = true;
optsBeamEpfd.beamHalfEW_deg = 36.5;
optsBeamEpfd.beamHalfNS_deg = 36.0 / 16;
optsBeamEpfd.allocatePowerByUsers = true;
optsBeamEpfd.userPrefix = "User_";
optsBeamEpfd.prioritySatellite = "P02_S01";
optsBeamEpfd.priorityCoverageFirst = true;
optsBeamEpfd.previousBeamPowerScale = 0.2;
optsBeamEpfd.excelPath = char(fullfile(file_path, 'Matlab_data', 'Beam_EPFD_GS01_CurrentEpoch.xlsx'));
ComputeBeamEpfdToGsExcel(root, optsBeamEpfd);


%% ================== User field 平面圖 ==================
PlotUserFieldPlanarMap(root, satUserTargets, "GS_01", optsBeamEpfd.areaSide_km, tEpochStr, "User_", optsBeamEpfd.excelPath);



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
