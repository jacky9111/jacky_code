function out = main_overhead_evaluation(cfg)
%MAIN_OVERHEAD_EVALUATION Compare Only-HBR, PC+Tilt and EABR online execution time.
% Pure MATLAB (no STK). For each user load:
%   - find worst GS EPFD time near the flyover
%   - measure online runtime once per 1-s slot in a 60-s window (±30 s)
%   - bar = mean over slots; I = percentile range over slots
%
% Usage:
%   overheadResults = main_overhead_evaluation();
%
% =====================================================================
% 【中文說明】論文 Evaluation 第五項：「On-Orbit Computational Overhead」
%   → 一次產生論文的兩張 overhead 圖：
%     (1) runtime_overhead_pc_tilt_vs_eabr
%         「Per-slot execution time of EABR and the reproduced PC + Tilt」
%     (2) runtime_overhead_only_hbr_vs_eabr（= 論文 ch5_overhead_only_hbr_vs_eabr）
%         「Per-slot execution time of Only HBR and EABR」
%         由 cfg.measureOnlyHbr 控制是否量測（預設 true）
%
% 純 MATLAB、不需要 STK。幾何用與 helper_availability 相同的 OneWeb-like Walker，
% 只取 GS 附近 25 顆衛星的局部鄰域（與 jacky.m 的 satUserTargets 規模一致）。
%
% 量測方法（對應論文內文的說明）：
%   1. 在寬時間窗（±120 s）掃描 aggregate EPFD，找出最壞的時刻 t_worst
%   2. 在 [t_worst-30, t_worst+30) 這 60 個 1 秒 slot，每個 slot 各量一次線上執行時間
%   3. 長條 = 60 個 slot 的平均；黑色 I 形線 = 執行時間範圍
%   4. 三種 user 負載（30 / 50 / 70）各做一次
%
% 為什麼要取 t_worst 附近？因為各 slot 的關閉束數量不同，
% 這個區間剛好涵蓋「從無救援需求到最大救援需求」的完整範圍。
%
% 論文的判準是「平均執行時間必須小於 1 s 的 time slot 長度」，
% 所以下面有 maximumRuntimeMs > 1000 的檢查與警告。
%
% 【三個方法共用同一組場景】每個負載只呼叫一次 prepare_overhead_case，
% 產生的 slot 場景同時餵給 Only HBR / PC+Tilt / EABR ——
% 幾何、user 分佈、關閉束都相同，量到的時間差才純粹來自演算法本身。
% =====================================================================

if nargin < 1 || isempty(cfg)
    cfg = overhead_config();
end
if ~exist(cfg.resultsDir, 'dir')
    mkdir(cfg.resultsDir);
end
addpath(cfg.moduleDir);
addpath(fullfile(cfg.matlabDir, 'jacky'));
addpath(fullfile(cfg.matlabDir, 'powertilt'));
addpath(fullfile(cfg.matlabDir, 'helper_availability'));

if exist('runGraphSelectionPolicyLocal', 'file') ~= 2
    error('main_overhead_evaluation:MissingEABR', ...
        'Existing EABR function runGraphSelectionPolicyLocal.m was not found.');
end
if exist('run_pc_tilt_online_existing_logic', 'file') ~= 2
    error('main_overhead_evaluation:MissingPcTilt', ...
        'PC+Tilt function run_pc_tilt_online_existing_logic.m was not found.');
end

% 是否一併量測 Only HBR baseline（預設開啟；舊的 cfg 沒這欄位時也視為開啟）
measureOnlyHbr = true;
if isfield(cfg, 'measureOnlyHbr') && ~isempty(cfg.measureOnlyHbr)
    measureOnlyHbr = logical(cfg.measureOnlyHbr);
end
if measureOnlyHbr && exist('measure_only_hbr_runtime', 'file') ~= 2
    error('main_overhead_evaluation:MissingOnlyHbr', ...
        'measure_only_hbr_runtime.m was not found; set cfg.measureOnlyHbr = false to skip.');
end

nLoad = numel(cfg.userLoads);
pcTiltMeasurements = repmat(emptyMeasurementLocal(), nLoad, 1);
eabrMeasurements = repmat(emptyMeasurementLocal(), nLoad, 1);
onlyHbrMeasurements = repmat(emptyMeasurementLocal(), nLoad, 1);
caseMetadata = repmat(struct(), nLoad, 1);
nExpectedSlots = numel((-cfg.slotHalfWindow_s):cfg.slotStep_s:(cfg.slotHalfWindow_s - cfg.slotStep_s));

if measureOnlyHbr
    methodListStr = 'Only HBR, PC+Tilt, EABR';
else
    methodListStr = 'PC+Tilt, EABR';
end
fprintf('\n===== Computational overhead: %s (MATLAB-only) =====\n', methodListStr);
fprintf('Window = ±%d s around worst GS EPFD (%d x %d-s slots)\n', ...
    cfg.slotHalfWindow_s, nExpectedSlots, cfg.slotStep_s);
fprintf('Warm-up on first slot only = %d\n', cfg.warmupRuns);
fprintf('Geometry: OneWeb-like Walker, local %d sats around GS=(%.1f, %.1f)\n', ...
    cfg.nLocalSats, cfg.gsLat_deg, cfg.gsLon_deg);

