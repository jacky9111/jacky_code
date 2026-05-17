function [TbeamContributionLog, TbackoffLog, TavgUserSatisfaction] = RunFullPowerAggregateShutdownSweepExcel(root, opts)
% RunFullPowerAggregateShutdownSweepExcel
% Refill every beam to fixed full power at each time slot, then greedily shut
% beams off (set power to zero) until aggregate EPFD becomes legal.
% Optional: record per-slot mean user satisfaction for selected satellites
% (nearest-subpoint assignment at tStart; shut beams -> satisfaction 0; no relay).

if nargin < 2 || isempty(opts)
    opts = struct();
end
opts = applyDefaults(root, opts);

sc = root.CurrentScenario;
here = fileparts(mfilename('fullpath'));
addpath(fullfile(here, '..', 'powertilt'));

tStart = datenum(char(string(opts.tStartStr)));
tEnd = datenum(char(string(opts.tEndStr)));
step = double(opts.stepSec) / 86400;
satList = string(opts.satList(:));
geoList = string(opts.geoList(:));
gsName = char(string(opts.gsName));
timeGrid = tStart:step:tEnd;
numSlots = numel(timeGrid);

gsLat_deg = double(opts.gsLat_deg);
gsLon_deg = double(opts.gsLon_deg);
gsAlt_km = double(opts.gsAlt_km);
P_gs_km = groundXYZFromLatLonLocal(gsLat_deg, gsLon_deg, gsAlt_km);

if opts.verbose
    fprintf('Full-power shutdown sweep start\n');
    fprintf('  GS           : %s\n', gsName);
    fprintf('  GS lat/lon   : %.3f deg, %.3f deg\n', gsLat_deg, gsLon_deg);
    fprintf('  Time range   : %s -> %s\n', char(string(opts.tStartStr)), char(string(opts.tEndStr)));
    fprintf('  Step seconds : %.0f\n', double(opts.stepSec));
    fprintf('  Slot count   : %d\n', numSlots);
    if opts.params.useEIRPDensityModel
        fprintf('  Power model  : OneWeb EIRP density %.1f dBW/4kHz (BWref %.0f Hz)\n', ...
            double(opts.params.EIRPdens_dBW_per_4kHz), double(opts.params.BWref_Hz));
    else
        fprintf('  Beam power   : %.3f W\n', double(opts.fullBeamPower_W));
    end
    fprintf('  EPFD limit   : %.2f dB\n', double(opts.params.EPFD_thr_dB));
    if opts.recordUserSatisfaction
        fprintf('  User satis.  : %s (assign at tStart, no relay)\n', strjoin(string(opts.satisfactionSatList), ', '));
    end
end

recordSatisfaction = opts.recordUserSatisfaction && ~isempty(opts.satisfactionSatList);
userSatIdx = [];
userBeamIdx = [];
userCountMat = [];
P_users_km = [];
if recordSatisfaction
    tAssignStr = datestr(tStart, 'dd mmm yyyy HH:MM:SS');
    [~, P_users_km] = userFacilitiesXYZLocal(sc, string(opts.userPrefix));
    satGeomAssign = buildSatelliteBeamGeometryLocal(root, satList, tAssignStr, opts.beamHalfNS_deg);
    [userCountMat, userSatIdx, userBeamIdx] = assignUsersToNearestBeamCenterLocal( ...
        satGeomAssign, P_users_km, opts.beamHalfEW_deg, opts.beamHalfNS_deg);
    if opts.verbose
        fprintf('  Users loaded : %d (assigned at %s)\n', size(P_users_km, 2), tAssignStr);
    end
end

backoffRows = struct('time', {}, 'geo', {}, 'shutdown_rank', {}, 'sat', {}, 'beam', {}, ...
    'beam_pfd_contribution_dB', {}, 'gs_epfd_before_dB', {}, 'gs_epfd_after_dB', {}, 'epfd_drop_dB', {});
beamRows = struct('time', {}, 'geo', {}, 'sat', {}, 'beam', {}, 'beam_pfd_contribution_dB', {}, ...
    'gs_current_epfd_dB', {}, 'initial_power_W', {}, 'final_power_W', {}, 'shut_off', {}, 'shutdown_rank', {});
satisfactionRows = struct('time', {}, 'geo', {}, 'sat', {}, 'avg_user_satisfaction', {}, 'assigned_user_count', {});

