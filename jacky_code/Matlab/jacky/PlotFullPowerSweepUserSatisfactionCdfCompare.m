function [Tplot, Tstats] = PlotFullPowerSweepUserSatisfactionCdfCompare(~, opts)
% PlotFullPowerSweepUserSatisfactionCdfCompare
% Fig.5: standard empirical CDF F(x)=P(S<=x) at t0 (worst pre-backoff EPFD slot).
%
% Required:
%   opts.referenceExcelPath
%   opts.methodDefs — label, excelPath, sourceType ('fullpower'|'ku16_pc_tilt')
%
% Optional:
%   userSetMode — "all_users" (default) | "affected_users"
%   recordSatellite — for affected_users (default P03_S49)
%   geoName, xAxisPercent, showFigure, figurePath, tablePath
%
% =====================================================================
% 【中文說明】論文 Evaluation 圖五：ch5_U{50,70}_UserSatisfaction_CDF_3MethodCompare
%   「CDF of user satisfaction for different interference mitigation methods」
%
% 畫什麼：三個方法（PC + Tilt / Only HBR / EABR）在 t0 這一瞬間的
%         使用者滿意度經驗 CDF，F(x) = P(S <= x)。
%         曲線越往右 = 越多 user 維持高滿意度；
%         曲線在低滿意度區越早爬升 = 越多 user 服務品質受損。
%         論文結論：EABR 的曲線最偏右，代表它不只提高平均值，
%                   也降低了低滿意度 user 的比例。
%
% t0 的定義與圖一～圖四相同：referenceExcelPath 上「backoff 前 EPFD 最高」的 slot。
%
% userSetMode 決定統計哪一群 user：
%   "home_cohort"     recordSatellite 原本歸屬的 user（jacky.m 圖五用這個，與圖三/四一致）
%   "all_users"       所有 user
%   "affected_users"  只算受關束影響的 user
%
% 【注意】'fullpower' 來源的 Excel 必須含 PerUser 分頁才能算 CDF。
% 舊版 sweep 產生的 xlsx 沒有這個分頁，需要重跑 RelayOnly / EABR sweep。
% =====================================================================

if nargin < 2 || isempty(opts)
    opts = struct();
end
if ~isfield(opts, 'referenceExcelPath') || strlength(string(opts.referenceExcelPath)) == 0
    error('opts.referenceExcelPath is required (defines t0).');
end
if ~isfield(opts, 'methodDefs') || isempty(opts.methodDefs)
    error('opts.methodDefs is required.');
end
if ~isfield(opts, 'showFigure') || isempty(opts.showFigure)
    opts.showFigure = true;
end
if ~isfield(opts, 'xAxisPercent') || isempty(opts.xAxisPercent)
    opts.xAxisPercent = false;
end
if ~isfield(opts, 'userSetMode') || strlength(string(opts.userSetMode)) == 0
    opts.userSetMode = "all_users";
end

geoName = "";
if isfield(opts, 'geoName') && strlength(string(opts.geoName)) > 0
    geoName = string(opts.geoName);
end
criticalSat = "P03_S49";
if isfield(opts, 'recordSatellite') && strlength(string(opts.recordSatellite)) > 0
    criticalSat = string(opts.recordSatellite);
end

