function result = RunDenseOverlapEpfdShutdownSnapshotLocal(opts)
% RunDenseOverlapEpfdShutdownSnapshotLocal
% Pure-MATLAB snapshot: 5 orbits x 10 sats with 50% N-S / E-W footprint overlap,
% -3 dB 16-beam rectangles on middle orbit.
% opts.gsPlacement:
%   'between_mid_pair' — GS along-track between sats 5 and 6 (default)
%   'under_sat'        — GS along-track under opts.gsAnchorSatIdx (default 5)
% opts.gsRelLon_deg: GS longitude offset from middle-orbit ground track (deg).
%   GS lon = orbitLon_deg + gsRelLon_deg; 0 => GS on the middle orbit track.
% Runs the same greedy EPFD beam-shutdown as full-power sweep and plots shut beams.

if nargin < 1 || isempty(opts)
    opts = struct();
end
opts = applyDenseSnapshotDefaultsLocal(opts);

Re_km = 6378.137;
alt_km = double(opts.alt_km);
beamHalfEW_deg = double(opts.beamHalfEW_deg);
beamHalfNS_total_deg = double(opts.beamHalfNS_total_deg);
beamHalfNS_deg = beamHalfNS_total_deg / 16;
nOrbit = double(opts.nOrbit);
nSatPerOrbit = double(opts.nSatPerOrbit);
gsLat_deg = double(opts.gsLat_deg);
orbitLon_deg = double(opts.orbitLon_deg);   % middle-orbit ground track longitude
gsRelLon_deg = double(opts.gsRelLon_deg);   % GS relative lon from middle orbit
gsLon_deg = orbitLon_deg + gsRelLon_deg;    % absolute GS longitude

% Ground footprint half-extents (flat-Earth nadir approx, same style as jacky.m).
halfNS_km = alt_km * tand(beamHalfNS_total_deg);
halfEW_km = alt_km * tand(beamHalfEW_deg);
spacingMode = lower(string(opts.satSpacingMode));
switch spacingMode
    case "starlink_density"
        % Local square-lattice spacing with the same surface density as a
        % representative Starlink shell. Beam geometry is still OneWeb-like.
        starlinkTotalSats = double(opts.starlinkDensityTotalSats);
        spacingAlong_km = sqrt(4 * pi * Re_km^2 / starlinkTotalSats);
        spacingCross_km = spacingAlong_km;
    otherwise
        % 50% overlap => adjacent spacing = half footprint extent.
        spacingAlong_km = halfNS_km;
        spacingCross_km = halfEW_km;
end

midOrbit = (nOrbit + 1) / 2;
assert(abs(midOrbit - round(midOrbit)) < 1e-9, 'nOrbit must be odd so a middle orbit exists.');
midOrbit = round(midOrbit);

gsPlacement = lower(char(string(opts.gsPlacement)));
gsAnchorSatIdx = round(double(opts.gsAnchorSatIdx));
assert(gsAnchorSatIdx >= 1 && gsAnchorSatIdx <= nSatPerOrbit, ...
    'opts.gsAnchorSatIdx must be in 1..nSatPerOrbit.');

% Along-track placement relative to GS on middle orbit.
satIdx = (1:nSatPerOrbit).';
switch gsPlacement
    case 'under_sat'
        % GS directly under middle-orbit sat gsAnchorSatIdx (e.g. S05).
        alongOffset_km = (satIdx - gsAnchorSatIdx) * spacingAlong_km;
        gsPlaceDesc = sprintf('under P%02d_S%02d', midOrbit, gsAnchorSatIdx);
    case 'between_mid_pair'
        % GS between sat N and N+1 (default N=5 for 10 sats).
        alongOffset_km = (satIdx - (gsAnchorSatIdx + 0.5)) * spacingAlong_km;
        gsPlaceDesc = sprintf('between P%02d_S%02d and S%02d', ...
            midOrbit, gsAnchorSatIdx, gsAnchorSatIdx + 1);
    otherwise
        error('opts.gsPlacement must be ''between_mid_pair'' or ''under_sat''.');
end
crossOffset_km = ((1:nOrbit) - midOrbit) * spacingCross_km;

