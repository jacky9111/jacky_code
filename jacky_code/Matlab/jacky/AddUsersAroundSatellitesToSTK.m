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
%
% 【用途說明】這支只負責「在 STK 場景裡把 user 畫出來」，方便肉眼檢查覆蓋關係。
% Evaluation 的模擬本身走 opts.useSimulatedUsers = true，
% 由 GenerateSimulatedUsersAroundSatellites 在 MATLAB 內部生成同樣分佈的 user，
% 不依賴 STK Facility，所以這支就算跳過也不影響論文數據。

satNames = string(satNames(:));
if nargin < 5
    tStr = [];
end

% 取得目前 STK 場景；未指定時間則用場景起始時間讀取子星點
sc = root.CurrentScenario;
if isempty(sc)
    error('AddUsersAroundSatellitesToSTK:NoScenario', 'No current STK scenario.');
end
if isempty(tStr) || strlength(string(tStr)) == 0
    tStr = char(sc.StartTime);
end
tStr = char(string(tStr));

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

deleteExistingUsers(sc, "User_");   % 先清掉上一次跑剩下的 User_* facility，避免重複堆積
% 用與模擬完全相同的灑點演算法算出經緯度，確保 STK 畫面與 MATLAB 內部一致
[userNames, ~, userLat_deg, userLon_deg, ~] = GenerateSimulatedUsersAroundSatellites( ...
    root, satNames, areaSide_km, numUsersPerSatellite, tStr, "User_");

% 逐一在 STK 建立 Facility 物件（僅供視覺化）
for iu = 1:numel(userNames)
    userName = char(userNames(iu));
    userObj = sc.Children.New('eFacility', userName);
    userObj.Position.AssignGeodetic(userLat_deg(iu), userLon_deg(iu), 0);
    userObj.Graphics.LabelVisible = true;
end

for iSat = 1:numel(satNames)
    fprintf("Created %d users for %s at %s within %.2f km x %.2f km\n", ...
        numUsersPerSatellite, char(satNames(iSat)), tStr, areaSide_km, areaSide_km);
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
