function [Tuser, Tbeam, Tsat, Tglobal] = RunKu16BeamBaselineObservationLogExcel(root, opts)
% RunKu16BeamBaselineObservationLogExcel
% Ku 16-beam baseline: load-aware power split, beam-level EPFD aggregate at GSO GS.
%
% Spectrum (user link): 8 fixed channels × 250 MHz; beams b=1..16 map to
% channel mod(b-1,8)+1 (beams 1 and 9 share channel 1, etc.). SINR/capacity
% use co-channel interference only; EPFD is still summed over all active beams
% (not filtered by channel). Optional legacy: opts.useFullFrequencyReuse=true
% restores interference from all active beams.
%
% No ISL offloading / seamless constraints / donor selection / beam shutoff.
%
% opts.excelSatelliteIds (optional): cellstr/string list of names that must exist in
% opts.leoList. If non-empty, PerUser / PerBeam / PerSatellite rows are written only
% for these satellites; physics (EPFD, SINR, power control) still uses full leoList.
% Global sheet is unchanged (full-system aggregate per timestep).

if nargin < 2 || isempty(opts), opts = struct(); end
if ~isfield(opts,'leoList') || isempty(opts.leoList), error('opts.leoList required'); end
if ~isfield(opts,'geoList') || isempty(opts.geoList), error('opts.geoList required'); end

sc = root.CurrentScenario;
if isempty(sc), error('No current STK scenario'); end

here = fileparts(mfilename('fullpath'));
addpath(fullfile(here, '..', 'powertilt'));

leoList = cellstr(string(opts.leoList));
geoList = cellstr(string(opts.geoList));
Nleo = numel(leoList);
Ngeo = numel(geoList);
Nbeam = 16;

if ~isfield(opts,'stepSec') || ~isfinite(opts.stepSec), opts.stepSec = 1; end
step = double(opts.stepSec) / 86400;
if ~isfield(opts,'tStartStr') || isempty(opts.tStartStr), opts.tStartStr = sc.StartTime; end
if ~isfield(opts,'tEndStr') || isempty(opts.tEndStr), opts.tEndStr = sc.StopTime; end
tStart = datenum(char(opts.tStartStr));
tEnd = datenum(char(opts.tEndStr));

if ~isfield(opts,'beamHalfEW_deg') || ~isfinite(opts.beamHalfEW_deg), opts.beamHalfEW_deg = 24.5; end
if ~isfield(opts,'beamHalfNS_deg') || ~isfinite(opts.beamHalfNS_deg), opts.beamHalfNS_deg = 25/16; end
beamHalfEW_deg = double(opts.beamHalfEW_deg);
beamHalfNS_deg = double(opts.beamHalfNS_deg);
basePitchOffsets_deg = (8.5 - (1:Nbeam)) * (2*beamHalfNS_deg);

if ~isfield(opts,'usersPerSat') || ~isfinite(opts.usersPerSat), opts.usersPerSat = 5; end
UperSat = max(1, round(double(opts.usersPerSat)));
if ~isfield(opts,'enablePowerControl') || isempty(opts.enablePowerControl), opts.enablePowerControl = true; end
enablePowerControl = logical(opts.enablePowerControl);
if ~isfield(opts,'useUserAntennaPattern') || isempty(opts.useUserAntennaPattern), opts.useUserAntennaPattern = true; end
useUserAntennaPattern = logical(opts.useUserAntennaPattern);
if ~isfield(opts,'useGsoNoiseInQualityMetric') || isempty(opts.useGsoNoiseInQualityMetric), opts.useGsoNoiseInQualityMetric = true; end
useGsoNoiseInQualityMetric = logical(opts.useGsoNoiseInQualityMetric);
if ~isfield(opts,'userInBeamCenterOnly') || isempty(opts.userInBeamCenterOnly)
    opts.userInBeamCenterOnly = true; % place all users at exact beam center (th_h=0, th_v=0)
end
userInBeamCenterOnly = logical(opts.userInBeamCenterOnly);

if ~isfield(opts,'pcBeamSatisfactionFloor') || ~isfinite(opts.pcBeamSatisfactionFloor)
    opts.pcBeamSatisfactionFloor = 0.2; % do not reduce a beam below the power that keeps its served users at this satisfaction floor
end
pcBeamSatisfactionFloor = max(0, min(1, double(opts.pcBeamSatisfactionFloor)));
if ~isfield(opts,'enablePowerRedistribution') || isempty(opts.enablePowerRedistribution)
    opts.enablePowerRedistribution = false;
end
enablePowerRedistribution = logical(opts.enablePowerRedistribution);
if ~isfield(opts,'redistributionStep_W') || ~isfinite(opts.redistributionStep_W)
    opts.redistributionStep_W = 0.1; % greedy incremental donor-power reallocation step
end
redistributionStep_W = max(1e-6, double(opts.redistributionStep_W));
if ~isfield(opts,'enableBidirectionalRelay') || isempty(opts.enableBidirectionalRelay)
    opts.enableBidirectionalRelay = false;
end
enableBidirectionalRelay = logical(opts.enableBidirectionalRelay);
if ~isfield(opts,'enableBaselineTilt') || isempty(opts.enableBaselineTilt)
    opts.enableBaselineTilt = false;
end
enableBaselineTilt = logical(opts.enableBaselineTilt);
if ~isfield(opts,'baselineTiltSatelliteId') || isempty(opts.baselineTiltSatelliteId)
    opts.baselineTiltSatelliteId = "";
end
baselineTiltSatelliteId = string(opts.baselineTiltSatelliteId);
if ~isfield(opts,'baselineTiltMaxDeg') || ~isfinite(opts.baselineTiltMaxDeg)
    opts.baselineTiltMaxDeg = 10;
end
baselineTiltMaxDeg = max(0, double(opts.baselineTiltMaxDeg));
if ~isfield(opts,'baselineTiltStepDeg') || ~isfinite(opts.baselineTiltStepDeg)
    opts.baselineTiltStepDeg = 0.5;
end
baselineTiltStepDeg = max(0.05, double(opts.baselineTiltStepDeg));
if ~isfield(opts,'relaySourceSatelliteId') || isempty(opts.relaySourceSatelliteId)
    opts.relaySourceSatelliteId = "";
end
relaySourceSatelliteId = string(opts.relaySourceSatelliteId);
if ~isfield(opts,'relayDistressedSatisfactionFloor') || ~isfinite(opts.relayDistressedSatisfactionFloor)
    opts.relayDistressedSatisfactionFloor = 0.4;
end
relayDistressedSatisfactionFloor = max(0, min(1, double(opts.relayDistressedSatisfactionFloor)));
if ~isfield(opts,'satTotalDemandGbps') || ~isfinite(opts.satTotalDemandGbps)
    opts.satTotalDemandGbps = 0.5; % default: 5 users × 0.1 Gbps (spec baseline)
end
satTotalDemandGbps = double(opts.satTotalDemandGbps);
if ~isfield(opts,'useFullFrequencyReuse') || isempty(opts.useFullFrequencyReuse)
    opts.useFullFrequencyReuse = false; % false => 8-channel co-channel IC only
end
useFullFrequencyReuse = logical(opts.useFullFrequencyReuse);

if isfield(opts,'params') && ~isempty(opts.params)
    P = opts.params;
else
    P = ku_epfd_params();
end
if ~isfield(P,'Nbeam'), P.Nbeam = 16; end
if P.Nbeam ~= 16, error('This model assumes 16 beams per satellite'); end
if ~isfield(P,'min_elev_deg') || ~isfinite(P.min_elev_deg), P.min_elev_deg = 10; end
if ~isfield(P,'BWref_Hz') || ~isfinite(P.BWref_Hz), P.BWref_Hz = 1e6; end
if ~isfield(P,'EPFD_thr_dB') || ~isfinite(P.EPFD_thr_dB), P.EPFD_thr_dB = -173.4; end
if ~isfield(P,'Ptotal_W') || ~isfinite(P.Ptotal_W), P.Ptotal_W = 10; end
if ~isfield(P,'kB') || ~isfinite(P.kB), P.kB = 1.380649e-23; end
if ~isfield(P,'user_noise_temp_K') || ~isfinite(P.user_noise_temp_K), P.user_noise_temp_K = 240; end
if ~isfield(P,'B_Hz') || ~isfinite(P.B_Hz), P.B_Hz = 250e6; end
if ~isfield(P,'lambda_m') || ~isfinite(P.lambda_m), P.lambda_m = 3e8/(P.freq_GHz*1e9); end
if ~isfield(P,'GSO_D_m') || ~isfinite(P.GSO_D_m), P.GSO_D_m = 0.7; end
if ~isfield(P,'GSO_Gmax_dBi') || ~isfinite(P.GSO_Gmax_dBi), P.GSO_Gmax_dBi = 40.95; end
if ~isfield(P,'GS_LEO_Gmax_dBi') || ~isfinite(P.GS_LEO_Gmax_dBi), P.GS_LEO_Gmax_dBi = 40.95; end
if ~isfield(P,'user_D_m') || ~isfinite(P.user_D_m), P.user_D_m = 0.7; end
if ~isfield(P,'GSO_noise_temp_K') || ~isfinite(P.GSO_noise_temp_K), P.GSO_noise_temp_K = 240; end
if ~isfield(P,'A_fit') || ~isfinite(P.A_fit), P.A_fit = 1.0632e4; end
if ~isfield(P,'beta_fit') || ~isfinite(P.beta_fit), P.beta_fit = -0.0671; end
if ~isfield(P,'Nchannel') || ~isfinite(P.Nchannel), P.Nchannel = 8; end
Nchannel = max(1, round(double(P.Nchannel)));

