function [TbeamContributionLog, TbackoffLog, TavgUserSatisfaction, TrelayAssignment, TrelayHomeToHelper] = RunFullPowerAggregateShutdownSweepExcel(root, opts)
% RunFullPowerAggregateShutdownSweepExcel
% Per time slot: (1) reassign users to nearest subpoint + covering beam, (2) EPFD
% backoff until legal, (3) relay & satisfaction. Relay uses post-backoff beam states.
% Per slot (when relay on): (a) swap if middle ON beam covers user and sat>=floor,
% (b) move spare to helper beams that cover distressed users on middle SHUT beams,
% (c) relay with boosted power. relayPowerShiftMode:
%     'overlapCapped' — overlap donors only, cap at maxBeamPower_W;
%     'helperSatPoolUnlimited' — all helper open-beam spare (allocate minus native x1,
%       excluding sat=1 surplus) pooled to relay beams, no power cap.
% Excel averages by per-slot home assignment (userSatIdx); relayed users remain
% in that slot's home satellite cohort.
% Users may be read from STK facilities or generated in MATLAB (useSimulatedUsers).

if nargin < 2 || isempty(opts)
    opts = struct();
end
opts = applyDefaults(root, opts);

sc = root.CurrentScenario;
here = fileparts(mfilename('fullpath'));
addpath(fullfile(here, '..', 'powertilt'));

tStart = datenum(char(string(opts.tStartStr)));
tEnd = datenum(char(string(opts.tEndStr)));
step = double(opts.stepSec) / 86400;
satList = string(opts.satList(:));
geoList = string(opts.geoList(:));
gsName = char(string(opts.gsName));
timeGrid = tStart:step:tEnd;
numSlots = numel(timeGrid);

gsLat_deg = double(opts.gsLat_deg);
gsLon_deg = double(opts.gsLon_deg);
gsAlt_km = double(opts.gsAlt_km);
P_gs_km = groundXYZFromLatLonLocal(gsLat_deg, gsLon_deg, gsAlt_km);

if opts.verbose
    fprintf('Full-power shutdown sweep start\n');
    fprintf('  GS           : %s\n', gsName);
    fprintf('  GS lat/lon   : %.3f deg, %.3f deg\n', gsLat_deg, gsLon_deg);
    fprintf('  Time range   : %s -> %s\n', char(string(opts.tStartStr)), char(string(opts.tEndStr)));
    fprintf('  Step seconds : %.0f\n', double(opts.stepSec));
    fprintf('  Slot count   : %d\n', numSlots);
    if opts.params.useEIRPDensityModel
        fprintf('  Power model  : OneWeb EIRP density %.1f dBW/4kHz (BWref %.0f Hz)\n', ...
            double(opts.params.EIRPdens_dBW_per_4kHz), double(opts.params.BWref_Hz));
    else
        fprintf('  Nominal beam : %.3f W (EPFD on-beam)\n', double(opts.fullBeamPower_W));
        fprintf('  Beam allocate: %.3f W (per open beam for serve/pool)\n', double(opts.beamAllocatePower_W));
        if isRelayPowerShiftUnlimitedLocal(opts)
            fprintf('  Relay shift  : helper sat pool -> relay beams (no cap)\n');
        else
            fprintf('  Beam budget  : %.3f W (max per beam for serve/shift)\n', double(opts.maxBeamPower_W));
            fprintf('  Relay shift  : overlap donors, capped\n');
        end
    end
    fprintf('  EPFD limit   : %.2f dB\n', double(opts.params.EPFD_thr_dB));
    if opts.recordUserSatisfaction
        recSats = satisfactionRecordSatListLocal(opts);
        if opts.reassignUsersEachSlot
            assignNote = 'reassign users each slot';
        else
            assignNote = 'assign users once at tStart';
        end
        if opts.enableRelay
            fprintf('  User satis.  : %s, relay ON, record %d sats, native floor %.2f\n', ...
                assignNote, numel(recSats), double(opts.relayMinNativeSat));
        else
            fprintf('  User satis.  : %s, %s, no relay\n', assignNote, strjoin(recSats, ', '));
        end
    end
end

recordSatisfaction = opts.recordUserSatisfaction;
userSatIdx = [];
userBeamIdx = [];
userCountMat = [];
P_users_km = [];
userNames = strings(0, 1);
if recordSatisfaction
    tAssignStr = datestr(tStart, 'dd mmm yyyy HH:MM:SS');
    if opts.useSimulatedUsers
        placementSats = string(opts.userPlacementSatList(:));
        [userNames, P_users_km, ~, ~, ~] = GenerateSimulatedUsersAroundSatellites( ...
            root, placementSats, opts.userAreaSide_km, opts.numUsersPerSatellite, tAssignStr, opts.userPrefix);
    else
        [userNames, P_users_km] = userFacilitiesXYZLocal(sc, string(opts.userPrefix));
    end
    if ~opts.reassignUsersEachSlot
        satGeomAssign = buildSatelliteBeamGeometryLocal(root, satList, tAssignStr, opts.beamHalfNS_deg);
        [userCountMat, userSatIdx, userBeamIdx] = assignUsersToNearestBeamCenterLocal( ...
            satGeomAssign, P_users_km, opts.beamHalfEW_deg, opts.beamHalfNS_deg);
    end
    if opts.verbose
        if opts.useSimulatedUsers
            if opts.reassignUsersEachSlot
                assignNote = 'nearest subpoint reassigned every slot';
            else
                assignNote = sprintf('assigned at %s', tAssignStr);
            end
            fprintf(['  Users simulated: %d (%d/sat x %d sats, %.0f km field, ' ...
                'fixed positions, %s)\n'], ...
                size(P_users_km, 2), opts.numUsersPerSatellite, numel(placementSats), ...
                opts.userAreaSide_km, assignNote);
        else
            fprintf('  Users loaded : %d from STK prefix "%s"\n', ...
                size(P_users_km, 2), char(string(opts.userPrefix)));
        end
    end
end

backoffRows = struct('time', {}, 'geo', {}, 'shutdown_rank', {}, 'sat', {}, 'beam', {}, ...
    'beam_pfd_contribution_dB', {}, 'gs_epfd_before_dB', {}, 'gs_epfd_after_dB', {}, 'epfd_drop_dB', {});
beamRows = struct('time', {}, 'geo', {}, 'sat', {}, 'beam', {}, 'beam_pfd_contribution_dB', {}, ...
    'gs_current_epfd_dB', {}, 'initial_power_W', {}, 'final_power_W', {}, 'shut_off', {}, 'shutdown_rank', {});
satisfactionRows = struct('time', {}, 'geo', {}, 'sat', {}, 'sat_subpoint_lat_deg', {}, ...
    'avg_user_satisfaction', {}, 'avg_user_satisfaction_no_relay', {}, 'assigned_user_count', {}, ...
    'relay_served_count', {}, 'unserved_distressed_count', {}, 'gs_epfd_after_dB', {}, ...
    'epfd_legal_before_relay', {});
relayAssignmentRows = struct('time', {}, 'geo', {}, 'user_id', {}, 'home_sat', {}, 'home_beam', {}, ...
    'relay_sat', {}, 'relay_beam', {}, 'user_satisfaction', {});
relayHomeToHelperRows = struct('time', {}, 'geo', {}, 'home_sat', {}, 'relay_sat', {}, 'relay_user_count', {});
swapServiceRows = struct('time', {}, 'geo', {}, 'user_id', {}, 'home_sat', {}, 'home_beam', {}, ...
    'service_sat', {}, 'service_beam', {}, 'user_satisfaction', {});
intraSatPowerShiftRows = struct('time', {}, 'geo', {}, 'helper_sat', {}, 'donor_beam', {}, ...
    'spare_W', {}, 'recipient_beam', {}, 'allocated_W', {}, 'recipient_final_power_W', {});

