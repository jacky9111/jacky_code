function satNames = GetStkSatelliteNamesByPlane(root, planeIds, namePrefixes)
% GetStkSatelliteNamesByPlane
% Read satellite names directly from the current STK scenario and keep only
% satellites that belong to the requested orbital planes.
%
% Inputs:
% - root: STK root object
% - planeIds: numeric array, e.g. [1 2 3]
% - namePrefixes (optional): string array, e.g. ["P","I"]
%
% Output:
% - satNames: string column vector of matched satellite names
%
% 【中文說明】直接從目前的 STK 場景讀出所有衛星名稱，只留下屬於指定軌道面的那些。
% 比起沿用建星函式的回傳值，這樣做的好處是：即使場景是先前存檔載入的
% （沒有跑過 CreateWalkerConstellation_HPOP），也能正確取得衛星清單。
%
% 比對方式：名稱開頭符合 <前綴><兩位數軌道面編號>_，例如 planeIds=[3] 會抓到
% P03_S01 ~ P03_S49。前綴預設 ["P","I"]（P=極軌面、I=傾斜面命名習慣）。

if nargin < 2 || isempty(planeIds)
    satNames = strings(0,1);
    return;
end

if nargin < 3 || isempty(namePrefixes)
    namePrefixes = ["P","I"];
end

planeIds = unique(reshape(double(planeIds), 1, []));
namePrefixes = string(namePrefixes);

sc = root.CurrentScenario;
sats = sc.Children.GetElements('eSatellite');

allSatNames = strings(0,1);
for k = 0:int32(sats.Count-1)
    satObj = sats.Item(k);
    allSatNames(end+1,1) = string(satObj.InstanceName); %#ok<AGROW>
end

if isempty(allSatNames)
    satNames = strings(0,1);
    return;
end

mask = false(size(allSatNames));
for kp = 1:numel(planeIds)
    for kn = 1:numel(namePrefixes)
        mask = mask | startsWith(allSatNames, sprintf('%s%02d_', char(namePrefixes(kn)), planeIds(kp)));
    end
end

satNames = allSatNames(mask);
satNames = satNames(:);
end