nSat = nOrbit * nSatPerOrbit;
satNames = strings(nSat, 1);
planeLabels = strings(nSat, 1);
satLat_deg = zeros(nSat, 1);
satLon_deg = zeros(nSat, 1);
P_leo_km = zeros(3, nSat);
V_leo_kmps = zeros(3, nSat);

k = 0;
for iOrbit = 1:nOrbit
    for iSat = 1:nSatPerOrbit
        k = k + 1;
        satNames(k) = sprintf('P%02d_S%02d', iOrbit, iSat);
        planeLabels(k) = sprintf('P%02d', iOrbit);
        % Near-polar: along-track ~ latitude, cross-track ~ longitude at equator.
        % Orbits are centered on orbitLon_deg; GS may be offset by gsRelLon_deg.
        satLat_deg(k) = gsLat_deg + (alongOffset_km(iSat) / Re_km) * (180 / pi);
        lonScale = max(cosd(satLat_deg(k)), 1e-6);
        satLon_deg(k) = orbitLon_deg + (crossOffset_km(iOrbit) / (Re_km * lonScale)) * (180 / pi);
        r_km = Re_km + alt_km;
        P_leo_km(:, k) = r_km * [ ...
            cosd(satLat_deg(k)) * cosd(satLon_deg(k)); ...
            cosd(satLat_deg(k)) * sind(satLon_deg(k)); ...
            sind(satLat_deg(k))];
        % Northbound velocity (local north), unit km/s scale only for direction.
        V_leo_kmps(:, k) = [ ...
            -sind(satLat_deg(k)) * cosd(satLon_deg(k)); ...
            -sind(satLat_deg(k)) * sind(satLon_deg(k)); ...
            cosd(satLat_deg(k))];
    end
end

pitchOffsets_deg = (8.5 - (1:16)) * (2 * beamHalfNS_deg);
satGeom = repmat(struct('satName', "", 'P_leo_km', [], 'b_all', [], 'c_axis', [], ...
    'subLat', [], 'subLon', [], 'plane', ""), nSat, 1);
for iSat = 1:nSat
    [b_all, c_axis] = beamBoresightsDenseLocal(P_leo_km(:, iSat) * 1000, V_leo_kmps(:, iSat) * 1000, pitchOffsets_deg);
    satGeom(iSat).satName = satNames(iSat);
    satGeom(iSat).plane = planeLabels(iSat);
    satGeom(iSat).P_leo_km = P_leo_km(:, iSat);
    satGeom(iSat).b_all = reorderBoresightsNorthToSouthDenseLocal(P_leo_km(:, iSat) * 1000, b_all);
    satGeom(iSat).c_axis = c_axis;
    satGeom(iSat).subLat = satLat_deg(iSat);
    satGeom(iSat).subLon = satLon_deg(iSat);
end

P_gs_km = (Re_km + 0) * [ ...
    cosd(gsLat_deg) * cosd(gsLon_deg); ...
    cosd(gsLat_deg) * sind(gsLon_deg); ...
    sind(gsLat_deg)];
P_geo_km = idealGsoXYZFromLongitudeDenseLocal(gsLon_deg);

P = opts.params;
P.EPFD_thr_dB = double(opts.epfdThr_dB);
fullBeamPower_W = double(opts.fullBeamPower_W);
threshold_lin = 10^(P.EPFD_thr_dB / 10);
Gmax_lin = 10^(P.GSO_Gmax_dBi / 10);
Gt_max_lin = max(P.A_fit, eps);
useEirpDens = isfield(P, 'useEIRPDensityModel') && P.useEIRPDensityModel;
if useEirpDens
    eirpRef_dBW = P.EIRPdens_dBW_per_4kHz + 10 * log10(P.BWref_Hz / 4000);
    eirpRef_lin = 10^(eirpRef_dBW / 10);
else
    eirpRef_lin = NaN;
end

rows = struct('sat', {}, 'plane', {}, 'beam', {}, 'epfd_lin', {}, ...
    'beam_pfd_contribution_dB', {}, 'initial_power_W', {}, 'final_power_W', {}, ...
    'shut_off', {}, 'shutdown_rank', {});
