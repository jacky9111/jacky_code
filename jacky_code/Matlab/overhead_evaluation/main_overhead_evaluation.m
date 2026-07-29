function out = main_overhead_evaluation(cfg)
%MAIN_OVERHEAD_EVALUATION Compare PC+Tilt and EABR online execution time.
% Pure MATLAB (no STK). For each user load:
%   - find worst GS EPFD time near the flyover
%   - measure online runtime once per 1-s slot in a 60-s window (±30 s)
%   - bar = mean over slots; I = min–max over slots
%
% Usage:
%   overheadResults = main_overhead_evaluation();

if nargin < 1 || isempty(cfg)
    cfg = overhead_config();
end
if ~exist(cfg.resultsDir, 'dir')
    mkdir(cfg.resultsDir);
end
addpath(cfg.moduleDir);
addpath(fullfile(cfg.matlabDir, 'jacky'));
addpath(fullfile(cfg.matlabDir, 'powertilt'));
addpath(fullfile(cfg.matlabDir, 'helper_availability'));

if exist('runGraphSelectionPolicyLocal', 'file') ~= 2
    error('main_overhead_evaluation:MissingEABR', ...
        'Existing EABR function runGraphSelectionPolicyLocal.m was not found.');
end
if exist('run_pc_tilt_online_existing_logic', 'file') ~= 2
    error('main_overhead_evaluation:MissingPcTilt', ...
        'PC+Tilt function run_pc_tilt_online_existing_logic.m was not found.');
end

nLoad = numel(cfg.userLoads);
pcTiltMeasurements = repmat(emptyMeasurementLocal(), nLoad, 1);
eabrMeasurements = repmat(emptyMeasurementLocal(), nLoad, 1);
caseMetadata = repmat(struct(), nLoad, 1);
nExpectedSlots = numel((-cfg.slotHalfWindow_s):cfg.slotStep_s:(cfg.slotHalfWindow_s - cfg.slotStep_s));

fprintf('\n===== Computational overhead: PC+Tilt vs EABR (MATLAB-only) =====\n');
fprintf('Window = ±%d s around worst GS EPFD (%d x %d-s slots)\n', ...
    cfg.slotHalfWindow_s, nExpectedSlots, cfg.slotStep_s);
fprintf('Warm-up on first slot only = %d\n', cfg.warmupRuns);
fprintf('Geometry: OneWeb-like Walker, local %d sats around GS=(%.1f, %.1f)\n', ...
    cfg.nLocalSats, cfg.gsLat_deg, cfg.gsLon_deg);

for iLoad = 1:nLoad
    userLoad = cfg.userLoads(iLoad);
    fprintf('\nPreparing worst-EPFD flyover window for user load %d...\n', userLoad);
    caseData = prepare_overhead_case(cfg, userLoad);
    nSlot = numel(caseData.eabrScenarios);
    fprintf('  Measuring %d slots (t_worst=%d s, window [%d,%d] s)...\n', ...
        nSlot, caseData.tWorst_s, caseData.tSlots_s(1), caseData.tSlots_s(end));

    fprintf('Measuring PC+Tilt (reproduced) over slots...\n');
    pcTiltMeasurements(iLoad) = measure_pc_tilt_runtime(caseData.pcTiltScenarios, cfg);
    fprintf('Measuring EABR over slots...\n');
    eabrMeasurements(iLoad) = measure_eabr_runtime(caseData.eabrScenarios, cfg);

    caseMetadata(iLoad).userLoad = userLoad;
    caseMetadata(iLoad).actualUserCount = caseData.eabrScenarios{1}.nUsers;
    caseMetadata(iLoad).criticalSlot = caseData.criticalSlot;
    caseMetadata(iLoad).criticalSatellite = caseData.criticalSatellite;
    caseMetadata(iLoad).tWorst_s = caseData.tWorst_s;
    caseMetadata(iLoad).tSlots_s = caseData.tSlots_s;
    caseMetadata(iLoad).tRel_s = caseData.tRel_s;
    caseMetadata(iLoad).slotMeta = caseData.slotMeta;
    caseMetadata(iLoad).epfdSearch = caseData.epfdSearch;
    caseMetadata(iLoad).nSlots = nSlot;
    caseMetadata(iLoad).closedBeamAffectedUsers = ...
        arrayfun(@(m) m.nClosedUsers, caseData.slotMeta);
    caseMetadata(iLoad).sbrCandidateEdges = ...
        arrayfun(@(m) m.nSbrEdges, caseData.slotMeta);
    caseMetadata(iLoad).hbrCandidateEdges = ...
        arrayfun(@(m) m.nHbrEdges, caseData.slotMeta);

    fprintf(['  PC+Tilt min/avg/max = %.3f / %.3f / %.3f ms; ' ...
        'EABR min/avg/max = %.3f / %.3f / %.3f ms  (over %d slots)\n'], ...
        pcTiltMeasurements(iLoad).minimumRuntimeMs, ...
        pcTiltMeasurements(iLoad).averageRuntimeMs, ...
        pcTiltMeasurements(iLoad).maximumRuntimeMs, ...
        eabrMeasurements(iLoad).minimumRuntimeMs, ...
        eabrMeasurements(iLoad).averageRuntimeMs, ...
        eabrMeasurements(iLoad).maximumRuntimeMs, ...
        nSlot);
    if eabrMeasurements(iLoad).maximumRuntimeMs > 1000
        warning('main_overhead_evaluation:EABRRuntime', ...
            'EABR maximum runtime at user load %d is %.3f ms (> 1000 ms).', ...
            userLoad, eabrMeasurements(iLoad).maximumRuntimeMs);
    else
        fprintf('  EABR maximum runtime check: %.3f ms < 1000 ms.\n', ...
            eabrMeasurements(iLoad).maximumRuntimeMs);
    end
    if pcTiltMeasurements(iLoad).minimumRuntimeMs > 1000
        fprintf('  PC+Tilt: all %d slots exceed 1000 ms (min = %.3f ms).\n', ...
            nSlot, pcTiltMeasurements(iLoad).minimumRuntimeMs);
    end
