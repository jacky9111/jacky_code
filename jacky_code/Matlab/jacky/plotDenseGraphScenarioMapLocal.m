function figPath = plotDenseGraphScenarioMapLocal(scenario, plotOpts)
% plotDenseGraphScenarioMapLocal
% Plot user distribution with dense constellation footprints and shut beams.

if nargin < 2 || isempty(plotOpts)
    plotOpts = struct();
end
showFig = true;
figPath = "";
if isfield(plotOpts, 'showFigure') && ~isempty(plotOpts.showFigure)
    showFig = logical(plotOpts.showFigure);
end
if isfield(plotOpts, 'figurePath') && strlength(string(plotOpts.figurePath)) > 0
    figPath = char(string(plotOpts.figurePath));
end
if ~showFig && strlength(figPath) == 0
    return;
end

satGeom = scenario.satGeom;
nSat = numel(satGeom);
nUser = scenario.nUsers;
userLat = scenario.userLat(:);
userLon = scenario.userLon(:);
gsLat = scenario.gsLat_deg;
gsLon = scenario.gsLon_deg;
if isfield(scenario, 'gsLon_deg')
    gsLon = scenario.gsLon_deg;
end

halfEW_km = scenario.alt_km * tand(scenario.beamHalfEW_deg);
if isfield(scenario, 'beamHalfNS_total_deg') && isfinite(scenario.beamHalfNS_total_deg)
    halfNS_total_deg = scenario.beamHalfNS_total_deg;
else
    halfNS_total_deg = scenario.beamHalfNS_deg * scenario.nBeam;
end
halfNS_km = scenario.alt_km * tand(halfNS_total_deg);
planeList = strings(nSat, 1);
for iSat = 1:nSat
    planeList(iSat) = extractPlaneLabelGraphLocal(satGeom(iSat).satName);
end
planeUnique = unique(planeList, 'stable');
planeColors = lines(max(numel(planeUnique), 1));

critMask = false(nSat, 1);
if isfield(scenario, 'criticalSatIdx') && ~isempty(scenario.criticalSatIdx)
    critMask(scenario.criticalSatIdx) = true;
end

fig = figure('Name', 'Dense graph scenario: users and satellites', ...
    'Color', 'w', 'Visible', ternaryPlotGraphLocal(showFig, 'on', 'off'));
ax = axes('Parent', fig);
hold(ax, 'on');
grid(ax, 'on');
box(ax, 'on');

hatchLegendDrawn = false;
for iSat = 1:nSat
    iPlane = find(planeUnique == planeList(iSat), 1);
    satColor = planeColors(iPlane, :);
    isCrit = critMask(iSat);
    faceAlpha = ternaryPlotGraphLocal(isCrit, 0.07, 0.02);
    edgeW = ternaryPlotGraphLocal(isCrit, 1.1, 0.6);
    [rectLon, rectLat] = footprintRectPlotGraphLocal(satGeom(iSat).subLat, satGeom(iSat).subLon, ...
        halfEW_km, halfNS_km);
    patch(ax, 'XData', rectLon([1 2 3 4 1]), 'YData', rectLat([1 2 3 4 1]), ...
        'FaceColor', satColor, 'FaceAlpha', faceAlpha, ...
        'EdgeColor', satColor, 'LineWidth', edgeW, 'HandleVisibility', 'off');

    if isfield(scenario, 'shutOffMat') && isCrit
        shutBeams = find(scenario.shutOffMat(iSat, :));
        for b = shutBeams(:).'
            drawShutBeamHatchPlotGraphLocal(ax, rectLon, rectLat, b, satColor);
            if ~hatchLegendDrawn
                patch(ax, nan, nan, [0.75 0.75 0.75], 'FaceAlpha', 0.35, ...
                    'EdgeColor', [0.2 0.2 0.2], 'DisplayName', 'Shut beam');
                hatchLegendDrawn = true;
            end
        end
    end
end

for iSat = 1:nSat
    iPlane = find(planeUnique == planeList(iSat), 1);
    satColor = planeColors(iPlane, :);
    isCrit = critMask(iSat);
    if isCrit
        scatter(ax, satGeom(iSat).subLon, satGeom(iSat).subLat, 72, ...
            'Marker', 'o', 'MarkerEdgeColor', 'k', 'MarkerFaceColor', satColor, ...
            'LineWidth', 1.2, 'HandleVisibility', 'off');
    else
        scatter(ax, satGeom(iSat).subLon, satGeom(iSat).subLat, 28, ...
            'Marker', 'o', 'MarkerEdgeColor', satColor, 'MarkerFaceColor', satColor, ...
            'HandleVisibility', 'off');
    end
    if isCrit
        text(ax, satGeom(iSat).subLon + 0.12, satGeom(iSat).subLat + 0.10, ...
            char(satGeom(iSat).satName), 'FontSize', 7, 'Interpreter', 'none', ...
            'Color', [0.1 0.1 0.1]);
    end
