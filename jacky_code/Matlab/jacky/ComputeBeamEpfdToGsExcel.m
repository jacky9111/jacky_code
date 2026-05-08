function [Tdetail, Tsummary] = ComputeBeamEpfdToGsExcel(root, opts)
% ComputeBeamEpfdToGsExcel
% Compute one-epoch per-beam EPFD contribution from selected LEO satellites
% to one ground station, then write Detail/Summary sheets to Excel.

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
if ~isfield(opts, 'useIdealGsoAtGs') || isempty(opts.useIdealGsoAtGs)
    opts.useIdealGsoAtGs = false;
end
if ~isfield(opts, 'prioritySatellite')
    opts.prioritySatellite = "";
end
if ~isfield(opts, 'priorityCoverageFirst') || isempty(opts.priorityCoverageFirst)
    opts.priorityCoverageFirst = false;
end
if ~isfield(opts, 'userDemand_Mbps') || ~isfinite(opts.userDemand_Mbps)
    opts.userDemand_Mbps = 25;
end
if ~isfield(opts, 'limitPowerToDemand') || isempty(opts.limitPowerToDemand)
    opts.limitPowerToDemand = false;
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
    'ActiveBeam', {}, 'UserCount', {}, 'LoadShare', {}, 'UserDemand_Mbps', {}, ...
    'BeamDemand_Mbps', {}, 'PbeamDemandLimited_W', {}, 'PbeamRequired_W', {}, ...
    'BeamPowerSatisfaction', {}, 'EPFD_dB', {}, 'EPFD_lin', {}, ...
    'InBeam', {}, 'Elevation_deg', {}, 'PhiT_deg', {}, 'Alpha_deg', {}, ...
    'Distance_km', {}, 'BeamCenterLat_deg', {}, 'BeamCenterLon_deg', {});

satGeom = buildSatelliteBeamGeometry(root, satList, tStr, pitchOffsets_deg);
[userCountMat, userSatIdx, userBeamIdx] = assignUsersToNearestBeamCenter(satGeom, P_users_km, ...
    opts.beamHalfEW_deg, opts.beamHalfNS_deg, string(opts.prioritySatellite), opts.priorityCoverageFirst);
userDemand_bps = double(opts.userDemand_Mbps) * 1e6;
[beamRequiredPower_W, beamDemand_bps] = computeBeamDemandLimitedPower(satGeom, P_users_km, ...
    userSatIdx, userBeamIdx, userDemand_bps, P);

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

    for b = 1:Nbeam
        b_hat = b_all(:,b);
        t_axis = cross(c_axis, b_hat);
        t_axis = t_axis / max(norm(t_axis), eps);
        activeBeamNow = activeByBeam(b);
        userCountNow = userCountByBeam(b);
        loadShareNow = loadShareByBeam(b);
        beamDemandMbpsNow = beamDemand_bps(iSat,b) / 1e6;
        PbeamRequiredNow_W = beamRequiredPower_W(iSat,b);
        PbeamDemandLimitedNow_W = NaN;
        beamPowerSatisfactionNow = NaN;
        if opts.allocatePowerByUsers
            PbeamActual_W = P.Ptotal_W * loadShareNow;
            if opts.limitPowerToDemand && activeBeamNow
                PbeamDemandLimitedNow_W = min(PbeamActual_W, PbeamRequiredNow_W);
                beamPowerSatisfactionNow = min(PbeamActual_W / max(PbeamRequiredNow_W, eps), 1);
                PbeamActual_W = PbeamDemandLimitedNow_W;
            end
        else
            activeBeamNow = true;
            PbeamActual_W = Pbeam_W;
            loadShareNow = 1 / Nbeam;
            if opts.limitPowerToDemand && userCountNow > 0
                PbeamDemandLimitedNow_W = min(PbeamActual_W, PbeamRequiredNow_W);
                beamPowerSatisfactionNow = min(PbeamActual_W / max(PbeamRequiredNow_W, eps), 1);
                PbeamActual_W = PbeamDemandLimitedNow_W;
            end
        end

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

