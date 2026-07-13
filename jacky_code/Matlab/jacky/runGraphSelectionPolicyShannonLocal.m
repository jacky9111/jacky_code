function result = runGraphSelectionPolicyShannonLocal(scenario, policy, rngSeed)
% runGraphSelectionPolicyShannonLocal
% SBR + power allocation + HBR with Shannon capacity (B*log2(1+SINR)) throughout.
% No fixed beamCapacity_Mbps demand-sum accounting.
% policy: 'dynamic' | 'initial' | 'max_user' | 'random'
%
% Key baseline distinction (see runSbrProcedureLocal / runHbrProcedureLocal):
%   dynamic  — recompute edge score every selection round
%   initial  — score once at procedure start, fixed sort, still iterative updates

if nargin >= 3 && isfinite(rngSeed)
    rng(rngSeed);
end
policy = lower(char(string(policy)));
tStart = tic;

st = initRecoveryStateLocal(scenario);

% --- SBR: iterative edge selection ---
% Proposed (dynamic): recompute edge score every round.
% Initial-score: compute score once at procedure start; fixed sort, no rescore.
st = runSbrProcedureLocal(st, scenario, policy);

% Released power allocation to helper recovery beams.
st = allocateRecoveryPowerLocal(st, scenario);

% --- HBR ---
st = runHbrProcedureLocal(st, scenario, policy);

satisfaction = evaluateAllUserSatisfactionLocal(st, scenario);
result.avgSatisfaction = mean(satisfaction, 'omitnan');
result.avgCriticalUserSatisfaction = criticalUserSatisfactionMetricLocal(st, scenario, satisfaction);
result.priorityWeightedRecovered = priorityWeightedRecoveredMetricLocal(st, scenario, satisfaction);
result.avgClosedBeamSatisfaction = closedBeamUserSatisfactionMetricLocal(st, scenario, satisfaction);
result.priorityWeightedClosedBeam = priorityWeightedClosedBeamMetricLocal(st, scenario, satisfaction);
result.priorityWeightedDemandRecovery = priorityWeightedDemandRecoveryMetricLocal(st, scenario, satisfaction);
result.highPriorityRecoveryRatio = highPriorityRecoveryRatioMetricLocal(st, scenario, satisfaction);
result.unservedHighPriorityDemand_Mbps = unservedHighPriorityDemandMetricLocal(st, scenario, satisfaction);
result.satisfaction = satisfaction;
result.runtime_s = toc(tStart);
result.policy = string(policy);
result.nSbrActivations = st.nSbrActivations;
result.nHbrActivations = st.nHbrActivations;
end

function st = initRecoveryStateLocal(scenario)
nUser = scenario.nUsers;
nSat = scenario.nSat;
nBeam = scenario.nBeam;
st.userHomeSat = scenario.userHomeSat;
st.userHomeBeam = scenario.userHomeBeam;
st.userServiceSat = scenario.userServiceSat;
st.userServiceBeam = scenario.userServiceBeam;
st.closedBeamUserMask = scenario.closedBeamUserMask;
if isfield(scenario, 'criticalSatUserMask')
    st.criticalSatUserMask = scenario.criticalSatUserMask;
else
    st.criticalSatUserMask = false(nUser, 1);
end
st.sbrDone = false(nUser, 1);
st.hbrDone = false(nUser, 1);
st.recoveryPower_W = zeros(nSat, nBeam); % SBR-released boost only (added on top of fullBeamPower_W)
st.releasedPower_W = zeros(nSat, 1);
st.nSbrActivations = 0;
st.nHbrActivations = 0;
end

function st = runSbrProcedureLocal(st, scenario, policy)
edges = scenario.sbrEdges;
if isempty(edges)
    return;