for iSlot = 1:numSlots
    t = timeGrid(iSlot);
    tStr = datestr(t, 'dd mmm yyyy HH:MM:SS');
    slotTic = tic;
    slotAggBefore_dB = NaN;
    slotAggAfter_dB = NaN;
    slotShutCount = 0;
    if opts.updateStkAnimation
        root.ExecuteCommand(['Animate * SetTime "' tStr '"']);
        if opts.animationPauseSec > 0
            pause(opts.animationPauseSec);
        end
    end
    if opts.verbose && (mod(iSlot-1, opts.logEveryNSlots) == 0 || iSlot == 1 || iSlot == numSlots)
        fprintf('[%d/%d] %s : reading STK and computing backoff...\n', iSlot, numSlots, tStr);
        drawnow;
    end
    satGeom = buildSatelliteBeamGeometryLocal(root, satList, tStr, opts.beamHalfNS_deg);
    [P_geo_all, geoNames] = buildGeoReferencePointsLocal(root, geoList, gsLon_deg, opts.useIdealGsoAtGs, tStr);
    [beamTable, threshold_lin] = buildFullPowerBeamTable(tStr, gsName, satList, satGeom, P_gs_km, P_geo_all, geoNames, opts);

    for ig = 1:numel(geoNames)
        geoMask = string(beamTable.geo) == geoNames(ig);
        Tgeo = beamTable(geoMask, :);
        if isempty(Tgeo)
            continue;
        end

        aggBefore_lin = sum(Tgeo.epfd_lin);
        aggAfter_lin = aggBefore_lin;
        shutCount = 0;
        slotAggBefore_dB = 10*log10(max(aggBefore_lin, 1e-300));

        linTol = threshold_lin * 1e-12;
        slotViolated = aggAfter_lin > threshold_lin + linTol;
        if slotViolated
            [~, order] = sort(Tgeo.epfd_lin, 'descend');
            for k = 1:numel(order)
                row = order(k);
                if aggAfter_lin <= threshold_lin + linTol
                    break;
                end
                before_lin = aggAfter_lin;
                aggAfter_lin = aggAfter_lin - Tgeo.epfd_lin(row);
                Tgeo.final_power_W(row) = 0;
                Tgeo.shut_off(row) = 1;
                Tgeo.shutdown_rank(row) = k;
                shutCount = k;

                backoffRows(end+1).time = string(tStr); %#ok<AGROW>
                backoffRows(end).geo = geoNames(ig);
                backoffRows(end).shutdown_rank = k;
                backoffRows(end).sat = Tgeo.sat(row);
                backoffRows(end).beam = Tgeo.beam(row);
                backoffRows(end).beam_pfd_contribution_dB = Tgeo.beam_pfd_contribution_dB(row);
                backoffRows(end).gs_epfd_before_dB = 10*log10(max(before_lin, 1e-300));
                backoffRows(end).gs_epfd_after_dB = 10*log10(max(aggAfter_lin, 1e-300));
                backoffRows(end).epfd_drop_dB = backoffRows(end).gs_epfd_before_dB - backoffRows(end).gs_epfd_after_dB;
            end
        end

        slotAggAfter_dB = 10*log10(max(aggAfter_lin, 1e-300));
        slotShutCount = max(slotShutCount, shutCount);

        if slotViolated && any(Tgeo.shut_off > 0)
            involvedSats = unique(string(Tgeo.sat(Tgeo.shut_off > 0)), 'stable');
            for iSatRec = 1:numel(involvedSats)
                satMask = string(Tgeo.sat) == involvedSats(iSatRec);
                Tsat = sortrows(Tgeo(satMask, :), 'beam', 'ascend');
                for r = 1:height(Tsat)
                    beamRows(end+1).time = string(tStr); %#ok<AGROW>
                    beamRows(end).geo = geoNames(ig);
                    beamRows(end).sat = Tsat.sat(r);
                    beamRows(end).beam = Tsat.beam(r);
                    beamRows(end).beam_pfd_contribution_dB = Tsat.beam_pfd_contribution_dB(r);
                    beamRows(end).gs_current_epfd_dB = 10*log10(max(aggBefore_lin, 1e-300));
                    beamRows(end).initial_power_W = Tsat.initial_power_W(r);
                    beamRows(end).final_power_W = Tsat.final_power_W(r);
                    beamRows(end).shut_off = Tsat.shut_off(r);
                    beamRows(end).shutdown_rank = Tsat.shutdown_rank(r);
                end
            end
        end

        if recordSatisfaction
            userDemand_bps = double(opts.userDemand_Mbps) * 1e6;
            satisfaction = computeUserSatisfactionNoRelayLocal( ...
                satGeom, satList, userSatIdx, userBeamIdx, userCountMat, P_users_km, Tgeo, opts.params, userDemand_bps);
            for iSatRec = 1:numel(opts.satisfactionSatList)
                satName = string(opts.satisfactionSatList(iSatRec));
                iSat = find(satList == satName, 1);
                if isempty(iSat)
                    continue;
                end
                userMask = userSatIdx == iSat;
                nAssigned = sum(userMask);
                if nAssigned > 0
                    avgSat = mean(satisfaction(userMask), 'omitnan');
                else
                    avgSat = NaN;
                end
                satisfactionRows(end+1).time = string(tStr); %#ok<AGROW>
                satisfactionRows(end).geo = geoNames(ig);
                satisfactionRows(end).sat = satName;
                satisfactionRows(end).avg_user_satisfaction = avgSat;
                satisfactionRows(end).assigned_user_count = nAssigned;
            end
        end
    end

    if opts.verbose && (mod(iSlot-1, opts.logEveryNSlots) == 0 || iSlot == 1 || iSlot == numSlots)
        fprintf('  done in %.2f s | GS EPFD %.2f -> %.2f dB | shut %d beams\n', ...
            toc(slotTic), slotAggBefore_dB, slotAggAfter_dB, slotShutCount);
        if recordSatisfaction
            for iSatRec = 1:numel(opts.satisfactionSatList)
                satName = string(opts.satisfactionSatList(iSatRec));
                rowMask = string({satisfactionRows.time})' == string(tStr) & ...
                    string({satisfactionRows.sat})' == satName;
                if any(rowMask)
                    fprintf('    %s avg user sat = %.4f (%d users)\n', satName, ...
                        satisfactionRows(find(rowMask,1)).avg_user_satisfaction, ...
                        satisfactionRows(find(rowMask,1)).assigned_user_count);
                end
            end
        end
        drawnow;
    end
