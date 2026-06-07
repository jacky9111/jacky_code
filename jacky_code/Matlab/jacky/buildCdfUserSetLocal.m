function [userIds, meta] = buildCdfUserSetLocal(referenceExcelPath, userSetMode, criticalSat, geoName)
% buildCdfUserSetLocal  Canonical user_id list for fig.5 CDF (shared across methods).
% userSetMode: "home_cohort" (default, same as fig.3/4) | "all_users" | "affected_users"

if nargin < 3 || strlength(string(criticalSat)) == 0
    criticalSat = "P03_S49";
end
if nargin < 4
    geoName = "";
end
userSetMode = lower(string(userSetMode));
criticalSat = string(criticalSat);
geoName = string(geoName);

slotMeta = resolveWorstEpfdSlotLocal(referenceExcelPath, geoName);
t0 = slotMeta.t0_time;

Tpu = readtable(referenceExcelPath, 'Sheet', 'PerUser', 'TextType', 'string');
if isempty(Tpu)
    error('PerUser empty in %s', referenceExcelPath);
end
mask = string(Tpu.time) == t0;
if strlength(geoName) > 0 && ismember('geo', Tpu.Properties.VariableNames)
    mask = mask & (string(Tpu.geo) == geoName);
end
Tpu = Tpu(mask, :);
if isempty(Tpu)
    error('No PerUser rows at t0=%s in %s', char(t0), referenceExcelPath);
end

switch userSetMode
    case {"home_cohort", "record_satellite", "critical_sat_home"}
        if ~ismember('home_sat', Tpu.Properties.VariableNames)
            error('PerUser.home_sat missing in %s (required for home_cohort).', referenceExcelPath);
        end
        homeSatCol = string(Tpu.home_sat);
        userIds = unique(string(Tpu.user_id(homeSatCol == criticalSat)), 'stable');
        if isempty(userIds)
            error('No home-cohort users on %s at t0=%s.', char(criticalSat), char(t0));
        end
    case "all_users"
        userIds = unique(string(Tpu.user_id), 'stable');
    case {"affected_users", "closed_beam_affected"}
        closedBeams = closedCriticalBeamsAtSlotLocal(referenceExcelPath, t0, criticalSat, geoName);
        if isempty(closedBeams)
            error(['No closed beams on %s at t0=%s. Cannot build affected-user CDF.'], ...
                char(criticalSat), char(t0));
        end
        homeSatCol = string(Tpu.home_sat);
        homeBeamCol = double(Tpu.home_beam);
        affMask = homeSatCol == criticalSat & ismember(homeBeamCol, closedBeams);
        userIds = unique(string(Tpu.user_id(affMask)), 'stable');
        if isempty(userIds)
            error('No affected users on %s closed beams at t0=%s.', char(criticalSat), char(t0));
        end
    otherwise
        error('Unknown userSetMode: %s', char(userSetMode));
end

meta = slotMeta;
meta.user_set_mode = char(userSetMode);
meta.critical_satellite = char(criticalSat);
meta.n_users_requested = numel(userIds);
if userSetMode == "affected_users" || userSetMode == "closed_beam_affected"
    meta.closed_beams = closedBeams(:).';
end
end

function closedBeams = closedCriticalBeamsAtSlotLocal(excelPath, t0, criticalSat, geoName)
closedBeams = [];
Tbeam = readtable(excelPath, 'Sheet', 'ViolatingSat_16BeamState', 'TextType', 'string');
if isempty(Tbeam) || ~ismember('shut_off', Tbeam.Properties.VariableNames)
    return;
end
mask = string(Tbeam.time) == t0 & string(Tbeam.sat) == criticalSat;
if strlength(geoName) > 0 && ismember('geo', Tbeam.Properties.VariableNames)
    mask = mask & (string(Tbeam.geo) == geoName);
end
Tbeam = Tbeam(mask, :);
if isempty(Tbeam)
    return;
end
shutCol = double(Tbeam.shut_off);
closedBeams = unique(double(Tbeam.beam(shutCol > 0.5)), 'stable');
end
