function measurement = measure_eabr_runtime(eabrScenarios, cfg)
%MEASURE_EABR_RUNTIME Time EABR (SBR + allocation + HBR) once per time slot.
% eabrScenarios: 1 x nSlot cell of scenarios (same users, evolving geometry).

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
