function results = run_pitch2_paper(root, leoList, geoList, opts)
% run_pitch2_paper
% 純 Matlab 模擬：progressive pitch + discrimination angle gate（beam-level）
% 不依賴 STK beam 物件，僅從 STK 讀取 LEO/GEO/GS 位置
%
% 論文對照：Coexistence Downlink Interference Analysis Between LEO System
% and GEO System in Ka Band (2018 IEEE/CIC ICCC)
% - Discrimination angle: alpha = angle(GS->LEO, GS->GEO)
% - Beam coverage gate: beta_b = beta0 - (2*bp-1)*betaEllipse, Eq.(1)(2)(3)
% - Shutoff: alpha < alpha_th -> beam OFF
%
% inputs:
%   root    : STK root (con.Personality2)
%   leoList : cellstr / string array, LEO 衛星名稱
%   geoList : cellstr / string array, GEO 衛星名稱（對應 GSO_GS_geo_xx）
%   opts    : struct（可選）
%
% outputs:
%   results : struct（thetaBestDeg, stats, timeSeries, config）

cfg = pitch2_default_config();
if nargin >= 4 && ~isempty(opts)
    cfg = pitch2_merge_struct(cfg, opts);
end

% 印出論文參數對照
pitch2_print_paper_params(cfg);

leoList = pitch2_to_cellstr(leoList);
geoList = pitch2_to_cellstr(geoList);

sc = root.CurrentScenario;
if isempty(cfg.tStartStr) || (isstring(cfg.tStartStr) && cfg.tStartStr == "")
    try
        cfg.tStartStr = char(sc.StartTime);
    catch
        cfg.tStartStr = datestr(now, 'dd mmm yyyy HH:MM:SS');
    end
    if isempty(cfg.tStartStr), cfg.tStartStr = datestr(now, 'dd mmm yyyy HH:MM:SS'); end
end
if isempty(cfg.tStopStr) || (isstring(cfg.tStopStr) && cfg.tStopStr == "")
    try
        cfg.tStopStr = char(sc.StopTime);
    catch
        cfg.tStopStr = datestr(now + 1, 'dd mmm yyyy HH:MM:SS');
    end
    if isempty(cfg.tStopStr), cfg.tStopStr = datestr(now + 1, 'dd mmm yyyy HH:MM:SS'); end
end
% 確保為 char（datenum 需要）
if isstring(cfg.tStartStr), cfg.tStartStr = char(cfg.tStartStr); end
if isstring(cfg.tStopStr), cfg.tStopStr = char(cfg.tStopStr); end
cfg.stepDay = cfg.stepSec / 86400;

% 純 Matlab 模擬：只讀 LEO/GEO/GS 位置，不查 STK beam
[leoPosDPs, leoLlaDPs] = preloadLeoPositionsOnly(root, leoList);
[geoPosDPs, gsObjMap, gsLatMap] = preloadGeoAndGS_Paper(root, geoList);
[P_gs_all, phiES_all] = preloadGsFixedPositions(root, geoList, gsObjMap, gsLatMap);

switch lower(string(cfg.thetaMode))
    case "fixed"
        thetaBest = cfg.thetaFixedDeg;
        [resultsTS, stats] = eval_theta(thetaBest);
        results = pack_results(thetaBest, stats, resultsTS, cfg);
    case "brute"
        thetaCandidates = cfg.thetaBoundsDeg(1):cfg.thetaStepDeg:cfg.thetaBoundsDeg(2);
        bestScore = -inf;
        thetaBest = cfg.thetaFixedDeg;
        bestStats = [];
        for th = thetaCandidates
            [~, stats] = eval_theta(th);
            if stats.objective > bestScore
                bestScore = stats.objective;
                thetaBest = th;
                bestStats = stats;
            end
        end
        [resultsTS, statsFinal] = eval_theta(thetaBest);
        if ~isempty(bestStats)
            statsFinal.objective = bestStats.objective;
        end
        results = pack_results(thetaBest, statsFinal, resultsTS, cfg);
    case "ga"
        [thetaBest, statsBest] = pitch2_ga_optimize(@(th) eval_theta(th), cfg);
        [resultsTS, statsFinal] = eval_theta(thetaBest);
        if ~isempty(statsBest)
            statsFinal.objective = statsBest.objective;
        end
        results = pack_results(thetaBest, statsFinal, resultsTS, cfg);
    otherwise
        error('opts.thetaMode 請用 fixed / brute / ga');
end