end
% Initial-score baseline: score/sort once at procedure start (no rescore later).
if strcmp(policy, 'initial')
    initOrder = scoreAndSortSbrEdgesLocal(st, scenario, edges, 'initial');
    initOrder = initOrder(initOrder > 0);
    edgeQueue = initOrder;
    queuePos = 1;
    while queuePos <= numel(edgeQueue)
        eid = edgeQueue(queuePos);
        queuePos = queuePos + 1;
        edge = edges(eid);
        [feasible, st, moved] = applySbrEdgeLocal(st, scenario, edge);
        if ~feasible || moved == 0
            continue;
        end
        st.nSbrActivations = st.nSbrActivations + 1;
    end
    return;
end

while true
  switch policy
    case 'dynamic'
      order = scoreAndSortSbrEdgesLocal(st, scenario, edges, 'dynamic');
    case 'max_user'
      order = scoreAndSortSbrEdgesLocal(st, scenario, edges, 'max_user');
    case 'random'
      order = findActiveSbrEdgesLocal(st, scenario, edges);
      if isempty(order)
        break;
      end
      order = order(randi(numel(order)));
    otherwise
      error('Unknown SBR policy: %s', policy);
  end
  if isempty(order) || (isscalar(order) && order == 0)
    break;
  end
  if strcmp(policy, 'random')
    eid = order;
    edge = edges(eid);
    [feasible, st, moved] = applySbrEdgeLocal(st, scenario, edge);
    if ~feasible || moved == 0
      edges(eid).blocked = true;
      if isempty(findActiveSbrEdgesLocal(st, scenario, edges))
        break;
      end
      continue;
    end
    st.nSbrActivations = st.nSbrActivations + 1;
    continue;
  end
  progressed = false;
  for k = 1:numel(order)
    eid = order(k);
    if eid <= 0
      continue;
    end
    edge = edges(eid);
    [feasible, st, moved] = applySbrEdgeLocal(st, scenario, edge);
    if feasible && moved > 0
      st.nSbrActivations = st.nSbrActivations + 1;
      progressed = true;
      break;
    end
  end
  if ~progressed
    break;
  end
end
end

function st = runHbrProcedureLocal(st, scenario, policy)
edges = scenario.hbrEdges;
if isempty(edges)
    return;
end
if strcmp(policy, 'initial')
    initOrder = scoreAndSortHbrEdgesLocal(st, scenario, edges, 'initial');
    initOrder = initOrder(initOrder > 0);
    queuePos = 1;
    while queuePos <= numel(initOrder)
        eid = initOrder(queuePos);
        queuePos = queuePos + 1;
        edge = edges(eid);
        [feasible, st, moved] = applyHbrEdgeLocal(st, scenario, edge);
        if ~feasible || moved == 0
            continue;
        end
        st.nHbrActivations = st.nHbrActivations + 1;
    end
    return;
end

while true
  switch policy
    case 'dynamic'
      order = scoreAndSortHbrEdgesLocal(st, scenario, edges, 'dynamic');
    case 'max_user'
      order = scoreAndSortHbrEdgesLocal(st, scenario, edges, 'max_user');
    case 'random'
      order = findActiveHbrEdgesLocal(st, scenario, edges);
      if isempty(order), break; end
      order = order(randi(numel(order)));
    otherwise
      error('Unknown HBR policy: %s', policy);
  end
  if isempty(order) || (isscalar(order) && order == 0)
    break;
  end
  if strcmp(policy, 'random')
    eid = order;
    edge = edges(eid);
    [feasible, st, moved] = applyHbrEdgeLocal(st, scenario, edge);
    if ~feasible || moved == 0
      edges(eid).blocked = true;
      if isempty(findActiveHbrEdgesLocal(st, scenario, edges))
        break;
      end
      continue;
    end
    st.nHbrActivations = st.nHbrActivations + 1;
    continue;
  end
  progressed = false;
  for k = 1:numel(order)
    eid = order(k);
    if eid <= 0
      continue;
    end
    edge = edges(eid);
    [feasible, st, moved] = applyHbrEdgeLocal(st, scenario, edge);
    if feasible && moved > 0
      st.nHbrActivations = st.nHbrActivations + 1;
      progressed = true;
      break;
    end
  end
  if ~progressed
    break;
  end
end
end

