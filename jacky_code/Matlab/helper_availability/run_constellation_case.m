function caseResult = run_constellation_case(constellation, common)
% run_constellation_case
% Run the full helper-availability pipeline for ONE constellation-like
% geometry over the common time grid:
%   generate geometry -> align reference over GS -> propagate ->
%   per slot: visibility -> beam footprints -> aggregate EPFD & beam
%   shutdown (critical satellites) -> recovery-capable helper identification
%   -> accumulate metrics and diagnostic time series.
%
% Inputs:
%   constellation : one entry of cfg.constellations
%   common        : cfg.common
%
% Output caseResult:
%   .name, .isExampleGeometry, .alignInfo
%   .metrics        : compute_helper_availability_metrics output
%   .acc            : accumulated counters
%   .timeSeries     : per-slot diagnostic vectors
%   .criticalRecord : 1 x nT struct array, .satellites per slot (raw record)
%
% Units: km, deg, W, linear EPFD (dB only for time-series output fields).

beam = common.beam;
P = common.params;

% Geometry and alignment.
geom = generate_constellation_geometry(constellation, common);
[geom, alignInfo] = align_reference_satellite_over_gs(geom, common);
satNames = string({geom.sats.name}.');

% Time grid.
t_s = common.tStart_s : common.tStep_s : common.tEnd_s;
nT = numel(t_s);
state = propagate_satellites(geom, common, t_s);

% Fixed ECEF ground station and reference GSO (same longitude as GS).
P_gs_km = common.Re_km * [cosd(common.gsLat_deg) * cosd(common.gsLon_deg); ...
                          cosd(common.gsLat_deg) * sind(common.gsLon_deg); ...
                          sind(common.gsLat_deg)];
P_geo_km = common.Rgeo_km * [cosd(common.gsoLon_deg); sind(common.gsoLon_deg); 0];

% Accumulators for the four summary metrics.
acc = struct('criticalSlotsCount', 0, 'sumCriticalSatsCriticalSlot', 0, ...
    'totalCriticalInstances', 0, 'sumHelpersOverInstances', 0, ...
    'zeroHelperInstances', 0, 'totalClosedBeamInstances', 0, ...
    'closedBeamWithHelper', 0);

% Diagnostic time series.
ts = struct();
ts.t_s                    = t_s;
ts.nCriticalSats          = zeros(1, nT);
ts.avgHelpersPerCritical  = nan(1, nT);
ts.closedBeamCoveragePct  = nan(1, nT);
ts.aggEpfdBefore_dB       = nan(1, nT);
ts.aggEpfdAfter_dB        = nan(1, nT);
ts.nClosedBeams           = zeros(1, nT);

criticalRecord = repmat(struct('t_s', 0, 'satellites', []), 1, nT);

for it = 1:nT
    pos_all = state.pos_ecef_km(:, :, it);
    vel_all = state.vel_ecef_kmps(:, :, it);

    vis = get_visible_satellites(pos_all, P_gs_km, common.minElev_deg);
    criticalRecord(it).t_s = t_s(it);

    if isempty(vis.idx)
        criticalRecord(it).satellites = [];
        continue;
    end

    visIdx = vis.idx;
    nVis = numel(visIdx);
    pos_vis = pos_all(:, visIdx);
    fpCell = cell(1, nVis);
    boresights_vis = cell(1, nVis);
    for i = 1:nVis
        gi = visIdx(i);
        fp = generate_beam_footprints(pos_all(:, gi), vel_all(:, gi), beam, common.Re_km);
        fpCell{i} = fp;
        boresights_vis{i} = [fp.boresight];
    end

    slot = identify_critical_satellites(visIdx, pos_vis, boresights_vis, ...
        P_gs_km, P_geo_km, P, beam, common.epfdThr_dB);
    slotHelper = identify_recovery_helpers(slot, fpCell, satNames, common);

    % ---- Accumulate metric counters ----
    nCrit = slotHelper.nCriticalSats;
    if nCrit > 0
        acc.criticalSlotsCount = acc.criticalSlotsCount + 1;
        acc.sumCriticalSatsCriticalSlot = acc.sumCriticalSatsCriticalSlot + nCrit;
        acc.totalCriticalInstances = acc.totalCriticalInstances + nCrit;
        acc.sumHelpersOverInstances = acc.sumHelpersOverInstances + sum(slotHelper.instanceNumHelpers);
        acc.zeroHelperInstances = acc.zeroHelperInstances + sum(slotHelper.instanceZeroHelper);
    end
    acc.totalClosedBeamInstances = acc.totalClosedBeamInstances + slotHelper.nClosedBeamInstances;
    acc.closedBeamWithHelper = acc.closedBeamWithHelper + slotHelper.nClosedBeamWithHelper;

    % ---- Diagnostic time series ----
    ts.nCriticalSats(it) = nCrit;
    ts.nClosedBeams(it)  = slot.nShut;
    ts.aggEpfdBefore_dB(it) = 10 * log10(max(slot.aggBefore_lin, 1e-300));
    ts.aggEpfdAfter_dB(it)  = 10 * log10(max(slot.aggAfter_lin, 1e-300));
    if nCrit > 0
        ts.avgHelpersPerCritical(it) = mean(slotHelper.instanceNumHelpers);
    end
    if slotHelper.nClosedBeamInstances > 0
        ts.closedBeamCoveragePct(it) = ...
            100 * slotHelper.nClosedBeamWithHelper / slotHelper.nClosedBeamInstances;
    end

    criticalRecord(it).satellites = slotHelper.satellites;
end

metrics = compute_helper_availability_metrics(acc);

caseResult = struct();
caseResult.name              = geom.name;
caseResult.isExampleGeometry = geom.isExampleGeometry;
caseResult.alignInfo         = alignInfo;
caseResult.metrics           = metrics;
caseResult.acc               = acc;
caseResult.timeSeries        = ts;
caseResult.criticalRecord    = criticalRecord;
caseResult.geomSummary       = struct('nSat', geom.nSat, 'nShell', geom.nShell, ...
    'shells', geom.shells);
end
