function fig = PlotOffloadingResultPlanarMap(root, satNames, gsName, areaSide_km, tStr, userPrefix, offloadExcelPath)
if nargin < 6 || strlength(string(userPrefix)) == 0
    userPrefix = "User_";
end
if nargin < 7
    offloadExcelPath = "";
end

sc = root.CurrentScenario;
satNames = string(satNames(:));
gsName = char(string(gsName));
tStr = char(string(tStr));
[userLon_deg, userLat_deg, userNames] = getUsersLatLonLocal(sc, string(userPrefix));
[gsLat_deg, gsLon_deg] = getFacilityLatLonLocal(root.GetObjectFromPath(['*/Facility/' gsName]));
[satLon_deg, satLat_deg, satLabels, satPlaneLabels] = getSatelliteSubpointsLocal(root, satNames, tStr);
[rectLonMat_deg, rectLatMat_deg] = getSatelliteRectanglesLocal(satLat_deg, satLon_deg, areaSide_km);
[trackLonCells, trackLatCells, trackLabels] = getExtendedPlaneTracksLocal(satLon_deg, satLat_deg, satPlaneLabels, rectLonMat_deg(:), rectLatMat_deg(:), userLon_deg, userLat_deg, gsLon_deg, gsLat_deg);
Toutcome = loadSourceOutcomeTable(offloadExcelPath);

fig = figure('Name', 'Offloading Result Planar Map', 'Color', 'w');
hold on;
grid on;
box on;

satColors = lines(max(numel(satLabels), 1));
for kSat = 1:numel(satLabels)
    rectLon_deg = rectLonMat_deg(kSat,:);
    rectLat_deg = rectLatMat_deg(kSat,:);
    [bandLonCells, bandLatCells] = getRectangleBandsLocal(rectLon_deg, rectLat_deg, 16);
    satColor = satColors(kSat,:);
    patch('XData', rectLon_deg([1 2 3 4 1]), 'YData', rectLat_deg([1 2 3 4 1]), ...
        'FaceColor', satColor, 'FaceAlpha', 0.03, 'EdgeColor', satColor, 'LineStyle', '-', 'LineWidth', 0.8, ...
        'DisplayName', sprintf('%s field', satLabels(kSat)));
    for kBand = 1:numel(bandLonCells)
        plot(bandLonCells{kBand}, bandLatCells{kBand}, '--', 'Color', satColor, 'LineWidth', 0.6, 'HandleVisibility', 'off');
    end
end

for k = 1:numel(trackLonCells)
    plot(trackLonCells{k}, trackLatCells{k}, '-', 'Color', 'k', 'LineWidth', 1.0, 'DisplayName', sprintf('%s ground track', trackLabels(k)));
end

plotTransferredUsers(userLon_deg, userLat_deg, userNames, Toutcome, satLabels, satColors);

for kSat = 1:numel(satLabels)
    scatter(satLon_deg(kSat), satLat_deg(kSat), 52, 'Marker', 'o', 'MarkerEdgeColor', satColors(kSat,:), 'MarkerFaceColor', satColors(kSat,:), ...
        'DisplayName', sprintf('%s satellite', satLabels(kSat)));
    text(satLon_deg(kSat) + 0.25, satLat_deg(kSat) + 0.18, satLabels(kSat), 'FontSize', 12, 'Color', [0.10 0.10 0.10], 'Interpreter', 'none');
end

plot(gsLon_deg, gsLat_deg, 'p', 'MarkerSize', 14, 'MarkerFaceColor', [0.93 0.69 0.13], 'MarkerEdgeColor', 'k', 'DisplayName', 'GS');
text(gsLon_deg + 0.25, gsLat_deg + 0.20, "GS", 'FontSize', 9, 'FontWeight', 'bold', 'Interpreter', 'none');

xlabel('Longitude (deg)');
ylabel('Latitude (deg)');
title(sprintf('Offloading Result Planar Map at %s', tStr), 'Interpreter', 'none');
legend('Location', 'best');

allLon = [userLon_deg(:); gsLon_deg; rectLonMat_deg(:); satLon_deg(:)];
allLat = [userLat_deg(:); gsLat_deg; rectLatMat_deg(:); satLat_deg(:)];
for k = 1:numel(trackLonCells)
    allLon = [allLon; trackLonCells{k}(:)]; %#ok<AGROW>
    allLat = [allLat; trackLatCells{k}(:)]; %#ok<AGROW>