if cfg.writeExcel
    outDir = cfg.excelOutDir;
    if isempty(outDir), outDir = fullfile(pwd, 'Matlab_data'); end
    if ~exist(outDir, 'dir'), mkdir(outDir); end
    excelFile = fullfile(outDir, sprintf('pitch2_log_%s.xlsx', datestr(now,'yyyymmdd_HHMMSS')));
    T = struct2table(results.timeSeries);
    writetable(T, excelFile);
    results.excelFile = excelFile;
end

if cfg.makePlots
    plot_results(results);
end

    function [ts, stats] = eval_theta(thetaDeg)
        stats = struct();
        stats.thetaDeg = thetaDeg;
        t0 = datenum(cfg.tStartStr);
        t1 = datenum(cfg.tStopStr);
        Nt = floor((t1 - t0) / cfg.stepDay) + 1;
        timeStr = strings(Nt,1);
        activeBeams = zeros(Nt,1);
        offBeams = zeros(Nt,1);
        minAlpha = nan(Nt,1);
        minOverlapDeg = nan(Nt,1);
        leoLatDeg = nan(Nt,1);   % LEO 緯度（論文 Figure 6 x 軸）
        idxT = 0;
        t = t0;
        Ngeo = numel(geoList);
        Nbeam = cfg.Nbeam;

        while t <= t1 + 1e-12
            idxT = idxT + 1;
            tStr = datestr(t, 'dd mmm yyyy HH:MM:SS');
            timeStr(idxT) = string(tStr);
            root.ExecuteCommand(['Animate * SetTime "' tStr '"']);

            P_geo_all = zeros(3, Ngeo);
            for jj = 1:Ngeo
                P_geo_all(:,jj) = stkGetXYZ_ExecSingle(geoPosDPs(geoList{jj}), tStr);
            end

            totalBeams = 0;
            totalOff = 0;
            minAlphaThisT = inf;
            covIntervals = nan(numel(leoList), 2);
            leoLatNow = nan(numel(leoList), 1);

            for ii = 1:numel(leoList)
                leoName = leoList{ii};
                P_leo = stkGetXYZ_ExecSingle(leoPosDPs(leoName), tStr);
                phiS = stkGetLat_ExecSingle(leoLlaDPs(leoName), tStr);
                leoLatNow(ii) = phiS;
                RS_km = norm(P_leo);

                vLEO = P_leo(:,ones(1,Ngeo)) - P_gs_all;
                vGEO = P_geo_all - P_gs_all;
                alpha_all = angleDeg_columns(vLEO, vGEO);

                [phiB1_all, phiB2_all] = compute_beam_bounds_deg(phiS, RS_km, thetaDeg, cfg, Nbeam);
                violateBeam = false(1, Nbeam);
                alphaMinPerBeam = nan(1, Nbeam);

                for b = 1:Nbeam
                    inCov = (phiES_all >= phiB2_all(b)) & (phiES_all <= phiB1_all(b));
                    if any(inCov)
                        alphaMin = min(alpha_all(inCov));
                        alphaMinPerBeam(b) = alphaMin;
                        violateBeam(b) = (alphaMin < cfg.alphaThDeg);
                    end
                end
                if cfg.symmetricShutoff
                    for b = 1:Nbeam
                        if violateBeam(b)
                            violateBeam(Nbeam - b + 1) = true;
                        end
                    end
                end

                totalBeams = totalBeams + Nbeam;
                totalOff = totalOff + sum(violateBeam);

                activeMask = ~violateBeam & ~isnan(alphaMinPerBeam);
                if any(activeMask)
                    minAlphaThisT = min(minAlphaThisT, min(alphaMinPerBeam(activeMask)));
                end
                if any(~violateBeam)
                    covIntervals(ii,:) = [min(phiB2_all(~violateBeam)) max(phiB1_all(~violateBeam))];
                end
            end

            activeBeams(idxT) = totalBeams - totalOff;
            offBeams(idxT) = totalOff;
            if isfinite(minAlphaThisT), minAlpha(idxT) = minAlphaThisT; end
            minOverlapDeg(idxT) = compute_min_overlap_deg(covIntervals, leoLatNow);
            leoLatDeg(idxT) = mean(leoLatNow, 'omitnan');
            t = t + cfg.stepDay;
        end

        ts = struct();
        ts.time = timeStr(1:idxT);
        ts.activeBeams = activeBeams(1:idxT);
        ts.offBeams = offBeams(1:idxT);
        ts.minAlphaDeg = minAlpha(1:idxT);
        ts.minOverlapDeg = minOverlapDeg(1:idxT);
        ts.leoLatDeg = leoLatDeg(1:idxT);

        meanActive = mean(activeBeams(1:idxT));
        gapPenalty = 0;
        if cfg.enforceSeamless
            gaps = minOverlapDeg(1:idxT);
            gaps = gaps(~isnan(gaps));
            if ~isempty(gaps)
                gapPenalty = sum(max(0, -gaps)) * cfg.gapPenaltyWeight;
            end
        end
        stats.meanActiveBeams = meanActive;
        stats.gapPenalty = gapPenalty;
        stats.objective = meanActive - gapPenalty;
    end