end

maskClosed = scenario.closedBeamUserMask(:);
maskOpen = ~maskClosed;
if any(maskOpen)
    scatter(ax, userLon(maskOpen), userLat(maskOpen), 22, ...
        'Marker', '.', 'MarkerEdgeColor', [0.15 0.45 0.75], ...
        'MarkerFaceColor', [0.15 0.45 0.75], 'DisplayName', 'Unaffected user');
end
if any(maskClosed)
    scatter(ax, userLon(maskClosed), userLat(maskClosed), 36, ...
        'Marker', 'x', 'LineWidth', 1.2, 'MarkerEdgeColor', [0.85 0.20 0.10], ...
        'DisplayName', 'Closed-beam affected user');
end

plot(ax, gsLon, gsLat, 'p', 'MarkerSize', 14, ...
    'MarkerFaceColor', [0.93 0.69 0.13], 'MarkerEdgeColor', 'k', 'DisplayName', 'GS');

lonPad = max(scenario.userSpreadLon_deg * 0.55, 1.5);
latPad = max(scenario.userSpreadLat_deg * 0.55, 1.5);
if isfield(scenario, 'userSpreadLon_deg')
    lonPad = max(lonPad, scenario.userSpreadLon_deg * 0.55);
end
if isfield(scenario, 'userSpreadLat_deg')
    latPad = max(latPad, scenario.userSpreadLat_deg * 0.55);
end
lonView = [userLon; gsLon];
latView = [userLat; gsLat];
if any(critMask)
    lonView = [lonView; [satGeom(critMask).subLon]'];
    latView = [latView; [satGeom(critMask).subLat]'];
end
xlim(ax, [min(lonView) - lonPad, max(lonView) + lonPad]);
ylim(ax, [min(latView) - latPad, max(latView) + latPad]);

nClosed = sum(maskClosed);
title(ax, sprintf('Users (N=%d, closed-beam affected=%d) with dense constellation', ...
    nUser, nClosed), 'FontWeight', 'normal');
xlabel(ax, 'Longitude (deg)');
ylabel(ax, 'Latitude (deg)');
legend(ax, 'Location', 'eastoutside');
axis(ax, 'equal');
hold(ax, 'off');

if strlength(figPath) > 0
    figDir = fileparts(figPath);
    if ~isempty(figDir) && ~exist(figDir, 'dir')
        mkdir(figDir);
    end
    saveas(fig, figPath);
    fprintf('Saved figure: %s\n', figPath);
end
if ~showFig && isgraphics(fig)
    close(fig);
end
end

function plane = extractPlaneLabelGraphLocal(satName)
tok = regexp(char(string(satName)), '^(P\d+)', 'tokens', 'once');
if isempty(tok)
    plane = "SAT";
else
    plane = string(tok{1});
end
end

function [rectLon, rectLat] = footprintRectPlotGraphLocal(lat_deg, lon_deg, halfEW_km, halfNS_km)
dLat = halfNS_km / 111.32;
lonScale = max(cosd(lat_deg), 1e-6);
dLon = halfEW_km / (111.32 * lonScale);
rectLon = [lon_deg - dLon, lon_deg + dLon, lon_deg + dLon, lon_deg - dLon];
rectLat = [lat_deg - dLat, lat_deg - dLat, lat_deg + dLat, lat_deg + dLat];
end

function drawShutBeamHatchPlotGraphLocal(ax, rectLon, rectLat, beamIdx, satColor)
lonMin = min(rectLon);
lonMax = max(rectLon);
latMin = min(rectLat);
latMax = max(rectLat);
bandHeight = (latMax - latMin) / 16;
latTop = latMax - (beamIdx - 1) * bandHeight;
latBottom = latTop - bandHeight;
patch(ax, 'XData', [lonMin lonMax lonMax lonMin lonMin], ...
    'YData', [latBottom latBottom latTop latTop latBottom], ...
    'FaceColor', satColor, 'FaceAlpha', 0.14, ...
    'EdgeColor', 'none', 'HandleVisibility', 'off');
h = latTop - latBottom;
xStart = linspace(lonMin - h, lonMax, 8);
for xs = xStart
    x1 = max(lonMin, xs);
    x2 = min(lonMax, xs + h);
    if x2 <= x1
        continue;
    end
    y1 = latBottom + (x1 - xs);
    y2 = latBottom + (x2 - xs);
    plot(ax, [x1 x2], [y1 y2], '-', 'Color', satColor, 'LineWidth', 1.0, 'HandleVisibility', 'off');
end
end

function out = ternaryPlotGraphLocal(c, a, b)
if c, out = a; else, out = b; end
end
