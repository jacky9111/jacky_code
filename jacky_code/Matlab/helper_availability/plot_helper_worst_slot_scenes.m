function plot_helper_worst_slot_scenes(caseResults, cfg)
%PLOT_HELPER_WORST_SLOT_SCENES Map of critical + helper sats at worst EPFD slot.
% For each constellation geometry:
%   1) Pick t_worst = argmax(aggregate EPFD before shutdown)
%   2) Recompute visibility / critical / helpers at that single slot
%   3) Cross-check against the stored criticalRecord from the time sweep
%   4) Save a lon/lat scene figure under results/figures/
%
% This corroborates the helper-availability numbers and verifies the
% identification code on the most dangerous GS moment.

figDir = cfg.io.figuresDir;
if ~exist(figDir, 'dir')
    mkdir(figDir);
end
outDirs = {figDir};
if isfield(cfg.io, 'matlabDataDir') && strlength(string(cfg.io.matlabDataDir)) > 0
    if ~exist(cfg.io.matlabDataDir, 'dir')
        mkdir(cfg.io.matlabDataDir);
    end
    outDirs{end+1} = cfg.io.matlabDataDir; %#ok<AGROW>
end
common = cfg.common;

fprintf('\n----- Worst-slot critical/helper scene snapshots -----\n');
for i = 1:numel(caseResults)
    cr = caseResults{i};
    tag = sanitize_name(cr.name);
    c = find_constellation_by_name(cfg.constellations, cr.name);
    if isempty(c)
        warning('plot_helper_worst_slot_scenes:MissingConstellation', ...
            'Skip "%s": constellation config not found.', cr.name);
        continue;
    end

    ts = cr.timeSeries;
    [peakEpfd_dB, iWorst] = max(ts.aggEpfdBefore_dB);
    if ~isfinite(peakEpfd_dB)
        warning('plot_helper_worst_slot_scenes:NoEpfd', ...
            'Skip "%s": no finite aggregate EPFD samples.', cr.name);
        continue;
    end
    tWorst_s = ts.t_s(iWorst);

    snap = rebuild_slot_snapshot(c, common, tWorst_s);
    stored = cr.criticalRecord(iWorst);
    verify = verify_against_stored(snap, stored);

    fprintf(['  %s: t_worst=%d s, EPFD_before=%.2f dB, nCrit=%d, ' ...
        'helpers/crit=%.2f, closedBeams=%d | verify match=%s\n'], ...
        cr.name, tWorst_s, peakEpfd_dB, snap.nCritical, ...
        snap.avgHelpers, snap.nClosedBeams, string(verify.ok));
    if ~verify.ok
        warning('plot_helper_worst_slot_scenes:Mismatch', ...
            '%s worst-slot recomputation differs from stored record: %s', ...
            cr.name, verify.message);
    end

    for d = 1:numel(outDirs)
        basePath = fullfile(outDirs{d}, sprintf('%s_6_worst_slot_scene', tag));
        save_scene_figure(snap, common, cr.name, tWorst_s, peakEpfd_dB, basePath);
    end
end
fprintf('Saved worst-slot scene figures to: %s\n', strjoin(outDirs, ' | '));
end

