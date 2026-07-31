function Tplot = PlotFullPowerSweepClosedCriticalBeamsVsTime(~, opts)
% PlotFullPowerSweepClosedCriticalBeamsVsTime
% Bar chart: shut beams on critical satellite vs time offset (same t=0 as fig 1).
% Default bins: x = -60,-40,-20,0,20,40,60 s (mean closed-beam count per 20 s segment).
%
% Required: opts.sweepExcelPath
% Optional: sheetName ('Slot_EPFD'), criticalSatellite, relTimeWindowSec [-60 60],
%           timeSegmentEdges (default [-60 -40 -20 0 20 40 60]), segmentAggregate mean|max,
%           yLim [0 16], figurePath, tablePath, showFigure
%
% =====================================================================
% 【中文說明】論文 Evaluation 圖二：ch5_FullPower_BeamShutdown
%   「Number of closed beams on critical satellites over time」
%
% 畫什麼：長條圖，critical 衛星在各時間點為了滿足 EPFD 限制而必須關閉的 beam 數。
%         越接近 worst EPFD slot（t=0）關越多束，離開後逐漸減少 ——
%         說明關束需求是隨衛星-地面站幾何變化的，也就是服務救援的必要性來源。
%
% 資料來源：EABR sweep 的 Excel Slot_EPFD 分頁，橫軸 t=0 定義同圖一。
% 縱軸上限預設 16（因為每顆衛星就是 16 束）。
%
% 分箱邏輯：預設把 [-60, 60] 秒切成 -60/-40/-20/0/20/40/60 共 7 根長條，
%           每根取該區段內所有 slot 的平均（segmentAggregate='mean'）或最大值('max')。
%           邊界用相鄰刻度的中點切分，所以每根長條代表以該刻度為中心的 ±10 s。
%
% 常用參數（jacky.m 的 optsFig2）：
%   criticalSatellite  要統計的 critical 衛星，需與圖一、圖三同一顆
%   timeSegmentEdges   長條位置；圖四用相同設定以便對照
%   segmentAggregate   'mean' 或 'max'
% =====================================================================

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
if ~isfield(opts, 'relTimeWindowSec') || numel(opts.relTimeWindowSec) ~= 2
    opts.relTimeWindowSec = [-60, 60];
end
if ~isfield(opts, 'showFigure') || isempty(opts.showFigure)
    opts.showFigure = true;
end
if ~isfield(opts, 'yLim') || numel(opts.yLim) ~= 2
    opts.yLim = [0, 16];
end
if ~isfield(opts, 'timeSegmentEdges') || isempty(opts.timeSegmentEdges)
    opts.timeSegmentEdges = [-60, -40, -20, 0, 20, 40, 60];
end
if ~isfield(opts, 'segmentAggregate') || strlength(string(opts.segmentAggregate)) == 0
    opts.segmentAggregate = "mean";
end
opts.timeSegmentEdges = double(opts.timeSegmentEdges(:)).';
if numel(opts.timeSegmentEdges) < 2
    error('opts.timeSegmentEdges needs at least two edges.');
end

T = readtable(excelPath, 'Sheet', char(string(opts.sheetName)), 'TextType', 'string');
if isempty(T)
    error('Sheet %s is empty in %s.', char(string(opts.sheetName)), excelPath);
end
if isfield(opts, 'geoName') && strlength(string(opts.geoName)) > 0
    T = T(string(T.geo) == string(opts.geoName), :);
end
if isempty(T)
    error('No rows after geo filter.');
end

critSat = "P03_S49";
if isfield(opts, 'criticalSatellite') && strlength(string(opts.criticalSatellite)) > 0
    critSat = string(opts.criticalSatellite);
elseif ismember('critical_satellite', T.Properties.VariableNames)
    critSat = string(T.critical_satellite(1));
end

tRel = FullPowerSweepSlotTimeOffsetLocal(T, opts);
curve = loadClosedCriticalBeamsCurveLocal(excelPath, critSat, 'fullpower');
nClosed = curve.nClosed;

