function scenario = buildDenseGraphScenarioLocal(opts)
% buildDenseGraphScenarioLocal
% Dense 5x10 geometry + EPFD shutdown + 100 users + SBR/HBR candidate edges.

if nargin < 1 || isempty(opts)
    opts = struct();
end
scenario = applyScenarioDefaultsLocal(opts);

snapOpts = struct();
snapOpts.alt_km = scenario.alt_km;
snapOpts.nOrbit = scenario.nOrbit;
snapOpts.nSatPerOrbit = scenario.nSatPerOrbit;
snapOpts.gsLat_deg = scenario.gsLat_deg;
snapOpts.orbitLon_deg = scenario.orbitLon_deg;
snapOpts.gsRelLon_deg = scenario.gsRelLon_deg;
snapOpts.gsPlacement = scenario.gsPlacement;
snapOpts.gsAnchorSatIdx = scenario.gsAnchorSatIdx;
snapOpts.beamHalfEW_deg = scenario.beamHalfEW_deg;
snapOpts.beamHalfNS_total_deg = scenario.beamHalfNS_total_deg;
snapOpts.fullBeamPower_W = scenario.fullBeamPower_W;
snapOpts.epfdThr_dB = scenario.epfdThr_dB;
snapOpts.showFigure = false;
snapOpts.figurePath = "";
snapOpts.params = scenario.params;

snap = RunDenseOverlapEpfdShutdownSnapshotLocal(snapOpts);
nSat = numel(snap.satNames);
Nbeam = 16;
beamHalfNS_deg = scenario.beamHalfNS_total_deg / Nbeam;

% Rebuild satGeom and shutOffMat from snapshot table.
satGeom = rebuildSatGeomFromSnapshotLocal(snap, scenario);
shutOffMat = false(nSat, Nbeam);
for iSat = 1:nSat
    mask = snap.Tbeam.sat == snap.satNames(iSat);
    Tb = snap.Tbeam(mask, :);
    for r = 1:height(Tb)
        shutOffMat(iSat, Tb.beam(r)) = Tb.shut_off(r) > 0;
    end
end
criticalSatMask = any(shutOffMat, 2);
criticalSatIdx = find(criticalSatMask);

% Users near GS.
rng(scenario.userSeed);
nUser = scenario.nUsers;
userLat = scenario.gsLat_deg + (rand(nUser, 1) - 0.5) * scenario.userSpreadLat_deg;
userLon = scenario.gsLon_deg + (rand(nUser, 1) - 0.5) * scenario.userSpreadLon_deg;
P_users_km = zeros(3, nUser);
for iu = 1:nUser
    P_users_km(:, iu) = graphRecoverySharedLocal('groundxyz', userLat(iu), userLon(iu), 0);
end

% Priority classes: 50% low, 30% medium, 20% high.
rng(scenario.prioritySeed);
perm = randperm(nUser);
nLow = round(0.5 * nUser);
nMed = round(0.3 * nUser);
priorityClass = strings(nUser, 1);
priorityWeight = ones(nUser, 1);
priorityClass(perm(1:nLow)) = "low";
priorityWeight(perm(1:nLow)) = 1;
priorityClass(perm(nLow + (1:nMed))) = "medium";
priorityWeight(perm(nLow + (1:nMed))) = 2;
priorityClass(perm(nLow + nMed + 1:end)) = "high";
priorityWeight(perm(nLow + nMed + 1:end)) = 3;

% Pre-shutdown home association (include shut beams) for closed-beam user definition.
[userHomeSat, userHomeBeam] = assignUsersToBeamsGraphLocal( ...
    satGeom, P_users_km, scenario.beamHalfEW_deg, beamHalfNS_deg, false(size(shutOffMat)));

userDemand_bps = scenario.userDemand_Mbps * 1e6 * ones(nUser, 1);
userServiceSat = userHomeSat;
userServiceBeam = userHomeBeam;
closedBeamUserMask = false(nUser, 1);
for iu = 1:nUser
  if userHomeSat(iu) >= 1 && userHomeBeam(iu) >= 1
    if shutOffMat(userHomeSat(iu), userHomeBeam(iu))
      closedBeamUserMask(iu) = true;
      userServiceSat(iu) = 0;
      userServiceBeam(iu) = 0;
    end
  end
end

sbrEdges = buildSbrEdgesGraphLocal(satGeom, shutOffMat, criticalSatIdx, ...
    scenario.beamHalfEW_deg, beamHalfNS_deg, scenario.alt_km);
