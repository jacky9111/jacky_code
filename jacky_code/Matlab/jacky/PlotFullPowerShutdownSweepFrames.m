function Tframes = PlotFullPowerShutdownSweepFrames(root, satNames, gsName, areaSide_km, sweepExcelPath, opts)
% PlotFullPowerShutdownSweepFrames
% Read full-power shutdown Excel results and render one figure per changed
% violating time slot. Unchanged on/off beam states are skipped.

if nargin < 6 || isempty(opts)
    opts = struct();
end
opts = applyFrameDefaults(opts, sweepExcelPath);

excelPath = char(string(sweepExcelPath));
if ~exist(excelPath, 'file')
    error('PlotFullPowerShutdownSweepFrames:MissingExcel', 'Excel file not found: %s', excelPath);
end

Tstate = readtable(excelPath, 'Sheet', 'ViolatingSat_16BeamState');
if isempty(Tstate) || height(Tstate) == 0
    warning('PlotFullPowerShutdownSweepFrames:NoViolatingState', ...
        'ViolatingSat_16BeamState sheet is empty. No frames generated.');
    Tframes = table();
    return;
end

Tstate.time = string(Tstate.time);
Tstate.geo = string(Tstate.geo);
Tstate.sat = string(Tstate.sat);
satNames = string(satNames(:));
gsName = char(string(gsName));
Tstate = Tstate(ismember(Tstate.sat, satNames), :);
if isempty(Tstate) || height(Tstate) == 0
    warning('PlotFullPowerShutdownSweepFrames:NoSatData', ...
        'No rows in Excel for requested satellites: %s', strjoin(satNames, ', '));
    Tframes = table();
    return;
end

sc = root.CurrentScenario;
[gsLat_deg, gsLon_deg] = resolvePlotGsLatLon(opts, root, gsName);

excelTimeList = unique(Tstate.time, 'stable');
motionTimeList = resolveMotionTimeList(opts, excelTimeList);
[satLonHist, satLatHist] = precomputeSatSubpointHistory(root, satNames, motionTimeList, sc);
satPlaneLabelsAll = planeLabelsFromSatNames(satNames);
if opts.snapSatellitesToGroundTrack
    trackModels = buildPlaneTrackModelsFromHistory(satLonHist, satLatHist, satPlaneLabelsAll);
    [satLonHist, satLatHist] = snapPositionsOntoPlaneTracks(satLonHist, satLatHist, satPlaneLabelsAll, trackModels);
end
if opts.fixedAxesOnGs
    [fixedXlim, fixedYlim] = computeFixedAxesIncludingFields( ...
        gsLon_deg, gsLat_deg, satLonHist, satLatHist, areaSide_km, opts);
end
defaultGeo = "IdealGSO_GS01";
if ~isempty(Tstate.geo)
    defaultGeo = unique(Tstate.geo, 'stable');
    defaultGeo = defaultGeo(1);
end
prevSignature = "";
frameRows = struct('time', {}, 'geo', {}, 'frame_index', {}, 'skipped_same_state', {}, ...
    'violating_sat_count', {}, 'shut_beam_count', {}, 'frame_path', {});
frameIndex = 0;

