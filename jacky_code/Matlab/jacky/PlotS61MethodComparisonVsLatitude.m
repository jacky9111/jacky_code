function Tplot = PlotS61MethodComparisonVsLatitude(root, opts)
% PlotS61MethodComparisonVsLatitude
% Compare average satisfaction of the original P01_S61 user cohort while
% the satellite passes the latitude-0 GS. The baseline curve is forced to
% zero whenever aggregate EPFD exceeds the limit, matching the "beam shutoff"
% interpretation requested for the no-control method.

if nargin < 2 || isempty(opts)
    opts = struct();
end

if ~isfield(opts, 'targetSatelliteId') || isempty(opts.targetSatelliteId)
    opts.targetSatelliteId = "P01_S61";
end
targetSatelliteId = string(opts.targetSatelliteId);

if ~isfield(opts, 'baselineExcelPath') || isempty(opts.baselineExcelPath)
    error('opts.baselineExcelPath is required');
end
if ~isfield(opts, 'pcExcelPath') || isempty(opts.pcExcelPath)
    error('opts.pcExcelPath is required');
end
if ~isfield(opts, 'tiltExcelPath') || isempty(opts.tiltExcelPath)
    error('opts.tiltExcelPath is required');
end
if ~isfield(opts, 'relayExcelPath') || isempty(opts.relayExcelPath)
    error('opts.relayExcelPath is required');
end

if ~isfield(opts, 'figurePath') || isempty(opts.figurePath)
    opts.figurePath = fullfile(pwd, 'Matlab_data', 'LEO16_Ku_MethodComparison_S61_GS0.png');
end
if ~isfield(opts, 'tablePath') || isempty(opts.tablePath)
    opts.tablePath = fullfile(pwd, 'Matlab_data', 'LEO16_Ku_MethodComparison_S61_GS0.xlsx');
end
if ~isfield(opts, 'latitudeWindowDeg') || ~isfinite(opts.latitudeWindowDeg)
    opts.latitudeWindowDeg = 5;
end
latitudeWindowDeg = abs(double(opts.latitudeWindowDeg));

methodDefs = { ...
    struct('name',"Baseline (forced off on EPFD exceed)", 'shortName',"baseline", 'excelPath', string(opts.baselineExcelPath), 'forceZeroOnExceed', true), ...
    struct('name',"PC", 'shortName',"pc", 'excelPath', string(opts.pcExcelPath), 'forceZeroOnExceed', false), ...
    struct('name',"PC + Tilt", 'shortName',"pc_tilt", 'excelPath', string(opts.tiltExcelPath), 'forceZeroOnExceed', false), ...
    struct('name',"PC + Relay", 'shortName',"pc_relay", 'excelPath', string(opts.relayExcelPath), 'forceZeroOnExceed', false)};

methodData = cell(numel(methodDefs), 1);
masterTimes = strings(0,1);
for k = 1:numel(methodDefs)
    methodData{k} = loadMethodCurve(methodDefs{k}.excelPath, targetSatelliteId, methodDefs{k}.forceZeroOnExceed);
    if isempty(masterTimes)
        masterTimes = methodData{k}.times;
    end
end

lat_deg = satelliteLatitudesAtTimes(root, targetSatelliteId, masterTimes);
curveMat = nan(numel(masterTimes), numel(methodDefs));
worstMat = nan(numel(masterTimes), numel(methodDefs));
globalMat = nan(numel(masterTimes), numel(methodDefs));
for k = 1:numel(methodDefs)
    curveMat(:,k) = alignCurve(masterTimes, methodData{k}.times, methodData{k}.avgSat);
    worstMat(:,k) = alignCurve(masterTimes, methodData{k}.times, methodData{k}.worstSat);
    globalMat(:,k) = alignCurve(masterTimes, methodData{k}.times, methodData{k}.globalSumSat);
end

[latSorted, ord] = sort(lat_deg, 'ascend');
timeSorted = masterTimes(ord);
curveSorted = curveMat(ord,:);
worstSorted = worstMat(ord,:);
globalSorted = globalMat(ord,:);

latMask = abs(latSorted) <= latitudeWindowDeg + 1e-12;
latSorted = latSorted(latMask);
timeSorted = timeSorted(latMask);
curveSorted = curveSorted(latMask, :);
worstSorted = worstSorted(latMask, :);
globalSorted = globalSorted(latMask, :);