end

TbeamContributionLog = struct2table(beamRows);
TbackoffLog = struct2table(backoffRows);
TavgUserSatisfaction = struct2table(satisfactionRows);

if ~isempty(TbeamContributionLog)
    TbeamContributionLog = sortrows(TbeamContributionLog, {'time','geo','sat','beam'}, {'ascend','ascend','ascend','ascend'});
end
if ~isempty(TbackoffLog)
    TbackoffLog = sortrows(TbackoffLog, {'time','geo','shutdown_rank'}, {'ascend','ascend','ascend'});
end
if ~isempty(TavgUserSatisfaction)
    TavgUserSatisfaction = sortrows(TavgUserSatisfaction, {'time','geo','sat'}, {'ascend','ascend','ascend'});
end

excelPath = char(string(opts.excelPath));
outDir = fileparts(excelPath);
if ~isempty(outDir) && ~exist(outDir, 'dir')
    mkdir(outDir);
end
if exist(excelPath, 'file')
    delete(excelPath);
end
writetable(TbeamContributionLog, excelPath, 'Sheet', 'ViolatingSat_16BeamState');
writetable(TbackoffLog, excelPath, 'Sheet', 'Backoff_Log');
if recordSatisfaction && ~isempty(TavgUserSatisfaction)
    writetable(TavgUserSatisfaction, excelPath, 'Sheet', 'AvgUserSatisfaction');
end
fprintf('Saved full-power shutdown Excel: %s\n', excelPath);
end

