function Tplot = PlotFullPowerSweepSatisfactionVsTimeCompare(~, opts)
% PlotFullPowerSweepSatisfactionVsTimeCompare
% Four-method compare: home-cohort / satellite average user satisfaction vs
% time offset (t=0 = worst pre-backoff EPFD slot on reference Excel).
%
% Required:
%   opts.referenceExcelPath
%   opts.methodDefs — label, excelPath, sourceType ('fullpower'|'ku16_pc_tilt')
%
% Optional: recordSatellite (default P03_S49), relTimeWindowSec, yLim, yAxisPercent
%
% =====================================================================
% 【中文說明】本函式同時服務論文的兩張圖：
%
%  ● 圖三 ch5_U{30,50,70}_AvgUserSatisfaction_4MethodCompare
%    「Average user satisfaction of different interference mitigation methods」
%    四條線 = Beam shutdown only / PC + Tilt / Only HBR / EABR，
%    在同一個 user 負載下比平均滿意度隨時間的變化。
%
%  ● 圖六 ch5_U70_EABR_AvgUserSatisfaction_EpfdCompare
%    「Average user satisfaction of EABR under different EPFD limits」
%    這時 methodDefs 每一項換成「同一個 EABR、不同 EPFD 門檻的 Excel」，
%    幾條門檻就畫幾條線（jacky.m 的圖六迴圈負責組出 methodDefs）。
%
% 滿意度定義：min(1, 實際取得速率 / 需求速率 50 Mbps)，
%             統計對象是 recordSatellite 的 home cohort（原本歸屬該星的 user）。
%
% methodDefs 每一項的 sourceType 決定怎麼讀 Excel：
%   'fullpower'      → Beam shutdown only / Only HBR / EABR 的 sweep 檔
%   'ku16_pc_tilt'   → PC + Tilt 的 Ku16 baseline 檔（欄位格式不同）
%
% referenceExcelPath 只用來定義 t=0（worst EPFD slot），
% 所有方法共用同一個 t=0，橫軸才對得起來。
% =====================================================================

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
if ~isfield(opts, 'showFigure') || isempty(opts.showFigure)
    opts.showFigure = true;
end
if ~isfield(opts, 'yAxisPercent') || isempty(opts.yAxisPercent)
    opts.yAxisPercent = true;
end

recordSat = "P03_S49";
if isfield(opts, 'recordSatellite') && strlength(string(opts.recordSatellite)) > 0
    recordSat = string(opts.recordSatellite);
end

win = double(opts.relTimeWindowSec(:)).';

% 預設配色（依 methodDefs 順序取用）：黑 / 藍 / 橘 / 綠
nMethod = numel(opts.methodDefs);
if ~isfield(opts, 'colors') || isempty(opts.colors)
    cmap = [0 0 0; 0 0.45 0.74; 0.85 0.33 0.10; 0.47 0.67 0.19];
    opts.colors = cmap(mod((1:nMethod) - 1, size(cmap, 1)) + 1, :);
end
lineStyle = linePlotStylePresetLocal(nMethod, opts.colors);

Tplot = table();
fig = [];
ax = [];

if opts.showFigure
    fig = figure('Name', 'Average user satisfaction (method compare)', 'Color', 'w');
    ax = axes('Parent', fig);
    hold(ax, 'on');
end

for m = 1:nMethod
    def = opts.methodDefs(m);
    if ~isfield(def, 'sourceType') || strlength(string(def.sourceType)) == 0
        def.sourceType = "fullpower";
    end
    refPath = opts.referenceExcelPath;
    if isfield(def, 'referenceExcelPath') && strlength(string(def.referenceExcelPath)) > 0
        refPath = def.referenceExcelPath;
    end
    Tref = readtable(char(string(refPath)), 'Sheet', 'Slot_EPFD', 'TextType', 'string');
    tRelRef = FullPowerSweepSlotTimeOffsetLocal(Tref, struct());
    curve = loadMethodSatisfactionCurveLocal(def.excelPath, recordSat, def.sourceType);
    tRel = alignTimeOffsetToReferenceLocal(curve.times, tRelRef, Tref.time);
    winMask = tRel >= win(1) - 1e-9 & tRel <= win(2) + 1e-9;
    tPlot = tRel(winMask);
    yPlot = curve.avgSat(winMask);
    if opts.yAxisPercent
        yPlot = 100 * yPlot;
    end
    if isempty(tPlot)
        warning('PlotFullPowerSweepSatisfactionVsTimeCompare:Empty', ...
            'No samples for method %s in window [%.0f, %.0f] s.', def.label, win(1), win(2));
        continue;
    end
    [tPlot, ord] = sort(tPlot, 'ascend');
    yPlot = yPlot(ord);

    if opts.showFigure && isgraphics(ax)
        plotStyledLineLocal(ax, tPlot, yPlot, m, lineStyle, 1.8, string(def.label));
    end

    yCol = 'avg_user_satisfaction';
    if opts.yAxisPercent
        yCol = 'avg_user_satisfaction_percent';
    end
    block = table(tPlot, yPlot, repmat(string(def.label), numel(tPlot), 1), ...
        'VariableNames', {'time_offset_from_worst_epfd_slot_s', yCol, 'method'});
    Tplot = [Tplot; block]; %#ok<AGROW>
end

if isempty(Tplot)
    error('No method produced data in the requested time window.');
end

if opts.showFigure && isgraphics(ax)
    grid(ax, 'on');
    xlabel(ax, 'Time Offset from Worst EPFD Slot (s)');
    if opts.yAxisPercent
        ylabel(ax, 'Average user satisfaction (%)');
        if ~isfield(opts, 'yLim') || numel(opts.yLim) ~= 2
            opts.yLim = [0, 100];
        end
    else
        ylabel(ax, 'Average user satisfaction');
        if ~isfield(opts, 'yLim') || numel(opts.yLim) ~= 2
            opts.yLim = [0, 1];
        end
    end
    xlim(ax, win);
    ylim(ax, double(opts.yLim(:)).');
    legendLoc = 'southeast';
    if isfield(opts, 'legendLocation') && strlength(string(opts.legendLocation)) > 0
        legendLoc = char(string(opts.legendLocation));
    end
    lg = legend(ax, 'Location', legendLoc);
    lg.FontSize = 8;
    lg.ItemTokenSize = [14, 6];
    lg.Box = 'on';
    applyFigureTitleIfPresentLocal(ax, opts);
    hold(ax, 'off');
    if ~isfield(opts, 'figurePath') || strlength(string(opts.figurePath)) == 0
        opts.figurePath = fullfile(fileparts(char(string(opts.referenceExcelPath))), ...
            'AvgUserSatisfaction_MethodCompare.png');
    end
    figDir = fileparts(char(string(opts.figurePath)));
    if ~isempty(figDir) && ~exist(figDir, 'dir')
        mkdir(figDir);
    end
    saveas(fig, char(string(opts.figurePath)));
    fprintf('Saved figure: %s\n', char(string(opts.figurePath)));
end

if isfield(opts, 'tablePath') && strlength(string(opts.tablePath)) > 0
    writetable(Tplot, char(string(opts.tablePath)), 'Sheet', 'AvgUserSatisfaction');
    fprintf('Saved plot table: %s\n', char(string(opts.tablePath)));
end
end

function tRel = alignTimeOffsetToReferenceLocal(times, tRelRef, refTimes)
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
