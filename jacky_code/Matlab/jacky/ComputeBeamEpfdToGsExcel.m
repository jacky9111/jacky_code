function [Tsystem, Tuser] = ComputeBeamEpfdToGsExcel(root, opts)
% ComputeBeamEpfdToGsExcel
% Compute one-epoch per-beam EPFD contribution from selected LEO satellites
% to one ground station, then write readable System_State/User_State sheets.

if nargin < 2 || isempty(opts)
    opts = struct();
end
if ~isfield(opts, 'satList') || isempty(opts.satList)
    error('opts.satList is required.');
end
if ~isfield(opts, 'geoList') || isempty(opts.geoList)
    error('opts.geoList is required for the GSO receive antenna reference direction.');
end
if ~isfield(opts, 'gsName') || strlength(string(opts.gsName)) == 0
    error('opts.gsName is required.');
end

sc = root.CurrentScenario;
here = fileparts(mfilename('fullpath'));
addpath(fullfile(here, '..', 'powertilt'));

satList = string(opts.satList(:));
geoList = string(opts.geoList(:));
gsName = char(string(opts.gsName));

if ~isfield(opts, 'tStr') || strlength(string(opts.tStr)) == 0
    tStr = char(sc.StartTime);
else
    tStr = char(string(opts.tStr));
end

if ~isfield(opts, 'beamHalfEW_deg') || ~isfinite(opts.beamHalfEW_deg)
    opts.beamHalfEW_deg = 24.5;
end
if ~isfield(opts, 'beamHalfNS_deg') || ~isfinite(opts.beamHalfNS_deg)
    opts.beamHalfNS_deg = 25/16;
end
if ~isfield(opts, 'excelPath') || strlength(string(opts.excelPath)) == 0
    opts.excelPath = fullfile(here, '..', '..', 'Matlab_data', 'Beam_EPFD_GS_CurrentEpoch.xlsx');
end
if ~isfield(opts, 'allocatePowerByUsers') || isempty(opts.allocatePowerByUsers)
    opts.allocatePowerByUsers = true;
end
if ~isfield(opts, 'userPrefix') || strlength(string(opts.userPrefix)) == 0
    opts.userPrefix = "User_";
end
if ~isfield(opts, 'previousBeamPowerScale') || ~isfinite(opts.previousBeamPowerScale)
    opts.previousBeamPowerScale = 0.2;
end
opts.previousBeamPowerScale = max(0, min(1, double(opts.previousBeamPowerScale)));
if ~isfield(opts, 'epfdBackoffMinInitialUserSat') || ~isfinite(opts.epfdBackoffMinInitialUserSat)
    opts.epfdBackoffMinInitialUserSat = 0.9;
end
opts.epfdBackoffMinInitialUserSat = max(0, min(1, double(opts.epfdBackoffMinInitialUserSat)));
if ~isfield(opts, 'useIdealGsoAtGs') || isempty(opts.useIdealGsoAtGs)
    opts.useIdealGsoAtGs = false;
end
if ~isfield(opts, 'prioritySatellite')
    opts.prioritySatellite = "";
end
if ~isfield(opts, 'priorityCoverageFirst') || isempty(opts.priorityCoverageFirst)
    opts.priorityCoverageFirst = false;
end
if ~isfield(opts, 'priorityBeamRange') || isempty(opts.priorityBeamRange)
    opts.priorityBeamRange = 1:Nbeam;
end
if ~isfield(opts, 'userDemand_Mbps') || ~isfinite(opts.userDemand_Mbps)
    opts.userDemand_Mbps = 25;
end
if ~isfield(opts, 'limitPowerToDemand') || isempty(opts.limitPowerToDemand)
    opts.limitPowerToDemand = false;
end
if ~isfield(opts, 'enforceBeamPowerMax') || isempty(opts.enforceBeamPowerMax)
    opts.enforceBeamPowerMax = false;
end
if ~isfield(opts, 'maxBeamPower_W') || ~isfinite(opts.maxBeamPower_W)
    opts.maxBeamPower_W = 1.05;
end
opts.maxBeamPower_W = max(double(opts.maxBeamPower_W), 0);
if ~isfield(opts, 'distressSatellite') || strlength(string(opts.distressSatellite)) == 0
    opts.distressSatellite = "P03_S01";
end
if ~isfield(opts, 'distressXi1') || ~isfinite(opts.distressXi1)
    opts.distressXi1 = 0.7;
end
if ~isfield(opts, 'distressXi2') || ~isfinite(opts.distressXi2)
    opts.distressXi2 = 0.3;
end
if ~isfield(opts, 'helperEta1') || ~isfinite(opts.helperEta1)
    opts.helperEta1 = 0.5;
end
if ~isfield(opts, 'helperEta2') || ~isfinite(opts.helperEta2)
    opts.helperEta2 = 0.3;
end
if ~isfield(opts, 'helperEta3') || ~isfinite(opts.helperEta3)
    opts.helperEta3 = 0.2;
end
opts.distressXi1 = max(double(opts.distressXi1), 0);
opts.distressXi2 = max(double(opts.distressXi2), 0);
xiSum = opts.distressXi1 + opts.distressXi2;
if xiSum <= 0
    opts.distressXi1 = 0.7;
    opts.distressXi2 = 0.3;
else
    opts.distressXi1 = opts.distressXi1 / xiSum;
    opts.distressXi2 = opts.distressXi2 / xiSum;
end
opts.helperEta1 = max(double(opts.helperEta1), 0);
opts.helperEta2 = max(double(opts.helperEta2), 0);
opts.helperEta3 = max(double(opts.helperEta3), 0);
etaSum = opts.helperEta1 + opts.helperEta2 + opts.helperEta3;
if etaSum <= 0
    opts.helperEta1 = 0.5;
    opts.helperEta2 = 0.3;
    opts.helperEta3 = 0.2;
else
    opts.helperEta1 = opts.helperEta1 / etaSum;
    opts.helperEta2 = opts.helperEta2 / etaSum;
    opts.helperEta3 = opts.helperEta3 / etaSum;
end
if isfield(opts, 'params') && ~isempty(opts.params)
    P = opts.params;
else
    P = ku_epfd_params();
end

if ~isfield(P, 'Nbeam'), P.Nbeam = 16; end
if ~isfield(P, 'useEIRPDensityModel'), P.useEIRPDensityModel = true; end
if ~isfield(P, 'EIRPdens_dBW_per_4kHz'), P.EIRPdens_dBW_per_4kHz = -13.4; end
if ~isfield(P, 'B_Hz'), P.B_Hz = 250e6; end
if ~isfield(P, 'kB'), P.kB = 1.380649e-23; end
if ~isfield(P, 'user_noise_temp_K'), P.user_noise_temp_K = 240; end
if P.Nbeam ~= 16
    error('This function assumes 16 beams.');
end

Nbeam = 16;
Pbeam_W = P.Ptotal_W / Nbeam;
Gmax_lin = 10^(P.GSO_Gmax_dBi/10);
Gt_max_lin = max(P.A_fit, eps);
pitchOffsets_deg = (8.5 - (1:Nbeam)) * (2*opts.beamHalfNS_deg);

gsObj = root.GetObjectFromPath(['*/Facility/' gsName]);
P_gs_km = facilityXYZ(gsObj);
[gsLat_deg, gsLon_deg] = facilityLatLon(gsObj);
[userNames, P_users_km] = userFacilitiesXYZ(sc, string(opts.userPrefix));