function snap = rebuild_slot_snapshot(constellation, common, t_s)
beam = common.beam;
P = common.params;
geom = generate_constellation_geometry(constellation, common);
[geom, ~] = align_reference_satellite_over_gs(geom, common);
satNames = string({geom.sats.name}.');
state = propagate_satellites(geom, common, t_s);

P_gs_km = common.Re_km * [cosd(common.gsLat_deg) * cosd(common.gsLon_deg); ...
                          cosd(common.gsLat_deg) * sind(common.gsLon_deg); ...
                          sind(common.gsLat_deg)];
P_geo_km = common.Rgeo_km * [cosd(common.gsoLon_deg); sind(common.gsoLon_deg); 0];

pos_all = state.pos_ecef_km(:, :, 1);
vel_all = state.vel_ecef_kmps(:, :, 1);
subLat = state.subLat_deg(:, 1);
subLon = state.subLon_deg(:, 1);

vis = get_visible_satellites(pos_all, P_gs_km, common.minElev_deg);
visIdx = vis.idx;
nVis = numel(visIdx);
fpCell = cell(1, nVis);
boresights_vis = cell(1, nVis);
for k = 1:nVis
    gi = visIdx(k);
    fp = generate_beam_footprints(pos_all(:, gi), vel_all(:, gi), beam, common.Re_km);
    fpCell{k} = fp;
    boresights_vis{k} = [fp.boresight];
end

slot = identify_critical_satellites(visIdx, pos_all(:, visIdx), boresights_vis, ...
    P_gs_km, P_geo_km, P, beam, common.epfdThr_dB);
slotHelper = identify_recovery_helpers(slot, fpCell, satNames, common);

critLocal = find(slot.isCritical(:).');
critGlobal = visIdx(critLocal);
helperGlobal = [];
helperNames = strings(0, 1);
for cc = 1:numel(slotHelper.satellites)
    ids = slotHelper.satellites(cc).helperSatelliteIds;
    for hh = 1:numel(ids)
        gi = find(satNames == ids(hh), 1);
        if ~isempty(gi) && ~any(helperGlobal == gi)
            helperGlobal(end+1) = gi; %#ok<AGROW>
            helperNames(end+1, 1) = ids(hh); %#ok<AGROW>
        end
    end
end

% Closed-beam polygons of critical sats (for scene corroboration).
closedPolys = struct('lat', {}, 'lon', {});
for cc = 1:numel(critLocal)
    iLoc = critLocal(cc);
    closedBeams = find(slot.closedMask(iLoc, :));
    fp = fpCell{iLoc};
    for jb = 1:numel(closedBeams)
        b = closedBeams(jb);
        if fp(b).valid && ~isempty(fp(b).polyLat)
            closedPolys(end+1).lat = fp(b).polyLat; %#ok<AGROW>
            closedPolys(end).lon = fp(b).polyLon;
        end
    end
end

snap = struct();
snap.t_s = t_s;
snap.subLat = subLat;
snap.subLon = subLon;
snap.visIdx = visIdx;
snap.critGlobal = critGlobal(:);
snap.helperGlobal = helperGlobal(:);
snap.helperNames = helperNames;
snap.critNames = satNames(critGlobal);
snap.nCritical = numel(critGlobal);
snap.nHelpers = numel(helperGlobal);
snap.nClosedBeams = slot.nShut;
snap.avgHelpers = mean(slotHelper.instanceNumHelpers);
if isempty(slotHelper.instanceNumHelpers)
    snap.avgHelpers = NaN;
end
snap.closedPolys = closedPolys;
snap.slotHelper = slotHelper;
snap.satNames = satNames;
snap.aggBefore_dB = 10 * log10(max(slot.aggBefore_lin, 1e-300));
snap.aggAfter_dB = 10 * log10(max(slot.aggAfter_lin, 1e-300));
end

function verify = verify_against_stored(snap, stored)
verify = struct('ok', true, 'message', "");
storedSats = stored.satellites;
if isempty(storedSats)
    nStoredCrit = 0;
    storedHelperCounts = [];
    storedCritNames = strings(0, 1);
else
    nStoredCrit = numel(storedSats);
    storedHelperCounts = arrayfun(@(s) s.numHelpers, storedSats);
    storedCritNames = string({storedSats.satelliteId}.');
end

if nStoredCrit ~= snap.nCritical
    verify.ok = false;
    verify.message = sprintf('nCrit stored=%d recomputed=%d', nStoredCrit, snap.nCritical);
    return;
end
if nStoredCrit == 0
    return;
end

% Compare by satellite id (order-independent).
recompNames = string(snap.critNames(:));
if ~isempty(setxor(storedCritNames, recompNames))
    verify.ok = false;
    verify.message = 'critical satellite id sets differ';
    return;
end

recompCounts = zeros(nStoredCrit, 1);
for k = 1:nStoredCrit
    match = find(recompNames == storedCritNames(k), 1);
    if isempty(match)
        verify.ok = false;
        verify.message = sprintf('missing critical %s', storedCritNames(k));
        return;
    end
    recompCounts(k) = snap.slotHelper.satellites(match).numHelpers;
end
if any(recompCounts(:) ~= storedHelperCounts(:))
    verify.ok = false;
    verify.message = sprintf('helper counts differ (stored mean=%.2f, recomputed mean=%.2f)', ...
        mean(storedHelperCounts), mean(recompCounts));
    return;
end
end

function save_scene_figure(snap, common, name, tWorst_s, peakEpfd_dB, basePath)
fig = figure('Color', 'w', 'Visible', 'off', 'Units', 'inches', ...
    'Position', [1 1 6.2 5.2]);
ax = axes('Parent', fig);
hold(ax, 'on');

% Closed-beam footprints first (background).
for p = 1:numel(snap.closedPolys)
    fill(ax, wrap_lon_for_plot(snap.closedPolys(p).lon), snap.closedPolys(p).lat, ...
        [1.0 0.80 0.80], 'EdgeColor', [0.75 0.20 0.20], 'LineWidth', 0.6, ...
        'FaceAlpha', 0.25, 'HandleVisibility', 'off');
end

% Visible satellites.
if ~isempty(snap.visIdx)
    plot(ax, wrap_lon_for_plot(snap.subLon(snap.visIdx)), snap.subLat(snap.visIdx), ...
        '.', 'Color', [0.65 0.65 0.65], 'MarkerSize', 8, 'DisplayName', 'Visible satellites');
end

% Helper satellites.
if ~isempty(snap.helperGlobal)
    plot(ax, wrap_lon_for_plot(snap.subLon(snap.helperGlobal)), ...
        snap.subLat(snap.helperGlobal), 'o', 'Color', [0.00 0.45 0.74], ...
        'MarkerFaceColor', [0.30 0.70 1.00], 'MarkerSize', 7, ...
        'LineWidth', 1.0, 'DisplayName', 'Recovery-capable helpers');
end

% Critical satellites.
if ~isempty(snap.critGlobal)
    plot(ax, wrap_lon_for_plot(snap.subLon(snap.critGlobal)), ...
        snap.subLat(snap.critGlobal), 's', 'Color', [0.70 0.05 0.05], ...
        'MarkerFaceColor', [0.95 0.25 0.25], 'MarkerSize', 9, ...
        'LineWidth', 1.1, 'DisplayName', 'Critical satellites');
end

% Links: each critical -> its helpers.
for cc = 1:numel(snap.slotHelper.satellites)
    cName = string(snap.slotHelper.satellites(cc).satelliteId);
    iCrit = find(snap.satNames == cName, 1);
    if isempty(iCrit)
        continue;
    end
    hNames = string(snap.slotHelper.satellites(cc).helperSatelliteIds);
    for hh = 1:numel(hNames)
        iHelp = find(snap.satNames == hNames(hh), 1);
        if isempty(iHelp)
            continue;
        end
        lonPair = wrap_lon_pair(snap.subLon(iCrit), snap.subLon(iHelp));
        plot(ax, lonPair, [snap.subLat(iCrit), snap.subLat(iHelp)], '-', ...
            'Color', [0.35 0.55 0.80], 'LineWidth', 0.7, 'HandleVisibility', 'off');
    end
end

% Ground station.
plot(ax, common.gsLon_deg, common.gsLat_deg, '^', 'Color', 'k', ...
    'MarkerFaceColor', [1 0.85 0], 'MarkerSize', 10, 'LineWidth', 1.1, ...
    'DisplayName', 'GS');

grid(ax, 'on');
box(ax, 'on');
axis(ax, 'equal');
xlabel(ax, 'Longitude (deg)');
ylabel(ax, 'Latitude (deg)');
title(ax, {sprintf('%s: worst-EPFD slot scene', name), ...
    sprintf('t = %d s, EPFD_{before} = %.2f dB, N_{crit} = %d, N_{helpers} = %d, closed beams = %d', ...
    tWorst_s, peakEpfd_dB, snap.nCritical, snap.nHelpers, snap.nClosedBeams)}, ...
    'Interpreter', 'tex');
legend(ax, 'Location', 'bestoutside');
ax.FontName = 'Times New Roman';
ax.FontSize = 10;
hold(ax, 'off');

% Focus around GS / scene content.
allLat = common.gsLat_deg;
allLon = common.gsLon_deg;
if ~isempty(snap.visIdx)
    allLat = [allLat; snap.subLat(snap.visIdx)];
    allLon = [allLon; wrap_lon_for_plot(snap.subLon(snap.visIdx))];
end
for p = 1:numel(snap.closedPolys)
    allLat = [allLat; snap.closedPolys(p).lat(:)]; %#ok<AGROW>
    allLon = [allLon; wrap_lon_for_plot(snap.closedPolys(p).lon(:))]; %#ok<AGROW>
end
padLat = max(3, 0.15 * max(max(allLat) - min(allLat), 1));
padLon = max(3, 0.15 * max(max(allLon) - min(allLon), 1));
xlim(ax, [min(allLon) - padLon, max(allLon) + padLon]);
ylim(ax, [min(allLat) - padLat, max(allLat) + padLat]);

set(fig, 'Color', 'w', 'InvertHardcopy', 'off', 'PaperPositionMode', 'auto');
print(fig, [basePath '.png'], '-dpng', '-r300');
savefig(fig, [basePath '.fig']);
close(fig);
end

function c = find_constellation_by_name(constellations, name)
c = [];
target = string(name);
for i = 1:numel(constellations)
    if string(constellations{i}.name) == target
        c = constellations{i};
        return;
    end
end
end

function lon = wrap_lon_for_plot(lon)
% Keep longitudes continuous near the plotted scene (no hard wrap jumps).
lon = lon(:);
if isempty(lon)
    return;
end
lon = mod(lon + 180, 360) - 180;
end

function lonPair = wrap_lon_pair(lon1, lon2)
lon1 = wrap_lon_for_plot(lon1);
lon2 = wrap_lon_for_plot(lon2);
if abs(lon2 - lon1) > 180
    if lon2 > lon1
        lon1 = lon1 + 360;
    else
        lon2 = lon2 + 360;
    end
end
lonPair = [lon1, lon2];
end

function s = sanitize_name(name)
s = regexprep(char(name), '[^A-Za-z0-9]+', '_');
s = regexprep(s, '_+', '_');
s = regexprep(s, '^_|_$', '');
end
