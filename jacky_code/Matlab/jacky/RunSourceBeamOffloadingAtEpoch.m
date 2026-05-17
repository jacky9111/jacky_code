function [ToffloadSummary, TiterationLog, TuserTransferLog, TfinalSystem, TfinalUser] = RunSourceBeamOffloadingAtEpoch(root, opts)
% RunSourceBeamOffloadingAtEpoch
% Single-epoch offloading simulation for one source satellite.

if nargin < 2 || isempty(opts)
    opts = struct();
end
opts = applyOffloadDefaults(opts);

sc = root.CurrentScenario;
here = fileparts(mfilename('fullpath'));
addpath(fullfile(here, '..', 'powertilt'));

satList = string(opts.satList(:));
geoList = string(opts.geoList(:));
sourceSatellite = string(opts.sourceSatellite);
gsName = char(string(opts.gsName));
tStr = char(string(opts.tStr));

gsObj = root.GetObjectFromPath(['*/Facility/' gsName]);
P_gs_km = facilityXYZ(gsObj);
[~, gsLon_deg] = facilityLatLon(gsObj);
[userNames, P_users_km] = userFacilitiesXYZ(sc, string(opts.userPrefix));
satGeom = buildSatelliteBeamGeometry(root, satList, tStr, offloadPitchOffsets(opts));
[P_geo_all, geoNames] = buildGeoReferencePoints(root, geoList, gsLon_deg, opts.useIdealGsoAtGs, tStr);

[userCountMat, userSatIdx, userBeamIdx] = assignUsersToNearestBeamCenter(satGeom, P_users_km, ...
    opts.beamHalfEW_deg, opts.beamHalfNS_deg, string(opts.prioritySatellite), ...
    opts.priorityCoverageFirst, opts.priorityBeamRange);

sourceSatIdx = find(satList == sourceSatellite, 1);
if isempty(sourceSatIdx)
    error('RunSourceBeamOffloadingAtEpoch:MissingSourceSatellite', 'Source satellite %s not found.', char(sourceSatellite));
end

state.userSatIdx = userSatIdx;
state.userBeamIdx = userBeamIdx;
state.originalUserSatIdx = userSatIdx;
state.originalUserBeamIdx = userBeamIdx;
state.originalSourceMask = userSatIdx == sourceSatIdx;
state.lockedBeamKeys = containers.Map('KeyType', 'char', 'ValueType', 'logical');

snapshot = recomputeSnapshot(state, satList, satGeom, P_users_km, P_gs_km, P_geo_all, geoNames, userNames, opts);

iter = 0;
maxIter = max(20, 8 * numel(userNames));
iterLog = struct('Iteration', {}, 'AggregateEPFD_dB_before', {}, 'AggregateEPFD_dB_after', {}, ...
    'SelectedSourceBeam', {}, 'SelectedSourceScore', {}, 'MovedUsers', {}, 'UsedSAHR', {}, 'Status', {});
transferLog = struct('Iteration', {}, 'UserId', {}, 'FromSat', {}, 'FromBeam', {}, 'ToSat', {}, 'ToBeam', {}, ...
    'MoveType', {}, 'Accepted', {}, 'UserSatisfactionAfter', {}, 'AggregateEPFD_dB_after', {});

while snapshot.aggregateEpfd_lin > snapshot.epfdThreshold_lin + 1e-12 && iter < maxIter
    iter = iter + 1;
    before_dB = 10*log10(max(snapshot.aggregateEpfd_lin, 1e-300));
    sourceDistress = sourceBeamDistressTable(snapshot.Tdistress, sourceSatellite, state.lockedBeamKeys);
    if isempty(sourceDistress)
        iterLog(end+1) = makeIterLog(iter, before_dB, before_dB, NaN, NaN, 0, false, "no_source_beam"); %#ok<AGROW>
        break;
    end

    movedThisIter = false;
    usedSAHR = false;
    after_dB = before_dB;
    chosenBeam = NaN;
    chosenScore = NaN;
    movedCount = 0;

    for iBeam = 1:height(sourceDistress)
        chosenBeam = double(sourceDistress.beam(iBeam));
        chosenScore = double(sourceDistress.beam_distress_score(iBeam));
        sourceUserIdx = find(state.userSatIdx == sourceSatIdx & state.userBeamIdx == chosenBeam);
        if isempty(sourceUserIdx)
            state.lockedBeamKeys(beamKey(sourceSatellite, chosenBeam)) = true;
            continue;
        end

        helperTable = buildHelperCandidateTable(sourceUserIdx, snapshot, state, satList, satGeom, P_users_km, opts);
        if isempty(helperTable)
            state.lockedBeamKeys(beamKey(sourceSatellite, chosenBeam)) = true;
            continue;
        end

        userOrder = orderUsersByBestHelper(helperTable);
        for kUser = 1:numel(userOrder)
            iu = userOrder(kUser);
            acceptedViaSAHR = false;
            [stateCandidate, snapshotCandidate, accepted, transferEntry] = ...
                tryOffloadUser(iu, helperTable, snapshot, state, satList, satGeom, P_users_km, P_gs_km, P_geo_all, geoNames, userNames, opts, iter);
            if ~accepted
                [stateCandidate, snapshotCandidate, accepted, sahrTransfers] = ...
                    runTargetedSahrAndRetry(iu, chosenBeam, chosenScore, helperTable, snapshot, state, satList, satGeom, P_users_km, P_gs_km, P_geo_all, geoNames, userNames, opts, iter);
                if accepted
                    acceptedViaSAHR = true;
                    usedSAHR = true;
                    for m = 1:numel(sahrTransfers)
                        transferLog(end+1) = sahrTransfers(m); %#ok<AGROW>
                    end
                end
            end

            if accepted
                state = stateCandidate;
                snapshot = snapshotCandidate;
                movedThisIter = true;
                movedCount = movedCount + 1;
                after_dB = 10*log10(max(snapshot.aggregateEpfd_lin, 1e-300));
                if ~acceptedViaSAHR
                    transferLog(end+1) = transferEntry; %#ok<AGROW>
                end
            end

            if snapshot.aggregateEpfd_lin <= snapshot.epfdThreshold_lin + 1e-12
                break;
            end
        end

        if movedThisIter
            break;
        end

        state.lockedBeamKeys(beamKey(sourceSatellite, chosenBeam)) = true;
    end

    status = "no_improvement";
    if movedThisIter
        status = "moved";
    end
    iterLog(end+1) = makeIterLog(iter, before_dB, after_dB, chosenBeam, chosenScore, movedCount, usedSAHR, status); %#ok<AGROW>

    if ~movedThisIter
        break;
    end
end

TfinalSystem = snapshot.Tsystem;
TfinalUser = snapshot.Tuser;
TiterationLog = struct2table(iterLog);
TuserTransferLog = struct2table(transferLog);
if isempty(TuserTransferLog)
    TuserTransferLog = table();
end
ToffloadSummary = buildOffloadSummary(state, snapshot, satList, sourceSatIdx, sourceSatellite, iter, maxIter);

writeOffloadOutputs(opts.resultExcelPath, ToffloadSummary, TiterationLog, TuserTransferLog, TfinalSystem, TfinalUser, state, satList, sourceSatIdx, userNames);
fprintf('Saved offloading Excel: %s\n', char(string(opts.resultExcelPath)));
end

