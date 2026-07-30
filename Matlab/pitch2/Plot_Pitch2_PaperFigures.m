function Plot_Pitch2_PaperFigures(results, varargin)
% Plot_Pitch2_PaperFigures
% 重現論文評估圖（Coexistence LEO-GEO Ka Band, 2018 ICCC）
% 格式：論文風格、x 軸為實際時間、三子圖 (a)(b)(c)
%
% inputs:
%   results : run_pitch2_paper 回傳的 struct
%   varargin: 'SaveDir', dir  (可選，儲存 PNG)
%             'MultiTheta', {results_0, results_2, ...}  (可選，多 θ 比較)
%
% 若提供 MultiTheta，則 (a) 會畫多條線比較不同 θ

p = inputParser;
addParameter(p, 'SaveDir', '');
addParameter(p, 'MultiTheta', {});
parse(p, varargin{:});
saveDir = p.Results.SaveDir;
multiTheta = p.Results.MultiTheta;

ts = results.timeSeries;
cfg = results.config;
n = numel(ts.activeBeams);

% 將 time 字串轉為 datenum 供 x 軸
xTime = zeros(n, 1);
for i = 1:n
    xTime(i) = datenum(char(ts.time(i)));
end

fig = figure('Name', 'Pitch2 Paper Evaluation Figures', 'Position', [80 80 900 750]);
fig.Color = [1 1 1];

%% (a) Active beams - proxy for capacity
ax1 = subplot(3,1,1);
set(ax1, 'FontSize', 11, 'FontName', 'Times New Roman');
if isempty(multiTheta)
    plot(xTime, ts.activeBeams, 'b-', 'LineWidth', 1.8);
    title('(a) Active Beams (capacity proxy)');
else
    hold on;
    colors = lines(numel(multiTheta));
    for k = 1:numel(multiTheta)
        r = multiTheta{k};
        tt = r.timeSeries;
        nt = numel(tt.activeBeams);
        xt = zeros(nt,1);
        for i = 1:nt, xt(i) = datenum(char(tt.time(i))); end
        thetaVal = r.thetaBestDeg;
        plot(xt, tt.activeBeams, '-', 'LineWidth', 1.5, 'Color', colors(k,:), ...
            'DisplayName', sprintf('\\theta = %.1f°', thetaVal));
    end
    hold off;
    legend('Location', 'best', 'FontSize', 9);
    title('(a) Active Beams vs. Progressive Pitch \theta');
end
ylabel('Active beams');
grid on;
box on;
datetick('x', 'HH:MM', 'keepticks');
xlabel('Time (UTC)');

%% (b) Minimum discrimination angle α vs threshold α_th
ax2 = subplot(3,1,2);
set(ax2, 'FontSize', 11, 'FontName', 'Times New Roman');
plot(xTime, ts.minAlphaDeg, 'b-', 'LineWidth', 1.8);
hold on;
plot([xTime(1) xTime(end)], [cfg.alphaThDeg cfg.alphaThDeg], 'r--', 'LineWidth', 1.2);
hold off;
ylabel('min \alpha (deg)');
grid on;
box on;
title(sprintf('(b) Minimum Off-axis Angle (threshold \\alpha_{th} = %.1f°)', cfg.alphaThDeg));
legend('min \alpha', '\alpha_{th}', 'Location', 'best', 'FontSize', 9);
datetick('x', 'HH:MM', 'keepticks');
xlabel('Time (UTC)');

%% (c) Coverage overlap (negative = gap)
ax3 = subplot(3,1,3);
set(ax3, 'FontSize', 11, 'FontName', 'Times New Roman');
plot(xTime, ts.minOverlapDeg, 'b-', 'LineWidth', 1.8);
hold on;
plot([xTime(1) xTime(end)], [0 0], 'r--', 'LineWidth', 1.2);
hold off;
ylabel('min overlap (deg)');
xlabel('Time (UTC)');
grid on;
box on;
title('(c) Coverage Overlap (negative = gap)');
legend('min overlap', '0 (no gap)', 'Location', 'best', 'FontSize', 9);
datetick('x', 'HH:MM', 'keepticks');

sgtitle(sprintf('LEO-GEO Coexistence Evaluation (\\theta = %.2f°, step = %d s)', ...
    results.thetaBestDeg, cfg.stepSec), 'FontSize', 12, 'FontWeight', 'bold');

% 儲存
if ~isempty(saveDir)
    if ~exist(saveDir, 'dir'), mkdir(saveDir); end
    fname = fullfile(saveDir, sprintf('Pitch2_Paper_Fig_theta%.1f_%s.png', ...
        results.thetaBestDeg, datestr(now,'yyyymmdd_HHMM')));
    saveas(fig, fname);
    fprintf('已儲存: %s\n', fname);
end

%% 可選：多 θ 比較圖（單獨一張）
if ~isempty(multiTheta) && numel(multiTheta) >= 2
    fig2 = figure('Name', 'Pitch2 Theta Comparison', 'Position', [100 100 700 400]);
    fig2.Color = [1 1 1];
    hold on;
    colors = lines(numel(multiTheta));
    for k = 1:numel(multiTheta)
        r = multiTheta{k};
        tt = r.timeSeries;
        nt = numel(tt.activeBeams);
        xt = zeros(nt,1);
        for i = 1:nt, xt(i) = datenum(char(tt.time(i))); end
        thetaVal = r.thetaBestDeg;
        plot(xt, tt.activeBeams, '-', 'LineWidth', 2, 'Color', colors(k,:), ...
            'DisplayName', sprintf('\\theta = %.1f°', thetaVal));
    end
    hold off;
    xlabel('Time (UTC)');
    ylabel('Active beams');
    title('Active Beams: Progressive Pitch Comparison');
    legend('Location', 'best');
    grid on;
    box on;
    datetick('x', 'HH:MM', 'keepticks');

    if ~isempty(saveDir)
        fname2 = fullfile(saveDir, sprintf('Pitch2_Theta_Comparison_%s.png', datestr(now,'yyyymmdd_HHMM')));
        saveas(fig2, fname2);
        fprintf('已儲存: %s\n', fname2);
    end
end

end
