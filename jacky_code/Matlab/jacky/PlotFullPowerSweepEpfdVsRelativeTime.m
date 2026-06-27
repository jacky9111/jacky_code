function Tplot = PlotFullPowerSweepEpfdVsRelativeTime(~, opts)
% PlotFullPowerSweepEpfdVsRelativeTime
% GS aggregate EPFD vs time relative to critical satellite overhead (t = 0 s).
% Reads sheet Slot_EPFD from full-power sweep Excel (gs_epfd_before/after_dB).
%
% Required: opts.sweepExcelPath
% Optional:
%   sheetName           (default 'Slot_EPFD')
%   geoName             filter geo (default first in sheet)
%   epfdThreshold_dB    (default from sheet or -173.4)
%   plotEpfdField         'before' | 'after' (default 'after' = post-shutdown, EPFD legal)
%   relTimeWindowSec      [tMin tMax] default [-60 60]
%   yLim_dB               [y1 y2] EPFD axis limits in dB, e.g. [-173.65 -173.4]
%                         (with YDir reverse: more negative toward top)
%   figurePath, tablePath, showFigure

if nargin < 2 || isempty(opts)
    opts = struct();
end
if ~isfield(opts, 'sweepExcelPath') || strlength(string(opts.sweepExcelPath)) == 0
    error('opts.sweepExcelPath is required.');
end
excelPath = char(string(opts.sweepExcelPath));
if ~isfile(excelPath)
    error('Sweep Excel not found: %s', excelPath);
end
if ~isfield(opts, 'sheetName') || strlength(string(opts.sheetName)) == 0
    opts.sheetName = "Slot_EPFD";
end
if ~isfield(opts, 'plotEpfdField') || strlength(string(opts.plotEpfdField)) == 0
    opts.plotEpfdField = "after";
end
if ~isfield(opts, 'relTimeWindowSec') || numel(opts.relTimeWindowSec) ~= 2
    opts.relTimeWindowSec = [-60, 60];
end
if ~isfield(opts, 'showFigure') || isempty(opts.showFigure)
    opts.showFigure = true;
end

T = readtable(excelPath, 'Sheet', char(string(opts.sheetName)), 'TextType', 'string');
if isempty(T)
    error('Sheet %s is empty in %s.', char(string(opts.sheetName)), excelPath);
end

if isfield(opts, 'geoName') && strlength(string(opts.geoName)) > 0
    gMask = string(T.geo) == string(opts.geoName);
else
    gMask = true(height(T), 1);
end
T = T(gMask, :);
if isempty(T)
    error('No rows after geo filter in %s.', excelPath);
end

plotField = lower(string(opts.plotEpfdField));
tRel = FullPowerSweepSlotTimeOffsetLocal(T, opts);
switch plotField
    case "before"
        yEpfd = double(T.gs_epfd_before_dB);
        epfdLineName = 'Aggregate EPFD (before backoff)';
    case "after"
        yEpfd = double(T.gs_epfd_after_dB);
        epfdLineName = 'EABR';
    otherwise
        error('opts.plotEpfdField must be ''before'' or ''after''.');
end

if isfield(opts, 'epfdThreshold_dB') && isfinite(opts.epfdThreshold_dB)
    thr_dB = double(opts.epfdThreshold_dB);
elseif ismember('epfd_threshold_dB', T.Properties.VariableNames)
    thr_dB = double(T.epfd_threshold_dB(1));
else
    thr_dB = -173.4;
end

win = double(opts.relTimeWindowSec(:)).';
winMask = tRel >= win(1) - 1e-9 & tRel <= win(2) + 1e-9;
tPlot = tRel(winMask);
yPlot = yEpfd(winMask);
if isempty(tPlot)
    error('No samples in relTimeWindowSec [%.1f, %.1f] s.', win(1), win(2));
end

[tPlot, ord] = sort(tPlot, 'ascend');
yPlot = yPlot(ord);

if plotField == "after" && ismember('epfd_legal_before_relay', T.Properties.VariableNames)
    legalMask = winMask;
    legalCol = double(T.epfd_legal_before_relay(legalMask));
    nIllegal = sum(legalCol < 0.5, 'omitnan');
    if nIllegal > 0
        warning('PlotFullPowerSweepEpfdVsRelativeTime:AfterNotLegal', ...
            '%d slot(s) still above EPFD limit after beam shutdown (see Slot_EPFD).', nIllegal);
    end
end

if opts.showFigure
    fig = figure('Name', 'GS EPFD vs worst EPFD slot (t = 0)', 'Color', 'w');
    ax = axes('Parent', fig);
    hold(ax, 'on');
    yline(ax, thr_dB, 'r-', 'LineWidth', 1.8, 'DisplayName', sprintf('EPFD Constraint'));
    plot(ax, tPlot, yPlot, 'Color', [0 0 0], 'LineStyle', '-', 'LineWidth', 1.8, ...
        'DisplayName', epfdLineName);
    grid(ax, 'on');
    xlabel(ax, 'Time Offset from Worst EPFD Slot (s)');
    ylabel(ax, 'Aggregate EPFD (dBW/m²/40 kHz)');
    xlim(ax, win);
    set(ax, 'YDir', 'reverse');
    if isfield(opts, 'yLim_dB') && numel(opts.yLim_dB) == 2 && all(isfinite(opts.yLim_dB))
        ylim(ax, double(opts.yLim_dB(:)).');
    end
    legend(ax, 'Location', 'northeast');
    applyFigureTitleIfPresentLocal(ax, opts);
    hold(ax, 'off');
    if ~isfield(opts, 'figurePath') || strlength(string(opts.figurePath)) == 0
        [d, b, ~] = fileparts(excelPath);
        opts.figurePath = fullfile(d, [b '_EPFD_vsRelTime.png']);
    end
    figDir = fileparts(char(string(opts.figurePath)));
    if ~isempty(figDir) && ~exist(figDir, 'dir')
        mkdir(figDir);
    end
    saveas(fig, char(string(opts.figurePath)));
    fprintf('Saved figure: %s\n', char(string(opts.figurePath)));
end

Tplot = table(tPlot, yPlot, repmat(thr_dB, numel(tPlot), 1), ...
    'VariableNames', {'time_offset_from_worst_epfd_slot_s','gs_epfd_dB','epfd_threshold_dB'});
if isfield(opts, 'tablePath') && strlength(string(opts.tablePath)) > 0
    writetable(Tplot, char(string(opts.tablePath)), 'Sheet', 'EpfdVsRelTime');
    fprintf('Saved plot table: %s\n', char(string(opts.tablePath)));
end
end