Tplot = table(timeSorted, latSorted, ...
    curveSorted(:,1)*100, curveSorted(:,2)*100, curveSorted(:,3)*100, curveSorted(:,4)*100, ...
    worstSorted(:,1)*100, worstSorted(:,2)*100, worstSorted(:,3)*100, worstSorted(:,4)*100, ...
    globalSorted(:,1), globalSorted(:,2), globalSorted(:,3), globalSorted(:,4), ...
    'VariableNames', {'time','s61_latitude_deg', ...
    'baseline_avg_satisfaction_pct','pc_avg_satisfaction_pct','pc_tilt_avg_satisfaction_pct','pc_relay_avg_satisfaction_pct', ...
    'baseline_worst_satisfaction_pct','pc_worst_satisfaction_pct','pc_tilt_worst_satisfaction_pct','pc_relay_worst_satisfaction_pct', ...
    'baseline_global_sum_satisfaction','pc_global_sum_satisfaction','pc_tilt_global_sum_satisfaction','pc_relay_global_sum_satisfaction'});

fig = figure('Name', 'S61 Method Comparison', 'Color', 'w');
plot(latSorted, curveSorted(:,1)*100, '-k', 'LineWidth', 1.8); hold on;
plot(latSorted, curveSorted(:,2)*100, '-', 'Color', [0.85 0.33 0.10], 'LineWidth', 1.8);
plot(latSorted, curveSorted(:,3)*100, '-', 'Color', [0 0.45 0.74], 'LineWidth', 1.8);
plot(latSorted, curveSorted(:,4)*100, '-', 'Color', [0.47 0.67 0.19], 'LineWidth', 1.8);
grid on;
xlabel('LEO Satellite Latitude (deg)');
ylabel('Average User Satisfaction (%)');
title(sprintf('(d) Method comparison for %s over latitude-0 GS', targetSatelliteId));
legend({methodDefs{1}.name, methodDefs{2}.name, methodDefs{3}.name, methodDefs{4}.name}, 'Location', 'best');
ylim([0, 100]);
xlim([-latitudeWindowDeg, latitudeWindowDeg]);

fig2 = figure('Name', 'S61 Worst-User Comparison', 'Color', 'w');
plot(latSorted, worstSorted(:,1)*100, '-k', 'LineWidth', 1.8); hold on;
plot(latSorted, worstSorted(:,2)*100, '-', 'Color', [0.85 0.33 0.10], 'LineWidth', 1.8);
plot(latSorted, worstSorted(:,3)*100, '-', 'Color', [0 0.45 0.74], 'LineWidth', 1.8);
plot(latSorted, worstSorted(:,4)*100, '-', 'Color', [0.47 0.67 0.19], 'LineWidth', 1.8);
grid on;
xlabel('LEO Satellite Latitude (deg)');
ylabel('Worst User Satisfaction (%)');
title(sprintf('Worst-user comparison for %s over latitude-0 GS', targetSatelliteId));
legend({methodDefs{1}.name, methodDefs{2}.name, methodDefs{3}.name, methodDefs{4}.name}, 'Location', 'best');
ylim([0, 100]);
xlim([-latitudeWindowDeg, latitudeWindowDeg]);

fig3 = figure('Name', 'Global Satisfaction Comparison', 'Color', 'w');
plot(latSorted, globalSorted(:,1), '-k', 'LineWidth', 1.8); hold on;
plot(latSorted, globalSorted(:,2), '-', 'Color', [0.85 0.33 0.10], 'LineWidth', 1.8);
plot(latSorted, globalSorted(:,3), '-', 'Color', [0 0.45 0.74], 'LineWidth', 1.8);
plot(latSorted, globalSorted(:,4), '-', 'Color', [0.47 0.67 0.19], 'LineWidth', 1.8);
grid on;
xlabel('LEO Satellite Latitude (deg)');
ylabel('Global Sum Satisfaction');
title(sprintf('Global satisfaction comparison for %s over latitude-0 GS', targetSatelliteId));
legend({methodDefs{1}.name, methodDefs{2}.name, methodDefs{3}.name, methodDefs{4}.name}, 'Location', 'best');
xlim([-latitudeWindowDeg, latitudeWindowDeg]);

figDir = fileparts(char(string(opts.figurePath)));
if ~isempty(figDir) && ~exist(figDir, 'dir')
    mkdir(figDir);
end
tblDir = fileparts(char(string(opts.tablePath)));
if ~isempty(tblDir) && ~exist(tblDir, 'dir')
    mkdir(tblDir);
end

