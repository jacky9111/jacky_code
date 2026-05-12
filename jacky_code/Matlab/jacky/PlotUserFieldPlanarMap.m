function fig = PlotUserFieldPlanarMap(root, satNames, gsName, areaSide_km, tStr, userPrefix, epfdExcelPath)
% PlotUserFieldPlanarMap
% Draw a longitude-latitude planar view of:
% - users (points)
% - GS (star)
% - long plane lines fitted from satellite subpoints
% - satellite subpoints and labels
% - satellite-subpoint-centered user field rectangles split into 16 bands

if nargin < 6 || strlength(string(userPrefix)) == 0
    userPrefix = "User_";
end
if nargin < 7
    epfdExcelPath = "";
end

sc = root.CurrentScenario;
if nargin < 5 || strlength(string(tStr)) == 0
    tStr = char(sc.StartTime);
else
    tStr = char(string(tStr));
end

satNames = string(satNames(:));
userPrefix = string(userPrefix);
epfdExcelPath = string(epfdExcelPath);
gsName = char(string(gsName));

[userLon_deg, userLat_deg] = getUsersLatLon(sc, userPrefix);
[gsLat_deg, gsLon_deg] = getFacilityLatLon(root.GetObjectFromPath(['*/Facility/' gsName]));
[satLon_deg, satLat_deg, satLabels, satPlaneLabels] = getSatelliteSubpoints(root, satNames, tStr);
[rectLonMat_deg, rectLatMat_deg] = getSatelliteRectangles(satLat_deg, satLon_deg, areaSide_km);
[trackLonCells, trackLatCells, trackLabels] = getExtendedPlaneTracks( ...
    satLon_deg, satLat_deg, satPlaneLabels, rectLonMat_deg(:), rectLatMat_deg(:), userLon_deg, userLat_deg, gsLon_deg, gsLat_deg);
Tsystem = loadSystemStateTable(epfdExcelPath);
Tdistress = loadBeamDistressScoreTable(epfdExcelPath);
Tuser = loadUserStateTable(epfdExcelPath);

fig = figure('Name', 'User Field Planar Map', 'Color', 'w');
hold on;
grid on;
box on;

rectColors = lines(max(numel(satLabels), 1));
for kSat = 1:numel(satLabels)
    rectLon_deg = rectLonMat_deg(kSat,:);
    rectLat_deg = rectLatMat_deg(kSat,:);
    [bandLonCells, bandLatCells] = getRectangleBands(rectLon_deg, rectLat_deg, 16);
    rectColor = rectColors(kSat,:);

    patch('XData', rectLon_deg([1 2 3 4 1]), ...
        'YData', rectLat_deg([1 2 3 4 1]), ...
        'FaceColor', rectColor, 'FaceAlpha', 0.035, ...
        'EdgeColor', rectColor, 'LineStyle', '-', 'LineWidth', 0.8, ...
        'DisplayName', sprintf('%s field', satLabels(kSat)));

    for kBand = 1:numel(bandLonCells)
        plot(bandLonCells{kBand}, bandLatCells{kBand}, '--', ...
            'Color', rectColor, 'LineWidth', 0.6, 'HandleVisibility', 'off');
    end
end

annotateBeamDistressLabels(Tdistress, satLabels, rectLonMat_deg, rectLatMat_deg, rectColors);

for k = 1:numel(trackLonCells)
    plot(trackLonCells{k}, trackLatCells{k}, '-', ...
        'Color', 'k', 'LineWidth', 1.0, ...
        'DisplayName', sprintf('%s ground track', trackLabels(k)));
end

plotUsersByServingSatellite(userLon_deg, userLat_deg, Tuser, satLabels, rectColors);

