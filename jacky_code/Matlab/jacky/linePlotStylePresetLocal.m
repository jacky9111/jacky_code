function style = linePlotStylePresetLocal(nSeries, colorsIn)
% linePlotStylePresetLocal  Colors + line styles + markers for multi-series line plots.

if nargin < 1 || ~isfinite(nSeries) || nSeries < 1
    nSeries = 1;
end
nSeries = round(double(nSeries));

defaultColors = [
    0.0000 0.4470 0.7410
    0.8500 0.3250 0.0980
    0.4660 0.6740 0.1880
    0.0000 0.0000 0.0000
    0.4940 0.1840 0.5560
    0.9290 0.6940 0.1250
    0.3010 0.7450 0.9330
    0.6350 0.0780 0.1840];
defaultMarkers = {'o', 's', '^', 'd', 'x', 'p', 'v', '>'};
defaultLineStyles = {'-', '--', '-.', ':', '-', '--', '-.', ':'};

if nargin >= 2 && ~isempty(colorsIn)
    style.colors = colorsIn;
    if size(style.colors, 1) < nSeries
        style.colors = defaultColors(mod((0:nSeries - 1)', size(defaultColors, 1)) + 1, :);
    end
else
    style.colors = defaultColors(mod((0:nSeries - 1)', size(defaultColors, 1)) + 1, :);
end

style.markers = defaultMarkers(mod((0:nSeries - 1), numel(defaultMarkers)) + 1);
style.lineStyles = defaultLineStyles(mod((0:nSeries - 1), numel(defaultLineStyles)) + 1);
end