function opts = applyDefaults(root, opts)
sc = root.CurrentScenario;
if ~isfield(opts, 'satList') || isempty(opts.satList), error('opts.satList is required.'); end
if ~isfield(opts, 'geoList') || isempty(opts.geoList), error('opts.geoList is required.'); end
if ~isfield(opts, 'gsName') || strlength(string(opts.gsName)) == 0, error('opts.gsName is required.'); end
if ~isfield(opts, 'stepSec') || ~isfinite(opts.stepSec), opts.stepSec = 1; end
if ~isfield(opts, 'tStartStr') || strlength(string(opts.tStartStr)) == 0, opts.tStartStr = sc.StartTime; end
if ~isfield(opts, 'tEndStr') || strlength(string(opts.tEndStr)) == 0, opts.tEndStr = sc.StopTime; end
if ~isfield(opts, 'beamHalfEW_deg') || ~isfinite(opts.beamHalfEW_deg), opts.beamHalfEW_deg = 24.5; end
if ~isfield(opts, 'beamHalfNS_deg') || ~isfinite(opts.beamHalfNS_deg), opts.beamHalfNS_deg = 25/16; end
if ~isfield(opts, 'gsLat_deg') || ~isfinite(opts.gsLat_deg), opts.gsLat_deg = 0; end
if ~isfield(opts, 'gsLon_deg') || ~isfinite(opts.gsLon_deg), opts.gsLon_deg = 121; end
if ~isfield(opts, 'gsAlt_km') || ~isfinite(opts.gsAlt_km), opts.gsAlt_km = 0; end
if ~isfield(opts, 'useIdealGsoAtGs') || isempty(opts.useIdealGsoAtGs), opts.useIdealGsoAtGs = false; end
if ~isfield(opts, 'fullBeamPower_W') || ~isfinite(opts.fullBeamPower_W), opts.fullBeamPower_W = 1.05; end
if ~isfield(opts, 'verbose') || isempty(opts.verbose), opts.verbose = true; end
if ~isfield(opts, 'logEveryNSlots') || ~isfinite(opts.logEveryNSlots) || opts.logEveryNSlots < 1
    opts.logEveryNSlots = 1;
end
if ~isfield(opts, 'updateStkAnimation') || isempty(opts.updateStkAnimation), opts.updateStkAnimation = true; end
if ~isfield(opts, 'animationPauseSec') || ~isfinite(opts.animationPauseSec), opts.animationPauseSec = 0; end
opts.animationPauseSec = max(double(opts.animationPauseSec), 0);
opts.logEveryNSlots = max(1, round(double(opts.logEveryNSlots)));
if ~isfield(opts, 'excelPath') || strlength(string(opts.excelPath)) == 0
    opts.excelPath = fullfile(fileparts(mfilename('fullpath')), '..', '..', 'Matlab_data', 'FullPower_BeamShutdownSweep.xlsx');
end
if isfield(opts, 'params') && ~isempty(opts.params)
    opts.params = opts.params;
else
    opts.params = ku_epfd_params();
end
opts.params = ensureParamDefaults(opts.params);
if ~isfield(opts, 'userPrefix') || strlength(string(opts.userPrefix)) == 0
    opts.userPrefix = "User_";
end
if ~isfield(opts, 'userDemand_Mbps') || ~isfinite(opts.userDemand_Mbps)
    opts.userDemand_Mbps = 25;
end
if ~isfield(opts, 'satisfactionSatList') || isempty(opts.satisfactionSatList)
    opts.satisfactionSatList = ["P03_S01", "P03_S49", "P03_S48"];
end
opts.satisfactionSatList = string(opts.satisfactionSatList(:));
if ~isfield(opts, 'recordUserSatisfaction') || isempty(opts.recordUserSatisfaction)
    opts.recordUserSatisfaction = true;
end
end

function P = ensureParamDefaults(P)
if ~isfield(P, 'useEIRPDensityModel'), P.useEIRPDensityModel = false; end
if ~isfield(P, 'EIRPdens_dBW_per_4kHz'), P.EIRPdens_dBW_per_4kHz = -13.4; end
if ~isfield(P, 'BWref_Hz'), P.BWref_Hz = 4e4; end
if ~isfield(P, 'GSO_Gmax_dBi'), P.GSO_Gmax_dBi = 0; end
if ~isfield(P, 'A_fit'), P.A_fit = 1; end
if ~isfield(P, 'beta_fit'), P.beta_fit = 0; end
if ~isfield(P, 'GSO_D_m'), P.GSO_D_m = 1; end
if ~isfield(P, 'lambda_m'), P.lambda_m = 0.025; end
if ~isfield(P, 'EPFD_thr_dB'), P.EPFD_thr_dB = -180; end
if ~isfield(P, 'B_Hz'), P.B_Hz = 250e6; end
if ~isfield(P, 'kB'), P.kB = 1.380649e-23; end
if ~isfield(P, 'user_noise_temp_K'), P.user_noise_temp_K = 240; end
if ~isfield(P, 'GS_LEO_Gmax_dBi')
    if isfield(P, 'user_D_m') && isfield(P, 'lambda_m')
        P.GS_LEO_Gmax_dBi = 20 * log10(P.user_D_m / P.lambda_m) + 7.7;
    else
        P.GS_LEO_Gmax_dBi = 0;
    end
