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