saveas(fig, char(string(opts.figurePath)));
saveas(fig2, replace(char(string(opts.figurePath)), '.png', '_WorstUser.png'));
saveas(fig3, replace(char(string(opts.figurePath)), '.png', '_GlobalSum.png'));
writetable(Tplot, char(string(opts.tablePath)), 'Sheet', 'S61_Method_Comparison');
fprintf('Saved figure: %s\n', char(string(opts.figurePath)));
fprintf('Saved figure: %s\n', replace(char(string(opts.figurePath)), '.png', '_WorstUser.png'));
fprintf('Saved figure: %s\n', replace(char(string(opts.figurePath)), '.png', '_GlobalSum.png'));
fprintf('Saved table: %s\n', char(string(opts.tablePath)));
end

function S = loadMethodCurve(excelPath, targetSatelliteId, forceZeroOnExceed)
if ~isfile(excelPath)
    error('Excel file not found: %s', char(excelPath));
end

Tuser = readtable(excelPath, 'Sheet', 'PerUser', 'TextType', 'string');
Tglobal = readtable(excelPath, 'Sheet', 'Global', 'TextType', 'string');

if ismember('original_serving_satellite', Tuser.Properties.VariableNames)
    cohortMask = string(Tuser.original_serving_satellite) == targetSatelliteId;
else
    cohortMask = startsWith(string(Tuser.user_id), targetSatelliteId + "_");
end

timesUser = normalizeTimeStrings(Tuser.time);
[G, timeKeys] = findgroups(timesUser(cohortMask));
avgSat = splitapply(@mean, double(Tuser.satisfaction(cohortMask)), G);
worstSat = splitapply(@min, double(Tuser.satisfaction(cohortMask)), G);

timesGlobal = normalizeTimeStrings(Tglobal.time);
epfdExceed = double(Tglobal.aggregate_EPFD) > double(Tglobal.EPFD_threshold) + 1e-12;
avgSatAligned = avgSat;
worstSatAligned = worstSat;
if forceZeroOnExceed
    for i = 1:numel(timeKeys)
        idxg = find(timesGlobal == timeKeys(i), 1);
        if ~isempty(idxg) && epfdExceed(idxg)
            avgSatAligned(i) = 0;
            worstSatAligned(i) = 0;
        end
    end
end

globalSumSat = nan(numel(timeKeys), 1);
if ismember('sum_user_satisfaction', Tglobal.Properties.VariableNames)
    globalVals = double(Tglobal.sum_user_satisfaction);
    for i = 1:numel(timeKeys)
        idxg = find(timesGlobal == timeKeys(i), 1);
        if ~isempty(idxg)
            globalSumSat(i) = globalVals(idxg);
        end
    end
end

S = struct('times', timeKeys, 'avgSat', avgSatAligned, 'worstSat', worstSatAligned, 'globalSumSat', globalSumSat);
end

function yAligned = alignCurve(masterTimes, curveTimes, curveVals)
yAligned = nan(numel(masterTimes), 1);
for i = 1:numel(masterTimes)
    idx = find(curveTimes == masterTimes(i), 1);
    if ~isempty(idx)
        yAligned(i) = curveVals(idx);
    end
end
end

function timeStr = normalizeTimeStrings(timeCol)
if iscell(timeCol)
    timeStr = string(timeCol);
elseif isstring(timeCol)
    timeStr = timeCol;
elseif isdatetime(timeCol)
    timeStr = string(timeCol, 'dd MMM yyyy HH:mm:ss');
else
    timeStr = string(timeCol);
end
timeStr = strtrim(timeStr);
end

function lat_deg = satelliteLatitudesAtTimes(root, satName, timeList)
sat = root.GetObjectFromPath(['*/Satellite/' char(satName)]);
dp = sat.DataProviders.Item('Cartesian Position').Group.Item('Fixed');
lat_deg = nan(numel(timeList), 1);
for i = 1:numel(timeList)
    xyz = stkXYZ(dp, char(timeList(i)));
    lat_deg(i) = asind(xyz(3) / max(norm(xyz), eps));
end
end

function P = stkXYZ(dpFixed, tStr)
res = dpFixed.ExecSingle(tStr);
P = xyzFromArray(res.DataSets.ToArray);
end

function P = xyzFromArray(arr)
if isnumeric(arr)
    P = double(arr(1:3));
    return;
end
vals = [];
for k = 1:numel(arr)
    a = arr{k};
    if isnumeric(a) && isscalar(a)
        vals(end+1,1) = double(a); %#ok<AGROW>
    elseif ischar(a) || isstring(a)
        n = str2double(a);
        if ~isnan(n)
            vals(end+1,1) = n; %#ok<AGROW>
        end
    end
end
if numel(vals) < 3
    error('cannot parse XYZ');
end
P = vals(1:3);
end
