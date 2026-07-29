function measurement = measure_only_hbr_runtime(eabrScenarios, cfg)
%MEASURE_ONLY_HBR_RUNTIME Time Only-HBR once per flyover time slot.
% eabrScenarios: 1 x nSlot cell of scenarios (same users, evolving geometry).

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

measurement = struct();
measurement.rawRuntimeMs = runtimeMs;
measurement.averageRuntimeMs = mean(runtimeMs);
measurement.minimumRuntimeMs = min(runtimeMs);
measurement.maximumRuntimeMs = max(runtimeMs);
measurement.stdRuntimeMs = std(runtimeMs);
measurement.nSlots = nSlot;
measurement.lastDecision = lastDecision;
end