end
if ~isempty(allLon) && ~isempty(allLat)
    lonPad = max(0.5, 0.05 * max(allLon) - 0.05 * min(allLon));
    latPad = max(0.5, 0.05 * max(allLat) - 0.05 * min(allLat));
    xlim([min(allLon)-lonPad, max(allLon)+lonPad]);
    ylim([min(allLat)-latPad, max(allLat)+latPad]);
end
end

function plotTransferredUsers(userLon_deg, userLat_deg, userNames, Toutcome, satLabels, satColors)
if isempty(Toutcome) || height(Toutcome) == 0
    return;
end
userMap = containers.Map('KeyType', 'char', 'ValueType', 'char');
for i = 1:height(Toutcome)
    userMap(char(string(Toutcome.user_id(i)))) = char(string(Toutcome.final_sat(i)));
end
for kSat = 1:numel(satLabels)
    mask = false(numel(userNames), 1);
    for iu = 1:numel(userNames)
        key = char(userNames(iu));
        if isKey(userMap, key)
            mask(iu) = strcmp(userMap(key), char(satLabels(kSat)));
        end
    end
    if any(mask)
        scatter(userLon_deg(mask), userLat_deg(mask), 24, 'filled', 'MarkerFaceColor', satColors(kSat,:), 'MarkerEdgeColor', satColors(kSat,:), ...
            'MarkerFaceAlpha', 0.80, 'DisplayName', sprintf('%s outcome users', satLabels(kSat)));
    end
end
end

function Toutcome = loadSourceOutcomeTable(offloadExcelPath)
Toutcome = table();
if strlength(string(offloadExcelPath)) == 0
    return;
end
excelPath = char(string(offloadExcelPath));
if ~exist(excelPath, 'file')
    return;
end
try
    Toutcome = readtable(excelPath, 'Sheet', 'Original_Source_User_Outcome');
catch
    Toutcome = table();
end
end

function [userLon_deg, userLat_deg, userNames] = getUsersLatLonLocal(sc, userPrefix)
facs = sc.Children.GetElements('eFacility');
userLon_deg = [];
userLat_deg = [];
userNames = strings(0,1);
for k = 0:int32(facs.Count-1)
    fac = facs.Item(k);
    facName = string(fac.InstanceName);
    if ~startsWith(facName, userPrefix)
        continue;
    end
    [lat_deg, lon_deg] = getFacilityLatLonLocal(fac);
    userLon_deg(end+1,1) = lon_deg; %#ok<AGROW>
    userLat_deg(end+1,1) = lat_deg; %#ok<AGROW>
    userNames(end+1,1) = facName; %#ok<AGROW>
end
end

function [rectLon_deg, rectLat_deg] = getCenteredRectangleLocal(centerLat_deg, centerLon_deg, areaSide_km)
halfSide_km = areaSide_km / 2;
dLat_deg = halfSide_km / 111.32;
lonScale = cosd(centerLat_deg);
if abs(lonScale) < 1e-6
    lonScale = 1e-6;
end
dLon_deg = halfSide_km / (111.32 * lonScale);
rectLon_deg = [centerLon_deg - dLon_deg, centerLon_deg + dLon_deg, centerLon_deg + dLon_deg, centerLon_deg - dLon_deg];
rectLat_deg = [centerLat_deg - dLat_deg, centerLat_deg - dLat_deg, centerLat_deg + dLat_deg, centerLat_deg + dLat_deg];
end

function [rectLonMat_deg, rectLatMat_deg] = getSatelliteRectanglesLocal(satLat_deg, satLon_deg, areaSide_km)
rectLonMat_deg = zeros(numel(satLat_deg), 4);
rectLatMat_deg = zeros(numel(satLat_deg), 4);
for k = 1:numel(satLat_deg)
    [rectLon_deg, rectLat_deg] = getCenteredRectangleLocal(satLat_deg(k), satLon_deg(k), areaSide_km);
    rectLonMat_deg(k,:) = rectLon_deg;
    rectLatMat_deg(k,:) = rectLat_deg;
