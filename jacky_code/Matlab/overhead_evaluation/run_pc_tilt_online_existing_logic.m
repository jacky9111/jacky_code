function decision = run_pc_tilt_online_existing_logic(input)
%RUN_PC_TILT_ONLINE_EXISTING_LOGIC Isolated extraction of the PC+Tilt core.
% The control flow and equations mirror RunKu16BeamBaselineObservationLogExcel:
% load-aware initial power, beam-level EPFD power control, then the signed
% tilt grid on the configured critical satellite.

P = input.P;
nSat = size(input.satPos_km, 2);
nBeam = size(input.initialPower_W, 2);
if ~isfield(P, 'Nchannel') || ~isfinite(P.Nchannel)
    P.Nchannel = 8;
end
nChannel = P.Nchannel;
kappa = zeros(nSat, nBeam);
for iSat = 1:nSat
    if input.satVisible(iSat)
        kappa(iSat, :) = computeKappaLocal(input.satPos_km(:, iSat), ...
            input.beamBores{iSat}, input.P_gs_km, input.P_geo_km, P);
    end
end

[power_W, adjustedMask] = powerControlLocal(input.initialPower_W, kappa, input, nChannel);
state = evaluateStateLocal(power_W, kappa, input);
best = struct('objective',sum(state.userSatisfaction), 'state',state, ...
    'power_W',power_W, 'tilt_deg',0, 'kappa',kappa, ...
    'beamBores',{input.beamBores}, 'beamCAxis',{input.beamCAxis}, ...
    'adjustedMask',adjustedMask);

tiltSatIdx = input.criticalSatelliteIndex;
searchMode = "exhaustive";
if isfield(input, 'tiltSearchMode') && strlength(string(input.tiltSearchMode)) > 0
    searchMode = lower(string(input.tiltSearchMode));
end
if input.satVisible(tiltSatIdx) && any(input.userServiceSat == tiltSatIdx)
    offsets = input.basePitchOffsets_deg;
    switch searchMode
        case "max_only"
            % Overhead-oriented reproduction: if PC already had to cut power
            % (EPFD pressure), only try signed maximum tilt (±tiltMax).
            % No dense angle grid. Baseline tilt=0 is already in "best".
            tiltNeeded = any(adjustedMask(:));
            if tiltNeeded
                tiltGrid = unique([-input.tiltMax_deg, input.tiltMax_deg]);
                best = evaluateTiltCandidatesLocal(best, tiltGrid, tiltSatIdx, offsets, ...
                    input, kappa, P, nChannel);
            end
        case "coarse_to_fine"
            coarseStep = input.tiltStep_deg;
            if isfield(input, 'tiltCoarseStep_deg') && isfinite(input.tiltCoarseStep_deg)
                coarseStep = input.tiltCoarseStep_deg;
            end
            tiltGrid = buildUniformTiltGridLocal(input.tiltMax_deg, coarseStep);
            best = evaluateTiltCandidatesLocal(best, tiltGrid, tiltSatIdx, offsets, ...
                input, kappa, P, nChannel);
            fineStep = 0.5;
            fineHalf = 2.0;
            if isfield(input, 'tiltFineStep_deg') && isfinite(input.tiltFineStep_deg)
                fineStep = input.tiltFineStep_deg;
            end
            if isfield(input, 'tiltFineHalfWidth_deg') && isfinite(input.tiltFineHalfWidth_deg)
                fineHalf = input.tiltFineHalfWidth_deg;
            end
            fineGrid = buildLocalTiltGridLocal(best.tilt_deg, input.tiltMax_deg, fineHalf, fineStep);
            best = evaluateTiltCandidatesLocal(best, fineGrid, tiltSatIdx, offsets, ...
                input, kappa, P, nChannel);
        otherwise  % exhaustive
            tiltGrid = buildUniformTiltGridLocal(input.tiltMax_deg, input.tiltStep_deg);
            best = evaluateTiltCandidatesLocal(best, tiltGrid, tiltSatIdx, offsets, ...
                input, kappa, P, nChannel);
    end
