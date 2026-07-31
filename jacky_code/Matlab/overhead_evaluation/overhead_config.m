function cfg = overhead_config()
%OVERHEAD_CONFIG Pure-MATLAB configuration for the online-runtime experiment.
% No STK is required. Geometry follows the OneWeb-like Walker used by
% helper_availability, with a local 25-satellite neighborhood around the GS.
%
% Timing methodology:
%   1) Search aggregate EPFD over a wide flyover window and pick t_worst.
%   2) Measure online runtime once per 1-s slot in [t_worst-30, t_worst+29]
%      (60 slots total). Bar = mean over slots; I = min–max over slots.
%
% 【中文說明】overhead 量測的唯一參數來源，要調什麼都改這一支。
% jacky.m 的 overhead 區段會先呼叫本函式取得預設值，再覆寫其中幾個欄位。
%
% 常改的參數：
%   userLoads              量哪幾種 user 負載，論文用 [30, 50, 70]
%   slotHalfWindow_s       t_worst 前後各幾秒（30 → 共 60 個 slot）
%   pcTiltSearchMode       PC+Tilt 線上 tilt 搜尋策略，直接決定它的執行時間
%   epfdThreshold_dB       EPFD 門檻，會影響關束數量進而影響救援計算量
%   nLocalSats             取 GS 附近幾顆衛星做局部鄰域
%   runtimeRangePercentiles 圖上 I 形線用的百分位（預設 p10–p90，
%                          避免單一異常 slot 把誤差線拉爆）

moduleDir = fileparts(mfilename('fullpath'));
matlabDir = fileparts(moduleDir);

cfg.moduleDir = moduleDir;
cfg.matlabDir = matlabDir;
cfg.resultsDir = fullfile(moduleDir, 'results');
cfg.userLoads = [30, 50, 70];  % 要量測的 user 負載（= 論文的 U30/U50/U70）
cfg.warmupRuns = 2;          % warm-up on first slot only (discarded)
                             % 先空跑 2 次讓 MATLAB JIT 暖機，這些數據不列入統計
cfg.randomSeed = 2026;       % 固定亂數種子 → user 位置與策略可重現

% 是否一併量測 Only HBR baseline（論文 Only HBR vs EABR 那張 overhead 圖）。
% true  → 每個負載多跑一輪 Only HBR，額外產生
%         runtime_overhead_only_hbr_vs_eabr.{png,fig,pdf}
% false → 只量 PC+Tilt 與 EABR，總時間約少三分之一
cfg.measureOnlyHbr = true;

% Worst-EPFD search around the aligned overhead (t = 0).
% 第一階段：在這個寬窗內掃描 aggregate EPFD，找出最壞時刻 t_worst
cfg.epfdSearchStart_s = -120;
cfg.epfdSearchEnd_s = 120;
cfg.epfdSearchStep_s = 1;

% Measurement window relative to t_worst: 30 s before + 30 s after = 60 slots.
% 第二階段：只在 t_worst 前後各 30 s（共 60 個 1 秒 slot）量測執行時間
cfg.slotHalfWindow_s = 30;
cfg.slotStep_s = 1;
% I-bar on the figure uses these percentiles (not raw min/max), so a single
% pathological slot cannot dominate the whisker.
cfg.runtimeRangePercentiles = [10, 90];

% Local evaluation geometry (MATLAB-only Walker, aligned over GS at t = 0).
cfg.gsLat_deg = 0;
cfg.gsLon_deg = 120.4;
cfg.alt_km = 1200;
cfg.inclination_deg = 87.9;
cfg.nPlanes = 12;
cfg.nSatPerPlane = 49;
cfg.walkerType = 'star';
cfg.walkerPhasingF = 1;
cfg.refPlaneIndex = 3;
cfg.refSatIndex = 25;
cfg.nLocalSats = 25;   % same local neighborhood size as jacky.m satUserTargets

cfg.beamHalfEW_deg = 34.0;
cfg.beamHalfNS_deg = 33.5 / 16;
cfg.userAreaSide_km = max(2 * cfg.alt_km * tand(cfg.beamHalfEW_deg), ...
    2 * cfg.alt_km * tand(33.5));
cfg.userDemand_Mbps = 50;
cfg.fullBeamPower_W = 1.05;
cfg.maxBeamPower_W = 2.0;
cfg.epfdThreshold_dB = -173.4;
cfg.pcTiltMax_deg = 10;
% Tilt search for overhead timing (service sim may keep 0.5 deg in RunKu16).
% Jalali et al. specify max tilt but not online grid step; coarser step is
% used here for feasible 1-s-slot runtime measurement of the reproduced logic.
cfg.pcTiltStep_deg = 2.0;          % exhaustive mode: candidates per slot ~ 2*max/step + 1
% 'max_only' | 'coarse_to_fine' | 'exhaustive'
% max_only: if PC adjusted power, try only ±tiltMax (fastest overhead timing).
% 【PC+Tilt 線上傾斜角搜尋策略】—— 這個選擇直接決定 PC+Tilt 的執行時間，
% 是這張 overhead 圖最敏感的參數：
%   'max_only'       功率有調整時只試 ±tiltMax，每 slot 最多 2 個候選（最快）
%   'coarse_to_fine' 先粗搜再在最佳點附近細搜
%   'exhaustive'     ±tiltMax 固定步長全掃（最慢，候選數 ≈ 2*max/step + 1）
% 論文用 'max_only'，等於是給 PC+Tilt 最有利（最快）的設定下去比較。
cfg.pcTiltSearchMode = 'max_only';
cfg.pcTiltCoarseStep_deg = 2.0;    % coarse-to-fine: first pass
cfg.pcTiltFineStep_deg = 0.5;      % coarse-to-fine: local refine
cfg.pcTiltFineHalfWidth_deg = 2.0; % refine in [best ± this]
cfg.nBeam = 16;
cfg.recoveryPowerPoolMode = "per_sat";

cfg.Re_km = 6378.137;
cfg.mu_km3_s2 = 3.986004418e5;
cfg.we_rad_s = 7.2921159e-5;
cfg.Rgeo_km = 42164.0;

cfg.summaryCsvPath = fullfile(cfg.resultsDir, 'overhead_runtime_summary.csv');
cfg.rawMatPath = fullfile(cfg.resultsDir, 'overhead_runtime_raw.mat');

% --- 圖一：PC + Tilt vs EABR ---
cfg.figureBasePath = fullfile(cfg.resultsDir, 'runtime_overhead_pc_tilt_vs_eabr');
% Thesis-ready export: jacky_code/Matlab_data (sibling of Matlab/).
cfg.matlabDataDir = fullfile(fileparts(matlabDir), 'Matlab_data');
cfg.matlabDataFigureBase = fullfile(cfg.matlabDataDir, 'runtime_overhead_pc_tilt_vs_eabr');
cfg.figureExportPaths = {cfg.matlabDataFigureBase, cfg.figureBasePath};

% --- 圖二：Only HBR vs EABR（cfg.measureOnlyHbr = true 時才產生）---
% 檔名沿用論文既有的 runtime_overhead_only_hbr_vs_eabr，
% 放進論文時對應 figures/ch5_overhead_only_hbr_vs_eabr。
cfg.onlyHbrFigureBasePath = fullfile(cfg.resultsDir, 'runtime_overhead_only_hbr_vs_eabr');
cfg.matlabDataOnlyHbrFigureBase = fullfile(cfg.matlabDataDir, 'runtime_overhead_only_hbr_vs_eabr');
cfg.onlyHbrFigureExportPaths = {cfg.matlabDataOnlyHbrFigureBase, cfg.onlyHbrFigureBasePath};
end