if ~isfield(opts,'excelSatelliteIds') || isempty(opts.excelSatelliteIds)
    excelExportIdx = 1:Nleo; % export all satellites to Excel
else
    exNames = cellstr(string(opts.excelSatelliteIds));
    excelExportIdx = find(ismember(leoList, exNames));
    miss = exNames(~ismember(exNames, leoList));
    if ~isempty(miss)
        warning('excelSatelliteIds not found in leoList: %s', strjoin(miss, ', '));
    end
    if isempty(excelExportIdx)
        warning('excelSatelliteIds matched nothing; exporting all satellites to Excel.');
        excelExportIdx = 1:Nleo;
    end
end

if ~isfield(opts,'excelPath') || isempty(opts.excelPath)
    opts.excelPath = fullfile(here, '..', '..', 'Matlab_data', 'LEO16_Ku_Baseline_Observation.xlsx');
end
excelPath = char(string(opts.excelPath));
outDir = fileparts(excelPath);
if ~isempty(outDir) && ~exist(outDir,'dir'), mkdir(outDir); end
if exist(excelPath,'file'), delete(excelPath); end

[leoPosDP, leoVelDP] = preloadLeo(root, leoList);
geoPosDP = preloadGeo(root, geoList);
gsObjMap = preloadGs(root, geoList);

TimeU = strings(0,1); user_id = strings(0,1); serving_satellite = strings(0,1); serving_beam = nan(0,1);
original_serving_satellite = strings(0,1); original_serving_beam = nan(0,1); relay_changed_flag = nan(0,1);
serving_channel = nan(0,1);
demand_Gbps = nan(0,1); SINR_lin = nan(0,1); instantaneous_capacity_Gbps = nan(0,1);
actual_rate_after_TDMA_Gbps = nan(0,1); satisfaction_after_pc_before_relay = nan(0,1); satisfaction = nan(0,1);

TimeB = strings(0,1); satellite_id_b = strings(0,1); beam_id_b = nan(0,1); channel_id_b = nan(0,1); active_b = nan(0,1);
assigned_power_W = nan(0,1); power_before_pc_W = nan(0,1); power_after_pc_W = nan(0,1); power_after_reallocation_W = nan(0,1);
pc_adjusted_flag = nan(0,1); redistribution_adjusted_flag = nan(0,1);
number_of_users = nan(0,1); beam_total_demand_Gbps = nan(0,1);
average_user_rate_Gbps = nan(0,1); average_user_satisfaction_after_pc_before_relay = nan(0,1); average_user_satisfaction = nan(0,1); beam_EPFD_contribution_lin = nan(0,1);
beam_rank_within_satellite = nan(0,1); beam_rank_global = nan(0,1);

TimeS = strings(0,1); satellite_id_s = strings(0,1); total_active_beams = nan(0,1); total_power_used_W = nan(0,1);
total_users = nan(0,1); satellite_total_demand_Gbps = nan(0,1); satellite_average_satisfaction = nan(0,1);
satellite_average_satisfaction_after_pc_before_relay = nan(0,1);
satellite_EPFD_contribution_lin = nan(0,1); is_critical_satellite = nan(0,1);

TimeG = strings(0,1); aggregate_EPFD_dB = nan(0,1); EPFD_threshold_dB = nan(0,1); EPFD_margin_dB = nan(0,1);
critical_satellite_id = strings(0,1); critical_beam_id = strings(0,1); GS_region_label = strings(0,1);
power_control_scale = nan(0,1);
power_control_adjusted_beam_count = nan(0,1); power_control_adjusted_beams = strings(0,1);
power_redistribution_step_count = nan(0,1); power_redistributed_beams = strings(0,1);
relay_source_satellite_id = strings(0,1); relay_accepted_move_count = nan(0,1); relay_changed_user_count = nan(0,1); relay_actions = strings(0,1);
baseline_tilt_satellite_id = strings(0,1); baseline_tilt_signed_deg = nan(0,1); baseline_tilt_applied_flag = nan(0,1);
sum_user_satisfaction_after_pc_before_relay = nan(0,1);
sum_user_satisfaction = nan(0,1);
gso_noise_power_dBW = nan(0,1); gso_IN_proxy_dB = nan(0,1);

