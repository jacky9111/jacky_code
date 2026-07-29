function out = main_worst_slot_schematic(cfg)
%MAIN_WORST_SLOT_SCHEMATIC Draw critical/helper scene at worst EPFD only.
% For each density variant (OneWeb-like reference / High-density / Low-density):
%   1) Search aggregate EPFD over the flyover window to find t_worst
%      (no helper identification on every slot)
%   2) At t_worst only: identify critical sats + recovery-capable helpers
%   3) Geographic lon/lat scene: each shown satellite's sub-point + all 16
%      actual ray/Earth beam footprints (closed beams highlighted on critical)
%
% Usage:
%   out = main_worst_slot_schematic();
% Subset rows with select_helper_constellations(cfg, "Low-density") before calling.

if nargin < 1 || isempty(cfg)
    moduleDir = fileparts(mfilename('fullpath'));
    addpath(moduleDir);
    addpath(fullfile(moduleDir, '..', 'jacky'));
    addpath(fullfile(moduleDir, '..', 'powertilt'));
    cfg = config_helper_availability();
end

if ~exist(cfg.io.resultsDir, 'dir')
    mkdir(cfg.io.resultsDir);
end
if ~exist(cfg.io.figuresDir, 'dir')
    mkdir(cfg.io.figuresDir);
end
if isfield(cfg.io, 'matlabDataDir') && ~exist(cfg.io.matlabDataDir, 'dir')
    mkdir(cfg.io.matlabDataDir);
end

fprintf('\n===== Worst-EPFD scenes (SSP + 16 beams, critical/helpers) =====\n');
N = numel(cfg.constellations);
scenes = cell(1, N);
for i = 1:N
    c = cfg.constellations{i};
    fprintf('\n----- [%d/%d] %s -----\n', i, N, c.name);
    scenes{i} = build_and_plot_worst_schematic(c, cfg);
    fprintf('  t_worst=%d s | N_crit=%d | N_helpers=%d | closedBeams=%d\n', ...
        scenes{i}.tWorst_s, scenes{i}.nCritical, scenes{i}.nHelpers, ...
        scenes{i}.nClosedBeams);
    fprintf('  Saved: %s\n', scenes{i}.pngPath);
end

out = struct();
out.scenes = scenes;
out.cfg = cfg;
end

function scene = build_and_plot_worst_schematic(constellation, cfg)
common = cfg.common;
beam = common.beam;
P = common.params;

