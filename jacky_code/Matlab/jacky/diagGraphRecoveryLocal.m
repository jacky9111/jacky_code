function diagGraphRecoveryLocal(opts)
if nargin < 1, opts = struct(); end
addpath(fileparts(mfilename('fullpath')));
s = buildDenseGraphScenarioLocal(opts);
Pw = s.fullBeamPower_W;

% Step through policy manually by calling the function and inspecting
% Re-implement minimal state trace inside diagnostic
st = struct();
st.userServiceSat = s.userServiceSat;
st.userServiceBeam = s.userServiceBeam;
st.sbrDone = false(s.nUsers, 1);
st.hbrDone = false(s.nUsers, 1);
st.releasedPower_W = zeros(s.nSat, 1);
st.recoveryPower_W = zeros(s.nSat, s.nBeam);
st.closedBeamUserMask = s.closedBeamUserMask;

fprintf('\n--- DIAG: initial ---\n');
fprintf('closed=%d, non-closed on service=%d\n', sum(s.closedBeamUserMask), sum(~s.closedBeamUserMask & st.userServiceSat > 0));

r = runGraphSelectionPolicyShannonLocal(s, 'dynamic', 28);
fprintf('\n--- DIAG: final ---\n');
fprintf('SBR activations=%d, HBR activations=%d\n', r.nSbrActivations, r.nHbrActivations);
fprintf('closed recovered=%d / %d\n', sum(r.satisfaction(s.closedBeamUserMask) > 0), sum(s.closedBeamUserMask));

% SBR cannot touch closed users (serviceSat=0)
nSbrCandClosed = 0;
for iu = find(s.closedBeamUserMask)'
    for e = 1:numel(s.sbrEdges)
        ed = s.sbrEdges(e);
        if s.userHomeSat(iu) == ed.iHelpSat && s.userHomeBeam(iu) == ed.bRelease ...
                && st.userServiceSat(iu) == ed.iHelpSat && st.userServiceBeam(iu) == ed.bRelease
            nSbrCandClosed = nSbrCandClosed + 1;
            break;
        end
    end
end
fprintf('closed users eligible for SBR (must be on open helper beam): %d\n', nSbrCandClosed);

% Count HBR candidates for closed users
nHbrReach = 0;
for iu = find(s.closedBeamUserMask)'
    for e = 1:numel(s.hbrEdges)
        ed = s.hbrEdges(e);
        if s.userHomeSat(iu) ~= ed.iClosedSat || s.userHomeBeam(iu) ~= ed.bClosed
            continue;
        end
        uLat = asind(s.P_users_km(3, iu) / max(norm(s.P_users_km(:, iu)), eps));
        uLon = atan2d(s.P_users_km(2, iu), s.P_users_km(1, iu));
        if graphRecoverySharedLocal('userinfootprint', uLat, uLon, ...
                s.satGeom(ed.iHelpSat), ed.bRecovery, s.beamHalfEW_deg, s.beamHalfNS_deg, s.alt_km)
            nHbrReach = nHbrReach + 1;
            break;
        end
    end
end
fprintf('closed users with HBR footprint coverage: %d / %d\n', nHbrReach, sum(s.closedBeamUserMask));

% Trace SBR -> power -> HBR bottleneck
st2 = initDiagStateLocal(s);
[st2, nSbr] = runDiagSbrLocal(st2, s);
totalReleased = sum(st2.releasedPower_W);
fprintf('\nAfter SBR: activations=%d, total released power=%.4f W (full beam=%.2f W)\n', nSbr, totalReleased, Pw);
fprintf('SBR moved users (non-closed only): %d\n', sum(st2.sbrDone));
st2 = allocateDiagRecoveryPowerLocal(st2, s);
totalRecPow = sum(st2.recoveryPower_W(:));
fprintf('After power alloc: recovery power on beams=%.4f W across %d beams\n', ...
    totalRecPow, sum(st2.recoveryPower_W(:) > 0));
nHbrCandAfter = 0;
for e = 1:numel(s.hbrEdges)
    ed = s.hbrEdges(e);
    if st2.recoveryPower_W(ed.iHelpSat, ed.bRecovery) <= 0
        continue;
    end
    nc = 0;
    for iu = find(s.closedBeamUserMask)'
        if st2.hbrDone(iu), continue; end
        if s.userHomeSat(iu) ~= ed.iClosedSat || s.userHomeBeam(iu) ~= ed.bClosed, continue; end
        uLat = asind(s.P_users_km(3, iu) / max(norm(s.P_users_km(:, iu)), eps));
        uLon = atan2d(s.P_users_km(2, iu), s.P_users_km(1, iu));
        if graphRecoverySharedLocal('userinfootprint', uLat, uLon, ...
                s.satGeom(ed.iHelpSat), ed.bRecovery, s.beamHalfEW_deg, s.beamHalfNS_deg, s.alt_km)
            nc = nc + 1;
        end
    end
    if nc > 0
        nHbrCandAfter = nHbrCandAfter + nc;
        fprintf('  beam %s B%02d: Pavail=%.3f W, closed candidates=%d\n', ...
            s.satNames(ed.iHelpSat), ed.bRecovery, st2.recoveryPower_W(ed.iHelpSat, ed.bRecovery), nc);
    end
end
fprintf('closed users reachable on powered recovery beams: %d (counting overlaps)\n', nHbrCandAfter);

% Linear cap comparison
rLin = runGraphSelectionPolicyLocal(s, 'dynamic', 28);
fprintf('Linear-cap dynamic: SBR=%d HBR=%d closed recovered=%d\n', ...
    rLin.nSbrActivations, rLin.nHbrActivations, sum(rLin.satisfaction(s.closedBeamUserMask) > 0));

end