end

% ============================================================
% 論文參數對照（Coexistence LEO-GEO Ka Band, 2018 ICCC）
% ============================================================
function cfg = pitch2_default_config()
cfg = struct();

% --- 論文對照 ---
% RE: WGS84 地球半徑
cfg.ReKm = 6378.137;

% Nbeam: 論文 16-beam 結構
cfg.Nbeam = 16;

% alpha_th: 論文 Eq.(8)(9) discrimination angle threshold
% 若 alpha < alpha_th，該 beam 對 GSO GS 造成干擾，需關閉
cfg.alphaThDeg = 10.0;

% beta0, betaEllipse: 論文 Eq.(1) coverage gate
% beta_b = beta0 - (2*bp-1)*betaEllipse, bp=1..16
% beta0: 外側 beam 半角；betaEllipse: 相鄰 beam 間距 ≈ 25/16
cfg.beta0Deg = 23.41;
cfg.betaEllipseDeg = 1.56;

% theta: progressive pitch angle (deg)
cfg.thetaFixedDeg = 0.0;
cfg.thetaBoundsDeg = [0.0 10.0];
cfg.thetaStepDeg = 0.1;

% time
cfg.tStartStr = "";
cfg.tStopStr = "";
cfg.stepSec = 30;

% theta mode
cfg.thetaMode = "fixed";

% seamless coverage
cfg.enforceSeamless = true;
cfg.gapPenaltyWeight = 10.0;

% symmetric shutoff（論文可選）
cfg.symmetricShutoff = false;

% 純 Matlab 模擬：不使用 STK beam，此欄位保留但不作用
cfg.applyToSTK = false;

cfg.writeExcel = false;
cfg.excelOutDir = "";
cfg.makePlots = true;

% GA
cfg.ga = struct();
cfg.ga.popSize = 30;
cfg.ga.generations = 25;
cfg.ga.eliteCount = 2;
cfg.ga.mutationRate = 0.25;
cfg.ga.mutationSigma = 0.5;
cfg.ga.crossoverRate = 0.7;
cfg.ga.seed = 1;
end

function pitch2_print_paper_params(cfg)
fprintf('\n=== 論文參數對照 (Coexistence LEO-GEO Ka Band) ===\n');
fprintf('  RE (km)        = %.3f  (WGS84)\n', cfg.ReKm);
fprintf('  Nbeam          = %d     (論文 16-beam)\n', cfg.Nbeam);
fprintf('  alpha_th (deg) = %.1f   (discrimination angle threshold, Eq.8,9)\n', cfg.alphaThDeg);
fprintf('  beta0 (deg)    = %.2f   (coverage gate, Eq.1)\n', cfg.beta0Deg);
fprintf('  betaEllipse    = %.2f   (25/16, beam 間距)\n', cfg.betaEllipseDeg);
fprintf('  theta (deg)    = [%.1f, %.1f] (progressive pitch)\n', cfg.thetaBoundsDeg(1), cfg.thetaBoundsDeg(2));
fprintf('  stepSec        = %d\n', cfg.stepSec);
fprintf('==================================================\n\n');
end

function [thetaBest, statsBest] = pitch2_ga_optimize(evalFn, cfg)
rng(cfg.ga.seed);
lb = cfg.thetaBoundsDeg(1);
ub = cfg.thetaBoundsDeg(2);
pop = lb + (ub - lb) * rand(cfg.ga.popSize, 1);
fit = nan(cfg.ga.popSize, 1);
statsBest = [];
bestFit = -inf;
thetaBest = cfg.thetaFixedDeg;

