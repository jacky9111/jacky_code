function out = RunGraphSelectionComparisonDenseShannonLocal(opts)
% RunGraphSelectionComparisonDenseShannonLocal
% Ch.4 dense graph comparison with Shannon capacity throughout (independent of linear-cap path).

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

fprintf('\n===== Graph selection comparison (dense, Shannon capacity) =====\n');
fprintf('Purpose: compare edge-selection rules under identical graphs, EPFD, users (Shannon B*log2(1+SINR)).\n');

scenarioOpts = buildScenarioOptsFromGraphOptsLocal(opts);
scenario = buildDenseGraphScenarioLocal(scenarioOpts);
nClosedAffected = sum(scenario.closedBeamUserMask);
fprintf('Scenario: %d sats, %d users, %d closed-beam affected users, capacity=Shannon\n', ...
    scenario.nSat, scenario.nUsers, nClosedAffected);
fprintf('Plot metrics: closed-beam affected users only (exclude unaffected users).\n');

figScenarioMapPath = fullfile(outDir, 'fig_graph_scenario_users_sats_shannon.png');
plotDenseGraphScenarioMapLocal(scenario, struct( ...
    'showFigure', opts.showFigures, 'figurePath', figScenarioMapPath));

methodIds = ["proposed_dynamic", "initial_score", "max_user", "random_feasible"];
methodLabels = [ ...
    "Proposed (Dynamic-Score)", ...
    "Initial-Score", ...
    "Max-User", ...
    "Random"];
policies = ["dynamic", "initial", "max_user", "random"];

nMethod = numel(methodIds);
closedPw = nan(nMethod, 1);
closedAvg = nan(nMethod, 1);
pwdRecovery = nan(nMethod, 1);
highPriRatio = nan(nMethod, 1);
unservedHighDemand = nan(nMethod, 1);
closedPwStd = zeros(nMethod, 1);
closedAvgStd = zeros(nMethod, 1);
pwdRecoveryStd = zeros(nMethod, 1);
highPriRatioStd = zeros(nMethod, 1);
unservedHighDemandStd = zeros(nMethod, 1);
runtime_s = nan(nMethod, 1);

for m = 1:nMethod - 1
    res = runGraphSelectionPolicyShannonLocal(scenario, policies(m), opts.randomSeed);
    closedPw(m) = res.priorityWeightedClosedBeam;
    closedAvg(m) = res.avgClosedBeamSatisfaction;
    pwdRecovery(m) = res.priorityWeightedDemandRecovery;
    highPriRatio(m) = res.highPriorityRecoveryRatio;
    unservedHighDemand(m) = res.unservedHighPriorityDemand_Mbps;
    runtime_s(m) = res.runtime_s;
    fprintf('  %s: closedPw=%.4f, closedAvg=%.4f, pwd=%.4f, highRatio=%.4f, unservedHigh=%.1f Mbps, HBR=%d (%.3fs)\n', ...
        methodLabels(m), closedPw(m), closedAvg(m), pwdRecovery(m), highPriRatio(m), ...
        unservedHighDemand(m), res.nHbrActivations, runtime_s(m));
end

nRand = opts.randomRuns;
randClosedPw = nan(nRand, 1);
randClosedAvg = nan(nRand, 1);
randPwdRecovery = nan(nRand, 1);
randHighPriRatio = nan(nRand, 1);
randUnservedHighDemand = nan(nRand, 1);
for r = 1:nRand
    res = runGraphSelectionPolicyShannonLocal(scenario, 'random', opts.randomSeed + r);
    randClosedPw(r) = res.priorityWeightedClosedBeam;
    randClosedAvg(r) = res.avgClosedBeamSatisfaction;
    randPwdRecovery(r) = res.priorityWeightedDemandRecovery;
    randHighPriRatio(r) = res.highPriorityRecoveryRatio;
    randUnservedHighDemand(r) = res.unservedHighPriorityDemand_Mbps;
end
closedPw(nMethod) = mean(randClosedPw, 'omitnan');
closedAvg(nMethod) = mean(randClosedAvg, 'omitnan');
pwdRecovery(nMethod) = mean(randPwdRecovery, 'omitnan');
highPriRatio(nMethod) = mean(randHighPriRatio, 'omitnan');
unservedHighDemand(nMethod) = mean(randUnservedHighDemand, 'omitnan');
closedPwStd(nMethod) = std(randClosedPw, 'omitnan');
closedAvgStd(nMethod) = std(randClosedAvg, 'omitnan');
pwdRecoveryStd(nMethod) = std(randPwdRecovery, 'omitnan');
highPriRatioStd(nMethod) = std(randHighPriRatio, 'omitnan');
unservedHighDemandStd(nMethod) = std(randUnservedHighDemand, 'omitnan');
runtime_s(nMethod) = mean(runtime_s(1:nMethod-1), 'omitnan');
fprintf('  %s: closedPw=%.4f +/- %.4f, closedAvg=%.4f +/- %.4f, pwd=%.4f +/- %.4f, highRatio=%.4f +/- %.4f, unservedHigh=%.1f +/- %.1f Mbps (%d runs)\n', ...
    methodLabels(nMethod), closedPw(nMethod), closedPwStd(nMethod), ...
    closedAvg(nMethod), closedAvgStd(nMethod), pwdRecovery(nMethod), pwdRecoveryStd(nMethod), ...
    highPriRatio(nMethod), highPriRatioStd(nMethod), ...
    unservedHighDemand(nMethod), unservedHighDemandStd(nMethod), nRand);