end

decision = struct();
decision.power_W = best.power_W;
decision.tilt_deg = best.tilt_deg;
decision.userSatisfaction = best.state.userSatisfaction;
decision.epfd_dB = best.state.epfd_dB;
decision.powerAdjustedMask = best.adjustedMask;
decision.userServiceSat = input.userServiceSat;
decision.userServiceBeam = input.userServiceBeam;
end

function best = evaluateTiltCandidatesLocal(best, tiltGrid, tiltSatIdx, offsets, ...
    input, kappa, P, nChannel)
for theta_deg = tiltGrid
    [bTrial, cTrial] = beamBoresightsLocal( ...
        input.satPos_km(:, tiltSatIdx) * 1000, ...
        input.satVel_kmps(:, tiltSatIdx) * 1000, offsets + theta_deg);
    bores = input.beamBores;
    cAxes = input.beamCAxis;
    bores{tiltSatIdx} = reorderNorthToSouthLocal( ...
        input.satPos_km(:, tiltSatIdx) * 1000, bTrial);
    cAxes{tiltSatIdx} = cTrial;
    trialInput = input;
    trialInput.beamBores = bores;
    trialInput.beamCAxis = cAxes;
    kappaTrial = kappa;
    kappaTrial(tiltSatIdx, :) = computeKappaLocal( ...
        input.satPos_km(:, tiltSatIdx), bores{tiltSatIdx}, ...
        input.P_gs_km, input.P_geo_km, P);
    [powerTrial, adjustedTrial] = powerControlLocal( ...
        input.initialPower_W, kappaTrial, trialInput, nChannel);
    stateTrial = evaluateStateLocal(powerTrial, kappaTrial, trialInput);
    objective = sum(stateTrial.userSatisfaction);
    legal = stateTrial.epfd_lin <= 10^(P.EPFD_thr_dB/10) + 1e-18;
    if legal && objective > best.objective + 1e-12
        best = struct('objective',objective, 'state',stateTrial, ...
            'power_W',powerTrial, 'tilt_deg',theta_deg, 'kappa',kappaTrial, ...
            'beamBores',{bores}, 'beamCAxis',{cAxes}, ...
            'adjustedMask',adjustedTrial);
    end
end
end

function grid = buildUniformTiltGridLocal(tiltMax_deg, step_deg)
grid = unique([-tiltMax_deg:step_deg:tiltMax_deg, 0]);
grid = grid(isfinite(grid));
end

function grid = buildLocalTiltGridLocal(center_deg, tiltMax_deg, halfWidth_deg, step_deg)
lo = max(-tiltMax_deg, center_deg - halfWidth_deg);
hi = min(tiltMax_deg, center_deg + halfWidth_deg);
grid = unique([lo:step_deg:hi, center_deg, 0]);
grid = grid(isfinite(grid));
end

function [powerOut, adjustedMask] = powerControlLocal(powerIn, kappa, input, nChannel)
powerOut = powerIn;
[~, numUsers] = buildLoadsLocal(input.userServiceSat, input.userServiceBeam, ...
    input.userDemand_bps, size(powerIn,1), size(powerIn,2));