function order = scoreAndSortSbrEdgesLocal(st, scenario, edges, mode)
nE = numel(edges);
scores = zeros(nE, 1);
for e = 1:nE
    [sc, ~] = scoreSbrEdgeLocal(st, scenario, edges(e), mode);
    scores(e) = sc;
end
[~, order] = sort(scores, 'descend');
order = order(scores(order) > 0);
end

function order = scoreAndSortHbrEdgesLocal(st, scenario, edges, mode)
nE = numel(edges);
scores = zeros(nE, 1);
for e = 1:nE
    [sc, ~] = scoreHbrEdgeLocal(st, scenario, edges(e), mode);
    scores(e) = sc;
end
[~, order] = sort(scores, 'descend');
order = order(scores(order) > 0);
end

function active = findActiveSbrEdgesLocal(st, scenario, edges)
active = [];
for e = 1:numel(edges)
    if isfield(edges, 'blocked') && edges(e).blocked
        continue;
    end
    [sc, ~] = scoreSbrEdgeLocal(st, scenario, edges(e), 'dynamic');
    if sc > 0
        active(end+1) = e; %#ok<AGROW>
    end
end
end

function active = findActiveHbrEdgesLocal(st, scenario, edges)
active = [];
for e = 1:numel(edges)
    if isfield(edges, 'blocked') && edges(e).blocked
        continue;
    end
    [sc, ~] = scoreHbrEdgeLocal(st, scenario, edges(e), 'dynamic');
    if sc > 0
        active(end+1) = e; %#ok<AGROW>
    end
end
end

function [score, subset] = scoreSbrEdgeLocal(st, scenario, edge, mode)
subset = [];
cand = candidateSbrUsersLocal(st, scenario, edge);
if isempty(cand)
    score = 0;
    return;
end
[subset, ~] = selectFeasibleSbrSubsetLocal(st, scenario, edge, cand);
if isempty(subset)
    score = 0;
    return;
end
demandSum = sum(scenario.userDemand_bps(subset)) / 1e6;
if strcmp(mode, 'max_user')
    score = numel(subset);
else
    score = demandSum;
end
end

function [score, subset] = scoreHbrEdgeLocal(st, scenario, edge, mode)
subset = [];
cand = candidateHbrUsersLocal(st, scenario, edge);
if isempty(cand)
    score = 0;
    return;
end
subset = selectFeasibleHbrSubsetLocal(st, scenario, edge, cand);
if isempty(subset)
    score = 0;
    return;
end
iHelp = edge.iHelpSat;
bRec = edge.bRecovery;
[Prelay_W, ~] = helperBeamRelayPoolLocal(st, scenario, iHelp, bRec);
nRelayBase = helperBeamRelayCountLocal(st, scenario, iHelp, bRec);
if strcmp(mode, 'max_user')
    score = numel(subset);
elseif strcmp(mode, 'initial')
    score = 0;
    for k = 1:numel(subset)
        iu = subset(k);
        nRelay = nRelayBase + k;
        sTry = relayUserSatisfactionOnBeamLocal(iu, iHelp, bRec, Prelay_W, nRelay, scenario);
        score = score + sTry;
    end
else
    score = 0;
    for k = 1:numel(subset)
        iu = subset(k);
        nRelay = nRelayBase + k;
        sTry = relayUserSatisfactionOnBeamLocal(iu, iHelp, bRec, Prelay_W, nRelay, scenario);
        score = score + scenario.priorityWeight(iu) * sTry;
    end
end
end

function cand = candidateSbrUsersLocal(st, scenario, edge)
cand = [];
for iu = 1:scenario.nUsers
    if st.userHomeSat(iu) ~= edge.iHelpSat || st.userHomeBeam(iu) ~= edge.bRelease
        continue;
    end
    if st.sbrDone(iu)
        continue;
    end
    if st.userServiceSat(iu) ~= edge.iHelpSat || st.userServiceBeam(iu) ~= edge.bRelease
        continue;
    end
    if ~graphRecoverySharedLocal('usercovered', scenario.satGeom(edge.iSafeSat), edge.bSafe, ...
            scenario.P_users_km(:, iu), scenario.beamHalfEW_deg, scenario.beamHalfNS_deg)
        continue;
    end
    cand(end+1) = iu; %#ok<AGROW>
