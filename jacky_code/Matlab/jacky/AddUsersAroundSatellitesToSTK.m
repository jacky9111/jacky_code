function userNames = AddUsersAroundSatellitesToSTK(root, satNames, areaSide_km, numUsersPerSatellite, tStr)
% AddUsersAroundSatellitesToSTK
% 以每顆衛星在指定時間的子星點為中心，在 areaSide_km x areaSide_km
% 的正方形範圍內平均分散建立 user（以 STK Facility 表示）。
%
% Inputs:
% - root: STK root object
% - satNames: 衛星名稱陣列，例如 ["P02_S01","P02_S02"]
% - areaSide_km: 每顆衛星的 user 分布邊長（km）
% - numUsersPerSatellite: 每顆衛星要建立的 user 數量
% - tStr (optional): STK 時間字串；未提供時使用 CurrentScenario.StartTime
%
% Output:
% - userNames: 所有建立的 user 名稱（string column vector）

sc = root.CurrentScenario;
if nargin < 5
    tStr = resolveStkTimeString(sc);
else
    tStr = resolveStkTimeString(sc, tStr);
end
satNames = string(satNames(:));

if isempty(satNames)
    userNames = strings(0,1);
    return;
end
if areaSide_km <= 0
    error('areaSide_km must be positive.');
end
if numUsersPerSatellite <= 0 || mod(numUsersPerSatellite, 1) ~= 0
    error('numUsersPerSatellite must be a positive integer.');
end

[baseOffsets_km, dx_km, dy_km] = buildUniformScatteredOffsets(areaSide_km, numUsersPerSatellite);
userNames = strings(0,1);
globalUserCount = 0;
deleteExistingUsers(sc, "User_");

for iSat = 1:numel(satNames)
    satName = char(satNames(iSat));
    satObj = root.GetObjectFromPath(['*/Satellite/' satName]);
    [lat0_deg, lon0_deg] = getSatelliteSubpointLatLon(satObj, sc, tStr);

    for k = 1:size(baseOffsets_km, 1)
        east_km = baseOffsets_km(k, 1);
        north_km = baseOffsets_km(k, 2);

        lat_deg = lat0_deg + north_km / 111.32;
        lonScale = cosd(lat_deg);
        if abs(lonScale) < 1e-6
            lonScale = sign(lonScale) * 1e-6;
            if lonScale == 0
                lonScale = 1e-6;
            end
        end
        lon_deg = lon0_deg + east_km / (111.32 * lonScale);

        globalUserCount = globalUserCount + 1;
        userName = sprintf('User_%03d', globalUserCount);
        userObj = sc.Children.New('eFacility', userName);
        userObj.Position.AssignGeodetic(lat_deg, lon_deg, 0);
        userObj.Graphics.LabelVisible = true;

        userNames(end+1,1) = string(userName); %#ok<AGROW>
    end

    fprintf("Created %d users for %s at %s within %.2f km x %.2f km (spacing %.2f / %.2f km)\n", ...
        numUsersPerSatellite, satName, tStr, areaSide_km, areaSide_km, dx_km, dy_km);
end
end

function deleteExistingUsers(sc, userPrefix)
facs = sc.Children.GetElements('eFacility');
toDelete = strings(0,1);
for k = 0:int32(facs.Count-1)
    fac = facs.Item(k);
    facName = string(fac.InstanceName);
    if startsWith(facName, userPrefix)
        toDelete(end+1,1) = facName; %#ok<AGROW>
    end
end

for k = 1:numel(toDelete)
    try
        sc.Children.Item(char(toDelete(k))).Unload();
    catch
    end
end
end

function [offsets_km, dx_km, dy_km] = buildUniformScatteredOffsets(areaSide_km, numUsers)
% Balance users across the 16 north-south beam bands first, then spread each
% band in the east-west direction. This keeps per-beam loads much flatter.
numBands = 16;
centerPull = 0.88;
effectiveSide_km = areaSide_km * centerPull;
bandHeight_km = effectiveSide_km / numBands;
dy_km = bandHeight_km;

basePerBand = floor(numUsers / numBands);
extraUsers = mod(numUsers, numBands);
usersPerBand = repmat(basePerBand, numBands, 1);
if extraUsers > 0
    extraBands = round(linspace(1, numBands, extraUsers));
    usersPerBand(extraBands) = usersPerBand(extraBands) + 1;
end

offsets_km = zeros(numUsers, 2);
row = 0;
maxUsersInBand = max(usersPerBand);
dx_km = effectiveSide_km / max(maxUsersInBand, 1);

for band = 1:numBands
    nBandUsers = usersPerBand(band);
    if nBandUsers <= 0
        continue;
    end

    northBase_km = effectiveSide_km / 2 - (band - 0.5) * bandHeight_km;
    if nBandUsers == 1
        % One user in this beam band: rotate its east-west position by band
        % so sparse bands do not all sit near the center line.
        eastPositions_km = -effectiveSide_km/2 + effectiveSide_km * mod((band - 1) * 0.61803398875 + 0.5, 1);
    else
        eastPositions_km = linspace(-effectiveSide_km/2, effectiveSide_km/2, nBandUsers + 2);
        eastPositions_km = eastPositions_km(2:end-1);
        if mod(band, 2) == 0
            eastPositions_km = fliplr(eastPositions_km);
        end
    end

    for k = 1:nBandUsers
        row = row + 1;
        [jx, jy] = localBoundedJitter(row);
        east_km = eastPositions_km(k) + jx * 0.18 * dx_km;
        north_km = northBase_km + jy * 0.20 * bandHeight_km;

        offsets_km(row, 1) = min(max(east_km, -effectiveSide_km/2), effectiveSide_km/2);
        offsets_km(row, 2) = min(max(north_km, -effectiveSide_km/2), effectiveSide_km/2);
    end
end
end

function [lat_deg, lon_deg] = getSatelliteSubpointLatLon(satObj, sc, tStr)
dpLLA = satObj.DataProviders.Item('LLA State').Group.Item('Fixed');
try
    res = dpLLA.ExecSingle(tStr);
catch
    % Fallback to scenario start time when the provided time is not accepted by STK.
    res = dpLLA.ExecSingle(char(sc.StartTime));
end
vals = numericScalars(res.DataSets.ToArray);
if numel(vals) < 2
    error('Failed to read satellite subpoint latitude/longitude at %s.', tStr);
end
lat_deg = vals(1);
lon_deg = vals(2);
end

function tStr = resolveStkTimeString(sc, tStrIn)
if nargin < 2 || strlength(string(tStrIn)) == 0
    tStr = char(sc.StartTime);
    return;
end

tStr = char(string(tStrIn));
if isempty(strtrim(tStr))
    tStr = char(sc.StartTime);
end
end

function vals = numericScalars(arr)
vals = [];
if isnumeric(arr)
    vals = double(arr(:));
    return;
end

for i = 1:numel(arr)
    a = arr{i};
    if isnumeric(a) && isscalar(a)
        vals(end+1,1) = double(a); %#ok<AGROW>
    else
        v = str2double(string(a));
        if ~isnan(v)
            vals(end+1,1) = v; %#ok<AGROW>
        end
    end
end
end

function [jx, jy] = localBoundedJitter(idx)
jx = mod(idx * 0.75487766625, 1.0) - 0.5;
jy = mod(idx * 0.56984029099, 1.0) - 0.5;
end