rng(1);
for t = tStart:step:tEnd
    tStr = datestr(t, 'dd mmm yyyy HH:MM:SS');
    root.ExecuteCommand(['Animate * SetTime "' tStr '"']);

    P_geo_all = zeros(3, Ngeo);
    P_gs_all = zeros(3, Ngeo);
    for j = 1:Ngeo
        P_geo_all(:,j) = stkXYZ(geoPosDP(geoList{j}), tStr);
        P_gs_all(:,j) = gsXYZ(gsObjMap(geoList{j}));
    end
    jVictim = 1;
    P_gs = P_gs_all(:, jVictim);
    P_geo = P_geo_all(:, jVictim);

    satPos = zeros(3,Nleo); satVel = zeros(3,Nleo); satVisible = false(Nleo,1);
    satSubLat = nan(Nleo,1); beamBores = cell(Nleo,1); beamCAxis = cell(Nleo,1);
    for i = 1:Nleo
        satPos(:,i) = stkXYZ(leoPosDP(leoList{i}), tStr);
        satVel(:,i) = stkXYZ(leoVelDP(leoList{i}), tStr);
        satVisible(i) = gsElev(satPos(:,i), P_gs) >= P.min_elev_deg;
        satSubLat(i) = asind(satPos(3,i) / max(norm(satPos(:,i)), eps));
        [b_all, c_axis] = beamBoresights(satPos(:,i)*1000, satVel(:,i)*1000, basePitchOffsets_deg);
        beamBores{i} = reorderBoresightsNorthToSouth(satPos(:,i)*1000, b_all);
        beamCAxis{i} = c_axis;
    end

    % 1) Generate users per visible satellite; total demand = satTotalDemandGbps (default 0.5 Gbps).
    Urows = struct('uid',{},'satIdx',{},'pos',{},'demand',{},'servBeam',{});
    for i = 1:Nleo
        if ~satVisible(i), continue; end
        Dtot_Gbps = max(0, satTotalDemandGbps);
        Du_Gbps = Dtot_Gbps / UperSat;
        for u = 1:UperSat
            b0 = randi(Nbeam);
            [uPos_km, ok] = sampleUserInBeamFootprint( ...
                satPos(:,i), satVel(:,i), beamBores{i}, beamCAxis{i}, b0, ...
                beamHalfEW_deg, beamHalfNS_deg, userInBeamCenterOnly);
            if ~ok
                uPos_km = 6378.137 * (satPos(:,i) / max(norm(satPos(:,i)), eps));
            end
            rec.uid = sprintf('%s_U%02d', leoList{i}, u);
            rec.satIdx = i;
            rec.pos = uPos_km(:);
            rec.demand = Du_Gbps * 1e9;
            rec.servBeam = 0;
            Urows(end+1) = rec; %#ok<AGROW>
        end
    end

    Nusers = numel(Urows);
    if Nusers == 0
        % still output global row
        TimeG(end+1,1) = string(tStr);
        aggregate_EPFD_dB(end+1,1) = -inf;
        EPFD_threshold_dB(end+1,1) = P.EPFD_thr_dB;
        EPFD_margin_dB(end+1,1) = -inf;
        critical_satellite_id(end+1,1) = "";
        critical_beam_id(end+1,1) = "";
        GS_region_label(end+1,1) = "unknown";
        power_control_adjusted_beam_count(end+1,1) = 0;
        power_control_adjusted_beams(end+1,1) = "";
        power_redistribution_step_count(end+1,1) = 0;
        power_redistributed_beams(end+1,1) = "";
        relay_source_satellite_id(end+1,1) = "";
        relay_accepted_move_count(end+1,1) = 0;
        relay_changed_user_count(end+1,1) = 0;
        relay_actions(end+1,1) = "";
        baseline_tilt_satellite_id(end+1,1) = "";
        baseline_tilt_signed_deg(end+1,1) = 0;
        baseline_tilt_applied_flag(end+1,1) = 0;
        sum_user_satisfaction_after_pc_before_relay(end+1,1) = 0;
        sum_user_satisfaction(end+1,1) = 0;
        continue;
    end

    % 2) Assign each user to one covered beam of its own satellite.
    userServSat = zeros(Nusers,1);
    userServBeam = zeros(Nusers,1);
    userDemand = zeros(Nusers,1);
    for uu = 1:Nusers
        i = Urows(uu).satIdx;
        uPos = Urows(uu).pos;
        userDemand(uu) = Urows(uu).demand;
        [bAssign, covered] = assignUserToBeam(uPos, satPos(:,i), beamBores{i}, beamCAxis{i}, beamHalfEW_deg, beamHalfNS_deg);
        if covered
            userServSat(uu) = i;
            userServBeam(uu) = bAssign;
        end
    end

    % 3) Load-aware power split among active beams (per satellite total budget).
    load_ib = zeros(Nleo, Nbeam);
    num_ib = zeros(Nleo, Nbeam);
    for uu = 1:Nusers
        i = userServSat(uu); b = userServBeam(uu);
        if i < 1 || b < 1, continue; end
        load_ib(i,b) = load_ib(i,b) + userDemand(uu);
        num_ib(i,b) = num_ib(i,b) + 1;
    end
    P_ib = zeros(Nleo, Nbeam);
    a_ib = zeros(Nleo, Nbeam);
    for i = 1:Nleo
        Li = load_ib(i,:);
        active = Li > 0;
        a_ib(i,active) = 1;
        if any(active)
            P_ib(i,active) = P.Ptotal_W * Li(active) / max(sum(Li(active)), eps);
        end
    end

    % 4) Power control (critical-beam backoff with satisfaction floor).
    % Keep baseline load-aware split shape, then:
    % - pick the current largest EPFD-contribution beam
    % - first allow it to drop down to the power that keeps its served users
    %   at pcBeamSatisfactionFloor
    % - if that still cannot clear EPFD, lock it at that floor and move on
    % - otherwise use this "last" beam as the precise cleanup beam so
    %   aggregate EPFD becomes just legal for this time slot
    kappa_ib = zeros(Nleo, Nbeam); % EPFD coefficient per beam for 1 W
    for i = 1:Nleo
        if ~satVisible(i), continue; end
        d_gs_m = norm((P_gs - satPos(:,i))*1000);
        if d_gs_m < 1, continue; end
        alpha = angleDeg(satPos(:,i)-P_gs, P_geo-P_gs);
        Gr_dBi = gso_rx_gain_itu1428(alpha, P.GSO_D_m, P.lambda_m);
        Gr_lin = 10^(Gr_dBi/10);
        Gr_norm = Gr_lin / max(10^(P.GSO_Gmax_dBi/10), eps);
        d_hat_gs = (P_gs - satPos(:,i)); d_hat_gs = d_hat_gs / max(norm(d_hat_gs), eps);
        for b = 1:Nbeam
            phit = angleDeg(beamBores{i}(:,b), d_hat_gs);
            Gt_lin = max(P.A_fit * exp(P.beta_fit * phit), 1e-30);
            kappa_ib(i,b) = (1 / P.BWref_Hz) * (Gt_lin/(4*pi*d_gs_m^2)) * Gr_norm;
        end
    end

    P_ib_before_pc = P_ib;
    P_ib_loadsplit = P_ib;
    pcAdjustedMask = false(Nleo, Nbeam);
    pcScale = 1.0;
    pcAdjustedBeamOrder = strings(0,1);
    if enablePowerControl
        [P_ib, pcAdjustedMask, pcAdjustedBeamOrder] = runBeamLevelPowerControl( ...
            P_ib_before_pc, kappa_ib, satPos, Urows, beamBores, beamCAxis, P, ...
            useUserAntennaPattern, userServSat, userServBeam, userDemand, num_ib, ...
            Nleo, Nbeam, Nchannel, useFullFrequencyReuse, pcBeamSatisfactionFloor, leoList);
    end
    a_ib = double(P_ib > 0);
    if ~isempty(pcAdjustedBeamOrder)
        pcAdjustedBeamsStr = strjoin(pcAdjustedBeamOrder.', ',');
        pcAdjustedBeamCount = numel(pcAdjustedBeamOrder);
    else
        adjustedIdx = find(pcAdjustedMask);
        if isempty(adjustedIdx)
            pcAdjustedBeamsStr = "";
            pcAdjustedBeamCount = 0;
        else
            [adjSatIdx, adjBeamIdx] = ind2sub([Nleo, Nbeam], adjustedIdx);
            adjNames = strings(numel(adjustedIdx),1);
            for kk = 1:numel(adjustedIdx)
                adjNames(kk) = string(sprintf('%s_B%02d', leoList{adjSatIdx(kk)}, adjBeamIdx(kk)));
            end
            pcAdjustedBeamsStr = strjoin(adjNames.', ',');
            pcAdjustedBeamCount = numel(adjustedIdx);
        end
    end
    pcScale = sum(P_ib(:)) / max(sum(P_ib_before_pc(:)), eps);
    P_ib_after_pc = P_ib;
    redistributionAdjustedMask = false(Nleo, Nbeam);
    redistributionBeamOrder = strings(0,1);
    redistributionStepCount = 0;

    % 4b) Optional donor-power redistribution after PC.
    % Use any per-satellite power headroom left by PC and greedily assign it to
    % the low-satisfaction beam that yields the largest total-satisfaction gain
    % per additional watt, while keeping aggregate EPFD within the limit.
    if enablePowerRedistribution
        epfd_thr_lin = 10^(P.EPFD_thr_dB / 10);
        satHeadroom = max(P.Ptotal_W - sum(P_ib, 2), 0);

        maxRedisIter = max(50, round(sum(satHeadroom) / redistributionStep_W) + 10);
        for redIter = 1:maxRedisIter
            eta_red = P_ib .* kappa_ib;
            epfd_red_lin = sum(eta_red(:));
            epfd_margin_lin = epfd_thr_lin - epfd_red_lin;
            if epfd_margin_lin <= 1e-18
                break;
            end

            bestGainPerW = -inf;
            bestSat = 0; bestBeam = 0; bestDelta = 0;
            for i = 1:Nleo
                if satHeadroom(i) <= 1e-12, continue; end
                for b = 1:Nbeam
                    ub = find(userServSat == i & userServBeam == b);
                    if isempty(ub), continue; end

                    satNow = beamAverageSatisfactionGivenPower(i, b, P_ib(i,b), P_ib, satPos, Urows, beamBores, beamCAxis, P, ...
                        useUserAntennaPattern, userServSat, userServBeam, userDemand, num_ib, Nleo, Nbeam, Nchannel, useFullFrequencyReuse);
                    if satNow >= 1 - 1e-12
                        continue;
                    end

                    deltaEpfdMax = inf;
                    if kappa_ib(i,b) > 0
                        deltaEpfdMax = epfd_margin_lin / kappa_ib(i,b);
                    end
                    deltaP = min([redistributionStep_W, satHeadroom(i), deltaEpfdMax]);
                    if ~isfinite(deltaP) || deltaP <= 1e-12
                        continue;
                    end

                    satNext = beamAverageSatisfactionGivenPower(i, b, P_ib(i,b) + deltaP, P_ib, satPos, Urows, beamBores, beamCAxis, P, ...
                        useUserAntennaPattern, userServSat, userServBeam, userDemand, num_ib, Nleo, Nbeam, Nchannel, useFullFrequencyReuse);
                    totalGain = numel(ub) * max(satNext - satNow, 0);
                    gainPerW = totalGain / deltaP;
                    if gainPerW > bestGainPerW + 1e-18
                        bestGainPerW = gainPerW;
                        bestSat = i;
                        bestBeam = b;
                        bestDelta = deltaP;
                    end
                end
            end

            if bestSat < 1 || bestBeam < 1 || bestDelta <= 1e-12 || bestGainPerW <= 0
                break;
            end

            epfd_candidate_lin = epfd_red_lin + bestDelta * kappa_ib(bestSat, bestBeam);
            if epfd_candidate_lin <= epfd_thr_lin + 1e-18
                P_ib(bestSat, bestBeam) = P_ib(bestSat, bestBeam) + bestDelta;
                satHeadroom(bestSat) = max(satHeadroom(bestSat) - bestDelta, 0);
                redistributionAdjustedMask(bestSat, bestBeam) = true;
                redistributionStepCount = redistributionStepCount + 1;
                redistributionBeamOrder(end+1,1) = string(sprintf('%s_B%02d', leoList{bestSat}, bestBeam)); %#ok<AGROW>
            else
                break;
            end
        end
    end

    % 5) Evaluate the post-PC state, then optionally run bidirectional relay.
    userServSat_beforeRelay = userServSat;
    userServBeam_beforeRelay = userServBeam;
    relayAcceptedMoveCountNow = 0;
    relayActionsNow = strings(0,1);
    relaySourceSatNameNow = "";
    baselineTiltSatNameNow = "";
    baselineTiltSignedDegNow = 0;
    baselineTiltAppliedNow = false;

    stateNow = evaluateSystemState(P_ib, userServSat, userServBeam, satPos, Urows, beamBores, beamCAxis, P, ...
        useUserAntennaPattern, userDemand, Nleo, Nbeam, Nchannel, useFullFrequencyReuse, kappa_ib);
    stateBeforeRelay = stateNow;
    satPowerBudgetRelay = sum(P_ib, 2);

    if enableBaselineTilt && Nusers > 0
        tiltSatIdx = stateNow.idxCritSat;
        if strlength(baselineTiltSatelliteId) > 0
            tiltFixedIdx = find(strcmp(leoList, char(baselineTiltSatelliteId)), 1);
            if ~isempty(tiltFixedIdx)
                tiltSatIdx = tiltFixedIdx;
            else
                warning('baselineTiltSatelliteId not found in leoList: %s. Fallback to critical satellite.', char(baselineTiltSatelliteId));
            end
        end

        if satVisible(tiltSatIdx) && any(userServSat == tiltSatIdx)
            baselineTiltSatNameNow = string(leoList{tiltSatIdx});
            bestTiltObj = sum(stateNow.userSatis);
            bestTiltState = stateNow;
            bestTiltBeamBores = beamBores;
            bestTiltBeamCAxis = beamCAxis;
            bestTiltKappa = kappa_ib;
            bestTiltP = P_ib;
            bestTiltPcAdjustedMask = pcAdjustedMask;
            bestTiltPcAdjustedBeamOrder = pcAdjustedBeamOrder;
            tiltGrid = unique([-baselineTiltMaxDeg:baselineTiltStepDeg:baselineTiltMaxDeg, 0]);
            tiltGrid = tiltGrid(isfinite(tiltGrid));
            for kkTilt = 1:numel(tiltGrid)
                thetaSigned_deg = tiltGrid(kkTilt);

                [b_all_tilt, c_axis_tilt] = beamBoresights(satPos(:,tiltSatIdx)*1000, satVel(:,tiltSatIdx)*1000, basePitchOffsets_deg + thetaSigned_deg);
                beamBoresTrial = beamBores;
                beamCAxisTrial = beamCAxis;
                beamBoresTrial{tiltSatIdx} = reorderBoresightsNorthToSouth(satPos(:,tiltSatIdx)*1000, b_all_tilt);
                beamCAxisTrial{tiltSatIdx} = c_axis_tilt;

                kappaTrial = kappa_ib;
                kappaTrial(tiltSatIdx,:) = computeKappaForSatellite(satPos(:,tiltSatIdx), beamBoresTrial{tiltSatIdx}, P_gs, P_geo, P);
                [P_trial_tilt, pcAdjustedMaskTrial, pcAdjustedBeamOrderTrial] = runBeamLevelPowerControl( ...
                    P_ib_loadsplit, kappaTrial, satPos, Urows, beamBoresTrial, beamCAxisTrial, P, ...
                    useUserAntennaPattern, userServSat, userServBeam, userDemand, num_ib, ...
                    Nleo, Nbeam, Nchannel, useFullFrequencyReuse, pcBeamSatisfactionFloor, leoList);
                stateTrial = evaluateSystemState(P_trial_tilt, userServSat, userServBeam, satPos, Urows, beamBoresTrial, beamCAxisTrial, P, ...
                    useUserAntennaPattern, userDemand, Nleo, Nbeam, Nchannel, useFullFrequencyReuse, kappaTrial);

                epfdLegalTilt = stateTrial.epfd_lin <= 10^(P.EPFD_thr_dB/10) + 1e-18;
                objTilt = sum(stateTrial.userSatis);
                if epfdLegalTilt && objTilt > bestTiltObj + 1e-12
                    bestTiltObj = objTilt;
                    bestTiltState = stateTrial;
                    bestTiltBeamBores = beamBoresTrial;
                    bestTiltBeamCAxis = beamCAxisTrial;
                    bestTiltKappa = kappaTrial;
                    bestTiltP = P_trial_tilt;
                    bestTiltPcAdjustedMask = pcAdjustedMaskTrial;
                    bestTiltPcAdjustedBeamOrder = pcAdjustedBeamOrderTrial;
                    baselineTiltSignedDegNow = thetaSigned_deg;
                    baselineTiltAppliedNow = true;
                end
            end

            if baselineTiltAppliedNow
                P_ib = bestTiltP;
                stateNow = bestTiltState;
                beamBores = bestTiltBeamBores;
                beamCAxis = bestTiltBeamCAxis;
                kappa_ib = bestTiltKappa;
                pcAdjustedMask = bestTiltPcAdjustedMask;
                pcAdjustedBeamOrder = bestTiltPcAdjustedBeamOrder;
                if ~isempty(pcAdjustedBeamOrder)
                    pcAdjustedBeamsStr = strjoin(pcAdjustedBeamOrder.', ',');
                    pcAdjustedBeamCount = numel(pcAdjustedBeamOrder);
                else
                    adjustedIdx = find(pcAdjustedMask);
                    if isempty(adjustedIdx)
                        pcAdjustedBeamsStr = "";
                        pcAdjustedBeamCount = 0;
                    else
                        [adjSatIdx, adjBeamIdx] = ind2sub([Nleo, Nbeam], adjustedIdx);
                        adjNames = strings(numel(adjustedIdx),1);
                        for kk = 1:numel(adjustedIdx)
                            adjNames(kk) = string(sprintf('%s_B%02d', leoList{adjSatIdx(kk)}, adjBeamIdx(kk)));
                        end
                        pcAdjustedBeamsStr = strjoin(adjNames.', ',');
                        pcAdjustedBeamCount = numel(adjustedIdx);
                    end
                end
                pcScale = sum(P_ib(:)) / max(sum(P_ib_before_pc(:)), eps);
                P_ib_after_pc = P_ib;
            end
        end
    end

    if enableBidirectionalRelay && Nusers > 0
        sourceSatIdxRelay = stateNow.idxCritSat;
        if strlength(relaySourceSatelliteId) > 0
            srcFixedIdx = find(strcmp(leoList, char(relaySourceSatelliteId)), 1);
            if ~isempty(srcFixedIdx)
                sourceSatIdxRelay = srcFixedIdx;
            else
                warning('relaySourceSatelliteId not found in leoList: %s. Fallback to critical satellite.', char(relaySourceSatelliteId));
            end
        end
        relaySourceSatNameNow = string(leoList{sourceSatIdxRelay});
        [northHelperIdx, southHelperIdx] = samePlaneSlotNeighbors(sourceSatIdxRelay, leoList, satVisible);
        helperOrder = unique([northHelperIdx, southHelperIdx], 'stable');
        helperOrder = helperOrder(helperOrder >= 1);
        triedDistressed = false(Nusers,1);

        if ~isempty(helperOrder)
            maxRelayIter = max(1, Nusers);
            for relayIter = 1:maxRelayIter
                distressedUsers = find((userServSat == sourceSatIdxRelay) & (stateNow.userSatis < relayDistressedSatisfactionFloor) & ~triedDistressed);
                if isempty(distressedUsers)
                    break;
                end
                [~, ordDist] = sort(stateNow.userSatis(distressedUsers), 'ascend');
                uDist = distressedUsers(ordDist(1));

                baseObj = sum(stateNow.userSatis);
                baseDistSat = stateNow.userSatis(uDist);
                bestAccepted = false;
                bestObj = baseObj;
                bestState = stateNow;
                bestP = P_ib;
                bestUserServSat = userServSat;
                bestUserServBeam = userServBeam;
                bestAction = "";

                for hh = 1:numel(helperOrder)
                    helperIdx = helperOrder(hh);
                    if helperIdx == sourceSatIdxRelay || ~satVisible(helperIdx)
                        continue;
                    end

                    [helperBeam, helperCovered] = assignUserToBeam(Urows(uDist).pos, satPos(:,helperIdx), beamBores{helperIdx}, beamCAxis{helperIdx}, beamHalfEW_deg, beamHalfNS_deg);
                    if ~helperCovered
                        continue;
                    end

                    helperUsersBeforeForward = find(userServSat == helperIdx);
                    userServSatTrial = userServSat;
                    userServBeamTrial = userServBeam;
                    userServSatTrial(uDist) = helperIdx;
                    userServBeamTrial(uDist) = helperBeam;
                    affectedSats = unique([sourceSatIdxRelay, helperIdx]);
                    [P_trial, stateTrial] = recomputeRelayTrial(P_ib, userServSatTrial, userServBeamTrial, userDemand, satPowerBudgetRelay, affectedSats, ...
                        satPos, Urows, beamBores, beamCAxis, P, useUserAntennaPattern, Nleo, Nbeam, Nchannel, useFullFrequencyReuse, kappa_ib);

                    distressImproved = stateTrial.userSatis(uDist) > baseDistSat + 1e-12;
                    objectiveImproved = sum(stateTrial.userSatis) > baseObj + 1e-12;
                    epfdLegal = stateTrial.epfd_lin <= 10^(P.EPFD_thr_dB/10) + 1e-18;

                    if distressImproved && objectiveImproved && epfdLegal
                        objTrial = sum(stateTrial.userSatis);
                        if objTrial > bestObj + 1e-12
                            bestAccepted = true;
                            bestObj = objTrial;
                            bestState = stateTrial;
                            bestP = P_trial;
                            bestUserServSat = userServSatTrial;
                            bestUserServBeam = userServBeamTrial;
                            bestAction = string(sprintf('forward:%s->%s_B%02d for %s', leoList{sourceSatIdxRelay}, leoList{helperIdx}, helperBeam, Urows(uDist).uid));
                        end
                        continue;
                    end

                    % If one-way relay does not improve the global objective, try
                    % helper->source reverse reassociation to balance both satellites.
                    stateBi = stateTrial;
                    P_bi = P_trial;
                    userServSatBi = userServSatTrial;
                    userServBeamBi = userServBeamTrial;
                    biActions = strings(0,1);
                    reversedUsers = false(Nusers,1);

                    for revIter = 1:max(1, numel(helperUsersBeforeForward))
                        bestReverseFound = false;
                        bestReverseObj = sum(stateBi.userSatis);
                        bestReverseState = stateBi;
                        bestReverseP = P_bi;
                        bestReverseSat = userServSatBi;
                        bestReverseBeam = userServBeamBi;
                        bestReverseUser = 0;
                        bestReverseBeamId = 0;

                        helperUsersCurrent = helperUsersBeforeForward(userServSatBi(helperUsersBeforeForward) == helperIdx);
                        for rr = 1:numel(helperUsersCurrent)
                            uRev = helperUsersCurrent(rr);
                            if uRev == uDist || reversedUsers(uRev)
                                continue;
                            end
                            [srcBeam, srcCovered] = assignUserToBeam(Urows(uRev).pos, satPos(:,sourceSatIdxRelay), beamBores{sourceSatIdxRelay}, beamCAxis{sourceSatIdxRelay}, beamHalfEW_deg, beamHalfNS_deg);
                            if ~srcCovered
                                continue;
                            end

                            userServSatRev = userServSatBi;
                            userServBeamRev = userServBeamBi;
                            userServSatRev(uRev) = sourceSatIdxRelay;
                            userServBeamRev(uRev) = srcBeam;
                            [P_rev, stateRev] = recomputeRelayTrial(P_bi, userServSatRev, userServBeamRev, userDemand, satPowerBudgetRelay, affectedSats, ...
                                satPos, Urows, beamBores, beamCAxis, P, useUserAntennaPattern, Nleo, Nbeam, Nchannel, useFullFrequencyReuse, kappa_ib);

                            distressImprovedRev = stateRev.userSatis(uDist) > baseDistSat + 1e-12;
                            objectiveImprovedRev = sum(stateRev.userSatis) > bestReverseObj + 1e-12;
                            epfdLegalRev = stateRev.epfd_lin <= 10^(P.EPFD_thr_dB/10) + 1e-18;
                            if distressImprovedRev && objectiveImprovedRev && epfdLegalRev
                                bestReverseFound = true;
                                bestReverseObj = sum(stateRev.userSatis);
                                bestReverseState = stateRev;
                                bestReverseP = P_rev;
                                bestReverseSat = userServSatRev;
                                bestReverseBeam = userServBeamRev;
                                bestReverseUser = uRev;
                                bestReverseBeamId = srcBeam;
                            end
                        end

                        if ~bestReverseFound
                            break;
                        end

                        reversedUsers(bestReverseUser) = true;
                        stateBi = bestReverseState;
                        P_bi = bestReverseP;
                        userServSatBi = bestReverseSat;
                        userServBeamBi = bestReverseBeam;
                        biActions(end+1,1) = string(sprintf('reverse:%s->%s_B%02d for %s', leoList{helperIdx}, leoList{sourceSatIdxRelay}, bestReverseBeamId, Urows(bestReverseUser).uid)); %#ok<AGROW>
                    end

                    distressImprovedBi = stateBi.userSatis(uDist) > baseDistSat + 1e-12;
                    objectiveImprovedBi = sum(stateBi.userSatis) > baseObj + 1e-12;
                    epfdLegalBi = stateBi.epfd_lin <= 10^(P.EPFD_thr_dB/10) + 1e-18;
                    if distressImprovedBi && objectiveImprovedBi && epfdLegalBi
                        objBi = sum(stateBi.userSatis);
                        if objBi > bestObj + 1e-12
                            bestAccepted = true;
                            bestObj = objBi;
                            bestState = stateBi;
                            bestP = P_bi;
                            bestUserServSat = userServSatBi;
                            bestUserServBeam = userServBeamBi;
                            actionStr = string(sprintf('forward:%s->%s_B%02d for %s', leoList{sourceSatIdxRelay}, leoList{helperIdx}, helperBeam, Urows(uDist).uid));
                            if ~isempty(biActions)
                                actionStr = strjoin([actionStr; biActions], ' | ');
                            end
                            bestAction = actionStr;
                        end
                    end
                end

                if bestAccepted
                    P_ib = bestP;
                    userServSat = bestUserServSat;
                    userServBeam = bestUserServBeam;
                    stateNow = bestState;
                    relayAcceptedMoveCountNow = relayAcceptedMoveCountNow + 1;
                    relayActionsNow(end+1,1) = bestAction; %#ok<AGROW>
                else
                    triedDistressed(uDist) = true;
                end
            end
        end
    end

    load_ib = stateNow.load_ib;
    num_ib = stateNow.num_ib;
    a_ib = stateNow.a_ib;
    userSINR = stateNow.userSINR;
    userCinst = stateNow.userCinst;
    userRate = stateNow.userRate;
    userSat = stateNow.userSat;
    userBeam = stateNow.userBeam;
    userSatis = stateNow.userSatis;
    eta_ib = stateNow.eta_ib;
    eta_sat = stateNow.eta_sat;
    eta_all = eta_ib(:);
    idxCritSat = stateNow.idxCritSat;
    critSatIdxBeam = stateNow.critSatIdxBeam;
    critBeamIdx = stateNow.critBeamIdx;
    epfd_lin = stateNow.epfd_lin;
    epfd_dB = stateNow.epfd_dB;
    relayChangedUserMaskNow = (userServSat ~= userServSat_beforeRelay) | (userServBeam ~= userServBeam_beforeRelay);

    % 6) ranking
    rankWithin = zeros(Nleo,Nbeam);
    for i = 1:Nleo
        [~, ord] = sort(eta_ib(i,:), 'descend');
        rk = zeros(1,Nbeam); rk(ord) = 1:Nbeam;
        rankWithin(i,:) = rk;
    end
    [~, ordG] = sort(eta_all, 'descend');
    rankGlobalVec = zeros(numel(eta_all),1); rankGlobalVec(ordG) = 1:numel(eta_all);
    rankGlobal = reshape(rankGlobalVec, [Nleo,Nbeam]);

    % GS region label using middle satellite among north->south sorted visible set.
    visIdx = find(satVisible);
    if numel(visIdx) >= 3
        [~,ordLat] = sort(satSubLat(visIdx), 'descend');
        midSat = visIdx(ordLat(2));
        gsLat = asind(P_gs(3) / max(norm(P_gs), eps));
        dLat = gsLat - satSubLat(midSat);
        if dLat > beamHalfNS_deg
            regionLabel = "upper";
        elseif dLat < -beamHalfNS_deg
            regionLabel = "lower";
        else
            regionLabel = "middle";
        end
    else
        regionLabel = "unknown";
    end

    % Per-user rows (optional subset: excelExportIdx)
    for uu = 1:Nusers
        if userSat(uu) < 1 || ~ismember(userSat(uu), excelExportIdx)
            continue;
        end
        TimeU(end+1,1) = string(tStr);
        user_id(end+1,1) = string(Urows(uu).uid);
        serving_satellite(end+1,1) = string(leoList{userSat(uu)});
        serving_beam(end+1,1) = userBeam(uu);
        if userServSat_beforeRelay(uu) >= 1
            original_serving_satellite(end+1,1) = string(leoList{userServSat_beforeRelay(uu)});
        else
            original_serving_satellite(end+1,1) = "";
        end
        original_serving_beam(end+1,1) = userServBeam_beforeRelay(uu);
        relay_changed_flag(end+1,1) = double(relayChangedUserMaskNow(uu));
        serving_channel(end+1,1) = beam_id_to_channel_id(userBeam(uu), Nchannel);
        demand_Gbps(end+1,1) = userDemand(uu)/1e9;
        SINR_lin(end+1,1) = userSINR(uu);
        instantaneous_capacity_Gbps(end+1,1) = userCinst(uu)/1e9;
        actual_rate_after_TDMA_Gbps(end+1,1) = userRate(uu)/1e9;
        satisfaction_after_pc_before_relay(end+1,1) = stateBeforeRelay.userSatis(uu);
        satisfaction(end+1,1) = userSatis(uu);
    end

    % Per-beam and per-satellite rows
    satAvgSat = zeros(Nleo,1);
    satAvgSatBeforeRelay = zeros(Nleo,1);
    for i = 1:Nleo
        satUsers = find(userServSat == i);
        satAvgSat(i) = ternary(~isempty(satUsers), mean(userSatis(satUsers)), 0);
        satUsersBeforeRelay = find(userServSat_beforeRelay == i);
        satAvgSatBeforeRelay(i) = ternary(~isempty(satUsersBeforeRelay), mean(stateBeforeRelay.userSatis(satUsersBeforeRelay)), 0);
        if ismember(i, excelExportIdx)
            for b = 1:Nbeam
                ub = find(userServSat==i & userServBeam==b);
                ubBeforeRelay = find(userServSat_beforeRelay==i & userServBeam_beforeRelay==b);
                TimeB(end+1,1) = string(tStr);
                satellite_id_b(end+1,1) = string(leoList{i});
                beam_id_b(end+1,1) = b;
                channel_id_b(end+1,1) = beam_id_to_channel_id(b, Nchannel);
                active_b(end+1,1) = a_ib(i,b);
                assigned_power_W(end+1,1) = P_ib(i,b);
                power_before_pc_W(end+1,1) = P_ib_before_pc(i,b);
                power_after_pc_W(end+1,1) = P_ib_after_pc(i,b);
                power_after_reallocation_W(end+1,1) = P_ib(i,b);
                pc_adjusted_flag(end+1,1) = double(pcAdjustedMask(i,b));
                redistribution_adjusted_flag(end+1,1) = double(redistributionAdjustedMask(i,b));
                number_of_users(end+1,1) = numel(ub);
                beam_total_demand_Gbps(end+1,1) = load_ib(i,b)/1e9;
                average_user_rate_Gbps(end+1,1) = ternary(~isempty(ub), mean(userRate(ub))/1e9, 0);
                average_user_satisfaction_after_pc_before_relay(end+1,1) = ternary(~isempty(ubBeforeRelay), mean(stateBeforeRelay.userSatis(ubBeforeRelay)), 0);
                average_user_satisfaction(end+1,1) = ternary(~isempty(ub), mean(userSatis(ub)), 0);
                beam_EPFD_contribution_lin(end+1,1) = eta_ib(i,b);
                beam_rank_within_satellite(end+1,1) = rankWithin(i,b);
                beam_rank_global(end+1,1) = rankGlobal(i,b);
            end
            TimeS(end+1,1) = string(tStr);
            satellite_id_s(end+1,1) = string(leoList{i});
            total_active_beams(end+1,1) = sum(a_ib(i,:));
            total_power_used_W(end+1,1) = sum(P_ib(i,:));
            total_users(end+1,1) = numel(satUsers);
            satellite_total_demand_Gbps(end+1,1) = sum(userDemand(satUsers))/1e9;
            satellite_average_satisfaction_after_pc_before_relay(end+1,1) = satAvgSatBeforeRelay(i);
            satellite_average_satisfaction(end+1,1) = satAvgSat(i);
            satellite_EPFD_contribution_lin(end+1,1) = eta_sat(i);
            is_critical_satellite(end+1,1) = double(i == idxCritSat);
        end
    end

    % Global row
    TimeG(end+1,1) = string(tStr);
    aggregate_EPFD_dB(end+1,1) = epfd_dB;
    EPFD_threshold_dB(end+1,1) = P.EPFD_thr_dB;
    EPFD_margin_dB(end+1,1) = epfd_dB - P.EPFD_thr_dB;
    critical_satellite_id(end+1,1) = string(leoList{idxCritSat});
    critical_beam_id(end+1,1) = string(sprintf('%s_B%02d', leoList{critSatIdxBeam}, critBeamIdx));
    GS_region_label(end+1,1) = regionLabel;
    power_control_scale(end+1,1) = pcScale;
    power_control_adjusted_beam_count(end+1,1) = pcAdjustedBeamCount;
    power_control_adjusted_beams(end+1,1) = pcAdjustedBeamsStr;
    power_redistribution_step_count(end+1,1) = redistributionStepCount;
    if isempty(redistributionBeamOrder)
        power_redistributed_beams(end+1,1) = "";
    else
        power_redistributed_beams(end+1,1) = strjoin(redistributionBeamOrder.', ',');
    end
    relay_source_satellite_id(end+1,1) = relaySourceSatNameNow;
    relay_accepted_move_count(end+1,1) = relayAcceptedMoveCountNow;
    relay_changed_user_count(end+1,1) = nnz(relayChangedUserMaskNow);
    if isempty(relayActionsNow)
        relay_actions(end+1,1) = "";
    else
        relay_actions(end+1,1) = strjoin(relayActionsNow.', ' || ');
    end
    baseline_tilt_satellite_id(end+1,1) = baselineTiltSatNameNow;
    baseline_tilt_signed_deg(end+1,1) = baselineTiltSignedDegNow;
    baseline_tilt_applied_flag(end+1,1) = double(baselineTiltAppliedNow);
    sum_user_satisfaction_after_pc_before_relay(end+1,1) = sum(stateBeforeRelay.userSatis);
    sum_user_satisfaction(end+1,1) = sum(userSatis);
    n_gso_W = P.kB * P.GSO_noise_temp_K * P.BWref_Hz;
    gso_noise_power_dBW(end+1,1) = 10*log10(max(n_gso_W, 1e-300));
    if useGsoNoiseInQualityMetric
        i_proxy_W = epfd_lin * P.BWref_Hz; % proxy from EPFD spectral aggregate
        gso_IN_proxy_dB(end+1,1) = 10*log10(max(i_proxy_W,1e-300) / max(n_gso_W,1e-300));
    else
        gso_IN_proxy_dB(end+1,1) = nan;
    end
end

Tuser = table(TimeU, user_id, serving_satellite, serving_beam, original_serving_satellite, original_serving_beam, relay_changed_flag, serving_channel, demand_Gbps, SINR_lin, ...
    instantaneous_capacity_Gbps, actual_rate_after_TDMA_Gbps, satisfaction_after_pc_before_relay, satisfaction, ...
    'VariableNames', {'time','user_id','serving_satellite','serving_beam','original_serving_satellite','original_serving_beam','relay_changed_flag','serving_channel','demand_Gbps','SINR', ...
    'instantaneous_capacity_Gbps','actual_rate_after_TDMA_Gbps','satisfaction_after_pc_before_relay','satisfaction'});

Tbeam = table(TimeB, satellite_id_b, beam_id_b, channel_id_b, active_b, assigned_power_W, power_before_pc_W, power_after_pc_W, power_after_reallocation_W, pc_adjusted_flag, redistribution_adjusted_flag, number_of_users, ...
    beam_total_demand_Gbps, average_user_rate_Gbps, average_user_satisfaction_after_pc_before_relay, average_user_satisfaction, beam_EPFD_contribution_lin, ...
    beam_rank_within_satellite, beam_rank_global, ...
    'VariableNames', {'time','satellite_id','beam_id','channel_id','active','assigned_power_W','power_before_pc_W','power_after_pc_W','power_after_reallocation_W','pc_adjusted_flag','redistribution_adjusted_flag','number_of_users', ...
    'beam_total_demand_Gbps','average_user_rate_Gbps','average_user_satisfaction_after_pc_before_relay','average_user_satisfaction','beam_EPFD_contribution', ...
    'beam_rank_within_satellite','beam_rank_global'});

Tsat = table(TimeS, satellite_id_s, total_active_beams, total_power_used_W, total_users, ...
    satellite_total_demand_Gbps, satellite_average_satisfaction_after_pc_before_relay, satellite_average_satisfaction, satellite_EPFD_contribution_lin, is_critical_satellite, ...
    'VariableNames', {'time','satellite_id','total_active_beams','total_power_used_W','total_users', ...
    'satellite_total_demand_Gbps','satellite_average_satisfaction_after_pc_before_relay','satellite_average_satisfaction','satellite_EPFD_contribution','is_critical_satellite'});

Tglobal = table(TimeG, aggregate_EPFD_dB, EPFD_threshold_dB, EPFD_margin_dB, critical_satellite_id, critical_beam_id, GS_region_label, power_control_scale, power_control_adjusted_beam_count, power_control_adjusted_beams, power_redistribution_step_count, power_redistributed_beams, relay_source_satellite_id, relay_accepted_move_count, relay_changed_user_count, relay_actions, baseline_tilt_satellite_id, baseline_tilt_signed_deg, baseline_tilt_applied_flag, sum_user_satisfaction_after_pc_before_relay, sum_user_satisfaction, gso_noise_power_dBW, gso_IN_proxy_dB, ...
    'VariableNames', {'time','aggregate_EPFD','EPFD_threshold','EPFD_margin','critical_satellite_id','critical_beam_id','GS_region_label','power_control_scale','power_control_adjusted_beam_count','power_control_adjusted_beams','power_redistribution_step_count','power_redistributed_beams','relay_source_satellite_id','relay_accepted_move_count','relay_changed_user_count','relay_actions','baseline_tilt_satellite_id','baseline_tilt_signed_deg','baseline_tilt_applied_flag','sum_user_satisfaction_after_pc_before_relay','sum_user_satisfaction','gso_noise_power_dBW','gso_IN_proxy_dB'});

writetable(Tuser, excelPath, 'Sheet', 'PerUser');
writetable(Tbeam, excelPath, 'Sheet', 'PerBeam');
writetable(Tsat, excelPath, 'Sheet', 'PerSatellite');
writetable(Tglobal, excelPath, 'Sheet', 'Global');
fprintf('Saved Excel: %s\n', excelPath);
end

function state = evaluateSystemState(P_ib, userServSat, userServBeam, satPos, Urows, beamBores, beamCAxis, P, ...
    useUserAntennaPattern, userDemand, Nleo, Nbeam, Nchannel, useFullFrequencyReuse, kappa_ib)
[load_ib, num_ib, a_ib] = buildBeamLoads(userServSat, userServBeam, userDemand, Nleo, Nbeam);

Nusers = numel(Urows);
N0 = P.kB * P.user_noise_temp_K;
Buser = P.B_Hz;
userSINR = zeros(Nusers,1);
userCinst = zeros(Nusers,1);
userRate = zeros(Nusers,1);
userSat = userServSat;
userBeam = userServBeam;
userSatis = zeros(Nusers,1);

for uu = 1:Nusers
    i0 = userServSat(uu);
    b0 = userServBeam(uu);
    if i0 < 1 || b0 < 1
        continue;
    end
    if useUserAntennaPattern
        Gur_des_dBi = gso_rx_gain_itu1428(0, P.user_D_m, P.lambda_m);
        Gur_des_lin = 10^(Gur_des_dBi/10);
    else
        Gur_des_lin = 10^(P.GS_LEO_Gmax_dBi/10);
    end
    sig = rxPowerAtUser(P_ib(i0,b0), satPos(:,i0), Urows(uu).pos, beamBores{i0}(:,b0), beamCAxis{i0}, P, Gur_des_lin);
    I = 0;
    sinr = sig / max(I + N0*Buser, eps);
    cinst = Buser * log2(1 + sinr);
    Uib = max(num_ib(i0,b0), 1);
    rate = cinst / Uib;
    satv = min(rate / max(userDemand(uu), eps), 1);
    userSINR(uu) = sinr;
    userCinst(uu) = cinst;
    userRate(uu) = rate;
    userSatis(uu) = satv;
end

eta_ib = P_ib .* kappa_ib;
eta_sat = sum(eta_ib,2);
eta_all = eta_ib(:);
[~, idxCritSat] = max(eta_sat);
[~, idxCritBeam] = max(eta_all);
[critSatIdxBeam, critBeamIdx] = ind2sub([Nleo, Nbeam], idxCritBeam);
epfd_lin = sum(eta_all);
epfd_dB = 10*log10(max(epfd_lin, 1e-300));

state = struct( ...
    'load_ib', load_ib, ...
    'num_ib', num_ib, ...
    'a_ib', a_ib, ...
    'userSINR', userSINR, ...
    'userCinst', userCinst, ...
    'userRate', userRate, ...
    'userSat', userSat, ...
    'userBeam', userBeam, ...
    'userSatis', userSatis, ...
    'eta_ib', eta_ib, ...
    'eta_sat', eta_sat, ...
    'idxCritSat', idxCritSat, ...
    'critSatIdxBeam', critSatIdxBeam, ...
    'critBeamIdx', critBeamIdx, ...
    'epfd_lin', epfd_lin, ...
    'epfd_dB', epfd_dB);
end

function [P_out, pcAdjustedMask, pcAdjustedBeamOrder] = runBeamLevelPowerControl(P_in, kappa_ib, satPos, Urows, beamBores, beamCAxis, P, ...
    useUserAntennaPattern, userServSat, userServBeam, userDemand, num_ib, Nleo, Nbeam, Nchannel, useFullFrequencyReuse, pcBeamSatisfactionFloor, leoList)
P_out = P_in;
pcAdjustedMask = false(Nleo, Nbeam);
pcAdjustedBeamOrder = strings(0,1);
epfd_thr_lin = 10^(P.EPFD_thr_dB / 10);
maxPcIter = nnz(P_in > 0) + 5;

for pcIter = 1:maxPcIter
    eta_pc = P_out .* kappa_ib;
    epfd_pc_lin = sum(eta_pc(:));
    if epfd_pc_lin <= epfd_thr_lin + 1e-18
        break;
    end

    [eta_sorted_pc, ordPc] = sort(eta_pc(:), 'descend');
    foundReducible = false;
    for kk = 1:numel(ordPc)
        eta_sel = eta_sorted_pc(kk);
        if ~isfinite(eta_sel) || eta_sel <= 0
            break;
        end
        [iTry, bTry] = ind2sub([Nleo, Nbeam], ordPc(kk));
        P_try = P_out(iTry, bTry);
        if P_try <= 0
            continue;
        end
        P_floor_try = beamSatisfactionFloorPower( ...
            iTry, bTry, P_try, P_out, satPos, Urows, beamBores, beamCAxis, P, ...
            useUserAntennaPattern, userServSat, userServBeam, userDemand, num_ib, ...
            Nleo, Nbeam, Nchannel, useFullFrequencyReuse, pcBeamSatisfactionFloor);
        if P_floor_try >= P_try - 1e-12
            continue;
        end
        foundReducible = true;
        iSel = iTry;
        bSel = bTry;
        P_now = P_try;
        P_floor = P_floor_try;
        break;
    end

    if ~foundReducible
        break;
    end

    eta_sel = P_now * kappa_ib(iSel, bSel);
    other_lin = epfd_pc_lin - eta_sel;
    epfd_if_floor = other_lin + P_floor * kappa_ib(iSel, bSel);
    if epfd_if_floor > epfd_thr_lin + 1e-18
        P_out(iSel, bSel) = P_floor;
    else
        P_target = (epfd_thr_lin - other_lin) / max(kappa_ib(iSel, bSel), eps);
        P_out(iSel, bSel) = max(P_floor, min(P_target, P_now));
    end

    if ~pcAdjustedMask(iSel, bSel)
        pcAdjustedBeamOrder(end+1,1) = string(sprintf('%s_B%02d', leoList{iSel}, bSel)); %#ok<AGROW>
    end
    pcAdjustedMask(iSel, bSel) = true;

    if epfd_if_floor <= epfd_thr_lin + 1e-18
        break;
    end
end
end

function kappa_row = computeKappaForSatellite(satPos_i, beamBores_i, P_gs, P_geo, P)
Nbeam = size(beamBores_i, 2);
kappa_row = zeros(1, Nbeam);
d_gs_m = norm((P_gs - satPos_i) * 1000);
if d_gs_m < 1
    return;
end
alpha = angleDeg(satPos_i - P_gs, P_geo - P_gs);
Gr_dBi = gso_rx_gain_itu1428(alpha, P.GSO_D_m, P.lambda_m);
Gr_lin = 10^(Gr_dBi/10);
Gr_norm = Gr_lin / max(10^(P.GSO_Gmax_dBi/10), eps);
d_hat_gs = (P_gs - satPos_i);
d_hat_gs = d_hat_gs / max(norm(d_hat_gs), eps);
for b = 1:Nbeam
    phit = angleDeg(beamBores_i(:,b), d_hat_gs);
    Gt_lin = max(P.A_fit * exp(P.beta_fit * phit), 1e-30);
    kappa_row(b) = (1 / P.BWref_Hz) * (Gt_lin / (4*pi*d_gs_m^2)) * Gr_norm;
end
end

function [P_out, state_out] = recomputeRelayTrial(P_in, userServSat, userServBeam, userDemand, satBudget_W, affectedSats, ...
    satPos, Urows, beamBores, beamCAxis, P, useUserAntennaPattern, Nleo, Nbeam, Nchannel, useFullFrequencyReuse, kappa_ib)
[load_ib_trial, ~, ~] = buildBeamLoads(userServSat, userServBeam, userDemand, Nleo, Nbeam);
P_out = P_in;
for kk = 1:numel(affectedSats)
    ii = affectedSats(kk);
    Li = load_ib_trial(ii,:);
    active = Li > 0;
    P_out(ii,:) = 0;
    if any(active)
        P_out(ii,active) = satBudget_W(ii) * Li(active) / max(sum(Li(active)), eps);
    end
end
state_out = evaluateSystemState(P_out, userServSat, userServBeam, satPos, Urows, beamBores, beamCAxis, P, ...
    useUserAntennaPattern, userDemand, Nleo, Nbeam, Nchannel, useFullFrequencyReuse, kappa_ib);
end

function [load_ib, num_ib, a_ib] = buildBeamLoads(userServSat, userServBeam, userDemand, Nleo, Nbeam)
load_ib = zeros(Nleo, Nbeam);
num_ib = zeros(Nleo, Nbeam);
for uu = 1:numel(userServSat)
    i = userServSat(uu);
    b = userServBeam(uu);
    if i < 1 || b < 1
        continue;
    end
    load_ib(i,b) = load_ib(i,b) + userDemand(uu);
    num_ib(i,b) = num_ib(i,b) + 1;
end
a_ib = double(load_ib > 0);
end

function [northIdx, southIdx] = samePlaneSlotNeighbors(srcIdx, leoList, satVisible)
northIdx = 0;
southIdx = 0;
[srcPlane, srcSlot, okSrc] = parseSatelliteName(leoList{srcIdx});
if ~okSrc
    return;
end

for ii = 1:numel(leoList)
    if ii == srcIdx || ~satVisible(ii)
        continue;
    end
    [planeNow, slotNow, okNow] = parseSatelliteName(leoList{ii});
    if ~(okNow && planeNow == srcPlane)
        continue;
    end
    if slotNow == srcSlot + 1
        northIdx = ii;
    elseif slotNow == srcSlot - 1
        southIdx = ii;
    end
end
end

function [planeNum, slotNum, ok] = parseSatelliteName(satName)
tok = regexp(char(satName), '^P(\d+)_S(\d+)$', 'tokens', 'once');
if isempty(tok)
    planeNum = NaN;
    slotNum = NaN;
    ok = false;
    return;
end
planeNum = str2double(tok{1});
slotNum = str2double(tok{2});
ok = isfinite(planeNum) && isfinite(slotNum);
end

function [bAssign, covered] = assignUserToBeam(userPos_km, satPos_km, b_all, c_axis, beamHalfEW_deg, beamHalfNS_deg)
v_su = userPos_km(:) - satPos_km(:);
d_hat = v_su / max(norm(v_su), eps);
bAssign = 1; bestScore = -inf; covered = false;
for b = 1:size(b_all,2)
    b_hat = b_all(:,b);
    t_axis = cross(c_axis, b_hat); t_axis = t_axis / max(norm(t_axis), eps);
    th_h = atan2d(dot(d_hat, c_axis), dot(d_hat, b_hat));
    th_v = atan2d(dot(d_hat, t_axis), dot(d_hat, b_hat));
    inb = (abs(th_h) <= beamHalfEW_deg) && (abs(th_v) <= beamHalfNS_deg);
    if inb
        covered = true;
        score = dot(d_hat, b_hat);
        if score > bestScore
            bestScore = score;
            bAssign = b;
        end
    end
end
end

function Prx = rxPowerAtUser(Ptx_W, satPos_km, userPos_km, b_hat, c_axis, P, Gur_lin)
if Ptx_W <= 0, Prx = 0; return; end
v_su = userPos_km(:) - satPos_km(:);
d_m = norm(v_su) * 1000;
if d_m < 1, Prx = 0; return; end
d_hat = v_su / max(norm(v_su), eps);
t_axis = cross(c_axis, b_hat); t_axis = t_axis / max(norm(t_axis), eps);
th_h = atan2d(dot(d_hat, c_axis), dot(d_hat, b_hat));
th_v = atan2d(dot(d_hat, t_axis), dot(d_hat, b_hat));
phi = hypot(th_h, th_v);
Gt_lin = max(P.A_fit * exp(P.beta_fit * phi), 1e-30);
path = (P.lambda_m^2) / max((4*pi*d_m)^2, eps);
Prx = Ptx_W * Gt_lin * Gur_lin * path;
end

function P_floor = beamSatisfactionFloorPower(iSel, bSel, P_now, P_ib, satPos, Urows, beamBores, beamCAxis, P, ...
    useUserAntennaPattern, userServSat, userServBeam, userDemand, num_ib, Nleo, Nbeam, Nchannel, useFullFrequencyReuse, satFloor)
beamUsers = find(userServSat == iSel & userServBeam == bSel);
if isempty(beamUsers)
    P_floor = P_now;
    return;
end
if satFloor <= 0
    P_floor = 0;
    return;
end

avgSatNow = beamAverageSatisfactionGivenPower(iSel, bSel, P_now, P_ib, satPos, Urows, beamBores, beamCAxis, P, ...
    useUserAntennaPattern, userServSat, userServBeam, userDemand, num_ib, Nleo, Nbeam, Nchannel, useFullFrequencyReuse);
if avgSatNow <= satFloor + 1e-12
    P_floor = P_now;
    return;
end

lo = 0;
hi = P_now;
for it = 1:24
    mid = 0.5 * (lo + hi);
    avgSatMid = beamAverageSatisfactionGivenPower(iSel, bSel, mid, P_ib, satPos, Urows, beamBores, beamCAxis, P, ...
        useUserAntennaPattern, userServSat, userServBeam, userDemand, num_ib, Nleo, Nbeam, Nchannel, useFullFrequencyReuse);
    if avgSatMid >= satFloor
        hi = mid;
    else
        lo = mid;
    end
end
P_floor = hi;
end

function avgSat = beamAverageSatisfactionGivenPower(iSel, bSel, P_trial, P_ib, satPos, Urows, beamBores, beamCAxis, P, ...
    useUserAntennaPattern, userServSat, userServBeam, userDemand, num_ib, Nleo, Nbeam, Nchannel, useFullFrequencyReuse)
beamUsers = find(userServSat == iSel & userServBeam == bSel);
if isempty(beamUsers)
    avgSat = 0;
    return;
end

N0 = P.kB * P.user_noise_temp_K;
Buser = P.B_Hz;
Uib = max(num_ib(iSel, bSel), 1);
satVals = zeros(numel(beamUsers),1);

for kk = 1:numel(beamUsers)
    uu = beamUsers(kk);
    v_ref = satPos(:,iSel) - Urows(uu).pos;
    v_ref = v_ref / max(norm(v_ref), eps);
    if useUserAntennaPattern
        Gur_des_dBi = gso_rx_gain_itu1428(0, P.user_D_m, P.lambda_m);
        Gur_des_lin = 10^(Gur_des_dBi/10);
    else
        Gur_des_lin = 10^(P.GS_LEO_Gmax_dBi/10);
    end
    sig = rxPowerAtUser(P_trial, satPos(:,iSel), Urows(uu).pos, beamBores{iSel}(:,bSel), beamCAxis{iSel}, P, Gur_des_lin);

    I = 0;
    % Keep the power-control floor estimator consistent with the current
    % capacity model: ignore all NGSO beam-to-beam interference here as well.

    sinr = sig / max(I + N0*Buser, eps);
    cinst = Buser * log2(1 + sinr);
    rate = cinst / Uib;
    satVals(kk) = min(rate / max(userDemand(uu), eps), 1);
end

avgSat = mean(satVals);
end

function [uPos_km, ok] = sampleUserInBeamFootprint(P_leo_km, V_leo_kmps, b_all, c_axis, b, beamHalfEW_deg, beamHalfNS_deg, userInBeamCenterOnly)
uPos_km = [NaN;NaN;NaN]; ok = false;
b_hat = b_all(:,b);
t_axis = cross(c_axis, b_hat); t_axis = t_axis / max(norm(t_axis), eps);
if nargin < 8 || isempty(userInBeamCenterOnly), userInBeamCenterOnly = false; end
if userInBeamCenterOnly
    % Exact beam center: direction exactly equals boresight (th_h=0, th_v=0)
    th_h = 0;
    th_v = 0;
else
    th_h = (2*rand()-1) * beamHalfEW_deg;
    th_v = (2*rand()-1) * beamHalfNS_deg;
end
d = b_hat + tand(th_h)*c_axis + tand(th_v)*t_axis;
d = d / max(norm(d), eps);
hit = rayEarthIntersect(P_leo_km*1000, d, 6378137.0);
if isempty(hit), return; end
uPos_km = hit / 1000;
ok = true;
end

function [leoPosDP, leoVelDP] = preloadLeo(root, leoList)
leoPosDP = containers.Map; leoVelDP = containers.Map;
for i = 1:numel(leoList)
    nm = leoList{i};
    sat = root.GetObjectFromPath(['*/Satellite/' nm]);
    leoPosDP(nm) = sat.DataProviders.Item('Cartesian Position').Group.Item('Fixed');
    leoVelDP(nm) = sat.DataProviders.Item('Cartesian Velocity').Group.Item('Fixed');
end
end

function geoPosDP = preloadGeo(root, geoList)
geoPosDP = containers.Map;
for j = 1:numel(geoList)
    nm = geoList{j};
    geo = root.GetObjectFromPath(['*/Satellite/' nm]);
    geoPosDP(nm) = geo.DataProviders.Item('Cartesian Position').Group.Item('Fixed');
end
end

function gsObjMap = preloadGs(root, geoList)
gsObjMap = containers.Map;
for j = 1:numel(geoList)
    gn = geoList{j};
    gsObjMap(gn) = root.GetObjectFromPath(['*/Facility/GSO_GS_' gn]);
end
end

function P = gsXYZ(gsObj)
res = gsObj.DataProviders.Item('Cartesian Position').Exec;
P = xyzFromArray(res.DataSets.ToArray);
end

function P = stkXYZ(dp, tStr)
res = dp.ExecSingle(tStr);
P = xyzFromArray(res.DataSets.ToArray);
end

function P = xyzFromArray(arr)
if isnumeric(arr), P = double(arr(1:3)); return; end
vals = [];
for k = 1:numel(arr)
    a = arr{k};
    if isnumeric(a) && isscalar(a)
        vals(end+1,1) = double(a); %#ok<AGROW>
    elseif ischar(a) || isstring(a)
        n = str2double(a);
        if ~isnan(n), vals(end+1,1) = n; end %#ok<AGROW>
    end
end
if numel(vals) < 3, error('cannot parse XYZ'); end
P = vals(1:3);
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
    b_all(:,k) = rodrigues(b0, c_axis, deg2rad(pitchOffsets_deg(k)));
end
end

function b_sorted = reorderBoresightsNorthToSouth(r_sat_m, b_all)
Re_m = 6378137.0;
nb = size(b_all, 2); lat_deg = -inf(1, nb);
for k = 1:nb
    hit = rayEarthIntersect(r_sat_m, b_all(:,k), Re_m);
    if ~isempty(hit)
        lat_deg(k) = asind(hit(3) / max(norm(hit), eps));
    end
end
[~, idx] = sort(lat_deg, 'descend');
b_sorted = b_all(:, idx);
end

function hit = rayEarthIntersect(r_s_m, d_unit, Re_m)
a = 1; b = 2*dot(r_s_m, d_unit); c = dot(r_s_m,r_s_m)-Re_m^2;
disc = b^2 - 4*a*c;
if disc < 0, hit = []; return; end
s = sqrt(disc);
lam1 = (-b - s)/2; lam2 = (-b + s)/2;
cand = [lam1, lam2]; cand = cand(cand > 0);
if isempty(cand), hit = []; return; end
hit = r_s_m + min(cand)*d_unit;
end

function v = rodrigues(u, k, ang)
v = u*cos(ang) + cross(k,u)*sin(ang) + k*dot(k,u)*(1-cos(ang));
v = v / max(norm(v), eps);
end

function e = gsElev(P_leo_km, P_gs_km)
zen = P_gs_km(:) / max(norm(P_gs_km), eps);
v = P_leo_km(:) - P_gs_km(:);
e = 90 - acosd(max(-1, min(1, dot(v,zen)/(norm(v)+eps))));
end

function a = angleDeg(x, y)
a = acosd(max(-1, min(1, dot(x,y)/(norm(x)*norm(y)+eps))));
end

function s = ternary(c, a, b)
if c, s = a; else, s = b; end
end

function ch = beam_id_to_channel_id(beam_id, nCh)
% Fixed mapping: beam 1..8 -> channels 1..8; beam 9..16 repeat (OneWeb-style 8×250 MHz).
ch = mod(beam_id - 1, nCh) + 1;
end