function opts = applyOffloadDefaults(opts)
if ~isfield(opts, 'satList') || isempty(opts.satList), error('opts.satList is required.'); end
if ~isfield(opts, 'geoList') || isempty(opts.geoList), error('opts.geoList is required.'); end
if ~isfield(opts, 'gsName') || strlength(string(opts.gsName)) == 0, error('opts.gsName is required.'); end
if ~isfield(opts, 'tStr') || strlength(string(opts.tStr)) == 0, error('opts.tStr is required.'); end
if ~isfield(opts, 'sourceSatellite') || strlength(string(opts.sourceSatellite)) == 0, opts.sourceSatellite = "P03_S01"; end
if ~isfield(opts, 'userPrefix') || strlength(string(opts.userPrefix)) == 0, opts.userPrefix = "User_"; end
if ~isfield(opts, 'beamHalfEW_deg') || ~isfinite(opts.beamHalfEW_deg), opts.beamHalfEW_deg = 24.5; end
if ~isfield(opts, 'beamHalfNS_deg') || ~isfinite(opts.beamHalfNS_deg), opts.beamHalfNS_deg = 25/16; end
if ~isfield(opts, 'allocatePowerByUsers') || isempty(opts.allocatePowerByUsers), opts.allocatePowerByUsers = true; end
if ~isfield(opts, 'limitPowerToDemand') || isempty(opts.limitPowerToDemand), opts.limitPowerToDemand = true; end
if ~isfield(opts, 'enforceBeamPowerMax') || isempty(opts.enforceBeamPowerMax), opts.enforceBeamPowerMax = false; end
if ~isfield(opts, 'maxBeamPower_W') || ~isfinite(opts.maxBeamPower_W), opts.maxBeamPower_W = 1.05; end
if ~isfield(opts, 'prioritySatellite'), opts.prioritySatellite = ""; end
if ~isfield(opts, 'priorityCoverageFirst') || isempty(opts.priorityCoverageFirst), opts.priorityCoverageFirst = false; end
if ~isfield(opts, 'priorityBeamRange') || isempty(opts.priorityBeamRange), opts.priorityBeamRange = 1:16; end
if ~isfield(opts, 'userDemand_Mbps') || ~isfinite(opts.userDemand_Mbps), opts.userDemand_Mbps = 25; end
if ~isfield(opts, 'useIdealGsoAtGs') || isempty(opts.useIdealGsoAtGs), opts.useIdealGsoAtGs = false; end
if ~isfield(opts, 'distressXi1') || ~isfinite(opts.distressXi1), opts.distressXi1 = 0.7; end
if ~isfield(opts, 'distressXi2') || ~isfinite(opts.distressXi2), opts.distressXi2 = 0.3; end
if ~isfield(opts, 'helperEta1') || ~isfinite(opts.helperEta1), opts.helperEta1 = 0.5; end
if ~isfield(opts, 'helperEta2') || ~isfinite(opts.helperEta2), opts.helperEta2 = 0.3; end
if ~isfield(opts, 'helperEta3') || ~isfinite(opts.helperEta3), opts.helperEta3 = 0.2; end
if ~isfield(opts, 'minAcceptSatisfaction') || ~isfinite(opts.minAcceptSatisfaction), opts.minAcceptSatisfaction = 0.2; end
if ~isfield(opts, 'sourceSafeBeamCount') || ~isfinite(opts.sourceSafeBeamCount), opts.sourceSafeBeamCount = 3; end
if ~isfield(opts, 'resultExcelPath') || strlength(string(opts.resultExcelPath)) == 0
    opts.resultExcelPath = fullfile(fileparts(mfilename('fullpath')), '..', '..', 'Matlab_data', 'SourceOffloading_CurrentEpoch.xlsx');
end
if isfield(opts, 'params') && ~isempty(opts.params)
    opts.params = opts.params;
else
    opts.params = ku_epfd_params();
end
opts.params = ensureOffloadParamDefaults(opts.params);
opts.distressXi1 = max(double(opts.distressXi1), 0);
opts.distressXi2 = max(double(opts.distressXi2), 0);
s = opts.distressXi1 + opts.distressXi2;
opts.distressXi1 = opts.distressXi1 / max(s, eps);
opts.distressXi2 = opts.distressXi2 / max(s, eps);
opts.helperEta1 = max(double(opts.helperEta1), 0);
opts.helperEta2 = max(double(opts.helperEta2), 0);
opts.helperEta3 = max(double(opts.helperEta3), 0);
s = opts.helperEta1 + opts.helperEta2 + opts.helperEta3;
opts.helperEta1 = opts.helperEta1 / max(s, eps);
opts.helperEta2 = opts.helperEta2 / max(s, eps);
opts.helperEta3 = opts.helperEta3 / max(s, eps);
end

function P = ensureOffloadParamDefaults(P)
if ~isfield(P, 'Nbeam'), P.Nbeam = 16; end
if ~isfield(P, 'useEIRPDensityModel'), P.useEIRPDensityModel = true; end
if ~isfield(P, 'EIRPdens_dBW_per_4kHz'), P.EIRPdens_dBW_per_4kHz = -13.4; end
if ~isfield(P, 'B_Hz'), P.B_Hz = 250e6; end
if ~isfield(P, 'kB'), P.kB = 1.380649e-23; end
if ~isfield(P, 'user_noise_temp_K'), P.user_noise_temp_K = 240; end
if ~isfield(P, 'Ptotal_W'), P.Ptotal_W = 16.8; end
if ~isfield(P, 'BWref_Hz'), P.BWref_Hz = 4e3; end
if ~isfield(P, 'GSO_Gmax_dBi'), P.GSO_Gmax_dBi = 0; end
if ~isfield(P, 'GS_LEO_Gmax_dBi'), P.GS_LEO_Gmax_dBi = 0; end
if ~isfield(P, 'A_fit'), P.A_fit = 1; end
if ~isfield(P, 'beta_fit'), P.beta_fit = 0; end
if ~isfield(P, 'lambda_m'), P.lambda_m = 0.025; end
if ~isfield(P, 'GSO_D_m'), P.GSO_D_m = 1; end
if ~isfield(P, 'EPFD_thr_dB'), P.EPFD_thr_dB = -180; end
end

function pitchOffsets_deg = offloadPitchOffsets(opts)
pitchOffsets_deg = (8.5 - (1:16)) * (2 * opts.beamHalfNS_deg);
end

function [P_geo_all, geoNames] = buildGeoReferencePoints(root, geoList, gsLon_deg, useIdealGsoAtGs, tStr)
geoNames = string(geoList(:));
P_geo_all = zeros(3, numel(geoNames));
for j = 1:numel(geoNames)
    if useIdealGsoAtGs
        P_geo_all(:,j) = idealGsoXYZFromLongitude(gsLon_deg);
    else
        geoObj = root.GetObjectFromPath(['*/Satellite/' char(geoNames(j))]);
        geoDP = geoObj.DataProviders.Item('Cartesian Position').Group.Item('Fixed');
        P_geo_all(:,j) = stkXYZ(geoDP, tStr);
    end
end
end