T = table(methodLabels(:), methodIds(:), closedPw, closedAvg, pwdRecovery, highPriRatio, ...
    unservedHighDemand, closedPwStd, closedAvgStd, pwdRecoveryStd, highPriRatioStd, ...
    unservedHighDemandStd, runtime_s, ...
    'VariableNames', {'method_name', 'method_id', 'closed_beam_pw_satisfaction', ...
    'closed_beam_avg_satisfaction', 'priority_weighted_demand_recovery', ...
    'high_priority_recovery_ratio', 'unserved_high_priority_demand_Mbps', ...
    'closed_beam_pw_std', 'closed_beam_avg_std', 'priority_weighted_demand_recovery_std', ...
    'high_priority_recovery_ratio_std', 'unserved_high_priority_demand_std_Mbps', 'runtime_s'});

matPath = fullfile(outDir, 'graph_selection_comparison_shannon_results.mat');
csvPath = fullfile(outDir, 'graph_selection_comparison_shannon_results.csv');
save(matPath, 'T', 'scenario', 'opts', 'randClosedPw', 'randClosedAvg', ...
    'randPwdRecovery', 'randHighPriRatio', 'randUnservedHighDemand');
writetable(T, csvPath);
fprintf('Saved results: %s\nSaved results: %s\n', matPath, csvPath);

figPwPath = fullfile(outDir, 'fig_priority_weighted_recovery_graph_selection_shannon.png');
figAvgPath = fullfile(outDir, 'fig_avg_satisfaction_graph_selection_shannon.png');
figPwdPath = fullfile(outDir, 'fig_priority_weighted_demand_recovery_graph_selection_shannon.png');
figHighRatioPath = fullfile(outDir, 'fig_high_priority_recovery_ratio_graph_selection_shannon.png');
figUnservedHighPath = fullfile(outDir, 'fig_unserved_high_priority_demand_graph_selection_shannon.png');
pwYLabel = sprintf('Closed-beam affected users (N=%d): priority-weighted satisfaction', nClosedAffected);
avgYLabel = sprintf('Closed-beam affected users (N=%d): average satisfaction', nClosedAffected);
pwdYLabel = sprintf('Closed-beam affected users (N=%d): priority-weighted demand recovery', nClosedAffected);
highRatioYLabel = sprintf('High-priority closed users: recovery ratio (s >= %.1f)', ...
    scenario.highPriorityRecoveryThreshold);
unservedHighYLabel = 'High-priority closed users: unserved demand (Mbps)';
plotGraphSelectionBarLocal(methodLabels, closedPw, closedPwStd, ...
    pwYLabel, figPwPath, opts.showFigures, ...
    struct('ylimMode', 'unit', 'highlightFirst', true, 'valueFormat', '%.3f'));
plotGraphSelectionBarLocal(methodLabels, closedAvg, closedAvgStd, ...
    avgYLabel, figAvgPath, opts.showFigures, ...
    struct('ylimMode', 'unit', 'highlightFirst', true, 'valueFormat', '%.3f'));
plotGraphSelectionBarLocal(methodLabels, pwdRecovery, pwdRecoveryStd, ...
    pwdYLabel, figPwdPath, opts.showFigures, ...
    struct('ylimMode', 'unit', 'highlightFirst', true, 'valueFormat', '%.3f'));
plotGraphSelectionBarLocal(methodLabels, highPriRatio, highPriRatioStd, ...
    highRatioYLabel, figHighRatioPath, opts.showFigures, ...
    struct('ylimMode', 'unit', 'highlightFirst', true, 'valueFormat', '%.3f'));
plotGraphSelectionBarLocal(methodLabels, unservedHighDemand, unservedHighDemandStd, ...
    unservedHighYLabel, figUnservedHighPath, opts.showFigures, ...
    struct('ylimMode', 'auto', 'highlightFirst', true, 'valueFormat', '%.1f'));

out = struct();
out.resultsTable = T;
out.scenario = scenario;
out.matPath = matPath;
out.csvPath = csvPath;
out.figPwPath = figPwPath;
out.figAvgPath = figAvgPath;
out.figPwdPath = figPwdPath;
out.figHighRatioPath = figHighRatioPath;
out.figUnservedHighPath = figUnservedHighPath;
out.figScenarioMapPath = figScenarioMapPath;
end

function scenarioOpts = buildScenarioOptsFromGraphOptsLocal(opts)
scenarioOpts = struct();
fields = {'alt_km','nOrbit','nSatPerOrbit','satSpacingMode','starlinkDensityTotalSats', ...
    'gsLat_deg','orbitLon_deg','gsRelLon_deg', ...
    'gsPlacement','gsAnchorSatIdx','beamHalfEW_deg','beamHalfNS_total_deg', ...
    'fullBeamPower_W','maxBeamPower_W','beamCapacity_Mbps','epfdThr_dB','nUsers', ...
    'userDemandMode','userDemandMin_Mbps','userDemandMax_Mbps','userDemandSeed', ...
    'highPriorityRecoveryThreshold', ...
    'userDemandLow_Mbps','userDemandMed_Mbps','userDemandHigh_Mbps', ...
    'userSeed','prioritySeed','userPlacementMode','userPlacementNearestSatCount', ...
    'userSpreadLat_deg','userSpreadLon_deg','recoveryPowerPoolMode'};
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
if strcmpi(ylimMode, 'unit')
    ylim(ax, [0 1]);
elseif strcmpi(ylimMode, 'tight') && any(isfinite(yTop)) && any(isfinite(yBot))
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