for iTime = 1:numel(motionTimeList)
    tStr = char(motionTimeList(iTime));
    TslotAll = Tstate(Tstate.time == motionTimeList(iTime), :);
    if isempty(TslotAll)
        geoList = defaultGeo;
    else
        geoList = unique(TslotAll.geo, 'stable');
    end

    for iGeo = 1:numel(geoList)
        if isempty(TslotAll)
            Tslot = table();
        else
            Tslot = TslotAll(TslotAll.geo == geoList(iGeo), :);
            Tslot = sortrows(Tslot, {'sat','beam'}, {'ascend','ascend'});
        end

        [satLon_deg, satLat_deg, satLabels, satPlaneLabels] = getSatelliteSubpointsLocal(root, satNames, tStr, sc);
        if opts.snapSatellitesToGroundTrack
            [satLon_deg, satLat_deg] = snapPositionsOntoPlaneTracks( ...
                satLon_deg(:), satLat_deg(:), satPlaneLabels, trackModels);
        end
        if opts.skipUnchanged
            signature = buildFrameSignature(Tslot, satLon_deg, satLat_deg);
            if signature == prevSignature
                frameRows(end+1) = makeFrameRow(motionTimeList(iTime), geoList(iGeo), frameIndex, true, Tslot, ""); %#ok<AGROW>
                continue;
            end
            prevSignature = signature;
        end
        frameIndex = frameIndex + 1;

        [rectLonMat_deg, rectLatMat_deg] = getSatelliteRectanglesLocal(satLat_deg, satLon_deg, areaSide_km);
        if opts.fixedAxesOnGs
            plotXlim = fixedXlim;
            plotYlim = fixedYlim;
        else
            plotXlim = [min([gsLon_deg; satLonHist(:)]) - 1, max([gsLon_deg; satLonHist(:)]) + 1];
            plotYlim = [min([gsLat_deg; satLatHist(:)]) - 1, max([gsLat_deg; satLatHist(:)]) + 1];
        end
        if opts.snapSatellitesToGroundTrack
            [trackLonCells, trackLatCells, trackLabels] = groundTrackLinesFromModels( ...
                trackModels, plotXlim, plotYlim);
        else
            [trackLonCells, trackLatCells, trackLabels] = getExtendedPlaneTracksLocal( ...
                satLon_deg, satLat_deg, satPlaneLabels, rectLonMat_deg(:), rectLatMat_deg(:), gsLon_deg, gsLat_deg);
        end

        fig = figure('Visible', ternary(opts.showFigures, 'on', 'off'), ...
            'Name', sprintf('Shutdown Sweep %03d', frameIndex), 'Color', 'w');
        hold on;
        grid on;
        box on;
        ax = gca;

        satColors = lines(max(numel(satLabels), 1));
        usePerSatLegend = numel(satLabels) <= 6;
        planeList = unique(satPlaneLabels, 'stable');
        firstFieldSatPerPlane = zeros(numel(planeList), 1);
        for iPlane = 1:numel(planeList)
            firstFieldSatPerPlane(iPlane) = find(satPlaneLabels == planeList(iPlane), 1, 'first');
        end
        hatchLegendDrawn = false;
        if opts.showMotionTrail
            drawMotionTrailsUpToTime(satLonHist, satLatHist, satLabels, motionTimeList, motionTimeList(iTime), satColors);
        end
        for kSat = 1:numel(satLabels)
            rectLon_deg = rectLonMat_deg(kSat,:);
            rectLat_deg = rectLatMat_deg(kSat,:);
            satColor = satColors(kSat,:);
            if usePerSatLegend
                showFieldInLegend = true;
                fieldLegendName = sprintf('%s field', satLabels(kSat));
            else
                showFieldInLegend = any(kSat == firstFieldSatPerPlane);
                fieldLegendName = sprintf('%s field', satPlaneLabels(kSat));
            end
            patch('XData', rectLon_deg([1 2 3 4 1]), ...
                'YData', rectLat_deg([1 2 3 4 1]), ...
                'FaceColor', satColor, 'FaceAlpha', 0.03, ...
                'EdgeColor', satColor, 'LineStyle', '-', 'LineWidth', 0.8, ...
                'HandleVisibility', ternary(showFieldInLegend, 'on', 'off'), ...
                'DisplayName', fieldLegendName);

            [bandLonCells, bandLatCells] = getRectangleBandsLocal(rectLon_deg, rectLat_deg, 16);
            for kBand = 1:numel(bandLonCells)
                plot(bandLonCells{kBand}, bandLatCells{kBand}, '--', ...
                    'Color', satColor, 'LineWidth', 0.6, 'HandleVisibility', 'off');
            end

            if isempty(Tslot) || height(Tslot) == 0
                satMask = false;
            else
                satMask = Tslot.sat == satLabels(kSat);
            end
            if any(satMask)
                Tsat = Tslot(satMask, :);
                shutBeams = double(Tsat.beam(Tsat.shut_off > 0));
                for b = shutBeams(:).'
                    drawShutBeamHatch(rectLon_deg, rectLat_deg, b, satColor, opts.hatchLineWidth, opts.hatchDensity);
                    if ~hatchLegendDrawn
                        drawShutBeamLegendSample(satColor, opts.hatchLineWidth);
                        hatchLegendDrawn = true;
                    end
                end
            end
        end

        for k = 1:numel(trackLonCells)
            plot(trackLonCells{k}, trackLatCells{k}, '-', 'Color', 'k', 'LineWidth', 1.0, ...
                'DisplayName', sprintf('%s ground track', trackLabels(k)));
        end

        if usePerSatLegend
            for kSat = 1:numel(satLabels)
                scatter(satLon_deg(kSat), satLat_deg(kSat), 52, ...
                    'Marker', 'o', 'MarkerEdgeColor', satColors(kSat,:), ...
                    'MarkerFaceColor', satColors(kSat,:), ...
                    'DisplayName', char(satLabels(kSat)));
            end
        else
            for iPlane = 1:numel(planeList)
                mask = satPlaneLabels == planeList(iPlane);
                kRef = find(mask, 1, 'first');
                scatter(satLon_deg(mask), satLat_deg(mask), 52, ...
                    'Marker', 'o', 'MarkerEdgeColor', satColors(kRef,:), ...
                    'MarkerFaceColor', satColors(kRef,:), ...
                    'DisplayName', sprintf('%s satellites', planeList(iPlane)));
            end
        end
        for kSat = 1:numel(satLabels)
            text(satLon_deg(kSat) + 0.25, satLat_deg(kSat) + 0.18, satLabels(kSat), ...
                'FontSize', 9, 'Color', [0.10 0.10 0.10], 'Interpreter', 'none');
        end

        plot(gsLon_deg, gsLat_deg, 'p', 'MarkerSize', 14, ...
            'MarkerFaceColor', [0.93 0.69 0.13], 'MarkerEdgeColor', 'k', ...
            'DisplayName', 'GS');
        text(gsLon_deg + 0.25, gsLat_deg + 0.20, gsName, ...
            'FontSize', 9, 'FontWeight', 'bold', 'Interpreter', 'none');

        title(ax, sprintf('Shutdown Sweep at %s (%s)', tStr, char(geoList(iGeo))), 'Interpreter', 'none');
        xlabel(ax, 'Longitude (deg)');
        ylabel(ax, 'Latitude (deg)');
        legend(ax, 'Location', 'northeast');

        if opts.fixedAxesOnGs
            exportXlim = fixedXlim;
            exportYlim = fixedYlim;
        else
            allLon = [gsLon_deg; rectLonMat_deg(:); satLon_deg(:)];
            allLat = [gsLat_deg; rectLatMat_deg(:); satLat_deg(:)];
            for k = 1:numel(trackLonCells)
                allLon = [allLon; trackLonCells{k}(:)]; %#ok<AGROW>
                allLat = [allLat; trackLatCells{k}(:)]; %#ok<AGROW>
            end
            lonPad = max(0.5, 0.05 * (max(allLon) - min(allLon)));
            latPad = max(0.5, 0.05 * (max(allLat) - min(allLat)));
            exportXlim = [min(allLon)-lonPad, max(allLon)+lonPad];
            exportYlim = [min(allLat)-latPad, max(allLat)+latPad];
        end
        xlim(ax, exportXlim);
        ylim(ax, exportYlim);
        applyFigureSizeForLimits(fig, exportXlim, exportYlim, opts);
        set(ax, 'LooseInset', max(get(ax, 'LooseInset'), 0.04));

        framePath = fullfile(opts.outputDir, sprintf('shutdown_%03d_%s.png', frameIndex, sanitizeTimeToken(tStr)));
        if opts.savePng
            drawnow;
            exportgraphics(fig, framePath, ...
                'Resolution', opts.pngResolution, ...
                'BackgroundColor', 'white', ...
                'ContentType', 'image');
        else
            framePath = "";
        end
        if ~opts.showFigures
            close(fig);
        end

        frameRows(end+1) = makeFrameRow(motionTimeList(iTime), geoList(iGeo), frameIndex, false, Tslot, framePath); %#ok<AGROW>
    end
