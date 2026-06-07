function Tplot = PlotFullPowerSweepClosedCriticalBeamsCompare(~, opts)
% PlotFullPowerSweepClosedCriticalBeamsCompare
% Stairs compare: Number of Closed Critical Beams vs time offset (t=0 = worst
% pre-backoff EPFD slot on reference Excel).
%
% Required:
%   opts.referenceExcelPath  (e.g. SAPR-R sweep for t=0)
%   opts.methodDefs          struct array with fields:
%       label, excelPath, sourceType ('fullpower'|'ku16_pc_tilt')
%
% Optional: criticalSatellite, relTimeWindowSec, yLim, colors, figurePath, tablePath

if nargin < 2 || isempty(opts)
    opts = struct();
end
if ~isfield(opts, 'referenceExcelPath') || strlength(string(opts.referenceExcelPath)) == 0
    error('opts.referenceExcelPath is required (defines t=0).');
end
if ~isfield(opts, 'methodDefs') || isempty(opts.methodDefs)
    error('opts.methodDefs is required.');
end
if ~isfield(opts, 'relTimeWindowSec') || numel(opts.relTimeWindowSec) ~= 2
    opts.relTimeWindowSec = [-60, 60];
end
if ~isfield(opts, 'yLim') || numel(opts.yLim) ~= 2
    opts.yLim = [0, 16];
end
if ~isfield(opts, 'showFigure') || isempty(opts.showFigure)
    opts.showFigure = true;
end

critSat = "P03_S49";
if isfield(opts, 'criticalSatellite') && strlength(string(opts.criticalSatellite)) > 0
    critSat = string(opts.criticalSatellite);
end

Tref = readtable(char(string(opts.referenceExcelPath)), 'Sheet', 'Slot_EPFD', 'TextType', 'string');
tRelRef = FullPowerSweepSlotTimeOffsetLocal(Tref, struct());
win = double(opts.relTimeWindowSec(:)).';

nMethod = numel(opts.methodDefs);
if ~isfield(opts, 'colors') || isempty(opts.colors)
    cmap = [0 0 0; 0 0.45 0.74; 0.85 0.33 0.10; 0.47 0.67 0.19];
    opts.colors = cmap(mod((1:nMethod) - 1, size(cmap, 1)) + 1, :);
end

Tplot = table();
fig = [];
ax = [];

if opts.showFigure
    fig = figure('Name', 'Closed critical beams (method compare)', 'Color', 'w');
    ax = axes('Parent', fig);
    hold(ax, 'on');
end

for m = 1:nMethod
    def = opts.methodDefs(m);
    if ~isfield(def, 'sourceType') || strlength(string(def.sourceType)) == 0
        def.sourceType = "fullpower";
    end
    curve = loadClosedCriticalBeamsCurveLocal(def.excelPath, critSat, def.sourceType);
    tRel = alignTimeOffsetToReferenceLocal(curve.times, tRelRef, Tref.time);
    winMask = tRel >= win(1) - 1e-9 & tRel <= win(2) + 1e-9;
    tPlot = tRel(winMask);
    yPlot = curve.nClosed(winMask);
    if isempty(tPlot)
        warning('PlotFullPowerSweepClosedCriticalBeamsCompare:Empty', ...
            'No samples for method %s in window [%.0f, %.0f] s.', def.label, win(1), win(2));
        continue;
    end
    [tPlot, ord] = sort(tPlot, 'ascend');
    yPlot = yPlot(ord);

    if opts.showFigure && isgraphics(ax)
        stairs(ax, tPlot, yPlot, '-', 'Color', opts.colors(m, :), 'LineWidth', 1.8, ...
            'DisplayName', string(def.label));
    end

    block = table(tPlot, yPlot, repmat(string(def.label), numel(tPlot), 1), ...
        'VariableNames', {'time_offset_from_worst_epfd_slot_s', 'closed_critical_beam_count', 'method'});
    Tplot = [Tplot; block]; %#ok<AGROW>
end

if isempty(Tplot)
    error('No method produced data in the requested time window.');
end

if opts.showFigure && isgraphics(ax)
    grid(ax, 'on');
    xlabel(ax, 'Time Offset from Worst EPFD Slot (s)');
    ylabel(ax, 'Number of Closed Critical Beams');
    xlim(ax, win);
    ylim(ax, double(opts.yLim(:)).');
    legend(ax, 'Location', 'northeast');
    hold(ax, 'off');
    if ~isfield(opts, 'figurePath') || strlength(string(opts.figurePath)) == 0
        opts.figurePath = fullfile(fileparts(char(string(opts.referenceExcelPath))), ...
            'ClosedCriticalBeams_MethodCompare.png');
    end
    figDir = fileparts(char(string(opts.figurePath)));
    if ~isempty(figDir) && ~exist(figDir, 'dir')
        mkdir(figDir);
    end
    saveas(fig, char(string(opts.figurePath)));
    fprintf('Saved figure: %s\n', char(string(opts.figurePath)));
end

if isfield(opts, 'tablePath') && strlength(string(opts.tablePath)) > 0
    writetable(Tplot, char(string(opts.tablePath)), 'Sheet', 'ClosedCriticalBeams');
    fprintf('Saved plot table: %s\n', char(string(opts.tablePath)));
end
end

function tRel = alignTimeOffsetToReferenceLocal(times, tRelRef, refTimes)
% Map each time in times to offset relative to reference slot where tRelRef==0.
times = string(times);
refTimes = string(refTimes);
[~, i0] = min(abs(tRelRef));
t0 = datenum(char(refTimes(i0)), 'dd mmm yyyy HH:MM:SS'); %#ok<DATNM>
tRel = nan(numel(times), 1);
for k = 1:numel(times)
    tk = datenum(char(times(k)), 'dd mmm yyyy HH:MM:SS'); %#ok<DATNM>
    tRel(k) = (tk - t0) * 86400;
end
end