for iSlot = 1:numSlots
    t = timeGrid(iSlot);
    tStr = datestr(t, 'dd mmm yyyy HH:MM:SS');
    slotTic = tic;
    slotAggBefore_dB = NaN;
    slotAggAfter_dB = NaN;
    slotShutCount = 0;
    if opts.updateStkAnimation
        root.ExecuteCommand(['Animate * SetTime "' tStr '"']);
        if opts.animationPauseSec > 0
            pause(opts.animationPauseSec);
        end
    end
    if opts.verbose && (mod(iSlot-1, opts.logEveryNSlots) == 0 || iSlot == 1 || iSlot == numSlots)
        if recordSatisfaction && opts.reassignUsersEachSlot
            fprintf('[%d/%d] %s : reassign -> EPFD backoff -> relay/satisfaction...\n', iSlot, numSlots, tStr);
        else
            fprintf('[%d/%d] %s : EPFD backoff -> relay/satisfaction...\n', iSlot, numSlots, tStr);
        end
        drawnow;
    end
    satGeom = buildSatelliteBeamGeometryLocal(root, satList, tStr, opts.beamHalfNS_deg);
    if recordSatisfaction && opts.reassignUsersEachSlot
        [userCountMat, userSatIdx, userBeamIdx] = assignUsersToNearestBeamCenterLocal( ...
            satGeom, P_users_km, opts.beamHalfEW_deg, opts.beamHalfNS_deg);
    end
    [P_geo_all, geoNames] = buildGeoReferencePointsLocal(root, geoList, gsLon_deg, opts.useIdealGsoAtGs, tStr);
    [beamTable, threshold_lin] = buildFullPowerBeamTable(tStr, gsName, satList, satGeom, P_gs_km, P_geo_all, geoNames, opts);

    for ig = 1:numel(geoNames)
        geoMask = string(beamTable.geo) == geoNames(ig);
        Tgeo = beamTable(geoMask, :);
        if isempty(Tgeo)
            continue;
        end

        aggBefore_lin = sum(Tgeo.epfd_lin);
        aggAfter_lin = aggBefore_lin;
        shutCount = 0;
        slotAggBefore_dB = 10*log10(max(aggBefore_lin, 1e-300));

        linTol = threshold_lin * 1e-12;
        slotViolated = aggAfter_lin > threshold_lin + linTol;
        if slotViolated
            [~, order] = sort(Tgeo.epfd_lin, 'descend');
            for k = 1:numel(order)
                row = order(k);
                if aggAfter_lin <= threshold_lin + linTol
                    break;
                end
                before_lin = aggAfter_lin;
                aggAfter_lin = aggAfter_lin - Tgeo.epfd_lin(row);
                Tgeo.final_power_W(row) = 0;
                Tgeo.shut_off(row) = 1;
                Tgeo.shutdown_rank(row) = k;
                shutCount = k;

                backoffRows(end+1).time = string(tStr); %#ok<AGROW>
                backoffRows(end).geo = geoNames(ig);
                backoffRows(end).shutdown_rank = k;
                backoffRows(end).sat = Tgeo.sat(row);
                backoffRows(end).beam = Tgeo.beam(row);
                backoffRows(end).beam_pfd_contribution_dB = Tgeo.beam_pfd_contribution_dB(row);
                backoffRows(end).gs_epfd_before_dB = 10*log10(max(before_lin, 1e-300));
                backoffRows(end).gs_epfd_after_dB = 10*log10(max(aggAfter_lin, 1e-300));
                backoffRows(end).epfd_drop_dB = backoffRows(end).gs_epfd_before_dB - backoffRows(end).gs_epfd_after_dB;
            end
        end

        slotAggAfter_dB = 10*log10(max(aggAfter_lin, 1e-300));
        slotShutCount = max(slotShutCount, shutCount);
        epfdLegalBeforeRelay = aggAfter_lin <= threshold_lin + linTol;

        if slotViolated && any(Tgeo.shut_off > 0)
            involvedSats = unique(string(Tgeo.sat(Tgeo.shut_off > 0)), 'stable');
            for iSatRec = 1:numel(involvedSats)
                satMask = string(Tgeo.sat) == involvedSats(iSatRec);
                Tsat = sortrows(Tgeo(satMask, :), 'beam', 'ascend');
                for r = 1:height(Tsat)
                    beamRows(end+1).time = string(tStr); %#ok<AGROW>
                    beamRows(end).geo = geoNames(ig);
                    beamRows(end).sat = Tsat.sat(r);
                    beamRows(end).beam = Tsat.beam(r);
                    beamRows(end).beam_pfd_contribution_dB = Tsat.beam_pfd_contribution_dB(r);
                    beamRows(end).gs_current_epfd_dB = 10*log10(max(aggBefore_lin, 1e-300));
                    beamRows(end).initial_power_W = Tsat.initial_power_W(r);
                    beamRows(end).final_power_W = Tsat.final_power_W(r);
                    beamRows(end).shut_off = Tsat.shut_off(r);
                    beamRows(end).shutdown_rank = Tsat.shutdown_rank(r);
                end
            end
        end

        % Phase 3: middle swap -> pre-shift power on helper (overlap spare -> shut-region beams) -> relay -> satisfaction.
        if recordSatisfaction
            userDemand_bps = double(opts.userDemand_Mbps) * 1e6;
            NuserSlot = numel(userSatIdx);
            NsatSlot = numel(satList);
            NbeamSlot = size(satGeom(1).b_all, 2);
            PbeamBase_W = beamPowerMatrixFromTgeoLocal(Tgeo, satList, NbeamSlot);
            shutOffMat = shutOffMatrixFromTgeoLocal(Tgeo, satList, NbeamSlot);
            swapServiceMask = false(NuserSlot, 1);
            swapMiddleSatIdx = zeros(NuserSlot, 1);
            swapMiddleBeamIdx = zeros(NuserSlot, 1);
            middleServeCount = zeros(NsatSlot, NbeamSlot);

            if opts.enableRelay && opts.enableMiddleHelperSwap && epfdLegalBeforeRelay
                [swapServiceMask, swapMiddleSatIdx, swapMiddleBeamIdx, middleServeCount, swapRowsSlot] = ...
                    applyMiddleHelperSwapLocal(string(tStr), geoNames(ig), satGeom, satList, shutOffMat, ...
                    userSatIdx, userBeamIdx, P_users_km, userNames, PbeamBase_W, beamPowerBudgetForSwapLocal(opts), ...
                    opts.beamHalfEW_deg, opts.beamHalfNS_deg, opts.params, userDemand_bps, opts.relayMinNativeSat);
                swapServiceRows = [swapServiceRows, swapRowsSlot]; %#ok<AGROW>
            end

            satisfactionNoRelay = computeUserSatisfactionNoRelayLocal( ...
                satGeom, satList, userSatIdx, userBeamIdx, userCountMat, P_users_km, Tgeo, opts.params, userDemand_bps);
            relaySatIdx = zeros(NuserSlot, 1);
            relayBeamIdx = zeros(NuserSlot, 1);
            relayAssignedMask = false(NuserSlot, 1);
            satisfactionRelay = satisfactionNoRelay;
            PbeamEffective_W = PbeamBase_W;

            if opts.enableRelay && epfdLegalBeforeRelay
                if isRelayPowerShiftUnlimitedLocal(opts)
                    PbeamEffective_W = beamPowerServeMatrixLocal(shutOffMat, PbeamBase_W, opts.beamAllocatePower_W);
                    [PbeamEffective_W, shiftRowsSlot] = poolHelperSpareToRelayBeamsUnlimitedLocal( ...
                        string(tStr), geoNames(ig), satGeom, satList, userSatIdx, userBeamIdx, shutOffMat, ...
                        swapServiceMask, PbeamEffective_W, P_users_km, opts.params, userDemand_bps, ...
                        opts.beamAllocatePower_W, opts.beamHalfEW_deg, opts.beamHalfNS_deg);
                    intraSatPowerShiftRows = [intraSatPowerShiftRows, shiftRowsSlot]; %#ok<AGROW>
                else
                    PbeamEffective_W = PbeamBase_W;
                    if opts.enableMiddleHelperSwap
                        [PbeamEffective_W, shiftRowsSlot] = boostHelperBeamsBeforeRelayLocal( ...
                            string(tStr), geoNames(ig), satGeom, satList, userSatIdx, userBeamIdx, shutOffMat, ...
                            swapServiceMask, PbeamBase_W, P_users_km, opts.params, userDemand_bps, ...
                            opts.fullBeamPower_W, opts.maxBeamPower_W, opts.beamHalfEW_deg, opts.beamHalfNS_deg);
                        intraSatPowerShiftRows = [intraSatPowerShiftRows, shiftRowsSlot]; %#ok<AGROW>
                    end
                end
                [relayAssignedMask, relaySatIdx, relayBeamIdx] = assignRelayUsersLocal( ...
                    satGeom, satList, userSatIdx, userBeamIdx, shutOffMat, swapServiceMask, P_users_km, ...
                    PbeamEffective_W, opts.beamHalfEW_deg, opts.beamHalfNS_deg, opts.params, userDemand_bps, ...
                    opts.relayMinNativeSat, opts.relayMinRelayAvgSat);
                satisfactionRelay = evaluateUserSatisfactionWithSwapRelayLocal( ...
                    satGeom, satList, userSatIdx, userBeamIdx, userCountMat, P_users_km, PbeamEffective_W, ...
                    swapServiceMask, swapMiddleSatIdx, swapMiddleBeamIdx, middleServeCount, ...
                    relayAssignedMask, relaySatIdx, relayBeamIdx, opts.params, userDemand_bps, ...
                    opts.relayMinNativeSat, opts.relayMinRelayAvgSat);
            else
                if opts.enableRelay && ~epfdLegalBeforeRelay
                    warning('RunFullPowerAggregateShutdownSweepExcel:EpfdNotLegal', ...
                        '%s geo %s: EPFD still illegal after backoff (%.2f dB); relay skipped.', ...
                        tStr, geoNames(ig), slotAggAfter_dB);
                end
            end
            [relayAssignmentRows, relayHomeToHelperRows] = appendRelayExcelRowsLocal( ...
                relayAssignmentRows, relayHomeToHelperRows, string(tStr), geoNames(ig), ...
                userNames, satList, userSatIdx, userBeamIdx, relayAssignedMask, relaySatIdx, relayBeamIdx, ...
                satisfactionRelay, satisfactionRecordSatListLocal(opts));
            recordSats = satisfactionRecordSatListLocal(opts);
            for iSatRec = 1:numel(recordSats)
                satName = string(recordSats(iSatRec));
                iSat = find(satList == satName, 1);
                if isempty(iSat)
                    continue;
                end
                % Home cohort: this slot's assignment (userSatIdx). Relayed users stay in
                % this home group; satisfaction uses helper beam when relay applies.
                userMask = userSatIdx == iSat;
                nAssigned = sum(userMask);
                if nAssigned > 0
                    avgRelay = mean(satisfactionRelay(userMask), 'omitnan');
                    avgNoRelay = mean(satisfactionNoRelay(userMask), 'omitnan');
                else
                    avgRelay = NaN;
                    avgNoRelay = NaN;
                end
                homeDistressed = userMask & ~relayAssignedMask & (satisfactionNoRelay < 1e-12);
                relayServed = userMask & relayAssignedMask;
                satisfactionRows(end+1).time = string(tStr); %#ok<AGROW>
                satisfactionRows(end).geo = geoNames(ig);
                satisfactionRows(end).sat = satName;
                satisfactionRows(end).sat_subpoint_lat_deg = satGeom(iSat).subLat;
                satisfactionRows(end).avg_user_satisfaction = avgRelay;
                satisfactionRows(end).avg_user_satisfaction_no_relay = avgNoRelay;
                satisfactionRows(end).assigned_user_count = nAssigned;
                satisfactionRows(end).relay_served_count = sum(relayServed);
                satisfactionRows(end).unserved_distressed_count = sum(homeDistressed);
                satisfactionRows(end).gs_epfd_after_dB = slotAggAfter_dB;
                satisfactionRows(end).epfd_legal_before_relay = double(epfdLegalBeforeRelay);
                nUnserved = sum(homeDistressed);
                if nUnserved > 0
                    relayHomeToHelperRows(end+1).time = string(tStr); %#ok<AGROW>
                    relayHomeToHelperRows(end).geo = geoNames(ig);
                    relayHomeToHelperRows(end).home_sat = satName;
                    relayHomeToHelperRows(end).relay_sat = "UNSERVED";
                    relayHomeToHelperRows(end).relay_user_count = nUnserved;
                end
            end
        end
    end

    if opts.verbose && (mod(iSlot-1, opts.logEveryNSlots) == 0 || iSlot == 1 || iSlot == numSlots)
        fprintf('  done in %.2f s | GS EPFD %.2f -> %.2f dB | shut %d beams\n', ...
            toc(slotTic), slotAggBefore_dB, slotAggAfter_dB, slotShutCount);
        if recordSatisfaction
            recordSats = satisfactionRecordSatListLocal(opts);
            for iSatRec = 1:numel(recordSats)
                satName = string(recordSats(iSatRec));
                rowMask = string({satisfactionRows.time})' == string(tStr) & ...
                    string({satisfactionRows.sat})' == satName;
                if any(rowMask)
                    r = satisfactionRows(find(rowMask, 1));
                    if opts.enableRelay
                        fprintf('    %s avg sat %.4f (no relay %.4f) | relay %d unserved %d\n', ...
                            satName, r.avg_user_satisfaction, r.avg_user_satisfaction_no_relay, ...
                            r.relay_served_count, r.unserved_distressed_count);
                    else
                        fprintf('    %s avg user sat = %.4f (%d users)\n', satName, ...
                            r.avg_user_satisfaction, r.assigned_user_count);
                    end
                end
            end
        end
        drawnow;
    end