geom = generate_constellation_geometry(constellation, common);
[geom, ~] = align_reference_satellite_over_gs(geom, common);
satNames = string({geom.sats.name}.');

P_gs_km = common.Re_km * [cosd(common.gsLat_deg) * cosd(common.gsLon_deg); ...
                          cosd(common.gsLat_deg) * sind(common.gsLon_deg); ...
                          sind(common.gsLat_deg)];
P_geo_km = common.Rgeo_km * [cosd(common.gsoLon_deg); sind(common.gsoLon_deg); 0];

% --- Search worst EPFD only (no helper ID per slot) ---
tSearch = common.tStart_s:common.tStep_s:common.tEnd_s;
nT = numel(tSearch);
epfdBefore_dB = -inf(1, nT);
fprintf('  Searching worst EPFD over t=[%d,%d] s ...\n', tSearch(1), tSearch(end));
for it = 1:nT
    state = propagate_satellites(geom, common, tSearch(it));
    pos_all = state.pos_ecef_km(:, :, 1);
    vel_all = state.vel_ecef_kmps(:, :, 1);
    vis = get_visible_satellites(pos_all, P_gs_km, common.minElev_deg);
    if isempty(vis.idx)
        continue;
    end
    visIdx = vis.idx;
    nVis = numel(visIdx);
    boresights_vis = cell(1, nVis);
    for k = 1:nVis
        gi = visIdx(k);
        fp = generate_beam_footprints(pos_all(:, gi), vel_all(:, gi), beam, common.Re_km);
        boresights_vis{k} = [fp.boresight];
    end
    slot = identify_critical_satellites(visIdx, pos_all(:, visIdx), boresights_vis, ...
        P_gs_km, P_geo_km, P, beam, common.epfdThr_dB);
    epfdBefore_dB(it) = 10 * log10(max(slot.aggBefore_lin, 1e-300));
end
[peakEpfd_dB, iWorst] = max(epfdBefore_dB);
tWorst_s = tSearch(iWorst);

% --- Full critical + helper identification at t_worst only ---
state = propagate_satellites(geom, common, tWorst_s);
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
for cc = 1:numel(slotHelper.satellites)
    ids = string(slotHelper.satellites(cc).helperSatelliteIds);
    for hh = 1:numel(ids)
        gi = find(satNames == ids(hh), 1);
        if ~isempty(gi) && ~any(helperGlobal == gi) && ~any(critGlobal == gi)
            helperGlobal(end+1) = gi; %#ok<AGROW>
        end
    end
end

% Map global sat index -> fpCell entry (visible sats only).
visLocalOf = containers.Map('KeyType', 'double', 'ValueType', 'double');
for k = 1:nVis
    visLocalOf(visIdx(k)) = k;
end
closedMaskByGlobal = containers.Map('KeyType', 'double', 'ValueType', 'any');
for k = 1:nVis
    closedMaskByGlobal(visIdx(k)) = slot.closedMask(k, :);
end

scene = struct();
scene.name = geom.name;
scene.tWorst_s = tWorst_s;
scene.peakEpfd_dB = peakEpfd_dB;
scene.nCritical = numel(critGlobal);
scene.nHelpers = numel(helperGlobal);
scene.nClosedBeams = slot.nShut;
scene.gsLat_deg = common.gsLat_deg;
scene.gsLon_deg = common.gsLon_deg;
scene.slotHelper = slotHelper;
scene.satNames = satNames;
scene.geom = geom;
scene.subLat = subLat;
scene.subLon = subLon;
scene.critGlobal = critGlobal(:);
scene.helperGlobal = helperGlobal(:);
scene.fpCell = fpCell;
scene.visLocalOf = visLocalOf;
scene.closedMaskByGlobal = closedMaskByGlobal;
scene.Nbeam = beam.Nbeam;
scene.plotBeamHalfEW_km = common.plotBeamHalfEW_km;
scene.plotBeamHalfNS_km = common.plotBeamHalfNS_km;

tag = sanitize_name(geom.name);
baseName = sprintf('%s_worst_epfd_ssp_16beams', tag);
paths = {};
paths{end+1} = fullfile(cfg.io.figuresDir, baseName); %#ok<AGROW>
if isfield(cfg.io, 'matlabDataDir') && strlength(string(cfg.io.matlabDataDir)) > 0
    paths{end+1} = fullfile(cfg.io.matlabDataDir, baseName); %#ok<AGROW>
end
for p = 1:numel(paths)
    draw_ssp_16beam_scene(scene, paths{p});
end
scene.pngPath = [paths{end} '.png'];
end

function draw_ssp_16beam_scene(scene, basePath)
% Lon/lat map: critical + helper SSPs and actual ray/Earth 16-beam footprints.

shownIdx = unique([scene.critGlobal(:); scene.helperGlobal(:)], 'stable');
if isempty(shownIdx)
    warning('draw_ssp_16beam_scene:Empty', ...
        'No critical/helper sats to draw for %s.', scene.name);
    return;
end

gsLon = scene.gsLon_deg;
gsLat = scene.gsLat_deg;
lonPlot = @(lon) wrap_lon(lon);   % absolute longitude [deg]

fig = figure('Color', 'w', 'Visible', 'off', 'Units', 'inches', ...
    'Position', [1 1 7.0 5.6]);
ax = axes('Parent', fig);
hold(ax, 'on');

allLon = gsLon;
allLat = gsLat;
legHelperBeam = false;
legCritOpen = false;
legCritClosed = false;

% --- Actual 16-beam polygons per shown satellite ---
for k = 1:numel(shownIdx)
    gi = shownIdx(k);
    if ~isKey(scene.visLocalOf, gi)
        continue;
    end
    fp = scene.fpCell{scene.visLocalOf(gi)};
    isCrit = any(scene.critGlobal == gi);
    closedMask = false(1, scene.Nbeam);
    if isCrit && isKey(scene.closedMaskByGlobal, gi)
        closedMask = logical(scene.closedMaskByGlobal(gi));
        if numel(closedMask) < scene.Nbeam
            closedMask(end+1:scene.Nbeam) = false;
        end
    end

    for b = 1:numel(fp)
        if ~fp(b).valid || numel(fp(b).polyLat) < 3
            continue;
        end
        lonP = lonPlot(fp(b).polyLon);
        latP = fp(b).polyLat;
        allLon = [allLon; lonP(:)]; %#ok<AGROW>
        allLat = [allLat; latP(:)]; %#ok<AGROW>

        if isCrit && closedMask(min(b, numel(closedMask)))
            faceC = [1.00 0.55 0.55];
            edgeC = [0.70 0.05 0.05];
            faceA = 0.28;
            lw = 0.9;
            showLeg = ~legCritClosed;
            legName = 'Critical satellite';
            if showLeg, legCritClosed = true; end
        elseif isCrit
            % Open beams on critical sat: keep drawing, but do not duplicate legend.
            faceC = [1.00 0.88 0.70];
            edgeC = [0.75 0.40 0.05];
            faceA = 0.12;
            lw = 0.55;
            showLeg = false;
            legName = 'Critical satellite';
            legCritOpen = true;
        else
            faceC = [0.70 0.85 1.00];
            edgeC = [0.05 0.35 0.70];
            faceA = 0.10;
            lw = 0.55;
            showLeg = ~legHelperBeam;
            legName = 'Helper satellite';
            if showLeg, legHelperBeam = true; end
        end

        if showLeg
            fill(ax, lonP, latP, faceC, 'EdgeColor', edgeC, 'LineWidth', lw, ...
                'FaceAlpha', faceA, 'DisplayName', legName);
        else
            fill(ax, lonP, latP, faceC, 'EdgeColor', edgeC, 'LineWidth', lw, ...
                'FaceAlpha', faceA, 'HandleVisibility', 'off');
        end
    end
end

% Equator.
xPadTmp = 2;
plot(ax, [min(allLon) - xPadTmp, max(allLon) + xPadTmp], [0 0], '--', ...
    'Color', [0.25 0.25 0.25], 'LineWidth', 1.0, 'DisplayName', 'Equator');

% Satellite SSPs: S1, S2, ... (smaller markers; black labels offset from sub-points).
critPlotted = false;
helperPlotted = false;
labelDx = 0.55;
labelDy = 0.55;
gsLabelDx = 0.50;      % GS red text to the right of the yellow triangle
gsLabelStackDy = 1.15; % S# above GS when the sub-point is at/near GS
nearGsTol_deg = 0.35;
for si = 1:numel(shownIdx)
    gi = shownIdx(si);
    x = lonPlot(scene.subLon(gi));
    y = scene.subLat(gi);
    allLon = [allLon; x]; %#ok<AGROW>
    allLat = [allLat; y]; %#ok<AGROW>
    isCrit = any(scene.critGlobal == gi);
    if isCrit
        if ~critPlotted
            plot(ax, x, y, 's', 'MarkerSize', 6, ...
                'MarkerFaceColor', [0.95 0.25 0.25], 'MarkerEdgeColor', [0.55 0 0], ...
                'LineWidth', 1.0, 'DisplayName', 'Critical sub-point');
            critPlotted = true;
        else
            plot(ax, x, y, 's', 'MarkerSize', 6, ...
                'MarkerFaceColor', [0.95 0.25 0.25], 'MarkerEdgeColor', [0.55 0 0], ...
                'LineWidth', 1.0, 'HandleVisibility', 'off');
        end
    else
        if ~helperPlotted
            plot(ax, x, y, 'o', 'MarkerSize', 6, ...
                'MarkerFaceColor', [0.30 0.70 1.00], 'MarkerEdgeColor', [0 0.35 0.65], ...
                'LineWidth', 0.9, 'DisplayName', 'Helper sub-point');
            helperPlotted = true;
        else
            plot(ax, x, y, 'o', 'MarkerSize', 6, ...
                'MarkerFaceColor', [0.30 0.70 1.00], 'MarkerEdgeColor', [0 0.35 0.65], ...
                'LineWidth', 0.9, 'HandleVisibility', 'off');
        end
    end
    if hypot(x - gsLon, y - gsLat) <= nearGsTol_deg
        % Critical sat over GS: stack S# above the GS label (not on the triangle).
        tx = gsLon + gsLabelDx;
        ty = gsLat + gsLabelStackDy;
    else
        tx = x + labelDx;
        ty = y + labelDy;
    end
    text(ax, tx, ty, sprintf('S%d', si), ...
        'FontSize', 10, 'FontName', 'Times New Roman', 'FontWeight', 'bold', ...
        'Color', [0 0 0], 'HorizontalAlignment', 'left', 'VerticalAlignment', 'bottom');
end

% GS: yellow triangle at sub-point; red label to its right (not overlapping).
plot(ax, gsLon, gsLat, '^', 'MarkerSize', 9, 'MarkerFaceColor', [1 0.85 0], ...
    'MarkerEdgeColor', 'k', 'LineWidth', 1.0, 'DisplayName', 'GS');
text(ax, gsLon + gsLabelDx, gsLat, 'GS', 'Color', [0.75 0 0], ...
    'FontSize', 10, 'FontName', 'Times New Roman', 'FontWeight', 'bold', ...
    'HorizontalAlignment', 'left', 'VerticalAlignment', 'middle');

padLon = max(1.5, 0.08 * max(max(allLon) - min(allLon), 1));
padLat = max(1.5, 0.08 * max(max(allLat) - min(allLat), 1));
xlim(ax, [min(allLon) - padLon, max(allLon) + padLon]);
ylim(ax, [min(allLat) - padLat, max(allLat) + padLat]);
axis(ax, 'equal');
grid(ax, 'on');
box(ax, 'on');
xlabel(ax, 'Longitude (deg)');
ylabel(ax, 'Latitude (deg)');
% Legend only for High-density; Low-density / OneWeb omit the side box.
showLegend = contains(lower(string(scene.name)), "high-density") || ...
             contains(lower(string(scene.name)), "high_density");
if showLegend
    legend(ax, 'Location', 'bestoutside');
else
    legend(ax, 'off');
end
ax.FontName = 'Times New Roman';
ax.FontSize = 10;
hold(ax, 'off');

set(fig, 'Color', 'w', 'InvertHardcopy', 'off', 'PaperPositionMode', 'auto');
print(fig, [basePath '.png'], '-dpng', '-r300');
savefig(fig, [basePath '.fig']);
close(fig);
end

function lon = wrap_lon(lon)
lon = mod(lon + 180, 360) - 180;
end

function s = sanitize_name(name)
s = regexprep(char(name), '[^A-Za-z0-9]+', '_');
s = regexprep(s, '_+', '_');
s = regexprep(s, '^_|_$', '');
end
