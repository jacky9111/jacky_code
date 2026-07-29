function paths = plot_overhead_result(summaryTable, cfg)
%PLOT_OVERHEAD_RESULT Grouped bars with black I-range.
% Bar height = average; I = configured percentile range (default p10–p90).

avgValues = [summaryTable.PcTiltAverageRuntimeMs, summaryTable.EABRAverageRuntimeMs];
minValues = [summaryTable.PcTiltMinimumRuntimeMs, summaryTable.EABRMinimumRuntimeMs];
maxValues = [summaryTable.PcTiltMaximumRuntimeMs, summaryTable.EABRMaximumRuntimeMs];

fig = figure('Color','w', 'Units','inches', 'Position',[1 1 4.4 3.5]);
ax = axes('Parent', fig);
nLoad = size(avgValues, 1);
xPos = 1 + (0:(nLoad - 1)) * 0.78;
bars = bar(ax, xPos, avgValues, 0.62, 'grouped');
bars(1).FaceColor = [0.18 0.45 0.70];
bars(2).FaceColor = [0.88 0.40 0.16];
bars(1).DisplayName = 'PC + Tilt';
bars(2).DisplayName = 'EABR';
set(ax, 'XTick', xPos, 'XTickLabel', string(summaryTable.UserLoad));
xlim(ax, [xPos(1) - 0.55, xPos(end) + 0.55]);
hold(ax, 'on');
drawnow;

errNeg = max(avgValues - minValues, 0);
errPos = max(maxValues - avgValues, 0);
for iMethod = 1:size(avgValues, 2)
    x = bars(iMethod).XEndPoints(:);
    y = avgValues(:, iMethod);
    eb = errorbar(ax, x, y, errNeg(:, iMethod), errPos(:, iMethod), ...
        'LineStyle', 'none', 'Color', 'k', 'LineWidth', 1.1, ...
        'CapSize', 8);
    eb.HandleVisibility = 'off';
end

yTop = max(maxValues, [], 'all');
if ~isfinite(yTop) || yTop <= 0
    yTop = 1;
end

xlabel(ax, 'Number of users per satellite');
ylabel(ax, 'Online execution time (ms)');
legend(ax, [bars(1), bars(2)], {'PC + Tilt', 'EABR'}, ...
    'Location', 'northwest', 'Box', 'on');
grid(ax, 'on');
box(ax, 'on');
ax.FontName = 'Times New Roman';
ax.FontSize = 10;
ax.LineWidth = 0.8;
ylim(ax, [0, yTop * 1.18 + eps]);
ax.Units = 'normalized';
ax.Position = [0.13 0.20 0.80 0.72];
hold(ax, 'off');
drawnow;

figureBases = {cfg.figureBasePath};
if isfield(cfg, 'figureExportPaths') && ~isempty(cfg.figureExportPaths)
    figureBases = cfg.figureExportPaths;
elseif isfield(cfg, 'matlabDataFigureBase') && strlength(string(cfg.matlabDataFigureBase)) > 0
    figureBases = unique([string(cfg.figureBasePath), string(cfg.matlabDataFigureBase)], 'stable');
    figureBases = cellstr(figureBases);
end

paths = struct('png', {{}}, 'fig', {{}}, 'pdf', {{}});
paths.png = strings(0, 1);
paths.fig = strings(0, 1);
paths.pdf = strings(0, 1);
set(fig, 'Color', 'w', 'InvertHardcopy', 'off', 'PaperPositionMode', 'auto');
for iBase = 1:numel(figureBases)
    base = char(figureBases{iBase});
    outDir = fileparts(base);
    if strlength(string(outDir)) > 0 && ~exist(outDir, 'dir')
        mkdir(outDir);
    end
    pngPath = [base '.png'];
    figPath = [base '.fig'];
    pdfPath = [base '.pdf'];
    print(fig, pngPath, '-dpng', '-r600');
    savefig(fig, figPath);
    print(fig, pdfPath, '-dpdf', '-painters');
    paths.png(end+1, 1) = string(pngPath); %#ok<AGROW>
    paths.fig(end+1, 1) = string(figPath); %#ok<AGROW>
    paths.pdf(end+1, 1) = string(pdfPath); %#ok<AGROW>
end
end