end

Tframes = struct2table(frameRows);
if ~isempty(Tframes)
    Tframes = sortrows(Tframes, {'frame_index','time'}, {'ascend','ascend'});
end
end

function [gsLat_deg, gsLon_deg] = resolvePlotGsLatLon(opts, root, gsName)
% Plot GS position: plotGsLat_deg / plotGsLon_deg (independent from sweep EPFD GS).
if isfield(opts, 'plotGsLat_deg') && isfinite(opts.plotGsLat_deg) && ...
        isfield(opts, 'plotGsLon_deg') && isfinite(opts.plotGsLon_deg)
    gsLat_deg = double(opts.plotGsLat_deg);
    gsLon_deg = double(opts.plotGsLon_deg);
elseif opts.useSimulatedGs
    gsLat_deg = double(opts.gsLat_deg);
    gsLon_deg = double(opts.gsLon_deg);
else
    [gsLat_deg, gsLon_deg] = getFacilityLatLonLocal(root.GetObjectFromPath(['*/Facility/' gsName]));
end
end

function opts = applyFrameDefaults(opts, sweepExcelPath)
if ~isfield(opts, 'showFigures') || isempty(opts.showFigures), opts.showFigures = false; end
if ~isfield(opts, 'savePng') || isempty(opts.savePng), opts.savePng = true; end
if ~isfield(opts, 'skipUnchanged') || isempty(opts.skipUnchanged), opts.skipUnchanged = true; end
if ~isfield(opts, 'useSimulatedGs') || isempty(opts.useSimulatedGs), opts.useSimulatedGs = false; end
if ~isfield(opts, 'gsLat_deg') || ~isfinite(opts.gsLat_deg), opts.gsLat_deg = 0; end
if ~isfield(opts, 'gsLon_deg') || ~isfinite(opts.gsLon_deg), opts.gsLon_deg = 121; end
if ~isfield(opts, 'plotGsLat_deg') || ~isfinite(opts.plotGsLat_deg), opts.plotGsLat_deg = opts.gsLat_deg; end
if ~isfield(opts, 'plotGsLon_deg') || ~isfinite(opts.plotGsLon_deg), opts.plotGsLon_deg = opts.gsLon_deg; end
if ~isfield(opts, 'pngResolution') || ~isfinite(opts.pngResolution), opts.pngResolution = 150; end
if ~isfield(opts, 'figureWidthPx') || ~isfinite(opts.figureWidthPx), opts.figureWidthPx = 1280; end
if ~isfield(opts, 'figureHeightPx') || ~isfinite(opts.figureHeightPx), opts.figureHeightPx = 0; end
if ~isfield(opts, 'hatchLineWidth') || ~isfinite(opts.hatchLineWidth), opts.hatchLineWidth = 0.8; end
if ~isfield(opts, 'hatchDensity') || ~isfinite(opts.hatchDensity), opts.hatchDensity = 8; end
if ~isfield(opts, 'fixedAxesOnGs') || isempty(opts.fixedAxesOnGs), opts.fixedAxesOnGs = false; end
if ~isfield(opts, 'showMotionTrail') || isempty(opts.showMotionTrail), opts.showMotionTrail = false; end
if ~isfield(opts, 'snapSatellitesToGroundTrack') || isempty(opts.snapSatellitesToGroundTrack)
    opts.snapSatellitesToGroundTrack = true;
