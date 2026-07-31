function evalEnv = BuildEvalEnvironmentLocal(evalCriticalSat, evalTStartStr, evalTEndStr, evalStepSec, ...
    evalBeamHalfEW_deg, evalBeamHalfNS_deg, evalGsLat_deg, evalGsLon_deg, ...
    evalUsersPerSat, evalUserDemand_Mbps, evalFullBeamPower_W, evalMaxBeamPower_W, ...
    evalRecordSats, leo_part, satUserTargets, ku_epfd_params_fn)
% BuildEvalEnvironmentLocal  Single source for full-power sweep vs Ku16 paper-model runs.
% Physics / time / GS / user field are shared; control policy differs per runner.
%
% 【中文說明】建立「共用評估環境」evalEnv —— 四個比較方法的唯一參數來源。
%   Beam shutdown only / PC+Tilt / Only HBR / EABR 這四條曲線之所以能公平比較，
%   就是因為它們的物理模型、時間窗、地面站、user 分佈全部由這個 struct 統一供給，
%   只有「干擾抑制的控制策略」不同。改這裡 → 四條曲線一起變。
%
% 輸入（對應論文 Table「Simulation parameters」）：
%   evalCriticalSat      critical 衛星 ID，例 "P03_S49"（會飛過 GS 正上方那顆）
%   evalTStartStr/EndStr STK 場景時間窗字串，例 "16 Dec 2025 12:11:00"
%   evalStepSec          time slot 長度 [s]，論文用 1 s
%   evalBeamHalfEW_deg   beam 東西向半角 [deg]，34.0（對齊 RectBeam -5 dB）
%   evalBeamHalfNS_deg   單一 beam 南北向半角 [deg]，33.5/16（16 束均分）
%   evalGsLat/Lon_deg    GSO 地面站經緯度 [deg]
%   evalUsersPerSat      每顆衛星的 user 數（論文的 U30 / U50 / U70）
%   evalUserDemand_Mbps  每個 user 的需求速率，論文用 50 Mbps
%   evalFullBeamPower_W  單一 beam 全開功率 [W]，1.05（×16 束 = 16.8 W/衛星）
%   evalMaxBeamPower_W   helper recovery beam 的功率上限 [W]
%   evalRecordSats       要寫進 Excel 明細的衛星（滿意度 / Per* 只記這幾顆）
%   leo_part             參與 EPFD 累加的 LEO 清單
%   satUserTargets       要在其覆蓋範圍內灑 user 的衛星清單
%   ku_epfd_params_fn    EPFD 工程參數函式 handle，通常傳 @ku_epfd_params
%
% 輸出：evalEnv struct，之後由 ApplyEvalEnvironmentToFullPowerSweep（EABR 系列）
%       與 ApplyEvalEnvironmentToKu16（PC+Tilt）各自翻譯成 runner 需要的 opts。

evalEnv = struct();

% ---- 幾何與時間：決定「哪顆星、看多久、多久取樣一次」----
evalEnv.criticalSat = string(evalCriticalSat);      % critical 衛星（EPFD 超標時要關束的那顆）
evalEnv.recordSats = string(evalRecordSats(:));     % 只有這幾顆會寫進 Excel 明細，控制檔案大小
evalEnv.tStartStr = evalTStartStr;
evalEnv.tEndStr = evalTEndStr;
evalEnv.stepSec = evalStepSec;                      % 1 s = 論文的 time slot 長度

% ---- 16-beam 佈局：衛星固定座標下的矩形 beam 半角 ----
evalEnv.beamHalfEW_deg = evalBeamHalfEW_deg;        % 東西向半角（16 束共用）
evalEnv.beamHalfNS_deg = evalBeamHalfNS_deg;        % 單束南北向半角 = 總半角/16

% ---- GSO 受擾端：地面站 + 正上方的理想 GSO ----
evalEnv.gsLat_deg = evalGsLat_deg;
evalEnv.gsLon_deg = evalGsLon_deg;
evalEnv.gsName = "GS_01";                           % STK 裡的地面站物件名稱
evalEnv.geoList = "IdealGSO_GS01";                  % 受擾 GSO 名稱（虛擬）
evalEnv.useIdealGsoAtGs = true;                     % true：GSO 星下點 = GS 經緯度（最壞 in-line 情況）

% ---- User 場：負載大小與需求 ----
evalEnv.numUsersPerSat = evalUsersPerSat;           % 每顆衛星的 user 數 → 論文的 U30/U50/U70
evalEnv.userDemand_Mbps = evalUserDemand_Mbps;      % 單一 user 需求速率，滿意度分母
evalEnv.fullBeamPower_W = evalFullBeamPower_W;      % beam 全開功率
evalEnv.maxBeamPower_W = evalMaxBeamPower_W;        % helper recovery beam 加功率的上限
evalEnv.userPrefix = "User_";
evalEnv.leoList = string(leo_part(:));              % 參與 aggregate EPFD 累加的 LEO
evalEnv.satList = string(satUserTargets(:));
evalEnv.userPlacementSatList = evalEnv.leoList;     % 在這些衛星底下灑 user
evalEnv.useSimulatedUsers = true;                   % true：MATLAB 自行生成 user（不從 STK 讀）
evalEnv.reassignUsersEachSlot = true;               % 每個 slot 重新做 beam-user 關聯

% ---- EPFD 工程參數（頻率 / 門檻 / 天線增益等，見 ku_epfd_params.m）----
evalEnv.params = ku_epfd_params_fn();
evalEnv.params.useEIRPDensityModel = false;         % false：用「每束明確功率」模型，而非 EIRP 密度模型
evalEnv.params.EIRPdens_dBW_per_4kHz = -13.4;       % 保留 OneWeb filing 口徑（此處未啟用）
evalEnv.params.Ptotal_W = evalFullBeamPower_W * 16; % 每顆衛星總功率 = 單束功率 × 16 束
end