if ~isempty(satLon_deg)
    planeU = unique(satPlaneLabels, 'stable');
    for iPlane = 1:numel(planeU)
        mask = satPlaneLabels == planeU(iPlane);
        scatter(satLon_deg(mask), satLat_deg(mask), 52, ...
            'Marker', 'o', 'MarkerEdgeColor', rectColors(find(mask, 1),:), ...
            'MarkerFaceColor', rectColors(find(mask, 1),:), ...
            'DisplayName', sprintf('%s satellites', planeU(iPlane)));
    end

    for k = 1:numel(satLabels)
        text(satLon_deg(k) + 0.25, satLat_deg(k) + 0.18, satLabels(k), ...
            'FontSize', 12, 'Color', [0.10 0.10 0.10], 'Interpreter', 'none');
    end
end

plot(gsLon_deg, gsLat_deg, 'p', 'MarkerSize', 14, ...
    'MarkerFaceColor', [0.93 0.69 0.13], 'MarkerEdgeColor', 'k', ...
    'DisplayName', 'GS');
text(gsLon_deg + 0.25, gsLat_deg + 0.20, gsName, ...
    'FontSize', 9, 'FontWeight', 'bold', 'Interpreter', 'none');

xlabel('Longitude (deg)');
ylabel('Latitude (deg)');
title(sprintf('User Field Planar Map at %s', tStr), 'Interpreter', 'none');
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

function [userLon_deg, userLat_deg] = getUsersLatLon(sc, userPrefix)
facs = sc.Children.GetElements('eFacility');
userLon_deg = [];
userLat_deg = [];

for k = 0:int32(facs.Count-1)
    fac = facs.Item(k);
    facName = string(fac.InstanceName);
    if ~startsWith(facName, userPrefix)
        continue;
    end

    [lat_deg, lon_deg] = getFacilityLatLon(fac);
    userLon_deg(end+1,1) = lon_deg; %#ok<AGROW>
    userLat_deg(end+1,1) = lat_deg; %#ok<AGROW>
end
end

function [rectLon_deg, rectLat_deg] = getCenteredRectangle(centerLat_deg, centerLon_deg, areaSide_km)
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

function [rectLonMat_deg, rectLatMat_deg] = getSatelliteRectangles(satLat_deg, satLon_deg, areaSide_km)
rectLonMat_deg = zeros(numel(satLat_deg), 4);
rectLatMat_deg = zeros(numel(satLat_deg), 4);

for k = 1:numel(satLat_deg)
    [rectLon_deg, rectLat_deg] = getCenteredRectangle(satLat_deg(k), satLon_deg(k), areaSide_km);
    rectLonMat_deg(k,:) = rectLon_deg;
    rectLatMat_deg(k,:) = rectLat_deg;
end
end

function [bandLonCells, bandLatCells] = getRectangleBands(rectLon_deg, rectLat_deg, numBands)
bandLonCells = {};
bandLatCells = {};

latEdges = linspace(min(rectLat_deg), max(rectLat_deg), numBands + 1);
for k = 2:numBands
    bandLonCells{end+1,1} = [min(rectLon_deg), max(rectLon_deg)]; %#ok<AGROW>
    bandLatCells{end+1,1} = [latEdges(k), latEdges(k)]; %#ok<AGROW>
end
end

function Tsystem = loadSystemStateTable(epfdExcelPath)
Tsystem = table();
if strlength(string(epfdExcelPath)) == 0
    return;
end

excelPath = char(string(epfdExcelPath));
if ~exist(excelPath, 'file')
    warning('PlotUserFieldPlanarMap:EpfdExcelMissing', ...
        'EPFD Excel not found: %s. Skipping system-state EPFD labels.', excelPath);
    return;
end

try
    Tsystem = readtable(excelPath, 'Sheet', 'System_State');
catch ME
    warning('PlotUserFieldPlanarMap:EpfdExcelReadFailed', ...
        'Failed to read System_State sheet from %s: %s', excelPath, ME.message);
    Tsystem = table();
end
end

function Tdistress = loadBeamDistressScoreTable(epfdExcelPath)
Tdistress = table();
if strlength(string(epfdExcelPath)) == 0
    return;
end