end
if ~isfield(opts, 'axesLatBelowGs_deg') || ~isfinite(opts.axesLatBelowGs_deg), opts.axesLatBelowGs_deg = 2; end
if ~isfield(opts, 'axesLonPad_deg') || ~isfinite(opts.axesLonPad_deg), opts.axesLonPad_deg = NaN; end
if ~isfield(opts, 'axesLatPad_deg') || ~isfinite(opts.axesLatPad_deg), opts.axesLatPad_deg = NaN; end
if ~isfield(opts, 'plotEveryTimeSlot') || isempty(opts.plotEveryTimeSlot), opts.plotEveryTimeSlot = false; end
if ~isfield(opts, 'tStartStr'), opts.tStartStr = ""; end
if ~isfield(opts, 'tEndStr'), opts.tEndStr = ""; end
if ~isfield(opts, 'stepSec') || ~isfinite(opts.stepSec), opts.stepSec = 2; end
if ~isfield(opts, 'outputDir') || strlength(string(opts.outputDir)) == 0
    [parentDir, baseName] = fileparts(char(string(sweepExcelPath)));
    opts.outputDir = fullfile(parentDir, [baseName '_frames']);
end
opts.outputDir = char(string(opts.outputDir));
if opts.savePng && ~exist(opts.outputDir, 'dir')
    mkdir(opts.outputDir);