hbrEdges = buildHbrEdgesGraphLocal(satGeom, shutOffMat, criticalSatIdx, ...
    scenario.beamHalfEW_deg, beamHalfNS_deg, scenario.alt_km);

scenario.satNames = snap.satNames;
scenario.satGeom = satGeom;
scenario.shutOffMat = shutOffMat;
scenario.criticalSatIdx = criticalSatIdx;
scenario.nSat = nSat;
scenario.nBeam = Nbeam;
scenario.beamHalfNS_deg = beamHalfNS_deg;
scenario.beamCapacity_Mbps = scenario.beamCapacity_Mbps;
scenario.beamHalfEW_deg = scenario.beamHalfEW_deg;
scenario.fullBeamPower_W = scenario.fullBeamPower_W;
scenario.maxBeamPower_W = scenario.maxBeamPower_W;
scenario.params = scenario.params;
scenario.alt_km = scenario.alt_km;
scenario.userDemand_Mbps = scenario.userDemand_Mbps;
scenario.gsLat_deg = scenario.gsLat_deg;
scenario.userLon = userLon;
scenario.userHomeSat = userHomeSat;
scenario.userHomeBeam = userHomeBeam;
scenario.userServiceSat = userServiceSat;
scenario.userServiceBeam = userServiceBeam;
scenario.closedBeamUserMask = closedBeamUserMask;
scenario.priorityClass = priorityClass;
scenario.priorityWeight = priorityWeight;
scenario.userDemand_bps = userDemand_bps;
scenario.sbrEdges = sbrEdges;
scenario.hbrEdges = hbrEdges;
scenario.Tbeam = snap.Tbeam;
scenario.gsLon_deg = snap.gsLon_deg;
scenario.nUsers = nUser;
scenario.userLat = userLat;
scenario.P_users_km = P_users_km;
scenario.userSeed = scenario.userSeed;
scenario.prioritySeed = scenario.prioritySeed;
end

function opts = applyScenarioDefaultsLocal(opts)
if ~isfield(opts, 'alt_km'), opts.alt_km = 1200; end
if ~isfield(opts, 'nOrbit'), opts.nOrbit = 5; end
if ~isfield(opts, 'nSatPerOrbit'), opts.nSatPerOrbit = 10; end
if ~isfield(opts, 'gsLat_deg'), opts.gsLat_deg = 0; end
if ~isfield(opts, 'orbitLon_deg'), opts.orbitLon_deg = 120.4; end
if ~isfield(opts, 'gsRelLon_deg'), opts.gsRelLon_deg = 0; end
if ~isfield(opts, 'gsPlacement'), opts.gsPlacement = 'under_sat'; end
if ~isfield(opts, 'gsAnchorSatIdx'), opts.gsAnchorSatIdx = 5; end
if ~isfield(opts, 'beamHalfEW_deg'), opts.beamHalfEW_deg = 24.5; end
if ~isfield(opts, 'beamHalfNS_total_deg'), opts.beamHalfNS_total_deg = 25.0; end
if ~isfield(opts, 'fullBeamPower_W'), opts.fullBeamPower_W = 1.05; end
if ~isfield(opts, 'maxBeamPower_W'), opts.maxBeamPower_W = 2.0; end
if ~isfield(opts, 'beamCapacity_Mbps'), opts.beamCapacity_Mbps = opts.fullBeamPower_W * 25; end
if ~isfield(opts, 'epfdThr_dB'), opts.epfdThr_dB = -173.4; end
if ~isfield(opts, 'nUsers'), opts.nUsers = 100; end
if ~isfield(opts, 'userDemand_Mbps'), opts.userDemand_Mbps = 25; end
if ~isfield(opts, 'userSeed'), opts.userSeed = 42; end
if ~isfield(opts, 'prioritySeed'), opts.prioritySeed = 42; end
if ~isfield(opts, 'userSpreadLat_deg'), opts.userSpreadLat_deg = 8; end
if ~isfield(opts, 'userSpreadLon_deg'), opts.userSpreadLon_deg = 8; end
if ~isfield(opts, 'params') || isempty(opts.params)
    opts.params = ku_epfd_params();
    opts.params.useEIRPDensityModel = false;
end
opts.params = ensureGraphLinkParamsLocal(opts.params);
opts.gsLon_deg = opts.orbitLon_deg + opts.gsRelLon_deg;
end

