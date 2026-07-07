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
fprintf('Scenario: %d sats, %d users, %d SBR edges, %d HBR edges, %d critical sats\n', ...
    scenario.nSat, scenario.nUsers, numel(scenario.sbrEdges), numel(scenario.hbrEdges), ...
    numel(scenario.criticalSatIdx));

methodIds = ["proposed_dynamic", "initial_score", "max_user", "random_feasible"];
methodLabels = [ ...
    "Proposed Dynamic-Score Iterative Selection", ...
    "Initial-Score Iterative Selection", ...
    "Max-User Iterative Selection", ...
    "Random Feasible Iterative Selection"];
policies = ["dynamic", "initial", "max_user", "random"];

nMethod = numel(methodIds);
avgSat = nan(nMethod, 1);
pwRec = nan(nMethod, 1);
avgStd = zeros(nMethod, 1);
pwStd = zeros(nMethod, 1);
runtime_s = nan(nMethod, 1);

for m = 1:nMethod - 1
    res = runGraphSelectionPolicyLocal(scenario, policies(m), opts.randomSeed);
    avgSat(m) = res.avgSatisfaction;
    pwRec(m) = res.priorityWeightedRecovered;
    runtime_s(m) = res.runtime_s;
    fprintf('  %s: avgSat=%.4f, pwRec=%.4f (%.3fs)\n', ...
        methodLabels(m), avgSat(m), pwRec(m), runtime_s(m));
end

% Random: 30 runs with fixed seed stream.
nRand = opts.randomRuns;
randAvg = nan(nRand, 1);
randPw = nan(nRand, 1);
for r = 1:nRand
    res = runGraphSelectionPolicyLocal(scenario, 'random', opts.randomSeed + r);
    randAvg(r) = res.avgSatisfaction;
    randPw(r) = res.priorityWeightedRecovered;
end
avgSat(nMethod) = mean(randAvg, 'omitnan');
pwRec(nMethod) = mean(randPw, 'omitnan');
avgStd(nMethod) = std(randAvg, 'omitnan');
pwStd(nMethod) = std(randPw, 'omitnan');
runtime_s(nMethod) = mean(runtime_s(1:nMethod-1), 'omitnan');
fprintf('  %s: avgSat=%.4f +/- %.4f, pwRec=%.4f +/- %.4f (%d runs)\n', ...
    methodLabels(nMethod), avgSat(nMethod), avgStd(nMethod), pwRec(nMethod), pwStd(nMethod), nRand);

T = table(methodLabels(:), methodIds(:), avgSat, pwRec, avgStd, pwStd, runtime_s, ...
    'VariableNames', {'method_name', 'method_id', 'avg_user_satisfaction', ...
    'priority_weighted_recovered_satisfaction', 'avg_satisfaction_std', ...
    'pw_recovered_std', 'runtime_s'});

matPath = fullfile(outDir, 'graph_selection_comparison_results.mat');
csvPath = fullfile(outDir, 'graph_selection_comparison_results.csv');
save(matPath, 'T', 'scenario', 'opts', 'randAvg', 'randPw');
writetable(T, csvPath);
fprintf('Saved results: %s\nSaved results: %s\n', matPath, csvPath);

figAvgPath = fullfile(outDir, 'fig_avg_satisfaction_graph_selection.png');
figPwPath = fullfile(outDir, 'fig_priority_weighted_recovery_graph_selection.png');
plotGraphSelectionBarLocal(methodLabels, avgSat, avgStd, ...
    'Average user satisfaction', figAvgPath, opts.showFigures);
plotGraphSelectionBarLocal(methodLabels, pwRec, pwStd, ...
    'Priority-weighted recovered satisfaction', figPwPath, opts.showFigures);

% Summary vs Initial-Score baseline.
iProp = 1;
iInit = 2;
if isfinite(avgSat(iInit)) && avgSat(iInit) > 0
    pctAvg = 100 * (avgSat(iProp) - avgSat(iInit)) / avgSat(iInit);
    pctPw = 100 * (pwRec(iProp) - pwRec(iInit)) / max(pwRec(iInit), eps);
    fprintf('Proposed method improves average satisfaction by %.2f%% over Initial-Score Iterative Selection.\n', pctAvg);
    fprintf('Proposed method improves priority-weighted recovered satisfaction by %.2f%% over Initial-Score Iterative Selection.\n', pctPw);
end
fprintf('Random Feasible result is averaged over %d runs (seed=%d).\n', nRand, opts.randomSeed);

out = struct();
out.resultsTable = T;
out.scenario = scenario;
out.matPath = matPath;
out.csvPath = csvPath;
out.figAvgPath = figAvgPath;
out.figPwPath = figPwPath;
end

function scenarioOpts = buildScenarioOptsFromGraphOptsLocal(opts)
scenarioOpts = struct();
fields = {'alt_km','nOrbit','nSatPerOrbit','gsLat_deg','orbitLon_deg','gsRelLon_deg', ...
    'gsPlacement','gsAnchorSatIdx','beamHalfEW_deg','beamHalfNS_total_deg', ...
    'fullBeamPower_W','maxBeamPower_W','beamCapacity_Mbps','epfdThr_dB','nUsers','userDemand_Mbps', ...
    'userSeed','prioritySeed','userSpreadLat_deg','userSpreadLon_deg'};
for k = 1:numel(fields)
    f = fields{k};
    if isfield(opts, f)
        scenarioOpts.(f) = opts.(f);
    end
end
end

function plotGraphSelectionBarLocal(labels, y, yStd, yLabel, figPath, showFig)
if nargin < 6, showFig = true; end
x = 1:numel(labels);
fig = figure('Color', 'w', 'Visible', ternaryGraphLocal(showFig, 'on', 'off'));
ax = axes('Parent', fig);
bar(ax, x, y, 0.65, 'FaceColor', [0.2 0.45 0.74]);
hold(ax, 'on');
errorbar(ax, x, y, yStd, 'k.', 'LineWidth', 1.2, 'CapSize', 8);
hold(ax, 'off');
set(ax, 'XTick', x, 'XTickLabel', labels, 'XTickLabelRotation', 18);
ylabel(ax, yLabel);
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