end
end

function motionTimeList = resolveMotionTimeList(opts, excelTimeList)
if opts.plotEveryTimeSlot && strlength(string(opts.tStartStr)) > 0 && strlength(string(opts.tEndStr)) > 0
    motionTimeList = buildTimeGridLocal(opts.tStartStr, opts.tEndStr, opts.stepSec);
elseif ~isempty(excelTimeList)
    motionTimeList = excelTimeList;
else
    motionTimeList = string.empty(0, 1);
end
end

function timeList = buildTimeGridLocal(tStartStr, tEndStr, stepSec)
tStart = datenum(char(string(tStartStr)));
tEnd = datenum(char(string(tEndStr)));
step = double(stepSec) / 86400;
timeGrid = tStart:step:tEnd;
timeList = strings(numel(timeGrid), 1);
for i = 1:numel(timeGrid)
    timeList(i) = string(datestr(timeGrid(i), 'dd mmm yyyy HH:MM:SS'));
end
end

function signature = buildFrameSignature(Tslot, satLon_deg, satLat_deg)
posParts = strings(numel(satLon_deg), 1);
for k = 1:numel(satLon_deg)
    posParts(k) = sprintf('%.4f,%.4f', satLon_deg(k), satLat_deg(k));
end
posPart = join(posParts, '_');
if isempty(Tslot) || height(Tslot) == 0
    signature = "pos|" + posPart;
else
    signature = buildSlotSignature(Tslot) + "|" + posPart;
end
end

function planeLabels = planeLabelsFromSatNames(satNames)
planeLabels = strings(numel(satNames), 1);
for k = 1:numel(satNames)
    parts = split(string(satNames(k)), '_');
    planeLabels(k) = parts(1);
end
end

function trackModels = buildPlaneTrackModelsFromHistory(satLonHist, satLatHist, satPlaneLabels)
planeList = unique(satPlaneLabels, 'stable');
trackModels = repmat(struct('planeLabel', "", 'latIndependent', true, 'p', [0 0]), 0, 1);
for iPlane = 1:numel(planeList)
    mask = satPlaneLabels == planeList(iPlane);
    lonV = satLonHist(:, mask);
    latV = satLatHist(:, mask);
    x = lonV(isfinite(lonV));
    y = latV(isfinite(latV));
    if numel(x) < 2
        continue;
    end
    model.planeLabel = planeList(iPlane);
    if (max(y) - min(y)) >= (max(x) - min(x))
        model.latIndependent = true;
        model.p = polyfit(y, x, 1);
    else
        model.latIndependent = false;
        model.p = polyfit(x, y, 1);
    end
    trackModels(end+1) = model; %#ok<AGROW>
