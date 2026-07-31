function caseData = prepare_overhead_case(cfg, userLoad)
%PREPARE_OVERHEAD_CASE Build untimed scenarios for a 60-s window around worst EPFD.
% Pure MATLAB: find t_worst = argmax(aggregate EPFD before shutdown) near the
% GS flyover, then build one scenario per 1-s slot in
% [t_worst-30, t_worst+29] (60 slots). All of this is outside online timing.
%
% 【中文說明】為一種 user 負載準備量測所需的所有場景快照。
%
% 【關鍵設計】這裡做的所有事情都「不列入計時」——
% 建幾何、找 t_worst、灑 user、預先算好每個 slot 的衛星位置與 beam 指向，
% 全部在計時開始前完成。這樣 measure_* 量到的才是純粹的「線上決策時間」，
% 不會混入離線前處理的成本，符合論文對 on-orbit computational overhead 的定義。
%
% 流程：
%   1. 建立對齊過的 OneWeb-like Walker 幾何（t=0 時參考衛星在 GS 正上方）
%   2. 在 ±120 s 內掃描「關束前的 aggregate EPFD」，取最大值的時刻為 t_worst
%   3. 在 t_worst 這一瞬間固定住「局部衛星集合」與 critical 衛星，
%      整個量測窗都追蹤同一批衛星（避免衛星進出集合造成計算量跳動）
%   4. 依 userLoad 灑 user（位置固定不隨時間移動）
%   5. 為 [t_worst-30, t_worst+29] 每個 slot 各做一份場景快照

validateattributes(userLoad, {'numeric'}, {'scalar','integer','positive'});

addpath(fullfile(cfg.matlabDir, 'jacky'));
addpath(fullfile(cfg.matlabDir, 'powertilt'));
addpath(fullfile(cfg.matlabDir, 'helper_availability'));
rng(cfg.randomSeed, 'twister');   % 固定種子 → 三種負載的 user 分佈可重現

% 步驟 1-2：建幾何並找出最壞 EPFD 時刻
[geom, common, pitchOffsets_deg] = buildAlignedWalkerLocal(cfg);
[tWorst_s, searchT_s, searchEpfd_dB] = findWorstEpfdTimeLocal( ...
    geom, common, pitchOffsets_deg, cfg);

% 量測窗：t_worst 前 30 s 到後 29 s，共 60 個 1 秒 slot
tRel_s = (-cfg.slotHalfWindow_s):cfg.slotStep_s:(cfg.slotHalfWindow_s - cfg.slotStep_s);
tSlots_s = tWorst_s + tRel_s;
nSlot = numel(tSlots_s);

% Freeze local satellite set at the worst-EPFD instant so the same sats are
% tracked through the flyover window.
[localIdx, criticalSatIdx, criticalName] = selectLocalSatsAtTimeLocal( ...
    geom, common, tWorst_s, cfg);
satGeomWorst = buildLocalSatGeomAtTimeLocal( ...
    geom, common, localIdx, tWorst_s, pitchOffsets_deg, cfg);

[userNames, P_users_km, userLat, userLon] = generateUsersAroundSatsLocal( ...
    satGeomWorst, cfg.userAreaSide_km, userLoad);

P = ku_epfd_params();
P.useEIRPDensityModel = false;
P.EPFD_thr_dB = cfg.epfdThreshold_dB;
P.Ptotal_W = cfg.fullBeamPower_W * cfg.nBeam;
P.kB = 1.380649e-23;
P.user_noise_temp_K = 240;
if ~isfield(P, 'Nchannel') || ~isfinite(P.Nchannel)
    P.Nchannel = 8;
end
if ~isfield(P, 'lambda_m') || ~isfinite(P.lambda_m)
    P.lambda_m = 3e8 / (P.freq_GHz * 1e9);
end

