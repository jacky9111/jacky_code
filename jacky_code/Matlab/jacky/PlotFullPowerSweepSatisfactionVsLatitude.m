function Tplot = PlotFullPowerSweepSatisfactionVsLatitude(root, opts)
% PlotFullPowerSweepSatisfactionVsLatitude
% Plot home-cohort average user satisfaction vs satellite subpoint latitude
% using sheet AvgUserSatisfaction from the full-power shutdown sweep Excel.
%
% Single file: opts.sweepExcelPath
% Compare two sweeps: opts.compareExcelPaths + opts.compareLabels
%   e.g. relay-only vs relay+middle-helper-swap Excel outputs.

if nargin < 2 || isempty(opts)
    opts = struct();
end

if isfield(opts, 'compareExcelPaths') && ~isempty(opts.compareExcelPaths)
    comparePaths = string(opts.compareExcelPaths(:));
    if ~isfield(opts, 'compareLabels') || isempty(opts.compareLabels)
        opts.compareLabels = "Run " + (1:numel(comparePaths))';
    end
    compareLabels = string(opts.compareLabels(:));
    if numel(compareLabels) ~= numel(comparePaths)
        error('compareLabels length must match compareExcelPaths.');
    end
    Tplot = table();
    if ~isfield(opts, 'showFigure') || isempty(opts.showFigure)
        opts.showFigure = true;
    end
    if opts.showFigure
        fig = figure('Name', 'Sweep satisfaction vs latitude (compare)', 'Color', 'w');
        ax = axes('Parent', fig);
        hold(ax, 'on');
    else
        fig = [];
        ax = [];
    end
    lineColors = defaultAxesColorOrderLocal(numel(comparePaths));
    for iRun = 1:numel(comparePaths)
        optsRun = opts;
        optsRun.sweepExcelPath = comparePaths(iRun);
        optsRun.showFigure = false;
        Trun = plotOneSweepExcelLocal(root, optsRun, lineColors(iRun,:), compareLabels(iRun), ax);
        Trun.scenario = repmat(compareLabels(iRun), height(Trun), 1);
        Tplot = [Tplot; Trun]; %#ok<AGROW>
    end
    if isempty(Tplot)
        error('No data to plot for the requested comparison.');
    end
    if opts.showFigure && ~isempty(ax) && isgraphics(ax)
        grid(ax, 'on');
        xlabel(ax, 'Satellite subpoint latitude (deg)');
        if ~isfield(opts, 'yAxisPercent') || isempty(opts.yAxisPercent)
            opts.yAxisPercent = true;
        end
        if opts.yAxisPercent
            ylabel(ax, 'Home-cohort average user satisfaction (%)');
            ylim(ax, [0, 100]);
        else
            ylabel(ax, 'Home-cohort average user satisfaction');
            ylim(ax, [0, 1]);
        end
        legend(ax, 'Location', 'best');
        hold(ax, 'off');
        if ~isfield(opts, 'figurePath') || strlength(string(opts.figurePath)) == 0
            opts.figurePath = fullfile(fileparts(char(comparePaths(1))), ...
                'FullPowerSweep_SatisfactionVsLat_Compare.png');
        end
        figDir = fileparts(char(string(opts.figurePath)));
        if ~isempty(figDir) && ~exist(figDir, 'dir')
            mkdir(figDir);
        end
        saveas(fig, char(string(opts.figurePath)));
        fprintf('Saved figure: %s\n', char(string(opts.figurePath)));
    end
    if ~isfield(opts, 'tablePath') || strlength(string(opts.tablePath)) == 0
        opts.tablePath = fullfile(fileparts(char(comparePaths(1))), ...
            'FullPowerSweep_SatisfactionVsLat_Compare.xlsx');
    end
    tblDir = fileparts(char(string(opts.tablePath)));
    if ~isempty(tblDir) && ~exist(tblDir, 'dir')
        mkdir(tblDir);
    end
    writetable(Tplot, char(string(opts.tablePath)), 'Sheet', 'SatisfactionVsLat');
    fprintf('Saved plot table: %s\n', char(string(opts.tablePath)));
    return;
end

if ~isfield(opts, 'sweepExcelPath') || strlength(string(opts.sweepExcelPath)) == 0
    error('opts.sweepExcelPath or opts.compareExcelPaths is required.');
end
if ~isfield(opts, 'showFigure') || isempty(opts.showFigure)
    opts.showFigure = true;
end
fig = [];
ax = [];
if opts.showFigure
    fig = figure('Name', 'Sweep satisfaction vs latitude', 'Color', 'w');
    ax = axes('Parent', fig);
    hold(ax, 'on');
end
plotColors = defaultAxesColorOrderLocal(1);
Tplot = plotOneSweepExcelLocal(root, opts, plotColors(1, :), "", ax);
if isempty(Tplot)
    error('No data to plot for the requested satellites.');