function snapshot = recomputeSnapshot(state, satList, satGeom, P_users_km, P_gs_km, P_geo_all, geoNames, userNames, opts)
P = opts.params;
userDemand_bps = double(opts.userDemand_Mbps) * 1e6;
[beamRequiredPower_W, beamDemand_bps] = computeBeamDemandLimitedPower(satGeom, P_users_km, state.userSatIdx, state.userBeamIdx, userDemand_bps, P);
[PbeamActualMat_W, satRemaining_W, beamPowerSatisfactionByBeam] = allocateBeamPowers(state.userSatIdx, state.userBeamIdx, satList, satGeom, beamRequiredPower_W, opts);
Tuser = buildCurrentUserTable(string(opts.tStr), userNames, satList, satGeom, state.userSatIdx, state.userBeamIdx, ...
    P_users_km, userDemand_bps, countUsersByBeam(state.userSatIdx, state.userBeamIdx, numel(satList), 16), PbeamActualMat_W, P, opts);
Tdetail = buildCurrentDetailTable(string(opts.tStr), string(opts.gsName), geoNames, satList, satGeom, state.userSatIdx, state.userBeamIdx, ...
    P_users_km, P_gs_km, P_geo_all, beamRequiredPower_W, beamDemand_bps, PbeamActualMat_W, satRemaining_W, beamPowerSatisfactionByBeam, P, opts);
Tsystem = buildSystemStateTableLocal(Tdetail, Tuser);
Tdistress = buildBeamDistressScoreTableLocal(Tdetail, P, opts);
geoMask = string(Tdetail.GeoName) == geoNames(1) & Tdetail.ActiveBeam > 0;
aggregateEpfd_lin = sum(Tdetail.EPFD_lin(geoMask));
snapshot.Tuser = Tuser;
snapshot.Tdetail = Tdetail;
snapshot.Tsystem = Tsystem;
snapshot.Tdistress = Tdistress;
snapshot.PbeamActualMat_W = PbeamActualMat_W;
snapshot.beamRequiredPower_W = beamRequiredPower_W;
snapshot.satRemaining_W = satRemaining_W;
snapshot.aggregateEpfd_lin = aggregateEpfd_lin;
snapshot.epfdThreshold_lin = 10^(double(P.EPFD_thr_dB) / 10);
end

function [PbeamActualMat_W, satRemaining_W, beamPowerSatisfactionByBeam] = allocateBeamPowers(userSatIdx, userBeamIdx, satList, satGeom, beamRequiredPower_W, opts)
P = opts.params;
Nbeam = 16;
Nsat = numel(satList);
PbeamActualMat_W = zeros(Nsat, Nbeam);
satRemaining_W = zeros(Nsat, 1);
beamPowerSatisfactionByBeam = nan(Nsat, Nbeam);
userCountMat = countUsersByBeam(userSatIdx, userBeamIdx, Nsat, Nbeam);
Pbeam_W = P.Ptotal_W / Nbeam;

