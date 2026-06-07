function plotStyledLineLocal(ax, x, y, seriesIdx, style, lineWidth, displayName)
% plotStyledLineLocal  Line with spaced markers for paper-style multi-series plots.

if nargin < 6 || ~isfinite(lineWidth)
    lineWidth = 1.8;
end
seriesIdx = max(1, round(double(seriesIdx)));
x = x(:);
y = y(:);
mi = markerIndicesForLineLocal(numel(x), 10);
plot(ax, x, y, ...
    'Color', style.colors(seriesIdx, :), ...
    'LineStyle', style.lineStyles{seriesIdx}, ...
    'Marker', style.markers{seriesIdx}, ...
    'MarkerSize', 6, ...
    'MarkerIndices', mi, ...
    'LineWidth', lineWidth, ...
    'DisplayName', displayName);
end

function idx = markerIndicesForLineLocal(n, targetCount)
if nargin < 2 || ~isfinite(targetCount)
    targetCount = 10;
end
n = max(1, round(double(n)));
targetCount = max(3, round(double(targetCount)));
if n <= targetCount
    idx = (1:n)';
    return;
end
idx = unique(round(linspace(1, n, targetCount)), 'stable');
idx = idx(:);
end
