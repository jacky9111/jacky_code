function measurement = measure_pc_tilt_runtime(pcTiltScenarios, cfg)
%MEASURE_PC_TILT_RUNTIME Time reproduced PC+Tilt once per flyover time slot.
% pcTiltScenarios: 1 x nSlot cell of inputs (same users, evolving geometry).

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