end

TbeamContributionLog = struct2table(beamRows);
TbackoffLog = struct2table(backoffRows);
TavgUserSatisfaction = struct2table(satisfactionRows);
TrelayAssignment = struct2table(relayAssignmentRows);
TrelayHomeToHelper = struct2table(relayHomeToHelperRows);

if ~isempty(TbeamContributionLog)
    TbeamContributionLog = sortrows(TbeamContributionLog, {'time','geo','sat','beam'}, {'ascend','ascend','ascend','ascend'});
end
if ~isempty(TbackoffLog)
    TbackoffLog = sortrows(TbackoffLog, {'time','geo','shutdown_rank'}, {'ascend','ascend','ascend'});
end
if ~isempty(TavgUserSatisfaction)
    TavgUserSatisfaction = sortrows(TavgUserSatisfaction, {'time','geo','sat'}, {'ascend','ascend','ascend'});
end
if ~isempty(TrelayAssignment)
    TrelayAssignment = sortrows(TrelayAssignment, {'time','geo','home_sat','relay_sat','user_id'}, ...
        {'ascend','ascend','ascend','ascend','ascend'});
end
if ~isempty(TrelayHomeToHelper)
    TrelayHomeToHelper = sortrows(TrelayHomeToHelper, {'time','geo','home_sat','relay_sat'}, ...
        {'ascend','ascend','ascend','ascend'});
end

excelPath = char(string(opts.excelPath));
outDir = fileparts(excelPath);
if ~isempty(outDir) && ~exist(outDir, 'dir')
    mkdir(outDir);
end
if exist(excelPath, 'file')
    delete(excelPath);
end
writetable(TbeamContributionLog, excelPath, 'Sheet', 'ViolatingSat_16BeamState');
writetable(TbackoffLog, excelPath, 'Sheet', 'Backoff_Log');
if recordSatisfaction && ~isempty(TavgUserSatisfaction)
    writetable(TavgUserSatisfaction, excelPath, 'Sheet', 'AvgUserSatisfaction');
end
if recordSatisfaction && ~isempty(TrelayAssignment)
    writetable(TrelayAssignment, excelPath, 'Sheet', 'Relay_Assignment');
end
if recordSatisfaction && ~isempty(TrelayHomeToHelper)
    writetable(TrelayHomeToHelper, excelPath, 'Sheet', 'Relay_HomeToHelper');
end
TswapService = struct2table(swapServiceRows);
TintraSatPowerShift = struct2table(intraSatPowerShiftRows);
if recordSatisfaction && ~isempty(TswapService)
    TswapService = sortrows(TswapService, {'time','geo','home_sat','service_sat','user_id'}, ...
        {'ascend','ascend','ascend','ascend','ascend'});
    writetable(TswapService, excelPath, 'Sheet', 'Swap_Service');
end
if recordSatisfaction && ~isempty(TintraSatPowerShift)
    TintraSatPowerShift = sortrows(TintraSatPowerShift, {'time','geo','helper_sat','donor_beam','recipient_beam'}, ...
        {'ascend','ascend','ascend','ascend','ascend'});
    writetable(TintraSatPowerShift, excelPath, 'Sheet', 'IntraSat_PowerShift');
end
fprintf('Saved full-power shutdown Excel: %s\n', excelPath);
end

function opts = applyDefaults(root, opts)
sc = root.CurrentScenario;
if ~isfield(opts, 'satList') || isempty(opts.satList), error('opts.satList is required.'); end
if ~isfield(opts, 'geoList') || isempty(opts.geoList), error('opts.geoList is required.'); end
if ~isfield(opts, 'gsName') || strlength(string(opts.gsName)) == 0, error('opts.gsName is required.'); end
if ~isfield(opts, 'stepSec') || ~isfinite(opts.stepSec), opts.stepSec = 1; end
if ~isfield(opts, 'tStartStr') || strlength(string(opts.tStartStr)) == 0, opts.tStartStr = sc.StartTime; end
if ~isfield(opts, 'tEndStr') || strlength(string(opts.tEndStr)) == 0, opts.tEndStr = sc.StopTime; end
if ~isfield(opts, 'beamHalfEW_deg') || ~isfinite(opts.beamHalfEW_deg), opts.beamHalfEW_deg = 24.5; end
if ~isfield(opts, 'beamHalfNS_deg') || ~isfinite(opts.beamHalfNS_deg), opts.beamHalfNS_deg = 25/16; end
if ~isfield(opts, 'gsLat_deg') || ~isfinite(opts.gsLat_deg), opts.gsLat_deg = 0; end
if ~isfield(opts, 'gsLon_deg') || ~isfinite(opts.gsLon_deg), opts.gsLon_deg = 121; end
if ~isfield(opts, 'gsAlt_km') || ~isfinite(opts.gsAlt_km), opts.gsAlt_km = 0; end
if ~isfield(opts, 'useIdealGsoAtGs') || isempty(opts.useIdealGsoAtGs), opts.useIdealGsoAtGs = false; end
if ~isfield(opts, 'fullBeamPower_W') || ~isfinite(opts.fullBeamPower_W), opts.fullBeamPower_W = 1.05; end
if ~isfield(opts, 'verbose') || isempty(opts.verbose), opts.verbose = true; end
if ~isfield(opts, 'logEveryNSlots') || ~isfinite(opts.logEveryNSlots) || opts.logEveryNSlots < 1
    opts.logEveryNSlots = 1;
end
if ~isfield(opts, 'updateStkAnimation') || isempty(opts.updateStkAnimation), opts.updateStkAnimation = true; end
if ~isfield(opts, 'animationPauseSec') || ~isfinite(opts.animationPauseSec), opts.animationPauseSec = 0; end
opts.animationPauseSec = max(double(opts.animationPauseSec), 0);
opts.logEveryNSlots = max(1, round(double(opts.logEveryNSlots)));
if ~isfield(opts, 'excelPath') || strlength(string(opts.excelPath)) == 0
    opts.excelPath = fullfile(fileparts(mfilename('fullpath')), '..', '..', 'Matlab_data', 'FullPower_BeamShutdownSweep.xlsx');
end
if isfield(opts, 'params') && ~isempty(opts.params)
    opts.params = opts.params;
else
    opts.params = ku_epfd_params();
end
opts.params = ensureParamDefaults(opts.params);
if ~isfield(opts, 'userPrefix') || strlength(string(opts.userPrefix)) == 0
    opts.userPrefix = "User_";
end
if ~isfield(opts, 'useSimulatedUsers') || isempty(opts.useSimulatedUsers)
    opts.useSimulatedUsers = false;
end
if ~isfield(opts, 'reassignUsersEachSlot') || isempty(opts.reassignUsersEachSlot)
    opts.reassignUsersEachSlot = true;
end
if ~isfield(opts, 'userPlacementSatList')
    opts.userPlacementSatList = string.empty(0, 1);
end
if isempty(opts.userPlacementSatList)
    opts.userPlacementSatList = string(opts.satList(:));
end
opts.userPlacementSatList = string(opts.userPlacementSatList(:));
if ~isfield(opts, 'numUsersPerSatellite') || ~isfinite(opts.numUsersPerSatellite)
    opts.numUsersPerSatellite = 30;
end
opts.numUsersPerSatellite = max(1, round(double(opts.numUsersPerSatellite)));
if ~isfield(opts, 'userAreaSide_km') || ~isfinite(opts.userAreaSide_km)
    opts.userAreaSide_km = 1888;
end
if ~isfield(opts, 'userDemand_Mbps') || ~isfinite(opts.userDemand_Mbps)
    opts.userDemand_Mbps = 25;
end
if ~isfield(opts, 'satisfactionSatList') || isempty(opts.satisfactionSatList)
    opts.satisfactionSatList = ["P03_S01", "P03_S49", "P03_S48"];
end
opts.satisfactionSatList = string(opts.satisfactionSatList(:));
if ~isfield(opts, 'recordUserSatisfaction') || isempty(opts.recordUserSatisfaction)
    opts.recordUserSatisfaction = true;
end
if ~isfield(opts, 'enableRelay') || isempty(opts.enableRelay)
    opts.enableRelay = true;
end
if ~isfield(opts, 'relayMinNativeSat') || ~isfinite(opts.relayMinNativeSat)
    opts.relayMinNativeSat = 0.9;
end
opts.relayMinNativeSat = max(0, min(1, double(opts.relayMinNativeSat)));
if ~isfield(opts, 'relayMinRelayAvgSat') || ~isfinite(opts.relayMinRelayAvgSat)
    opts.relayMinRelayAvgSat = opts.relayMinNativeSat;
end
opts.relayMinRelayAvgSat = max(0, min(1, double(opts.relayMinRelayAvgSat)));
if ~isfield(opts, 'enableMiddleHelperSwap') || isempty(opts.enableMiddleHelperSwap)
    opts.enableMiddleHelperSwap = opts.enableRelay;
end
if ~isfield(opts, 'beamAllocatePower_W') || ~isfinite(opts.beamAllocatePower_W)
    opts.beamAllocatePower_W = 1.05;
end
if ~isfield(opts, 'relayPowerShiftMode') || strlength(string(opts.relayPowerShiftMode)) == 0
    opts.relayPowerShiftMode = "overlapCapped";
end
opts.relayPowerShiftMode = string(opts.relayPowerShiftMode);
if ~isfield(opts, 'enforceMaxBeamPowerCap') || isempty(opts.enforceMaxBeamPowerCap)
    opts.enforceMaxBeamPowerCap = ~isRelayPowerShiftUnlimitedLocal(opts);
end
if ~isfield(opts, 'maxBeamPower_W') || ~isfinite(opts.maxBeamPower_W)
    opts.maxBeamPower_W = opts.beamAllocatePower_W;
end
if opts.enforceMaxBeamPowerCap
    opts.maxBeamPower_W = max(double(opts.beamAllocatePower_W), double(opts.maxBeamPower_W));
else
    opts.maxBeamPower_W = inf;
end
if ~isfield(opts, 'satisfactionRecordSatList')
    opts.satisfactionRecordSatList = string.empty(0, 1);
end
if isempty(opts.satisfactionRecordSatList)
    if opts.enableRelay
        opts.satisfactionRecordSatList = string(opts.satList(:));
    else
        opts.satisfactionRecordSatList = string(opts.satisfactionSatList(:));
    end