end
end

function model = findPlaneTrackModel(planeLabel, trackModels)
model = struct('planeLabel', "", 'latIndependent', true, 'p', []);
for i = 1:numel(trackModels)
    if trackModels(i).planeLabel == planeLabel
        model = trackModels(i);
        return;
    end
end
end

function [lonOut, latOut] = snapPositionsOntoPlaneTracks(lonIn, latIn, satPlaneLabels, trackModels)
lonOut = lonIn;
latOut = latIn;
if isempty(trackModels)
    return;
end
if isvector(lonIn)
    lonOut = lonIn(:);
    latOut = latIn(:);
    satPlaneLabels = satPlaneLabels(:);
    for k = 1:numel(lonOut)
        if ~isfinite(lonOut(k)) || ~isfinite(latOut(k))
            continue;
        end
        model = findPlaneTrackModel(satPlaneLabels(k), trackModels);
        if isempty(model.p)
            continue;
        end
        if model.latIndependent
            lonOut(k) = polyval(model.p, latOut(k));
        else
            latOut(k) = polyval(model.p, lonOut(k));
        end
    end
    if isrow(lonIn)
        lonOut = lonOut.';
        latOut = latOut.';
    end
else
    for k = 1:size(lonIn, 2)
        model = findPlaneTrackModel(satPlaneLabels(k), trackModels);
        if isempty(model.p)
            continue;
        end
        for i = 1:size(lonIn, 1)
            if ~isfinite(lonIn(i, k)) || ~isfinite(latIn(i, k))
                continue;
            end
            if model.latIndependent
                lonOut(i, k) = polyval(model.p, latIn(i, k));
            else
                latOut(i, k) = polyval(model.p, lonIn(i, k));
            end
        end
    end
end
end

function [trackLonCells, trackLatCells, trackLabels] = groundTrackLinesFromModels(trackModels, xlim_deg, ylim_deg)
trackLonCells = {};
trackLatCells = {};
trackLabels = strings(0, 1);
for i = 1:numel(trackModels)
    model = trackModels(i);
    if isempty(model.p)
        continue;
    end
    if model.latIndependent
        latLine = linspace(ylim_deg(1), ylim_deg(2), 200);
        lonLine = polyval(model.p, latLine);
    else
        lonLine = linspace(xlim_deg(1), xlim_deg(2), 200);
        latLine = polyval(model.p, lonLine);
    end
    trackLonCells{end+1, 1} = lonLine; %#ok<AGROW>
    trackLatCells{end+1, 1} = latLine; %#ok<AGROW>
    trackLabels(end+1, 1) = model.planeLabel; %#ok<AGROW>
end
end

function [satLonHist, satLatHist] = precomputeSatSubpointHistory(root, satNames, timeList, sc)
nTime = numel(timeList);
nSat = numel(satNames);
satLonHist = nan(nTime, nSat);
satLatHist = nan(nTime, nSat);
for iTime = 1:nTime
    [lon_deg, lat_deg] = getSatelliteSubpointsLocal(root, satNames, char(timeList(iTime)), sc);
    satLonHist(iTime, :) = lon_deg(:).';
    satLatHist(iTime, :) = lat_deg(:).';
end
end

function [xlim_deg, ylim_deg] = computeFixedAxesIncludingFields( ...
    gsLon_deg, gsLat_deg, satLonHist, satLatHist, areaSide_km, opts)
