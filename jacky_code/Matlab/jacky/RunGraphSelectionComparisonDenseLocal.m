function out = RunGraphSelectionComparisonDenseLocal(opts)
% RunGraphSelectionComparisonDenseLocal
% Compare four graph-based edge selection methods on dense OneWeb-like geometry.

if nargin < 1 || isempty(opts)
    opts = struct();
end
if ~isfield(opts, 'file_path') || strlength(string(opts.file_path)) == 0
    opts.file_path = "C:\Users\jacky\Desktop\jacky_code\jacky_code\";
end
if ~isfield(opts, 'randomRuns') || ~isfinite(opts.randomRuns)
    opts.randomRuns = 30;
end
if ~isfield(opts, 'randomSeed') || ~isfinite(opts.randomSeed)
    opts.randomSeed = 2026;
end
if ~isfield(opts, 'showFigures') || isempty(opts.showFigures)
    opts.showFigures = true;
end

outDir = fullfile(char(string(opts.file_path)), 'Matlab_data');
if ~exist(outDir, 'dir')
    mkdir(outDir);
end

fprintf('\n===== Graph selection comparison (dense scenario) =====\n');
fprintf('Purpose: compare edge-selection rules under identical graphs, capacity, EPFD, users.\n');

scenarioOpts = buildScenarioOptsFromGraphOptsLocal(opts);
scenario = buildDenseGraphScenarioLocal(scenarioOpts);
nClosedAffected = sum(scenario.closedBeamUserMask);
fprintf('Scenario: %d sats, %d users, %d closed-beam affected users, beamCap=%.2f Mbps\n', ...
    scenario.nSat, scenario.nUsers, nClosedAffected, scenario.beamCapacity_Mbps);
fprintf('Plot metrics: closed-beam affected users only (exclude unaffected users).\n');

methodIds = ["proposed_dynamic", "initial_score", "max_user", "random_feasible"];
methodLabels = [ ...
    "Proposed Dynamic-Score Iterative Selection", ...
    "Initial-Score Iterative Selection", ...
    "Max-User Iterative Selection", ...
    "Random Feasible Iterative Selection"];
policies = ["dynamic", "initial", "max_user", "random"];

nMethod = numel(methodIds);
closedPw = nan(nMethod, 1);
closedAvg = nan(nMethod, 1);
closedPwStd = zeros(nMethod, 1);
closedAvgStd = zeros(nMethod, 1);
runtime_s = nan(nMethod, 1);

for m = 1:nMethod - 1
    res = runGraphSelectionPolicyLocal(scenario, policies(m), opts.randomSeed);
    closedPw(m) = res.priorityWeightedClosedBeam;
    closedAvg(m) = res.avgClosedBeamSatisfaction;
    runtime_s(m) = res.runtime_s;
    fprintf('  %s: closedPw=%.4f, closedAvg=%.4f, HBR=%d (%.3fs)\n', ...
        methodLabels(m), closedPw(m), closedAvg(m), res.nHbrActivations, runtime_s(m));
end

nRand = opts.randomRuns;
randClosedPw = nan(nRand, 1);
randClosedAvg = nan(nRand, 1);
for r = 1:nRand
    res = runGraphSelectionPolicyLocal(scenario, 'random', opts.randomSeed + r);
    randClosedPw(r) = res.priorityWeightedClosedBeam;
    randClosedAvg(r) = res.avgClosedBeamSatisfaction;
end
closedPw(nMethod) = mean(randClosedPw, 'omitnan');
closedAvg(nMethod) = mean(randClosedAvg, 'omitnan');
closedPwStd(nMethod) = std(randClosedPw, 'omitnan');
closedAvgStd(nMethod) = std(randClosedAvg, 'omitnan');
runtime_s(nMethod) = mean(runtime_s(1:nMethod-1), 'omitnan');
fprintf('  %s: closedPw=%.4f +/- %.4f, closedAvg=%.4f +/- %.4f (%d runs)\n', ...
    methodLabels(nMethod), closedPw(nMethod), closedPwStd(nMethod), ...
    closedAvg(nMethod), closedAvgStd(nMethod), nRand);

T = table(methodLabels(:), methodIds(:), closedPw, closedAvg, closedPwStd, closedAvgStd, runtime_s, ...
    'VariableNames', {'method_name', 'method_id', 'closed_beam_pw_satisfaction', ...
    'closed_beam_avg_satisfaction', 'closed_beam_pw_std', 'closed_beam_avg_std', 'runtime_s'});

matPath = fullfile(outDir, 'graph_selection_comparison_results.mat');
csvPath = fullfile(outDir, 'graph_selection_comparison_results.csv');
save(matPath, 'T', 'scenario', 'opts', 'randClosedPw', 'randClosedAvg');
writetable(T, csvPath);
fprintf('Saved results: %s\nSaved results: %s\n', matPath, csvPath);