function st = initDiagStateLocal(scenario)
st.userServiceSat = scenario.userServiceSat;
st.userServiceBeam = scenario.userServiceBeam;
st.sbrDone = false(scenario.nUsers, 1);
st.hbrDone = false(scenario.nUsers, 1);
st.releasedPower_W = zeros(scenario.nSat, 1);
st.recoveryPower_W = zeros(scenario.nSat, scenario.nBeam);
end

function [st, nAct] = runDiagSbrLocal(st, scenario)
edges = scenario.sbrEdges;
nAct = 0;
while true
    order = diagScoreSbrOrderLocal(st, scenario, edges);
    if isempty(order), break; end
    progressed = false;
    for k = 1:numel(order)
        edge = edges(order(k));
        [ok, st, moved] = diagApplySbrLocal(st, scenario, edge);
        if ok && moved > 0
            nAct = nAct + 1;
            progressed = true;
            break;
        end
    end
    if ~progressed, break; end
end
end

function order = diagScoreSbrOrderLocal(st, scenario, edges)
scores = zeros(numel(edges), 1);
for e = 1:numel(edges)
    scores(e) = diagScoreOneSbrLocal(st, scenario, edges(e));
end
[~, order] = sort(scores, 'descend');
order = order(scores(order) > 0);
end

function score = diagScoreOneSbrLocal(st, scenario, edge)
cand = diagSbrCandLocal(st, scenario, edge);
if isempty(cand), score = 0; return; end
subset = diagSbrSubsetLocal(st, scenario, edge, cand);
score = numel(subset);
end

function cand = diagSbrCandLocal(st, scenario, edge)
cand = [];
for iu = 1:scenario.nUsers
    if scenario.userHomeSat(iu) ~= edge.iHelpSat || scenario.userHomeBeam(iu) ~= edge.bRelease, continue; end
    if st.sbrDone(iu), continue; end
    if st.userServiceSat(iu) ~= edge.iHelpSat || st.userServiceBeam(iu) ~= edge.bRelease, continue; end
    if ~graphRecoverySharedLocal('usercovered', scenario.satGeom(edge.iSafeSat), edge.bSafe, ...
            scenario.P_users_km(:, iu), scenario.beamHalfEW_deg, scenario.beamHalfNS_deg)
        continue;
    end
    cand(end+1) = iu; %#ok<AGROW>
end
end

function subset = diagSbrSubsetLocal(st, scenario, edge, cand)
iSafe = edge.iSafeSat; bSafe = edge.bSafe;
iHelp = edge.iHelpSat; bRel = edge.bRelease;
subset = [];
for iu = cand
    nOn = max(sum(st.userServiceSat == iHelp & st.userServiceBeam == bRel), 1);
    sOld = graphRecoverySharedLocal('satisfaction', iu, iHelp, bRel, scenario.fullBeamPower_W, nOn, ...
        scenario.satGeom, scenario.P_users_km, scenario.params, scenario.userDemand_bps(iu));
    nSafe = max(sum(st.userServiceSat == iSafe & st.userServiceBeam == bSafe), 1) + numel(subset);
    sNew = graphRecoverySharedLocal('satisfaction', iu, iSafe, bSafe, scenario.fullBeamPower_W, nSafe, ...
        scenario.satGeom, scenario.P_users_km, scenario.params, scenario.userDemand_bps(iu));
    if sNew <= 0 || sNew + 1e-9 < sOld, continue; end
    subset(end+1) = iu; %#ok<AGROW>
end
end

function [ok, st, nMoved] = diagApplySbrLocal(st, scenario, edge)
subset = diagSbrSubsetLocal(st, scenario, edge, diagSbrCandLocal(st, scenario, edge));
nMoved = 0;
if isempty(subset), ok = false; return; end
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
ok = nMoved > 0;
end

function st = allocateDiagRecoveryPowerLocal(st, scenario)
globalPool = sum(st.releasedPower_W);
st.releasedPower_W(:) = 0;
if globalPool <= 0, return; end
recBeams = []; demand = []; iHelpList = [];
for iHelp = 1:scenario.nSat
    for e = 1:numel(scenario.hbrEdges)
        edge = scenario.hbrEdges(e);
        if edge.iHelpSat ~= iHelp, continue; end
        nc = 0;
        for iu = find(scenario.closedBeamUserMask)'
            if scenario.userHomeSat(iu) ~= edge.iClosedSat || scenario.userHomeBeam(iu) ~= edge.bClosed, continue; end
            uLat = asind(scenario.P_users_km(3, iu) / max(norm(scenario.P_users_km(:, iu)), eps));
            uLon = atan2d(scenario.P_users_km(2, iu), scenario.P_users_km(1, iu));
            if graphRecoverySharedLocal('userinfootprint', uLat, uLon, scenario.satGeom(iHelp), edge.bRecovery, ...
                    scenario.beamHalfEW_deg, scenario.beamHalfNS_deg, scenario.alt_km)
                nc = nc + 1;
            end
        end
        if nc == 0, continue; end
        iHelpList(end+1) = iHelp; %#ok<AGROW>
        recBeams(end+1) = edge.bRecovery; %#ok<AGROW>
        demand(end+1) = nc * scenario.userDemand_Mbps; %#ok<AGROW>
    end
end
if isempty(recBeams), return; end
[~, ord] = sort(demand, 'descend');
for k = 1:numel(ord)
    if globalPool <= 0, break; end
  alloc = min(globalPool, scenario.maxBeamPower_W);
    st.recoveryPower_W(iHelpList(ord(k)), recBeams(ord(k))) = ...
        st.recoveryPower_W(iHelpList(ord(k)), recBeams(ord(k))) + alloc;
    globalPool = globalPool - alloc;
end
end