end
end

function cand = candidateHbrUsersLocal(st, scenario, edge)
cand = [];
for iu = 1:scenario.nUsers
    if ~st.closedBeamUserMask(iu)
        continue;
    end
    if st.userHomeSat(iu) ~= edge.iClosedSat || st.userHomeBeam(iu) ~= edge.bClosed
        continue;
    end
    if st.hbrDone(iu)
        continue;
    end
    if ~graphRecoverySharedLocal('usercovered', scenario.satGeom(edge.iHelpSat), edge.bRecovery, ...
            scenario.P_users_km(:, iu), scenario.beamHalfEW_deg, scenario.beamHalfNS_deg)
        continue;
    end
    cand(end+1) = iu; %#ok<AGROW>
end
end

function Pbeam = helperBeamEffectivePowerLocal(st, scenario, iSat, b)
% Nominal on-air power on open beams plus SBR-released boost (capped at maxBeamPower_W).
Pbeam = 0;
if iSat < 1 || b < 1
    return;
end
if ~scenario.shutOffMat(iSat, b)
    Pbeam = scenario.fullBeamPower_W;
end
Pbeam = Pbeam + st.recoveryPower_W(iSat, b);
if isfield(scenario, 'maxBeamPower_W') && isfinite(scenario.maxBeamPower_W)
    Pbeam = min(Pbeam, scenario.maxBeamPower_W);
end
end

function nativeList = helperBeamNativeListLocal(st, scenario, iSat, b)
% Non-closed-beam users already on this helper recovery beam (reserve power for them first).
onBeam = find(st.userServiceSat == iSat & st.userServiceBeam == b);
nativeList = onBeam(~scenario.closedBeamUserMask(onBeam));
end

function relayCount = helperBeamRelayCountLocal(st, scenario, iSat, b)
onBeam = find(st.userServiceSat == iSat & st.userServiceBeam == b);
relayCount = sum(scenario.closedBeamUserMask(onBeam));
end

function [Prelay_W, PnativeReserve_W] = helperBeamRelayPoolLocal(st, scenario, iSat, b)
% Pool for HBR relays = total effective power minus per-native reserve for sat=1.
Ptotal = helperBeamEffectivePowerLocal(st, scenario, iSat, b);
nativeList = helperBeamNativeListLocal(st, scenario, iSat, b);
if isempty(nativeList)
    PnativeReserve_W = 0;
    Prelay_W = Ptotal;
    return;
end
[PnativeReserve_W, ~] = nativePowerReserveSumGraphLocal(nativeList, iSat, b, 1.0, ...
    scenario.satGeom, scenario.P_users_km, scenario.params, scenario.userDemand_bps);
if ~isfinite(PnativeReserve_W)
    PnativeReserve_W = Ptotal;
end
Prelay_W = max(Ptotal - PnativeReserve_W, 0);
end

function [Psum_W, Puser_W] = nativePowerReserveSumGraphLocal(nativeList, iSat, b, targetSat, ...
    satGeom, P_users_km, P, userDemand_bps)
nNative = numel(nativeList);
Puser_W = nan(nNative, 1);
if nNative == 0
    Psum_W = 0;
    return;
end
for jj = 1:nNative
    iu = nativeList(jj);
    Puser_W(jj) = transmitPowerForUserTargetGraphLocal(iu, iSat, b, targetSat, nNative, ...
        satGeom, P_users_km, P, userDemand_bps(iu));
end
if any(~isfinite(Puser_W))
    Psum_W = inf;
else
    Psum_W = sum(Puser_W);
end
end

function Ptx_W = transmitPowerForUserTargetGraphLocal(iu, iSat, b, targetSat, usersInBeam, ...
    satGeom, P_users_km, P, userDemand_bps)