figPwPath = fullfile(outDir, 'fig_priority_weighted_recovery_graph_selection.png');
figAvgPath = fullfile(outDir, 'fig_avg_satisfaction_graph_selection.png');
pwYLabel = sprintf('Closed-beam affected users (N=%d): priority-weighted satisfaction', nClosedAffected);
avgYLabel = sprintf('Closed-beam affected users (N=%d): average satisfaction', nClosedAffected);
plotGraphSelectionBarLocal(methodLabels, closedPw, closedPwStd, ...
    pwYLabel, figPwPath, opts.showFigures, ...
    struct('ylimMode', 'tight', 'highlightFirst', true, 'valueFormat', '%.3f'));
plotGraphSelectionBarLocal(methodLabels, closedAvg, closedAvgStd, ...
    avgYLabel, figAvgPath, opts.showFigures, ...
    struct('ylimMode', 'tight', 'highlightFirst', true, 'valueFormat', '%.3f'));

out = struct();
out.resultsTable = T;
out.scenario = scenario;
out.matPath = matPath;
out.csvPath = csvPath;
out.figPwPath = figPwPath;
out.figAvgPath = figAvgPath;
end

function scenarioOpts = buildScenarioOptsFromGraphOptsLocal(opts)
scenarioOpts = struct();
fields = {'alt_km','nOrbit','nSatPerOrbit','gsLat_deg','orbitLon_deg','gsRelLon_deg', ...
    'gsPlacement','gsAnchorSatIdx','beamHalfEW_deg','beamHalfNS_total_deg', ...
    'fullBeamPower_W','maxBeamPower_W','beamCapacity_Mbps','epfdThr_dB','nUsers','userDemand_Mbps', ...
    'userSeed','prioritySeed','userSpreadLat_deg','userSpreadLon_deg','recoveryPowerPoolMode'};
for k = 1:numel(fields)
    f = fields{k};
    if isfield(opts, f)
        scenarioOpts.(f) = opts.(f);
    end
end
end

function plotGraphSelectionBarLocal(labels, y, yStd, yLabel, figPath, showFig, plotOpts)
if nargin < 6, showFig = true; end
if nargin < 7 || isempty(plotOpts), plotOpts = struct(); end
ylimMode = 'auto';
highlightFirst = true;
valueFormat = '%.3f';
if isfield(plotOpts, 'ylimMode'), ylimMode = plotOpts.ylimMode; end
if isfield(plotOpts, 'highlightFirst'), highlightFirst = plotOpts.highlightFirst; end
if isfield(plotOpts, 'valueFormat'), valueFormat = plotOpts.valueFormat; end

x = 1:numel(labels);
fig = figure('Color', 'w', 'Visible', ternaryGraphLocal(showFig, 'on', 'off'));
ax = axes('Parent', fig);
barColors = repmat([0.2 0.45 0.74], numel(x), 1);
if highlightFirst
    barColors(1, :) = [0.85 0.33 0.10];
end
b = bar(ax, x, y, 0.65);
b.FaceColor = 'flat';
b.CData = barColors;
hold(ax, 'on');
for k = 1:numel(x)
    if yStd(k) > 1e-6
        errorbar(ax, x(k), y(k), yStd(k), 'k', 'LineStyle', 'none', ...
            'LineWidth', 1.2, 'CapSize', 10);
    end
end
yTop = max(y + yStd, [], 'omitnan');
yBot = min(y - yStd, [], 'omitnan');
for k = 1:numel(x)
    text(ax, x(k), y(k), sprintf(valueFormat, y(k)), ...
        'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom', ...
        'FontSize', 8, 'Margin', 1);
end
hold(ax, 'off');
set(ax, 'XTick', x, 'XTickLabel', labels, 'XTickLabelRotation', 18);
ylabel(ax, yLabel);
if strcmpi(ylimMode, 'tight') && any(isfinite(yTop)) && any(isfinite(yBot))
    pad = max(0.008, 0.12 * (yTop - yBot));
    ylim(ax, [max(0, yBot - pad), yTop + pad]);
elseif strcmpi(ylimMode, 'auto') && any(isfinite(yTop))
    ylim(ax, [0, max(yTop) * 1.18 + 0.01]);
else
    ylim(ax, [0 1]);
end
grid(ax, 'on');
box(ax, 'on');
if strlength(string(figPath)) > 0
    saveas(fig, char(string(figPath)));
    fprintf('Saved figure: %s\n', figPath);
end
if ~showFig && isgraphics(fig)
    close(fig);
end
end

function out = ternaryGraphLocal(c, a, b)
if c, out = a; else, out = b; end
end
