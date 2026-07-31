function paths = plot_overhead_result(summaryTable, cfg)
%PLOT_OVERHEAD_RESULT Grouped bars with black I-range: PC+Tilt vs EABR.
% Bar height = average; I = configured percentile range (default p10–p90).
%
% 【中文說明】畫論文的 runtime_overhead_pc_tilt_vs_eabr 圖。
%   X 軸 = 每星 user 數（30/50/70）
%   長條高度 = 該負載下 60 個 slot 的平均執行時間
%   黑色 I 形線 = 執行時間範圍（預設 p10–p90，見 summarize_runtime_ms.m）
%
% 實際繪圖與存檔交給共用的 plot_overhead_bar_chart.m，
% 本檔只負責從 summaryTable 取出 PC+Tilt 與 EABR 兩組數據並指定顏色。
% Only HBR vs EABR 那張圖由 plot_overhead_only_hbr_result.m 負責。
%
% 圖檔會同時輸出 .png（600 dpi）/ .fig / .pdf 三種格式到
% cfg.figureExportPaths 列出的每個位置（results/ 與 jacky_code/Matlab_data/）。
% 論文用的是 .pdf 向量圖。

opts = struct();
opts.xTickLabels = string(summaryTable.UserLoad);

% 系列 1：PC + Tilt（藍）；系列 2：EABR（橘）
% 【顏色約定】EABR 在兩張 overhead 圖都用同一個橘色，方便論文並排對照。
opts.series(1) = struct( ...
    'label', 'PC + Tilt', ...
    'color', [0.18 0.45 0.70], ...
    'avg',   summaryTable.PcTiltAverageRuntimeMs, ...
    'low',   summaryTable.PcTiltMinimumRuntimeMs, ...
    'high',  summaryTable.PcTiltMaximumRuntimeMs);
opts.series(2) = struct( ...
    'label', 'EABR', ...
    'color', [0.88 0.40 0.16], ...
    'avg',   summaryTable.EABRAverageRuntimeMs, ...
    'low',   summaryTable.EABRMinimumRuntimeMs, ...
    'high',  summaryTable.EABRMaximumRuntimeMs);

opts.figureBases = resolveFigureBasesLocal(cfg);
paths = plot_overhead_bar_chart(opts);
end

% ----------------------------------------------------------------------
function figureBases = resolveFigureBasesLocal(cfg)
% 決定要輸出到哪些位置：優先用 cfg.figureExportPaths（results/ + Matlab_data/），
% 其次是 matlabDataFigureBase，最後退回單一 figureBasePath。
figureBases = {cfg.figureBasePath};
if isfield(cfg, 'figureExportPaths') && ~isempty(cfg.figureExportPaths)
    figureBases = cfg.figureExportPaths;
elseif isfield(cfg, 'matlabDataFigureBase') && strlength(string(cfg.matlabDataFigureBase)) > 0
    figureBases = unique([string(cfg.figureBasePath), string(cfg.matlabDataFigureBase)], 'stable');
    figureBases = cellstr(figureBases);
end
end
