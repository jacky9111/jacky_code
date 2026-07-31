function result = runGraphSelectionPolicyLocal(scenario, policy, rngSeed)
% runGraphSelectionPolicyLocal
% Run SBR + power allocation + HBR with one edge-selection policy.
% policy: 'dynamic' | 'initial' | 'max_user' | 'random'
%
% Key baseline distinction (see runSbrProcedureLocal / runHbrProcedureLocal):
%   dynamic  — recompute edge score every selection round
%   initial  — score once at procedure start, fixed sort, still iterative updates
%
% =====================================================================
% 【中文說明】EABR 演算法本體（純 MATLAB，不需要 STK）
%
% 論文 Method 章的三個步驟就寫在下面的 if/else 裡：
%   1. SBR（Safe-Beam Reassociation）
%      在候選圖上逐輪挑邊，把 helper 自家 user 換到安全束，釋放功率
%   2. EPFD-constrained power allocation
%      把釋放出的功率配給 helper recovery beam，且不得讓 EPFD 超標
%   3. HBR（Helper-Beam Reassociation）
%      把關閉束底下的 user 接到 helper recovery beam
%
% scenario.onlyHbrWithInitialPower = true 時只跑步驟 3，
% 且 recovery beam 只能用「預設功率」—— 這就是論文的 Only HBR baseline。
%
% policy 決定候選圖上「每輪要挑哪條邊」：
%   'dynamic'   每輪重算分數再挑（本論文提出的做法）
%   'initial'   只在開始時算一次分數，之後固定排序
%   'max_user'  永遠挑能服務最多 user 的邊
%   'random'    隨機挑（需要 rngSeed 才可重現）
%
% 這支同時被 overhead_evaluation 模組拿來量測 EABR 的線上執行時間
% （result.runtime_s 就是論文 overhead 圖的原始數據來源）。
% =====================================================================

if nargin >= 3 && isfinite(rngSeed)
    rng(rngSeed);
end
policy = lower(char(string(policy)));
tStart = tic;

st = initRecoveryStateLocal(scenario);

onlyHbrInitial = isfield(scenario, 'onlyHbrWithInitialPower') && ...
    logical(scenario.onlyHbrWithInitialPower);

if onlyHbrInitial
    % Only HBR: skip SBR / released-power boost; each recovery beam uses
    % its nominal/initial full-beam power.
    % 【Only HBR baseline】跳過 SBR 與功率釋放，recovery beam 只能用預設功率，
    % 所以在高負載時會受限於 helper 的既有功率 —— 這正是論文要對比的限制。
    st = allocateInitialBeamPowerForHbrLocal(st, scenario);
    st = runHbrProcedureLocal(st, scenario, policy);
else
    % --- SBR: iterative edge selection ---
    % Proposed (dynamic): recompute edge score every round.
    % Initial-score: compute score once at procedure start; fixed sort, no rescore.
    % 【EABR 步驟 1】SBR：在 safe-release 候選圖上逐輪挑邊，
    % 每挑一條就更新圖的狀態，把 helper 自家 user 換到安全束以釋放功率。
    st = runSbrProcedureLocal(st, scenario, policy);

    % Released power allocation to helper recovery beams.
    % 【EABR 步驟 2】把 SBR 釋放出的功率配給 helper recovery beam，
    % 配置過程受 EPFD 限制約束，確保救援後 aggregate EPFD 仍合法。
    st = allocateRecoveryPowerLocal(st, scenario);

    % --- HBR ---
    % 【EABR 步驟 3】HBR：把 critical 衛星關閉束底下的 user
    % 接到有覆蓋、且已取得足夠功率的 helper recovery beam。
    st = runHbrProcedureLocal(st, scenario, policy);
end