Ngeo = numel(geoList);
P_geo_all = zeros(3, Ngeo);
for j = 1:Ngeo
    geoName = char(geoList(j));
    if opts.useIdealGsoAtGs
        P_geo_all(:,j) = idealGsoXYZFromLongitude(gsLon_deg);
    else
        try
            geoObj = root.GetObjectFromPath(['*/Satellite/' geoName]);
            geoDP = geoObj.DataProviders.Item('Cartesian Position').Group.Item('Fixed');
            P_geo_all(:,j) = stkXYZ(geoDP, tStr);
        catch ME
            P_geo_all(:,j) = idealGsoXYZFromLongitude(gsLon_deg);
            warning('ComputeBeamEpfdToGsExcel:GeoNotFound', ...
                ['GEO satellite "%s" was not found in STK; using an ideal GSO reference ' ...
                'above GS longitude %.3f deg instead. Original error: %s'], ...
                geoName, gsLon_deg, ME.message);
        end
    end
end

Time = strings(0,1);
GSName = strings(0,1);
GeoName = strings(0,1);
Satellite = strings(0,1);
Plane = strings(0,1);
Beam = zeros(0,1);
PowerModel = strings(0,1);
Pbeam_W_col = nan(0,1);
SatelliteRemainingPower_W = nan(0,1);
BackoffApplied = zeros(0,1);
BackoffRank = nan(0,1);
PowerReturned_W = nan(0,1);
EPFD_lin_initial = nan(0,1);
AggregateEPFD_before_lin = nan(0,1);
AggregateEPFD_after_lin = nan(0,1);
ActiveBeam = zeros(0,1);
UserCount = zeros(0,1);
LoadShare = nan(0,1);
UserDemand_Mbps = nan(0,1);
BeamDemand_Mbps = nan(0,1);
PbeamDemandLimited_W = nan(0,1);
PbeamRequired_W = nan(0,1);
BeamPowerSatisfaction = nan(0,1);
EPFD_dB = nan(0,1);
EPFD_lin = nan(0,1);
EPFD_pct_of_GeoTotal = nan(0,1);
InBeam = zeros(0,1);
Elevation_deg = nan(0,1);
PhiT_deg = nan(0,1);
Alpha_deg = nan(0,1);
Distance_km = nan(0,1);
BeamCenterLat_deg = nan(0,1);
BeamCenterLon_deg = nan(0,1);

rawRows = struct('Time', {}, 'GSName', {}, 'GeoName', {}, 'Satellite', {}, ...
    'Plane', {}, 'Beam', {}, 'PowerModel', {}, 'Pbeam_W', {}, ...
    'SatelliteRemainingPower_W', {}, 'BackoffApplied', {}, 'BackoffRank', {}, 'PowerReturned_W', {}, ...
    'EPFD_lin_initial', {}, 'AggregateEPFD_before_lin', {}, 'AggregateEPFD_after_lin', {}, ...
    'ActiveBeam', {}, 'UserCount', {}, 'LoadShare', {}, 'UserDemand_Mbps', {}, ...
    'BeamDemand_Mbps', {}, 'PbeamDemandLimited_W', {}, 'PbeamRequired_W', {}, ...
    'BeamPowerSatisfaction', {}, 'EPFD_dB', {}, 'EPFD_lin', {}, ...
    'InBeam', {}, 'Elevation_deg', {}, 'PhiT_deg', {}, 'Alpha_deg', {}, ...
    'Distance_km', {}, 'BeamCenterLat_deg', {}, 'BeamCenterLon_deg', {});

satGeom = buildSatelliteBeamGeometry(root, satList, tStr, pitchOffsets_deg);
[userCountMat, userSatIdx, userBeamIdx] = assignUsersToNearestBeamCenter(satGeom, P_users_km, ...
    opts.beamHalfEW_deg, opts.beamHalfNS_deg, string(opts.prioritySatellite), ...
    opts.priorityCoverageFirst, opts.priorityBeamRange);
userDemand_bps = double(opts.userDemand_Mbps) * 1e6;
[beamRequiredPower_W, beamDemand_bps] = computeBeamDemandLimitedPower(satGeom, P_users_km, ...
    userSatIdx, userBeamIdx, userDemand_bps, P);
PbeamActualMat_W = zeros(numel(satList), Nbeam);