else
    opts.satisfactionRecordSatList = string(opts.satisfactionRecordSatList(:));
end
end

function satListOut = satisfactionRecordSatListLocal(opts)
satListOut = string(opts.satisfactionRecordSatList(:));
end

function P = ensureParamDefaults(P)
if ~isfield(P, 'useEIRPDensityModel'), P.useEIRPDensityModel = false; end
if ~isfield(P, 'EIRPdens_dBW_per_4kHz'), P.EIRPdens_dBW_per_4kHz = -13.4; end
if ~isfield(P, 'BWref_Hz'), P.BWref_Hz = 4e4; end
if ~isfield(P, 'GSO_Gmax_dBi'), P.GSO_Gmax_dBi = 0; end
if ~isfield(P, 'A_fit'), P.A_fit = 1; end
if ~isfield(P, 'beta_fit'), P.beta_fit = 0; end
if ~isfield(P, 'GSO_D_m'), P.GSO_D_m = 1; end
if ~isfield(P, 'lambda_m'), P.lambda_m = 0.025; end
if ~isfield(P, 'EPFD_thr_dB'), P.EPFD_thr_dB = -180; end
if ~isfield(P, 'B_Hz'), P.B_Hz = 250e6; end
if ~isfield(P, 'kB'), P.kB = 1.380649e-23; end
if ~isfield(P, 'user_noise_temp_K'), P.user_noise_temp_K = 240; end
if ~isfield(P, 'GS_LEO_Gmax_dBi')
    if isfield(P, 'user_D_m') && isfield(P, 'lambda_m')
        P.GS_LEO_Gmax_dBi = 20 * log10(P.user_D_m / P.lambda_m) + 7.7;
    else
        P.GS_LEO_Gmax_dBi = 0;
    end
end
end

function [beamTable, threshold_lin] = buildFullPowerBeamTable(tStr, gsName, satList, satGeom, P_gs_km, P_geo_all, geoNames, opts)
P = opts.params;
Gmax_lin = 10^(P.GSO_Gmax_dBi/10);
Gt_max_lin = max(P.A_fit, eps);
threshold_lin = 10^(P.EPFD_thr_dB/10);
if P.useEIRPDensityModel
    eirpRef_dBW = P.EIRPdens_dBW_per_4kHz + 10*log10(P.BWref_Hz/4000);
    eirpRef_lin = 10^(eirpRef_dBW/10);
else
    eirpRef_lin = NaN;
end
rows = struct('time', {}, 'gs', {}, 'geo', {}, 'sat', {}, 'beam', {}, 'initial_power_W', {}, 'final_power_W', {}, 'epfd_lin', {}, 'beam_pfd_contribution_dB', {}, 'shut_off', {}, 'shutdown_rank', {});
for iSat = 1:numel(satList)
    satName = char(satList(iSat));
    P_leo_km = satGeom(iSat).P_leo_km;
    b_all = satGeom(iSat).b_all;
    c_axis = satGeom(iSat).c_axis;
    for b = 1:16
        b_hat = b_all(:,b);
        t_axis = cross(c_axis, b_hat);
        t_axis = t_axis / max(norm(t_axis), eps);
        v_gs_m = (P_gs_km - P_leo_km) * 1000;
        d_m = norm(v_gs_m);
        for j = 1:numel(geoNames)
            if d_m < 1
                epfdLin = 0;
                if P.useEIRPDensityModel
                    beamPower_W = NaN;
                else
                    beamPower_W = opts.fullBeamPower_W;
                end
            else
                d_hat = v_gs_m / d_m;
                phit = angleDegLocal(b_hat, d_hat);
                Gt_lin = max(P.A_fit * exp(P.beta_fit * phit), 1e-30);
                alpha = angleDegLocal(P_leo_km - P_gs_km, P_geo_all(:,j) - P_gs_km);
                Gr_dBi = gso_rx_gain_itu1428(alpha, P.GSO_D_m, P.lambda_m);
                Gr_lin = 10^(Gr_dBi/10);
                if P.useEIRPDensityModel
                    Gt_rel = Gt_lin / Gt_max_lin;
                    epfdLin = eirpRef_lin * Gt_rel * (1/(4*pi*d_m^2)) * (Gr_lin/Gmax_lin);
                    beamPower_W = NaN;
                else
                    epfdLin = (opts.fullBeamPower_W / P.BWref_Hz) * (Gt_lin/(4*pi*d_m^2)) * (Gr_lin/Gmax_lin);
                    beamPower_W = opts.fullBeamPower_W;
                end
            end
            rows(end+1).time = string(tStr); %#ok<AGROW>
            rows(end).gs = string(gsName);
            rows(end).geo = geoNames(j);
            rows(end).sat = string(satName);
            rows(end).beam = b;
            rows(end).initial_power_W = beamPower_W;
            rows(end).final_power_W = beamPower_W;
            rows(end).epfd_lin = epfdLin;
            rows(end).beam_pfd_contribution_dB = 10*log10(max(epfdLin, 1e-300));
            rows(end).shut_off = 0;
            rows(end).shutdown_rank = NaN;
        end
    end
end
beamTable = struct2table(rows);
end

function [P_geo_all, geoNames] = buildGeoReferencePointsLocal(root, geoList, gsLon_deg, useIdealGsoAtGs, tStr)
geoNames = string(geoList(:));
P_geo_all = zeros(3, numel(geoNames));
for j = 1:numel(geoNames)
    if useIdealGsoAtGs
        P_geo_all(:,j) = idealGsoXYZFromLongitudeLocal(gsLon_deg);
    else
        geoObj = root.GetObjectFromPath(['*/Satellite/' char(geoNames(j))]);
        geoDP = geoObj.DataProviders.Item('Cartesian Position').Group.Item('Fixed');
        P_geo_all(:,j) = stkXYZLocal(geoDP, tStr);
    end
end
end

function satGeom = buildSatelliteBeamGeometryLocal(root, satList, tStr, beamHalfNS_deg)
pitchOffsets_deg = (8.5 - (1:16)) * (2 * beamHalfNS_deg);
satGeom = repmat(struct('satName', "", 'P_leo_km', [], 'b_all', [], 'c_axis', [], ...
    'subLat', [], 'subLon', []), numel(satList), 1);
for iSat = 1:numel(satList)
    satName = char(satList(iSat));
    satObj = root.GetObjectFromPath(['*/Satellite/' satName]);
    posDP = satObj.DataProviders.Item('Cartesian Position').Group.Item('Fixed');
    velDP = satObj.DataProviders.Item('Cartesian Velocity').Group.Item('Fixed');
    P_leo_km = stkXYZLocal(posDP, tStr);
    V_leo_kmps = stkXYZLocal(velDP, tStr);
    [b_all, c_axis] = beamBoresightsLocal(P_leo_km*1000, V_leo_kmps*1000, pitchOffsets_deg);
    satGeom(iSat).satName = string(satName);
    satGeom(iSat).P_leo_km = P_leo_km;
    satGeom(iSat).b_all = reorderBoresightsNorthToSouthLocal(P_leo_km*1000, b_all);
    satGeom(iSat).c_axis = c_axis;
    satGeom(iSat).subLat = asind(P_leo_km(3) / max(norm(P_leo_km), eps));
    satGeom(iSat).subLon = atan2d(P_leo_km(2), P_leo_km(1));
end
end

function [b_all, c_axis] = beamBoresightsLocal(r_sat_m, v_sat_mps, pitchOffsets_deg)
n_hat = r_sat_m / max(norm(r_sat_m), eps);
v_perp = v_sat_mps - dot(v_sat_mps, n_hat) * n_hat;
t_hat = v_perp / max(norm(v_perp), eps);
c_axis = cross(n_hat, t_hat);
c_axis = c_axis / max(norm(c_axis), eps);
b0 = -n_hat;
b_all = zeros(3, numel(pitchOffsets_deg));
for k = 1:numel(pitchOffsets_deg)
    b_all(:,k) = rodriguesLocal(b0, c_axis, deg2rad(pitchOffsets_deg(k)));
end
end

function b_sorted = reorderBoresightsNorthToSouthLocal(r_sat_m, b_all)
Re_m = 6378137.0;
nb = size(b_all, 2);
lat_deg = -inf(1, nb);
for k = 1:nb
    hit = rayEarthIntersectLocal(r_sat_m, b_all(:,k), Re_m);
    if ~isempty(hit)
        lat_deg(k) = asind(hit(3) / max(norm(hit), eps));
    end
end
[~, idx] = sort(lat_deg, 'descend');
b_sorted = b_all(:, idx);
end

function hit = rayEarthIntersectLocal(r_s_m, d_unit, Re_m)
a = 1.0;
b = 2.0 * dot(r_s_m, d_unit);
c = dot(r_s_m, r_s_m) - Re_m^2;
disc = b^2 - 4*a*c;
if disc < 0
    hit = [];
    return;
end
s = sqrt(disc);
lam1 = (-b - s) / 2.0;
lam2 = (-b + s) / 2.0;
cand = [lam1, lam2];
cand = cand(cand > 0);
if isempty(cand)
    hit = [];
    return;
end
hit = r_s_m + min(cand) * d_unit;
end

function v = rodriguesLocal(u, k, ang)
v = u*cos(ang) + cross(k,u)*sin(ang) + k*dot(k,u)*(1-cos(ang));
v = v / max(norm(v), eps);
end

function P = stkXYZLocal(dp, tStr)
res = dp.ExecSingle(tStr);
P = xyzFromArrayLocal(res.DataSets.ToArray);
end

function P = facilityXYZLocal(gsObj)
res = gsObj.DataProviders.Item('Cartesian Position').Exec;
P = xyzFromArrayLocal(res.DataSets.ToArray);
end

function P_gs_km = groundXYZFromLatLonLocal(lat_deg, lon_deg, alt_km)
Re_km = 6378.137;
r_km = Re_km + alt_km;
P_gs_km = r_km * [cosd(lat_deg) * cosd(lon_deg); cosd(lat_deg) * sind(lon_deg); sind(lat_deg)];
end

function [lat_deg, lon_deg] = facilityLatLonLocal(gsObj)
res = gsObj.DataProviders.Item('LLA State').Exec;
vals = numericScalarsLocal(res.DataSets.ToArray);
lat_deg = vals(1);
lon_deg = vals(2);
end

function P_geo_km = idealGsoXYZFromLongitudeLocal(lon_deg)
R_geo_km = 42164.0;
P_geo_km = R_geo_km * [cosd(lon_deg); sind(lon_deg); 0];
end

