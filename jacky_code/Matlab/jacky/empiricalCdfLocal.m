function [cdfY, satSorted, stats] = empiricalCdfLocal(sat)
% empiricalCdfLocal  Standard empirical CDF: F(x)=P(S<=x), y=(1:N)/N.

sat = sat(:);
sat = sat(isfinite(sat));
sat = min(max(sat, 0), 1);
satSorted = sort(sat, 'ascend');
n = numel(satSorted);
if n == 0
    cdfY = [];
    stats = struct('N', 0, 'cdf_y_end', NaN, 'avg', NaN, 'median', NaN, ...
        'frac_lt_0p5', NaN, 'frac_ge_0p9', NaN, 'sat_max', NaN);
    return;
end

cdfY = (1:n)' / n;
stats = struct();
stats.N = n;
stats.cdf_y_end = cdfY(end);
stats.avg = mean(satSorted);
stats.median = median(satSorted);
stats.frac_lt_0p5 = mean(satSorted < 0.5);
stats.frac_ge_0p9 = mean(satSorted >= 0.9);
stats.sat_max = max(satSorted);

if abs(stats.cdf_y_end - 1) > 1e-12
    error('empiricalCdfLocal:InvalidCdfEnd', 'cdf_y(end)=%.6f (expected 1).', stats.cdf_y_end);
end
end