for iSat = 1:numel(satList)
    satName = char(satList(iSat));
    P_leo_km = satGeom(iSat).P_leo_km;
    b_all = satGeom(iSat).b_all;
    c_axis = satGeom(iSat).c_axis;
    beamLat = satGeom(iSat).beamLat;
    beamLon = satGeom(iSat).beamLon;
    userCountByBeam = userCountMat(iSat,:).';
    totalUsersAssigned = sum(userCountByBeam);
    activeByBeam = userCountByBeam > 0;
    loadShareByBeam = zeros(Nbeam, 1);
    if totalUsersAssigned > 0
        loadShareByBeam = userCountByBeam / totalUsersAssigned;
    end

    PbeamActualByBeam = zeros(Nbeam, 1);
    activeActualByBeam = activeByBeam;
    loadShareActualByBeam = loadShareByBeam;
    PbeamDemandLimitedByBeam = nan(Nbeam, 1);
    beamPowerSatisfactionByBeam = nan(Nbeam, 1);
    for bb = 1:Nbeam
        if opts.allocatePowerByUsers
            PbeamActualByBeam(bb) = P.Ptotal_W * loadShareActualByBeam(bb);
            if opts.limitPowerToDemand && activeActualByBeam(bb)
                PbeamDemandLimitedByBeam(bb) = min(PbeamActualByBeam(bb), beamRequiredPower_W(iSat,bb));
                beamPowerSatisfactionByBeam(bb) = min(PbeamActualByBeam(bb) / max(beamRequiredPower_W(iSat,bb), eps), 1);
                PbeamActualByBeam(bb) = PbeamDemandLimitedByBeam(bb);
            end
        else
            activeActualByBeam(bb) = true;
            loadShareActualByBeam(bb) = 1 / Nbeam;
            PbeamActualByBeam(bb) = Pbeam_W;
            if opts.limitPowerToDemand && userCountByBeam(bb) > 0
                PbeamDemandLimitedByBeam(bb) = min(PbeamActualByBeam(bb), beamRequiredPower_W(iSat,bb));
                beamPowerSatisfactionByBeam(bb) = min(PbeamActualByBeam(bb) / max(beamRequiredPower_W(iSat,bb), eps), 1);
                PbeamActualByBeam(bb) = PbeamDemandLimitedByBeam(bb);
            end
        end
        if opts.enforceBeamPowerMax
            PbeamActualByBeam(bb) = min(PbeamActualByBeam(bb), opts.maxBeamPower_W);
        end
    end

    if opts.limitPowerToDemand
        [PbeamActualByBeam, beamPowerSatisfactionByBeam, satelliteRemainingPowerNow_W] = ...
            redistributeSatelliteRemainingPower(PbeamActualByBeam, beamRequiredPower_W(iSat,:).', ...
            userCountByBeam, activeActualByBeam, P.Ptotal_W, opts.enforceBeamPowerMax, opts.maxBeamPower_W);
        PbeamDemandLimitedByBeam(activeActualByBeam) = PbeamActualByBeam(activeActualByBeam);
    else
        satelliteRemainingPowerNow_W = max(P.Ptotal_W - sum(PbeamActualByBeam), 0);
    end
    PbeamActualMat_W(iSat,:) = PbeamActualByBeam.';

    for b = 1:Nbeam
        b_hat = b_all(:,b);
        t_axis = cross(c_axis, b_hat);
        t_axis = t_axis / max(norm(t_axis), eps);
        activeBeamNow = activeActualByBeam(b);
        userCountNow = userCountByBeam(b);
        loadShareNow = loadShareActualByBeam(b);
        beamDemandMbpsNow = beamDemand_bps(iSat,b) / 1e6;
        PbeamRequiredNow_W = beamRequiredPower_W(iSat,b);
        PbeamDemandLimitedNow_W = PbeamDemandLimitedByBeam(b);
        beamPowerSatisfactionNow = beamPowerSatisfactionByBeam(b);
        PbeamActual_W = PbeamActualByBeam(b);

        for j = 1:Ngeo
            geoName = char(geoList(j));
            v_gs_m = (P_gs_km - P_leo_km) * 1000;
            d_m = norm(v_gs_m);
            if d_m < 1 || ~activeBeamNow || PbeamActual_W <= 0
                epfdLin = 0;
                phit = NaN;
                alpha = NaN;
                inBeamNow = false;
            else
                d_hat = v_gs_m / d_m;
                th_h = atan2d(dot(d_hat, c_axis), dot(d_hat, b_hat));
                th_v = atan2d(dot(d_hat, t_axis), dot(d_hat, b_hat));
                inBeamNow = (abs(th_h) <= opts.beamHalfEW_deg) && (abs(th_v) <= opts.beamHalfNS_deg);

                phit = angleDeg(b_hat, d_hat);
                Gt_lin = max(P.A_fit * exp(P.beta_fit * phit), 1e-30);
                alpha = angleDeg(P_leo_km - P_gs_km, P_geo_all(:,j) - P_gs_km);
                Gr_dBi = gso_rx_gain_itu1428(alpha, P.GSO_D_m, P.lambda_m);
                Gr_lin = 10^(Gr_dBi/10);

                if P.useEIRPDensityModel
                    eirpRef_dBW = P.EIRPdens_dBW_per_4kHz + 10*log10(P.BWref_Hz/4000);
                    eirpRef_lin = 10^(eirpRef_dBW/10);
                    Gt_rel = Gt_lin / Gt_max_lin;
                    epfdLin = eirpRef_lin * Gt_rel * (1/(4*pi*d_m^2)) * (Gr_lin/Gmax_lin);
                else
                    epfdLin = (PbeamActual_W / P.BWref_Hz) * (Gt_lin/(4*pi*d_m^2)) * (Gr_lin/Gmax_lin);
                end
            end

            parts = split(string(satName), "_");
            planeName = parts(1);
            rawRows(end+1).Time = string(tStr); %#ok<AGROW>
            rawRows(end).GSName = string(gsName);
            rawRows(end).GeoName = string(geoName);
            rawRows(end).Satellite = string(satName);
            rawRows(end).Plane = string(planeName);
            rawRows(end).Beam = b;
            if P.useEIRPDensityModel
                rawRows(end).PowerModel = "EIRP_density";
                rawRows(end).Pbeam_W = NaN;
            elseif opts.allocatePowerByUsers
                if opts.limitPowerToDemand
                    rawRows(end).PowerModel = "Demand_limited_user_load";
                else
                    rawRows(end).PowerModel = "User_load_share";
                end
                rawRows(end).Pbeam_W = PbeamActual_W;
            else
                rawRows(end).PowerModel = "Ptotal_W_div_16";
                rawRows(end).Pbeam_W = PbeamActual_W;
            end
            rawRows(end).SatelliteRemainingPower_W = satelliteRemainingPowerNow_W;
            rawRows(end).BackoffApplied = 0;
            rawRows(end).BackoffRank = NaN;
            rawRows(end).PowerReturned_W = 0;
            rawRows(end).EPFD_lin_initial = epfdLin;
            rawRows(end).AggregateEPFD_before_lin = NaN;
            rawRows(end).AggregateEPFD_after_lin = NaN;
            rawRows(end).ActiveBeam = double(activeBeamNow);
            rawRows(end).UserCount = userCountNow;
            rawRows(end).LoadShare = loadShareNow;
            rawRows(end).UserDemand_Mbps = double(opts.userDemand_Mbps);
            rawRows(end).BeamDemand_Mbps = beamDemandMbpsNow;
            rawRows(end).PbeamDemandLimited_W = PbeamDemandLimitedNow_W;
            rawRows(end).PbeamRequired_W = PbeamRequiredNow_W;
            rawRows(end).BeamPowerSatisfaction = beamPowerSatisfactionNow;
            rawRows(end).EPFD_dB = 10*log10(max(epfdLin, 1e-300));
            rawRows(end).EPFD_lin = epfdLin;
            rawRows(end).InBeam = double(inBeamNow);
            rawRows(end).Elevation_deg = groundElevation(P_leo_km, P_gs_km);
            rawRows(end).PhiT_deg = phit;
            rawRows(end).Alpha_deg = alpha;
            rawRows(end).Distance_km = d_m / 1000;
            rawRows(end).BeamCenterLat_deg = beamLat(b);
            rawRows(end).BeamCenterLon_deg = beamLon(b);
        end
    end
end

[rawRows, PbeamActualMat_W, userBackoffPower_W] = applyAggregateEpfdBackoffToActualPower( ...
    rawRows, PbeamActualMat_W, satList, P.Ptotal_W, P.EPFD_thr_dB, opts.previousBeamPowerScale, ...
    opts.epfdBackoffMinInitialUserSat, satGeom, userSatIdx, userBeamIdx, P_users_km, userCountMat, P, userDemand_bps);
Tuser = buildUserStateTable(tStr, userNames, P_users_km, satList, satGeom, userSatIdx, userBeamIdx, ...
    userDemand_bps, userCountMat, PbeamActualMat_W, P, opts.beamHalfEW_deg, opts.beamHalfNS_deg, userBackoffPower_W);

if isempty(rawRows)
    Tsystem = table();
    Tdistress = table();
    Thelper = table();