function P = xyzFromArrayLocal(arr)
vals = numericScalarsLocal(arr);
P = vals(1:3);
end

function vals = numericScalarsLocal(arr)
vals = [];
if isnumeric(arr)
    vals = double(arr(:));
    return;
end
for k = 1:numel(arr)
    a = arr{k};
    if isnumeric(a) && isscalar(a)
        vals(end+1,1) = double(a); %#ok<AGROW>
    else
        n = str2double(string(a));
        if ~isnan(n)
            vals(end+1,1) = n; %#ok<AGROW>
        end
    end
end
end

function a = angleDegLocal(x, y)
a = acosd(max(-1, min(1, dot(x,y)/(norm(x)*norm(y)+eps))));
end

function [userNames, P_users_km] = userFacilitiesXYZLocal(sc, userPrefix)
facs = sc.Children.GetElements('eFacility');
userNames = strings(0,1);
P_users_km = zeros(3,0);
for k = 0:int32(facs.Count-1)
    fac = facs.Item(k);
    facName = string(fac.InstanceName);
    if ~startsWith(facName, userPrefix)
        continue;
    end
    userNames(end+1,1) = facName; %#ok<AGROW>
    P_users_km(:,end+1) = facilityXYZLocal(fac); %#ok<AGROW>
end
if isempty(userNames)
    warning('RunFullPowerAggregateShutdownSweepExcel:NoUsers', ...
        'No user facilities found with prefix "%s".', char(userPrefix));
end
end

function [userCountMat, userSatIdx, userBeamIdx] = assignUsersToNearestBeamCenterLocal( ...
    satGeom, P_users_km, beamHalfEW_deg, beamHalfNS_deg)
Nsat = numel(satGeom);
Nbeam = size(satGeom(1).b_all, 2);
Nuser = size(P_users_km, 2);
userCountMat = zeros(Nsat, Nbeam);
userSatIdx = zeros(Nuser, 1);
userBeamIdx = zeros(Nuser, 1);

for iu = 1:Nuser
    userLat = asind(P_users_km(3,iu) / max(norm(P_users_km(:,iu)), eps));
    userLon = atan2d(P_users_km(2,iu), P_users_km(1,iu));
    bestSat = nearestSatelliteSubpointLocal(satGeom, userLat, userLon, 1:Nsat);
    [bestBeam, ~] = bestCoveredBeamForUserLocal(satGeom(bestSat), P_users_km(:,iu), ...
        beamHalfEW_deg, beamHalfNS_deg);
    if bestSat > 0 && bestBeam > 0
        userCountMat(bestSat, bestBeam) = userCountMat(bestSat, bestBeam) + 1;
        userSatIdx(iu) = bestSat;
        userBeamIdx(iu) = bestBeam;
    end
end
end

function PbeamActualMat_W = beamPowerMatrixFromTgeoLocal(Tgeo, satList, Nbeam)
Nsat = numel(satList);
PbeamActualMat_W = zeros(Nsat, Nbeam);
for r = 1:height(Tgeo)
    iSat = find(satList == string(Tgeo.sat(r)), 1);
    if isempty(iSat)
        continue;
    end
    b = Tgeo.beam(r);
    PbeamActualMat_W(iSat, b) = Tgeo.final_power_W(r);
end
end

function shutOffMat = shutOffMatrixFromTgeoLocal(Tgeo, satList, Nbeam)
Nsat = numel(satList);
shutOffMat = zeros(Nsat, Nbeam);
for r = 1:height(Tgeo)
    iSat = find(satList == string(Tgeo.sat(r)), 1);
    if isempty(iSat)
        continue;
    end
    shutOffMat(iSat, Tgeo.beam(r)) = double(Tgeo.shut_off(r) > 0);
end
end

function satisfaction = computeUserSatisfactionNoRelayLocal( ...
    satGeom, satList, userSatIdx, userBeamIdx, userCountMat, P_users_km, Tgeo, P, userDemand_bps)
Nbeam = size(satGeom(1).b_all, 2);
PbeamActualMat_W = beamPowerMatrixFromTgeoLocal(Tgeo, satList, Nbeam);
Nuser = numel(userSatIdx);
satisfaction = zeros(Nuser, 1);

for iu = 1:Nuser
    iSat = userSatIdx(iu);
    b = userBeamIdx(iu);
    if iSat < 1 || b < 1
        continue;
    end
    Pbeam = PbeamActualMat_W(iSat, b);
    usersInBeam = max(double(userCountMat(iSat, b)), 1);
    satisfaction(iu) = userSatisfactionAtBeamLocal( ...
        iu, iSat, b, Pbeam, usersInBeam, satGeom, P_users_km, P, userDemand_bps);
end
end

function [relayAssignmentRows, relayHomeToHelperRows] = appendRelayExcelRowsLocal( ...
    relayAssignmentRows, relayHomeToHelperRows, tStr, geoName, userNames, satList, ...
    userSatIdx, userBeamIdx, relayAssignedMask, relaySatIdx, relayBeamIdx, satisfactionRelay, ...
    homeSatFilterList)
if nargin < 14 || isempty(homeSatFilterList)
    homeSatFilterList = satList;
end
homeSatFilterList = string(homeSatFilterList(:));
relayUsers = find(relayAssignedMask);
if isempty(relayUsers)
    return;
end

pairCount = containers.Map('KeyType', 'char', 'ValueType', 'double');
for k = 1:numel(relayUsers)
    iu = relayUsers(k);
    homeSat = satList(userSatIdx(iu));
    if ~any(homeSatFilterList == homeSat)
        continue;
    end
    relaySat = satList(relaySatIdx(iu));
    relayBeam = relayBeamIdx(iu);
    homeBeam = userBeamIdx(iu);
    uid = userNames(iu);
    if iu > numel(userNames)
        uid = sprintf('User_%d', iu);
    end

    relayAssignmentRows(end+1).time = tStr; %#ok<AGROW>
    relayAssignmentRows(end).geo = geoName;
    relayAssignmentRows(end).user_id = string(uid);
    relayAssignmentRows(end).home_sat = homeSat;
    relayAssignmentRows(end).home_beam = homeBeam;
    relayAssignmentRows(end).relay_sat = relaySat;
    relayAssignmentRows(end).relay_beam = relayBeam;
    relayAssignmentRows(end).user_satisfaction = satisfactionRelay(iu);

    pairKey = sprintf('%s|%s', char(homeSat), char(relaySat));
    if isKey(pairCount, pairKey)
        pairCount(pairKey) = pairCount(pairKey) + 1;
    else
        pairCount(pairKey) = 1;
    end
end

pairKeys = keys(pairCount);
for p = 1:numel(pairKeys)
    parts = strsplit(char(pairKeys{p}), '|');
    relayHomeToHelperRows(end+1).time = tStr; %#ok<AGROW>
    relayHomeToHelperRows(end).geo = geoName;
    relayHomeToHelperRows(end).home_sat = string(parts{1});
    relayHomeToHelperRows(end).relay_sat = string(parts{2});
    relayHomeToHelperRows(end).relay_user_count = pairCount(pairKeys{p});
end
end

function [swapServiceMask, swapMiddleSatIdx, swapMiddleBeamIdx, middleServeCount, swapRows] = ...
    applyMiddleHelperSwapLocal(tStr, geoName, satGeom, satList, shutOffMat, userSatIdx, userBeamIdx, ...
    P_users_km, userNames, PbeamBase_W, beamPowerBudget_W, beamHalfEW_deg, beamHalfNS_deg, P, ...
    userDemand_bps, minSwapSat)
Nsat = numel(satList);
Nbeam = size(satGeom(1).b_all, 2);
Nuser = numel(userSatIdx);
swapServiceMask = false(Nuser, 1);
swapMiddleSatIdx = zeros(Nuser, 1);
swapMiddleBeamIdx = zeros(Nuser, 1);
middleServeCount = zeros(Nsat, Nbeam);
swapRows = struct('time', {}, 'geo', {}, 'user_id', {}, 'home_sat', {}, 'home_beam', {}, ...
    'service_sat', {}, 'service_beam', {}, 'user_satisfaction', {});

for iu = 1:Nuser
    iHome = userSatIdx(iu);
    bHome = userBeamIdx(iu);
    if iHome < 1 || bHome < 1 || shutOffMat(iHome, bHome) > 0
        continue;
    end
    middleServeCount(iHome, bHome) = middleServeCount(iHome, bHome) + 1;
end

distressedIdx = find(any(shutOffMat > 0, 2));
if isempty(distressedIdx)
    return;
end

middleOpenBeamsBySat = cell(Nsat, 1);
for iMid = distressedIdx(:).'
    middleOpenBeamsBySat{iMid} = find(shutOffMat(iMid, :) == 0 & PbeamBase_W(iMid, :) > 0);
end

for iMid = distressedIdx(:).'
    middleOpenBeams = middleOpenBeamsBySat{iMid};
    if isempty(middleOpenBeams)
        continue;
    end
    for iHelp = 1:Nsat
        if iHelp == iMid
            continue;
        end
        candUsers = find(userSatIdx == iHelp & ~swapServiceMask);
        for k = 1:numel(candUsers)
            iu = candUsers(k);
            bH = userBeamIdx(iu);
            if bH < 1 || shutOffMat(iHelp, bH) > 0 || PbeamBase_W(iHelp, bH) <= 0
                continue;
            end
            bestSat = -1;
            bestBM = 0;
            for bM = middleOpenBeams
                if ~userCoveredByBeamLocal(satGeom(iMid), bM, P_users_km(:, iu), beamHalfEW_deg, beamHalfNS_deg)
                    continue;
                end
                nMid = middleServeCount(iMid, bM) + 1;
                Pserve_W = beamPowerBudget_W;
                sTry = userSatisfactionAtBeamLocal(iu, iMid, bM, Pserve_W, nMid, ...
                    satGeom, P_users_km, P, userDemand_bps);
                if sTry + 1e-9 >= minSwapSat && sTry > bestSat
                    bestSat = sTry;
                    bestBM = bM;
                end
            end
            if bestBM < 1
                continue;
            end
            swapServiceMask(iu) = true;
            swapMiddleSatIdx(iu) = iMid;
            swapMiddleBeamIdx(iu) = bestBM;
            middleServeCount(iMid, bestBM) = middleServeCount(iMid, bestBM) + 1;
            uid = userIdStringLocal(userNames, iu);
            swapRows(end+1).time = tStr; %#ok<AGROW>
            swapRows(end).geo = geoName;
            swapRows(end).user_id = uid;
            swapRows(end).home_sat = satList(iHelp);
            swapRows(end).home_beam = bH;
            swapRows(end).service_sat = satList(iMid);
            swapRows(end).service_beam = bestBM;
            swapRows(end).user_satisfaction = bestSat;
        end
    end