excelPath = char(string(epfdExcelPath));
if ~exist(excelPath, 'file')
    warning('PlotUserFieldPlanarMap:DistressExcelMissing', ...
        'EPFD Excel not found: %s. Skipping beam distress labels.', excelPath);
    return;
end

try
    Tdistress = readtable(excelPath, 'Sheet', 'beam distress score');
catch ME
    warning('PlotUserFieldPlanarMap:DistressExcelReadFailed', ...
        'Failed to read beam distress score sheet from %s: %s', excelPath, ME.message);
    Tdistress = table();
end
end

function Tuser = loadUserStateTable(epfdExcelPath)
Tuser = table();
if strlength(string(epfdExcelPath)) == 0
    return;
end

excelPath = char(string(epfdExcelPath));
if ~exist(excelPath, 'file')
    warning('PlotUserFieldPlanarMap:UserExcelMissing', ...
        'EPFD Excel not found: %s. Skipping user-state coloring.', excelPath);
    return;
end

try
    Tuser = readtable(excelPath, 'Sheet', 'User_State');
catch ME
    warning('PlotUserFieldPlanarMap:UserExcelReadFailed', ...
        'Failed to read User_State sheet from %s: %s', excelPath, ME.message);
    Tuser = table();
end
end

function plotUsersByServingSatellite(userLon_deg, userLat_deg, Tuser, satLabels, satColors)
if isempty(userLon_deg)
    return;
end

if isempty(Tuser) || height(Tuser) == 0 || ...
        ~all(ismember(["sat"], string(Tuser.Properties.VariableNames)))
    scatter(userLon_deg, userLat_deg, 24, 'filled', ...
        'MarkerFaceColor', [0 0.45 0.74], 'MarkerFaceAlpha', 0.80, ...
        'DisplayName', 'Users');
    return;
end

Nuser = min(numel(userLon_deg), height(Tuser));
userSat = strings(numel(userLon_deg), 1);
userSat(1:Nuser) = string(Tuser.sat(1:Nuser));
plottedAny = false;

for kSat = 1:numel(satLabels)
    mask = userSat == satLabels(kSat);
    if any(mask)
        scatter(userLon_deg(mask), userLat_deg(mask), 24, 'filled', ...
            'MarkerFaceColor', satColors(kSat,:), 'MarkerEdgeColor', satColors(kSat,:), ...
            'MarkerFaceAlpha', 0.80, 'DisplayName', sprintf('%s users', satLabels(kSat)));
        plottedAny = true;
    end
end

unassignedMask = userSat == "" | ~ismember(userSat, satLabels);
if any(unassignedMask)
    scatter(userLon_deg(unassignedMask), userLat_deg(unassignedMask), 24, 'filled', ...
        'MarkerFaceColor', [0.50 0.50 0.50], 'MarkerEdgeColor', [0.50 0.50 0.50], ...
        'MarkerFaceAlpha', 0.80, 'DisplayName', 'Unassigned users');
        plottedAny = true;
end

if ~plottedAny
    scatter(userLon_deg, userLat_deg, 24, 'filled', ...
        'MarkerFaceColor', [0 0.45 0.74], 'MarkerFaceAlpha', 0.80, ...
        'DisplayName', 'Users');
end
end

function annotateBeamDistressLabels(Tdistress, satLabels, rectLonMat_deg, rectLatMat_deg, rectColors)
if isempty(Tdistress) || height(Tdistress) == 0
    return;
end

requiredVars = ["sat","beam","beam_distress_score"];
if ~all(ismember(requiredVars, string(Tdistress.Properties.VariableNames)))
    warning('PlotUserFieldPlanarMap:DistressExcelMissingColumns', ...
         'beam distress score sheet is missing required columns. Skipping distress labels.');
    return;
end

scoreMask = isfinite(Tdistress.beam_distress_score);
Tdistress = Tdistress(scoreMask, :);
if isempty(Tdistress)
    return;
end

[~, order] = sort(Tdistress.beam_distress_score, 'descend');
Tdistress = Tdistress(order, :);