end
end

function [beamTable, threshold_lin] = buildFullPowerBeamTable(tStr, gsName, satList, satGeom, P_gs_km, P_geo_all, geoNames, opts)
P = opts.params;
Gmax_lin = 10^(P.GSO_Gmax_dBi/10);
Gt_max_lin = max(P.A_fit, eps);
threshold_lin = 10^(P.EPFD_thr_dB/10);
if P.useEIRPDensityModel
    eirpRef_dBW = P.EIRPdens_dBW_per_4kHz + 10*log10(P.BWref_Hz/4000);
    eirpRef_lin = 10^(eirpRef_dBW/10);
else
    eirpRef_lin = NaN;
end
rows = struct('time', {}, 'gs', {}, 'geo', {}, 'sat', {}, 'beam', {}, 'initial_power_W', {}, 'final_power_W', {}, 'epfd_lin', {}, 'beam_pfd_contribution_dB', {}, 'shut_off', {}, 'shutdown_rank', {});
for iSat = 1:numel(satList)
    satName = char(satList(iSat));
    P_leo_km = satGeom(iSat).P_leo_km;
    b_all = satGeom(iSat).b_all;
    c_axis = satGeom(iSat).c_axis;
    for b = 1:16
        b_hat = b_all(:,b);
        t_axis = cross(c_axis, b_hat);
        t_axis = t_axis / max(norm(t_axis), eps);
        v_gs_m = (P_gs_km - P_leo_km) * 1000;
        d_m = norm(v_gs_m);
        for j = 1:numel(geoNames)
            if d_m < 1
                epfdLin = 0;
                if P.useEIRPDensityModel
                    beamPower_W = NaN;
                else
                    beamPower_W = opts.fullBeamPower_W;
                end
            else
                d_hat = v_gs_m / d_m;
                phit = angleDegLocal(b_hat, d_hat);
                Gt_lin = max(P.A_fit * exp(P.beta_fit * phit), 1e-30);
                alpha = angleDegLocal(P_leo_km - P_gs_km, P_geo_all(:,j) - P_gs_km);
                Gr_dBi = gso_rx_gain_itu1428(alpha, P.GSO_D_m, P.lambda_m);
                Gr_lin = 10^(Gr_dBi/10);
                if P.useEIRPDensityModel
                    Gt_rel = Gt_lin / Gt_max_lin;
                    epfdLin = eirpRef_lin * Gt_rel * (1/(4*pi*d_m^2)) * (Gr_lin/Gmax_lin);
                    beamPower_W = NaN;
                else
                    epfdLin = (opts.fullBeamPower_W / P.BWref_Hz) * (Gt_lin/(4*pi*d_m^2)) * (Gr_lin/Gmax_lin);
                    beamPower_W = opts.fullBeamPower_W;
                end
            end
            rows(end+1).time = string(tStr); %#ok<AGROW>
            rows(end).gs = string(gsName);
            rows(end).geo = geoNames(j);
            rows(end).sat = string(satName);
            rows(end).beam = b;
            rows(end).initial_power_W = beamPower_W;
            rows(end).final_power_W = beamPower_W;
            rows(end).epfd_lin = epfdLin;
            rows(end).beam_pfd_contribution_dB = 10*log10(max(epfdLin, 1e-300));
            rows(end).shut_off = 0;
            rows(end).shutdown_rank = NaN;
        end
    end
end
beamTable = struct2table(rows);
end

function [P_geo_all, geoNames] = buildGeoReferencePointsLocal(root, geoList, gsLon_deg, useIdealGsoAtGs, tStr)
geoNames = string(geoList(:));
P_geo_all = zeros(3, numel(geoNames));
for j = 1:numel(geoNames)
    if useIdealGsoAtGs
        P_geo_all(:,j) = idealGsoXYZFromLongitudeLocal(gsLon_deg);
    else
        geoObj = root.GetObjectFromPath(['*/Satellite/' char(geoNames(j))]);
        geoDP = geoObj.DataProviders.Item('Cartesian Position').Group.Item('Fixed');
        P_geo_all(:,j) = stkXYZLocal(geoDP, tStr);
    end
end
end