end
end

function [bandLonCells, bandLatCells] = getRectangleBandsLocal(rectLon_deg, rectLat_deg, numBands)
bandLonCells = {};
bandLatCells = {};
latEdges = linspace(min(rectLat_deg), max(rectLat_deg), numBands + 1);
for k = 2:numBands
    bandLonCells{end+1,1} = [min(rectLon_deg), max(rectLon_deg)]; %#ok<AGROW>
    bandLatCells{end+1,1} = [latEdges(k), latEdges(k)]; %#ok<AGROW>
end
end

function [trackLonCells, trackLatCells, trackLabels] = getExtendedPlaneTracksLocal(satLon_deg, satLat_deg, satPlaneLabels, rectLon_deg, rectLat_deg, userLon_deg, userLat_deg, gsLon_deg, gsLat_deg)
trackLonCells = {};
trackLatCells = {};
trackLabels = strings(0,1);
planeLabels = unique(satPlaneLabels, 'stable');
lonMin = min([rectLon_deg(:); userLon_deg(:); gsLon_deg; satLon_deg(:)]) - 1.0;
lonMax = max([rectLon_deg(:); userLon_deg(:); gsLon_deg; satLon_deg(:)]) + 1.0;
latMin = min([rectLat_deg(:); userLat_deg(:); gsLat_deg; satLat_deg(:)]) - 1.0;
latMax = max([rectLat_deg(:); userLat_deg(:); gsLat_deg; satLat_deg(:)]) + 1.0;
for iPlane = 1:numel(planeLabels)
    mask = satPlaneLabels == planeLabels(iPlane);
    x = satLon_deg(mask);
    y = satLat_deg(mask);
    if numel(x) < 2
        continue;
    end
    spanY = max(y) - min(y);
    spanX = max(x) - min(x);
    if spanY >= spanX
        p = polyfit(y, x, 1);
        yLine = linspace(latMin, latMax, 200);
        xLine = polyval(p, yLine);
    else
        p = polyfit(x, y, 1);
        xLine = linspace(lonMin, lonMax, 200);
        yLine = polyval(p, xLine);
    end
    inMask = xLine >= lonMin & xLine <= lonMax & yLine >= latMin & yLine <= latMax;
    trackLonCells{end+1,1} = xLine(inMask); %#ok<AGROW>
    trackLatCells{end+1,1} = yLine(inMask); %#ok<AGROW>
    trackLabels(end+1,1) = planeLabels(iPlane); %#ok<AGROW>
end
end

function [satLon_deg, satLat_deg, satLabels, satPlaneLabels] = getSatelliteSubpointsLocal(root, satNames, tStr)
satLon_deg = zeros(numel(satNames), 1);
satLat_deg = zeros(numel(satNames), 1);
satLabels = strings(numel(satNames), 1);
satPlaneLabels = strings(numel(satNames), 1);
for i = 1:numel(satNames)
    satName = satNames(i);
    satObj = root.GetObjectFromPath(['*/Satellite/' char(satName)]);
    [lat_deg, lon_deg] = getSatelliteSubpointLatLonLocal(satObj, tStr);
    satLon_deg(i) = lon_deg;
    satLat_deg(i) = lat_deg;
    satLabels(i) = satName;
    parts = split(satName, "_");
    satPlaneLabels(i) = parts(1);
end
end

function [lat_deg, lon_deg] = getSatelliteSubpointLatLonLocal(satObj, tStr)
dpLLA = satObj.DataProviders.Item('LLA State').Group.Item('Fixed');
res = dpLLA.ExecSingle(tStr);
vals = numericScalarsLocal(res.DataSets.ToArray);
lat_deg = vals(1);
lon_deg = vals(2);
end

function [lat_deg, lon_deg] = getFacilityLatLonLocal(facilityObj)
dpLLA = facilityObj.DataProviders.Item('LLA State');
res = dpLLA.Exec;
vals = numericScalarsLocal(res.DataSets.ToArray);
lat_deg = vals(1);
lon_deg = vals(2);
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
        vals(end+1,1) = double(a); %#ok<AGROW>
    else
        v = str2double(string(a));
        if ~isnan(v)
            vals(end+1,1) = v; %#ok<AGROW>
        end
    end
end
end