win = double(opts.relTimeWindowSec(:)).';
winMask = tRel >= win(1) - 1e-9 & tRel <= win(2) + 1e-9;
tPlot = tRel(winMask);
yPlot = nClosed(winMask);
if isempty(tPlot)
    error('No samples in relTimeWindowSec [%.1f, %.1f] s.', win(1), win(2));
end
[tPlot, ord] = sort(tPlot, 'ascend');
yPlot = yPlot(ord);

% ---- 逐根長條做分箱聚合：以每個刻度為中心，取相鄰刻度中點為邊界 ----
edges = opts.timeSegmentEdges;
nBar = numel(edges);
xBar = edges;
yBar = nan(nBar, 1);
segAggregate = lower(string(opts.segmentAggregate));
for k = 1:nBar
    if k == 1   % 第一根：從視窗左界到「第一、二刻度的中點」
        lo = edges(1);
        hi = 0.5 * (edges(1) + edges(2));
        mask = tPlot >= lo - 1e-9 & tPlot < hi - 1e-9;
    elseif k == nBar   % 最後一根：從「倒數兩刻度的中點」到視窗右界
        lo = 0.5 * (edges(end - 1) + edges(end));
        hi = edges(end);
        mask = tPlot >= lo - 1e-9 & tPlot <= hi + 1e-9;
    else               % 中間各根：前後刻度的中點之間
        lo = 0.5 * (edges(k - 1) + edges(k));
        hi = 0.5 * (edges(k) + edges(k + 1));
        mask = tPlot >= lo - 1e-9 & tPlot < hi - 1e-9;
    end
    vals = yPlot(mask);
    if isempty(vals)
        yBar(k) = 0;                            % 該區段無資料 → 視為沒關束
    elseif segAggregate == "max"
        yBar(k) = max(vals, [], 'omitnan');     % 取區段內最嚴重的一個 slot
    else
        yBar(k) = mean(vals, 'omitnan');        % 論文預設：取區段平均
    end
end

if opts.showFigure
    fig = figure('Name', 'Closed critical beams vs time', 'Color', 'w');
    ax = axes('Parent', fig);
    bar(ax, xBar, yBar, 0.65, 'FaceColor', [0 0.45 0.74], 'EdgeColor', 'none');
    grid(ax, 'on');
    xlabel(ax, 'Time Offset from Worst EPFD Slot (s)');
    ylabel(ax, 'Number of Closed Critical Beams');
    xticks(ax, xBar);
    xticklabels(ax, arrayfun(@(x) sprintf('%.0f', x), xBar, 'UniformOutput', false));
    xlim(ax, [min(xBar) - 15, max(xBar) + 15]);
    ylim(ax, double(opts.yLim(:)).');
    applyFigureTitleIfPresentLocal(ax, opts);
    if ~isfield(opts, 'figurePath') || strlength(string(opts.figurePath)) == 0
        [d, b, ~] = fileparts(excelPath);
        opts.figurePath = fullfile(d, [b '_ClosedCriticalBeams_vsRelTime.png']);
    end
    figDir = fileparts(char(string(opts.figurePath)));
    if ~isempty(figDir) && ~exist(figDir, 'dir')
        mkdir(figDir);
    end
    saveas(fig, char(string(opts.figurePath)));
    fprintf('Saved figure: %s\n', char(string(opts.figurePath)));
end

Tplot = table(xBar(:), yBar(:), 'VariableNames', ...
    {'time_offset_from_worst_epfd_slot_s', 'closed_critical_beam_count'});
if isfield(opts, 'tablePath') && strlength(string(opts.tablePath)) > 0
    writetable(Tplot, char(string(opts.tablePath)), 'Sheet', 'ClosedCriticalBeams');
    fprintf('Saved plot table: %s\n', char(string(opts.tablePath)));
end
end