targetSat = max(0, min(1, double(targetSat)));
Buser = P.B_Hz;
noisePower_W = P.kB * P.user_noise_temp_K * Buser;
Gur_lin = 10^(P.GS_LEO_Gmax_dBi / 10);
usersInBeam = max(double(usersInBeam), 1);
targetCapacityPerUser_bps = targetSat * userDemand_bps * usersInBeam;
sinrReq = 2^(targetCapacityPerUser_bps / max(Buser, eps)) - 1;
channelGain = userLinkChannelGainGraphLocal(satGeom(iSat), b, P_users_km(:, iu), P, Gur_lin);
if channelGain <= 0 || ~isfinite(channelGain)
    Ptx_W = inf;
else
    Ptx_W = sinrReq * noisePower_W / channelGain;
end
end

function channelGain = userLinkChannelGainGraphLocal(satGeomOne, beamIdx, P_user_km, P, Gur_lin)
P_leo_km = satGeomOne.P_leo_km;
b_hat = satGeomOne.b_all(:, beamIdx);
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
pathGain = (P.lambda_m^2) / max((4 * pi * d_m)^2, eps);
channelGain = Gt_lin * Gur_lin * pathGain;
end

function sTry = relayUserSatisfactionOnBeamLocal(iu, iSat, b, Prelay_W, nRelay, scenario)
if nRelay < 1 || Prelay_W <= 0
    sTry = 0;
    return;
end
PtxEach = Prelay_W / nRelay;
sTry = graphRecoverySharedLocal('satisfaction', iu, iSat, b, PtxEach, nRelay, ...
    scenario.satGeom, scenario.P_users_km, scenario.params, scenario.userDemand_bps(iu));
end

function [subset, sNewVec] = selectFeasibleSbrSubsetLocal(st, scenario, edge, cand)
% Shannon fair-share: non-degradation on helper beam + positive safe-beam satisfaction.
iSafe = edge.iSafeSat;
bSafe = edge.bSafe;
iHelp = edge.iHelpSat;
bRel = edge.bRelease;
sOld = zeros(numel(cand), 1);
for k = 1:numel(cand)
    iu = cand(k);
    nOn = max(sum(st.userServiceSat == iHelp & st.userServiceBeam == bRel), 1);
    sOld(k) = graphRecoverySharedLocal('satisfaction', iu, iHelp, bRel, ...
        scenario.fullBeamPower_W, nOn, scenario.satGeom, scenario.P_users_km, ...
        scenario.params, scenario.userDemand_bps(iu));
end
[~, ord] = sort(sOld, 'descend');
subset = [];
sNewVec = [];
for k = 1:numel(ord)
    iu = cand(ord(k));
    nSafe = max(sum(st.userServiceSat == iSafe & st.userServiceBeam == bSafe), 1) + numel(subset);
    sNew = graphRecoverySharedLocal('satisfaction', iu, iSafe, bSafe, ...
        scenario.fullBeamPower_W, nSafe, scenario.satGeom, scenario.P_users_km, ...
        scenario.params, scenario.userDemand_bps(iu));
    if sNew <= 0 || sNew + 1e-9 < sOld(ord(k))
        continue;
    end
    subset(end+1) = iu; %#ok<AGROW>
    sNewVec(end+1) = sNew; %#ok<AGROW>
end
end

function subset = selectFeasibleHbrSubsetLocal(st, scenario, edge, cand)
iHelp = edge.iHelpSat;
bRec = edge.bRecovery;
[Prelay_W, PnativeReserve_W] = helperBeamRelayPoolLocal(st, scenario, iHelp, bRec);
Ptotal = helperBeamEffectivePowerLocal(st, scenario, iHelp, bRec);
if Ptotal <= 0 || (Prelay_W <= 0 && PnativeReserve_W >= Ptotal - 1e-12)
    subset = [];
    return;
end
nRelayBase = helperBeamRelayCountLocal(st, scenario, iHelp, bRec);
estSat = zeros(numel(cand), 1);
for k = 1:numel(cand)
    estSat(k) = relayUserSatisfactionOnBeamLocal(cand(k), iHelp, bRec, Prelay_W, ...
        nRelayBase + 1, scenario);
