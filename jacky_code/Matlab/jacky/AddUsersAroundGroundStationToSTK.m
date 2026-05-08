function userNames = AddUsersAroundGroundStationToSTK(root, gsName, areaSide_km, numUsers, userPrefix)
% AddUsersAroundGroundStationToSTK
% 在指定地面站周圍的正方形範圍內，平均分布建立多個 user（Facility）。
%
% Inputs:
% - root: STK root object
% - gsName: 中心地面站名稱
% - areaSide_km: 正方形邊長（km），例如 100 表示 100 km x 100 km
% - numUsers: 要建立的 user 數量
% - userPrefix (optional): user 名稱前綴，預設 "<gsName>_User"
%
% Output:
% - userNames: 建立的 user 名稱（string column vector）

if nargin < 5 || strlength(string(userPrefix)) == 0
    userPrefix = string(gsName) + "_User";
end

gsName = char(string(gsName));
userPrefix = string(userPrefix);

if areaSide_km <= 0
    error('areaSide_km must be positive.');
end
if numUsers <= 0 || mod(numUsers, 1) ~= 0
    error('numUsers must be a positive integer.');
end

sc = root.CurrentScenario;
gs = sc.Children.Item(gsName);
[lat0_deg, lon0_deg] = getFacilityLatLon(gs);

% Build a staggered hex-like lattice, then apply bounded jitter.
% This keeps the density uniform while looking less "lined up".
dx_km = sqrt((areaSide_km * areaSide_km) / max(numUsers, 1));
dy_km = sqrt(3) / 2 * dx_km;
if dy_km <= 0
    dy_km = areaSide_km;
end

rows = max(1, floor(areaSide_km / dy_km) + 1);
cols = max(1, floor(areaSide_km / dx_km) + 2);

yStart_km = -areaSide_km / 2;
xStart_km = -areaSide_km / 2;
candidatePts_km = zeros(0, 2);

for ir = 1:rows
    y_km = yStart_km + (ir-1) * dy_km;
    rowShift_km = 0.5 * dx_km * mod(ir-1, 2);
    for ic = 1:cols
        x_km = xStart_km + (ic-1) * dx_km + rowShift_km;
        if x_km < -areaSide_km/2 || x_km > areaSide_km/2 || ...
                y_km < -areaSide_km/2 || y_km > areaSide_km/2
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
            if x_km < -areaSide_km/2 || x_km > areaSide_km/2 || ...
                    y_km < -areaSide_km/2 || y_km > areaSide_km/2
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
userNames = strings(0,1);

for userCount = 1:numUsers
    basePt = candidatePts_km(selectedIdx(userCount), :);
    [jx, jy] = localBoundedJitter(userCount);
    east_km = basePt(1) + jx * jitterFracX * dx_km;
    north_km = basePt(2) + jy * jitterFracY * dy_km;

    east_km = min(max(east_km, -areaSide_km/2), areaSide_km/2);
    north_km = min(max(north_km, -areaSide_km/2), areaSide_km/2);

    lat_deg = lat0_deg + north_km / 111.32;
    lonScale = cosd(lat_deg);
    if abs(lonScale) < 1e-6
        lonScale = sign(lonScale) * 1e-6;
        if lonScale == 0
            lonScale = 1e-6;
        end
    end
    lon_deg = lon0_deg + east_km / (111.32 * lonScale);

    userName = sprintf('%s_%03d', char(userPrefix), userCount);
    try
        sc.Children.Item(userName).Unload();
    catch
    end

    userObj = sc.Children.New('eFacility', userName);
    userObj.Position.AssignGeodetic(lat_deg, lon_deg, 0);
    userObj.Graphics.LabelVisible = true;

    userNames(end+1,1) = string(userName); %#ok<AGROW>
end

fprintf("Created %d users around %s within %.2f km x %.2f km\n", ...
    numel(userNames), gsName, areaSide_km, areaSide_km);
end

function [lat_deg, lon_deg] = getFacilityLatLon(facilityObj)
dpLLA = facilityObj.DataProviders.Item('LLA State');
res = dpLLA.Exec;
arr = res.DataSets.ToArray;

vals = [];
for i = 1:numel(arr)
    a = arr{i};
    if isnumeric(a) && isscalar(a)
        vals(end+1,1) = double(a); %#ok<AGROW>
    end
end

if numel(vals) < 2
    error('Failed to read facility latitude/longitude from STK.');
end

lat_deg = vals(1);
lon_deg = vals(2);
end

function [jx, jy] = localBoundedJitter(idx)
% Deterministic pseudo-random jitter in [-0.5, 0.5].
% Keeps points scattered without introducing dense local clusters.
jx = mod(idx * 0.75487766625, 1.0) - 0.5;
jy = mod(idx * 0.56984029099, 1.0) - 0.5;
end
