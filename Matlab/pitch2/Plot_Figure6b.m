function Plot_Figure6b(results, varargin)
% Plot_Figure6b
% 重現論文 Figure 6(b): Minimum off-axis angle vs latitude of LEO satellite
% 論文：Coexistence LEO-GEO Ka Band, 2018 ICCC
%
% inputs:
%   results : run_pitch2_paper 回傳的 struct
%   varargin: 'SaveDir', dir  (可選)

p = inputParser;
addParameter(p, 'SaveDir', '');
parse(p, varargin{:});
saveDir = p.Results.SaveDir;

ts = results.timeSeries;
cfg = results.config;

% 依緯度排序（論文 x 軸為 latitude）
lat = ts.leoLatDeg;
minAlpha = ts.minAlphaDeg;

% 移除 NaN
valid = ~isnan(lat) & ~isnan(minAlpha);
lat = lat(valid);
minAlpha = minAlpha(valid);
[latSort, idx] = sort(lat);
minAlphaSort = minAlpha(idx);

fig = figure('Name', 'Figure 6(b) Min off-axis angle vs latitude', 'Position', [100 100 600 400]);
fig.Color = [1 1 1];

plot(latSort, minAlphaSort, 'b-', 'LineWidth', 1.8);
hold on;
plot([latSort(1) latSort(end)], [cfg.alphaThDeg cfg.alphaThDeg], '--', 'Color', [0.5 0.7 1], 'LineWidth', 1.5);
hold off;

xlabel('Latitude (deg)');
ylabel('Minimum off-axis angle (deg)');
title(sprintf('(b) Minimum off-axis angle (threshold \\alpha_{th} = %.1f°)', cfg.alphaThDeg));
legend('min \alpha', 'Off-axis angle threshold', 'Location', 'best', 'FontSize', 10);
grid on;
box on;
set(gca, 'FontSize', 11, 'FontName', 'Times New Roman');

if ~isempty(saveDir)
    if ~exist(saveDir, 'dir'), mkdir(saveDir); end
    fname = fullfile(saveDir, sprintf('Figure6b_minAlpha_vs_latitude_%s.png', datestr(now,'yyyymmdd_HHMM')));
    saveas(fig, fname);
    fprintf('已儲存: %s\n', fname);
end

end
