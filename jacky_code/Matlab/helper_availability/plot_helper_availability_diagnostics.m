function plot_helper_availability_diagnostics(caseResults, cfg)
% plot_helper_availability_diagnostics
% Produce verification figures (one independent figure each, no subplots)
% for every constellation-like geometry and save them as .png and .fig to
%   results/figures/
%
% Five diagnostics per geometry (English labels/legend/title):
%   1. Number of critical satellites versus time
%   2. Average recovery-capable helpers per critical satellite versus time
%   3. Closed-beam helper-coverage ratio versus time
%   4. Aggregate EPFD versus time (with the EPFD limit)
%   5. Number of closed beams versus time
%
% Inputs:
%   caseResults : 1 x N cell of run_constellation_case outputs
%   cfg         : full config (for cfg.io.figuresDir and EPFD limit)

figDir = cfg.io.figuresDir;
if ~exist(figDir, 'dir')
    mkdir(figDir);
end
outDirs = {figDir};
if isfield(cfg.io, 'matlabDataDir') && strlength(string(cfg.io.matlabDataDir)) > 0
    if ~exist(cfg.io.matlabDataDir, 'dir')
        mkdir(cfg.io.matlabDataDir);
    end
    outDirs{end+1} = cfg.io.matlabDataDir; %#ok<AGROW>
end
epfdLimit_dB = cfg.common.epfdThr_dB;

for i = 1:numel(caseResults)
    cr = caseResults{i};
    ts = cr.timeSeries;
    tag = sanitize_name(cr.name);

    for d = 1:numel(outDirs)
        outDir = outDirs{d};
        save_line_figure(ts.t_s, ts.nCriticalSats, ...
            'Time (s)', 'Number of critical satellites', ...
            sprintf('%s: critical satellites vs time', cr.name), ...
            fullfile(outDir, sprintf('%s_1_critical_satellites', tag)), [], '');

        save_line_figure(ts.t_s, ts.avgHelpersPerCritical, ...
            'Time (s)', 'Avg. recovery-capable helpers per critical satellite', ...
            sprintf('%s: avg. recovery-capable helpers vs time', cr.name), ...
            fullfile(outDir, sprintf('%s_2_avg_helpers', tag)), [], '');

        save_line_figure(ts.t_s, ts.closedBeamCoveragePct, ...
            'Time (s)', 'Closed-beam helper-coverage ratio (%)', ...
            sprintf('%s: closed-beam helper-coverage ratio vs time', cr.name), ...
            fullfile(outDir, sprintf('%s_3_closedbeam_coverage', tag)), [], '');

        save_line_figure(ts.t_s, ts.aggEpfdBefore_dB, ...
            'Time (s)', 'Aggregate EPFD (dB(W/m^2/BW_{ref}))', ...
            sprintf('%s: aggregate EPFD vs time', cr.name), ...
            fullfile(outDir, sprintf('%s_4_aggregate_epfd', tag)), epfdLimit_dB, 'EPFD limit');

        save_line_figure(ts.t_s, ts.nClosedBeams, ...
            'Time (s)', 'Number of closed beams', ...
            sprintf('%s: closed beams vs time', cr.name), ...
            fullfile(outDir, sprintf('%s_5_closed_beams', tag)), [], '');
    end
end

fprintf('Saved diagnostic figures to: %s\n', strjoin(outDirs, ' | '));
end

function save_line_figure(x, y, xlab, ylab, ttl, basePath, limitVal, limitName)
fig = figure('Color', 'w', 'Visible', 'off');
ax = axes('Parent', fig);
plot(ax, x, y, '-', 'LineWidth', 1.5, 'Color', [0.0 0.45 0.74], ...
    'DisplayName', 'value');
hold(ax, 'on');
if ~isempty(limitVal)
    plot(ax, [min(x) max(x)], [limitVal limitVal], '--', 'LineWidth', 1.3, ...
        'Color', [0.85 0.33 0.10], 'DisplayName', limitName);
    legend(ax, 'Location', 'best');
end
grid(ax, 'on'); box(ax, 'on');
xlabel(ax, xlab); ylabel(ax, ylab); title(ax, ttl);
xlim(ax, [min(x) max(x)]);
hold(ax, 'off');

saveas(fig, [basePath '.png']);
savefig(fig, [basePath '.fig']);
close(fig);
end

function s = sanitize_name(name)
s = regexprep(char(name), '[^A-Za-z0-9]+', '_');
s = regexprep(s, '_+', '_');
s = regexprep(s, '^_|_$', '');
end
