function Tplot = PlotFullPowerSweepRelayUserCountCompare(~, opts)
% PlotFullPowerSweepRelayUserCountCompare
% Fig.4 grouped bars: Only BPLR vs SAPR-R relay user counts over time segments.
% t=0 = worst pre-backoff EPFD slot on reference Excel (same as fig.1–3).
%
% Required:
%   opts.referenceExcelPath
%   opts.methodDefs — label, excelPath (two methods)
%
% Optional:
%   recordSatellite (default P03_S49)
%   relTimeWindowSec (default [-60, 60])
%   timeSegmentEdges (default [-60 -40 -20 0 20 40 60], same as fig.2)
%   nTimeSegments — used only if timeSegmentEdges omitted (equal-width bins)
%   relayUserMetric — 'assigned' | 'satisfied' (default 'satisfied')
%   relaySuccessThreshold (default 0.9, for 'satisfied')
%   segmentAggregate — 'mean' | 'sum' (default 'mean')
%   yLabel — default 'Number of recovered closed-beam users'
%
% =====================================================================
% 【中文說明】論文 Evaluation 圖四：ch5_U{50,70}_RecoveredUserCount
%   「Number of recovered closed-beam users achieved by Only HBR and EABR」
%
% 畫什麼：分組長條圖，比較 Only HBR 與 EABR 各自「成功救回幾個關閉束下的 user」。
%         這張圖是圖三（平均滿意度）的原因解釋 ——
%         EABR 之所以滿意度較高，是因為它靠 SBR 釋放出 helper 的可用功率，
%         所以能救回更多 user，差距在 worst EPFD slot 附近最明顯。
%
% 論文只畫 U50 與 U70：U30 是低負載，helper 預設功率就夠用，兩法差異不明顯。
%
% 關鍵參數（jacky.m 的 optsFig4）：
%   relayUserMetric        'satisfied' = 只算「接手後滿意度達標」的 user（論文用這個）
%                          'assigned'  = 只要被指派給 helper 就算，不管服務品質
%   relaySuccessThreshold  上面 'satisfied' 的門檻，預設 0.9
%   timeSegmentEdges       與圖二相同，方便兩張圖對照
%   yLim                   通常設 [0, U]，U = 本次 sweep 的每星 user 數
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
if ~isfield(opts, 'timeSegmentEdges') || isempty(opts.timeSegmentEdges)
    if ~isfield(opts, 'nTimeSegments') || ~isfinite(opts.nTimeSegments)
        opts.timeSegmentEdges = [-60, -40, -20, 0, 20, 40, 60];
    end
end
if ~isfield(opts, 'nTimeSegments') || ~isfinite(opts.nTimeSegments)
    opts.nTimeSegments = 6;
end
if ~isfield(opts, 'yLabel') || strlength(string(opts.yLabel)) == 0
    opts.yLabel = "Number of recovered closed-beam users";
end
if ~isfield(opts, 'relayUserMetric') || strlength(string(opts.relayUserMetric)) == 0
    opts.relayUserMetric = "satisfied";
end
if ~isfield(opts, 'relaySuccessThreshold') || ~isfinite(opts.relaySuccessThreshold)
    opts.relaySuccessThreshold = 0.9;
end
if ~isfield(opts, 'segmentAggregate') || strlength(string(opts.segmentAggregate)) == 0
    opts.segmentAggregate = "mean";
end
if ~isfield(opts, 'showFigure') || isempty(opts.showFigure)
    opts.showFigure = true;
end

recordSat = "P03_S49";
if isfield(opts, 'recordSatellite') && strlength(string(opts.recordSatellite)) > 0
    recordSat = string(opts.recordSatellite);
end

win = double(opts.relTimeWindowSec(:)).';
if isfield(opts, 'timeSegmentEdges') && ~isempty(opts.timeSegmentEdges)
    segmentSpec = double(opts.timeSegmentEdges(:)).';
    nSeg = numel(segmentSpec);
else
    segmentSpec = max(1, round(double(opts.nTimeSegments)));
    nSeg = segmentSpec;