end
metric = scenario.priorityWeight(cand) .* estSat;
[~, ord] = sort(metric, 'descend');
subset = [];
for k = 1:numel(ord)
    iu = cand(ord(k));
    nRelay = nRelayBase + numel(subset) + 1;
    sTry = relayUserSatisfactionOnBeamLocal(iu, iHelp, bRec, Prelay_W, nRelay, scenario);
    if sTry <= 0
        continue;
    end
    subset(end+1) = iu; %#ok<AGROW>
end
end

function [ok, st, nMoved] = applySbrEdgeLocal(st, scenario, edge)
nMoved = 0;
[score, subset] = scoreSbrEdgeLocal(st, scenario, edge, 'dynamic');
if score <= 0 || isempty(subset)
    ok = false;
    return;
end
nOnRelease = max(sum(st.userServiceSat == edge.iHelpSat & st.userServiceBeam == edge.bRelease), 1);
for iu = subset
    st.userServiceSat(iu) = edge.iSafeSat;
    st.userServiceBeam(iu) = edge.bSafe;
    st.sbrDone(iu) = true;
    nMoved = nMoved + 1;
end
if nMoved > 0
    st.releasedPower_W(edge.iHelpSat) = st.releasedPower_W(edge.iHelpSat) + ...
        nMoved * scenario.fullBeamPower_W / nOnRelease;
end
ok = true;
end

function [ok, st, nMoved] = applyHbrEdgeLocal(st, scenario, edge)
nMoved = 0;
[score, subset] = scoreHbrEdgeLocal(st, scenario, edge, 'dynamic');
if score <= 0 || isempty(subset)
    ok = false;
    return;
end
iHelp = edge.iHelpSat;
bRec = edge.bRecovery;
for iu = subset
    st.userServiceSat(iu) = iHelp;
    st.userServiceBeam(iu) = bRec;
    st.hbrDone(iu) = true;
    nMoved = nMoved + 1;
end
ok = true;
end

function st = allocateRecoveryPowerLocal(st, scenario)
poolMode = 'per_sat';
if isfield(scenario, 'recoveryPowerPoolMode') && strlength(string(scenario.recoveryPowerPoolMode)) > 0
    poolMode = lower(char(string(scenario.recoveryPowerPoolMode)));
end
if strcmp(poolMode, 'global')
    st = allocateRecoveryPowerGlobalPoolLocal(st, scenario);
else
    st = allocateRecoveryPowerPerSatPoolLocal(st, scenario);
end
end

function st = allocateRecoveryPowerPerSatPoolLocal(st, scenario)
for iHelp = 1:scenario.nSat
    pool = st.releasedPower_W(iHelp);
    if pool <= 0
        continue;
    end
    recBeams = [];
    demand = [];
    for e = 1:numel(scenario.hbrEdges)
        if scenario.hbrEdges(e).iHelpSat ~= iHelp
            continue;
        end
        bRec = scenario.hbrEdges(e).bRecovery;
        cand = candidateHbrUsersLocal(st, scenario, scenario.hbrEdges(e));
        if isempty(cand)
            continue;
        end
        pw = sum(scenario.priorityWeight(cand) .* scenario.userDemand_bps(cand) / 1e6);
        recBeams(end+1) = bRec; %#ok<AGROW>
        demand(end+1) = pw; %#ok<AGROW>
    end
    if isempty(recBeams)
        continue;
    end
    [recBeamsUnique, ~, ic] = unique(recBeams, 'stable');
    demandUnique = zeros(size(recBeamsUnique));
    for j = 1:numel(demand)
        demandUnique(ic(j)) = demandUnique(ic(j)) + demand(j);
    end
    recBeams = recBeamsUnique;
    demand = demandUnique;
    [~, ord] = sort(demand, 'descend');
    for k = 1:numel(ord)
        if pool <= 0
            break;
        end
        bRec = recBeams(ord(k));
        alloc = min(pool, scenario.maxBeamPower_W);
        st.recoveryPower_W(iHelp, bRec) = st.recoveryPower_W(iHelp, bRec) + alloc;
        pool = pool - alloc;
    end
    st.releasedPower_W(iHelp) = pool;
