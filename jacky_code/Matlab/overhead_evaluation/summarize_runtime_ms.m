function stats = summarize_runtime_ms(runtimeMs, cfg)
%SUMMARIZE_RUNTIME_MS Mean/std plus I-bar low/high from percentiles.
% Raw min/max are kept; reported minimum/maximum used for the figure I-bar
% default to the configured percentile range (avoids single-slot spikes).

runtimeMs = runtimeMs(:);
stats = struct();
stats.rawRuntimeMs = runtimeMs;
stats.averageRuntimeMs = mean(runtimeMs);
stats.stdRuntimeMs = std(runtimeMs);
stats.rawMinimumRuntimeMs = min(runtimeMs);
stats.rawMaximumRuntimeMs = max(runtimeMs);
stats.nSlots = numel(runtimeMs);

pLow = 10;
pHigh = 90;
if isfield(cfg, 'runtimeRangePercentiles') && numel(cfg.runtimeRangePercentiles) >= 2
    pLow = cfg.runtimeRangePercentiles(1);
    pHigh = cfg.runtimeRangePercentiles(2);
end
pLow = max(0, min(100, pLow));
pHigh = max(0, min(100, pHigh));
if pHigh < pLow
    tmp = pLow; pLow = pHigh; pHigh = tmp;
end
stats.rangePercentiles = [pLow, pHigh];
stats.minimumRuntimeMs = prctile(runtimeMs, pLow);
stats.maximumRuntimeMs = prctile(runtimeMs, pHigh);
end
