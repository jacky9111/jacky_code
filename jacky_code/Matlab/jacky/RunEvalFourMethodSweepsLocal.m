function RunEvalFourMethodSweepsLocal(root, file_path, evalEnv, evalUserAreaSide_km, ...
    evalCriticalSat, numUsersPerSat, epfdThr_dB, useEpfdThrTagInPaths)
% RunEvalFourMethodSweepsLocal  Four-method Excel sweep at one EPFD threshold.
% useEpfdThrTagInPaths=false -> baseline filenames (fig.1-5); true -> Thr* tag (fig.6).
%
% 【中文說明】在「同一個 EPFD 門檻」下，把論文 Compared Schemes 的四個方法各跑一次，
% 結果各自寫成一份 Excel。這是整個 Evaluation 的資料產生器 —— 圖一～圖五都是讀這裡的輸出。
%
% 四個方法與對應的開關（其餘物理參數完全相同，確保公平比較）：
%   (1) Beam shutdown only  enableRelay=false, enableMiddleHelperSwap=false
%                           → 只把高干擾 beam 關掉，不做任何服務救援
%   (2) PC + Tilt           走另一個 runner（RunKu16BeamBaselineObservationLogExcel）
%                           → 重現 Jalali et al. 的功率控制 + 衛星傾斜
%   (3) Only HBR            enableRelay=true, enableMiddleHelperSwap=false
%                           → 只做 HBR：helper 用「預設功率」接手關閉束的 user
%   (4) EABR（本論文）       enableRelay=true, enableMiddleHelperSwap=true
%                           → HBR + SBR（安全束換手）+ EPFD 受限的功率重配
%
% 輸入：
%   root                    STK COM 根物件（畫圖階段可傳 []）
%   file_path               專案根目錄字串，Excel 會寫到 <file_path>\Matlab_data\
%   evalEnv                 BuildEvalEnvironmentLocal 產生的共用環境
%   evalUserAreaSide_km     user 灑點正方形邊長 [km]
%   evalCriticalSat         critical 衛星 ID（PC+Tilt 的傾斜對象）
%   numUsersPerSat          每星 user 數，決定檔名的 U 標籤
%   epfdThr_dB              本次 sweep 使用的 EPFD 門檻 [dB(W/m^2/40kHz)]
%   useEpfdThrTagInPaths    false → 檔名不加門檻標籤（圖一～五的 baseline）
%                           true  → 檔名加 Thr* 標籤（圖六不同門檻的比較）

evalEnv.params.EPFD_thr_dB = double(epfdThr_dB);   % 門檻寫回共用環境，四個方法一致
pathEpfdThr = [];
if nargin >= 8 && useEpfdThrTagInPaths
    pathEpfdThr = double(epfdThr_dB);
end

if isempty(pathEpfdThr)
    pathTagStr = "(none)";
else
    pathTagStr = char(epfdThrPathTagLocal(pathEpfdThr));
end
fprintf('Sweep four methods: EPFD_thr=%.1f dB, U%d, pathTag=%s\n', ...
    double(epfdThr_dB), round(double(numUsersPerSat)), pathTagStr);

% ---- 三個「關束 + 救援」方法共用的基底設定 ----
optsSweepBase = struct();
optsSweepBase = ApplyEvalEnvironmentToFullPowerSweep(optsSweepBase, evalEnv, evalUserAreaSide_km);
optsSweepBase.enableRelay = true;
optsSweepBase.relayMinNativeSat = 0.9;      % helper 自家 user 滿意度需 >= 0.9 才准借出資源
optsSweepBase.relayMinRelayAvgSat = 0.9;    % 接手後的平均滿意度需 >= 0.9 才算救援成功
optsSweepBase.relayPowerShiftMode = "overlapCapped";  % 功率轉移量以重疊覆蓋比例為上限

% ---- 方法 (1) Beam shutdown only：只關束，不救援 ----
optsBeamShutdown = optsSweepBase;
optsBeamShutdown.enableRelay = false;            % 關掉 HBR
optsBeamShutdown.enableMiddleHelperSwap = false; % 關掉 SBR
optsBeamShutdown.excelPath = char(FullPowerSweepDataPathLocal(file_path, ...
    numUsersPerSat, 'BackoffOnly', '.xlsx', pathEpfdThr));
RunFullPowerAggregateShutdownSweepExcel(root, optsBeamShutdown);

% ---- 方法 (2) PC + Tilt：Jalali et al. 的功率控制 + 衛星傾斜 baseline ----
optsPcTilt = struct();
optsPcTilt = ApplyEvalEnvironmentToKu16(optsPcTilt, evalEnv, evalUserAreaSide_km);
optsPcTilt.excelPath = char(ku16PcTiltExcelPathLocal(file_path, numUsersPerSat, pathEpfdThr));
optsPcTilt.useGsoNoiseInQualityMetric = true;
optsPcTilt.enablePowerControl = true;        % 開啟功率控制（PC）
optsPcTilt.enablePowerRedistribution = false;% 不做本論文的功率重配
optsPcTilt.enableBidirectionalRelay = false; % 不做 beam reassociation
optsPcTilt.enableBaselineTilt = true;        % 開啟衛星傾斜（Tilt）
optsPcTilt.baselineTiltSatelliteId = evalCriticalSat;  % 對 critical 衛星做傾斜
optsPcTilt.baselineTiltMaxDeg = 10;          % 最大傾斜角 10 deg（論文 Table 參數）
optsPcTilt.baselineTiltStepDeg = 0.5;        % 傾斜角搜尋步長；overhead 量測另用較粗步長
RunKu16BeamBaselineObservationLogExcel(root, optsPcTilt);
fprintf('Saved PC+Tilt log: %s\n', optsPcTilt.excelPath);

% ---- 方法 (3) Only HBR：helper 以預設功率接手關閉束的 user ----
optsRelayOnly = optsSweepBase;
optsRelayOnly.enableMiddleHelperSwap = false;    % 不做 SBR → helper 無法額外釋放功率
optsRelayOnly.excelPath = char(FullPowerSweepDataPathLocal(file_path, ...
    numUsersPerSat, 'RelayOnly', '.xlsx', pathEpfdThr));
RunFullPowerAggregateShutdownSweepExcel(root, optsRelayOnly);

% ---- 方法 (4) EABR（本論文）：SBR + EPFD 受限功率配置 + HBR ----
optsSaprR = optsSweepBase;
optsSaprR.enableMiddleHelperSwap = true;         % 開啟 SBR，把 helper 的自家 user 換到安全束
optsSaprR.excelPath = char(FullPowerSweepDataPathLocal(file_path, ...
    numUsersPerSat, 'RelayWithMiddleSwap', '.xlsx', pathEpfdThr));
RunFullPowerAggregateShutdownSweepExcel(root, optsSaprR);
end
