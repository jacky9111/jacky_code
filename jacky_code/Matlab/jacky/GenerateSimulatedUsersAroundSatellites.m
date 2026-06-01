function [userNames, P_users_km, userLat_deg, userLon_deg, scatterSatNames] = GenerateSimulatedUsersAroundSatellites( ...
    root, placementSatNames, areaSide_km, numUsersPerSatellite, tStr, userPrefix)
% GenerateSimulatedUsersAroundSatellites
% Place users on a fixed lat/lon grid around each satellite subpoint (MATLAB only).
% Same scatter pattern as AddUsersAroundSatellitesToSTK; positions do not move in time.
%
% placementSatNames: satellites used as scatter centers (e.g. leo_part)
% numUsersPerSatellite: users per placement satellite
% tStr: STK time for reading each satellite subpoint at generation

if nargin < 6 || strlength(string(userPrefix)) == 0
    userPrefix = "User_";
end
userPrefix = string(userPrefix);
placementSatNames = string(placementSatNames(:));

if isempty(placementSatNames)
    userNames = strings(0, 1);
    P_users_km = zeros(3, 0);
    userLat_deg = zeros(0, 1);
    userLon_deg = zeros(0, 1);
    scatterSatNames = strings(0, 1);
    return;
end
if areaSide_km <= 0
    error('areaSide_km must be positive.');
end
if numUsersPerSatellite <= 0 || mod(numUsersPerSatellite, 1) ~= 0
    error('numUsersPerSatellite must be a positive integer.');
end

sc = root.CurrentScenario;
tStr = resolveStkTimeStringLocal(sc, tStr);
[baseOffsets_km, ~, ~] = buildUniformScatteredOffsetsLocal(areaSide_km, numUsersPerSatellite);

userNames = strings(0, 1);
userLat_deg = zeros(0, 1);
userLon_deg = zeros(0, 1);
scatterSatNames = strings(0, 1);
globalUserCount = 0;

for iSat = 1:numel(placementSatNames)
    satName = char(placementSatNames(iSat));
    satObj = root.GetObjectFromPath(['*/Satellite/' satName]);
    [lat0_deg, lon0_deg] = getSatelliteSubpointLatLonLocal(satObj, sc, tStr);

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
        userNames(end+1, 1) = sprintf('%s%03d', userPrefix, globalUserCount); %#ok<AGROW>
        userLat_deg(end+1, 1) = lat_deg; %#ok<AGROW>
        userLon_deg(end+1, 1) = lon_deg; %#ok<AGROW>
        scatterSatNames(end+1, 1) = placementSatNames(iSat); %#ok<AGROW>
    end
end

P_users_km = zeros(3, numel(userNames));
for iu = 1:numel(userNames)
    P_users_km(:, iu) = groundXYZFromLatLonKmLocal(userLat_deg(iu), userLon_deg(iu), 0);
end
end

function [offsets_km, dx_km, dy_km] = buildUniformScatteredOffsetsLocal(areaSide_km, numUsers)
numBands = 16;
centerPull = 1.0;
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
        [jx, jy] = localBoundedJitterLocal(row);
        east_km = eastPositions_km(k) + jx * 0.18 * dx_km;
        north_km = northBase_km + jy * 0.20 * bandHeight_km;

        offsets_km(row, 1) = min(max(east_km, -effectiveSide_km/2), effectiveSide_km/2);
        offsets_km(row, 2) = min(max(north_km, -effectiveSide_km/2), effectiveSide_km/2);
    end
end
end

function [lat_deg, lon_deg] = getSatelliteSubpointLatLonLocal(satObj, sc, tStr)
dpLLA = satObj.DataProviders.Item('LLA State').Group.Item('Fixed');
try
    res = dpLLA.ExecSingle(tStr);
catch
    res = dpLLA.ExecSingle(char(sc.StartTime));
end
vals = numericScalarsLocal(res.DataSets.ToArray);
if numel(vals) < 2
    error('Failed to read satellite subpoint latitude/longitude at %s.', tStr);
end
lat_deg = vals(1);
lon_deg = vals(2);
end

function tStr = resolveStkTimeStringLocal(sc, tStrIn)
if nargin < 2 || strlength(string(tStrIn)) == 0
    tStr = char(sc.StartTime);
    return;
end
tStr = char(string(tStrIn));
if isempty(strtrim(tStr))
    tStr = char(sc.StartTime);
end
end

function P_km = groundXYZFromLatLonKmLocal(lat_deg, lon_deg, alt_km)
Re_km = 6378.137;
r_km = Re_km + alt_km;
P_km = r_km * [cosd(lat_deg) * cosd(lon_deg); cosd(lat_deg) * sind(lon_deg); sind(lat_deg)];
end

function vals = numericScalarsLocal(arr)
vals = [];
if isnumeric(arr)
    vals = double(arr(:));
    return;
end
for i = 1:numel(arr)
    a = arr{i};
    if isnumeric(a) && isscalar(a)
        vals(end+1, 1) = double(a); %#ok<AGROW>
    else
        v = str2double(string(a));
        if ~isnan(v)
            vals(end+1, 1) = v; %#ok<AGROW>
        end
    end
end
end

function [jx, jy] = localBoundedJitterLocal(idx)
jx = mod(idx * 0.75487766625, 1.0) - 0.5;
jy = mod(idx * 0.56984029099, 1.0) - 0.5;
end
