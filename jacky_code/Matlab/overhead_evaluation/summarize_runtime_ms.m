function stats = summarize_runtime_ms(runtimeMs, cfg)
%SUMMARIZE_RUNTIME_MS Mean/std plus I-bar low/high from percentiles.
% Raw min/max are kept; reported minimum/maximum used for the figure I-bar
% default to the configured percentile range (avoids single-slot spikes).
%
% 【中文說明】把 60 個 slot 的執行時間換算成圖上要用的統計量。
%
% 注意這裡有兩組 min/max，用途不同：
%   rawMinimumRuntimeMs / rawMaximumRuntimeMs  真正的最小/最大值
%       → 論文內文引用的「maximum execution time」用這組
%         （例如 U70 的 1066.11 ms 略超過 1 s，就是這個數字）
%   minimumRuntimeMs / maximumRuntimeMs        百分位版本（預設 p10–p90）
%       → 圖上黑色 I 形線用這組，避免單一異常 slot 讓誤差線失去可讀性
%
% 百分位範圍由 cfg.runtimeRangePercentiles 控制。

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
