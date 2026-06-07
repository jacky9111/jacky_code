function [sat, meta] = loadUserSatisfactionForUserSetLocal(excelPath, sourceType, t0, userIds, geoName)
% loadUserSatisfactionForUserSetLocal  Satisfaction vector aligned to userIds (NaN if missing).

excelPath = char(string(excelPath));
t0 = string(t0);
userIds = string(userIds(:));
if nargin < 5
    geoName = "";
end
geoName = string(geoName);

switch lower(string(sourceType))
    case "fullpower"
        sheetName = 'PerUser';
        satCol = 'user_satisfaction';
        idCol = 'user_id';
    case {"ku16_pc_tilt", "ku16", "pc_tilt"}
        sheetName = 'PerUser';
        satCol = 'satisfaction';
        idCol = 'user_id';
    otherwise
        error('Unknown sourceType: %s', char(sourceType));
end

T = readtable(excelPath, 'Sheet', sheetName, 'TextType', 'string');
if isempty(T)
    error('Sheet %s empty in %s', sheetName, excelPath);
end
if ~ismember(satCol, T.Properties.VariableNames) || ~ismember(idCol, T.Properties.VariableNames)
    error('Required columns missing in %s (%s).', excelPath, sheetName);
end

mask = string(T.time) == t0;
if strlength(geoName) > 0 && ismember('geo', T.Properties.VariableNames)
    mask = mask & (string(T.geo) == geoName);
end
T = T(mask, :);

uidRows = string(T.(idCol));
satRows = double(T.(satCol));
uidToSat = containers.Map('KeyType', 'char', 'ValueType', 'double');
for k = 1:numel(uidRows)
    key = char(uidRows(k));
    if ~isKey(uidToSat, key)
        uidToSat(key) = satRows(k);
    end
end

sat = nan(numel(userIds), 1);
for k = 1:numel(userIds)
    key = char(userIds(k));
    if isKey(uidToSat, key)
        sat(k) = uidToSat(key);
    end
end

meta = struct();
meta.n_found = sum(isfinite(sat));
meta.n_missing = sum(~isfinite(sat));
meta.coverage = meta.n_found / max(numel(userIds), 1);
end