halfLat_deg = (areaSide_km / 2) / 111.32;
allLon = gsLon_deg;
allLat = gsLat_deg;
for i = 1:numel(satLonHist(:))
    satLon = satLonHist(i);
    satLat = satLatHist(i);
    if ~isfinite(satLon) || ~isfinite(satLat)
        continue;
    end
    halfLon_deg = halfLat_deg / max(cosd(satLat), 1e-6);
    allLon = [allLon; satLon + [-1; 1] * halfLon_deg]; %#ok<AGROW>
    allLat = [allLat; satLat + [-1; 1] * halfLat_deg]; %#ok<AGROW>
end
if isfinite(opts.axesLonPad_deg) && opts.axesLonPad_deg > 0
    lonPad = opts.axesLonPad_deg;
else
    lonPad = max(0.5, 0.03 * (max(allLon) - min(allLon)));
end
if isfinite(opts.axesLatPad_deg) && opts.axesLatPad_deg > 0
    latPad = opts.axesLatPad_deg;
else
    latPad = max(0.5, 0.03 * (max(allLat) - min(allLat)));
end
latBelow = opts.axesLatBelowGs_deg;
xlim_deg = [min(allLon) - lonPad, max(allLon) + lonPad];
ylim_deg = [min(allLat) - latPad, max(allLat) + latPad];
ylim_deg(1) = min(ylim_deg(1), gsLat_deg - latBelow);
if ylim_deg(2) <= ylim_deg(1)
    ylim_deg(2) = ylim_deg(1) + 2;
end
end

function applyFigureSizeForLimits(fig, xlim_deg, ylim_deg, opts)
lonSpan = max(diff(xlim_deg), 1e-3);
latSpan = max(diff(ylim_deg), 1e-3);
widthPx = max(round(double(opts.figureWidthPx)), 640);
if isfield(opts, 'figureHeightPx') && isfinite(opts.figureHeightPx) && opts.figureHeightPx > 0
    heightPx = round(double(opts.figureHeightPx));
else
    heightPx = max(round(widthPx * (latSpan / lonSpan)), 360);
end
set(fig, 'Position', [80 80 widthPx heightPx], 'PaperPositionMode', 'auto', 'Color', 'w');
end

function drawMotionTrailsUpToTime(satLonHist, satLatHist, satLabels, timeList, timeVal, satColors)
idxEnd = find(timeList == timeVal, 1, 'first');
if isempty(idxEnd) || idxEnd < 2
    return;
end
for kSat = 1:numel(satLabels)
    lonTrail = satLonHist(1:idxEnd, kSat);
    latTrail = satLatHist(1:idxEnd, kSat);
    valid = isfinite(lonTrail) & isfinite(latTrail);
    if sum(valid) < 2
        continue;
    end
    plot(lonTrail(valid), latTrail(valid), '-', ...
        'Color', [satColors(kSat,:) 0.35], 'LineWidth', 1.2, 'HandleVisibility', 'off');
    scatter(lonTrail(valid), latTrail(valid), 18, ...
        'Marker', '.', 'MarkerEdgeColor', satColors(kSat,:), ...
        'MarkerFaceColor', satColors(kSat,:), 'HandleVisibility', 'off');
end
end

function signature = buildSlotSignature(Tslot)
parts = strings(height(Tslot), 1);
for i = 1:height(Tslot)
    parts(i) = sprintf('%s_B%02d_%d', char(Tslot.sat(i)), round(double(Tslot.beam(i))), round(double(Tslot.shut_off(i))));
end
signature = join(parts, '|');
end

function frameRow = makeFrameRow(timeVal, geoVal, frameIndex, skipped, Tslot, framePath)
frameRow.time = string(timeVal);
frameRow.geo = string(geoVal);
frameRow.frame_index = double(frameIndex);
frameRow.skipped_same_state = double(skipped);
if isempty(Tslot) || height(Tslot) == 0
    frameRow.violating_sat_count = 0;
    frameRow.shut_beam_count = 0;
else
    frameRow.violating_sat_count = numel(unique(string(Tslot.sat), 'stable'));
    frameRow.shut_beam_count = sum(Tslot.shut_off > 0);