nMethod = numel(opts.methodDefs);
if ~isfield(opts, 'colors') || isempty(opts.colors)
    cmap = [0.85 0.33 0.10; 0 0.45 0.74; 0.47 0.67 0.19];
    opts.colors = cmap(mod((0:nMethod - 1)', size(cmap, 1)) + 1, :);
end
lineStyle = linePlotStylePresetLocal(nMethod, opts.colors);

[userIdsRequested, setMeta] = buildCdfUserSetLocal( ...
    opts.referenceExcelPath, opts.userSetMode, criticalSat, geoName);
fprintf('Fig5 user set: mode=%s, requested N=%d, t0=%s\n', ...
    setMeta.user_set_mode, setMeta.n_users_requested, char(setMeta.t0_time));

satByMethod = nan(numel(userIdsRequested), nMethod);
labels = strings(nMethod, 1);
for m = 1:nMethod
    def = opts.methodDefs(m);
    labels(m) = string(def.label);
    if ~isfield(def, 'sourceType') || strlength(string(def.sourceType)) == 0
        def.sourceType = "fullpower";
    end
    [satVec, loadMeta] = loadUserSatisfactionForUserSetLocal( ...
        def.excelPath, def.sourceType, setMeta.t0_time, userIdsRequested, geoName);
    satByMethod(:, m) = satVec;
    fprintf('Fig5 %s: found %d/%d users (coverage=%.1f%%)\n', ...
        char(def.label), loadMeta.n_found, numel(userIdsRequested), 100 * loadMeta.coverage);
end

commonMask = all(isfinite(satByMethod), 2);
nCommon = sum(commonMask);
if nCommon == 0
    error('No user has satisfaction in all methods at t0. Re-run sweeps with aligned PerUser logs.');
end
if nCommon < numel(userIdsRequested)
    warning('PlotFullPowerSweepUserSatisfactionCdfCompare:UserSetReduced', ...
        ['Using common intersection N=%d (requested %d on %s). ', ...
        'Re-run sweeps if a method is missing PerUser rows.'], ...
        nCommon, numel(userIdsRequested), char(setMeta.critical_satellite));
end
userIds = userIdsRequested(commonMask);

Tplot = table();
Tstats = table();
fig = [];
ax = [];

if opts.showFigure
    fig = figure('Name', 'Satisfaction CDF at Worst EPFD Slot', 'Color', 'w');
    ax = axes('Parent', fig);
    hold(ax, 'on');
    set(ax, 'FontSize', 13, 'FontName', 'Times New Roman');
end

for m = 1:nMethod
    sat = satByMethod(commonMask, m);
    [cdfY, satSorted, stats] = empiricalCdfLocal(sat);
    if isempty(satSorted)
        warning('PlotFullPowerSweepUserSatisfactionCdfCompare:Empty', ...
            'No user satisfaction at t0 for %s.', labels(m));
        continue;
    end
    if opts.xAxisPercent
        xPlot = 100 * satSorted;
    else
        xPlot = satSorted;
    end
    if opts.showFigure && isgraphics(ax)
        plotStyledLineLocal(ax, xPlot, cdfY, m, lineStyle, 2, string(labels(m)));
    end

    block = table(repmat(labels(m), numel(xPlot), 1), xPlot, cdfY, ...
        repmat(setMeta.t0_time, numel(xPlot), 1), repmat(stats.N, numel(xPlot), 1), ...
        repmat(string(setMeta.user_set_mode), numel(xPlot), 1), ...
        'VariableNames', {'method', 'user_satisfaction', 'cdf', 't0_time', 'n_users', 'user_set_mode'});
    Tplot = [Tplot; block]; %#ok<AGROW>

    statRow = table(labels(m), stats.N, stats.cdf_y_end, stats.avg, stats.median, ...
        stats.frac_lt_0p5, stats.frac_ge_0p9, stats.sat_max, ...
        repmat(setMeta.t0_time, 1), repmat(string(setMeta.user_set_mode), 1), ...
        'VariableNames', {'method', 'n_users', 'cdf_y_end', 'avg_satisfaction', ...
        'median_satisfaction', 'frac_satisfaction_lt_0p5', 'frac_satisfaction_ge_0p9', ...
        'max_satisfaction', 't0_time', 'user_set_mode'});
    Tstats = [Tstats; statRow]; %#ok<AGROW>

    fprintf(['Fig5 %s: N=%d, cdf_y(end)=%.4f, avg=%.4f, median=%.4f, ', ...
        'P(S<0.5)=%.3f, P(S>=0.9)=%.3f, max_sat=%.4f\n'], ...
        char(labels(m)), stats.N, stats.cdf_y_end, stats.avg, stats.median, ...
        stats.frac_lt_0p5, stats.frac_ge_0p9, stats.sat_max);
end

if isempty(Tplot)
    error('No CDF curves produced. Re-run sweeps with PerUser sheet (full-power) or Ku16 log.');
end

if opts.showFigure && isgraphics(ax)
    hold(ax, 'off');
    grid(ax, 'on');
    if opts.xAxisPercent
        xlabel(ax, 'User Satisfaction (%)', 'FontSize', 13, 'FontName', 'Times New Roman');
        xlim(ax, [0, 100]);
    else
        xlabel(ax, 'User Satisfaction', 'FontSize', 13, 'FontName', 'Times New Roman');
        xlim(ax, [0, 1]);
    end
    ylabel(ax, 'CDF', 'FontSize', 13, 'FontName', 'Times New Roman');
    ylim(ax, [0, 1]);
    applyFigureTitleIfPresentLocal(ax, opts);
    legendLoc = 'southeast';
    if isfield(opts, 'legendLocation') && strlength(string(opts.legendLocation)) > 0
        legendLoc = char(string(opts.legendLocation));
    end
    lg = legend(ax, 'Location', legendLoc);
    lg.FontSize = 8;
    lg.ItemTokenSize = [12, 4];
    lg.Box = 'on';
    if ~isfield(opts, 'figurePath') || strlength(string(opts.figurePath)) == 0
        opts.figurePath = fullfile(fileparts(char(string(opts.referenceExcelPath))), ...
            'UserSatisfaction_CDF_MethodCompare.png');
    end
    figDir = fileparts(char(string(opts.figurePath)));
    if ~isempty(figDir) && ~exist(figDir, 'dir')
        mkdir(figDir);
    end
    saveas(fig, char(string(opts.figurePath)));
    fprintf('Saved figure: %s\n', char(string(opts.figurePath)));
end

if isfield(opts, 'tablePath') && strlength(string(opts.tablePath)) > 0
    writetable(Tplot, char(string(opts.tablePath)), 'Sheet', 'UserSatisfactionCDF');
    writetable(Tstats, char(string(opts.tablePath)), 'Sheet', 'UserSatisfactionCDF_Stats');
    fprintf('Saved plot table: %s (CDF + Stats sheets)\n', char(string(opts.tablePath)));
end
end