% 三種 user 負載各量一輪（論文的 30 / 50 / 70）
for iLoad = 1:nLoad
    userLoad = cfg.userLoads(iLoad);
    fprintf('\nPreparing worst-EPFD flyover window for user load %d...\n', userLoad);
    % 找出 t_worst 並準備該區間每個 slot 的場景快照（兩個方法用同一組幾何與 user）
    caseData = prepare_overhead_case(cfg, userLoad);
    nSlot = numel(caseData.eabrScenarios);
    fprintf('  Measuring %d slots (t_worst=%d s, window [%d,%d] s)...\n', ...
        nSlot, caseData.tWorst_s, caseData.tSlots_s(1), caseData.tSlots_s(end));

    % 逐 slot 計時：各方法分開量，避免互相干擾快取
    fprintf('Measuring PC+Tilt (reproduced) over slots...\n');
    pcTiltMeasurements(iLoad) = measure_pc_tilt_runtime(caseData.pcTiltScenarios, cfg);
    fprintf('Measuring EABR over slots...\n');
    eabrMeasurements(iLoad) = measure_eabr_runtime(caseData.eabrScenarios, cfg);
    if measureOnlyHbr
        % 重用 EABR 的同一組場景，只在內部標上 onlyHbrWithInitialPower
        fprintf('Measuring Only HBR over slots...\n');
        onlyHbrMeasurements(iLoad) = measure_only_hbr_runtime(caseData.eabrScenarios, cfg);
    end

    caseMetadata(iLoad).userLoad = userLoad;
    caseMetadata(iLoad).actualUserCount = caseData.eabrScenarios{1}.nUsers;
    caseMetadata(iLoad).criticalSlot = caseData.criticalSlot;
    caseMetadata(iLoad).criticalSatellite = caseData.criticalSatellite;
    caseMetadata(iLoad).tWorst_s = caseData.tWorst_s;
    caseMetadata(iLoad).tSlots_s = caseData.tSlots_s;
    caseMetadata(iLoad).tRel_s = caseData.tRel_s;
    caseMetadata(iLoad).slotMeta = caseData.slotMeta;
    caseMetadata(iLoad).epfdSearch = caseData.epfdSearch;
    caseMetadata(iLoad).nSlots = nSlot;
    caseMetadata(iLoad).closedBeamAffectedUsers = ...
        arrayfun(@(m) m.nClosedUsers, caseData.slotMeta);
    caseMetadata(iLoad).sbrCandidateEdges = ...
        arrayfun(@(m) m.nSbrEdges, caseData.slotMeta);
    caseMetadata(iLoad).hbrCandidateEdges = ...
        arrayfun(@(m) m.nHbrEdges, caseData.slotMeta);

    fprintf(['  PC+Tilt min/avg/max = %.3f / %.3f / %.3f ms; ' ...
        'EABR min/avg/max = %.3f / %.3f / %.3f ms  (over %d slots)\n'], ...
        pcTiltMeasurements(iLoad).minimumRuntimeMs, ...
        pcTiltMeasurements(iLoad).averageRuntimeMs, ...
        pcTiltMeasurements(iLoad).maximumRuntimeMs, ...
        eabrMeasurements(iLoad).minimumRuntimeMs, ...
        eabrMeasurements(iLoad).averageRuntimeMs, ...
        eabrMeasurements(iLoad).maximumRuntimeMs, ...
        nSlot);
    if measureOnlyHbr
        fprintf('  Only HBR min/avg/max = %.3f / %.3f / %.3f ms  (over %d slots)\n', ...
            onlyHbrMeasurements(iLoad).minimumRuntimeMs, ...
            onlyHbrMeasurements(iLoad).averageRuntimeMs, ...
            onlyHbrMeasurements(iLoad).maximumRuntimeMs, ...
            nSlot);
    end
    % 論文判準：EABR 的執行時間應小於 1 s 的 time slot 長度
    if eabrMeasurements(iLoad).maximumRuntimeMs > 1000
        warning('main_overhead_evaluation:EABRRuntime', ...
            'EABR maximum runtime at user load %d is %.3f ms (> 1000 ms).', ...
            userLoad, eabrMeasurements(iLoad).maximumRuntimeMs);
    else
        fprintf('  EABR maximum runtime check: %.3f ms < 1000 ms.\n', ...
            eabrMeasurements(iLoad).maximumRuntimeMs);
    end
    if pcTiltMeasurements(iLoad).minimumRuntimeMs > 1000
        fprintf('  PC+Tilt: all %d slots exceed 1000 ms (min = %.3f ms).\n', ...
            nSlot, pcTiltMeasurements(iLoad).minimumRuntimeMs);
    end
end