end
end

function [relayAssignedMask, relaySatIdx, relayBeamIdx] = assignRelayUsersLocal( ...
    satGeom, satList, userSatIdx, userBeamIdx, shutOffMat, swapServiceMask, P_users_km, ...
    PbeamActualMat_W, beamHalfEW_deg, beamHalfNS_deg, P, userDemand_bps, relayMinNativeSat, relayMinRelayAvgSat)
Nsat = numel(satList);
Nuser = numel(userSatIdx);
relaySatIdx = zeros(Nuser, 1);
relayBeamIdx = zeros(Nuser, 1);
relayAssignedMask = false(Nuser, 1);
beamRelayCount = zeros(Nsat, size(satGeom(1).b_all, 2));

distressedUsers = false(Nuser, 1);
for iu = 1:Nuser
    if swapServiceMask(iu)
        continue;
    end
    iSat = userSatIdx(iu);
    b = userBeamIdx(iu);
    if iSat < 1 || b < 1
        continue;
    end
    Phome = PbeamActualMat_W(iSat, b);
    if ~isfinite(Phome) || Phome <= 0
        distressedUsers(iu) = true;
    end
end

distressedList = find(distressedUsers);
for k = 1:numel(distressedList)
    iu = distressedList(k);
    userLat = asind(P_users_km(3,iu) / max(norm(P_users_km(:,iu)), eps));
    userLon = atan2d(P_users_km(2,iu), P_users_km(1,iu));
    homeSat = userSatIdx(iu);

    candSat = zeros(0, 1);
    candBeam = zeros(0, 1);
    candDist = zeros(0, 1);
    for iSat = 1:Nsat
        if iSat == homeSat
            continue;
        end
        [bestBeam, ~] = bestCoveredBeamForUserLocal(satGeom(iSat), P_users_km(:,iu), ...
            beamHalfEW_deg, beamHalfNS_deg);
        if bestBeam < 1
            continue;
        end
        Phelper = PbeamActualMat_W(iSat, bestBeam);
        if ~isfinite(Phelper) || Phelper <= 0
            continue;
        end
        candSat(end+1,1) = iSat; %#ok<AGROW>
        candBeam(end+1,1) = bestBeam; %#ok<AGROW>
        candDist(end+1,1) = greatCircleDistanceDegLocal(userLat, userLon, ...
            satGeom(iSat).subLat, satGeom(iSat).subLon); %#ok<AGROW>
    end

    if isempty(candSat)
        continue;
    end
    [candDist, order] = sort(candDist, 'ascend');
    candSat = candSat(order);
    candBeam = candBeam(order);

    for c = 1:numel(candSat)
        iSat = candSat(c);
        b = candBeam(c);
        relayOnBeam = find(relayAssignedMask & relaySatIdx == iSat & relayBeamIdx == b);
        relayListTry = [relayOnBeam; iu];
        nativeList = find(userSatIdx == iSat & userBeamIdx == b & ~swapServiceMask);
        Pbeam = PbeamActualMat_W(iSat, b);
        planTry = planHelperBeamRelayPowerSplitLocal(iSat, b, nativeList, relayListTry, Pbeam, ...
            satGeom, P_users_km, P, userDemand_bps, relayMinNativeSat, relayMinRelayAvgSat);
        if ~planTry.feasible
            continue;
        end
        relaySatIdx(iu) = iSat;
        relayBeamIdx(iu) = b;
        relayAssignedMask(iu) = true;
        beamRelayCount(iSat, b) = beamRelayCount(iSat, b) + 1;
        break;
    end
end
end

function tf = isRelayPowerShiftUnlimitedLocal(opts)
tf = isfield(opts, 'relayPowerShiftMode') && string(opts.relayPowerShiftMode) == "helperSatPoolUnlimited";
end

function p_W = beamPowerBudgetForSwapLocal(opts)
if isRelayPowerShiftUnlimitedLocal(opts)
    p_W = double(opts.beamAllocatePower_W);
else
    p_W = double(opts.maxBeamPower_W);
end
end

function Pserve_W = beamPowerServeMatrixLocal(shutOffMat, PbeamBase_W, beamAllocatePower_W)
Pserve_W = zeros(size(PbeamBase_W));
onMask = PbeamBase_W > 0 & shutOffMat == 0;
Pserve_W(onMask) = beamAllocatePower_W;
end

function recipientBeams = relayRecipientBeamsOnHelperLocal(iHelp, distressedIdx, shutOffMat, PbeamBase_W, ...
    userSatIdx, userBeamIdx, swapServiceMask, satGeom, ~, P_users_km, beamHalfEW_deg, beamHalfNS_deg)
recipientBeams = zeros(0, 1);
Nbeam = size(shutOffMat, 2);
for iMid = distressedIdx(:).'
    if iMid == iHelp
        continue;
    end
    onMidMask = userSatIdx == iMid & userBeamIdx > 0 & ~swapServiceMask;
    distressedOnMid = find(onMidMask);
    keep = false(numel(distressedOnMid), 1);
    for kk = 1:numel(distressedOnMid)
        iuCheck = distressedOnMid(kk);
        keep(kk) = shutOffMat(iMid, userBeamIdx(iuCheck)) > 0;
    end
    distressedOnMid = distressedOnMid(keep);
    for k = 1:numel(distressedOnMid)
        iu = distressedOnMid(k);
        for bR = 1:Nbeam
            if PbeamBase_W(iHelp, bR) <= 0 || shutOffMat(iHelp, bR) > 0
                continue;
            end
            if ~userCoveredByBeamLocal(satGeom(iHelp), bR, P_users_km(:, iu), beamHalfEW_deg, beamHalfNS_deg)
                continue;
            end
            if ~any(recipientBeams == bR)
                recipientBeams(end+1, 1) = bR; %#ok<AGROW>
            end
        end
    end
end
end

function [PbeamEffective_W, shiftRows] = poolHelperSpareToRelayBeamsUnlimitedLocal( ...
    tStr, geoName, satGeom, satList, userSatIdx, userBeamIdx, shutOffMat, swapServiceMask, ...
    PbeamServe_W, P_users_km, P, userDemand_bps, beamAllocatePower_W, beamHalfEW_deg, beamHalfNS_deg)
% Each open helper beam starts at beamAllocatePower_W (e.g. 1.05 W). Before relay, pool
% spare on every open beam: allocate minus per-native power to reach sat=1 (sat=1 surplus
% excluded). Includes spare freed when middle swap removed natives. Split pool equally
% across helper beams that cover users on shut middle beams; no max power cap.
Nsat = numel(satList);
Nbeam = size(satGeom(1).b_all, 2);
PbeamEffective_W = PbeamServe_W;
shiftRows = struct('time', {}, 'geo', {}, 'helper_sat', {}, 'donor_beam', {}, 'spare_W', {}, ...
    'recipient_beam', {}, 'allocated_W', {}, 'recipient_final_power_W', {});
distressedIdx = find(any(shutOffMat > 0, 2));
if isempty(distressedIdx)
    return;
end

for iHelp = 1:Nsat
    donorBeams = zeros(0, 1);
    donorSpare_W = zeros(0, 1);
    recipientBeams = relayRecipientBeamsOnHelperLocal(iHelp, distressedIdx, shutOffMat, ...
        PbeamServe_W, userSatIdx, userBeamIdx, swapServiceMask, satGeom, satList, P_users_km, ...
        beamHalfEW_deg, beamHalfNS_deg);
    if isempty(recipientBeams)
        continue;
    end

    for bH = 1:Nbeam
        if PbeamServe_W(iHelp, bH) <= 0 || shutOffMat(iHelp, bH) > 0
            continue;
        end
        nativeList = find(userSatIdx == iHelp & userBeamIdx == bH & ~swapServiceMask);
        spare_W = helperBeamDonorSparePowerLocal(nativeList, iHelp, bH, beamAllocatePower_W, ...
            beamAllocatePower_W, satGeom, P_users_km, P, userDemand_bps);
        if spare_W <= 1e-12
            continue;
        end
        donorBeams(end+1, 1) = bH; %#ok<AGROW>
        donorSpare_W(end+1, 1) = spare_W; %#ok<AGROW>
    end

    if isempty(donorBeams)
        continue;
    end

    pool_W = sum(donorSpare_W);
    allocPerRecipient_W = pool_W / numel(recipientBeams);
    for r = 1:numel(recipientBeams)
        bR = recipientBeams(r);
        add_W = allocPerRecipient_W;
        if add_W <= 0
            continue;
        end
        PbeamEffective_W(iHelp, bR) = PbeamEffective_W(iHelp, bR) + add_W;
        for d = 1:numel(donorBeams)
            share_W = donorSpare_W(d) * (add_W / pool_W);
            shiftRows(end+1).time = tStr; %#ok<AGROW>
            shiftRows(end).geo = geoName;
            shiftRows(end).helper_sat = satList(iHelp);
            shiftRows(end).donor_beam = donorBeams(d);
            shiftRows(end).spare_W = donorSpare_W(d);
            shiftRows(end).recipient_beam = bR;
            shiftRows(end).allocated_W = share_W;
            shiftRows(end).recipient_final_power_W = PbeamEffective_W(iHelp, bR);
        end
    end
end
end

function [PbeamEffective_W, shiftRows] = boostHelperBeamsBeforeRelayLocal( ...
    tStr, geoName, satGeom, satList, userSatIdx, userBeamIdx, shutOffMat, swapServiceMask, ...
    PbeamBase_W, P_users_km, P, userDemand_bps, fullBeamPower_W, maxBeamPower_W, ...
    beamHalfEW_deg, beamHalfNS_deg)
% After swap: donor spare uses maxBeamPower_W budget minus native reserve x1.
% fullBeamPower_W is nominal on-air (e.g. 0.85 W); maxBeamPower_W is per-beam cap (e.g. 1.05 W).
% If natives are gone after swap, spare = maxBeamPower_W (includes 1.05-0.85 headroom).
Nsat = numel(satList);
Nbeam = size(satGeom(1).b_all, 2);
PbeamEffective_W = PbeamBase_W;
shiftRows = struct('time', {}, 'geo', {}, 'helper_sat', {}, 'donor_beam', {}, 'spare_W', {}, ...
    'recipient_beam', {}, 'allocated_W', {}, 'recipient_final_power_W', {});
distressedIdx = find(any(shutOffMat > 0, 2));
if isempty(distressedIdx)
    return;
end

