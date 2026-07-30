%% 重置 Command window 與 Workspace
clear;
clc;

%% ================== Paper implementation (Sensors 2022, 22, 6302) ==================
% This section reproduces the "Optimal Progressive Pitch for OneWeb Constellation with
% Seamless Coverage" model and GA solver from the provided PDF.
%
% - Set runMode="paper" to run the paper/GA demo (no STK required).
% - Set runMode="stk" to run your original STK scenario/TLE workflow below.
runMode = "paper";  % "paper" | "stk"

if runMode == "paper"
    addpath(fullfile(pwd, 'Matlab', 'pitch2', 'api'));

    P = pp_params_oneweb_sensors2022();

    % Speed knobs:
    % - P.eval_n_x controls Eq.(15) integral sampling (bigger => slower).
    % - GA in the paper uses generations=200, pop_size=100, but it can take a long time.
    %   If you want a quick run, try e.g.:
    %     P.GA.generations = 60; P.GA.pop_size = 40; P.eval_n_x = 7;

    best = pp_ga_optimize_progressive_pitch(P, struct('rng_seed', 1, 'verbose', true, 'verbose_every', 5));
    pp_plot_progressive_pitch_results(P, best);
    return;
end

%% 與STK連線
disp("連接STK");
con = actxGetRunningServer('STK12.application');
root = con.Personality2;
con.Visible = 1;
disp("---------------------- done");

%% 初始化
addpath(fullfile(pwd, 'Matlab', 'pitch2', 'api'));
addpath(fullfile(pwd, 'Matlab', 'Method'));
addpath(fullfile(pwd, 'Matlab'));
global OneWeb_leo OneWeb_geo  OneWeb_OMNet_leo OneWeb_OMNet_geo beam_config geoLongitudes OneWeb_OMNet_leo_part OneWeb_OMNet_geo_part;
disp("初始化");
Satellite_Name();
file_path = "C:\Users\jacky\Desktop\jacky_code\";
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
convert_tlm('C:\Users\jacky\Desktop\jacky_code\oneweb_tle\20251125_211107');

%GEO
convert_tlm('C:\Users\jacky\Desktop\jacky_code\geo_tle\20251125_212200');

%% Read LEO TLE Content 

disp("read TLEs");

% 開啟檔案
%LEO
filename = fullfile('C:\Users\jacky\Desktop\jacky_code\oneweb_tle\20251125_211107', '_oneweb.tle');
fid = fopen(filename, 'r');
if fid == -1
    error('❌ 無法開啟 TLE 檔案，請確認路徑是否正確');
end

% 讀取所有行
tle_lines = textscan(fid, '%s', 'Delimiter', '\n');
fclose(fid);
tle_lines = tle_lines{1};

% 呼叫 function 處理 TLE
tle_data_leo = parseTLE(tle_lines);
disp("---------------------- done");

%GEO
filename = fullfile('C:\Users\jacky\Desktop\jacky_code\geo_tle\20251125_212200', '_geo.tle');
fid = fopen(filename, 'r');
if fid == -1
    error('❌ 無法開啟 TLE 檔案，請確認路徑是否正確');
end

% 讀取所有行
tle_lines = textscan(fid, '%s', 'Delimiter', '\n');
fclose(fid);
tle_lines = tle_lines{1};

% 呼叫 function 處理 TLE
tle_data_geo = parseTLEgeo(tle_lines);
disp("---------------------- done");

%% Add satellite in STK through TLE file
%LEO 
addSatellitesFromTLE(root, sc, tle_data_leo, OneWeb_leo, OneWeb_OMNet_leo);
%GEO
addSatellitesFromTLE(root, sc, tle_data_geo, OneWeb_geo, OneWeb_OMNet_geo);


%% ================== 建立地面戰 ================== 
geo = [
    "geo_4_1"
    "geo_4_4"
    "geo_12"
    "geo_17"
];
latGS = 0;
GeoGroundStations(root, OneWeb_OMNet_geo, geoLongitudes, latGS);














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
root.LoadScenario('C:\Users\jacky\Desktop\jacky_code\STK\Scenario.sc');
sc = root.CurrentScenario;
disp("---------------------- done");