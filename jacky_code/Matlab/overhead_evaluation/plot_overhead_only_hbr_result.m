function paths = plot_overhead_only_hbr_result(summaryTable, cfg)
%PLOT_OVERHEAD_ONLY_HBR_RESULT Grouped bars with black I-range: Only HBR vs EABR.
% Bar height = average; I = configured percentile range (default p10–p90).
%
% 【中文說明】畫論文的 runtime_overhead_only_hbr_vs_eabr 圖
%   （論文 figures 中的 ch5_overhead_only_hbr_vs_eabr）
%   「Per-slot execution time of Only HBR and EABR under different user loads」
%
%   X 軸 = 每星 user 數（30/50/70）
%   長條高度 = 該負載下 60 個 slot 的平均執行時間
%   黑色 I 形線 = 執行時間範圍（預設 p10–p90，見 summarize_runtime_ms.m）
%
% 論文的觀察：Only HBR 在所有負載下都比較快，因為它只做關閉束 user 的重新關聯；
% EABR 額外做了 SBR 與 EPFD 受限的功率配置，所以線上計算負擔較高，
% 但平均執行時間仍低於 1 s 的 time slot 長度。
%
% 兩組數據來自 main_overhead_evaluation.m 的同一輪量測
% （同一組幾何、同一批 user、同一批 slot），差別只在
% measure_only_hbr_runtime 會把場景標上 onlyHbrWithInitialPower = true。
%
% 繪圖與存檔共用 plot_overhead_bar_chart.m，樣式與
% plot_overhead_result.m 產生的 PC+Tilt 對照圖完全一致。

if ~ismember('OnlyHbrAverageRuntimeMs', summaryTable.Properties.VariableNames)
    error('plot_overhead_only_hbr_result:MissingColumns', ...
        ['summaryTable has no Only-HBR columns. ', ...
         'Set cfg.measureOnlyHbr = true and re-run main_overhead_evaluation.']);
end

opts = struct();
opts.xTickLabels = string(summaryTable.UserLoad);

% 系列 1：Only HBR（綠）；系列 2：EABR（橘）
% 【顏色約定】EABR 沿用 PC+Tilt 對照圖的同一個橘色；
% Only HBR 用綠色，與該圖的 PC+Tilt 藍色區隔開。
opts.series(1) = struct( ...
    'label', 'Only HBR', ...
    'color', [0.47 0.67 0.19], ...
    'avg',   summaryTable.OnlyHbrAverageRuntimeMs, ...
    'low',   summaryTable.OnlyHbrMinimumRuntimeMs, ...
    'high',  summaryTable.OnlyHbrMaximumRuntimeMs);
opts.series(2) = struct( ...
    'label', 'EABR', ...
    'color', [0.88 0.40 0.16], ...
    'avg',   summaryTable.EABRAverageRuntimeMs, ...
    'low',   summaryTable.EABRMinimumRuntimeMs, ...
    'high',  summaryTable.EABRMaximumRuntimeMs);

opts.figureBases = resolveOnlyHbrFigureBasesLocal(cfg);
paths = plot_overhead_bar_chart(opts);
end

% ----------------------------------------------------------------------
function figureBases = resolveOnlyHbrFigureBasesLocal(cfg)
% 與 plot_overhead_result 同樣的路徑解析邏輯，只是換成 Only-HBR 的欄位。
figureBases = {cfg.onlyHbrFigureBasePath};
if isfield(cfg, 'onlyHbrFigureExportPaths') && ~isempty(cfg.onlyHbrFigureExportPaths)
    figureBases = cfg.onlyHbrFigureExportPaths;
elseif isfield(cfg, 'matlabDataOnlyHbrFigureBase') && ...
        strlength(string(cfg.matlabDataOnlyHbrFigureBase)) > 0
    figureBases = unique([string(cfg.onlyHbrFigureBasePath), ...
        string(cfg.matlabDataOnlyHbrFigureBase)], 'stable');
    figureBases = cellstr(figureBases);
end
end