end
if opts.showFigure && ~isempty(ax) && isgraphics(ax)
    grid(ax, 'on');
    xlabel(ax, 'Satellite subpoint latitude (deg)');
    if ~isfield(opts, 'yAxisPercent') || isempty(opts.yAxisPercent)
        opts.yAxisPercent = true;
    end
    if opts.yAxisPercent
        ylabel(ax, 'Home-cohort average user satisfaction (%)');
        ylim(ax, [0, 100]);
    else
        ylabel(ax, 'Home-cohort average user satisfaction');
        ylim(ax, [0, 1]);
    end
    if strlength(string(opts.sweepExcelPath)) > 0
        legend(ax, 'Location', 'best');
    end
    hold(ax, 'off');
    if ~isfield(opts, 'figurePath') || strlength(string(opts.figurePath)) == 0
        [excelDir, excelBase, ~] = fileparts(char(string(opts.sweepExcelPath)));
        opts.figurePath = fullfile(excelDir, [excelBase '_SatisfactionVsLat.png']);
    end
    figDir = fileparts(char(string(opts.figurePath)));
    if ~isempty(figDir) && ~exist(figDir, 'dir')
        mkdir(figDir);
    end
    saveas(fig, char(string(opts.figurePath)));
    fprintf('Saved figure: %s\n', char(string(opts.figurePath)));
end
if ~isfield(opts, 'tablePath') || strlength(string(opts.tablePath)) == 0
    [excelDir, excelBase, ~] = fileparts(char(string(opts.sweepExcelPath)));
    opts.tablePath = fullfile(excelDir, [excelBase '_SatisfactionVsLat.xlsx']);
end
tblDir = fileparts(char(string(opts.tablePath)));
if ~isempty(tblDir) && ~exist(tblDir, 'dir')
    mkdir(tblDir);
end
writetable(Tplot, char(string(opts.tablePath)), 'Sheet', 'SatisfactionVsLat');
fprintf('Saved plot table: %s\n', char(string(opts.tablePath)));
end

function Tplot = plotOneSweepExcelLocal(root, opts, lineColor, lineLabel, parentAx)
if nargin < 4
    lineLabel = "";
end
if nargin < 5
    parentAx = [];
end
excelPath = char(string(opts.sweepExcelPath));
if ~isfile(excelPath)
    error('Sweep Excel not found: %s', excelPath);
end

if ~isfield(opts, 'sheetName') || strlength(string(opts.sheetName)) == 0
    opts.sheetName = "AvgUserSatisfaction";
end
if ~isfield(opts, 'satNames') || isempty(opts.satNames)
    opts.satNames = string.empty(0, 1);
end
opts.satNames = string(opts.satNames(:));
if ~isfield(opts, 'gsLat_deg') || ~isfinite(opts.gsLat_deg)
    opts.gsLat_deg = 0;
end
if ~isfield(opts, 'latitudeWindowDeg') || ~isfinite(opts.latitudeWindowDeg)
    opts.latitudeWindowDeg = 20;
end
latitudeWindowDeg = abs(double(opts.latitudeWindowDeg));
if ~isfield(opts, 'plotNoRelay') || isempty(opts.plotNoRelay)
    opts.plotNoRelay = true;
end
if ~isfield(opts, 'yAxisPercent') || isempty(opts.yAxisPercent)
    opts.yAxisPercent = true;
end

T = readtable(excelPath, 'Sheet', char(string(opts.sheetName)), 'TextType', 'string');
if isempty(opts.satNames)
    opts.satNames = unique(string(T.sat), 'stable');
end

hasLatCol = ismember('sat_subpoint_lat_deg', T.Properties.VariableNames);
hasNoRelay = ismember('avg_user_satisfaction_no_relay', T.Properties.VariableNames);
times = normalizeTimeStringsLocal(T.time);
gsLat = double(opts.gsLat_deg);

Tplot = table();
satColors = defaultAxesColorOrderLocal(numel(opts.satNames));
doPlot = ~isempty(parentAx) && isgraphics(parentAx);