else
    totalByGeo = containers.Map('KeyType', 'char', 'ValueType', 'double');
    for r = 1:numel(rawRows)
        key = char(rawRows(r).GeoName);
        if ~isKey(totalByGeo, key)
            totalByGeo(key) = 0;
        end
        totalByGeo(key) = totalByGeo(key) + rawRows(r).EPFD_lin;
    end

    for r = 1:numel(rawRows)
        geoTotal = totalByGeo(char(rawRows(r).GeoName));
        Time(end+1,1) = rawRows(r).Time; %#ok<AGROW>
        GSName(end+1,1) = rawRows(r).GSName; %#ok<AGROW>
        GeoName(end+1,1) = rawRows(r).GeoName; %#ok<AGROW>
        Satellite(end+1,1) = rawRows(r).Satellite; %#ok<AGROW>
        Plane(end+1,1) = rawRows(r).Plane; %#ok<AGROW>
        Beam(end+1,1) = rawRows(r).Beam; %#ok<AGROW>
        PowerModel(end+1,1) = rawRows(r).PowerModel; %#ok<AGROW>
        Pbeam_W_col(end+1,1) = rawRows(r).Pbeam_W; %#ok<AGROW>
        SatelliteRemainingPower_W(end+1,1) = rawRows(r).SatelliteRemainingPower_W; %#ok<AGROW>
        BackoffApplied(end+1,1) = rawRows(r).BackoffApplied; %#ok<AGROW>
        BackoffRank(end+1,1) = rawRows(r).BackoffRank; %#ok<AGROW>
        PowerReturned_W(end+1,1) = rawRows(r).PowerReturned_W; %#ok<AGROW>
        EPFD_lin_initial(end+1,1) = rawRows(r).EPFD_lin_initial; %#ok<AGROW>
        AggregateEPFD_before_lin(end+1,1) = rawRows(r).AggregateEPFD_before_lin; %#ok<AGROW>
        AggregateEPFD_after_lin(end+1,1) = rawRows(r).AggregateEPFD_after_lin; %#ok<AGROW>
        ActiveBeam(end+1,1) = rawRows(r).ActiveBeam; %#ok<AGROW>
        UserCount(end+1,1) = rawRows(r).UserCount; %#ok<AGROW>
        LoadShare(end+1,1) = rawRows(r).LoadShare; %#ok<AGROW>
        UserDemand_Mbps(end+1,1) = rawRows(r).UserDemand_Mbps; %#ok<AGROW>
        BeamDemand_Mbps(end+1,1) = rawRows(r).BeamDemand_Mbps; %#ok<AGROW>
        PbeamDemandLimited_W(end+1,1) = rawRows(r).PbeamDemandLimited_W; %#ok<AGROW>
        PbeamRequired_W(end+1,1) = rawRows(r).PbeamRequired_W; %#ok<AGROW>
        BeamPowerSatisfaction(end+1,1) = rawRows(r).BeamPowerSatisfaction; %#ok<AGROW>
        EPFD_dB(end+1,1) = rawRows(r).EPFD_dB; %#ok<AGROW>
        EPFD_lin(end+1,1) = rawRows(r).EPFD_lin; %#ok<AGROW>
        EPFD_pct_of_GeoTotal(end+1,1) = 100 * rawRows(r).EPFD_lin / max(geoTotal, eps); %#ok<AGROW>
        InBeam(end+1,1) = rawRows(r).InBeam; %#ok<AGROW>
        Elevation_deg(end+1,1) = rawRows(r).Elevation_deg; %#ok<AGROW>
        PhiT_deg(end+1,1) = rawRows(r).PhiT_deg; %#ok<AGROW>
        Alpha_deg(end+1,1) = rawRows(r).Alpha_deg; %#ok<AGROW>
        Distance_km(end+1,1) = rawRows(r).Distance_km; %#ok<AGROW>
        BeamCenterLat_deg(end+1,1) = rawRows(r).BeamCenterLat_deg; %#ok<AGROW>
        BeamCenterLon_deg(end+1,1) = rawRows(r).BeamCenterLon_deg; %#ok<AGROW>
    end

    Tdetail = table(Time, GSName, GeoName, Satellite, Plane, Beam, PowerModel, Pbeam_W_col, SatelliteRemainingPower_W, BackoffApplied, ...
        BackoffRank, PowerReturned_W, EPFD_lin_initial, AggregateEPFD_before_lin, AggregateEPFD_after_lin, ...
        ActiveBeam, UserCount, LoadShare, UserDemand_Mbps, BeamDemand_Mbps, ...
        PbeamDemandLimited_W, PbeamRequired_W, BeamPowerSatisfaction, EPFD_dB, EPFD_lin, ...
        EPFD_pct_of_GeoTotal, InBeam, Elevation_deg, PhiT_deg, Alpha_deg, Distance_km, ...
        BeamCenterLat_deg, BeamCenterLon_deg, ...
        'VariableNames', {'Time','GSName','GeoName','Satellite','Plane','Beam','PowerModel','Pbeam_W','SatelliteRemainingPower_W','BackoffApplied', ...
        'BackoffRank','PowerReturned_W','EPFD_lin_initial','AggregateEPFD_before_lin','AggregateEPFD_after_lin', ...
        'ActiveBeam','UserCount','LoadShare','UserDemand_Mbps','BeamDemand_Mbps', ...
        'PbeamDemandLimited_W','PbeamRequired_W','BeamPowerSatisfaction', ...
        'EPFD_dB','EPFD_lin','EPFD_pct_of_GeoTotal', ...
        'InBeam','Elevation_deg','PhiT_deg','Alpha_deg','Distance_km','BeamCenterLat_deg','BeamCenterLon_deg'});
    Tsystem = buildSystemStateTable(Tdetail, Tuser);
    Tdistress = buildBeamDistressScoreTable(Tdetail, P, opts);
    Thelper = buildHelperUtilityTable(Tdistress, Tuser, userNames, P_users_km, satList, satGeom, ...
        userCountMat, PbeamActualMat_W, P, userDemand_bps, opts);
end

excelPath = char(string(opts.excelPath));
outDir = fileparts(excelPath);
if ~isempty(outDir) && ~exist(outDir, 'dir')
    mkdir(outDir);
end
if exist(excelPath, 'file')
    delete(excelPath);
end
writetable(Tsystem, excelPath, 'Sheet', 'System_State');
writetable(Tuser, excelPath, 'Sheet', 'User_State');
writetable(Tdistress, excelPath, 'Sheet', 'beam distress score');
writetable(Thelper, excelPath, 'Sheet', 'helper utility');
fprintf('Saved beam EPFD Excel: %s\n', excelPath);
end

function Tdistress = buildBeamDistressScoreTable(Tdetail, P, opts)
Tdistress = table();
if isempty(Tdetail) || height(Tdetail) == 0
    return;
end

satTarget = string(opts.distressSatellite);
mask = string(Tdetail.Satellite) == satTarget;
if any(mask)
    geoRef = string(Tdetail.GeoName(find(mask, 1, 'first')));
    mask = mask & string(Tdetail.GeoName) == geoRef;
end
mask = mask & Tdetail.ActiveBeam > 0;
mask = mask & isfinite(Tdetail.PbeamRequired_W);
mask = mask & isfinite(Tdetail.EPFD_lin_initial);

Tbeam = Tdetail(mask, :);
if isempty(Tbeam)
    return;
end

[~, uniqueIdx] = unique(Tbeam.Beam, 'stable');
Tbeam = Tbeam(uniqueIdx, :);

E_lim = 10^(double(P.EPFD_thr_dB) / 10);
a_s_b_GS = zeros(height(Tbeam), 1);
validPower = isfinite(Tbeam.Pbeam_W) & Tbeam.Pbeam_W > 0;
a_s_b_GS(validPower) = Tbeam.EPFD_lin_initial(validPower) ./ Tbeam.Pbeam_W(validPower);
P_req_W = max(Tbeam.PbeamRequired_W, 0);
N_s_b = max(Tbeam.UserCount, 0);
N_max = max(N_s_b);
if ~isfinite(N_max) || N_max <= 0
    N_max = 1;
end

demandDrivenEpfdPressure = (a_s_b_GS .* P_req_W) ./ max(E_lim, eps);
userImpactFactor = N_s_b ./ N_max;
beam_distress_score = opts.distressXi1 * demandDrivenEpfdPressure + opts.distressXi2 * userImpactFactor;

time = Tbeam.Time;
sat = Tbeam.Satellite;
beam = Tbeam.Beam;
geo = Tbeam.GeoName;
load_users = N_s_b;
demand_Mbps = Tbeam.BeamDemand_Mbps;
power_required_W = P_req_W;
epfd_sensitivity_per_W = a_s_b_GS;
xi1 = repmat(opts.distressXi1, height(Tbeam), 1);
xi2 = repmat(opts.distressXi2, height(Tbeam), 1);
epfd_limit_lin = repmat(E_lim, height(Tbeam), 1);
normalized_epfd_pressure = demandDrivenEpfdPressure;
normalized_user_impact = userImpactFactor;

Tdistress = table(time, sat, beam, geo, load_users, demand_Mbps, power_required_W, ...
    epfd_sensitivity_per_W, epfd_limit_lin, xi1, xi2, normalized_epfd_pressure, ...
    normalized_user_impact, beam_distress_score, ...
    'VariableNames', {'time','sat','beam','geo','load_users','demand_Mbps','power_required_W', ...
    'epfd_sensitivity_per_W','epfd_limit_lin','xi1','xi2','normalized_epfd_pressure', ...
    'normalized_user_impact','beam_distress_score'});
Tdistress = sortrows(Tdistress, 'beam_distress_score', 'descend');
end

function Thelper = buildHelperUtilityTable(Tdistress, Tuser, userNames, P_users_km, satList, satGeom, ...
    userCountMat, PbeamActualMat_W, P, userDemand_bps, opts)
Thelper = table();
if isempty(Tdistress) || height(Tdistress) == 0 || isempty(Tuser) || height(Tuser) == 0
    return;