for iSat = 1:Nsat
    userCountByBeam = userCountMat(iSat,:).';
    totalUsersAssigned = sum(userCountByBeam);
    activeByBeam = userCountByBeam > 0;
    loadShareByBeam = zeros(Nbeam,1);
    if totalUsersAssigned > 0
        loadShareByBeam = userCountByBeam / totalUsersAssigned;
    end
    PbeamActualByBeam = zeros(Nbeam,1);
    beamSatByBeam = nan(Nbeam,1);
    for bb = 1:Nbeam
        if opts.allocatePowerByUsers
            PbeamActualByBeam(bb) = P.Ptotal_W * loadShareByBeam(bb);
            if opts.limitPowerToDemand && activeByBeam(bb)
                PbeamActualByBeam(bb) = min(PbeamActualByBeam(bb), beamRequiredPower_W(iSat,bb));
            end
        else
            PbeamActualByBeam(bb) = Pbeam_W;
            if opts.limitPowerToDemand && activeByBeam(bb)
                PbeamActualByBeam(bb) = min(PbeamActualByBeam(bb), beamRequiredPower_W(iSat,bb));
            end
        end
        if opts.enforceBeamPowerMax
            PbeamActualByBeam(bb) = min(PbeamActualByBeam(bb), opts.maxBeamPower_W);
        end
    end
    if opts.limitPowerToDemand
        [PbeamActualByBeam, beamSatByBeam, satRemaining_W(iSat)] = redistributeSatelliteRemainingPowerLocal( ...
            PbeamActualByBeam, beamRequiredPower_W(iSat,:).', userCountByBeam, activeByBeam, P.Ptotal_W, opts.enforceBeamPowerMax, opts.maxBeamPower_W);
    else
        satRemaining_W(iSat) = max(P.Ptotal_W - sum(PbeamActualByBeam), 0);
        valid = activeByBeam & beamRequiredPower_W(iSat,:).' > 0;
        beamSatByBeam(valid) = min(PbeamActualByBeam(valid) ./ max(beamRequiredPower_W(iSat,valid).', eps), 1);
    end
    PbeamActualMat_W(iSat,:) = PbeamActualByBeam.';
    beamPowerSatisfactionByBeam(iSat,:) = beamSatByBeam.';
end
end

function sourceDistress = sourceBeamDistressTable(Tdistress, sourceSatellite, lockedBeamKeys)
sourceDistress = table();
if isempty(Tdistress)
    return;
end
mask = string(Tdistress.sat) == sourceSatellite & isfinite(Tdistress.beam_distress_score);
sourceDistress = Tdistress(mask,:);
if isempty(sourceDistress)
    return;
end
keep = true(height(sourceDistress),1);
for i = 1:height(sourceDistress)
    keep(i) = ~isKey(lockedBeamKeys, beamKey(sourceDistress.sat(i), sourceDistress.beam(i)));
end
sourceDistress = sourceDistress(keep,:);
if isempty(sourceDistress)
    return;
end
sourceDistress = sortrows(sourceDistress, 'beam_distress_score', 'descend');
end

function helperTable = buildHelperCandidateTable(sourceUserIdx, snapshot, state, satList, satGeom, P_users_km, opts)
helperTable = table();
if isempty(sourceUserIdx)
    return;
end
Nmax = max(countUsersByBeam(state.userSatIdx, state.userBeamIdx, numel(satList), 16), [], 'all');
if Nmax <= 0, Nmax = 1; end
P = opts.params;
Buser = P.B_Hz;
noisePower_W = P.kB * P.user_noise_temp_K * Buser;
Gur_lin = 10^(P.GS_LEO_Gmax_dBi/10);
rows = struct('userIdx', {}, 'helperSatIdx', {}, 'helperBeam', {}, 'serviceQuality', {}, 'beamLoadNorm', {}, 'satAvailability', {}, 'utility', {});

for iu = sourceUserIdx(:).'
    P_user_km = P_users_km(:,iu);
    demandMbps = double(opts.userDemand_Mbps);
    for iSat = 1:numel(satList)
        if iSat == state.userSatIdx(iu)
            continue;
        end
        [bestBeam, ~] = bestCoveredBeamForUser(satGeom(iSat), P_user_km, opts.beamHalfEW_deg, opts.beamHalfNS_deg);
        if bestBeam < 1
            continue;
        end
        beamLoadUsers = sum(state.userSatIdx == iSat & state.userBeamIdx == bestBeam);
        beamLoadNorm = (beamLoadUsers + 1) / Nmax;
        satAvailability = snapshot.satRemaining_W(iSat) / max(opts.params.Ptotal_W, eps);
        totalUsersOnSat = sum(state.userSatIdx == iSat);
        helperUsers = beamLoadUsers + 1;
        if opts.allocatePowerByUsers
            Ptx_W = opts.params.Ptotal_W * helperUsers / max(totalUsersOnSat + 1, 1);
        else
            Ptx_W = opts.params.Ptotal_W / 16;
        end
        if opts.enforceBeamPowerMax
            Ptx_W = min(Ptx_W, opts.maxBeamPower_W);
        end
        channelGain = userLinkChannelGainPerW(satGeom(iSat), bestBeam, P_user_km, opts.params, Gur_lin);
        sinr = Ptx_W * channelGain / max(noisePower_W, eps);
        rateMbps = Buser * log2(1 + sinr) / helperUsers / 1e6;
        serviceQuality = min(rateMbps / max(demandMbps, eps), 1);
        utility = opts.helperEta1 * serviceQuality - opts.helperEta2 * beamLoadNorm + opts.helperEta3 * satAvailability;
        rows(end+1).userIdx = iu; %#ok<AGROW>
        rows(end).helperSatIdx = iSat;
        rows(end).helperBeam = bestBeam;
        rows(end).serviceQuality = serviceQuality;
        rows(end).beamLoadNorm = beamLoadNorm;
        rows(end).satAvailability = satAvailability;
        rows(end).utility = utility;
    end
end

if isempty(rows)
    return;
end
helperTable = struct2table(rows);
helperTable = sortrows(helperTable, {'userIdx','utility'}, {'ascend','descend'});
end

function userOrder = orderUsersByBestHelper(helperTable)
userU = unique(helperTable.userIdx, 'stable');
bestUtility = nan(numel(userU),1);
for i = 1:numel(userU)
    bestUtility(i) = max(helperTable.utility(helperTable.userIdx == userU(i)));
end
[~, order] = sort(bestUtility, 'descend');
userOrder = userU(order);
end

function [stateOut, snapshotOut, accepted, transferEntry] = tryOffloadUser(iu, helperTable, snapshot, state, satList, satGeom, P_users_km, P_gs_km, P_geo_all, geoNames, userNames, opts, iter)
stateOut = state;
snapshotOut = snapshot;
accepted = false;
transferEntry = emptyTransferEntry();
cands = helperTable(helperTable.userIdx == iu, :);
if isempty(cands)
    return;
end
for k = 1:height(cands)
    tempState = state;
    fromSatIdx = tempState.userSatIdx(iu);
    fromBeam = tempState.userBeamIdx(iu);
    tempState.userSatIdx(iu) = cands.helperSatIdx(k);
    tempState.userBeamIdx(iu) = cands.helperBeam(k);
    tempSnapshot = recomputeSnapshot(tempState, satList, satGeom, P_users_km, P_gs_km, P_geo_all, geoNames, userNames, opts);
    userMask = string(tempSnapshot.Tuser.user_id) == string(userNames(iu));
    if ~any(userMask)
        continue;
    end
    userSatVal = tempSnapshot.Tuser.satisfaction(find(userMask, 1));
    if userSatVal + 1e-12 < opts.minAcceptSatisfaction
        continue;
    end
    if tempSnapshot.aggregateEpfd_lin > snapshot.aggregateEpfd_lin + 1e-12
        continue;
    end
    accepted = true;
    stateOut = tempState;
    snapshotOut = tempSnapshot;
    transferEntry = makeTransferEntry(iter, userNames(iu), satList(fromSatIdx), fromBeam, satList(cands.helperSatIdx(k)), cands.helperBeam(k), ...
        "helper", true, userSatVal, 10*log10(max(tempSnapshot.aggregateEpfd_lin, 1e-300)));
    return;
end
end

function [stateOut, snapshotOut, accepted, transferEntries] = runTargetedSahrAndRetry(iuSource, sourceBeam, sourceScore, helperTable, snapshot, state, satList, satGeom, P_users_km, P_gs_km, P_geo_all, geoNames, userNames, opts, iter)
stateOut = state;
snapshotOut = snapshot;
accepted = false;
transferEntries = repmat(emptyTransferEntry(), 0, 1);
sourceSatellite = string(opts.sourceSatellite);
sourceDistress = sourceBeamDistressTable(snapshot.Tdistress, sourceSatellite, containers.Map('KeyType', 'char', 'ValueType', 'logical'));
safeRows = sourceDistress(double(sourceDistress.beam) ~= sourceBeam, :);
if isempty(safeRows)
    return;
end
safeRows = sortrows(safeRows, 'beam_distress_score', 'ascend');
safeRows = safeRows(1:min(height(safeRows), round(opts.sourceSafeBeamCount)), :);
sourceSatIdx = find(satList == sourceSatellite, 1);

helperUserIdx = find(state.userSatIdx ~= sourceSatIdx);
for iSafe = 1:height(safeRows)
    safeBeam = double(safeRows.beam(iSafe));
    for iu = helperUserIdx(:).'
        [bestBeam, ~] = bestCoveredBeamForUser(satGeom(sourceSatIdx), P_users_km(:,iu), opts.beamHalfEW_deg, opts.beamHalfNS_deg);
        if bestBeam ~= safeBeam
            continue;
        end
        tempState = state;
        fromSatIdx = tempState.userSatIdx(iu);
        fromBeam = tempState.userBeamIdx(iu);
        tempState.userSatIdx(iu) = sourceSatIdx;
        tempState.userBeamIdx(iu) = safeBeam;
        tempSnapshot = recomputeSnapshot(tempState, satList, satGeom, P_users_km, P_gs_km, P_geo_all, geoNames, userNames, opts);
        userMask = string(tempSnapshot.Tuser.user_id) == string(userNames(iu));
        if ~any(userMask)
            continue;
        end
        movedUserSat = tempSnapshot.Tuser.satisfaction(find(userMask,1));
        if movedUserSat + 1e-12 < opts.minAcceptSatisfaction
            continue;
        end
        newSafeScore = getBeamDistressScore(tempSnapshot.Tdistress, sourceSatellite, safeBeam);
        if newSafeScore > sourceScore + 1e-12
            continue;
        end
        state = tempState;
        snapshot = tempSnapshot;
        transferEntries(end+1) = makeTransferEntry(iter, userNames(iu), satList(fromSatIdx), fromBeam, satList(sourceSatIdx), safeBeam, ...
            "sahr_rebalance", true, movedUserSat, 10*log10(max(snapshot.aggregateEpfd_lin, 1e-300))); %#ok<AGROW>
        [stateOut, snapshotOut, accepted, transferEntry] = tryOffloadUser(iuSource, helperTable, snapshot, state, satList, satGeom, P_users_km, P_gs_km, P_geo_all, geoNames, userNames, opts, iter);
        if accepted
            transferEntries(end+1) = transferEntry; %#ok<AGROW>
            return;
        end
    end
end
stateOut = state;
snapshotOut = snapshot;
end

function score = getBeamDistressScore(Tdistress, satName, beamIdx)
score = inf;
if isempty(Tdistress)
    return;
end
mask = string(Tdistress.sat) == string(satName) & double(Tdistress.beam) == double(beamIdx);
if any(mask)
    score = double(Tdistress.beam_distress_score(find(mask,1)));
end
end

function logEntry = makeIterLog(iter, before_dB, after_dB, beamIdx, score, movedUsers, usedSAHR, status)
logEntry.Iteration = iter;
logEntry.AggregateEPFD_dB_before = before_dB;
logEntry.AggregateEPFD_dB_after = after_dB;
logEntry.SelectedSourceBeam = beamIdx;
logEntry.SelectedSourceScore = score;
logEntry.MovedUsers = movedUsers;
logEntry.UsedSAHR = double(usedSAHR);
logEntry.Status = string(status);
end

function entry = emptyTransferEntry()
entry.Iteration = NaN;
entry.UserId = "";
entry.FromSat = "";
entry.FromBeam = NaN;
entry.ToSat = "";
entry.ToBeam = NaN;
entry.MoveType = "";
entry.Accepted = 0;
entry.UserSatisfactionAfter = NaN;
entry.AggregateEPFD_dB_after = NaN;
end

function entry = makeTransferEntry(iter, userId, fromSat, fromBeam, toSat, toBeam, moveType, accepted, satAfter, aggAfter)
entry = emptyTransferEntry();
entry.Iteration = iter;
entry.UserId = string(userId);
entry.FromSat = string(fromSat);
entry.FromBeam = double(fromBeam);
entry.ToSat = string(toSat);
entry.ToBeam = double(toBeam);
entry.MoveType = string(moveType);
entry.Accepted = double(accepted);
entry.UserSatisfactionAfter = double(satAfter);
entry.AggregateEPFD_dB_after = double(aggAfter);
end

function Tsummary = buildOffloadSummary(state, snapshot, satList, sourceSatIdx, sourceSatellite, iter, maxIter)
origSourceUsers = find(state.originalSourceMask);
currentOnSource = sum(state.userSatIdx(origSourceUsers) == sourceSatIdx);
transferredOut = numel(origSourceUsers) - currentOnSource;
agg_dB = 10*log10(max(snapshot.aggregateEpfd_lin, 1e-300));
isLegal = double(snapshot.aggregateEpfd_lin <= snapshot.epfdThreshold_lin + 1e-12);
Tsummary = table(string(optsafe(sourceSatellite)), numel(origSourceUsers), transferredOut, currentOnSource, ...
    agg_dB, 10*log10(max(snapshot.epfdThreshold_lin, 1e-300)), isLegal, iter, maxIter, ...
    'VariableNames', {'source_sat','original_source_users','transferred_out_users','remaining_on_source', ...
    'aggregate_epfd_dB','epfd_limit_dB','epfd_legal','iterations_used','iterations_cap'});
end

function writeOffloadOutputs(excelPath, Tsummary, TiterationLog, Ttransfer, Tsystem, Tuser, state, satList, sourceSatIdx, userNames)
outDir = fileparts(char(string(excelPath)));
if ~isempty(outDir) && ~exist(outDir, 'dir')
    mkdir(outDir);
end
if exist(char(string(excelPath)), 'file')
    delete(char(string(excelPath)));
end
writetable(Tsummary, char(string(excelPath)), 'Sheet', 'Summary');
writetable(TiterationLog, char(string(excelPath)), 'Sheet', 'Iteration_Log');
writetable(Ttransfer, char(string(excelPath)), 'Sheet', 'Transfer_Log');
writetable(Tsystem, char(string(excelPath)), 'Sheet', 'Final_System');
writetable(Tuser, char(string(excelPath)), 'Sheet', 'Final_User');
writetable(buildOriginalSourceOutcomeTable(state, satList, sourceSatIdx, userNames), char(string(excelPath)), 'Sheet', 'Original_Source_User_Outcome');
end

function Tout = buildOriginalSourceOutcomeTable(state, satList, sourceSatIdx, userNames)
idx = find(state.originalSourceMask);
user_id = string(userNames(idx));
original_sat = repmat(string(satList(sourceSatIdx)), numel(idx), 1);
original_beam = state.originalUserBeamIdx(idx);
final_sat = string(satList(state.userSatIdx(idx)));
final_beam = state.userBeamIdx(idx);
transferred = double(state.userSatIdx(idx) ~= sourceSatIdx);
Tout = table(user_id, original_sat, original_beam, final_sat, final_beam, transferred);
end

function x = optsafe(x)
x = string(x);
end

function userCountMat = countUsersByBeam(userSatIdx, userBeamIdx, Nsat, Nbeam)
userCountMat = zeros(Nsat, Nbeam);
for iu = 1:numel(userSatIdx)
    iSat = userSatIdx(iu);
    b = userBeamIdx(iu);
    if iSat >= 1 && iSat <= Nsat && b >= 1 && b <= Nbeam
        userCountMat(iSat,b) = userCountMat(iSat,b) + 1;
    end
end
end

function Tuser = buildCurrentUserTable(tStr, userNames, satList, satGeom, userSatIdx, userBeamIdx, P_users_km, userDemand_bps, userCountMat, PbeamActualMat_W, P, opts)
Nuser = numel(userNames);
time = repmat(string(tStr), Nuser, 1);
user_id = string(userNames(:));
sat = strings(Nuser,1);
beam = nan(Nuser,1);
demand_Mbps = repmat(userDemand_bps / 1e6, Nuser, 1);
rate_Mbps = zeros(Nuser,1);
satisfaction = zeros(Nuser,1);
covered_by_helpers = zeros(Nuser,1);
distress_risk = zeros(Nuser,1);
Buser = P.B_Hz;
noisePower_W = P.kB * P.user_noise_temp_K * Buser;
Gur_lin = 10^(P.GS_LEO_Gmax_dBi/10);
for iu = 1:Nuser
    iSat = userSatIdx(iu);
    b = userBeamIdx(iu);
    helperCount = countHelperCoverageLocal(satGeom, P_users_km(:,iu), iSat, b, opts.beamHalfEW_deg, opts.beamHalfNS_deg);
    covered_by_helpers(iu) = double(helperCount > 0);
    if iSat < 1 || b < 1
        distress_risk(iu) = 1;
        continue;
    end
    sat(iu) = satList(iSat);
    beam(iu) = b;
    channelGain = userLinkChannelGainPerW(satGeom(iSat), b, P_users_km(:,iu), P, Gur_lin);
    sig = PbeamActualMat_W(iSat,b) * channelGain;
    sinr = sig / max(noisePower_W, eps);
    cinst_bps = Buser * log2(1 + sinr);
    usersInBeam = max(userCountMat(iSat,b), 1);
    rate_Mbps(iu) = cinst_bps / usersInBeam / 1e6;
    satisfaction(iu) = min(rate_Mbps(iu) / max(demand_Mbps(iu), eps), 1);
    distress_risk(iu) = double(satisfaction(iu) < 1 && covered_by_helpers(iu) == 0);
end
Tuser = table(time, user_id, sat, beam, demand_Mbps, rate_Mbps, satisfaction, covered_by_helpers, distress_risk);
end

function Tdetail = buildCurrentDetailTable(tStr, gsName, geoNames, satList, satGeom, userSatIdx, userBeamIdx, P_users_km, P_gs_km, P_geo_all, beamRequiredPower_W, beamDemand_bps, PbeamActualMat_W, satRemaining_W, beamPowerSatisfactionByBeam, P, opts)
Nbeam = 16;
userCountMat = countUsersByBeam(userSatIdx, userBeamIdx, numel(satList), Nbeam);
Gmax_lin = 10^(P.GSO_Gmax_dBi/10);
Gt_max_lin = max(P.A_fit, eps);
rows = struct('Time', {}, 'GSName', {}, 'GeoName', {}, 'Satellite', {}, 'Plane', {}, 'Beam', {}, ...
    'PowerModel', {}, 'Pbeam_W', {}, 'SatelliteRemainingPower_W', {}, 'BackoffApplied', {}, 'BackoffRank', {}, ...
    'PowerReturned_W', {}, 'EPFD_lin_initial', {}, 'AggregateEPFD_before_lin', {}, 'AggregateEPFD_after_lin', {}, ...
    'ActiveBeam', {}, 'UserCount', {}, 'LoadShare', {}, 'UserDemand_Mbps', {}, 'BeamDemand_Mbps', {}, ...
    'PbeamDemandLimited_W', {}, 'PbeamRequired_W', {}, 'BeamPowerSatisfaction', {}, 'EPFD_dB', {}, 'EPFD_lin', {}, ...
    'InBeam', {}, 'Elevation_deg', {}, 'PhiT_deg', {}, 'Alpha_deg', {}, 'Distance_km', {}, 'BeamCenterLat_deg', {}, 'BeamCenterLon_deg', {});

for iSat = 1:numel(satList)
    satName = char(satList(iSat));
    P_leo_km = satGeom(iSat).P_leo_km;
    b_all = satGeom(iSat).b_all;
    c_axis = satGeom(iSat).c_axis;
    beamLat = satGeom(iSat).beamLat;
    beamLon = satGeom(iSat).beamLon;
    userCountByBeam = userCountMat(iSat,:).';
    totalUsersAssigned = sum(userCountByBeam);
    loadShareByBeam = zeros(Nbeam,1);
    if totalUsersAssigned > 0
        loadShareByBeam = userCountByBeam / totalUsersAssigned;
    end
    for b = 1:Nbeam
        b_hat = b_all(:,b);
        t_axis = cross(c_axis, b_hat);
        t_axis = t_axis / max(norm(t_axis), eps);
        activeBeamNow = userCountByBeam(b) > 0;
        PbeamActual_W = PbeamActualMat_W(iSat,b);
        for j = 1:numel(geoNames)
            v_gs_m = (P_gs_km - P_leo_km) * 1000;
            d_m = norm(v_gs_m);
            if d_m < 1 || ~activeBeamNow || PbeamActual_W <= 0
                epfdLin = 0;
                phit = NaN;
                alpha = NaN;
                inBeamNow = NaN;
            else
                d_hat = v_gs_m / d_m;
                th_h = atan2d(dot(d_hat, c_axis), dot(d_hat, b_hat));
                th_v = atan2d(dot(d_hat, t_axis), dot(d_hat, b_hat));
                inBeamNow = gsInBeamFootprint(th_h, th_v, opts.beamHalfEW_deg, opts.beamHalfNS_deg, P);
                phit = angleDegLocal(b_hat, d_hat);
                Gt_lin = max(P.A_fit * exp(P.beta_fit * phit), 1e-30);
                alpha = angleDegLocal(P_leo_km - P_gs_km, P_geo_all(:,j) - P_gs_km);
                Gr_dBi = gso_rx_gain_itu1428(alpha, P.GSO_D_m, P.lambda_m);
                Gr_lin = 10^(Gr_dBi/10);
                epfdLin = (PbeamActual_W / P.BWref_Hz) * (Gt_lin/(4*pi*d_m^2)) * (Gr_lin/Gmax_lin);
            end
            parts = split(string(satName), "_");
            rows(end+1).Time = string(tStr); %#ok<AGROW>
            rows(end).GSName = string(gsName);
            rows(end).GeoName = geoNames(j);
            rows(end).Satellite = string(satName);
            rows(end).Plane = parts(1);
            rows(end).Beam = b;
            rows(end).PowerModel = "Demand_limited_user_load";
            rows(end).Pbeam_W = PbeamActual_W;
            rows(end).SatelliteRemainingPower_W = satRemaining_W(iSat);
            rows(end).BackoffApplied = 0;
            rows(end).BackoffRank = NaN;
            rows(end).PowerReturned_W = 0;
            rows(end).EPFD_lin_initial = epfdLin;
            rows(end).AggregateEPFD_before_lin = NaN;
            rows(end).AggregateEPFD_after_lin = NaN;
            rows(end).ActiveBeam = double(activeBeamNow);
            rows(end).UserCount = userCountByBeam(b);
            rows(end).LoadShare = loadShareByBeam(b);
            rows(end).UserDemand_Mbps = double(opts.userDemand_Mbps);
            rows(end).BeamDemand_Mbps = beamDemand_bps(iSat,b) / 1e6;
            rows(end).PbeamDemandLimited_W = PbeamActual_W;
            rows(end).PbeamRequired_W = beamRequiredPower_W(iSat,b);
            rows(end).BeamPowerSatisfaction = beamPowerSatisfactionByBeam(iSat,b);
            rows(end).EPFD_dB = 10*log10(max(epfdLin, 1e-300));
            rows(end).EPFD_lin = epfdLin;
            rows(end).InBeam = double(inBeamNow);
            rows(end).Elevation_deg = groundElevationLocal(P_leo_km, P_gs_km);
            rows(end).PhiT_deg = phit;
            rows(end).Alpha_deg = alpha;
            rows(end).Distance_km = d_m / 1000;
            rows(end).BeamCenterLat_deg = beamLat(b);
            rows(end).BeamCenterLon_deg = beamLon(b);
        end
    end
end
Tdetail = struct2table(rows);
end

function Tsystem = buildSystemStateTableLocal(Tdetail, Tuser)
if isempty(Tdetail)
    Tsystem = table();
    return;
end
time = Tdetail.Time;
sat = Tdetail.Satellite;
beam = Tdetail.Beam;
active = Tdetail.ActiveBeam;
power_W = Tdetail.Pbeam_W;
remaining_power_W = Tdetail.SatelliteRemainingPower_W;
backoff_applied = Tdetail.BackoffApplied;
backoff_rank = Tdetail.BackoffRank;
power_returned_W = Tdetail.PowerReturned_W;
aggregate_epfd_before_dB = nan(height(Tdetail),1);
aggregate_epfd_after_dB = nan(height(Tdetail),1);
load_users = Tdetail.UserCount;
demand_Mbps = Tdetail.BeamDemand_Mbps;
avg_satisfaction = nan(height(Tdetail),1);
for r = 1:height(Tdetail)
    mask = string(Tuser.sat) == string(sat(r)) & double(Tuser.beam) == double(beam(r));
    if any(mask)
        avg_satisfaction(r) = mean(Tuser.satisfaction(mask), 'omitnan');
    end
end
Tsystem = table(time, sat, beam, active, power_W, remaining_power_W, backoff_applied, backoff_rank, power_returned_W, ...
    aggregate_epfd_before_dB, aggregate_epfd_after_dB, load_users, demand_Mbps, avg_satisfaction);
Tsystem = Tsystem(active > 0, :);
end

function Tdistress = buildBeamDistressScoreTableLocal(Tdetail, P, opts)
Tdistress = table();
if isempty(Tdetail)
    return;
end
mask = string(Tdetail.Satellite) == string(opts.sourceSatellite) & Tdetail.ActiveBeam > 0 & isfinite(Tdetail.PbeamRequired_W) & isfinite(Tdetail.EPFD_lin_initial);
if any(mask)
    geoRef = string(Tdetail.GeoName(find(mask, 1, 'first')));
    mask = mask & string(Tdetail.GeoName) == geoRef;
end
Tbeam = Tdetail(mask,:);
if isempty(Tbeam)
    return;
end
[~, idx] = unique(Tbeam.Beam, 'stable');
Tbeam = Tbeam(idx,:);
E_lim = 10^(double(P.EPFD_thr_dB) / 10);
a = zeros(height(Tbeam),1);
valid = isfinite(Tbeam.Pbeam_W) & Tbeam.Pbeam_W > 0;
a(valid) = Tbeam.EPFD_lin_initial(valid) ./ Tbeam.Pbeam_W(valid);
P_req = max(Tbeam.PbeamRequired_W, 0);
N = max(Tbeam.UserCount, 0);
Nmax = max(N);
if Nmax <= 0, Nmax = 1; end
score = opts.distressXi1 * ((a .* P_req) ./ max(E_lim, eps)) + opts.distressXi2 * (N ./ Nmax);
Tdistress = table(Tbeam.Time, Tbeam.Satellite, Tbeam.Beam, Tbeam.GeoName, Tbeam.UserCount, Tbeam.BeamDemand_Mbps, ...
    P_req, a, repmat(E_lim, height(Tbeam), 1), repmat(opts.distressXi1, height(Tbeam),1), repmat(opts.distressXi2, height(Tbeam),1), score, ...
    'VariableNames', {'time','sat','beam','geo','load_users','demand_Mbps','power_required_W','epfd_sensitivity_per_W','epfd_limit_lin','xi1','xi2','beam_distress_score'});
Tdistress = sortrows(Tdistress, 'beam_distress_score', 'descend');
end

function [PbeamActualByBeam, beamPowerSatisfactionByBeam, satelliteRemainingPower_W] = redistributeSatelliteRemainingPowerLocal(PbeamActualByBeam, PbeamRequiredByBeam, userCountByBeam, activeByBeam, satelliteTotalPower_W, enforceBeamPowerMax, maxBeamPower_W)
if nargin < 6, enforceBeamPowerMax = false; end
if nargin < 7, maxBeamPower_W = inf; end
if enforceBeamPowerMax
    PbeamActualByBeam = min(PbeamActualByBeam, maxBeamPower_W);
end
beamPowerSatisfactionByBeam = nan(size(PbeamActualByBeam));
validActive = activeByBeam & isfinite(PbeamRequiredByBeam) & PbeamRequiredByBeam > 0;
beamPowerSatisfactionByBeam(validActive) = min(PbeamActualByBeam(validActive) ./ max(PbeamRequiredByBeam(validActive), eps), 1);
satelliteRemainingPower_W = max(satelliteTotalPower_W - sum(PbeamActualByBeam), 0);
while satelliteRemainingPower_W > 1e-12
    underServed = validActive & PbeamActualByBeam < PbeamRequiredByBeam;
    if enforceBeamPowerMax
        underServed = underServed & PbeamActualByBeam < maxBeamPower_W - 1e-12;
    end
    if ~any(underServed)
        break;
    end
    weights = zeros(size(PbeamActualByBeam));
    weights(underServed) = max(userCountByBeam(underServed), 0);
    if sum(weights) <= 0
        weights(underServed) = 1;
    end
    allocatedAny = false;
    idx = find(underServed);
    for k = 1:numel(idx)
        b = idx(k);
        share_W = satelliteRemainingPower_W * weights(b) / max(sum(weights), eps);
        deficit_W = PbeamRequiredByBeam(b) - PbeamActualByBeam(b);
        if enforceBeamPowerMax
            deficit_W = min(deficit_W, maxBeamPower_W - PbeamActualByBeam(b));
        end
        add_W = min(share_W, deficit_W);
        if add_W <= 1e-12
            continue;
        end
        PbeamActualByBeam(b) = PbeamActualByBeam(b) + add_W;
        satelliteRemainingPower_W = satelliteRemainingPower_W - add_W;
        allocatedAny = true;
    end
    if ~allocatedAny
        break;
    end
end
beamPowerSatisfactionByBeam(validActive) = min(PbeamActualByBeam(validActive) ./ max(PbeamRequiredByBeam(validActive), eps), 1);
satelliteRemainingPower_W = max(satelliteRemainingPower_W, 0);
end

function helperCount = countHelperCoverageLocal(satGeom, P_user_km, servingSatIdx, servingBeamIdx, beamHalfEW_deg, beamHalfNS_deg)
helperCount = 0;
for iSat = 1:numel(satGeom)
    [bestBeam, ~] = bestCoveredBeamForUser(satGeom(iSat), P_user_km, beamHalfEW_deg, beamHalfNS_deg);
    if bestBeam < 1
        continue;
    end
    if iSat == servingSatIdx && bestBeam == servingBeamIdx
        continue;
    end
    helperCount = helperCount + 1;
end
end

function key = beamKey(satName, beamIdx)
key = sprintf('%s_B%02d', char(string(satName)), round(double(beamIdx)));
end

function [userNames, P_users_km] = userFacilitiesXYZ(sc, userPrefix)
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
    P_users_km(:,end+1) = facilityXYZ(fac); %#ok<AGROW>
end
end

function satGeom = buildSatelliteBeamGeometry(root, satList, tStr, pitchOffsets_deg)
satGeom = repmat(struct('satName', "", 'P_leo_km', [], 'b_all', [], 'c_axis', [], 'beamLat', [], 'beamLon', [], 'subLat', [], 'subLon', []), numel(satList), 1);
for iSat = 1:numel(satList)
    satName = char(satList(iSat));
    satObj = root.GetObjectFromPath(['*/Satellite/' satName]);
    posDP = satObj.DataProviders.Item('Cartesian Position').Group.Item('Fixed');
    velDP = satObj.DataProviders.Item('Cartesian Velocity').Group.Item('Fixed');
    P_leo_km = stkXYZ(posDP, tStr);
    V_leo_kmps = stkXYZ(velDP, tStr);
    [b_all, c_axis] = beamBoresights(P_leo_km*1000, V_leo_kmps*1000, pitchOffsets_deg);
    b_all = reorderBoresightsNorthToSouth(P_leo_km*1000, b_all);
    [beamLat, beamLon] = beamFootprintCenters(P_leo_km*1000, b_all);
    satGeom(iSat).satName = string(satName);
    satGeom(iSat).P_leo_km = P_leo_km;
    satGeom(iSat).b_all = b_all;
    satGeom(iSat).c_axis = c_axis;
    satGeom(iSat).beamLat = beamLat;
    satGeom(iSat).beamLon = beamLon;
    satGeom(iSat).subLat = asind(P_leo_km(3) / max(norm(P_leo_km), eps));
    satGeom(iSat).subLon = atan2d(P_leo_km(2), P_leo_km(1));
end
end

function [userCountMat, userSatIdx, userBeamIdx] = assignUsersToNearestBeamCenter(satGeom, P_users_km, beamHalfEW_deg, beamHalfNS_deg, prioritySatellite, priorityCoverageFirst, priorityBeamRange)
Nsat = numel(satGeom);
Nbeam = size(satGeom(1).b_all, 2);
Nuser = size(P_users_km, 2);
userCountMat = zeros(Nsat, Nbeam);
userSatIdx = zeros(Nuser, 1);
userBeamIdx = zeros(Nuser, 1);
prioritySatellite = string(prioritySatellite);
priorityBeamRange = round(double(priorityBeamRange(:))).';
priorityBeamRange = priorityBeamRange(priorityBeamRange >= 1 & priorityBeamRange <= Nbeam);
prioritySatIdx = find([satGeom.satName] == prioritySatellite, 1);
for iu = 1:Nuser
    userLat = asind(P_users_km(3,iu) / max(norm(P_users_km(:,iu)), eps));
    userLon = atan2d(P_users_km(2,iu), P_users_km(1,iu));
    if priorityCoverageFirst && ~isempty(prioritySatIdx)
        [priorityBeam, ~] = bestCoveredBeamForUser(satGeom(prioritySatIdx), P_users_km(:,iu), beamHalfEW_deg, beamHalfNS_deg);
        if priorityBeam > 0 && ismember(priorityBeam, priorityBeamRange)
            userCountMat(prioritySatIdx, priorityBeam) = userCountMat(prioritySatIdx, priorityBeam) + 1;
            userSatIdx(iu) = prioritySatIdx;
            userBeamIdx(iu) = priorityBeam;
            continue;
        end
    end
    if priorityCoverageFirst && ~isempty(prioritySatIdx)
        candidateIdx = setdiff(1:Nsat, prioritySatIdx, 'stable');
    else
        candidateIdx = 1:Nsat;
    end
    if isempty(candidateIdx)
        continue;
    end
    bestSat = nearestSatelliteSubpoint(satGeom, userLat, userLon, candidateIdx);
    [bestBeam, ~] = bestCoveredBeamForUser(satGeom(bestSat), P_users_km(:,iu), beamHalfEW_deg, beamHalfNS_deg);
    if bestSat > 0 && bestBeam > 0
        userCountMat(bestSat, bestBeam) = userCountMat(bestSat, bestBeam) + 1;
        userSatIdx(iu) = bestSat;
        userBeamIdx(iu) = bestBeam;
    end
end
end

function [beamRequiredPower_W, beamDemand_bps] = computeBeamDemandLimitedPower(satGeom, P_users_km, userSatIdx, userBeamIdx, userDemand_bps, P)
Nsat = numel(satGeom);
Nbeam = size(satGeom(1).b_all, 2);
beamRequiredPower_W = zeros(Nsat, Nbeam);
beamDemand_bps = zeros(Nsat, Nbeam);
Buser = P.B_Hz;
noisePower_W = P.kB * P.user_noise_temp_K * Buser;
Gur_lin = 10^(P.GS_LEO_Gmax_dBi/10);
for iSat = 1:Nsat
    for b = 1:Nbeam
        beamUsers = find(userSatIdx == iSat & userBeamIdx == b);
        if isempty(beamUsers)
            continue;
        end
        nUsers = numel(beamUsers);
        beamDemand_bps(iSat,b) = nUsers * userDemand_bps;
        snrReq = 2^(beamDemand_bps(iSat,b) / max(Buser, eps)) - 1;
        P_req_by_user = zeros(nUsers, 1);
        for k = 1:nUsers
            iu = beamUsers(k);
            channelGain = userLinkChannelGainPerW(satGeom(iSat), b, P_users_km(:,iu), P, Gur_lin);
            if channelGain <= 0
                P_req_by_user(k) = inf;
            else
                P_req_by_user(k) = snrReq * noisePower_W / channelGain;
            end
        end
        beamRequiredPower_W(iSat,b) = max(P_req_by_user);
    end
end
end

function channelGain = userLinkChannelGainPerW(satGeomOne, beamIdx, P_user_km, P, Gur_lin)
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

function [bestBeam, bestMetric] = bestCoveredBeamForUser(satGeomOne, P_user_km, beamHalfEW_deg, beamHalfNS_deg)
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

function bestSat = nearestSatelliteSubpoint(satGeom, userLat, userLon, candidateIdx)
bestSat = candidateIdx(1);
bestCentralAngle = inf;
for iSat = candidateIdx
    centralAngle = greatCircleDistanceDeg(userLat, userLon, satGeom(iSat).subLat, satGeom(iSat).subLon);
    if centralAngle < bestCentralAngle
        bestCentralAngle = centralAngle;
        bestSat = iSat;
    end
end
end

function d_deg = greatCircleDistanceDeg(lat1, lon1, lat2, lon2)
dlat = deg2rad(lat2 - lat1);
dlon = deg2rad(lon2 - lon1);
a = sin(dlat/2)^2 + cosd(lat1) * cosd(lat2) * sin(dlon/2)^2;
d_deg = rad2deg(2 * atan2(sqrt(a), sqrt(max(0, 1-a))));
end

function [b_all, c_axis] = beamBoresights(r_sat_m, v_sat_mps, pitchOffsets_deg)
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

function b_sorted = reorderBoresightsNorthToSouth(r_sat_m, b_all)
Re_m = 6378137.0;
nb = size(b_all, 2);
lat_deg = -inf(1, nb);
for k = 1:nb
    hit = rayEarthIntersect(r_sat_m, b_all(:,k), Re_m);
    if ~isempty(hit)
        lat_deg(k) = asind(hit(3) / max(norm(hit), eps));
    end
end
[~, idx] = sort(lat_deg, 'descend');
b_sorted = b_all(:, idx);
end

function [lat_deg, lon_deg] = beamFootprintCenters(r_sat_m, b_all)
Re_m = 6378137.0;
lat_deg = nan(size(b_all, 2), 1);
lon_deg = nan(size(b_all, 2), 1);
for k = 1:size(b_all, 2)
    hit = rayEarthIntersect(r_sat_m, b_all(:,k), Re_m);
    if isempty(hit)
        continue;
    end
    lat_deg(k) = asind(hit(3) / max(norm(hit), eps));
    lon_deg(k) = atan2d(hit(2), hit(1));
end
end

function hit = rayEarthIntersect(r_s_m, d_unit, Re_m)
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
lam = min(cand);
hit = r_s_m + lam * d_unit;
end

function v = rodriguesLocal(u, k, ang)
v = u*cos(ang) + cross(k,u)*sin(ang) + k*dot(k,u)*(1-cos(ang));
v = v / max(norm(v), eps);
end

function P = stkXYZ(dp, tStr)
res = dp.ExecSingle(tStr);
P = xyzFromArray(res.DataSets.ToArray);
end

function P = facilityXYZ(gsObj)
res = gsObj.DataProviders.Item('Cartesian Position').Exec;
P = xyzFromArray(res.DataSets.ToArray);
end

function [lat_deg, lon_deg] = facilityLatLon(gsObj)
res = gsObj.DataProviders.Item('LLA State').Exec;
vals = numericScalars(res.DataSets.ToArray);
lat_deg = vals(1);
lon_deg = vals(2);
end

function P_geo_km = idealGsoXYZFromLongitude(lon_deg)
R_geo_km = 42164.0;
P_geo_km = R_geo_km * [cosd(lon_deg); sind(lon_deg); 0];
end

function P = xyzFromArray(arr)
vals = numericScalars(arr);
P = vals(1:3);
end

function vals = numericScalars(arr)
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

function elev = groundElevationLocal(P_leo_km, P_gs_km)
zen = P_gs_km(:) / max(norm(P_gs_km), eps);
v = P_leo_km(:) - P_gs_km(:);
elev = 90 - acosd(max(-1, min(1, dot(v, zen)/(norm(v)+eps))));
end

function a = angleDegLocal(x, y)
a = acosd(max(-1, min(1, dot(x,y)/(norm(x)*norm(y)+eps))));
end
