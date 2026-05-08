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
        try
            sc.Children.Item(userName).Unload();
        catch
        end

        userObj = sc.Children.New('eFacility', userName);
        userObj.Position.AssignGeodetic(lat_deg, lon_deg, 0);
        userObj.Graphics.LabelVisible = true;

        userNames(end+1,1) = string(userName); %#ok<AGROW>
    end

    fprintf("Created %d users for %s at %s within %.2f km x %.2f km (spacing %.2f / %.2f km)\n", ...
        numUsersPerSatellite, satName, tStr, areaSide_km, areaSide_km, dx_km, dy_km);
end
end

function [offsets_km, dx_km, dy_km] = buildUniformScatteredOffsets(areaSide_km, numUsers)
% Staggered hex-like lattice + bounded jitter:
% keeps spacing nearly uniform while looking visually interleaved.
centerPull = 0.80;
effectiveSide_km = areaSide_km * centerPull;
dx_km = sqrt((effectiveSide_km * effectiveSide_km) / max(numUsers, 1));
dy_km = sqrt(3) / 2 * dx_km;
if dy_km <= 0
    dy_km = effectiveSide_km;
end

rows = max(1, floor(effectiveSide_km / dy_km) + 1);
cols = max(1, floor(effectiveSide_km / dx_km) + 2);
yStart_km = -effectiveSide_km / 2;
xStart_km = -effectiveSide_km / 2;
candidatePts_km = zeros(0, 2);

for ir = 1:rows
    y_km = yStart_km + (ir-1) * dy_km;
    rowShift_km = 0.5 * dx_km * mod(ir-1, 2);
    for ic = 1:cols
        x_km = xStart_km + (ic-1) * dx_km + rowShift_km;
        if x_km < -effectiveSide_km/2 || x_km > effectiveSide_km/2 || ...
                y_km < -effectiveSide_km/2 || y_km > effectiveSide_km/2
            continue;
        end
        candidatePts_km(end+1,:) = [x_km, y_km]; %#ok<AGROW>
    end
end

if size(candidatePts_km, 1) < numUsers
    extraCols = cols + 2;
    for ir = 1:rows
        y_km = yStart_km + (ir-1) * dy_km;
        rowShift_km = 0.5 * dx_km * mod(ir, 2);
        for ic = 1:extraCols
            x_km = xStart_km + (ic-1) * dx_km + rowShift_km;
            if x_km < -effectiveSide_km/2 || x_km > effectiveSide_km/2 || ...
                    y_km < -effectiveSide_km/2 || y_km > effectiveSide_km/2
                continue;
            end
            candidatePts_km(end+1,:) = [x_km, y_km]; %#ok<AGROW>
        end
    end
    candidatePts_km = unique(round(candidatePts_km, 9), 'rows', 'stable');
end

selectedIdx = round(linspace(1, size(candidatePts_km, 1), numUsers));
jitterFracX = 0.22;
jitterFracY = 0.22;
offsets_km = zeros(numUsers, 2);

for k = 1:numUsers
    basePt = candidatePts_km(selectedIdx(k), :);
    [jx, jy] = localBoundedJitter(k);
    east_km = basePt(1) + jx * jitterFracX * dx_km;
    north_km = basePt(2) + jy * jitterFracY * dy_km;

    offsets_km(k, 1) = min(max(east_km, -effectiveSide_km/2), effectiveSide_km/2);
    offsets_km(k, 2) = min(max(north_km, -effectiveSide_km/2), effectiveSide_km/2);
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
