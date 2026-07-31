function measurement = measure_only_hbr_runtime(eabrScenarios, cfg)
%MEASURE_ONLY_HBR_RUNTIME Time Only-HBR once per flyover time slot.
% eabrScenarios: 1 x nSlot cell of scenarios (same users, evolving geometry).
%
% 【中文說明】量測 Only HBR baseline 的線上執行時間。
% 作法是把場景標上 onlyHbrWithInitialPower = true 再丟給同一個
% runGraphSelectionPolicyLocal，讓它跳過 SBR 與功率釋放，
% recovery beam 只用預設功率 —— 所以執行時間會明顯低於 EABR。
%
% 刻意「重用 EABR 的同一組 eabrScenarios」，只加一個旗標：
% 這樣兩個方法面對的幾何、user 分佈、關閉束都完全相同，
% 量到的時間差才純粹來自「有沒有做 SBR + 功率重配」。
%
% 由 main_overhead_evaluation.m 呼叫，產生論文的
% runtime_overhead_only_hbr_vs_eabr 圖（Only HBR vs EABR）。

if ~iscell(eabrScenarios)
    eabrScenarios = {eabrScenarios};
end
nSlot = numel(eabrScenarios);
warmupRuns = 0;
if isfield(cfg, 'warmupRuns') && isfinite(cfg.warmupRuns)
    warmupRuns = max(0, round(cfg.warmupRuns));
end

% Warm-up on the first slot only (discarded; not part of min/avg/max).
for iRun = 1:warmupRuns
    scenario = eabrScenarios{1};
    scenario.onlyHbrWithInitialPower = true;
    runGraphSelectionPolicyLocal(scenario, 'dynamic', cfg.randomSeed);
end

runtimeMs = zeros(nSlot, 1);
lastDecision = struct();
for iSlot = 1:nSlot
    scenario = eabrScenarios{iSlot};
    scenario.onlyHbrWithInitialPower = true;
    timerId = tic;
    decision = runGraphSelectionPolicyLocal(scenario, 'dynamic', cfg.randomSeed);
    runtimeMs(iSlot) = toc(timerId) * 1000;
    lastDecision = decision;
end

if ~isfield(lastDecision, 'nHbrActivations')
    error('measure_only_hbr_runtime:MissingDecision', ...
        'Only-HBR pipeline did not return its final online result.');
end

% 與 measure_eabr_runtime / measure_pc_tilt_runtime 走同一支統計函式：
% (1) 三個方法的 I 形線語意一致（同樣是百分位範圍，見 summarize_runtime_ms）
% (2) 回傳的 struct 欄位集合一致，才能塞進 main_overhead_evaluation
%     用 repmat(emptyMeasurementLocal(), ...) 建出來的 struct array
measurement = summarize_runtime_ms(runtimeMs, cfg);
measurement.lastDecision = lastDecision;
end