for iSat = 1:numel(opts.satNames)
    satName = opts.satNames(iSat);
    mask = string(T.sat) == satName;
    if ~any(mask)
        warning('PlotFullPowerSweepSatisfactionVsLatitude:SatMissing', ...
            'Satellite %s not found in %s.', satName, excelPath);
        continue;
    end

    Tsat = T(mask, :);
    tSat = times(mask);
    yRelay = double(Tsat.avg_user_satisfaction);
    if opts.yAxisPercent
        yRelay = yRelay * 100;
    end

    if hasLatCol
        latSat = double(Tsat.sat_subpoint_lat_deg);
    else
        latSat = satelliteLatitudesAtTimesLocal(root, satName, tSat);
        warning('PlotFullPowerSweepSatisfactionVsLatitude:NoLatColumn', ...
            'Column sat_subpoint_lat_deg missing; read latitude from STK for %s.', satName);
    end

    latRel = latSat - gsLat;
    winMask = abs(latRel) <= latitudeWindowDeg + 1e-12;
    latSat = latSat(winMask);
    latRel = latRel(winMask);
    tSat = tSat(winMask);
    yRelay = yRelay(winMask);

    if isempty(latSat)
        continue;
    end

    [latSorted, ord] = sort(latSat, 'ascend');
    ySorted = yRelay(ord);
    tSorted = tSat(ord);
    latRelSorted = latRel(ord);

    yNoRelaySorted = nan(numel(latSorted), 1);
    if hasNoRelay
        yNoRelay = double(Tsat.avg_user_satisfaction_no_relay);
        if opts.yAxisPercent
            yNoRelay = yNoRelay * 100;
        end
        yNoRelay = yNoRelay(winMask);
        yNoRelaySorted = yNoRelay(ord);
    end

    if doPlot
        if strlength(lineLabel) > 0
            relayLabel = lineLabel;
        elseif numel(opts.satNames) == 1
            relayLabel = 'With relay';
        else
            relayLabel = sprintf('%s (relay)', satName);
        end
        if isempty(lineColor)
            plotColor = satColors(iSat, :);
        else
            plotColor = lineColor;
        end
        plot(parentAx, latSorted, ySorted, '-', 'Color', plotColor, 'LineWidth', 1.8, ...
            'DisplayName', relayLabel);
        if opts.plotNoRelay && hasNoRelay
            if strlength(lineLabel) > 0
                noRelayLabel = lineLabel + " (no relay)";
            elseif numel(opts.satNames) == 1
                noRelayLabel = 'No relay';
            else
                noRelayLabel = sprintf('%s (no relay)', satName);
            end
            plot(parentAx, latSorted, yNoRelaySorted, '--', 'Color', plotColor, 'LineWidth', 1.2, ...
                'DisplayName', noRelayLabel);
        end
    end

    newBlock = table(tSorted, latSorted, latRelSorted, repmat(satName, numel(latSorted), 1), ...
        ySorted, 'VariableNames', {'time','sat_subpoint_lat_deg','lat_offset_from_gs_deg','sat','avg_user_satisfaction_plot'});
    if hasNoRelay
        newBlock.avg_user_satisfaction_no_relay_plot = yNoRelaySorted;
    end
    if strlength(lineLabel) > 0
        newBlock.scenario = repmat(lineLabel, height(newBlock), 1);
    end
    Tplot = [Tplot; newBlock]; %#ok<AGROW>
end
end

function cmap = defaultAxesColorOrderLocal(nColors)
% Avoid naming conflict with workspace/path variable named "lines".
cmap = get(groot, 'DefaultAxesColorOrder');
if isempty(cmap)
    cmap = [0.0000 0.4470 0.7410; 0.8500 0.3250 0.0980; 0.9290 0.6940 0.1250; ...
        0.4940 0.1840 0.5560; 0.4660 0.6740 0.1880; 0.3010 0.7450 0.9330; ...
        0.6350 0.0780 0.1840];
end
if nargin < 1 || isempty(nColors)
    nColors = size(cmap, 1);
end
nColors = max(1, round(double(nColors)));
idx = mod((1:nColors) - 1, size(cmap, 1)) + 1;
cmap = cmap(idx, :);
end

function timeStr = normalizeTimeStringsLocal(timeCol)
if isdatetime(timeCol)
    timeStr = string(timeCol, 'dd MMM yyyy HH:mm:ss');
elseif isstring(timeCol)
    timeStr = strtrim(timeCol);
else
    timeStr = strtrim(string(timeCol));
end
end

function lat_deg = satelliteLatitudesAtTimesLocal(root, satName, timeList)
sat = root.GetObjectFromPath(['*/Satellite/' char(satName)]);
dp = sat.DataProviders.Item('Cartesian Position').Group.Item('Fixed');
lat_deg = nan(numel(timeList), 1);
for i = 1:numel(timeList)
    res = dp.ExecSingle(char(timeList(i)));
    xyz = xyzFromArrayLocal(res.DataSets.ToArray);
    lat_deg(i) = asind(xyz(3) / max(norm(xyz), eps));
end
end

function P = xyzFromArrayLocal(arr)
if isnumeric(arr)
    P = double(arr(1:3));
    return;
end
vals = [];
for k = 1:numel(arr)
    a = arr{k};
    if isnumeric(a) && isscalar(a)
        vals(end+1, 1) = double(a); %#ok<AGROW>
    else
        n = str2double(string(a));
        if ~isfinite(n)
            continue;
        end
        vals(end+1, 1) = n; %#ok<AGROW>
    end
end
if numel(vals) < 3
    error('Cannot parse XYZ from STK output.');
end
P = vals(1:3);
end