% 逐 user 算滿意度 min(1, 取得速率 / 需求速率)，再彙整成各項指標
satisfaction = evaluateAllUserSatisfactionLocal(st, scenario);
result.avgSatisfaction = mean(satisfaction, 'omitnan');
result.avgCriticalUserSatisfaction = criticalUserSatisfactionMetricLocal(st, scenario, satisfaction);
result.priorityWeightedRecovered = priorityWeightedRecoveredMetricLocal(st, scenario, satisfaction);
result.avgClosedBeamSatisfaction = closedBeamUserSatisfactionMetricLocal(st, scenario, satisfaction);
result.priorityWeightedClosedBeam = priorityWeightedClosedBeamMetricLocal(st, scenario, satisfaction);
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
st.safeBeamDemand_Mbps = zeros(nSat, nBeam);
st.safeBeamCap_Mbps = scenario.beamCapacity_Mbps * ones(nSat, nBeam);
st.recoveryPower_W = zeros(nSat, nBeam);
st.recoveryDemand_Mbps = zeros(nSat, nBeam);
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
    initOrder = scoreAndSortSbrEdgesLocal(st, scenario, edges, 'dynamic');
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
    initOrder = scoreAndSortHbrEdgesLocal(st, scenario, edges, 'dynamic');
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
subset = selectFeasibleSbrSubsetLocal(st, scenario, edge, cand);
if isempty(subset)
    score = 0;
    return;
end
demandSum = sum(scenario.userDemand_bps(subset)) / 1e6;
if strcmp(mode, 'max_user')
    score = numel(subset);
else
    score = demandSum; % demand-sum form; equals count*25 Mbps for homogeneous demand
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
if strcmp(mode, 'max_user')
    score = numel(subset);
else
    score = sum(scenario.priorityWeight(subset) .* ...
        estimateHbrSatisfactionLocal(st, scenario, edge, subset));
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
beamHalfNS_deg = scenario.beamHalfNS_deg;
alt_km = scenario.alt_km;
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
    uLat = asind(scenario.P_users_km(3, iu) / max(norm(scenario.P_users_km(:, iu)), eps));
    uLon = atan2d(scenario.P_users_km(2, iu), scenario.P_users_km(1, iu));
    if ~graphRecoverySharedLocal('userinfootprint', uLat, uLon, ...
            scenario.satGeom(edge.iHelpSat), edge.bRecovery, scenario.beamHalfEW_deg, ...
            beamHalfNS_deg, alt_km)
        continue;
    end
    cand(end+1) = iu; %#ok<AGROW>
end
end

function subset = selectFeasibleSbrSubsetLocal(st, scenario, edge, cand)
% Max demand-sum with non-degradation and safe-beam capacity.
iSafe = edge.iSafeSat;
bSafe = edge.bSafe;
iHelp = edge.iHelpSat;
bRel = edge.bRelease;
capRem_Mbps = st.safeBeamCap_Mbps(iSafe, bSafe) - st.safeBeamDemand_Mbps(iSafe, bSafe);
if capRem_Mbps <= 0
    subset = [];
    return;
end
% Sort by helper-side satisfaction descending (prefer easier moves).
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
for k = 1:numel(ord)
    iu = cand(ord(k));
    dMbps = scenario.userDemand_bps(iu) / 1e6;
    if dMbps > capRem_Mbps + 1e-9
        continue;
    end
    nSafe = max(sum(st.userServiceSat == iSafe & st.userServiceBeam == bSafe), 1) + numel(subset);
    sNew = graphRecoverySharedLocal('satisfaction', iu, iSafe, bSafe, ...
        scenario.fullBeamPower_W, nSafe, scenario.satGeom, scenario.P_users_km, ...
        scenario.params, scenario.userDemand_bps(iu));
    if sNew + 1e-9 < sOld(ord(k))
        continue;
    end
    subset(end+1) = iu; %#ok<AGROW>
    capRem_Mbps = capRem_Mbps - dMbps;
end
end

function subset = selectFeasibleHbrSubsetLocal(st, scenario, edge, cand)
iHelp = edge.iHelpSat;
bRec = edge.bRecovery;
Pavail = st.recoveryPower_W(iHelp, bRec);
if Pavail <= 0
    subset = [];
    return;
end
capRem_Mbps = recoveryCapMbpsLocal(Pavail, scenario) - st.recoveryDemand_Mbps(iHelp, bRec);
if capRem_Mbps <= 0
    subset = [];
    return;