for iSat = 1:nSat
    P_leo = satGeom(iSat).P_leo_km;
    b_all = satGeom(iSat).b_all;
    c_axis = satGeom(iSat).c_axis;
    v_gs_m = (P_gs_km - P_leo) * 1000;
    d_m = norm(v_gs_m);
    for b = 1:16
        b_hat = b_all(:, b);
        if d_m < 1
            epfdLin = 0;
            beamPower_W = fullBeamPower_W;
        else
            d_hat = v_gs_m / d_m;
            phit = angleDegDenseLocal(b_hat, d_hat);
            Gt_lin = max(P.A_fit * exp(P.beta_fit * phit), 1e-30);
            alpha = angleDegDenseLocal(P_leo - P_gs_km, P_geo_km - P_gs_km);
            Gr_dBi = gso_rx_gain_itu1428(alpha, P.GSO_D_m, P.lambda_m);
            Gr_lin = 10^(Gr_dBi / 10);
            if useEirpDens
                Gt_rel = Gt_lin / Gt_max_lin;
                epfdLin = eirpRef_lin * Gt_rel * (1 / (4 * pi * d_m^2)) * (Gr_lin / Gmax_lin);
                beamPower_W = NaN;
            else
                epfdLin = (fullBeamPower_W / P.BWref_Hz) * (Gt_lin / (4 * pi * d_m^2)) * (Gr_lin / Gmax_lin);
                beamPower_W = fullBeamPower_W;
            end
        end
        rows(end + 1).sat = satNames(iSat); %#ok<AGROW>
        rows(end).plane = planeLabels(iSat);
        rows(end).beam = b;
        rows(end).epfd_lin = epfdLin;
        rows(end).beam_pfd_contribution_dB = 10 * log10(max(epfdLin, 1e-300));
        rows(end).initial_power_W = beamPower_W;
        rows(end).final_power_W = beamPower_W;
        rows(end).shut_off = 0;
        rows(end).shutdown_rank = NaN;
    end
end
Tbeam = struct2table(rows);

aggBefore_lin = sum(Tbeam.epfd_lin);
aggAfter_lin = aggBefore_lin;
linTol = threshold_lin * 1e-12;
slotViolated = aggAfter_lin > threshold_lin + linTol;
shutCount = 0;
if slotViolated
    [~, order] = sort(Tbeam.epfd_lin, 'descend');
    for kOrd = 1:numel(order)
        row = order(kOrd);
        if aggAfter_lin <= threshold_lin + linTol
            break;
        end
        aggAfter_lin = aggAfter_lin - Tbeam.epfd_lin(row);
        Tbeam.final_power_W(row) = 0;
        Tbeam.shut_off(row) = 1;
        Tbeam.shutdown_rank(row) = kOrd;
        shutCount = kOrd;
    end
end

satEpfd_lin = zeros(nSat, 1);
satShutCount = zeros(nSat, 1);
for iSat = 1:nSat
    mask = Tbeam.sat == satNames(iSat);
    satEpfd_lin(iSat) = sum(Tbeam.epfd_lin(mask));
    satShutCount(iSat) = sum(Tbeam.shut_off(mask) > 0);
end
criticalMask = satShutCount > 0;
criticalSats = satNames(criticalMask);
nCritical = numel(criticalSats);

aggBefore_dB = 10 * log10(max(aggBefore_lin, 1e-300));
aggAfter_dB = 10 * log10(max(aggAfter_lin, 1e-300));

fprintf('\n===== Dense-overlap EPFD snapshot (MATLAB only) =====\n');
fprintf('Orbits=%d, sats/orbit=%d, alt=%.0f km, -3dB halfEW=%.1f deg, halfNS_total=%.1f deg\n', ...
    nOrbit, nSatPerOrbit, alt_km, beamHalfEW_deg, beamHalfNS_total_deg);
fprintf('Spacing mode=%s, along-track=%.1f km, cross-track=%.1f km\n', ...
    char(spacingMode), spacingAlong_km, spacingCross_km);
fprintf('Middle-orbit lon=%.2f deg, GS rel lon=%.2f deg -> GS=(%.2f, %.2f), placement=%s\n', ...
    orbitLon_deg, gsRelLon_deg, gsLat_deg, gsLon_deg, gsPlaceDesc);