for i = 1:height(Tdistress)
    satName = string(Tdistress.sat(i));
    beamIdx = double(Tdistress.beam(i));
    if ~isfinite(beamIdx) || beamIdx < 1 || beamIdx > 16
        continue;
    end

    satIdx = find(satLabels == satName, 1);
    if isempty(satIdx)
        continue;
    end

    rectLon_deg = rectLonMat_deg(satIdx,:);
    rectLat_deg = rectLatMat_deg(satIdx,:);
    lonMin = min(rectLon_deg);
    lonMax = max(rectLon_deg);
    lonC = lonMin + 0.10 * (lonMax - lonMin);
    latMax = max(rectLat_deg);
    latMin = min(rectLat_deg);
    bandHeight = (latMax - latMin) / 16;
    latC = latMax - (beamIdx - 0.5) * bandHeight;

    labelText = sprintf('R#%d %.3f', i, double(Tdistress.beam_distress_score(i)));
    text(lonC, latC, labelText, ...
        'HorizontalAlignment', 'left', 'VerticalAlignment', 'middle', ...
        'FontSize', 7, 'FontWeight', 'bold', ...
        'Color', 'k', 'BackgroundColor', 'w', 'EdgeColor', rectColors(satIdx,:), ...
        'Margin', 1.0, 'Interpreter', 'none', 'HandleVisibility', 'off');
end
end

function [trackLonCells, trackLatCells, trackLabels] = getExtendedPlaneTracks( ...
    satLon_deg, satLat_deg, satPlaneLabels, rectLon_deg, rectLat_deg, userLon_deg, userLat_deg, gsLon_deg, gsLat_deg)
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

function [satLon_deg, satLat_deg, satLabels, satPlaneLabels] = getSatelliteSubpoints(root, satNames, tStr)
satLon_deg = zeros(numel(satNames), 1);
satLat_deg = zeros(numel(satNames), 1);
satLabels = strings(numel(satNames), 1);
satPlaneLabels = strings(numel(satNames), 1);

for i = 1:numel(satNames)
    satName = satNames(i);
    satObj = root.GetObjectFromPath(['*/Satellite/' char(satName)]);
    [lat_deg, lon_deg] = getSatelliteSubpointLatLon(satObj, tStr);
    satLon_deg(i) = lon_deg;
    satLat_deg(i) = lat_deg;
    satLabels(i) = satName;

    parts = split(satName, "_");
    if numel(parts) >= 1
        satPlaneLabels(i) = parts(1);
    else
        satPlaneLabels(i) = satName;
    end
end
end

function [refLat_deg, refLon_deg, refSatLabel] = getReferenceSatellite(satLat_deg, satLon_deg, satLabels, gsLat_deg, gsLon_deg)
metric = hypot(satLat_deg - gsLat_deg, satLon_deg - gsLon_deg);
[~, idxMin] = min(metric);
refLat_deg = satLat_deg(idxMin);
refLon_deg = satLon_deg(idxMin);
refSatLabel = satLabels(idxMin);
end

function [lat_deg, lon_deg] = getSatelliteSubpointLatLon(satObj, tStr)
dpLLA = satObj.DataProviders.Item('LLA State').Group.Item('Fixed');
try
    res = dpLLA.ExecSingle(tStr);
catch
    sc = satObj.Parent.Parent;
    res = dpLLA.ExecSingle(char(sc.StartTime));
end
vals = numericScalars(res.DataSets.ToArray);
if numel(vals) < 2
    error('Failed to read satellite subpoint latitude/longitude at %s.', tStr);
end
lat_deg = vals(1);
lon_deg = vals(2);
end

function [lat_deg, lon_deg] = getFacilityLatLon(facilityObj)
dpLLA = facilityObj.DataProviders.Item('LLA State');
res = dpLLA.Exec;
vals = numericScalars(res.DataSets.ToArray);
if numel(vals) < 2
    error('Failed to read facility latitude/longitude.');
end
lat_deg = vals(1);
lon_deg = vals(2);
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