adjustedMask = false(size(powerIn));
threshold = 10^(input.P.EPFD_thr_dB / 10);
for iter = 1:(nnz(powerIn > 0) + 5)
    eta = powerOut .* kappa;
    aggregate = sum(eta, 'all');
    if aggregate <= threshold + 1e-18, break; end
    [etaSorted, order] = sort(eta(:), 'descend');
    found = false;
    for k = 1:numel(order)
        if ~isfinite(etaSorted(k)) || etaSorted(k) <= 0, break; end
        [iSat, iBeam] = ind2sub(size(powerOut), order(k));
        current = powerOut(iSat, iBeam);
        if current <= 0, continue; end
        floorPower = beamFloorPowerLocal(iSat, iBeam, current, powerOut, ...
            input, numUsers, nChannel);
        if floorPower < current - 1e-12
            found = true;
            break;
        end
    end
    if ~found, break; end
    other = aggregate - current * kappa(iSat, iBeam);
    if other + floorPower * kappa(iSat, iBeam) > threshold + 1e-18
        powerOut(iSat, iBeam) = floorPower;
    else
        target = (threshold - other) / max(kappa(iSat, iBeam), eps);
        powerOut(iSat, iBeam) = max(floorPower, min(target, current));
    end
    adjustedMask(iSat, iBeam) = true;
end
end

function floorPower = beamFloorPowerLocal(iSat, iBeam, current, powerMatrix, ...
    input, numUsers, nChannel)
beamUsers = find(input.userServiceSat == iSat & input.userServiceBeam == iBeam);
if isempty(beamUsers)
    floorPower = current;
    return;
end
if input.satisfactionFloor <= 0
    floorPower = 0;
    return;
end
satNow = beamAverageLocal(iSat, iBeam, current, input, numUsers, nChannel);
if satNow <= input.satisfactionFloor + 1e-12
    floorPower = current;
    return;
end
lo = 0;
hi = current;
for iter = 1:24
    mid = 0.5 * (lo + hi);
    satMid = beamAverageLocal(iSat, iBeam, mid, input, numUsers, nChannel);
    if satMid >= input.satisfactionFloor
        hi = mid;
    else
        lo = mid;
    end
end
floorPower = hi;
end

function average = beamAverageLocal(iSat, iBeam, trialPower, input, numUsers, ~)
users = find(input.userServiceSat == iSat & input.userServiceBeam == iBeam);
if isempty(users)
    average = 0;
    return;
end
P = input.P;
noiseDensity = P.kB * P.user_noise_temp_K;
usersOnBeam = max(numUsers(iSat, iBeam), 1);
satisfaction = zeros(numel(users), 1);
for k = 1:numel(users)
    iu = users(k);
    if input.useUserAntennaPattern
        receiveGain = 10^(gso_rx_gain_itu1428(0, P.user_D_m, P.lambda_m) / 10);
    else
        receiveGain = 10^(P.GS_LEO_Gmax_dBi / 10);
    end
    signal = rxPowerLocal(trialPower, input.satPos_km(:, iSat), ...
        input.userPosition_km(:, iu), input.beamBores{iSat}(:, iBeam), ...
        input.beamCAxis{iSat}, P, receiveGain);
    capacity = P.B_Hz * log2(1 + signal / max(noiseDensity * P.B_Hz, eps));
    satisfaction(k) = min(capacity / usersOnBeam / input.userDemand_bps(iu), 1);
end
average = mean(satisfaction);
end

function state = evaluateStateLocal(power_W, kappa, input)
[~, numUsers] = buildLoadsLocal(input.userServiceSat, input.userServiceBeam, ...
    input.userDemand_bps, size(power_W,1), size(power_W,2));
P = input.P;
satisfaction = zeros(numel(input.userServiceSat), 1);
for iu = 1:numel(satisfaction)
    iSat = input.userServiceSat(iu);
    iBeam = input.userServiceBeam(iu);
    if iSat < 1 || iBeam < 1, continue; end
    if input.useUserAntennaPattern
        receiveGain = 10^(gso_rx_gain_itu1428(0, P.user_D_m, P.lambda_m) / 10);
    else
        receiveGain = 10^(P.GS_LEO_Gmax_dBi / 10);
    end
    signal = rxPowerLocal(power_W(iSat,iBeam), input.satPos_km(:,iSat), ...
        input.userPosition_km(:,iu), input.beamBores{iSat}(:,iBeam), ...
        input.beamCAxis{iSat}, P, receiveGain);
    sinr = signal / max(P.kB * P.user_noise_temp_K * P.B_Hz, eps);
    rate = P.B_Hz * log2(1 + sinr) / max(numUsers(iSat,iBeam), 1);
    satisfaction(iu) = min(rate / input.userDemand_bps(iu), 1);