end
end

function st = allocateRecoveryPowerGlobalPoolLocal(st, scenario)
globalPool = sum(st.releasedPower_W);
st.releasedPower_W(:) = 0;
if globalPool <= 0
    return;
end
recBeams = [];
demand = [];
iHelpList = [];
for iHelp = 1:scenario.nSat
    [bList, dList] = recoveryBeamDemandOnHelperLocal(st, scenario, iHelp);
    for j = 1:numel(bList)
        iHelpList(end+1) = iHelp; %#ok<AGROW>
        recBeams(end+1) = bList(j); %#ok<AGROW>
        demand(end+1) = dList(j); %#ok<AGROW>
    end
end
if isempty(recBeams)
    return;
end
[~, ord] = sort(demand, 'descend');
for k = 1:numel(ord)
    if globalPool <= 0
        break;
    end
    iHelp = iHelpList(ord(k));
    bRec = recBeams(ord(k));
    alloc = min(globalPool, scenario.maxBeamPower_W);
    st.recoveryPower_W(iHelp, bRec) = st.recoveryPower_W(iHelp, bRec) + alloc;
    globalPool = globalPool - alloc;
end
end

function [recBeams, demand] = recoveryBeamDemandOnHelperLocal(st, scenario, iHelp)
recBeams = [];
demand = [];
for e = 1:numel(scenario.hbrEdges)
    edge = scenario.hbrEdges(e);
    if edge.iHelpSat ~= iHelp
        continue;
    end
    cand = candidateHbrUsersLocal(st, scenario, edge);
    if isempty(cand)
        continue;
    end
    pw = sum(scenario.priorityWeight(cand) .* scenario.userDemand_bps(cand) / 1e6);
    idx = find(recBeams == edge.bRecovery, 1);
    if isempty(idx)
        recBeams(end+1) = edge.bRecovery; %#ok<AGROW>
        demand(end+1) = pw; %#ok<AGROW>
    else
        demand(idx) = demand(idx) + pw;
    end
end
end

function satisfaction = evaluateAllUserSatisfactionLocal(st, scenario)
nUser = scenario.nUsers;
satisfaction = zeros(nUser, 1);
for iSat = 1:scenario.nSat
    for b = 1:scenario.nBeam
        iuList = find(st.userServiceSat == iSat & st.userServiceBeam == b);
        if isempty(iuList)
            continue;
        end
        relayList = iuList(scenario.closedBeamUserMask(iuList));
        nativeList = iuList(~scenario.closedBeamUserMask(iuList));
        relayList = relayList(:);
        nativeList = nativeList(:);
        Ptotal = helperBeamEffectivePowerLocal(st, scenario, iSat, b);
        if Ptotal <= 0
            continue;
        end
        if isempty(relayList)
            nOn = numel(iuList);
            for jj = 1:numel(iuList)
                iu = iuList(jj);
                satisfaction(iu) = graphRecoverySharedLocal('satisfaction', iu, iSat, b, Ptotal, nOn, ...
                    scenario.satGeom, scenario.P_users_km, scenario.params, scenario.userDemand_bps(iu));
            end
            continue;
        end
        [Prelay_W, PnativeReserve_W] = helperBeamRelayPoolLocal(st, scenario, iSat, b);
        if ~isempty(nativeList)
            [~, PuserNat_W] = nativePowerReserveSumGraphLocal(nativeList, iSat, b, 1.0, ...
                scenario.satGeom, scenario.P_users_km, scenario.params, scenario.userDemand_bps);
            nNat = numel(nativeList);
            if isfinite(PnativeReserve_W) && PnativeReserve_W <= Ptotal + 1e-9
                for jj = 1:nNat
                    iu = nativeList(jj);
                    Ptx = PuserNat_W(jj);
                    satisfaction(iu) = graphRecoverySharedLocal('satisfaction', iu, iSat, b, Ptx, nNat, ...
                        scenario.satGeom, scenario.P_users_km, scenario.params, scenario.userDemand_bps(iu));
                end
            else
                for jj = 1:nNat
                    iu = nativeList(jj);
                    satisfaction(iu) = graphRecoverySharedLocal('satisfaction', iu, iSat, b, Ptotal, nNat, ...
                        scenario.satGeom, scenario.P_users_km, scenario.params, scenario.userDemand_bps(iu));
                end
            end
        end
        nRelay = numel(relayList);
        if nRelay > 0 && Prelay_W > 0
            PtxRelay = Prelay_W / nRelay;
            for jj = 1:nRelay
                iu = relayList(jj);
                satisfaction(iu) = graphRecoverySharedLocal('satisfaction', iu, iSat, b, PtxRelay, nRelay, ...
                    scenario.satGeom, scenario.P_users_km, scenario.params, scenario.userDemand_bps(iu));
            end
        end
    end