if isempty(rawRows)
    Tdetail = table();
    Tsummary = table();
    Tbackoff = table();
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

    Tdetail = table(Time, GSName, GeoName, Satellite, Plane, Beam, PowerModel, Pbeam_W_col, ...
        ActiveBeam, UserCount, LoadShare, UserDemand_Mbps, BeamDemand_Mbps, ...
        PbeamDemandLimited_W, PbeamRequired_W, BeamPowerSatisfaction, EPFD_dB, EPFD_lin, ...
        EPFD_pct_of_GeoTotal, InBeam, Elevation_deg, PhiT_deg, Alpha_deg, Distance_km, ...
        BeamCenterLat_deg, BeamCenterLon_deg, ...
        'VariableNames', {'Time','GSName','GeoName','Satellite','Plane','Beam','PowerModel','Pbeam_W', ...
        'ActiveBeam','UserCount','LoadShare','UserDemand_Mbps','BeamDemand_Mbps', ...
        'PbeamDemandLimited_W','PbeamRequired_W','BeamPowerSatisfaction', ...
        'EPFD_dB','EPFD_lin','EPFD_pct_of_GeoTotal', ...
        'InBeam','Elevation_deg','PhiT_deg','Alpha_deg','Distance_km','BeamCenterLat_deg','BeamCenterLon_deg'});

    GeoSummary = strings(0,1);
    EPFD_total_dB = nan(0,1);
    EPFD_total_lin = nan(0,1);
    N_satellites = zeros(0,1);
    N_beams = zeros(0,1);
    MaxBeamEPFD_dB = nan(0,1);
    MaxBeamSatellite = strings(0,1);
    MaxBeam = zeros(0,1);

    for j = 1:Ngeo
        geoName = char(geoList(j));
        geoMask = GeoName == string(geoName);
        [maxVal, idxLocal] = max(EPFD_lin(geoMask));
        idxAll = find(geoMask);
        idxMax = idxAll(idxLocal);

        GeoSummary(end+1,1) = string(geoName); %#ok<AGROW>
        EPFD_total_lin(end+1,1) = sum(EPFD_lin(geoMask)); %#ok<AGROW>
        EPFD_total_dB(end+1,1) = 10*log10(max(sum(EPFD_lin(geoMask)), 1e-300)); %#ok<AGROW>
        N_satellites(end+1,1) = numel(unique(Satellite(geoMask))); %#ok<AGROW>
        N_beams(end+1,1) = nnz(geoMask); %#ok<AGROW>
        MaxBeamEPFD_dB(end+1,1) = 10*log10(max(maxVal, 1e-300)); %#ok<AGROW>
        MaxBeamSatellite(end+1,1) = Satellite(idxMax); %#ok<AGROW>
        MaxBeam(end+1,1) = Beam(idxMax); %#ok<AGROW>
    end

    TimeSummary = repmat(string(tStr), numel(GeoSummary), 1);
    GSNameSummary = repmat(string(gsName), numel(GeoSummary), 1);
    Tsummary = table(TimeSummary, GSNameSummary, ...
        GeoSummary, EPFD_total_dB, EPFD_total_lin, N_satellites, N_beams, ...
        MaxBeamEPFD_dB, MaxBeamSatellite, MaxBeam, ...
        'VariableNames', {'Time','GSName','GeoName','EPFD_total_dB','EPFD_total_lin', ...
        'N_satellites','N_beams','MaxBeamEPFD_dB','MaxBeamSatellite','MaxBeam'});

    Tbackoff = buildAggregateBackoffTable(Time, GSName, GeoName, Satellite, Plane, Beam, ...
        EPFD_lin, EPFD_dB, ActiveBeam, UserCount, LoadShare, Pbeam_W_col, opts.previousBeamPowerScale);
end

excelPath = char(string(opts.excelPath));
outDir = fileparts(excelPath);
if ~isempty(outDir) && ~exist(outDir, 'dir')
    mkdir(outDir);
end
if exist(excelPath, 'file')
    delete(excelPath);
end
writetable(Tdetail, excelPath, 'Sheet', 'Detail');
writetable(Tsummary, excelPath, 'Sheet', 'Summary');
writetable(Tbackoff, excelPath, 'Sheet', 'AggregateBackoff');
fprintf('Saved beam EPFD Excel: %s\n', excelPath);
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

function [userCountMat, userSatIdx, userBeamIdx] = assignUsersToNearestBeamCenter(satGeom, P_users_km, beamHalfEW_deg, beamHalfNS_deg, prioritySatellite, priorityCoverageFirst)
Nsat = numel(satGeom);
Nbeam = size(satGeom(1).b_all, 2);
Nuser = size(P_users_km, 2);
userCountMat = zeros(Nsat, Nbeam);
userSatIdx = zeros(Nuser, 1);
userBeamIdx = zeros(Nuser, 1);
prioritySatellite = string(prioritySatellite);
prioritySatIdx = find([satGeom.satName] == prioritySatellite, 1);

for iu = 1:Nuser
    userLat = asind(P_users_km(3,iu) / max(norm(P_users_km(:,iu)), eps));
    userLon = atan2d(P_users_km(2,iu), P_users_km(1,iu));

    if priorityCoverageFirst && ~isempty(prioritySatIdx)
        [priorityBeam, ~] = bestCoveredBeamForUser(satGeom(prioritySatIdx), P_users_km(:,iu), ...
            beamHalfEW_deg, beamHalfNS_deg);
        if priorityBeam > 0
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