for gen = 1:cfg.ga.generations
    for i = 1:numel(pop)
        [~, st] = evalFn(pop(i));
        fit(i) = st.objective;
    end
    [fitSorted, idx] = sort(fit, 'descend');
    elite = pop(idx(1:cfg.ga.eliteCount));
    if fitSorted(1) > bestFit
        bestFit = fitSorted(1);
        thetaBest = elite(1);
        statsBest = struct('objective', bestFit);
    end
    f = fit - min(fit) + 1e-9;
    prob = f / sum(f);
    cdf = cumsum(prob);
    newPop = nan(size(pop));
    newPop(1:cfg.ga.eliteCount) = elite;
    for k = (cfg.ga.eliteCount+1):cfg.ga.popSize
        p1 = pop(find(cdf >= rand(), 1, 'first'));
        p2 = pop(find(cdf >= rand(), 1, 'first'));
        child = p1;
        if rand() < cfg.ga.crossoverRate
            child = rand()*p1 + (1-rand())*p2;
        end
        if rand() < cfg.ga.mutationRate
            child = child + cfg.ga.mutationSigma * randn();
        end
        newPop(k) = min(ub, max(lb, child));
    end
    pop = newPop;
end
end

% 論文 Eq.(1)(2)(3): phiB1, phiB2 覆蓋緯度邊界
function [phiB1_all, phiB2_all] = compute_beam_bounds_deg(phiS_deg, RS_km, thetaDeg, cfg, Nbeam)
phiB1_all = nan(1, Nbeam);
phiB2_all = nan(1, Nbeam);
for b = 1:Nbeam
    bp = Nbeam - b + 1;
    beta_b = cfg.beta0Deg - (2*bp - 1)*cfg.betaEllipseDeg;
    psi_upper = deg2rad(beta_b - thetaDeg);
    psi_lower = deg2rad(cfg.beta0Deg + thetaDeg);
    delta_upper = rad2deg(acos(g_func(psi_upper, cfg.ReKm, RS_km)));
    delta_lower = rad2deg(acos(g_func(psi_lower, cfg.ReKm, RS_km)));
    phiB1_all(b) = phiS_deg + delta_upper;
    phiB2_all(b) = phiS_deg - delta_lower;
end
end

function minOv = compute_min_overlap_deg(covIntervals, leoLatNow)
valid = ~any(isnan(covIntervals), 2) & ~isnan(leoLatNow);
covIntervals = covIntervals(valid,:);
leoLatNow = leoLatNow(valid);
if size(covIntervals,1) < 2
    minOv = NaN;
    return;
end
[~, order] = sort(leoLatNow);
covIntervals = covIntervals(order,:);
ov = nan(size(covIntervals,1)-1, 1);
for k = 1:(size(covIntervals,1)-1)
    a = covIntervals(k,:);
    b = covIntervals(k+1,:);
    ov(k) = min(a(2), b(2)) - max(a(1), b(1));
end
minOv = min(ov);
end

% 純 Matlab 模擬：只讀 LEO 位置，不查 STK beam
function [leoPosDPs, leoLlaDPs] = preloadLeoPositionsOnly(root, leoList)
leoPosDPs = containers.Map;
leoLlaDPs = containers.Map;
for i = 1:numel(leoList)
    leoName = leoList{i};
    satObj = root.GetObjectFromPath(['*/Satellite/' leoName]);
    leoPosDPs(leoName) = satObj.DataProviders.Item('Cartesian Position').Group.Item('Fixed');
    leoLlaDPs(leoName) = satObj.DataProviders.Item('LLA State').Group.Item('Fixed');
end
end

function [geoPosDPs, gsObjMap, gsLatMap] = preloadGeoAndGS_Paper(root, geoList)
geoPosDPs = containers.Map;
gsObjMap = containers.Map;
gsLatMap = containers.Map;
for j = 1:numel(geoList)
    geoName = geoList{j};
    geoSat = root.GetObjectFromPath(['*/Satellite/' geoName]);
    geoPosDPs(geoName) = geoSat.DataProviders.Item('Cartesian Position').Group.Item('Fixed');
    gsObj = root.GetObjectFromPath(['*/Facility/GSO_GS_' geoName]);
    gsObjMap(geoName) = gsObj;
    try
        res = gsObj.DataProviders.Item('LLA State').Exec;
        arr = res.DataSets.ToArray;
        lat = stkGetLat_FromArray(arr);
    catch
        res = gsObj.DataProviders.Item('Cartesian Position').Exec;
        arr = res.DataSets.ToArray;
        P = stkGetXYZ_FromArray(arr);
        lat = atan2d(P(3), sqrt(P(1)^2 + P(2)^2));
    end
    gsLatMap(geoName) = lat;
end
end