end
frameRow.frame_path = string(framePath);
end

function drawShutBeamLegendSample(satColor, hatchLineWidth)
plot(nan, nan, '-', 'Color', satColor, 'LineWidth', hatchLineWidth, 'DisplayName', 'Shut beam');
end

function drawShutBeamHatch(rectLon_deg, rectLat_deg, beamIdx, satColor, hatchLineWidth, hatchDensity)
lonMin = min(rectLon_deg);
lonMax = max(rectLon_deg);
latMin = min(rectLat_deg);
latMax = max(rectLat_deg);
bandHeight = (latMax - latMin) / 16;
latTop = latMax - (beamIdx - 1) * bandHeight;
latBottom = latTop - bandHeight;

patch('XData', [lonMin lonMax lonMax lonMin lonMin], ...
    'YData', [latBottom latBottom latTop latTop latBottom], ...
    'FaceColor', satColor, 'FaceAlpha', 0.10, ...
    'EdgeColor', 'none', 'HandleVisibility', 'off');

h = latTop - latBottom;
xStart = linspace(lonMin - h, lonMax, max(3, round(hatchDensity)));
for xs = xStart
    x1 = max(lonMin, xs);
    x2 = min(lonMax, xs + h);
    if x2 <= x1
        continue;
    end
    y1 = latBottom + (x1 - xs);
    y2 = latBottom + (x2 - xs);
    plot([x1 x2], [y1 y2], '-', 'Color', satColor, 'LineWidth', hatchLineWidth, 'HandleVisibility', 'off');
end
end

function token = sanitizeTimeToken(tStr)
token = regexprep(char(string(tStr)), '[^A-Za-z0-9]+', '_');
token = regexprep(token, '_+', '_');
token = regexprep(token, '^_|_$', '');
end

function out = ternary(cond, a, b)
if cond
    out = a;
else
    out = b;
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

function [trackLonCells, trackLatCells, trackLabels] = getExtendedPlaneTracksLocal(satLon_deg, satLat_deg, satPlaneLabels, rectLon_deg, rectLat_deg, gsLon_deg, gsLat_deg)
trackLonCells = {};
trackLatCells = {};
trackLabels = strings(0,1);
planeLabels = unique(satPlaneLabels, 'stable');
lonMin = min([rectLon_deg(:); gsLon_deg; satLon_deg(:)]) - 1.0;
lonMax = max([rectLon_deg(:); gsLon_deg; satLon_deg(:)]) + 1.0;
latMin = min([rectLat_deg(:); gsLat_deg; satLat_deg(:)]) - 1.0;
latMax = max([rectLat_deg(:); gsLat_deg; satLat_deg(:)]) + 1.0;
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

function [satLon_deg, satLat_deg, satLabels, satPlaneLabels] = getSatelliteSubpointsLocal(root, satNames, tStr, sc)
satLon_deg = zeros(numel(satNames), 1);
satLat_deg = zeros(numel(satNames), 1);
satLabels = strings(numel(satNames), 1);
satPlaneLabels = strings(numel(satNames), 1);
for i = 1:numel(satNames)
    satName = satNames(i);
    satObj = root.GetObjectFromPath(['*/Satellite/' char(satName)]);
    [lat_deg, lon_deg] = getSatelliteSubpointLatLonLocal(satObj, tStr, sc);
    satLon_deg(i) = lon_deg;
    satLat_deg(i) = lat_deg;
    satLabels(i) = satName;
    parts = split(satName, '_');
    satPlaneLabels(i) = parts(1);
end
end

function [lat_deg, lon_deg] = getSatelliteSubpointLatLonLocal(satObj, tStr, sc)
dpLLA = satObj.DataProviders.Item('LLA State').Group.Item('Fixed');
try
    res = dpLLA.ExecSingle(tStr);
catch
    res = dpLLA.ExecSingle(char(sc.StartTime));
end
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