end
end

function m = priorityWeightedRecoveredMetricLocal(st, scenario, satisfaction)
mask = closedBeamAffectedUserMaskLocal(st);
if ~any(mask)
    m = NaN;
    return;
end
w = scenario.priorityWeight(mask);
num = sum(w .* satisfaction(mask));
den = sum(w);
m = num / max(den, eps);
end

function m = criticalUserSatisfactionMetricLocal(st, scenario, satisfaction)
mask = closedBeamAffectedUserMaskLocal(st);
if ~any(mask)
    m = NaN;
    return;
end
m = mean(satisfaction(mask), 'omitnan');
end

function m = closedBeamUserSatisfactionMetricLocal(st, scenario, satisfaction)
mask = closedBeamAffectedUserMaskLocal(st);
if ~any(mask)
    m = NaN;
    return;
end
m = mean(satisfaction(mask), 'omitnan');
end

function m = priorityWeightedClosedBeamMetricLocal(st, scenario, satisfaction)
mask = closedBeamAffectedUserMaskLocal(st);
if ~any(mask)
    m = NaN;
    return;
end
w = scenario.priorityWeight(mask);
num = sum(w .* satisfaction(mask));
den = sum(w);
m = num / max(den, eps);
end

function m = priorityWeightedDemandRecoveryMetricLocal(st, scenario, satisfaction)
mask = closedBeamAffectedUserMaskLocal(st);
if ~any(mask)
    m = NaN;
    return;
end
w = scenario.priorityWeight(mask);
dMbps = scenario.userDemand_bps(mask) / 1e6;
num = sum(w .* dMbps .* satisfaction(mask));
den = sum(w .* dMbps);
m = num / max(den, eps);
end

function m = highPriorityRecoveryRatioMetricLocal(st, scenario, satisfaction)
mask = highPriorityClosedBeamMaskLocal(st, scenario);
if ~any(mask)
    m = NaN;
    return;
end
thr = highPriorityRecoveryThresholdLocal(scenario);
m = mean(satisfaction(mask) >= thr, 'omitnan');
end

function m = unservedHighPriorityDemandMetricLocal(st, scenario, satisfaction)
mask = highPriorityClosedBeamMaskLocal(st, scenario);
if ~any(mask)
    m = NaN;
    return;
end
dMbps = scenario.userDemand_bps(mask) / 1e6;
m = sum(dMbps .* max(1 - satisfaction(mask), 0));
end

function mask = highPriorityClosedBeamMaskLocal(st, scenario)
closedMask = closedBeamAffectedUserMaskLocal(st);
if ~any(closedMask)
    mask = closedMask;
    return;
end
maxWeight = max(scenario.priorityWeight(closedMask));
mask = closedMask & (scenario.priorityWeight == maxWeight);
end

function thr = highPriorityRecoveryThresholdLocal(scenario)
if isfield(scenario, 'highPriorityRecoveryThreshold') && ...
        isfinite(scenario.highPriorityRecoveryThreshold)
    thr = scenario.highPriorityRecoveryThreshold;
else
    thr = 0.8;
end
end

function mask = closedBeamAffectedUserMaskLocal(st)
% Users whose home beam was shut down by EPFD (closed-beam affected cohort).
mask = st.closedBeamUserMask;
end