end

summaryTable = table(cfg.userLoads(:), ...
    arrayfun(@(x) x.minimumRuntimeMs, pcTiltMeasurements), ...
    arrayfun(@(x) x.averageRuntimeMs, pcTiltMeasurements), ...
    arrayfun(@(x) x.maximumRuntimeMs, pcTiltMeasurements), ...
    arrayfun(@(x) x.stdRuntimeMs, pcTiltMeasurements), ...
    arrayfun(@(x) x.minimumRuntimeMs, eabrMeasurements), ...
    arrayfun(@(x) x.averageRuntimeMs, eabrMeasurements), ...
    arrayfun(@(x) x.maximumRuntimeMs, eabrMeasurements), ...
    arrayfun(@(x) x.stdRuntimeMs, eabrMeasurements), ...
    'VariableNames', {'UserLoad', ...
    'PcTiltMinimumRuntimeMs','PcTiltAverageRuntimeMs','PcTiltMaximumRuntimeMs', ...
    'PcTiltStdRuntimeMs', ...
    'EABRMinimumRuntimeMs','EABRAverageRuntimeMs','EABRMaximumRuntimeMs', ...
    'EABRStdRuntimeMs'});

rawRuntime = struct();
rawRuntime.userLoads = cfg.userLoads;
rawRuntime.pcTiltRuntimeMs = {pcTiltMeasurements.rawRuntimeMs};
rawRuntime.eabrRuntimeMs = {eabrMeasurements.rawRuntimeMs};
rawRuntime.caseMetadata = caseMetadata;
rawRuntime.warmupRuns = cfg.warmupRuns;
rawRuntime.nSlots = nExpectedSlots;
rawRuntime.slotHalfWindow_s = cfg.slotHalfWindow_s;
rawRuntime.randomSeed = cfg.randomSeed;

writetable(summaryTable, cfg.summaryCsvPath);
save(cfg.rawMatPath, 'rawRuntime', 'summaryTable', 'cfg');
figurePaths = plot_overhead_result(summaryTable, cfg);

out = struct();
out.summaryTable = summaryTable;
out.rawRuntime = rawRuntime;
out.summaryCsvPath = cfg.summaryCsvPath;
out.rawMatPath = cfg.rawMatPath;
out.figurePaths = figurePaths;
out.reusedFunctions = [ ...
    "run_pc_tilt_online_existing_logic (reproduced PC+Tilt)", ...
    "runGraphSelectionPolicyLocal (EABR: SBR + power allocation + HBR)", ...
    "helper_availability Walker geometry (generate/align/propagate)", ...
    "graphRecoverySharedLocal", ...
    "gso_rx_gain_itu1428"];

fprintf('\nOverhead outputs saved in: %s\n', cfg.resultsDir);
end

function m = emptyMeasurementLocal()
m = struct('rawRuntimeMs',zeros(0,1), 'averageRuntimeMs',NaN, ...
    'minimumRuntimeMs',NaN, 'maximumRuntimeMs',NaN, ...
    'rawMinimumRuntimeMs',NaN, 'rawMaximumRuntimeMs',NaN, ...
    'stdRuntimeMs',NaN, 'nSlots',0, 'lastDecision',struct(), ...
    'rangePercentiles',[10, 90]);
end