for iHelp = 1:Nsat
    donorBeams = zeros(0, 1);
    donorSpare_W = zeros(0, 1);
    recipientBeams = relayRecipientBeamsOnHelperLocal(iHelp, distressedIdx, shutOffMat, PbeamBase_W, ...
        userSatIdx, userBeamIdx, swapServiceMask, satGeom, satList, P_users_km, beamHalfEW_deg, beamHalfNS_deg);

    for iMid = distressedIdx(:).'
        if iMid == iHelp
            continue;
        end
        middleOpenBeams = find(shutOffMat(iMid, :) == 0 & PbeamBase_W(iMid, :) > 0);

        for bH = 1:Nbeam
            if PbeamBase_W(iHelp, bH) <= 0 || shutOffMat(iHelp, bH) > 0
                continue;
            end
            if ~helperBeamHasUserCoverableByMiddleOpenLocal(iHelp, bH, iMid, middleOpenBeams, ...
                    userSatIdx, userBeamIdx, satGeom, P_users_km, beamHalfEW_deg, beamHalfNS_deg)
                continue;
            end
            if any(donorBeams == bH)
                continue;
            end
            nativeList = find(userSatIdx == iHelp & userBeamIdx == bH & ~swapServiceMask);
            spare_W = helperBeamDonorSparePowerLocal(nativeList, iHelp, bH, fullBeamPower_W, ...
                maxBeamPower_W, satGeom, P_users_km, P, userDemand_bps);
            if spare_W <= 1e-12
                continue;
            end
            donorBeams(end+1, 1) = bH; %#ok<AGROW>
            donorSpare_W(end+1, 1) = spare_W; %#ok<AGROW>
        end
    end

    if isempty(donorBeams) || isempty(recipientBeams)
        continue;
    end

    pool_W = sum(donorSpare_W);
    allocPerRecipient_W = pool_W / numel(recipientBeams);
    for r = 1:numel(recipientBeams)
        bR = recipientBeams(r);
        add_W = min(maxBeamPower_W - PbeamEffective_W(iHelp, bR), allocPerRecipient_W);
        if add_W <= 0
            continue;
        end
        PbeamEffective_W(iHelp, bR) = PbeamEffective_W(iHelp, bR) + add_W;
        for d = 1:numel(donorBeams)
            share_W = donorSpare_W(d) * (add_W / pool_W);
            shiftRows(end+1).time = tStr; %#ok<AGROW>
            shiftRows(end).geo = geoName;
            shiftRows(end).helper_sat = satList(iHelp);
            shiftRows(end).donor_beam = donorBeams(d);
            shiftRows(end).spare_W = donorSpare_W(d);
            shiftRows(end).recipient_beam = bR;
            shiftRows(end).allocated_W = share_W;
            shiftRows(end).recipient_final_power_W = PbeamEffective_W(iHelp, bR);
        end
    end
end
end

function satisfaction = evaluateUserSatisfactionWithSwapRelayLocal( ...
    satGeom, satList, userSatIdx, userBeamIdx, userCountMat, P_users_km, PbeamEffective_W, ...
    swapServiceMask, swapMiddleSatIdx, swapMiddleBeamIdx, middleServeCount, relayAssignedMask, ...
    relaySatIdx, relayBeamIdx, P, userDemand_bps, relayMinNativeSat, relayMinRelayAvgSat)
Nsat = numel(satList);
Nbeam = size(satGeom(1).b_all, 2);
Nuser = numel(userSatIdx);
satisfaction = zeros(Nuser, 1);
beamRelayCount = zeros(Nsat, Nbeam);
relayUsers = find(relayAssignedMask);
for k = 1:numel(relayUsers)
    iu = relayUsers(k);
    beamRelayCount(relaySatIdx(iu), relayBeamIdx(iu)) = beamRelayCount(relaySatIdx(iu), relayBeamIdx(iu)) + 1;
end

beamSplitCache = containers.Map('KeyType', 'char', 'ValueType', 'any');
for iu = 1:Nuser
    if swapServiceMask(iu)
        iSat = swapMiddleSatIdx(iu);
        b = swapMiddleBeamIdx(iu);
        Pbeam = PbeamEffective_W(iSat, b);
        usersInBeam = max(double(middleServeCount(iSat, b)), 1);
        satisfaction(iu) = userSatisfactionAtBeamLocal(iu, iSat, b, Pbeam, usersInBeam, ...
            satGeom, P_users_km, P, userDemand_bps);
        continue;
    end
    if relayAssignedMask(iu)
        iSat = relaySatIdx(iu);
        b = relayBeamIdx(iu);
    else
        iSat = userSatIdx(iu);
        b = userBeamIdx(iu);
    end
    if iSat < 1 || b < 1
        continue;
    end
    Pbeam = PbeamEffective_W(iSat, b);
    if beamRelayCount(iSat, b) > 0
        key = sprintf('%d_%d', iSat, b);
        if ~isKey(beamSplitCache, key)
            beamSplitCache(key) = buildBeamRelayPowerSplitLocal(iSat, b, userSatIdx, userBeamIdx, ...
                swapServiceMask, relayAssignedMask, relaySatIdx, relayBeamIdx, Pbeam, satGeom, ...
                P_users_km, P, userDemand_bps, relayMinNativeSat, relayMinRelayAvgSat);
        end
        split = beamSplitCache(key);
        if isKey(split.byIu, iu)
            satisfaction(iu) = split.byIu(iu);
        end
    else
        usersInBeam = max(double(userCountMat(iSat, b)), 1);
        if any(swapServiceMask & userSatIdx == iSat & userBeamIdx == b)
            usersInBeam = max(usersInBeam - sum(swapServiceMask & userSatIdx == iSat & userBeamIdx == b), 1);
        end
        satisfaction(iu) = userSatisfactionAtBeamLocal(iu, iSat, b, Pbeam, usersInBeam, ...
            satGeom, P_users_km, P, userDemand_bps);
    end
end
end

function tf = helperBeamHasUserCoverableByMiddleOpenLocal(iHelp, bH, iMid, middleOpenBeams, ...
    userSatIdx, userBeamIdx, satGeom, P_users_km, beamHalfEW_deg, beamHalfNS_deg)
tf = false;
usersOnBeam = find(userSatIdx == iHelp & userBeamIdx == bH);
for k = 1:numel(usersOnBeam)
    iu = usersOnBeam(k);
    for bM = middleOpenBeams
        if userCoveredByBeamLocal(satGeom(iMid), bM, P_users_km(:, iu), beamHalfEW_deg, beamHalfNS_deg)
            tf = true;
            return;
        end
    end
end
end

function tf = userCoveredByBeamLocal(satGeomOne, beamIdx, P_user_km, beamHalfEW_deg, beamHalfNS_deg)
P_leo_km = satGeomOne.P_leo_km;
b_hat = satGeomOne.b_all(:, beamIdx);
c_axis = satGeomOne.c_axis;
v_user_km = P_user_km(:) - P_leo_km(:);
d_m = norm(v_user_km) * 1000;
if d_m < 1
    tf = false;
    return;
end
d_hat = v_user_km / max(norm(v_user_km), eps);
t_axis = cross(c_axis, b_hat);
t_axis = t_axis / max(norm(t_axis), eps);
th_h = atan2d(dot(d_hat, c_axis), dot(d_hat, b_hat));
th_v = atan2d(dot(d_hat, t_axis), dot(d_hat, b_hat));
tf = abs(th_h) <= beamHalfEW_deg && abs(th_v) <= beamHalfNS_deg;
end

function uid = userIdStringLocal(userNames, iu)
if iu <= numel(userNames)
    uid = string(userNames(iu));
else
    uid = sprintf('User_%d', iu);
end
end

function s = userSatisfactionAtBeamLocal(iu, iSat, b, Pbeam, usersInBeam, satGeom, P_users_km, P, userDemand_bps)
if iSat < 1 || b < 1 || ~isfinite(Pbeam) || Pbeam <= 0
    s = 0;
    return;
end
Buser = P.B_Hz;
noisePower_W = P.kB * P.user_noise_temp_K * Buser;
Gur_lin = 10^(P.GS_LEO_Gmax_dBi/10);
demandMbps = userDemand_bps / 1e6;
channelGain = userLinkChannelGainPerWLocal(satGeom(iSat), b, P_users_km(:,iu), P, Gur_lin);
sig = Pbeam * channelGain;
sinr = sig / max(noisePower_W, eps);
cinst_bps = Buser * log2(1 + sinr);
usersInBeam = max(double(usersInBeam), 1);
rate_Mbps = cinst_bps / usersInBeam / 1e6;
s = min(rate_Mbps / max(demandMbps, eps), 1);
end

function Ptx_W = transmitPowerForUserTargetSatLocal(iu, iSat, b, targetSat, usersInBeam, ...
    satGeom, P_users_km, P, userDemand_bps)
targetSat = max(0, min(1, double(targetSat)));
Buser = P.B_Hz;
noisePower_W = P.kB * P.user_noise_temp_K * Buser;
Gur_lin = 10^(P.GS_LEO_Gmax_dBi/10);
usersInBeam = max(double(usersInBeam), 1);
targetCapacityPerUser_bps = targetSat * userDemand_bps * usersInBeam;
sinrReq = 2^(targetCapacityPerUser_bps / max(Buser, eps)) - 1;
channelGain = userLinkChannelGainPerWLocal(satGeom(iSat), b, P_users_km(:, iu), P, Gur_lin);
if channelGain <= 0 || ~isfinite(channelGain)
    Ptx_W = inf;
else
    Ptx_W = sinrReq * noisePower_W / channelGain;
end
end

function [P_native_sum_W, PuserTarget_W] = nativePowerReserveSumAtSatLocal(nativeList, iSat, b, ...
    targetSat, satGeom, P_users_km, P, userDemand_bps)
nNative = numel(nativeList);
PuserTarget_W = nan(nNative, 1);
if nNative == 0
    P_native_sum_W = 0;
    return;
end
for jj = 1:nNative
    iu = nativeList(jj);
    PuserTarget_W(jj) = transmitPowerForUserTargetSatLocal(iu, iSat, b, targetSat, nNative, ...
        satGeom, P_users_km, P, userDemand_bps);
end
if any(~isfinite(PuserTarget_W))
    P_native_sum_W = inf;
else
    P_native_sum_W = sum(PuserTarget_W);
end
end

function avgSat = meanNativeSatForTotalPowerLocal(nativeList, iSat, b, P_native_W, nNative, ...
    satGeom, P_users_km, P, userDemand_bps)
if nNative < 1 || ~isfinite(P_native_W) || P_native_W <= 0
    avgSat = 0;
    return;