function satGeom = buildSatelliteBeamGeometryLocal(root, satList, tStr, beamHalfNS_deg)
pitchOffsets_deg = (8.5 - (1:16)) * (2 * beamHalfNS_deg);
satGeom = repmat(struct('satName', "", 'P_leo_km', [], 'b_all', [], 'c_axis', [], ...
    'subLat', [], 'subLon', []), numel(satList), 1);
for iSat = 1:numel(satList)
    satName = char(satList(iSat));
    satObj = root.GetObjectFromPath(['*/Satellite/' satName]);
    posDP = satObj.DataProviders.Item('Cartesian Position').Group.Item('Fixed');
    velDP = satObj.DataProviders.Item('Cartesian Velocity').Group.Item('Fixed');
    P_leo_km = stkXYZLocal(posDP, tStr);
    V_leo_kmps = stkXYZLocal(velDP, tStr);
    [b_all, c_axis] = beamBoresightsLocal(P_leo_km*1000, V_leo_kmps*1000, pitchOffsets_deg);
    satGeom(iSat).satName = string(satName);
    satGeom(iSat).P_leo_km = P_leo_km;
    satGeom(iSat).b_all = reorderBoresightsNorthToSouthLocal(P_leo_km*1000, b_all);
    satGeom(iSat).c_axis = c_axis;
    satGeom(iSat).subLat = asind(P_leo_km(3) / max(norm(P_leo_km), eps));
    satGeom(iSat).subLon = atan2d(P_leo_km(2), P_leo_km(1));
end
end

function [b_all, c_axis] = beamBoresightsLocal(r_sat_m, v_sat_mps, pitchOffsets_deg)
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

function b_sorted = reorderBoresightsNorthToSouthLocal(r_sat_m, b_all)
Re_m = 6378137.0;
nb = size(b_all, 2);
lat_deg = -inf(1, nb);
for k = 1:nb
    hit = rayEarthIntersectLocal(r_sat_m, b_all(:,k), Re_m);
    if ~isempty(hit)
        lat_deg(k) = asind(hit(3) / max(norm(hit), eps));
    end
end
[~, idx] = sort(lat_deg, 'descend');
b_sorted = b_all(:, idx);
end

function hit = rayEarthIntersectLocal(r_s_m, d_unit, Re_m)
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
hit = r_s_m + min(cand) * d_unit;
end

function v = rodriguesLocal(u, k, ang)
v = u*cos(ang) + cross(k,u)*sin(ang) + k*dot(k,u)*(1-cos(ang));
v = v / max(norm(v), eps);
end

function P = stkXYZLocal(dp, tStr)
res = dp.ExecSingle(tStr);
P = xyzFromArrayLocal(res.DataSets.ToArray);
end

function P = facilityXYZLocal(gsObj)
res = gsObj.DataProviders.Item('Cartesian Position').Exec;
P = xyzFromArrayLocal(res.DataSets.ToArray);
end

function P_gs_km = groundXYZFromLatLonLocal(lat_deg, lon_deg, alt_km)
Re_km = 6378.137;
r_km = Re_km + alt_km;
P_gs_km = r_km * [cosd(lat_deg) * cosd(lon_deg); cosd(lat_deg) * sind(lon_deg); sind(lat_deg)];
end

function [lat_deg, lon_deg] = facilityLatLonLocal(gsObj)
res = gsObj.DataProviders.Item('LLA State').Exec;
vals = numericScalarsLocal(res.DataSets.ToArray);
lat_deg = vals(1);
lon_deg = vals(2);
end

function P_geo_km = idealGsoXYZFromLongitudeLocal(lon_deg)
R_geo_km = 42164.0;
P_geo_km = R_geo_km * [cosd(lon_deg); sind(lon_deg); 0];
end

function P = xyzFromArrayLocal(arr)
vals = numericScalarsLocal(arr);
P = vals(1:3);
end

function vals = numericScalarsLocal(arr)
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

function a = angleDegLocal(x, y)
a = acosd(max(-1, min(1, dot(x,y)/(norm(x)*norm(y)+eps))));
end

function [userNames, P_users_km] = userFacilitiesXYZLocal(sc, userPrefix)
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
    P_users_km(:,end+1) = facilityXYZLocal(fac); %#ok<AGROW>
end
if isempty(userNames)
    warning('RunFullPowerAggregateShutdownSweepExcel:NoUsers', ...
        'No user facilities found with prefix "%s".', char(userPrefix));