fprintf('Aggregate EPFD before=%.3f dB, after=%.3f dB, thr=%.1f dB\n', ...
    aggBefore_dB, aggAfter_dB, P.EPFD_thr_dB);
fprintf('Shut beams=%d, critical satellites=%d\n', shutCount, nCritical);
if nCritical > 0
    for iC = 1:nCritical
        iSat = find(satNames == criticalSats(iC), 1);
        maskSat = Tbeam.sat == criticalSats(iC);
        Tshut = sortrows(Tbeam(maskSat & Tbeam.shut_off > 0, :), 'shutdown_rank', 'ascend');
        shutBeams = double(Tshut.beam(:)).';
        shutRanks = double(Tshut.shutdown_rank(:)).';
        beamListStr = strjoin(compose('B%02d', shutBeams), ', ');
        rankListStr = strjoin(compose('%d', shutRanks), ', ');
        fprintf('  %s: shut %d/16 beams, sat EPFD contrib=%.3f dB\n', ...
            criticalSats(iC), satShutCount(iSat), 10 * log10(max(satEpfd_lin(iSat), 1e-300)));
        fprintf('    shut beams: %s\n', beamListStr);
        fprintf('    shutdown rank (global order): %s\n', rankListStr);
    end
else
    fprintf('  (no beam shutdown needed)\n');
end
if nCritical >= 2
    fprintf('NOTE: >=2 critical satellites under dense overlap at this snapshot.\n');
end

plotDenseOverlapShutdownMapLocal(satGeom, Tbeam, gsLat_deg, gsLon_deg, ...
    halfEW_km, halfNS_km, criticalSats, opts, gsPlaceDesc);

criticalShutBeams = cell(nCritical, 1);
for iC = 1:nCritical
    maskSat = Tbeam.sat == criticalSats(iC) & Tbeam.shut_off > 0;
    Tshut = sortrows(Tbeam(maskSat, :), 'shutdown_rank', 'ascend');
    criticalShutBeams{iC} = double(Tshut.beam(:)).';
end

result = struct();
result.satNames = satNames;
result.planeLabels = planeLabels;
result.satLat_deg = satLat_deg;
result.satLon_deg = satLon_deg;
result.Tbeam = Tbeam;
result.criticalSats = criticalSats;
result.criticalShutBeams = criticalShutBeams;
result.nCritical = nCritical;
result.satShutCount = satShutCount;
result.satEpfd_lin = satEpfd_lin;
result.aggBefore_dB = aggBefore_dB;
result.aggAfter_dB = aggAfter_dB;
result.epfdThr_dB = P.EPFD_thr_dB;
result.spacingAlong_km = spacingAlong_km;
result.spacingCross_km = spacingCross_km;
result.satSpacingMode = spacingMode;
result.starlinkDensityTotalSats = opts.starlinkDensityTotalSats;
result.halfEW_km = halfEW_km;
result.halfNS_km = halfNS_km;
result.gsLat_deg = gsLat_deg;
result.gsLon_deg = gsLon_deg;
result.orbitLon_deg = orbitLon_deg;
result.gsRelLon_deg = gsRelLon_deg;
result.gsPlacement = string(gsPlacement);
result.gsAnchorSatIdx = gsAnchorSatIdx;
result.gsPlaceDesc = string(gsPlaceDesc);
end

function opts = applyDenseSnapshotDefaultsLocal(opts)
if ~isfield(opts, 'alt_km') || ~isfinite(opts.alt_km), opts.alt_km = 1200; end
if ~isfield(opts, 'nOrbit') || ~isfinite(opts.nOrbit), opts.nOrbit = 5; end
if ~isfield(opts, 'nSatPerOrbit') || ~isfinite(opts.nSatPerOrbit), opts.nSatPerOrbit = 10; end
if ~isfield(opts, 'satSpacingMode') || strlength(string(opts.satSpacingMode)) == 0
    opts.satSpacingMode = 'footprint_overlap';
end
if ~isfield(opts, 'starlinkDensityTotalSats') || ~isfinite(opts.starlinkDensityTotalSats)
    opts.starlinkDensityTotalSats = 1584;