function P = ensureGraphLinkParamsLocal(P)
if ~isfield(P, 'kB') || ~isfinite(P.kB), P.kB = 1.380649e-23; end
if ~isfield(P, 'user_noise_temp_K') || ~isfinite(P.user_noise_temp_K), P.user_noise_temp_K = 240; end
if ~isfield(P, 'lambda_m') && isfield(P, 'lambda'), P.lambda_m = P.lambda; end
if ~isfield(P, 'A_fit') || ~isfinite(P.A_fit)
    if isfield(P, 'LEO_Gmax_dBi')
        P.A_fit = 10^(P.LEO_Gmax_dBi / 10);
    else
        P.A_fit = 1;
    end
end
if ~isfield(P, 'beta_fit') || ~isfinite(P.beta_fit), P.beta_fit = -0.0671; end
if ~isfield(P, 'GS_LEO_Gmax_dBi') || ~isfinite(P.GS_LEO_Gmax_dBi)
    if isfield(P, 'user_D_m') && isfield(P, 'lambda_m')
        P.GS_LEO_Gmax_dBi = 20 * log10(P.user_D_m / P.lambda_m) + 7.7;
    else
        P.GS_LEO_Gmax_dBi = 40;
    end
end
if ~isfield(P, 'B_Hz') || ~isfinite(P.B_Hz), P.B_Hz = 250e6; end
end

function satGeom = rebuildSatGeomFromSnapshotLocal(snap, scenario)
% Build boresights from snapshot sub-satellite points (no second EPFD run).
nSat = numel(snap.satNames);
beamHalfNS_deg = scenario.beamHalfNS_total_deg / 16;
pitchOffsets_deg = (8.5 - (1:16)) * (2 * beamHalfNS_deg);
satGeom = repmat(struct('satName', "", 'P_leo_km', [], 'b_all', [], 'c_axis', [], ...
    'subLat', [], 'subLon', []), nSat, 1);
Re_km = 6378.137;
alt_km = scenario.alt_km;
for iSat = 1:nSat
    lat = snap.satLat_deg(iSat);
    lon = snap.satLon_deg(iSat);
    r_km = Re_km + alt_km;
    P_leo_km = r_km * [cosd(lat) * cosd(lon); cosd(lat) * sind(lon); sind(lat)];
    V_leo_kmps = [-sind(lat) * cosd(lon); -sind(lat) * sind(lon); cosd(lat)];
    [b_all, c_axis] = beamBoresightsGraphLocal(P_leo_km * 1000, V_leo_kmps * 1000, pitchOffsets_deg);
    satGeom(iSat).satName = snap.satNames(iSat);
    satGeom(iSat).P_leo_km = P_leo_km;
    satGeom(iSat).b_all = reorderBoresightsGraphLocal(P_leo_km * 1000, b_all);
    satGeom(iSat).c_axis = c_axis;
    satGeom(iSat).subLat = lat;
    satGeom(iSat).subLon = lon;
end
end

function [userSat, userBeam] = assignUsersToBeamsGraphLocal(satGeom, P_users_km, beamHalfEW_deg, beamHalfNS_deg, shutOffMat)
nUser = size(P_users_km, 2);
nSat = numel(satGeom);
userSat = zeros(nUser, 1);
userBeam = zeros(nUser, 1);
for iu = 1:nUser
    bestMetric = inf;
    bestSat = 0;
    bestBeam = 0;
    uLat = asind(P_users_km(3, iu) / max(norm(P_users_km(:, iu)), eps));
    uLon = atan2d(P_users_km(2, iu), P_users_km(1, iu));
    for iSat = 1:nSat
        dist = hypot(uLat - satGeom(iSat).subLat, uLon - satGeom(iSat).subLon);
        for b = 1:size(satGeom(iSat).b_all, 2)
            if shutOffMat(iSat, b)
                continue;
            end
            if ~graphRecoverySharedLocal('usercovered', satGeom(iSat), b, P_users_km(:, iu), ...
                    beamHalfEW_deg, beamHalfNS_deg)
                continue;
            end
            if dist < bestMetric
                bestMetric = dist;
                bestSat = iSat;
                bestBeam = b;
            end
        end
    end
    userSat(iu) = bestSat;
    userBeam(iu) = bestBeam;
end
end