end
requiredDistress = ["sat","beam","beam_distress_score"];
requiredUser = ["user_id","sat","beam","demand_Mbps"];
if ~all(ismember(requiredDistress, string(Tdistress.Properties.VariableNames))) || ...
        ~all(ismember(requiredUser, string(Tuser.Properties.VariableNames)))
    return;
end

scoreMask = isfinite(Tdistress.beam_distress_score);
Tdistress = Tdistress(scoreMask, :);
if isempty(Tdistress)
    return;
end
Tdistress = sortrows(Tdistress, 'beam_distress_score', 'descend');
topSat = string(Tdistress.sat(1));
topBeam = double(Tdistress.beam(1));
topScore = double(Tdistress.beam_distress_score(1));

targetUsers = Tuser(string(Tuser.sat) == topSat & double(Tuser.beam) == topBeam, :);
if isempty(targetUsers)
    return;
end

userNameToIdx = containers.Map('KeyType', 'char', 'ValueType', 'double');
for iu = 1:numel(userNames)
    userNameToIdx(char(string(userNames(iu)))) = iu;
end

Nmax = max(userCountMat(:));
if ~isfinite(Nmax) || Nmax <= 0
    Nmax = 1;
end

time = strings(0,1);
distress_sat = strings(0,1);
distress_beam = zeros(0,1);
distress_score = nan(0,1);
user_id = strings(0,1);
helper_sat = strings(0,1);
helper_beam = zeros(0,1);
helper_set_rank = zeros(0,1);
helper_beam_load_users = zeros(0,1);
helper_beam_load_norm = nan(0,1);
helper_sat_remaining_W = nan(0,1);
helper_sat_availability = nan(0,1);
helper_beam_power_hyp_W = nan(0,1);
helper_service_rate_Mbps = nan(0,1);
helper_service_satisfaction = nan(0,1);
helper_service_quality = nan(0,1);
eta1 = nan(0,1);
eta2 = nan(0,1);
eta3 = nan(0,1);
helper_utility = nan(0,1);

Buser = P.B_Hz;
noisePower_W = P.kB * P.user_noise_temp_K * Buser;
Gur_lin = 10^(P.GS_LEO_Gmax_dBi/10);

for iuRow = 1:height(targetUsers)
    userId = char(string(targetUsers.user_id(iuRow)));
    if ~isKey(userNameToIdx, userId)
        continue;
    end
    iu = userNameToIdx(userId);
    P_user_km = P_users_km(:, iu);
    userDemandMbps = double(targetUsers.demand_Mbps(iuRow));
    helperRank = 0;

    for iSat = 1:numel(satList)
        if string(satList(iSat)) == topSat
            continue;
        end

        [bestBeam, ~] = bestCoveredBeamForUser(satGeom(iSat), P_user_km, opts.beamHalfEW_deg, opts.beamHalfNS_deg);
        if bestBeam < 1
            continue;
        end

        helperRank = helperRank + 1;
        beamLoadUsers = double(userCountMat(iSat, bestBeam));
        beamLoadNorm = (beamLoadUsers + 1) / Nmax;
        satRemaining_W = max(P.Ptotal_W - sum(PbeamActualMat_W(iSat,:)), 0);
        satAvailability = satRemaining_W / max(P.Ptotal_W, eps);
        totalUsersOnSat = sum(userCountMat(iSat,:));
        helperUsers = max(beamLoadUsers + 1, 1);
        if opts.allocatePowerByUsers
            PtxUser_W = P.Ptotal_W * helperUsers / max(totalUsersOnSat + 1, 1);
        else
            PtxUser_W = P.Ptotal_W / max(size(PbeamActualMat_W, 2), 1);
        end
        if isfield(opts, 'enforceBeamPowerMax') && opts.enforceBeamPowerMax
            PtxUser_W = min(PtxUser_W, opts.maxBeamPower_W);
        end
        channelGain = userLinkChannelGainPerW(satGeom(iSat), bestBeam, P_user_km, P, Gur_lin);
        sig = PtxUser_W * channelGain;
        sinr = sig / max(noisePower_W, eps);
        cinst_bps = Buser * log2(1 + sinr);
        rateMbps = cinst_bps / helperUsers / 1e6;
        serviceQuality = min(rateMbps / max(userDemandMbps, eps), 1);
        utility = opts.helperEta1 * serviceQuality - opts.helperEta2 * beamLoadNorm + opts.helperEta3 * satAvailability;

        time(end+1,1) = string(targetUsers.time(iuRow)); %#ok<AGROW>
        distress_sat(end+1,1) = topSat; %#ok<AGROW>
        distress_beam(end+1,1) = topBeam; %#ok<AGROW>
        distress_score(end+1,1) = topScore; %#ok<AGROW>
        user_id(end+1,1) = string(userId); %#ok<AGROW>
        helper_sat(end+1,1) = string(satList(iSat)); %#ok<AGROW>
        helper_beam(end+1,1) = bestBeam; %#ok<AGROW>
        helper_set_rank(end+1,1) = helperRank; %#ok<AGROW>
        helper_beam_load_users(end+1,1) = beamLoadUsers; %#ok<AGROW>
        helper_beam_load_norm(end+1,1) = beamLoadNorm; %#ok<AGROW>
        helper_sat_remaining_W(end+1,1) = satRemaining_W; %#ok<AGROW>
        helper_sat_availability(end+1,1) = satAvailability; %#ok<AGROW>
        helper_beam_power_hyp_W(end+1,1) = PtxUser_W; %#ok<AGROW>
        helper_service_rate_Mbps(end+1,1) = rateMbps; %#ok<AGROW>
        helper_service_satisfaction(end+1,1) = serviceQuality; %#ok<AGROW>
        helper_service_quality(end+1,1) = serviceQuality; %#ok<AGROW>
        eta1(end+1,1) = opts.helperEta1; %#ok<AGROW>
        eta2(end+1,1) = opts.helperEta2; %#ok<AGROW>
        eta3(end+1,1) = opts.helperEta3; %#ok<AGROW>
        helper_utility(end+1,1) = utility; %#ok<AGROW>
    end
end

if isempty(user_id)
    return;
end

Thelper = table(time, distress_sat, distress_beam, distress_score, user_id, helper_sat, helper_beam, ...
    helper_set_rank, helper_beam_load_users, helper_beam_load_norm, helper_sat_remaining_W, ...
    helper_sat_availability, helper_beam_power_hyp_W, helper_service_rate_Mbps, helper_service_satisfaction, ...
    helper_service_quality, eta1, eta2, eta3, helper_utility, ...
    'VariableNames', {'time','distress_sat','distress_beam','distress_score','user_id','helper_sat','helper_beam', ...
    'helper_set_rank','helper_beam_load_users','helper_beam_load_norm','helper_sat_remaining_W', ...
    'helper_sat_availability','helper_beam_power_hyp_W','helper_service_rate_Mbps','helper_service_satisfaction', ...
    'helper_service_quality','eta1','eta2','eta3','helper_utility'});
Thelper = sortrows(Thelper, 'helper_utility', 'descend');
end

