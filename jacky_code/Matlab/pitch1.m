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
addpath(fullfile(pwd, 'Matlab', 'Method'));
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

% % 以 UTC 建情境時間窗（現在起算 24h）
% tStartUtc = datestr(datetime('now','TimeZone','UTC'), 'dd mmm yyyy HH:MM:SS');
% tStopUtc  = datestr(datetime('now','TimeZone','UTC') + days(1), 'dd mmm yyyy HH:MM:SS');

tStartUtc = "16 Dec 2025 12:10:03"
tStopUtc  = "16 Dec 2025 13:10:03"

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

%% ================== 使用公式算 LEO 的 beam 半長軸 ================== 
% 依論文：每顆 OneWeb LEO 具備 16 條南北向排列的 user beams
% 本版本「不在 STK 建 beam sensors」，只用 MATLAB 模擬 16 beams 的覆蓋/干擾與 ON/OFF。

%% ================== 建立地面戰 ================== 
geo = [
    "geo_4_1"
    "geo_4_4"
    "geo_12"
    "geo_17"
];
latGS = 0;
GeoGroundStations(root, OneWeb_OMNet_geo, geoLongitudes, latGS);

%% ================== Progressive pitch + Beam OFF（論文：Ren 2021, sat.1399） ==================
% STK 只用來讀位置與時間同步；beam 本身完全在 MATLAB 端算。
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

stepSec = 1;
leo_demo = leo_part;
geo_demo = geo_part;
opts = struct();
opts.tStartStr = "16 Dec 2025 12:10:03";
opts.tEndStr = "16 Dec 2025 12:13:53";
opts.saveExcel = true;
opts.excelPath = 'C:\Users\jacky\Desktop\jacky_code\jacky_code\Matlab_data\OneWeb16Beam_MatlabSim.xlsx';
% 依你的策略：EPFD 超標就關 beam（beam 本身仍用論文 coverage gate 來判斷 GS 是否落在該 beam 覆蓋內）
opts.metric = "epfd";
% 放寬門檻（讓 beam 不那麼容易被關）：把 EPFD limit 調高（較不負）
% 原本 ITU 常用值是 -173.4 dB(W/m^2/1MHz)；這裡先放寬到 -150 dB 方便觀察服務率曲線。
opts.epfd_thr_dB = -140.0;           % dB(W/m^2/1MHz)（可自行調回 -173.4 做嚴格 baseline）
opts.BWref_Hz = 1e6;
opts.leo_psd_dBW_per_4kHz = -13.4;   % OneWeb Table 2
opts.gs_diameter_m = 0.6;            % GSO ES Table 1
opts.freq_GHz = 12.7;                % GSO downlink Table 1
opts.rx_pattern = "rec465";          % 用 REC-465 的近似模型；也可改 "itu1428"
T_beam = SimOneWeb16Beams_ProgressivePitch(root, leo_demo, geo_demo, stepSec, opts);

%% ================== Baseline：加入 users + 畫 Figure14-like（progressive pitch） ==================
% 你要的 baseline：不要讀 Excel / 不要用 T_beam 後處理，而是像 Plot_Figure14_LEO_Passing 一樣
% 逐時間片跑 STK、即時計算 beam ON/OFF（pitch1 策略），再統計使用者滿足率並畫圖。
target_sat = "ow1_30";
geoName = geo_part(1);
optsFig = struct();
optsFig.user_lat_deg = zeros(5,1);  % 5 users around equator (deg)
optsFig.beamOrder = "northToSouth";
optsFig.epfd_thr_dB = opts.epfd_thr_dB;
optsFig.BWref_Hz = opts.BWref_Hz;
optsFig.leo_psd_dBW_per_4kHz = opts.leo_psd_dBW_per_4kHz;
optsFig.gs_diameter_m = opts.gs_diameter_m;
optsFig.freq_GHz = opts.freq_GHz;
optsFig.rx_pattern = opts.rx_pattern;

Plot_Figure14_ProgressivePitch_Pitch1Strategy(root, geoName, target_sat, ...
    char(opts.tStartStr), char(opts.tEndStr), 1, optsFig);




% %% ================== GSO 保護排除角 16 Beam (計算EPFD) ================== 
% leo_1 = [
%     "ow1_3"
%     % "ow1_30"
%     % "ow1_38"
%     % "ow1_43"
%     % "ow1_29"
%     % "ow1_20"
% ];
% leo_18 = [
%     "ow18_33"
%     "ow18_16"
%     "ow18_26"
%     "ow18_3"
%     "ow18_53"
%     "ow18_50"
% ];
% leo_19 = [
%     "ow19_18"
%     "ow19_45" 
%     "ow19_29" 
%     "ow19_42" 
%     "ow19_31" 
%     "ow19_4" 
% ];
% Satellite_Name();
% stepSec = 10;   
% SystemWide16_GSO_EPFD_Control(root, leo_1, OneWeb_OMNet_geo_part, stepSec)

% leo_1_1220 = [
%     "ow1_41"
%     "ow1_25"
% ];

% SystemWide16_GSO_EPFD_Control_LogExcel( ...
%     root, leo_1, OneWeb_OMNet_geo_part, stepSec, ...
%     '16 Dec 2025 12:14:33');


% deltaH = 20;   % +20 km
% Raise_LEO_Altitude(root, OneWeb_OMNet_leo_part, deltaH);


% changeSTKSensorColor(root, "ow18_26", [255 255 255]);















%% Save STK scenario
disp("save");
root.Save;
disp("---------------------- done");

%% STK 場景另存新檔 (M)
disp("Save as");
sub_file_path = file_path + "STK\"; % modify
if ~exist(sub_file_path,'dir')
    mkdir(sub_file_path);
end
root.SaveAs(file_path + 'STK\Scenario'); % modify
disp("---------------------- done");

%% STL 關閉後用載入的方式開啟
disp("載入舊場景");
root.LoadScenario('C:\Users\jacky\Desktop\jacky_code\jacky_code\STK\Scenario.sc');
sc = root.CurrentScenario;
disp("---------------------- done");