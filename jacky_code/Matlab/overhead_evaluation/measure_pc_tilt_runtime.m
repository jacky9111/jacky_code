function measurement = measure_pc_tilt_runtime(pcTiltScenarios, cfg)
%MEASURE_PC_TILT_RUNTIME Time reproduced PC+Tilt once per flyover time slot.
% pcTiltScenarios: 1 x nSlot cell of inputs (same users, evolving geometry).
%
% 【中文說明】量測「重現版 PC + Tilt」的線上執行時間，量法與 measure_eabr_runtime
% 完全對稱（同樣的暖機、同樣的 tic/toc 包法、同樣的 slot 序列），
% 兩者才能放在同一張圖上比較。
%
% 【論文有特別說明的一點】Jalali et al. 原文並未報告執行時間，
% 所以圖上的 PC + Tilt 數據是「我們的重現實作」量出來的，不是原論文的數字。

if ~iscell(pcTiltScenarios)
    pcTiltScenarios = {pcTiltScenarios};
end
nSlot = numel(pcTiltScenarios);
warmupRuns = 0;
if isfield(cfg, 'warmupRuns') && isfinite(cfg.warmupRuns)
    warmupRuns = max(0, round(cfg.warmupRuns));
end

for iRun = 1:warmupRuns
    run_pc_tilt_online_existing_logic(pcTiltScenarios{1});
end

runtimeMs = zeros(nSlot, 1);
lastDecision = struct();
for iSlot = 1:nSlot
    timerId = tic;
    decision = run_pc_tilt_online_existing_logic(pcTiltScenarios{iSlot});
    runtimeMs(iSlot) = toc(timerId) * 1000;
    lastDecision = decision;
end

if ~isfield(lastDecision, 'power_W') || ~isfield(lastDecision, 'tilt_deg')
    error('measure_pc_tilt_runtime:MissingDecision', ...
        'PC+Tilt solver did not return final power and tilt decisions.');
end

measurement = summarize_runtime_ms(runtimeMs, cfg);
measurement.lastDecision = lastDecision;
end