function Tsystem = buildSystemStateTable(Tdetail, Tuser)
time = Tdetail.Time;
sat = Tdetail.Satellite;
beam = Tdetail.Beam;
active = Tdetail.ActiveBeam;
power_W = Tdetail.Pbeam_W;
remaining_power_W = Tdetail.SatelliteRemainingPower_W;
backoff_applied = Tdetail.BackoffApplied;
backoff_rank = Tdetail.BackoffRank;
power_returned_W = Tdetail.PowerReturned_W;
aggregate_epfd_before_dB = nan(height(Tdetail), 1);
mB = isfinite(Tdetail.AggregateEPFD_before_lin) & Tdetail.AggregateEPFD_before_lin > 0;
aggregate_epfd_before_dB(mB) = 10*log10(Tdetail.AggregateEPFD_before_lin(mB));
aggregate_epfd_after_dB = nan(height(Tdetail), 1);
mA = isfinite(Tdetail.AggregateEPFD_after_lin) & Tdetail.AggregateEPFD_after_lin > 0;
aggregate_epfd_after_dB(mA) = 10*log10(Tdetail.AggregateEPFD_after_lin(mA));
load_users = Tdetail.UserCount;
demand_Mbps = Tdetail.BeamDemand_Mbps;
avg_satisfaction = nan(height(Tdetail), 1);

for r = 1:height(Tdetail)
    mask = Tuser.sat == sat(r) & Tuser.beam == beam(r);
    if any(mask)
        avg_satisfaction(r) = mean(Tuser.satisfaction(mask), 'omitnan');
    elseif active(r) == 0
        avg_satisfaction(r) = NaN;
    else
        avg_satisfaction(r) = Tdetail.BeamPowerSatisfaction(r);
    end
end

Tsystem = table(time, sat, beam, active, power_W, remaining_power_W, backoff_applied, backoff_rank, ...
    power_returned_W, aggregate_epfd_before_dB, aggregate_epfd_after_dB, load_users, demand_Mbps, ...
    avg_satisfaction);

activeKeep = active > 0;
beamLinSort = Tdetail.EPFD_lin_initial(activeKeep);
Tsystem = Tsystem(activeKeep, :);
rankSort = Tsystem.backoff_rank;
rankSort(~(Tsystem.backoff_applied > 0) | isnan(rankSort)) = inf;
[~, order] = sortrows([rankSort, -beamLinSort]);
Tsystem = Tsystem(order, :);

% remaining_power_W is a satellite-level pool after beam demand caps. Show it
% once per satellite so it is not mistaken for a per-beam remaining budget.
satSeen = strings(0,1);
for r = 1:height(Tsystem)
    if any(satSeen == Tsystem.sat(r))
        Tsystem.remaining_power_W(r) = NaN;
    else
        satSeen(end+1,1) = Tsystem.sat(r); %#ok<AGROW>
    end
end
end

function [PbeamActualByBeam, beamPowerSatisfactionByBeam, satelliteRemainingPower_W] = ...
    redistributeSatelliteRemainingPower(PbeamActualByBeam, PbeamRequiredByBeam, userCountByBeam, activeByBeam, satelliteTotalPower_W, enforceBeamPowerMax, maxBeamPower_W)
if nargin < 6 || isempty(enforceBeamPowerMax)
    enforceBeamPowerMax = false;
end
if nargin < 7 || ~isfinite(maxBeamPower_W)
    maxBeamPower_W = inf;
end
if enforceBeamPowerMax
    PbeamActualByBeam = min(PbeamActualByBeam, maxBeamPower_W);
end

beamPowerSatisfactionByBeam = nan(size(PbeamActualByBeam));
validActive = activeByBeam & isfinite(PbeamRequiredByBeam) & PbeamRequiredByBeam > 0;
beamPowerSatisfactionByBeam(validActive) = min(PbeamActualByBeam(validActive) ./ ...
    max(PbeamRequiredByBeam(validActive), eps), 1);

satelliteRemainingPower_W = max(satelliteTotalPower_W - sum(PbeamActualByBeam), 0);
if satelliteRemainingPower_W <= 0 || ~any(validActive)
    return;
end

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

beamPowerSatisfactionByBeam(validActive) = min(PbeamActualByBeam(validActive) ./ ...
    max(PbeamRequiredByBeam(validActive), eps), 1);
satelliteRemainingPower_W = max(satelliteRemainingPower_W, 0);
end

function sMin = minUserSatisfactionAtBeamPower(Pbeam_W, iSat, b, userSatIdx, userBeamIdx, ...
    P_users_km, satGeom, userCountMat, P, userDemand_bps)
if iSat < 1 || b < 1 || ~isfinite(Pbeam_W) || Pbeam_W <= 0
    sMin = 0;
    return;
end
iuList = find(userSatIdx == iSat & userBeamIdx == b);
if isempty(iuList)
    sMin = NaN;
    return;
end
Buser = P.B_Hz;
noisePower_W = P.kB * P.user_noise_temp_K * Buser;
Gur_lin = 10^(P.GS_LEO_Gmax_dBi/10);
demandMbps = userDemand_bps / 1e6;
usersInBeam = max(double(userCountMat(iSat, b)), 1);
nU = numel(iuList);
sList = zeros(nU, 1);
for jj = 1:nU
    iu = iuList(jj);
    channelGain = userLinkChannelGainPerW(satGeom(iSat), b, P_users_km(:, iu), P, Gur_lin);
    sig = Pbeam_W * channelGain;
    sinr = sig / max(noisePower_W, eps);
    cinst_bps = Buser * log2(1 + sinr);
    rate_Mbps = cinst_bps / usersInBeam / 1e6;
    sList(jj) = min(rate_Mbps / max(demandMbps, eps), 1);
end
sMin = min(sList);
end

function [Pnew, iuList, PuserTarget_W] = beamPowerForAllUsersTargetSatisfaction(P_old, iSat, b, targetSat, userSatIdx, userBeamIdx, ...
    P_users_km, satGeom, userCountMat, P, userDemand_bps)
% Find the beam total power required when each user in the selected beam is
% individually allocated just enough power to reach targetSat satisfaction.
% Pnew is the sum of those per-user target powers. This is different from
% using one common Pbeam and only forcing the worst user to targetSat.
Pnew = P_old;
iuList = find(userSatIdx == iSat & userBeamIdx == b);
PuserTarget_W = nan(numel(iuList), 1);
if ~isfinite(P_old) || P_old <= 0 || isempty(iuList)
    return;
end

targetSat = max(0, min(1, double(targetSat)));
Buser = P.B_Hz;
noisePower_W = P.kB * P.user_noise_temp_K * Buser;
Gur_lin = 10^(P.GS_LEO_Gmax_dBi/10);
usersInBeam = max(double(userCountMat(iSat, b)), 1);

% In the original User_State model, each user rate is capacity/usersInBeam.
% Therefore each user's instantaneous capacity target must be multiplied by
% usersInBeam before converting to required SINR.
targetCapacityPerUser_bps = targetSat * userDemand_bps * usersInBeam;
sinrReq = 2^(targetCapacityPerUser_bps / max(Buser, eps)) - 1;

for jj = 1:numel(iuList)
    iu = iuList(jj);
    channelGain = userLinkChannelGainPerW(satGeom(iSat), b, P_users_km(:, iu), P, Gur_lin);
    if channelGain <= 0 || ~isfinite(channelGain)
        PuserTarget_W(jj) = inf;
    else
        PuserTarget_W(jj) = sinrReq * noisePower_W / channelGain;
    end
end

if any(~isfinite(PuserTarget_W))
    Pnew = P_old;
    return;
end

Pnew = sum(PuserTarget_W);
end

function [rawRows, PbeamActualMat_W, userBackoffPower_W] = applyAggregateEpfdBackoffToActualPower( ...
    rawRows, PbeamActualMat_W, satList, satelliteTotalPower_W, epfdThreshold_dB, targetMinUserSatisfaction, ...
    minInitialUserSat, satGeom, userSatIdx, userBeamIdx, P_users_km, userCountMat, P, userDemand_bps)