end
if ~isfield(opts, 'gsLat_deg') || ~isfinite(opts.gsLat_deg), opts.gsLat_deg = 0; end
% Middle-orbit ground-track longitude (legacy: opts.gsLon_deg).
if ~isfield(opts, 'orbitLon_deg') || ~isfinite(opts.orbitLon_deg)
    if isfield(opts, 'gsLon_deg') && isfinite(opts.gsLon_deg)
        opts.orbitLon_deg = opts.gsLon_deg;
    else
        opts.orbitLon_deg = 120.4;
    end
end
% GS longitude relative to middle orbit: GS_lon = orbitLon_deg + gsRelLon_deg.
if ~isfield(opts, 'gsRelLon_deg') || ~isfinite(opts.gsRelLon_deg)
    opts.gsRelLon_deg = 0;
end
if ~isfield(opts, 'gsPlacement') || strlength(string(opts.gsPlacement)) == 0
    opts.gsPlacement = 'between_mid_pair';
end
if ~isfield(opts, 'gsAnchorSatIdx') || ~isfinite(opts.gsAnchorSatIdx)
    opts.gsAnchorSatIdx = 5;
end
% Standard -3 dB rectangle (same as CreateOneWeb16BeamsKu / paper).
if ~isfield(opts, 'beamHalfEW_deg') || ~isfinite(opts.beamHalfEW_deg), opts.beamHalfEW_deg = 24.5; end
if ~isfield(opts, 'beamHalfNS_total_deg') || ~isfinite(opts.beamHalfNS_total_deg)
    opts.beamHalfNS_total_deg = 25.0;
end
if ~isfield(opts, 'fullBeamPower_W') || ~isfinite(opts.fullBeamPower_W), opts.fullBeamPower_W = 1.05; end
if ~isfield(opts, 'epfdThr_dB') || ~isfinite(opts.epfdThr_dB), opts.epfdThr_dB = -173.4; end
if ~isfield(opts, 'params') || isempty(opts.params)
    opts.params = ku_epfd_params();
end
opts.params.useEIRPDensityModel = false;
opts.params.Ptotal_W = opts.fullBeamPower_W * 16;
if ~isfield(opts, 'showFigure') || isempty(opts.showFigure), opts.showFigure = true; end
if ~isfield(opts, 'figurePath') || strlength(string(opts.figurePath)) == 0
    opts.figurePath = "";
end
end

function plotDenseOverlapShutdownMapLocal(satGeom, Tbeam, gsLat_deg, gsLon_deg, ...
    halfEW_km, halfNS_km, criticalSats, opts, gsPlaceDesc)
if nargin < 9 || strlength(string(gsPlaceDesc)) == 0
    gsPlaceDesc = 'GS placement';
end
wantSave = isfield(opts, 'figurePath') && strlength(string(opts.figurePath)) > 0;
if ~opts.showFigure && ~wantSave
    return;
end

nSat = numel(satGeom);
planeList = unique(string({satGeom.plane}), 'stable');
planeColors = lines(max(numel(planeList), 1));

fig = figure('Name', sprintf('Dense-overlap EPFD shutdown (%s)', gsPlaceDesc), ...
    'Color', 'w', 'Visible', ternaryDenseLocal(opts.showFigure, 'on', 'off'));
ax = axes('Parent', fig);
hold(ax, 'on');
grid(ax, 'on');
box(ax, 'on');