scenarios = cell(1, nSlot);
pcTiltScenarios = cell(1, nSlot);
slotMeta = repmat(struct( ...
    't_s', NaN, 'tRel_s', NaN, 'aggregateEpfdBefore_dB', NaN, ...
    'aggregateEpfdAfter_dB', NaN, 'nShutBeams', 0, ...
    'nSbrEdges', 0, 'nHbrEdges', 0, 'nClosedUsers', 0), 1, nSlot);

for iSlot = 1:nSlot
    t_s = tSlots_s(iSlot);
    satGeom = buildLocalSatGeomAtTimeLocal( ...
        geom, common, localIdx, t_s, pitchOffsets_deg, cfg);
    [userHomeSat, userHomeBeam] = assignUsersLocal( ...
        satGeom, P_users_km, cfg.beamHalfEW_deg, cfg.beamHalfNS_deg);

    nSat = numel(satGeom);
    nBeam = cfg.nBeam;
    [shutOffMat, ~, aggregateBefore_dB, aggregateAfter_dB] = ...
        buildBeamRoleRecordLocal(satGeom, cfg, P);
    closedMask = false(numel(userHomeSat), 1);
    validHome = userHomeSat > 0 & userHomeBeam > 0;
    homeLinear = sub2ind([nSat, nBeam], userHomeSat(validHome), userHomeBeam(validHome));
    closedMask(validHome) = shutOffMat(homeLinear);

    userCountMat = accumarray([userHomeSat(validHome), userHomeBeam(validHome)], 1, ...
        [nSat, nBeam], @sum, 0);
    [sbrEdges, hbrEdges] = buildCandidateGraphsLocal( ...
        satGeom, shutOffMat, userCountMat, cfg);

    nUsers = numel(userNames);
    priorityWeight = 1 + mod((1:nUsers)' + cfg.randomSeed, 3);
    userDemand_bps = cfg.userDemand_Mbps * 1e6 * ones(nUsers, 1);

    scenario = struct();
    scenario.nUsers = nUsers;
    scenario.nSat = nSat;
    scenario.nBeam = nBeam;
    scenario.userHomeSat = userHomeSat;
    scenario.userHomeBeam = userHomeBeam;
    scenario.userServiceSat = userHomeSat;
    scenario.userServiceBeam = userHomeBeam;
    scenario.closedBeamUserMask = closedMask;
    scenario.criticalSatUserMask = userHomeSat == criticalSatIdx;
    scenario.beamCapacity_Mbps = cfg.userDemand_Mbps * max(userLoad, 1);
    scenario.sbrEdges = sbrEdges;
    scenario.hbrEdges = hbrEdges;
    scenario.userDemand_bps = userDemand_bps;
    scenario.priorityWeight = priorityWeight;
    scenario.satGeom = satGeom;
    scenario.P_users_km = P_users_km;
    scenario.beamHalfEW_deg = cfg.beamHalfEW_deg;
    scenario.beamHalfNS_deg = cfg.beamHalfNS_deg;
    scenario.alt_km = cfg.alt_km;
    scenario.fullBeamPower_W = cfg.fullBeamPower_W;
    scenario.maxBeamPower_W = cfg.maxBeamPower_W;
    scenario.params = P;
    scenario.recoveryPowerPoolMode = cfg.recoveryPowerPoolMode;
    scenario.t_s = t_s;
    scenario.tRel_s = tRel_s(iSlot);

    scenarios{iSlot} = scenario;
    pcTiltScenarios{iSlot} = buildPcTiltInputLocal( ...
        satGeom, P_users_km, userHomeSat, userHomeBeam, ...
        userDemand_bps, priorityWeight, criticalSatIdx, cfg, P);
    slotMeta(iSlot).t_s = t_s;
    slotMeta(iSlot).tRel_s = tRel_s(iSlot);
    slotMeta(iSlot).aggregateEpfdBefore_dB = aggregateBefore_dB;
    slotMeta(iSlot).aggregateEpfdAfter_dB = aggregateAfter_dB;
    slotMeta(iSlot).nShutBeams = nnz(shutOffMat);
    slotMeta(iSlot).nSbrEdges = numel(sbrEdges);
    slotMeta(iSlot).nHbrEdges = numel(hbrEdges);
    slotMeta(iSlot).nClosedUsers = sum(closedMask);
end

caseData = struct();
caseData.userLoad = userLoad;
caseData.randomSeed = cfg.randomSeed;
caseData.criticalSlot = sprintf( ...
    "worst-EPFD window [%d,%d] s (t_worst=%d s, %d x 1-s slots)", ...
    tSlots_s(1), tSlots_s(end), tWorst_s, nSlot);
caseData.criticalSatellite = criticalName;
caseData.tWorst_s = tWorst_s;
caseData.tSlots_s = tSlots_s;
caseData.tRel_s = tRel_s;
caseData.userNames = userNames;
caseData.userLat_deg = userLat;
caseData.userLon_deg = userLon;
caseData.eabrScenarios = scenarios;
caseData.pcTiltScenarios = pcTiltScenarios;
caseData.slotMeta = slotMeta;
caseData.epfdSearch = struct( ...
    't_s', searchT_s, ...
    'aggEpfdBefore_dB', searchEpfd_dB, ...
    'tWorst_s', tWorst_s);
caseData.candidateGraphs = struct( ...
    'sbrEdges', scenarios{1}.sbrEdges, ...
    'hbrEdges', scenarios{1}.hbrEdges);
% Backward-compatible alias: first/worst-centered slot scenario.
[~, iCenter] = min(abs(tRel_s));
caseData.eabrScenario = scenarios{iCenter};
end

function [geom, common, pitchOffsets_deg] = buildAlignedWalkerLocal(cfg)
common = struct( ...
    'gsLat_deg', cfg.gsLat_deg, ...
    'gsLon_deg', cfg.gsLon_deg, ...
    'gsoLon_deg', cfg.gsLon_deg, ...
    'Re_km', cfg.Re_km, ...
    'mu_km3_s2', cfg.mu_km3_s2, ...
    'we_rad_s', cfg.we_rad_s, ...
    'Rgeo_km', cfg.Rgeo_km, ...
    'alignTol_km', 5.0);

shell = struct( ...
    'altitude_km', cfg.alt_km, ...
    'inclination_deg', cfg.inclination_deg, ...
    'number_of_planes', cfg.nPlanes, ...
    'satellites_per_plane', cfg.nSatPerPlane, ...
    'walker_type', cfg.walkerType, ...
    'walker_phasing_F', cfg.walkerPhasingF);
constellation = struct( ...
    'name', 'Overhead-OneWeb-like', ...
    'isExampleGeometry', false, ...
    'shells', {{shell}}, ...
    'ref_shell_index', 1, ...
    'ref_plane_index', cfg.refPlaneIndex, ...
    'ref_sat_index', cfg.refSatIndex);

geom = generate_constellation_geometry(constellation, common);
[geom, ~] = align_reference_satellite_over_gs(geom, common);
pitchOffsets_deg = (8.5 - (1:cfg.nBeam)) * (2 * cfg.beamHalfNS_deg);
end

function [tWorst_s, searchT_s, searchEpfd_dB] = findWorstEpfdTimeLocal( ...
    geom, common, pitchOffsets_deg, cfg)
searchT_s = cfg.epfdSearchStart_s:cfg.epfdSearchStep_s:cfg.epfdSearchEnd_s;
nT = numel(searchT_s);
searchEpfd_dB = -inf(1, nT);
P = ku_epfd_params();
P.useEIRPDensityModel = false;
P.EPFD_thr_dB = cfg.epfdThreshold_dB;
P.Ptotal_W = cfg.fullBeamPower_W * cfg.nBeam;
if ~isfield(P, 'lambda_m') || ~isfinite(P.lambda_m)
    P.lambda_m = 3e8 / (P.freq_GHz * 1e9);
end

fprintf('  Searching worst GS EPFD over t=[%d,%d] s (step=%d)...\n', ...
    searchT_s(1), searchT_s(end), cfg.epfdSearchStep_s);
for it = 1:nT
    [localIdx, ~, ~] = selectLocalSatsAtTimeLocal(geom, common, searchT_s(it), cfg);
    satGeom = buildLocalSatGeomAtTimeLocal( ...
        geom, common, localIdx, searchT_s(it), pitchOffsets_deg, cfg);
    [~, ~, before_dB, ~] = buildBeamRoleRecordLocal(satGeom, cfg, P);
    searchEpfd_dB(it) = before_dB;
end
[peakEpfd_dB, iWorst] = max(searchEpfd_dB);
tWorst_s = searchT_s(iWorst);
fprintf('  t_worst = %d s (agg EPFD before shutdown = %.2f dB)\n', ...
    tWorst_s, peakEpfd_dB);
end

function [localIdx, criticalSatIdx, criticalName] = selectLocalSatsAtTimeLocal( ...
    geom, common, t_s, cfg)
state = propagate_satellites(geom, common, t_s);
dist_km = zeros(geom.nSat, 1);
for iSat = 1:geom.nSat
    dist_km(iSat) = greatCircleKmLocal( ...
        state.subLat_deg(iSat, 1), state.subLon_deg(iSat, 1), ...
        cfg.gsLat_deg, cfg.gsLon_deg, cfg.Re_km);
end
[~, order] = sort(dist_km, 'ascend');
localIdx = order(1:min(cfg.nLocalSats, geom.nSat));
[~, critInLocal] = min(dist_km(localIdx));
criticalSatIdx = critInLocal;
criticalName = string(geom.sats(localIdx(critInLocal)).name);
end

function satGeom = buildLocalSatGeomAtTimeLocal( ...
    geom, common, localIdx, t_s, pitchOffsets_deg, cfg)
state = propagate_satellites(geom, common, t_s);
nSat = numel(localIdx);
satGeom = repmat(struct('name',"",'P_leo_km',zeros(3,1),'V_leo_kmps',zeros(3,1), ...
    'subLat',NaN,'subLon',NaN,'b_all',zeros(3,cfg.nBeam),'c_axis',zeros(3,1)), nSat, 1);
for k = 1:nSat
    gi = localIdx(k);
    pos = state.pos_ecef_km(:, gi, 1);
    vel = state.vel_ecef_kmps(:, gi, 1);
    [bAll, cAxis] = beamBoresightsLocal(pos * 1000, vel * 1000, pitchOffsets_deg);
    satGeom(k).name = string(geom.sats(gi).name);
    satGeom(k).P_leo_km = pos;
    satGeom(k).V_leo_kmps = vel;
    satGeom(k).subLat = state.subLat_deg(gi, 1);
    satGeom(k).subLon = state.subLon_deg(gi, 1);
    satGeom(k).b_all = reorderNorthToSouthLocal(pos * 1000, bAll);
    satGeom(k).c_axis = cAxis;
end
end

function [satGeom, criticalSatIdx, criticalName] = buildMatlabLocalGeometry(cfg)
% Backward-compatible single-snapshot helper (t = 0).
[geom, common, pitchOffsets_deg] = buildAlignedWalkerLocal(cfg);
[localIdx, criticalSatIdx, criticalName] = selectLocalSatsAtTimeLocal( ...
    geom, common, 0, cfg);
satGeom = buildLocalSatGeomAtTimeLocal( ...
    geom, common, localIdx, 0, pitchOffsets_deg, cfg);
end

function [userNames, P_users_km, userLat, userLon] = generateUsersAroundSatsLocal( ...
    satGeom, areaSide_km, usersPerSat)
% Deterministic scatter identical in spirit to GenerateSimulatedUsersAroundSatellites.
[baseOffsets_km, ~, ~] = buildUniformScatteredOffsetsLocal(areaSide_km, usersPerSat);
nSat = numel(satGeom);
nUsers = nSat * usersPerSat;
userNames = strings(nUsers, 1);
userLat = zeros(nUsers, 1);
userLon = zeros(nUsers, 1);
iu = 0;
for iSat = 1:nSat
    lat0 = satGeom(iSat).subLat;
    lon0 = satGeom(iSat).subLon;
    for k = 1:usersPerSat
        iu = iu + 1;
        east_km = baseOffsets_km(k, 1);
        north_km = baseOffsets_km(k, 2);
        lat_deg = lat0 + north_km / 111.32;
        lonScale = cosd(lat_deg);
        if abs(lonScale) < 1e-6
            lonScale = sign(lonScale) * 1e-6;
            if lonScale == 0
                lonScale = 1e-6;
            end
        end
        lon_deg = lon0 + east_km / (111.32 * lonScale);
        userNames(iu) = sprintf("OverheadUser_%03d", iu);
        userLat(iu) = lat_deg;
        userLon(iu) = lon_deg;
    end
end
P_users_km = zeros(3, nUsers);
for iu = 1:nUsers
    P_users_km(:, iu) = groundXyzLocal(userLat(iu), userLon(iu), 0);
end
end

function [offsets_km, dx_km, dy_km] = buildUniformScatteredOffsetsLocal(areaSide_km, numUsers)
numBands = 16;
effectiveSide_km = areaSide_km;
bandHeight_km = effectiveSide_km / numBands;
dy_km = bandHeight_km;
basePerBand = floor(numUsers / numBands);
extraUsers = mod(numUsers, numBands);
usersPerBand = repmat(basePerBand, numBands, 1);
if extraUsers > 0
    extraBands = round(linspace(1, numBands, extraUsers));
    usersPerBand(extraBands) = usersPerBand(extraBands) + 1;
end
offsets_km = zeros(numUsers, 2);
row = 0;
maxUsersInBand = max(usersPerBand);
dx_km = effectiveSide_km / max(maxUsersInBand, 1);
for band = 1:numBands
    nBandUsers = usersPerBand(band);
    if nBandUsers <= 0, continue; end
    northBase_km = effectiveSide_km / 2 - (band - 0.5) * bandHeight_km;
    if nBandUsers == 1
        eastPositions_km = -effectiveSide_km/2 + effectiveSide_km * ...
            mod((band - 1) * 0.61803398875 + 0.5, 1);
    else
        eastPositions_km = linspace(-effectiveSide_km/2, effectiveSide_km/2, nBandUsers + 2);
        eastPositions_km = eastPositions_km(2:end-1);
        if mod(band, 2) == 0
            eastPositions_km = fliplr(eastPositions_km);
        end
    end
    for k = 1:nBandUsers
        row = row + 1;
        jx = mod(row * 0.75487766625, 1.0) - 0.5;
        jy = mod(row * 0.56984029099, 1.0) - 0.5;
        east_km = eastPositions_km(k) + jx * 0.18 * dx_km;
        north_km = northBase_km + jy * 0.20 * bandHeight_km;
        offsets_km(row, 1) = min(max(east_km, -effectiveSide_km/2), effectiveSide_km/2);
        offsets_km(row, 2) = min(max(north_km, -effectiveSide_km/2), effectiveSide_km/2);
    end
end
end

function d_km = greatCircleKmLocal(lat1, lon1, lat2, lon2, Re_km)
dlat = deg2rad(lat2 - lat1);
dlon = deg2rad(lon2 - lon1);
a = sin(dlat/2)^2 + cosd(lat1) * cosd(lat2) * sin(dlon/2)^2;
d_km = Re_km * 2 * atan2(sqrt(a), sqrt(max(0, 1 - a)));
end

function [userSat, userBeam] = assignUsersLocal(satGeom, Pusers, halfEW, halfNS)
nUsers = size(Pusers, 2);
nSat = numel(satGeom);
nBeam = size(satGeom(1).b_all, 2);
userSat = zeros(nUsers, 1);
userBeam = zeros(nUsers, 1);
for iu = 1:nUsers
    bestRange = inf;
    bestSat = 0;
    bestBeam = 0;
    for iSat = 1:nSat
        range = norm(Pusers(:, iu) - satGeom(iSat).P_leo_km);
        if range >= bestRange
            continue;
        end
        for iBeam = 1:nBeam
            if graphRecoverySharedLocal('usercovered', satGeom(iSat), iBeam, ...
                    Pusers(:, iu), halfEW, halfNS)
                bestRange = range;
                bestSat = iSat;
                bestBeam = iBeam;
                break;
            end
        end
    end
    if bestSat == 0
        ranges = arrayfun(@(s) norm(Pusers(:, iu) - s.P_leo_km), satGeom);
        [~, bestSat] = min(ranges);
        dHat = (Pusers(:, iu) - satGeom(bestSat).P_leo_km);
        dHat = dHat / max(norm(dHat), eps);
        [~, bestBeam] = max(satGeom(bestSat).b_all' * dHat);
    end
    userSat(iu) = bestSat;
    userBeam(iu) = bestBeam;
end
end

function [shut, epfdPerW, before_dB, after_dB] = buildBeamRoleRecordLocal(satGeom, cfg, P)
nSat = numel(satGeom);
nBeam = cfg.nBeam;
Pgs = groundXyzLocal(cfg.gsLat_deg, cfg.gsLon_deg, 0);
Pgso = idealGsoXyzLocal(cfg.gsLon_deg);
gsoBore = Pgso - Pgs;
Gmax = 10^(P.GSO_Gmax_dBi / 10);
epfdPerW = zeros(nSat, nBeam);
for iSat = 1:nSat
    satToGs = Pgs - satGeom(iSat).P_leo_km;
    d_m = norm(satToGs) * 1000;
    gsToSat = -satToGs;
    elev = 90 - acosd(max(-1, min(1, dot(gsToSat, Pgs) / ...
        max(norm(gsToSat) * norm(Pgs), eps))));
    if elev <= 0
        continue;
    end
    phiR = angleDegLocal(gsoBore, gsToSat);
    Gr = 10^(gso_rx_gain_itu1428(phiR, P.GSO_D_m, P.lambda_m) / 10);
    for iBeam = 1:nBeam
        phiT = angleDegLocal(satGeom(iSat).b_all(:, iBeam), satToGs);
        Gt = max(P.A_fit * exp(P.beta_fit * phiT), 1e-30);
        epfdPerW(iSat, iBeam) = (Gt * Gr) / ...
            (P.BWref_Hz * 4 * pi * d_m^2 * Gmax);
    end
end

threshold = 10^(cfg.epfdThreshold_dB / 10);
beamEpfd = cfg.fullBeamPower_W * epfdPerW;
aggregate = sum(beamEpfd, 'all');
before_dB = 10 * log10(max(aggregate, realmin));
shut = false(nSat, nBeam);
[~, order] = sort(beamEpfd(:), 'descend');
for k = 1:numel(order)
    if aggregate <= threshold
        break;
    end
    shut(order(k)) = true;
    aggregate = aggregate - beamEpfd(order(k));
end
after_dB = 10 * log10(max(aggregate, realmin));
end

function [sbrEdges, hbrEdges] = buildCandidateGraphsLocal(satGeom, shut, userCount, cfg)
nSat = numel(satGeom);
nBeam = cfg.nBeam;
sbrEdges = struct('iHelpSat',{},'bRelease',{},'iSafeSat',{},'bSafe',{},'blocked',{});
hbrEdges = struct('iClosedSat',{},'bClosed',{},'iHelpSat',{},'bRecovery',{},'blocked',{});

for iHelp = 1:nSat
    for bRelease = 1:nBeam
        if shut(iHelp, bRelease) || userCount(iHelp, bRelease) == 0
            continue;
        end
        found = false;
        satOrder = nearestSatelliteOrderLocal(satGeom, iHelp);
        for iSafe = satOrder
            for bSafe = 1:nBeam
                if shut(iSafe, bSafe)
                    continue;
                end
                if graphRecoverySharedLocal('beamsoverlap', satGeom(iHelp), bRelease, ...
                        satGeom(iSafe), bSafe, cfg.beamHalfEW_deg, cfg.beamHalfNS_deg, cfg.alt_km)
                    sbrEdges(end+1) = struct('iHelpSat',iHelp,'bRelease',bRelease, ...
                        'iSafeSat',iSafe,'bSafe',bSafe,'blocked',false); %#ok<AGROW>
                    found = true;
                    break;
                end
            end
            if found, break; end
        end
    end
end

for iClosed = 1:nSat
    closedBeams = find(shut(iClosed, :));
    for ib = 1:numel(closedBeams)
        bClosed = closedBeams(ib);
        helperCount = 0;
        satOrder = nearestSatelliteOrderLocal(satGeom, iClosed);
        for iHelp = satOrder
            chosenBeam = 0;
            for bRecovery = 1:nBeam
                if shut(iHelp, bRecovery)
                    continue;
                end
                if graphRecoverySharedLocal('beamsoverlap', satGeom(iClosed), bClosed, ...
                        satGeom(iHelp), bRecovery, cfg.beamHalfEW_deg, cfg.beamHalfNS_deg, cfg.alt_km)
                    chosenBeam = bRecovery;
                    break;
                end
            end
            if chosenBeam == 0 && ...
                    norm(satGeom(iHelp).P_leo_km - satGeom(iClosed).P_leo_km) < 2500
                for delta = 0:2
                    candidates = unique([bClosed-delta, bClosed, bClosed+delta]);
                    candidates = candidates(candidates >= 1 & candidates <= nBeam);
                    for bRecovery = candidates
                        if ~shut(iHelp, bRecovery)
                            chosenBeam = bRecovery;
                            break;
                        end
                    end
                    if chosenBeam > 0, break; end
                end
            end
            if chosenBeam > 0
                hbrEdges(end+1) = struct('iClosedSat',iClosed,'bClosed',bClosed, ...
                    'iHelpSat',iHelp,'bRecovery',chosenBeam,'blocked',false); %#ok<AGROW>
                helperCount = helperCount + 1;
            end
            if helperCount >= 3, break; end
        end
    end
end
end

function input = buildPcTiltInputLocal(satGeom, Pusers, userSat, userBeam, ...
    userDemand, ~, criticalSatIdx, cfg, sourceP)
nSat = numel(satGeom);
nBeam = cfg.nBeam;
satPos = reshape([satGeom.P_leo_km], 3, nSat);
satVel = reshape([satGeom.V_leo_kmps], 3, nSat);
beamBores = arrayfun(@(s) s.b_all, satGeom, 'UniformOutput', false);
beamCAxis = arrayfun(@(s) s.c_axis, satGeom, 'UniformOutput', false);
Pgs = groundXyzLocal(cfg.gsLat_deg, cfg.gsLon_deg, 0);
Pgso = idealGsoXyzLocal(cfg.gsLon_deg);
satVisible = false(nSat, 1);
for iSat = 1:nSat
    toSat = satPos(:,iSat) - Pgs;
    elevation = 90 - angleDegLocal(toSat, Pgs);
    satVisible(iSat) = elevation > 0;
end

initialPower = zeros(nSat, nBeam);
for iSat = 1:nSat
    users = find(userSat == iSat);
    demandByBeam = zeros(1, nBeam);
    for iu = users'
        demandByBeam(userBeam(iu)) = demandByBeam(userBeam(iu)) + userDemand(iu);
    end
    active = demandByBeam > 0;
    if any(active)
        initialPower(iSat,active) = sourceP.Ptotal_W * demandByBeam(active) / sum(demandByBeam);
    end
end

input = struct();
input.P = sourceP;
input.P.Ptotal_W = cfg.fullBeamPower_W * nBeam;
input.P.EPFD_thr_dB = cfg.epfdThreshold_dB;
if ~isfield(input.P, 'Nchannel') || ~isfinite(input.P.Nchannel)
    input.P.Nchannel = 8;
end
input.satPos_km = satPos;
input.satVel_kmps = satVel;
input.satVisible = satVisible;
input.beamBores = beamBores;
input.beamCAxis = beamCAxis;
input.P_gs_km = Pgs;
input.P_geo_km = Pgso;
input.userPosition_km = Pusers;
input.userServiceSat = userSat;
input.userServiceBeam = userBeam;
input.userDemand_bps = userDemand;
input.initialPower_W = initialPower;
input.criticalSatelliteIndex = criticalSatIdx;
input.tiltMax_deg = cfg.pcTiltMax_deg;
input.tiltStep_deg = cfg.pcTiltStep_deg;
if isfield(cfg, 'pcTiltSearchMode') && strlength(string(cfg.pcTiltSearchMode)) > 0
    input.tiltSearchMode = char(string(cfg.pcTiltSearchMode));
else
    input.tiltSearchMode = 'exhaustive';
end
if isfield(cfg, 'pcTiltCoarseStep_deg'), input.tiltCoarseStep_deg = cfg.pcTiltCoarseStep_deg; end
if isfield(cfg, 'pcTiltFineStep_deg'), input.tiltFineStep_deg = cfg.pcTiltFineStep_deg; end
if isfield(cfg, 'pcTiltFineHalfWidth_deg'), input.tiltFineHalfWidth_deg = cfg.pcTiltFineHalfWidth_deg; end
input.basePitchOffsets_deg = (8.5 - (1:nBeam)) * (2*cfg.beamHalfNS_deg);
input.satisfactionFloor = 0.2;
input.useUserAntennaPattern = true;
end

function order = nearestSatelliteOrderLocal(satGeom, sourceIdx)
dist = arrayfun(@(s) norm(s.P_leo_km - satGeom(sourceIdx).P_leo_km), satGeom);
dist(sourceIdx) = inf;
[~, order] = sort(dist, 'ascend');
order = order(:)';  % row vector so for-loops iterate one index at a time
end

function [bAll, cAxis] = beamBoresightsLocal(rSat_m, vSat_mps, offsets_deg)
nadir = -rSat_m(:) / max(norm(rSat_m), eps);
along = vSat_mps(:) - dot(vSat_mps(:), nadir) * nadir;
along = along / max(norm(along), eps);
cAxis = cross(along, nadir);
cAxis = cAxis / max(norm(cAxis), eps);
bAll = zeros(3, numel(offsets_deg));
for k = 1:numel(offsets_deg)
    bAll(:, k) = rodriguesLocal(nadir, cAxis, offsets_deg(k));
end
end

function bSorted = reorderNorthToSouthLocal(rSat_m, bAll)
north = [0; 0; 1];
score = zeros(1, size(bAll, 2));
for k = 1:size(bAll, 2)
    score(k) = dot(bAll(:, k), north);
end
[~, order] = sort(score, 'descend');
bSorted = bAll(:, order);
if dot(rSat_m, north) < -0.99 * norm(rSat_m)
    bSorted = bAll;
end
end

function v = rodriguesLocal(u, axis, angle_deg)
a = deg2rad(angle_deg);
v = u * cos(a) + cross(axis, u) * sin(a) + axis * dot(axis, u) * (1 - cos(a));
v = v / max(norm(v), eps);
end

function P = groundXyzLocal(lat, lon, alt_km)
r = 6378.137 + alt_km;
P = r * [cosd(lat)*cosd(lon); cosd(lat)*sind(lon); sind(lat)];
end

function P = idealGsoXyzLocal(lon)
r = 42164;
P = r * [cosd(lon); sind(lon); 0];
end

function angle = angleDegLocal(a, b)
angle = acosd(max(-1, min(1, dot(a, b) / max(norm(a) * norm(b), eps))));
end