% Greedy EPFD control: each step picks the beam with largest current EPFD_lin among
% beams whose users are initially healthy enough for backoff. For a selected beam,
% every served user is assigned the power needed to reach targetMinUserSatisfaction;
% the new beam power is the sum of these per-user target powers. Returned power is
% P_old - P_new and is reflected in the satellite remaining-power pool.
% AggregateEPFD_before_lin / after_lin on a row: for the Geo being de-risked in that
% step only, linear sum of active beam EPFD_lin before vs after this step (chain:
% next step's before equals previous after only while the same Geo loop runs).
userBackoffPower_W = nan(numel(userSatIdx), 1);
if isempty(rawRows)
    return;
end

targetMinUserSatisfaction = max(0, min(1, double(targetMinUserSatisfaction)));
minInitialUserSat = max(0, min(1, double(minInitialUserSat)));
epfdThreshold_lin = 10^(epfdThreshold_dB / 10);
geoNames = unique([rawRows.GeoName], 'stable');

stepCounter = 0;
processedBeams = containers.Map('KeyType', 'char', 'ValueType', 'logical');

for ig = 1:numel(geoNames)
    geoName = geoNames(ig);
    maxIter = numel(rawRows) * 8;
    for it = 1:maxIter
        geoMask = [rawRows.GeoName] == geoName;
        activeMask = geoMask & [rawRows.ActiveBeam] > 0 & [rawRows.EPFD_lin] > 0 & ...
            isfinite([rawRows.Pbeam_W]) & [rawRows.Pbeam_W] > 0;
        aggregateEpfd_lin = sum([rawRows(activeMask).EPFD_lin]);
        if aggregateEpfd_lin <= epfdThreshold_lin
            break;
        end

        idx = find(activeMask);
        if isempty(idx)
            break;
        end

        eligibleIdx = zeros(0, 1);
        for k = 1:numel(idx)
            ii = idx(k);
            key = beamPowerKey(rawRows(ii).Satellite, rawRows(ii).Beam);
            if isKey(processedBeams, key)
                continue;
            end
            iSatEl = find(satList == rawRows(ii).Satellite, 1);
            if isempty(iSatEl)
                processedBeams(key) = true;
                continue;
            end
            bEl = rawRows(ii).Beam;
            Pnow = rawRows(ii).Pbeam_W;
            if ~isfinite(Pnow) || Pnow <= 0
                processedBeams(key) = true;
                continue;
            end
            sMinOld = minUserSatisfactionAtBeamPower(Pnow, iSatEl, bEl, userSatIdx, userBeamIdx, ...
                P_users_km, satGeom, userCountMat, P, userDemand_bps);
            if isnan(sMinOld)
                processedBeams(key) = true;
                continue;
            end
            if sMinOld <= targetMinUserSatisfaction + 1e-12
                processedBeams(key) = true;
                continue;
            end
            if sMinOld < minInitialUserSat - 1e-12
                processedBeams(key) = true;
                continue;
            end
            eligibleIdx(end+1,1) = ii; %#ok<AGROW>
        end

        if isempty(eligibleIdx)
            break;
        end

        [~, pickLocal] = max([rawRows(eligibleIdx).EPFD_lin]);
        rowIdx = eligibleIdx(pickLocal);
        satName = rawRows(rowIdx).Satellite;
        beamIdx = rawRows(rowIdx).Beam;
        key = beamPowerKey(satName, beamIdx);

        satIdxPick = find(satList == satName, 1);
        if isempty(satIdxPick)
            processedBeams(key) = true;
            continue;
        end
        P_old = rawRows(rowIdx).Pbeam_W;
        [P_new, iuBackoffList, PuserTarget_W] = beamPowerForAllUsersTargetSatisfaction(P_old, satIdxPick, beamIdx, targetMinUserSatisfaction, ...
            userSatIdx, userBeamIdx, P_users_km, satGeom, userCountMat, P, userDemand_bps);
        if P_new >= P_old - 1e-15
            processedBeams(key) = true;
            continue;
        end

        aggStepBefore = aggregateEpfd_lin;

        stepCounter = stepCounter + 1;
        powerReturned = P_old - P_new;
        powerScale = P_new / P_old;
        sPost = targetMinUserSatisfaction;
        if ~isempty(iuBackoffList) && numel(iuBackoffList) == numel(PuserTarget_W)
            userBackoffPower_W(iuBackoffList) = PuserTarget_W;
        end

        sameBeamMask = [rawRows.Satellite] == satName & [rawRows.Beam] == beamIdx;
        sameBeamIdx = find(sameBeamMask);
        for k = 1:numel(sameBeamIdx)
            ii = sameBeamIdx(k);
            rawRows(ii).Pbeam_W = P_new;
            rawRows(ii).PbeamDemandLimited_W = P_new;
            rawRows(ii).BeamPowerSatisfaction = sPost;
            rawRows(ii).EPFD_lin = rawRows(ii).EPFD_lin * powerScale;
            rawRows(ii).EPFD_dB = 10*log10(max(rawRows(ii).EPFD_lin, 1e-300));
            rawRows(ii).BackoffApplied = 1;
            rawRows(ii).BackoffRank = stepCounter;
            rawRows(ii).PowerReturned_W = powerReturned;
        end

        activeMaskPost = geoMask & [rawRows.ActiveBeam] > 0 & [rawRows.EPFD_lin] > 0 & ...
            isfinite([rawRows.Pbeam_W]) & [rawRows.Pbeam_W] > 0;
        aggStepAfter = sum([rawRows(activeMaskPost).EPFD_lin]);

        for k = 1:numel(sameBeamIdx)
            ii = sameBeamIdx(k);
            if rawRows(ii).GeoName == geoName
                rawRows(ii).AggregateEPFD_before_lin = aggStepBefore;
                rawRows(ii).AggregateEPFD_after_lin = aggStepAfter;
            end
        end

        PbeamActualMat_W(satIdxPick, beamIdx) = P_new;
        processedBeams(key) = true;
    end
end

for iSat = 1:numel(satList)
    satName = satList(iSat);
    satRemainingPower_W = max(satelliteTotalPower_W - sum(PbeamActualMat_W(iSat,:)), 0);
    satMask = [rawRows.Satellite] == satName;
    satIdx = find(satMask);
    for k = 1:numel(satIdx)
        rawRows(satIdx(k)).SatelliteRemainingPower_W = satRemainingPower_W;
    end
end
end

function key = beamPowerKey(satName, beamIdx)
key = sprintf('%s_B%02d', char(string(satName)), round(double(beamIdx)));
end

function Tuser = buildUserStateTable(tStr, userNames, P_users_km, satList, satGeom, userSatIdx, userBeamIdx, ...
    userDemand_bps, userCountMat, PbeamActualMat_W, P, beamHalfEW_deg, beamHalfNS_deg, userBackoffPower_W)
Nuser = numel(userNames);
if nargin < 14 || isempty(userBackoffPower_W)
    userBackoffPower_W = nan(Nuser, 1);
end
time = repmat(string(tStr), Nuser, 1);
user_id = string(userNames(:));
sat = strings(Nuser, 1);
beam = nan(Nuser, 1);
demand_Mbps = repmat(userDemand_bps / 1e6, Nuser, 1);
rate_Mbps = zeros(Nuser, 1);
satisfaction = zeros(Nuser, 1);
covered_by_helpers = zeros(Nuser, 1);
distress_risk = zeros(Nuser, 1);

Buser = P.B_Hz;
noisePower_W = P.kB * P.user_noise_temp_K * Buser;
Gur_lin = 10^(P.GS_LEO_Gmax_dBi/10);

for iu = 1:Nuser
    iSat = userSatIdx(iu);
    b = userBeamIdx(iu);
    helperCount = countHelperCoverage(satGeom, P_users_km(:,iu), iSat, b, beamHalfEW_deg, beamHalfNS_deg);
    covered_by_helpers(iu) = double(helperCount > 0);

    if iSat < 1 || b < 1
        distress_risk(iu) = 1;
        continue;
    end

    sat(iu) = satList(iSat);
    beam(iu) = b;
    channelGain = userLinkChannelGainPerW(satGeom(iSat), b, P_users_km(:,iu), P, Gur_lin);
    if iu <= numel(userBackoffPower_W) && isfinite(userBackoffPower_W(iu)) && userBackoffPower_W(iu) > 0
        PtxUser_W = userBackoffPower_W(iu);
    else
        PtxUser_W = PbeamActualMat_W(iSat,b);
    end
    sig = PtxUser_W * channelGain;
    sinr = sig / max(noisePower_W, eps);
    cinst_bps = Buser * log2(1 + sinr);
    usersInBeam = max(userCountMat(iSat,b), 1);
    rate_Mbps(iu) = cinst_bps / usersInBeam / 1e6;
    satisfaction(iu) = min(rate_Mbps(iu) / max(demand_Mbps(iu), eps), 1);
    distress_risk(iu) = double(satisfaction(iu) < 1 && covered_by_helpers(iu) == 0);
end

Tuser = table(time, user_id, sat, beam, demand_Mbps, rate_Mbps, satisfaction, ...
    covered_by_helpers, distress_risk);
end

function helperCount = countHelperCoverage(satGeom, P_user_km, servingSatIdx, servingBeamIdx, beamHalfEW_deg, beamHalfNS_deg)
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

function Tbackoff = buildAggregateBackoffTable(Time, GSName, GeoName, Satellite, Plane, Beam, ...
    EPFD_lin, EPFD_dB, ActiveBeam, UserCount, LoadShare, Pbeam_W, previousBeamPowerScale)
Rank = zeros(0,1);
TimeOut = strings(0,1);
GSNameOut = strings(0,1);
GeoNameOut = strings(0,1);
CandidateSatellite = strings(0,1);
CandidatePlane = strings(0,1);
CandidateBeam = zeros(0,1);
CandidateOriginalEPFD_dB = nan(0,1);
CandidateOriginalEPFD_lin = nan(0,1);
CandidateUserCount = zeros(0,1);
CandidateLoadShare = nan(0,1);
CandidatePbeam_W = nan(0,1);
PreviousReducedCount = zeros(0,1);
PreviousReducedPowerScale = nan(0,1);
AggregateEPFD_dB = nan(0,1);
AggregateEPFD_lin = nan(0,1);
AggregateReductionFromOriginal_dB = nan(0,1);

geoU = unique(GeoName, 'stable');
for iGeo = 1:numel(geoU)
    geoMask = GeoName == geoU(iGeo);
    activeMask = geoMask & ActiveBeam > 0 & EPFD_lin > 0;
    idx = find(activeMask);
    if isempty(idx)
        continue;
    end

    [sortedEpfd, order] = sort(EPFD_lin(idx), 'descend');
    idxSorted = idx(order);
    originalAgg = sum(sortedEpfd);
    reducedContributionSum = 0;

    for k = 1:numel(idxSorted)
        ii = idxSorted(k);
        currentAgg = originalAgg - (1 - previousBeamPowerScale) * reducedContributionSum;

        Rank(end+1,1) = k; %#ok<AGROW>
        TimeOut(end+1,1) = Time(ii); %#ok<AGROW>
        GSNameOut(end+1,1) = GSName(ii); %#ok<AGROW>
        GeoNameOut(end+1,1) = GeoName(ii); %#ok<AGROW>
        CandidateSatellite(end+1,1) = Satellite(ii); %#ok<AGROW>
        CandidatePlane(end+1,1) = Plane(ii); %#ok<AGROW>
        CandidateBeam(end+1,1) = Beam(ii); %#ok<AGROW>
        CandidateOriginalEPFD_dB(end+1,1) = EPFD_dB(ii); %#ok<AGROW>
        CandidateOriginalEPFD_lin(end+1,1) = EPFD_lin(ii); %#ok<AGROW>
        CandidateUserCount(end+1,1) = UserCount(ii); %#ok<AGROW>
        CandidateLoadShare(end+1,1) = LoadShare(ii); %#ok<AGROW>
        CandidatePbeam_W(end+1,1) = Pbeam_W(ii); %#ok<AGROW>
        PreviousReducedCount(end+1,1) = k - 1; %#ok<AGROW>
        PreviousReducedPowerScale(end+1,1) = previousBeamPowerScale; %#ok<AGROW>
        AggregateEPFD_lin(end+1,1) = currentAgg; %#ok<AGROW>
        AggregateEPFD_dB(end+1,1) = 10*log10(max(currentAgg, 1e-300)); %#ok<AGROW>
        AggregateReductionFromOriginal_dB(end+1,1) = ...
            10*log10(max(currentAgg, 1e-300)) - 10*log10(max(originalAgg, 1e-300)); %#ok<AGROW>

        reducedContributionSum = reducedContributionSum + EPFD_lin(ii);
    end
end

Tbackoff = table(Rank, TimeOut, GSNameOut, GeoNameOut, CandidateSatellite, CandidatePlane, ...
    CandidateBeam, CandidateOriginalEPFD_dB, CandidateOriginalEPFD_lin, ...
    CandidateUserCount, CandidateLoadShare, CandidatePbeam_W, ...
    PreviousReducedCount, PreviousReducedPowerScale, AggregateEPFD_dB, AggregateEPFD_lin, ...
    AggregateReductionFromOriginal_dB, ...
    'VariableNames', {'Rank','Time','GSName','GeoName','CandidateSatellite','CandidatePlane', ...
    'CandidateBeam','CandidateOriginalEPFD_dB','CandidateOriginalEPFD_lin', ...
    'CandidateUserCount','CandidateLoadShare','CandidatePbeam_W', ...
    'PreviousReducedCount','PreviousReducedPowerScale','AggregateEPFD_dB','AggregateEPFD_lin', ...
    'AggregateReductionFromOriginal_dB'});
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

function v = rodrigues(u, k, ang)
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
if numel(vals) < 2
    error('Cannot parse facility LLA.');
end
lat_deg = vals(1);
lon_deg = vals(2);
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

if isempty(userNames)
    warning('ComputeBeamEpfdToGsExcel:NoUsers', ...
        'No user facilities found with prefix "%s"; all beams will be inactive.', char(userPrefix));
end
end

function satGeom = buildSatelliteBeamGeometry(root, satList, tStr, pitchOffsets_deg)
satGeom = repmat(struct('satName', "", 'P_leo_km', [], 'b_all', [], 'c_axis', [], ...
    'beamLat', [], 'beamLon', [], 'subLat', [], 'subLon', []), numel(satList), 1);

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
        [priorityBeam, ~] = bestCoveredBeamForUser(satGeom(prioritySatIdx), P_users_km(:,iu), ...
            beamHalfEW_deg, beamHalfNS_deg);
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
    [bestBeam, ~] = bestCoveredBeamForUser(satGeom(bestSat), P_users_km(:,iu), ...
        beamHalfEW_deg, beamHalfNS_deg);

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

function P_geo_km = idealGsoXYZFromLongitude(lon_deg)
R_geo_km = 42164.0;
P_geo_km = R_geo_km * [cosd(lon_deg); sind(lon_deg); 0];
end

function P = xyzFromArray(arr)
vals = numericScalars(arr);
if numel(vals) < 3
    error('Cannot parse XYZ.');
end
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

function elev = groundElevation(P_leo_km, P_gs_km)
zen = P_gs_km(:) / max(norm(P_gs_km), eps);
v = P_leo_km(:) - P_gs_km(:);
elev = 90 - acosd(max(-1, min(1, dot(v, zen)/(norm(v)+eps))));
end

function a = angleDeg(x, y)
a = acosd(max(-1, min(1, dot(x,y)/(norm(x)*norm(y)+eps))));
end