hatchLegendDrawn = false;
for iSat = 1:nSat
    plane = string(satGeom(iSat).plane);
    iPlane = find(planeList == plane, 1);
    satColor = planeColors(iPlane, :);
    [rectLon, rectLat] = footprintRectDenseLocal(satGeom(iSat).subLat, satGeom(iSat).subLon, ...
        halfEW_km, halfNS_km);
    showFieldLegend = iSat == find(string({satGeom.plane}) == plane, 1, 'first');
    patch(ax, 'XData', rectLon([1 2 3 4 1]), 'YData', rectLat([1 2 3 4 1]), ...
        'FaceColor', satColor, 'FaceAlpha', 0.04, ...
        'EdgeColor', satColor, 'LineStyle', '-', 'LineWidth', 0.9, ...
        'HandleVisibility', ternaryDenseLocal(showFieldLegend, 'on', 'off'), ...
        'DisplayName', sprintf('%s field', plane));

    [bandLonCells, bandLatCells] = beamBandLinesDenseLocal(rectLon, rectLat, 16);
    for kBand = 1:numel(bandLonCells)
        plot(ax, bandLonCells{kBand}, bandLatCells{kBand}, '--', ...
            'Color', satColor, 'LineWidth', 0.5, 'HandleVisibility', 'off');
    end

    mask = Tbeam.sat == satGeom(iSat).satName;
    Tsat = Tbeam(mask, :);
    shutBeams = double(Tsat.beam(Tsat.shut_off > 0));
    for b = shutBeams(:).'
        drawShutBeamHatchDenseLocal(ax, rectLon, rectLat, b, satColor);
        if ~hatchLegendDrawn
            plot(ax, nan, nan, '-', 'Color', [0.2 0.2 0.2], 'LineWidth', 1.4, ...
                'DisplayName', 'Shut beam');
            hatchLegendDrawn = true;
        end
    end
end

for iSat = 1:nSat
    plane = string(satGeom(iSat).plane);
    iPlane = find(planeList == plane, 1);
    satColor = planeColors(iPlane, :);
    isCrit = any(criticalSats == satGeom(iSat).satName);
    if isCrit
        scatter(ax, satGeom(iSat).subLon, satGeom(iSat).subLat, 70, ...
            'Marker', 'o', 'MarkerEdgeColor', 'k', 'MarkerFaceColor', satColor, ...
            'LineWidth', 1.2, 'HandleVisibility', 'off');
    else
        scatter(ax, satGeom(iSat).subLon, satGeom(iSat).subLat, 36, ...
            'Marker', 'o', 'MarkerEdgeColor', satColor, 'MarkerFaceColor', satColor, ...
            'HandleVisibility', 'off');
    end
    text(ax, satGeom(iSat).subLon + 0.15, satGeom(iSat).subLat + 0.12, ...
        char(satGeom(iSat).satName), 'FontSize', 7, 'Interpreter', 'none', ...
        'Color', [0.1 0.1 0.1]);
end

plot(ax, gsLon_deg, gsLat_deg, 'p', 'MarkerSize', 14, ...
    'MarkerFaceColor', [0.93 0.69 0.13], 'MarkerEdgeColor', 'k', 'DisplayName', 'GS');
text(ax, gsLon_deg + 0.2, gsLat_deg + 0.25, 'GS', 'FontSize', 9, 'FontWeight', 'bold');

% Orbit ground tracks (vertical lines at each plane longitude near equator).
for iPlane = 1:numel(planeList)
    mask = string({satGeom.plane}) == planeList(iPlane);
    lonTrack = mean([satGeom(mask).subLon]);
    latMin = min([satGeom(mask).subLat]) - halfNS_km / 111.32;
    latMax = max([satGeom(mask).subLat]) + halfNS_km / 111.32;
    plot(ax, [lonTrack lonTrack], [latMin latMax], 'k-', 'LineWidth', 0.8, ...
        'HandleVisibility', 'off');
end

xlabel(ax, 'Longitude (deg)');
ylabel(ax, 'Latitude (deg)');
legend(ax, 'Location', 'eastoutside');
axis(ax, 'equal');
hold(ax, 'off');

if strlength(string(opts.figurePath)) > 0
    figDir = fileparts(char(string(opts.figurePath)));
    if ~isempty(figDir) && ~exist(figDir, 'dir')
        mkdir(figDir);
    end
    saveas(fig, char(string(opts.figurePath)));
    fprintf('Saved figure: %s\n', char(string(opts.figurePath)));
end
if ~opts.showFigure && isgraphics(fig)
    close(fig);
end
end

function [rectLon, rectLat] = footprintRectDenseLocal(lat_deg, lon_deg, halfEW_km, halfNS_km)
dLat = halfNS_km / 111.32;
lonScale = max(cosd(lat_deg), 1e-6);
dLon = halfEW_km / (111.32 * lonScale);
rectLon = [lon_deg - dLon, lon_deg + dLon, lon_deg + dLon, lon_deg - dLon];
rectLat = [lat_deg - dLat, lat_deg - dLat, lat_deg + dLat, lat_deg + dLat];
end

