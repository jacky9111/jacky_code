function paths = plot_overhead_bar_chart(opts)
%PLOT_OVERHEAD_BAR_CHART Grouped runtime bars with black I-range.
% Shared drawing/exporting routine for every overhead comparison figure so
% that all of them keep an identical look (font, size, colours, export set).
%
% 【中文說明】overhead 各張比較圖共用的繪圖與存檔routine。
% plot_overhead_result.m（PC+Tilt vs EABR）與
% plot_overhead_only_hbr_result.m（Only HBR vs EABR）都呼叫這支，
% 確保兩張圖的字型、尺寸、長條寬度、I 形線畫法完全一致 ——
% 論文並排時才不會看起來像兩套風格。
%
% 必要欄位 opts：
%   .xTickLabels    1 x nGroup 的 X 軸標籤（通常是 user 負載 30/50/70）
%   .series         1 x nSeries struct array，每個元素代表一組長條：
%                     .label  圖例文字
%                     .color  1x3 RGB
%                     .avg    nGroup x 1 平均值（長條高度）
%                     .low    nGroup x 1 誤差線下界
%                     .high   nGroup x 1 誤差線上界
%   .figureBases    cellstr，每個是「不含副檔名」的輸出路徑
%
% 可選欄位：
%   .xLabel         預設 'Number of users per satellite'
%   .yLabel         預設 'Online execution time (ms)'
%   .legendLocation 預設 'northwest'
%
% 輸出 paths：struct，欄位 .png / .fig / .pdf 各為 string 陣列
% （每個 figureBases 都會產生三種格式）。

% ---- 參數檢查與預設值 ----
if ~isfield(opts, 'series') || isempty(opts.series)
    error('plot_overhead_bar_chart:NoSeries', 'opts.series is required.');
end
if ~isfield(opts, 'figureBases') || isempty(opts.figureBases)
    error('plot_overhead_bar_chart:NoOutput', 'opts.figureBases is required.');
end
if ~isfield(opts, 'xLabel') || strlength(string(opts.xLabel)) == 0
    opts.xLabel = 'Number of users per satellite';
end
if ~isfield(opts, 'yLabel') || strlength(string(opts.yLabel)) == 0
    opts.yLabel = 'Online execution time (ms)';
end
if ~isfield(opts, 'legendLocation') || strlength(string(opts.legendLocation)) == 0
    opts.legendLocation = 'northwest';
end

nSeries = numel(opts.series);
% 把各系列的平均 / 上下界攤成 nGroup x nSeries 矩陣，供 bar 分組繪製
avgValues = cell2mat(arrayfun(@(s) s.avg(:), opts.series, 'UniformOutput', false));
minValues = cell2mat(arrayfun(@(s) s.low(:), opts.series, 'UniformOutput', false));
maxValues = cell2mat(arrayfun(@(s) s.high(:), opts.series, 'UniformOutput', false));
nLoad = size(avgValues, 1);

% ---- 建圖：分組長條 ----
fig = figure('Color','w', 'Units','inches', 'Position',[1 1 4.4 3.5]);
ax = axes('Parent', fig);
xPos = 1 + (0:(nLoad - 1)) * 0.78;
bars = bar(ax, xPos, avgValues, 0.62, 'grouped');
for iSeries = 1:nSeries
    bars(iSeries).FaceColor = opts.series(iSeries).color;
    bars(iSeries).DisplayName = char(string(opts.series(iSeries).label));
end
set(ax, 'XTick', xPos, 'XTickLabel', string(opts.xTickLabels));
xlim(ax, [xPos(1) - 0.55, xPos(end) + 0.55]);
hold(ax, 'on');
drawnow;   % 先 draw 一次，XEndPoints 才有值可以拿來對齊誤差線

% ---- 黑色 I 形線：從 low 畫到 high（誤差量以平均值為基準）----
errNeg = max(avgValues - minValues, 0);
errPos = max(maxValues - avgValues, 0);
for iSeries = 1:nSeries
    x = bars(iSeries).XEndPoints(:);   % 分組後每根長條的實際 X 位置
    y = avgValues(:, iSeries);
    eb = errorbar(ax, x, y, errNeg(:, iSeries), errPos(:, iSeries), ...
        'LineStyle', 'none', 'Color', 'k', 'LineWidth', 1.1, ...
        'CapSize', 8);
    eb.HandleVisibility = 'off';       % 誤差線不進圖例
end

yTop = max(maxValues, [], 'all');
if ~isfinite(yTop) || yTop <= 0
    yTop = 1;
end

% ---- 座標軸樣式（論文用 Times New Roman）----
xlabel(ax, char(string(opts.xLabel)));
ylabel(ax, char(string(opts.yLabel)));
legend(ax, bars, {opts.series.label}, ...
    'Location', char(string(opts.legendLocation)), 'Box', 'on');
grid(ax, 'on');
box(ax, 'on');
ax.FontName = 'Times New Roman';
ax.FontSize = 10;
ax.LineWidth = 0.8;
ylim(ax, [0, yTop * 1.18 + eps]);   % 頂端留 18% 空間給圖例
ax.Units = 'normalized';
ax.Position = [0.13 0.20 0.80 0.72];
hold(ax, 'off');
drawnow;

% ---- 輸出：每個 base 各存 png / fig / pdf ----
paths = struct('png', {{}}, 'fig', {{}}, 'pdf', {{}});
paths.png = strings(0, 1);
paths.fig = strings(0, 1);
paths.pdf = strings(0, 1);
set(fig, 'Color', 'w', 'InvertHardcopy', 'off', 'PaperPositionMode', 'auto');
figureBases = opts.figureBases;
if ~iscell(figureBases)
    figureBases = cellstr(string(figureBases));
end
for iBase = 1:numel(figureBases)
    base = char(string(figureBases{iBase}));
    outDir = fileparts(base);
    if strlength(string(outDir)) > 0 && ~exist(outDir, 'dir')
        mkdir(outDir);
    end
    pngPath = [base '.png'];
    figPath = [base '.fig'];
    pdfPath = [base '.pdf'];
    print(fig, pngPath, '-dpng', '-r600');       % 600 dpi 點陣圖
    savefig(fig, figPath);                       % 可再編輯的 MATLAB 圖檔
    print(fig, pdfPath, '-dpdf', '-painters');   % 論文用的向量圖
    paths.png(end+1, 1) = string(pngPath); %#ok<AGROW>
    paths.fig(end+1, 1) = string(figPath); %#ok<AGROW>
    paths.pdf(end+1, 1) = string(pdfPath); %#ok<AGROW>
end
end