end
end

function [userCountMat, userSatIdx, userBeamIdx] = assignUsersToNearestBeamCenterLocal( ...
    satGeom, P_users_km, beamHalfEW_deg, beamHalfNS_deg)
Nsat = numel(satGeom);
Nbeam = size(satGeom(1).b_all, 2);
Nuser = size(P_users_km, 2);
userCountMat = zeros(Nsat, Nbeam);
userSatIdx = zeros(Nuser, 1);
userBeamIdx = zeros(Nuser, 1);

for iu = 1:Nuser
    userLat = asind(P_users_km(3,iu) / max(norm(P_users_km(:,iu)), eps));
    userLon = atan2d(P_users_km(2,iu), P_users_km(1,iu));
    bestSat = nearestSatelliteSubpointLocal(satGeom, userLat, userLon, 1:Nsat);
    [bestBeam, ~] = bestCoveredBeamForUserLocal(satGeom(bestSat), P_users_km(:,iu), ...
        beamHalfEW_deg, beamHalfNS_deg);
    if bestSat > 0 && bestBeam > 0
        userCountMat(bestSat, bestBeam) = userCountMat(bestSat, bestBeam) + 1;
        userSatIdx(iu) = bestSat;
        userBeamIdx(iu) = bestBeam;
    end
end
end

function satisfaction = computeUserSatisfactionNoRelayLocal( ...
    satGeom, satList, userSatIdx, userBeamIdx, userCountMat, P_users_km, Tgeo, P, userDemand_bps)
Nsat = numel(satList);
Nbeam = size(satGeom(1).b_all, 2);
PbeamActualMat_W = zeros(Nsat, Nbeam);
for r = 1:height(Tgeo)
    iSat = find(satList == string(Tgeo.sat(r)), 1);
    if isempty(iSat)
        continue;
    end
    b = Tgeo.beam(r);
    PbeamActualMat_W(iSat, b) = Tgeo.final_power_W(r);
end

Nuser = numel(userSatIdx);
satisfaction = zeros(Nuser, 1);
Buser = P.B_Hz;
noisePower_W = P.kB * P.user_noise_temp_K * Buser;
Gur_lin = 10^(P.GS_LEO_Gmax_dBi/10);
demandMbps = userDemand_bps / 1e6;

for iu = 1:Nuser
    iSat = userSatIdx(iu);
    b = userBeamIdx(iu);
    if iSat < 1 || b < 1
        continue;
    end
    Pbeam = PbeamActualMat_W(iSat, b);
    if ~isfinite(Pbeam) || Pbeam <= 0
        satisfaction(iu) = 0;
        continue;
    end
    channelGain = userLinkChannelGainPerWLocal(satGeom(iSat), b, P_users_km(:,iu), P, Gur_lin);
    sig = Pbeam * channelGain;
    sinr = sig / max(noisePower_W, eps);
    cinst_bps = Buser * log2(1 + sinr);
    usersInBeam = max(double(userCountMat(iSat, b)), 1);
    rate_Mbps = cinst_bps / usersInBeam / 1e6;
    satisfaction(iu) = min(rate_Mbps / max(demandMbps, eps), 1);
end
end

function channelGain = userLinkChannelGainPerWLocal(satGeomOne, beamIdx, P_user_km, P, Gur_lin)
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

function [bestBeam, bestMetric] = bestCoveredBeamForUserLocal(satGeomOne, P_user_km, beamHalfEW_deg, beamHalfNS_deg)
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

function bestSat = nearestSatelliteSubpointLocal(satGeom, userLat, userLon, candidateIdx)
bestSat = candidateIdx(1);
bestCentralAngle = inf;
for iSat = candidateIdx
    centralAngle = greatCircleDistanceDegLocal(userLat, userLon, satGeom(iSat).subLat, satGeom(iSat).subLon);
    if centralAngle < bestCentralAngle
        bestCentralAngle = centralAngle;
        bestSat = iSat;
    end
end
end

function d_deg = greatCircleDistanceDegLocal(lat1, lon1, lat2, lon2)
dlat = deg2rad(lat2 - lat1);
dlon = deg2rad(lon2 - lon1);
a = sin(dlat/2)^2 + cosd(lat1) * cosd(lat2) * sin(dlon/2)^2;
d_deg = rad2deg(2 * atan2(sqrt(a), sqrt(max(0, 1-a))));
end