end
tRelByTime = buildTimeOffsetMapFromSlotEpfdLocal(opts.referenceExcelPath);

nMethod = numel(opts.methodDefs);
if ~isfield(opts, 'colors') || isempty(opts.colors)
    cmap = [0.85 0.33 0.10; 0.47 0.67 0.19];
    opts.colors = cmap(mod((0:nMethod - 1)', size(cmap, 1)) + 1, :);
end

segLabels = strings(0, 1);
xBar = [];
Y = nan(nSeg, nMethod);
Tplot = table();

for m = 1:nMethod
    def = opts.methodDefs(m);
    slotTable = loadRelayUsersPerSlotLocal(def.excelPath, recordSat, ...
        opts.relayUserMetric, opts.relaySuccessThreshold);
    seg = aggregateRelayCountByTimeSegmentsLocal(slotTable, tRelByTime, win, segmentSpec, opts.segmentAggregate);
    if isempty(segLabels)
        segLabels = seg.labels;
        xBar = seg.xBar(:);
    end
    y = seg.plotValue(:);
    if numel(y) ~= nSeg
        error('Segment count mismatch for method %s.', def.label);
    end
    Y(:, m) = y;

    block = table(xBar(:), repmat(string(def.label), nSeg, 1), y(:), ...
        'VariableNames', {'time_offset_from_worst_epfd_slot_s', 'method', 'relay_user_count'});
    Tplot = [Tplot; block]; %#ok<AGROW>
end

if opts.showFigure
    fig = figure('Name', 'Relay user count (method compare)', 'Color', 'w');
    ax = axes('Parent', fig);
    if isempty(xBar)
        xBar = (1:nSeg)';
    end
    if ~isfield(opts, 'barWidth') || ~isfinite(opts.barWidth)
        opts.barWidth = 0.65;
    end
    bh = bar(ax, xBar(:), Y, double(opts.barWidth), 'grouped', 'EdgeColor', 'none');
    for m = 1:min(nMethod, numel(bh))
        bh(m).FaceColor = opts.colors(m, :);
        bh(m).DisplayName = string(opts.methodDefs(m).label);
    end
    grid(ax, 'on');
    xlabel(ax, 'Time Offset from Worst EPFD Slot (s)');
    ylabel(ax, char(string(opts.yLabel)));
    xticks(ax, xBar);
    xticklabels(ax, arrayfun(@(x) sprintf('%.0f', x), xBar, 'UniformOutput', false));
    xlim(ax, [min(xBar) - 15, max(xBar) + 15]);
    lg = legend(ax, 'Location', 'northeast');
    lg.FontSize = 8;
    lg.Box = 'on';
    if ~isfield(opts, 'yLim') || numel(opts.yLim) ~= 2
        if isfield(opts, 'yMaxUsers') && isfinite(opts.yMaxUsers)
            opts.yLim = [0, double(opts.yMaxUsers)];
        elseif isfield(opts, 'numUsersPerSat') && isfinite(opts.numUsersPerSat)
            opts.yLim = [0, double(opts.numUsersPerSat)];
        else
            opts.yLim = [0, max(Y(:), [], 'omitnan') * 1.08 + 1e-6];
        end
    end
    ylim(ax, double(opts.yLim(:)).');
    applyFigureTitleIfPresentLocal(ax, opts);
    if ~isfield(opts, 'figurePath') || strlength(string(opts.figurePath)) == 0
        opts.figurePath = fullfile(fileparts(char(string(opts.referenceExcelPath))), ...
            'RelayUserCount_MethodCompare.png');
    end
    figDir = fileparts(char(string(opts.figurePath)));
    if ~isempty(figDir) && ~exist(figDir, 'dir')
        mkdir(figDir);
    end
    saveas(fig, char(string(opts.figurePath)));
    fprintf('Saved figure: %s\n', char(string(opts.figurePath)));
end

if isfield(opts, 'tablePath') && strlength(string(opts.tablePath)) > 0
    writetable(Tplot, char(string(opts.tablePath)), 'Sheet', 'RelayUserCount');
    fprintf('Saved plot table: %s\n', char(string(opts.tablePath)));
end
end