end
estSat = estimateHbrSatisfactionLocal(st, scenario, edge, cand);
metric = scenario.priorityWeight(cand) .* estSat;
[~, ord] = sort(metric, 'descend');
subset = [];
for k = 1:numel(ord)
    iu = cand(ord(k));
    dMbps = scenario.userDemand_bps(iu) / 1e6;
    if dMbps > capRem_Mbps + 1e-9
        continue;
    end
    subset(end+1) = iu; %#ok<AGROW>
    capRem_Mbps = capRem_Mbps - dMbps;
end
end

function capMbps = recoveryCapMbpsLocal(power_W, scenario)
capMbps = scenario.beamCapacity_Mbps * power_W / max(scenario.fullBeamPower_W, eps);
end

function estSat = estimateHbrSatisfactionLocal(st, scenario, edge, users)
estSat = zeros(numel(users), 1);
Pbeam = st.recoveryPower_W(edge.iHelpSat, edge.bRecovery);
if Pbeam <= 0
    Pbeam = scenario.fullBeamPower_W;
end
nServe = max(numel(users) + sum(st.userServiceSat == edge.iHelpSat & ...
    st.userServiceBeam == edge.bRecovery), 1);
for k = 1:numel(users)
    iu = users(k);
    estSat(k) = graphRecoverySharedLocal('satisfaction', iu, edge.iHelpSat, edge.bRecovery, ...
        Pbeam, nServe, scenario.satGeom, scenario.P_users_km, scenario.params, scenario.userDemand_bps(iu));
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
    dMbps = scenario.userDemand_bps(iu) / 1e6;
    st.safeBeamDemand_Mbps(edge.iSafeSat, edge.bSafe) = ...
        st.safeBeamDemand_Mbps(edge.iSafeSat, edge.bSafe) + dMbps;
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
    dMbps = scenario.userDemand_bps(iu) / 1e6;
    st.recoveryDemand_Mbps(iHelp, bRec) = st.recoveryDemand_Mbps(iHelp, bRec) + dMbps;
    st.userServiceSat(iu) = iHelp;
    st.userServiceBeam(iu) = bRec;
    st.hbrDone(iu) = true;
    nMoved = nMoved + 1;
end
ok = true;
end

function st = allocateInitialBeamPowerForHbrLocal(st, scenario)
% Assign nominal/initial full-beam power to every HBR recovery beam (no SBR boost).
% Candidate HBR edges are already filtered to non-shut recovery beams.
st.recoveryPower_W = zeros(size(st.recoveryPower_W));
if ~isfield(scenario, 'hbrEdges') || isempty(scenario.hbrEdges)
    return;
end
P0 = scenario.fullBeamPower_W;
nSat = size(st.recoveryPower_W, 1);
nBeam = size(st.recoveryPower_W, 2);
for e = 1:numel(scenario.hbrEdges)
    iHelp = scenario.hbrEdges(e).iHelpSat;
    bRec = scenario.hbrEdges(e).bRecovery;
    if iHelp < 1 || iHelp > nSat || bRec < 1 || bRec > nBeam
        continue;
    end
    st.recoveryPower_W(iHelp, bRec) = P0;
end
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
for iu = 1:nUser
    iSat = st.userServiceSat(iu);
    b = st.userServiceBeam(iu);
    if iSat < 1 || b < 1
        satisfaction(iu) = 0;
        continue;
    end
    Pbeam = scenario.fullBeamPower_W;
    if st.recoveryPower_W(iSat, b) > 0
        Pbeam = st.recoveryPower_W(iSat, b);
    end
    nOn = max(sum(st.userServiceSat == iSat & st.userServiceBeam == b), 1);
    satisfaction(iu) = graphRecoverySharedLocal('satisfaction', iu, iSat, b, Pbeam, nOn, ...
        scenario.satGeom, scenario.P_users_km, scenario.params, scenario.userDemand_bps(iu));
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

function mask = closedBeamAffectedUserMaskLocal(st)
% Users whose home beam was shut down by EPFD (closed-beam affected cohort).
mask = st.closedBeamUserMask;
end