function edges = buildSbrEdgesGraphLocal(satGeom, shutOffMat, criticalSatIdx, beamHalfEW_deg, beamHalfNS_deg, alt_km)
edges = struct('iSafeSat', {}, 'bSafe', {}, 'iHelpSat', {}, 'bRelease', {}, 'edgeId', {});
eid = 0;
nSat = numel(satGeom);
for ic = 1:numel(criticalSatIdx)
    iCrit = criticalSatIdx(ic);
    safeBeams = find(~shutOffMat(iCrit, :));
    for bSafe = safeBeams
        for iHelp = 1:nSat
            if iHelp == iCrit
                continue;
            end
            for bRel = 1:size(satGeom(iHelp).b_all, 2)
                if shutOffMat(iHelp, bRel)
                    continue;
                end
                if ~graphRecoverySharedLocal('beamsoverlap', satGeom(iCrit), bSafe, satGeom(iHelp), bRel, ...
                        beamHalfEW_deg, beamHalfNS_deg, alt_km)
                    continue;
                end
                eid = eid + 1;
                edges(eid).iSafeSat = iCrit;
                edges(eid).bSafe = bSafe;
                edges(eid).iHelpSat = iHelp;
                edges(eid).bRelease = bRel;
                edges(eid).edgeId = eid;
            end
        end
    end
end
end

function edges = buildHbrEdgesGraphLocal(satGeom, shutOffMat, criticalSatIdx, beamHalfEW_deg, beamHalfNS_deg, alt_km)
edges = struct('iClosedSat', {}, 'bClosed', {}, 'iHelpSat', {}, 'bRecovery', {}, 'edgeId', {});
eid = 0;
nSat = numel(satGeom);
for ic = 1:numel(criticalSatIdx)
    iCrit = criticalSatIdx(ic);
    closedBeams = find(shutOffMat(iCrit, :));
    for bClosed = closedBeams
        for iHelp = 1:nSat
            if iHelp == iCrit
                continue;
            end
            for bRec = 1:size(satGeom(iHelp).b_all, 2)
                if shutOffMat(iHelp, bRec)
                    continue;
                end
                if ~graphRecoverySharedLocal('beamsoverlap', satGeom(iCrit), bClosed, satGeom(iHelp), bRec, ...
                        beamHalfEW_deg, beamHalfNS_deg, alt_km)
                    continue;
                end
                eid = eid + 1;
                edges(eid).iClosedSat = iCrit;
                edges(eid).bClosed = bClosed;
                edges(eid).iHelpSat = iHelp;
                edges(eid).bRecovery = bRec;
                edges(eid).edgeId = eid;
            end
        end
    end
end
end

function [b_all, c_axis] = beamBoresightsGraphLocal(r_sat_m, v_sat_mps, pitchOffsets_deg)
n_hat = r_sat_m / max(norm(r_sat_m), eps);
v_perp = v_sat_mps - dot(v_sat_mps, n_hat) * n_hat;
t_hat = v_perp / max(norm(v_perp), eps);
c_axis = cross(n_hat, t_hat);
c_axis = c_axis / max(norm(c_axis), eps);
b0 = -n_hat;
b_all = zeros(3, numel(pitchOffsets_deg));
for k = 1:numel(pitchOffsets_deg)
    b_all(:, k) = rodriguesGraphLocal(b0, c_axis, deg2rad(pitchOffsets_deg(k)));
end
end

function b_sorted = reorderBoresightsGraphLocal(r_sat_m, b_all)
Re_m = 6378137.0;
nb = size(b_all, 2);
lat_deg = -inf(1, nb);
for k = 1:nb
    hit = rayEarthIntersectGraphLocal(r_sat_m, b_all(:, k), Re_m);
    if ~isempty(hit)
        lat_deg(k) = asind(hit(3) / max(norm(hit), eps));
    end
end
[~, idx] = sort(lat_deg, 'descend');
b_sorted = b_all(:, idx);
end

function hit = rayEarthIntersectGraphLocal(r_s_m, d_unit, Re_m)
a = 1.0; b = 2.0 * dot(r_s_m, d_unit); c = dot(r_s_m, r_s_m) - Re_m^2;
disc = b^2 - 4 * a * c;
if disc < 0, hit = []; return; end
s = sqrt(disc);
cand = [(-b - s) / 2, (-b + s) / 2];
cand = cand(cand > 0);
if isempty(cand), hit = []; return; end
hit = r_s_m + min(cand) * d_unit;
end

function v = rodriguesGraphLocal(u, k, ang)
v = u * cos(ang) + cross(k, u) * sin(ang) + k * dot(k, u) * (1 - cos(ang));
v = v / max(norm(v), eps);
end
