function slotHelper = identify_recovery_helpers(slot, fpCell, satNames, common)
% identify_recovery_helpers
% For ONE time slot, find the recovery-capable helper satellites of every
% critical satellite.
%
% A non-critical visible satellite with at least one active beam is a
% recovery-capable helper of a critical satellite if the SUM of polygon
% overlap areas between its active beams and that critical's closed beams
% is at least common.helperMinOverlapArea_km2 (default: one nominal beam
% footprint). Tiny edge grazes therefore do not qualify a helper.
%
% Only helpers usable for HBR are counted here (i.e. helper recovery beams
% overlapping closed-beam footprints); safe-release-only overlaps are not.
%
% Inputs:
%   slot     : output of identify_critical_satellites for this slot
%   fpCell   : 1 x nVis cell; fpCell{i} is the 1xNbeam footprint struct array
%              of visible satellite i (from generate_beam_footprints)
%   satNames : global satellite name list (string array)
%   common   : cfg.common (helperMinOverlapArea_km2, overlapAreaTol_km2, Re_km)
%
% Output slotHelper:
%   .satellites : struct array over critical satellites, with fields
%       satelliteId, satIdxGlobal, closedBeamIds, helperSatelliteIds,
%       numHelpers, closedBeamRecords(j).beamId /.helperBeamPairs /.hasHelperCoverage
%   .nCriticalSats           : number of critical satellites this slot
%   .instanceNumHelpers      : per-critical-sat recovery-capable helper count
%   .instanceZeroHelper      : logical, true if a critical sat has 0 helpers
%   .nClosedBeamInstances    : number of closed-beam instances this slot
%   .nClosedBeamWithHelper   : closed-beam instances with >=1 qualifying helper
%
% Units: km, km^2, deg.
%
% =====================================================================
% 【中文說明】helper 衛星的判定準則 —— 這是整個 helper availability 實驗的核心。
%
% 判定條件：一顆「可見、非 critical、且至少有一條 active beam」的衛星，
% 只有當「它的 active beam 與該 critical 衛星的 closed beam 的足跡重疊面積總和」
% 達到 common.helperMinOverlapArea_km2（預設 = 1 條標稱 beam 的面積）時，
% 才算是這顆 critical 衛星的 recovery-capable helper。
%
% 為什麼要設面積門檻？因為兩條 beam 只在邊緣「擦到一點點」時，
% 實務上根本無法承接換手，若不設門檻會把這種無效重疊也算成 helper，
% 讓 helper 數量嚴重高估。common.helperMinOverlapBeamFrac 就是調這個門檻的旋鈕
% （1.0 = 至少一整條 beam 的面積；0.5 = 半條）。
%
% 這裡只計算「可用於 HBR 的 helper」，也就是 recovery beam 必須覆蓋到關閉束；
% 只能用於 SBR（安全束釋放）的重疊不算在內。
%
% 為了效率，先用「足跡半徑」做便宜的預篩（兩個足跡中心距離 > 半徑和就不可能重疊），
% 通過預篩才做真正的多邊形交集面積計算。
% =====================================================================

Re_km = common.Re_km;
pairTol = common.overlapAreaTol_km2;          % ignore numerical dust per pair
                                              % 單一 beam 配對的重疊小於此值視為數值誤差
if isfield(common, 'helperMinOverlapArea_km2') && isfinite(common.helperMinOverlapArea_km2)
    helperAreaThr = common.helperMinOverlapArea_km2;   % helper 資格的重疊面積門檻
else
    helperAreaThr = pairTol;                  % fallback: legacy tiny-overlap rule
                                              % 沒設門檻時退回舊行為（只要有一點重疊就算）
end
nVis = numel(slot.visIdx);
Nbeam = size(slot.closedMask, 2);

% Precompute per-visible-satellite, per-beam footprint radius [km] (max
% great-circle distance center->boundary) for a cheap overlap pre-filter.
% 預先算好每條 beam 足跡的「外接半徑」（中心到邊界的最大大圓距離），
% 用來做重疊的快速預篩，避免對每一對 beam 都做昂貴的多邊形交集運算。
fpRadius_km = zeros(nVis, Nbeam);
for i = 1:nVis
    fp = fpCell{i};
    for b = 1:Nbeam
        if fp(b).valid && ~isempty(fp(b).polyLat)
            fpRadius_km(i, b) = max(gc_dist_km(fp(b).centerLat, fp(b).centerLon, ...
                fp(b).polyLat, fp(b).polyLon, Re_km));
        end
    end