function [P_gs_all, phiES_all] = preloadGsFixedPositions(~, geoList, gsObjMap, gsLatMap)
Ngeo = numel(geoList);
P_gs_all = zeros(3, Ngeo);
phiES_all = zeros(1, Ngeo);
for j = 1:Ngeo
    geoName = geoList{j};
    gsObj = gsObjMap(geoName);
    res = gsObj.DataProviders.Item('Cartesian Position').Exec;
    arr = res.DataSets.ToArray;
    P_gs_all(:,j) = stkGetXYZ_FromArray(arr);
    phiES_all(j) = gsLatMap(geoName);
end
end

% 論文 Eq.(4): alpha = angle(GS->LEO, GS->GEO)
function alpha = angleDeg_columns(v1_all, v2_all)
num = sum(v1_all .* v2_all, 1);
den = sqrt(sum(v1_all.^2,1)) .* sqrt(sum(v2_all.^2,1)) + eps;
c = min(1, max(-1, num ./ den));
alpha = acosd(c);
end

% 論文 Eq.(2)(3): g(psi) for coverage gate
function val = g_func(psi_rad, RE_km, RS_km)
s = sin(psi_rad);
c = cos(psi_rad);
under = max(RE_km^2 - RS_km^2*(s.^2), 0);
val = (RS_km*(s.^2) + c.*sqrt(under)) / RE_km;
val = min(1, max(-1, val));
end

function P = stkGetXYZ_ExecSingle(dp, tStr)
res = dp.ExecSingle(tStr);
arr = res.DataSets.ToArray;
P = stkGetXYZ_FromArray(arr);
end

function lat = stkGetLat_ExecSingle(dpLLA, tStr)
res = dpLLA.ExecSingle(tStr);
arr = res.DataSets.ToArray;
lat = stkGetLat_FromArray(arr);
end

function P = stkGetXYZ_FromArray(arr)
vals = [];
for k = 1:numel(arr)
    a = arr{k};
    if isnumeric(a) && isscalar(a)
        vals(end+1,1) = double(a);
    end
end
if numel(vals) < 3
    error('STK XYZ extraction failed.');
end
P = vals(1:3);
P = P(:);
end

function lat = stkGetLat_FromArray(arr)
vals = [];
for k = 1:numel(arr)
    a = arr{k};
    if isnumeric(a) && isscalar(a)
        vals(end+1,1) = double(a);
    end
end
if isempty(vals)
    error('STK LLA extraction failed.');
end
lat = vals(1);
end

function s = pitch2_merge_struct(s, u)
fn = fieldnames(u);
for i = 1:numel(fn)
    k = fn{i};
    if isstruct(u.(k)) && isfield(s, k) && isstruct(s.(k))
        s.(k) = pitch2_merge_struct(s.(k), u.(k));
    else
        s.(k) = u.(k);
    end
end
end

function c = pitch2_to_cellstr(x)
if iscell(x)
    c = x;
elseif isstring(x)
    c = cellstr(x);
elseif ischar(x)
    c = cellstr(string(x));
else
    error('leoList/geoList 須為 cellstr 或 string array');
end
end

function results = pack_results(thetaBest, stats, ts, cfg)
results = struct();
results.thetaBestDeg = thetaBest;
results.stats = stats;
results.timeSeries = ts;
results.config = cfg;
results.excelFile = "";
end

function plot_results(results)
ts = results.timeSeries;
n = max(1, numel(ts.activeBeams));
figure('Name', 'pitch2 paper metrics (Matlab simulation)', 'Position', [100 100 1100 700]);
subplot(3,1,1);
plot(ts.activeBeams, 'LineWidth', 1.8);
ylabel('Active beams');
grid on;
title(sprintf('(a) Active beams (theta=%.2f deg) - proxy for capacity', results.thetaBestDeg));
subplot(3,1,2);
h2a = plot(ts.minAlphaDeg, 'LineWidth', 1.8);
hold on;
h2b = plot([1 n], [results.config.alphaThDeg results.config.alphaThDeg], 'r--', 'LineWidth', 1.2);
ylabel('min \alpha (deg)');
grid on;
title('(b) Minimum off-axis angle (threshold \alpha_{th})');
legend([h2a h2b], {'min \alpha', '\alpha_{th}'}, 'Location', 'best');
subplot(3,1,3);
h3a = plot(ts.minOverlapDeg, 'LineWidth', 1.8);
hold on;
h3b = plot([1 n], [0 0], 'r--', 'LineWidth', 1.2);
ylabel('min overlap (deg)');
xlabel('time step');
grid on;
title('(c) Coverage overlap (negative = gap)');
legend([h3a h3b], {'min overlap', '0 (no gap)'}, 'Location', 'best');
end