end
epfd = sum(power_W .* kappa, 'all');
state = struct('userSatisfaction',satisfaction, 'epfd_lin',epfd, ...
    'epfd_dB',10*log10(max(epfd, 1e-300)));
end

function [load, count] = buildLoadsLocal(userSat, userBeam, demand, nSat, nBeam)
load = zeros(nSat, nBeam);
count = zeros(nSat, nBeam);
for iu = 1:numel(userSat)
    if userSat(iu) < 1 || userBeam(iu) < 1, continue; end
    load(userSat(iu),userBeam(iu)) = load(userSat(iu),userBeam(iu)) + demand(iu);
    count(userSat(iu),userBeam(iu)) = count(userSat(iu),userBeam(iu)) + 1;
end
end

function row = computeKappaLocal(satPos, beamBores, Pgs, Pgso, P)
row = zeros(1, size(beamBores,2));
d_m = norm(Pgs - satPos) * 1000;
if d_m < 1, return; end
alpha = angleDegLocal(satPos-Pgs, Pgso-Pgs);
receiveGain = 10^(gso_rx_gain_itu1428(alpha, P.GSO_D_m, P.lambda_m) / 10);
receiveGain = receiveGain / max(10^(P.GSO_Gmax_dBi/10), eps);
toGs = (Pgs - satPos) / max(norm(Pgs - satPos), eps);
for iBeam = 1:size(beamBores,2)
    phi = angleDegLocal(beamBores(:,iBeam), toGs);
    transmitGain = max(P.A_fit * exp(P.beta_fit * phi), 1e-30);
    row(iBeam) = transmitGain * receiveGain / (P.BWref_Hz * 4*pi*d_m^2);
end
end

function power = rxPowerLocal(Ptx, satPos, userPos, beamBore, cAxis, P, receiveGain)
if Ptx <= 0, power = 0; return; end
direction = userPos - satPos;
d_m = norm(direction) * 1000;
direction = direction / max(norm(direction), eps);
tAxis = cross(cAxis, beamBore);
tAxis = tAxis / max(norm(tAxis), eps);
horizontal = atan2d(dot(direction,cAxis), dot(direction,beamBore));
vertical = atan2d(dot(direction,tAxis), dot(direction,beamBore));
gain = max(P.A_fit * exp(P.beta_fit * hypot(horizontal,vertical)), 1e-30);
power = Ptx * gain * receiveGain * P.lambda_m^2 / max((4*pi*d_m)^2, eps);
end

function [bores, cAxis] = beamBoresightsLocal(position_m, velocity_mps, offsets_deg)
nadir = -position_m(:) / max(norm(position_m), eps);
along = velocity_mps(:) - dot(velocity_mps(:),nadir)*nadir;
along = along / max(norm(along), eps);
cAxis = cross(along,nadir);
cAxis = cAxis / max(norm(cAxis), eps);
bores = zeros(3,numel(offsets_deg));
for k = 1:numel(offsets_deg)
    bores(:,k) = rodriguesLocal(nadir,cAxis,offsets_deg(k));
end
end

function sorted = reorderNorthToSouthLocal(~, bores)
[~, order] = sort(bores(3,:), 'descend');
sorted = bores(:,order);
end

function value = rodriguesLocal(vector, axis, angle_deg)
angle = deg2rad(angle_deg);
value = vector*cos(angle) + cross(axis,vector)*sin(angle) + ...
    axis*dot(axis,vector)*(1-cos(angle));
value = value / max(norm(value), eps);
end

function angle = angleDegLocal(a,b)
angle = acosd(max(-1,min(1,dot(a,b)/max(norm(a)*norm(b),eps))));
end
