function measurement = measure_eabr_runtime(eabrScenarios, cfg)
%MEASURE_EABR_RUNTIME Time EABR (SBR + allocation + HBR) once per time slot.
% eabrScenarios: 1 x nSlot cell of scenarios (same users, evolving geometry).
%
% 【中文說明】量測 EABR 的「線上執行時間」。
% 每個 slot 呼叫一次 runGraphSelectionPolicyLocal（SBR + 功率配置 + HBR），
% 用 tic/toc 包住整個決策流程，得到該 slot 的執行時間 [ms]。
%
% eabrScenarios 是 1 x nSlot 的 cell，每個元素是該 slot 的場景快照：
% user 位置固定不變，只有衛星幾何隨時間演進 —— 這樣量到的時間差異
% 才純粹反映「救援決策複雜度」的變化，而不是 user 分佈的隨機波動。
%
% warmupRuns 先在第一個 slot 空跑幾次讓 MATLAB JIT 編譯完成，
% 這些暖機數據會被丟棄，避免第一個 slot 的時間被高估。

if ~iscell(eabrScenarios)
    eabrScenarios = {eabrScenarios};
end
nSlot = numel(eabrScenarios);
warmupRuns = 0;
if isfield(cfg, 'warmupRuns') && isfinite(cfg.warmupRuns)
    warmupRuns = max(0, round(cfg.warmupRuns));
end

for iRun = 1:warmupRuns
    scenario = eabrScenarios{1};
    runGraphSelectionPolicyLocal(scenario, 'dynamic', cfg.randomSeed);
end

runtimeMs = zeros(nSlot, 1);
lastDecision = struct();
for iSlot = 1:nSlot
    scenario = eabrScenarios{iSlot};
    timerId = tic;
    decision = runGraphSelectionPolicyLocal(scenario, 'dynamic', cfg.randomSeed);
    runtimeMs(iSlot) = toc(timerId) * 1000;
    lastDecision = decision;
end

if ~isfield(lastDecision, 'nSbrActivations') || ~isfield(lastDecision, 'nHbrActivations')
    error('measure_eabr_runtime:MissingDecision', ...
        'Existing EABR pipeline did not return its final online result.');
end

measurement = summarize_runtime_ms(runtimeMs, cfg);
measurement.lastDecision = lastDecision;
end