end

critLocal = find(slot.isCritical(:).');
nCrit = numel(critLocal);

satTemplate = struct('satelliteId', "", 'satIdxGlobal', 0, 'closedBeamIds', [], ...
    'helperSatelliteIds', strings(0,1), 'numHelpers', 0, ...
    'helperOverlapArea_km2', [], 'closedBeamRecords', []);
satellites = repmat(satTemplate, 1, max(nCrit, 0));

instanceNumHelpers = zeros(nCrit, 1);
instanceZeroHelper = false(nCrit, 1);
nClosedBeamInstances = 0;
nClosedBeamWithHelper = 0;

% Silence benign polyshape simplification warnings during overlap tests.
wState = warning('off', 'MATLAB:polyshape:repairedBySimplify');
cleanup = onCleanup(@() warning(wState)); %#ok<NASGU>

for cc = 1:nCrit
    i = critLocal(cc);
    fpCrit = fpCell{i};
    closedBeams = find(slot.closedMask(i, :));

    cbRecords = repmat(struct('beamId', 0, 'helperBeamPairs', [], ...
        'hasHelperCoverage', false), 1, numel(closedBeams));
    for jc = 1:numel(closedBeams)
        cbRecords(jc).beamId = closedBeams(jc);
        cbRecords(jc).helperBeamPairs = zeros(0, 4);
        cbRecords(jc).hasHelperCoverage = false;
    end

    % --- Pass 1: accumulate overlap area per candidate helper ---
    candLocal = [];
    candArea = [];
    candPairs = {};   % candPairs{k}: rows [cbLocalIdx, helperBeamId, area, h]
    for h = 1:nVis
        if h == i || slot.isCritical(h)
            continue;
        end
        activeBeamsH = find(slot.activeMask(h, :));
        if isempty(activeBeamsH)
            continue;
        end
        fpH = fpCell{h};
        pairsH = zeros(0, 4);
        areaSum = 0;
        for jc = 1:numel(closedBeams)
            cb = closedBeams(jc);
            if ~fpCrit(cb).valid || isempty(fpCrit(cb).polyLat)
                continue;
            end
            for ab = activeBeamsH
                if ~fpH(ab).valid || isempty(fpH(ab).polyLat)
                    continue;
                end
                dctr = gc_dist_km(fpCrit(cb).centerLat, fpCrit(cb).centerLon, ...
                    fpH(ab).centerLat, fpH(ab).centerLon, Re_km);
                if dctr > 1.15 * (fpRadius_km(i, cb) + fpRadius_km(h, ab))
                    continue;
                end
                area_km2 = footprint_overlap_area_km2( ...
                    fpCrit(cb).polyLat, fpCrit(cb).polyLon, ...
                    fpH(ab).polyLat, fpH(ab).polyLon, Re_km);
                if area_km2 > pairTol
                    pairsH(end+1, :) = [jc, ab, area_km2, h]; %#ok<AGROW>
                    areaSum = areaSum + area_km2;
                end
            end
        end
        if areaSum >= helperAreaThr
            candLocal(end+1) = h; %#ok<AGROW>
            candArea(end+1) = areaSum; %#ok<AGROW>
            candPairs{end+1} = pairsH; %#ok<AGROW>
        end
    end

    % --- Pass 2: record qualifying helpers onto closed-beam records ---
    helperSet = strings(0, 1);
    helperAreas = zeros(0, 1);
    for k = 1:numel(candLocal)
        h = candLocal(k);
        hid = satNames(slot.visIdx(h));
        helperSet(end+1, 1) = hid; %#ok<AGROW>
        helperAreas(end+1, 1) = candArea(k); %#ok<AGROW>
        pairsH = candPairs{k};
        for r = 1:size(pairsH, 1)
            jc = pairsH(r, 1);
            ab = pairsH(r, 2);
            area_km2 = pairsH(r, 3);
            cbRecords(jc).helperBeamPairs(end+1, :) = ...
                [double(slot.visIdx(h)), ab, area_km2, h]; %#ok<AGROW>
            cbRecords(jc).hasHelperCoverage = true;
        end
    end

    for jc = 1:numel(closedBeams)
        nClosedBeamInstances = nClosedBeamInstances + 1;
        if cbRecords(jc).hasHelperCoverage
            nClosedBeamWithHelper = nClosedBeamWithHelper + 1;
        end
    end

    satellites(cc).satelliteId           = satNames(slot.visIdx(i));
    satellites(cc).satIdxGlobal          = double(slot.visIdx(i));
    satellites(cc).closedBeamIds         = closedBeams;
    satellites(cc).helperSatelliteIds    = helperSet;
    satellites(cc).numHelpers            = numel(helperSet);
    satellites(cc).helperOverlapArea_km2 = helperAreas;
    satellites(cc).closedBeamRecords     = cbRecords;

    instanceNumHelpers(cc) = numel(helperSet);
    instanceZeroHelper(cc) = numel(helperSet) == 0;
end

slotHelper = struct();
slotHelper.satellites            = satellites;
slotHelper.nCriticalSats         = nCrit;
slotHelper.instanceNumHelpers    = instanceNumHelpers;
slotHelper.instanceZeroHelper    = instanceZeroHelper;
slotHelper.nClosedBeamInstances  = nClosedBeamInstances;
slotHelper.nClosedBeamWithHelper = nClosedBeamWithHelper;
slotHelper.helperMinOverlapArea_km2 = helperAreaThr;
end

function area_km2 = footprint_overlap_area_km2(latA, lonA, latB, lonB, Re_km)
% Intersection area of two footprint polygons, computed in a local ENU
% tangent plane centred on the mean of the two polygon centroids (km).
lat0 = mean([mean(latA), mean(latB)]);
lon0 = mean([mean(lonA), mean(lonB)]);
[xA, yA] = enu_xy_km(latA, lonA, lat0, lon0, Re_km);
[xB, yB] = enu_xy_km(latB, lonB, lat0, lon0, Re_km);
if numel(xA) < 3 || numel(xB) < 3
    area_km2 = 0;
    return;
end
try
    pA = polyshape(xA, yA, 'Simplify', true);
    pB = polyshape(xB, yB, 'Simplify', true);
    pI = intersect(pA, pB);
    area_km2 = area(pI);
catch
    area_km2 = 0;
end
if ~isfinite(area_km2)
    area_km2 = 0;
end
end

function [x_km, y_km] = enu_xy_km(lat_deg, lon_deg, lat0_deg, lon0_deg, Re_km)
% Project surface points (lat/lon on a sphere of radius Re) to a local
% East-North tangent plane at (lat0, lon0). Returns planar km coordinates.
lat_deg = lat_deg(:); lon_deg = lon_deg(:);
p = Re_km * [cosd(lat_deg) .* cosd(lon_deg), ...
             cosd(lat_deg) .* sind(lon_deg), ...
             sind(lat_deg)];
p0 = Re_km * [cosd(lat0_deg) * cosd(lon0_deg); ...
              cosd(lat0_deg) * sind(lon0_deg); ...
              sind(lat0_deg)];
eHat = [-sind(lon0_deg); cosd(lon0_deg); 0];
nHat = [-sind(lat0_deg) * cosd(lon0_deg); -sind(lat0_deg) * sind(lon0_deg); cosd(lat0_deg)];
d = p - p0.';
x_km = d * eHat;
y_km = d * nHat;
end

function d_km = gc_dist_km(lat1, lon1, lat2, lon2, Re_km)
% Great-circle distance(s); lat1/lon1 scalar, lat2/lon2 scalar or vector.
lat2 = lat2(:); lon2 = lon2(:);
dlat = deg2rad(lat2 - lat1);
dlon = deg2rad(lon2 - lon1);
a = sin(dlat/2).^2 + cosd(lat1) .* cosd(lat2) .* sin(dlon/2).^2;
d_km = Re_km * 2 .* atan2(sqrt(a), sqrt(max(0, 1 - a)));
end