summaryTable = table(cfg.userLoads(:), ...
    arrayfun(@(x) x.minimumRuntimeMs, pcTiltMeasurements), ...
    arrayfun(@(x) x.averageRuntimeMs, pcTiltMeasurements), ...
    arrayfun(@(x) x.maximumRuntimeMs, pcTiltMeasurements), ...
    arrayfun(@(x) x.stdRuntimeMs, pcTiltMeasurements), ...
    arrayfun(@(x) x.minimumRuntimeMs, eabrMeasurements), ...
    arrayfun(@(x) x.averageRuntimeMs, eabrMeasurements), ...
    arrayfun(@(x) x.maximumRuntimeMs, eabrMeasurements), ...
    arrayfun(@(x) x.stdRuntimeMs, eabrMeasurements), ...
    'VariableNames', {'UserLoad', ...
    'PcTiltMinimumRuntimeMs','PcTiltAverageRuntimeMs','PcTiltMaximumRuntimeMs', ...
    'PcTiltStdRuntimeMs', ...
    'EABRMinimumRuntimeMs','EABRAverageRuntimeMs','EABRMaximumRuntimeMs', ...
    'EABRStdRuntimeMs'});

% Only HBR 的欄位只在有量測時才加，避免舊流程的 CSV 欄位平白多出 NaN 行
if measureOnlyHbr
    summaryTable.OnlyHbrMinimumRuntimeMs = arrayfun(@(x) x.minimumRuntimeMs, onlyHbrMeasurements);
    summaryTable.OnlyHbrAverageRuntimeMs = arrayfun(@(x) x.averageRuntimeMs, onlyHbrMeasurements);
    summaryTable.OnlyHbrMaximumRuntimeMs = arrayfun(@(x) x.maximumRuntimeMs, onlyHbrMeasurements);
    summaryTable.OnlyHbrStdRuntimeMs = arrayfun(@(x) x.stdRuntimeMs, onlyHbrMeasurements);
end

rawRuntime = struct();
rawRuntime.userLoads = cfg.userLoads;
rawRuntime.pcTiltRuntimeMs = {pcTiltMeasurements.rawRuntimeMs};
rawRuntime.eabrRuntimeMs = {eabrMeasurements.rawRuntimeMs};
rawRuntime.measureOnlyHbr = measureOnlyHbr;
if measureOnlyHbr
    rawRuntime.onlyHbrRuntimeMs = {onlyHbrMeasurements.rawRuntimeMs};
else
    rawRuntime.onlyHbrRuntimeMs = {};
end
rawRuntime.caseMetadata = caseMetadata;
rawRuntime.warmupRuns = cfg.warmupRuns;
rawRuntime.nSlots = nExpectedSlots;
rawRuntime.slotHalfWindow_s = cfg.slotHalfWindow_s;
rawRuntime.randomSeed = cfg.randomSeed;

writetable(summaryTable, cfg.summaryCsvPath);
save(cfg.rawMatPath, 'rawRuntime', 'summaryTable', 'cfg');

% 圖一：PC + Tilt vs EABR（一定會畫）
figurePaths = plot_overhead_result(summaryTable, cfg);
% 圖二：Only HBR vs EABR（論文 ch5_overhead_only_hbr_vs_eabr）
% 用 {} 包住確保得到 1x1 struct（與 plot_overhead_bar_chart 的回傳形狀一致）
onlyHbrFigurePaths = struct('png', {strings(0,1)}, ...
    'fig', {strings(0,1)}, 'pdf', {strings(0,1)});
if measureOnlyHbr
    onlyHbrFigurePaths = plot_overhead_only_hbr_result(summaryTable, cfg);
end

out = struct();
out.summaryTable = summaryTable;
out.rawRuntime = rawRuntime;
out.summaryCsvPath = cfg.summaryCsvPath;
out.rawMatPath = cfg.rawMatPath;
out.figurePaths = figurePaths;
out.onlyHbrFigurePaths = onlyHbrFigurePaths;
out.measureOnlyHbr = measureOnlyHbr;
out.reusedFunctions = [ ...
    "run_pc_tilt_online_existing_logic (reproduced PC+Tilt)", ...
    "runGraphSelectionPolicyLocal (EABR: SBR + power allocation + HBR)", ...
    "runGraphSelectionPolicyLocal + onlyHbrWithInitialPower (Only HBR)", ...
    "helper_availability Walker geometry (generate/align/propagate)", ...
    "graphRecoverySharedLocal", ...
    "gso_rx_gain_itu1428"];

fprintf('\nOverhead outputs saved in: %s\n', cfg.resultsDir);
fprintf('  Figure (PC+Tilt vs EABR) : %s.png\n', cfg.figureBasePath);
if measureOnlyHbr
    fprintf('  Figure (Only HBR vs EABR): %s.png\n', cfg.onlyHbrFigureBasePath);
else
    fprintf('  Only HBR skipped (cfg.measureOnlyHbr = false).\n');
end
end

function m = emptyMeasurementLocal()
m = struct('rawRuntimeMs',zeros(0,1), 'averageRuntimeMs',NaN, ...
    'minimumRuntimeMs',NaN, 'maximumRuntimeMs',NaN, ...
    'rawMinimumRuntimeMs',NaN, 'rawMaximumRuntimeMs',NaN, ...
    'stdRuntimeMs',NaN, 'nSlots',0, 'lastDecision',struct(), ...
    'rangePercentiles',[10, 90]);
end