end
PtxEach_W = P_native_W / nNative;
satVals = zeros(nNative, 1);
for jj = 1:nNative
    iu = nativeList(jj);
    satVals(jj) = userSatisfactionAtBeamLocal(iu, iSat, b, PtxEach_W, nNative, ...
        satGeom, P_users_km, P, userDemand_bps);
end
avgSat = mean(satVals);
end

function avgSat = meanRelaySatForRelayPowerLocal(relayList, iSat, b, P_relay_W, ...
    satGeom, P_users_km, P, userDemand_bps)
nRelay = numel(relayList);
if nRelay < 1
    avgSat = 1;
    return;
end
if ~isfinite(P_relay_W) || P_relay_W <= 0
    avgSat = 0;
    return;
end
PtxEach_W = P_relay_W / nRelay;
satVals = zeros(nRelay, 1);
for jj = 1:nRelay
    iu = relayList(jj);
    satVals(jj) = userSatisfactionAtBeamLocal(iu, iSat, b, PtxEach_W, nRelay, ...
        satGeom, P_users_km, P, userDemand_bps);
end
avgSat = mean(satVals);
end

function [x_W, PtxEach_W] = nativeTotalPowerForAverageSatLocal(nativeList, iSat, b, targetAvgSat, ...
    Pbeam, satGeom, P_users_km, P, userDemand_bps)
nNative = numel(nativeList);
if nNative == 0
    x_W = 0;
    PtxEach_W = 0;
    return;
end
targetAvgSat = max(0, min(1, double(targetAvgSat)));
if ~isfinite(Pbeam) || Pbeam <= 0
    x_W = inf;
    PtxEach_W = inf;
    return;
end
avgAtBeam = meanNativeSatForTotalPowerLocal(nativeList, iSat, b, Pbeam, nNative, ...
    satGeom, P_users_km, P, userDemand_bps);
if avgAtBeam < targetAvgSat - 1e-9
    x_W = inf;
    PtxEach_W = inf;
    return;
end
lo = 0;
hi = Pbeam;
for it = 1:64
    mid = 0.5 * (lo + hi);
    avgMid = meanNativeSatForTotalPowerLocal(nativeList, iSat, b, mid, nNative, ...
        satGeom, P_users_km, P, userDemand_bps);
    if avgMid >= targetAvgSat
        hi = mid;
    else
        lo = mid;
    end
end
x_W = hi;
PtxEach_W = x_W / nNative;
end

function plan = planHelperBeamRelayPowerSplitLocal(iSat, b, nativeList, relayList, Pbeam, ...
    satGeom, P_users_km, P, userDemand_bps, nativeAvgSatFloor, relayAvgSatTarget)
plan = struct('feasible', false, 'nativeMode', "", 'P_native_W', 0, 'P_relay_W', 0, ...
    'PuserNative_W', [], 'nativeList', nativeList, 'relayList', relayList);
nativeAvgSatFloor = max(0, min(1, double(nativeAvgSatFloor)));
relayAvgSatTarget = max(0, min(1, double(relayAvgSatTarget)));

if ~isfinite(Pbeam) || Pbeam <= 0
    return;
end

nNative = numel(nativeList);
nRelay = numel(relayList);
if nNative == 0
    plan.feasible = true;
    plan.nativeMode = "none";
    plan.P_native_W = 0;
    plan.P_relay_W = Pbeam;
    plan.PuserNative_W = zeros(0, 1);
    return;
end

[x1_W, Puser1_W] = nativePowerReserveSumAtSatLocal(nativeList, iSat, b, 1.0, ...
    satGeom, P_users_km, P, userDemand_bps);
useSat1 = isfinite(x1_W) && x1_W <= Pbeam + 1e-12;
if useSat1 && nRelay > 0
    y_W = Pbeam - x1_W;
    avgRelay = meanRelaySatForRelayPowerLocal(relayList, iSat, b, y_W, ...
        satGeom, P_users_km, P, userDemand_bps);
    useSat1 = avgRelay >= relayAvgSatTarget - 1e-9;
elseif useSat1 && nRelay == 0
    useSat1 = true;
end

if useSat1
    plan.feasible = true;
    plan.nativeMode = "perUserSat1";
    plan.P_native_W = x1_W;
    plan.P_relay_W = max(Pbeam - x1_W, 0);
    plan.PuserNative_W = Puser1_W;
    return;
end

[x9_W, PtxEach9_W] = nativeTotalPowerForAverageSatLocal(nativeList, iSat, b, nativeAvgSatFloor, ...
    Pbeam, satGeom, P_users_km, P, userDemand_bps);
if ~isfinite(x9_W) || x9_W > Pbeam + 1e-12
    return;
end
plan.feasible = true;
plan.nativeMode = "equalSplitAvgFloor";
plan.P_native_W = x9_W;
plan.P_relay_W = max(Pbeam - x9_W, 0);
plan.PuserNative_W = PtxEach9_W * ones(nNative, 1);
end

function split = buildBeamRelayPowerSplitLocal(iSat, b, userSatIdx, userBeamIdx, ...
    swapServiceMask, relayAssignedMask, relaySatIdx, relayBeamIdx, Pbeam, satGeom, P_users_km, P, ...
    userDemand_bps, nativeAvgSatFloor, relayAvgSatTarget)
nativeList = find(userSatIdx == iSat & userBeamIdx == b & ~swapServiceMask);
relayList = find(relayAssignedMask & relaySatIdx == iSat & relayBeamIdx == b);
nNative = numel(nativeList);
nRelay = numel(relayList);
split.byIu = containers.Map('KeyType', 'double', 'ValueType', 'double');

plan = planHelperBeamRelayPowerSplitLocal(iSat, b, nativeList, relayList, Pbeam, ...
    satGeom, P_users_km, P, userDemand_bps, nativeAvgSatFloor, relayAvgSatTarget);
if ~plan.feasible
    return;
end

if nNative > 0
    for jj = 1:nNative
        iu = nativeList(jj);
        Ptx_W = plan.PuserNative_W(jj);
        if ~isfinite(Ptx_W) || Ptx_W < 0
            continue;
        end
        split.byIu(iu) = userSatisfactionAtBeamLocal(iu, iSat, b, Ptx_W, nNative, ...
            satGeom, P_users_km, P, userDemand_bps);
    end
end

if nRelay > 0
    Ptx_relay_W = plan.P_relay_W / nRelay;
    for jj = 1:nRelay
        iu = relayList(jj);
        split.byIu(iu) = userSatisfactionAtBeamLocal(iu, iSat, b, Ptx_relay_W, nRelay, ...
            satGeom, P_users_km, P, userDemand_bps);
    end
end
end

function channelGain = userLinkChannelGainPerWLocal(satGeomOne, beamIdx, P_user_km, P, Gur_lin)
P_leo_km = satGeomOne.P_leo_km;
b_hat = satGeomOne.b_all(:,beamIdx);
c_axis = satGeomOne.c_axis;
v_user_km = P_user_km(:) - P_leo_km(:);
d_m = norm(v_user_km) * 1000;
if d_m < 1
    channelGain = 0;
    return;
end
d_hat = v_user_km / max(norm(v_user_km), eps);
t_axis = cross(c_axis, b_hat);
t_axis = t_axis / max(norm(t_axis), eps);
th_h = atan2d(dot(d_hat, c_axis), dot(d_hat, b_hat));
th_v = atan2d(dot(d_hat, t_axis), dot(d_hat, b_hat));
phi = hypot(th_h, th_v);
Gt_lin = max(P.A_fit * exp(P.beta_fit * phi), 1e-30);
pathGain = (P.lambda_m^2) / max((4*pi*d_m)^2, eps);
channelGain = Gt_lin * Gur_lin * pathGain;
end

function spare_W = helperBeamDonorSparePowerLocal(nativeList, iHelp, bH, nominalBeamPower_W, ...
    maxBeamPower_W, satGeom, P_users_km, P, userDemand_bps)
% nominalBeamPower_W: documented for callers (EPFD nominal); reserve uses maxBeamPower_W.
% With natives: spare = budget - sum(per-user min power for sat=1); sat=1 surplus excluded.
% No natives after swap: entire beam budget is spare.
if isempty(nativeList)
    spare_W = max(0, maxBeamPower_W);
    return;
end
[x1_W, ~] = nativePowerReserveSumAtSatLocal(nativeList, iHelp, bH, 1.0, satGeom, P_users_km, P, userDemand_bps);
if ~isfinite(x1_W)
    spare_W = 0;
else
    spare_W = max(maxBeamPower_W - x1_W, 0);
end
end

function [bestBeam, bestMetric] = bestCoveredBeamForUserLocal(satGeomOne, P_user_km, beamHalfEW_deg, beamHalfNS_deg)
Nbeam = size(satGeomOne.b_all, 2);
P_leo_km = satGeomOne.P_leo_km;
b_all = satGeomOne.b_all;
c_axis = satGeomOne.c_axis;
bestBeam = 0;
bestMetric = inf;
v_user_m = (P_user_km(:) - P_leo_km(:)) * 1000;
d_m = norm(v_user_m);
if d_m < 1
    return;
end
d_hat = v_user_m / d_m;
for b = 1:Nbeam
    b_hat = b_all(:,b);
    t_axis = cross(c_axis, b_hat);
    t_axis = t_axis / max(norm(t_axis), eps);
    th_h = atan2d(dot(d_hat, c_axis), dot(d_hat, b_hat));
    th_v = atan2d(dot(d_hat, t_axis), dot(d_hat, b_hat));
    if abs(th_h) > beamHalfEW_deg || abs(th_v) > beamHalfNS_deg
        continue;
    end
    metric = hypot(th_h / max(beamHalfEW_deg, eps), th_v / max(beamHalfNS_deg, eps));
    if metric < bestMetric
        bestMetric = metric;
        bestBeam = b;
    end
end
end

function bestSat = nearestSatelliteSubpointLocal(satGeom, userLat, userLon, candidateIdx)
bestSat = candidateIdx(1);
bestCentralAngle = inf;
for iSat = candidateIdx
    centralAngle = greatCircleDistanceDegLocal(userLat, userLon, satGeom(iSat).subLat, satGeom(iSat).subLon);
    if centralAngle < bestCentralAngle
        bestCentralAngle = centralAngle;
        bestSat = iSat;
    end
end
end

function d_deg = greatCircleDistanceDegLocal(lat1, lon1, lat2, lon2)
dlat = deg2rad(lat2 - lat1);
dlon = deg2rad(lon2 - lon1);
a = sin(dlat/2)^2 + cosd(lat1) * cosd(lat2) * sin(dlon/2)^2;
d_deg = rad2deg(2 * atan2(sqrt(a), sqrt(max(0, 1-a))));
end