function [bandLonCells, bandLatCells] = beamBandLinesDenseLocal(rectLon, rectLat, numBands)
bandLonCells = {};
bandLatCells = {};
latEdges = linspace(min(rectLat), max(rectLat), numBands + 1);
for k = 2:numBands
    bandLonCells{end + 1, 1} = [min(rectLon), max(rectLon)]; %#ok<AGROW>
    bandLatCells{end + 1, 1} = [latEdges(k), latEdges(k)]; %#ok<AGROW>
end
end

function drawShutBeamHatchDenseLocal(ax, rectLon, rectLat, beamIdx, satColor)
lonMin = min(rectLon);
lonMax = max(rectLon);
latMin = min(rectLat);
latMax = max(rectLat);
bandHeight = (latMax - latMin) / 16;
latTop = latMax - (beamIdx - 1) * bandHeight;
latBottom = latTop - bandHeight;
patch(ax, 'XData', [lonMin lonMax lonMax lonMin lonMin], ...
    'YData', [latBottom latBottom latTop latTop latBottom], ...
    'FaceColor', satColor, 'FaceAlpha', 0.12, ...
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
    plot(ax, [x1 x2], [y1 y2], '-', 'Color', satColor, 'LineWidth', 1.2, 'HandleVisibility', 'off');
end
end

function [b_all, c_axis] = beamBoresightsDenseLocal(r_sat_m, v_sat_mps, pitchOffsets_deg)
n_hat = r_sat_m / max(norm(r_sat_m), eps);
v_perp = v_sat_mps - dot(v_sat_mps, n_hat) * n_hat;
t_hat = v_perp / max(norm(v_perp), eps);
c_axis = cross(n_hat, t_hat);
c_axis = c_axis / max(norm(c_axis), eps);
b0 = -n_hat;
b_all = zeros(3, numel(pitchOffsets_deg));
for k = 1:numel(pitchOffsets_deg)
    b_all(:, k) = rodriguesDenseLocal(b0, c_axis, deg2rad(pitchOffsets_deg(k)));
end
end

function b_sorted = reorderBoresightsNorthToSouthDenseLocal(r_sat_m, b_all)
Re_m = 6378137.0;
nb = size(b_all, 2);
lat_deg = -inf(1, nb);
for k = 1:nb
    hit = rayEarthIntersectDenseLocal(r_sat_m, b_all(:, k), Re_m);
    if ~isempty(hit)
        lat_deg(k) = asind(hit(3) / max(norm(hit), eps));
    end
end
[~, idx] = sort(lat_deg, 'descend');
b_sorted = b_all(:, idx);
end

function hit = rayEarthIntersectDenseLocal(r_s_m, d_unit, Re_m)
a = 1.0;
b = 2.0 * dot(r_s_m, d_unit);
c = dot(r_s_m, r_s_m) - Re_m^2;
disc = b^2 - 4 * a * c;
if disc < 0
    hit = [];
    return;
end
s = sqrt(disc);
lam1 = (-b - s) / 2.0;
lam2 = (-b + s) / 2.0;
cand = [lam1, lam2];
cand = cand(cand > 0);
if isempty(cand)
    hit = [];
    return;
end
hit = r_s_m + min(cand) * d_unit;
end

function v = rodriguesDenseLocal(u, k, ang)
v = u * cos(ang) + cross(k, u) * sin(ang) + k * dot(k, u) * (1 - cos(ang));
v = v / max(norm(v), eps);
end

function P_geo_km = idealGsoXYZFromLongitudeDenseLocal(lon_deg)
R_geo_km = 42164.0;
P_geo_km = R_geo_km * [cosd(lon_deg); sind(lon_deg); 0];
end

function a = angleDegDenseLocal(x, y)
a = acosd(max(-1, min(1, dot(x, y) / (norm(x) * norm(y) + eps))));
end

function out = ternaryDenseLocal(cond, a, b)
if cond
    out = a;
else
    out = b;
end
end
