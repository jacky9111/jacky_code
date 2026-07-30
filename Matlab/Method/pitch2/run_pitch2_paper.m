function results = run_pitch2_paper(root, leoList, geoList, opts)
% run_pitch2_paper
% ============================================================
% 實作論文的 progressive pitch + discrimination angle gate（beam-level）
% 並提供固定 pitch / brute-force / GA 三種選 pitch 方式。
%
% 主要概念（對應 paper）：
% - discrimination angle（GS 視角）: alpha = angle( GS->LEO , GS->GEO )
% - 干擾避免條件: alpha >= alpha_th
% - 覆蓋門檻（latitude gate）: 以 phiB1/phiB2 決定 beam 覆蓋的 GS 緯度範圍
% - progressive pitch 角: theta（deg），會影響 phiB1/phiB2
%
% 介面設計：
% - 這個函式可被 pitch2.m 直接呼叫（放在 Matlab/Method/pitch2 底下）
% - opts 可只給部分欄位，未給的會用 default
% ============================================================
%
% inputs:
%   root    : STK root (con.Personality2)
%   leoList : cellstr / string array, STK LEO 衛星名稱（例如 "ow1_3"）
%   geoList : cellstr / string array, STK GEO 衛星名稱（例如 "geo_4_1"）
%   opts    : struct
%
% outputs:
%   results : struct（含最佳 theta、時間序列指標、以及（若啟用）Excel 路徑）
%
% notes:
% - 為了讓 brute/GA 可以跑得動，最佳化階段預設不做 STK Graphics On/Off。
% - 最終會用最佳 theta 再跑一次（可選擇 applyToSTK=true 真的去關 beam）。
%

cfg = pitch2_default_config();
if nargin >= 4 && ~isempty(opts)
    cfg = pitch2_merge_struct(cfg, opts);
end

leoList = pitch2_to_cellstr(leoList);
geoList = pitch2_to_cellstr(geoList);

sc = root.CurrentScenario;

% -------- Time window --------
if isempty(cfg.tStartStr)
    cfg.tStartStr = char(sc.StartTime);
end
if isempty(cfg.tStopStr)
    cfg.tStopStr = char(sc.StopTime);
end
cfg.stepDay = cfg.stepSec / 86400;

% -------- Preload static providers / objects --------
[leoPosDPs, leoLlaDPs, beamMap] = preloadLeoBeams_Paper(root, leoList, cfg.Nbeam);
[geoPosDPs, gsObjMap, gsLatMap] = preloadGeoAndGS_Paper(root, geoList);

% GS 固定座標（Facility 在 Fixed frame 是常數），可以先抓一次
[P_gs_all, phiES_all] = preloadGsFixedPositions(root, geoList, gsObjMap, gsLatMap);

% -------- Choose theta --------
switch lower(string(cfg.thetaMode))
    case "fixed"
        thetaBest = cfg.thetaFixedDeg;
        [resultsTS, stats] = eval_theta(thetaBest, true);
        results = pack_results(thetaBest, stats, resultsTS, cfg);

    case "brute"
        thetaCandidates = cfg.thetaBoundsDeg(1):cfg.thetaStepDeg:cfg.thetaBoundsDeg(2);
        bestScore = -inf;
        thetaBest = cfg.thetaFixedDeg;
        bestStats = [];

        for th = thetaCandidates
            [~, stats] = eval_theta(th, false);
            score = stats.objective;
            if score > bestScore
                bestScore = score;
                thetaBest = th;
                bestStats = stats;
            end
        end

        [resultsTS, statsFinal] = eval_theta(thetaBest, true);
        % 保留最佳化階段的 score（避免和 final 的微差）
        if ~isempty(bestStats)
            statsFinal.objective = bestStats.objective;
        end
        results = pack_results(thetaBest, statsFinal, resultsTS, cfg);

    case "ga"
        [thetaBest, statsBest] = pitch2_ga_optimize(@(th) eval_theta(th, false), cfg);
        [resultsTS, statsFinal] = eval_theta(thetaBest, true);
        if ~isempty(statsBest)
            statsFinal.objective = statsBest.objective;
        end
        results = pack_results(thetaBest, statsFinal, resultsTS, cfg);

    otherwise
        error('Unknown opts.thetaMode="%s". Use fixed / brute / ga.', cfg.thetaMode);
end

% -------- Optional: write Excel --------
if cfg.writeExcel
    outDir = cfg.excelOutDir;
    if isempty(outDir)
        outDir = fullfile(pwd, 'Matlab_data');
    end
    if ~exist(outDir, 'dir'), mkdir(outDir); end
    excelFile = fullfile(outDir, sprintf('pitch2_log_%s.xlsx', datestr(now,'yyyymmdd_HHMMSS')));
    T = struct2table(results.timeSeries);
    writetable(T, excelFile);
    results.excelFile = excelFile;
end

% -------- Optional: plots --------
if cfg.makePlots
    plot_results(results);
end

% ============================================================
% Nested: evaluate one theta
% ============================================================
function [ts, stats] = eval_theta(thetaDeg, applyToStk)
    stats = struct();
    stats.thetaDeg = thetaDeg;
    stats.alpha_th_deg = cfg.alphaThDeg;

    t0 = datenum(cfg.tStartStr);
    t1 = datenum(cfg.tStopStr);

    % prealloc (upper bound)
    Nt = floor((t1 - t0) / cfg.stepDay) + 1;
    timeStr = strings(Nt,1);
    activeBeams = zeros(Nt,1);
    offBeams = zeros(Nt,1);
    minAlpha = nan(Nt,1);
    minOverlapDeg = nan(Nt,1);

    idxT = 0;
    t = t0;
    while t <= t1 + 1e-12
        idxT = idxT + 1;
        tStr = datestr(t, 'dd mmm yyyy HH:MM:SS');
        timeStr(idxT) = string(tStr);
        root.ExecuteCommand(['Animate * SetTime "' tStr '"']);

        % GEO positions（每個 time 會變）
        Ngeo = numel(geoList);
        P_geo_all = zeros(3, Ngeo);
        for jj = 1:Ngeo
            gName = geoList{jj};
            P_geo_all(:,jj) = stkGetXYZ_ExecSingle(geoPosDPs(gName), tStr);
        end

        % ---- Per LEO accumulate metrics ----
        totalBeams = 0;
        totalOff = 0;
        minAlphaThisT = inf;

        % coverage intervals for overlap metric
        covIntervals = nan(numel(leoList), 2); % [low high]
        leoLatNow = nan(numel(leoList), 1);

        for ii = 1:numel(leoList)
            leoName = leoList{ii};
            if ~isKey(beamMap, leoName), continue; end

            beamPaths = beamMap(leoName);
            Nbeam = numel(beamPaths);
            totalBeams = totalBeams + Nbeam;

            P_leo = stkGetXYZ_ExecSingle(leoPosDPs(leoName), tStr);
            phiS = stkGetLat_ExecSingle(leoLlaDPs(leoName), tStr);
            leoLatNow(ii) = phiS;

            RS_km = norm(P_leo);

            % discrimination angle alpha (GS view): 1 x Ngeo
            vLEO = P_leo(:,ones(1,Ngeo)) - P_gs_all;
            vGEO = P_geo_all - P_gs_all;
            alpha_all = angleDeg_columns(vLEO, vGEO);

            % beam bounds（paper-aligned gate）
            [phiB1_all, phiB2_all] = compute_beam_bounds_deg(phiS, RS_km, thetaDeg, cfg, Nbeam);

            violateBeam = false(1, Nbeam);
            alphaMinPerBeam = nan(1, Nbeam);

            for b = 1:Nbeam
                phiB1 = phiB1_all(b);
                phiB2 = phiB2_all(b);
                inCov = (phiES_all >= phiB2) & (phiES_all <= phiB1);
                if any(inCov)
                    alpha_b = alpha_all(inCov);
                    alphaMin = min(alpha_b);
                    alphaMinPerBeam(b) = alphaMin;
                    violateBeam(b) = (alphaMin < cfg.alphaThDeg);
                else
                    violateBeam(b) = false;
                end
            end

            if cfg.symmetricShutoff
                for b = 1:Nbeam
                    if violateBeam(b)
                        bSym = Nbeam - b + 1;
                        violateBeam(bSym) = true;
                    end
                end
            end

            nOff = sum(violateBeam);
            totalOff = totalOff + nOff;

            % apply to STK graphics（只在最終跑才做）
            if applyToStk && cfg.applyToSTK
                for b = 1:Nbeam
                    if violateBeam(b)
                        root.ExecuteCommand(sprintf('Graphics %s Show Off', beamPaths{b}));
                    else
                        root.ExecuteCommand(sprintf('Graphics %s Show On', beamPaths{b}));
                    end
                end
            end

            % minAlpha among ACTIVE beams that have alpha defined
            activeMask = ~violateBeam & ~isnan(alphaMinPerBeam);
            if any(activeMask)
                minAlphaThisT = min(minAlphaThisT, min(alphaMinPerBeam(activeMask)));
            end

            % coverage interval (union approx) for overlap metric
            if any(~violateBeam)
                low = min(phiB2_all(~violateBeam));
                high = max(phiB1_all(~violateBeam));
                covIntervals(ii,:) = [low high];
            end
        end

        activeBeams(idxT) = totalBeams - totalOff;
        offBeams(idxT) = totalOff;
        if isfinite(minAlphaThisT)
            minAlpha(idxT) = minAlphaThisT;
        end

        minOverlapDeg(idxT) = compute_min_overlap_deg(covIntervals, leoLatNow);

        t = t + cfg.stepDay;
    end

    % trim
    timeStr = timeStr(1:idxT);
    activeBeams = activeBeams(1:idxT);
    offBeams = offBeams(1:idxT);
    minAlpha = minAlpha(1:idxT);
    minOverlapDeg = minOverlapDeg(1:idxT);

    ts = struct();
    ts.time = timeStr;
    ts.activeBeams = activeBeams;
    ts.offBeams = offBeams;
    ts.minAlphaDeg = minAlpha;
    ts.minOverlapDeg = minOverlapDeg;

    % objective（proxy for Fig.6(a) capacity + penalties）
    meanActive = mean(activeBeams);
    gapPenalty = 0;
    if cfg.enforceSeamless
        gaps = minOverlapDeg;
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
% Helper: default config
% ============================================================
function cfg = pitch2_default_config()
cfg = struct();
cfg.ReKm = 6378.137;
cfg.Nbeam = 16;

% paper params (常見設定；若你已在別處校正可在 opts 覆寫)
cfg.alphaThDeg = 10.0;
cfg.beta0Deg = 23.41;
cfg.betaEllipseDeg = 1.56;

% time window (empty -> 用 scenario Start/Stop)
cfg.tStartStr = "";
cfg.tStopStr = "";
cfg.stepSec = 30;

% pitch selection
cfg.thetaMode = "fixed";       % fixed / brute / ga
cfg.thetaFixedDeg = 0.0;
cfg.thetaBoundsDeg = [0.0 10.0];
cfg.thetaStepDeg = 0.1;

% 是否要求 seamless coverage（用 overlap proxy）
cfg.enforceSeamless = true;
cfg.gapPenaltyWeight = 10.0;   % 每 1 度 gap 的 penalty

% beam control
cfg.symmetricShutoff = false;
cfg.applyToSTK = true;         % 最終跑是否真的去 Show On/Off

% outputs
cfg.writeExcel = false;
cfg.excelOutDir = "";
cfg.makePlots = true;

% GA (toolbox-free simple GA)
cfg.ga = struct();
cfg.ga.popSize = 30;
cfg.ga.generations = 25;
cfg.ga.eliteCount = 2;
cfg.ga.mutationRate = 0.25;
cfg.ga.mutationSigma = 0.5;    % deg
cfg.ga.crossoverRate = 0.7;
cfg.ga.seed = 1;
end

% ============================================================
% Helper: GA optimize (1D, maximize objective)
%   evalFn: @(thetaDeg) -> [ts, stats] 或 {~, stats}
% ============================================================
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
    % evaluate
    for i = 1:numel(pop)
        [~, st] = evalFn(pop(i));
        fit(i) = st.objective;
    end

    % elite
    [fitSorted, idx] = sort(fit, 'descend');
    elite = pop(idx(1:cfg.ga.eliteCount));
    eliteFit = fitSorted(1:cfg.ga.eliteCount);

    if eliteFit(1) > bestFit
        bestFit = eliteFit(1);
        thetaBest = elite(1);
        statsBest = struct('objective', bestFit);
    end

    % selection: roulette on shifted fitness
    f = fit - min(fit) + 1e-9;
    prob = f / sum(f);
    cdf = cumsum(prob);

    newPop = nan(size(pop));
    newPop(1:cfg.ga.eliteCount) = elite;

    for k = (cfg.ga.eliteCount+1):cfg.ga.popSize
        % parents
        p1 = pop(find(cdf >= rand(), 1, 'first'));
        p2 = pop(find(cdf >= rand(), 1, 'first'));

        child = p1;
        if rand() < cfg.ga.crossoverRate
            w = rand();
            child = w*p1 + (1-w)*p2;
        end

        if rand() < cfg.ga.mutationRate
            child = child + cfg.ga.mutationSigma * randn();
        end

        child = min(ub, max(lb, child));
        newPop(k) = child;
    end

    pop = newPop;
end
end

% ============================================================
% Helpers: coverage bounds / overlap proxy
% ============================================================
function [phiB1_all, phiB2_all] = compute_beam_bounds_deg(phiS_deg, RS_km, thetaDeg, cfg, Nbeam)
phiB1_all = nan(1, Nbeam);
phiB2_all = nan(1, Nbeam);

for b = 1:Nbeam
    % ---- Mapping: STK Beam_01 is OUTERMOST ----
    % Paper index bp: 1=outermost, Nbeam=innermost
    bp = Nbeam - b + 1;
    beta_b = cfg.beta0Deg - (2*bp - 1)*cfg.betaEllipseDeg;

    % paper-aligned gate:
    % upper uses beta_b - theta
    % lower uses beta0 + theta
    psi_upper = deg2rad(beta_b - thetaDeg);
    psi_lower = deg2rad(cfg.beta0Deg + thetaDeg);

    delta_upper = rad2deg(acos(g_func(psi_upper, cfg.ReKm, RS_km)));
    delta_lower = rad2deg(acos(g_func(psi_lower, cfg.ReKm, RS_km)));

    phiB1_all(b) = phiS_deg + delta_upper;
    phiB2_all(b) = phiS_deg - delta_lower;
end
end

function minOv = compute_min_overlap_deg(covIntervals, leoLatNow)
% 以同一 time step 下的「衛星 coverage interval」估計相鄰衛星的 overlap。
% 這是 paper Figure 6(c) 的簡化 proxy：overlap<0 表示 coverage gap。

valid = ~any(isnan(covIntervals), 2) & ~isnan(leoLatNow);
covIntervals = covIntervals(valid,:);
leoLatNow = leoLatNow(valid);
if size(covIntervals,1) < 2
    minOv = NaN;
    return;
end

% 以 sub-sat latitude 排序，近似相鄰衛星
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

% ============================================================
% Helpers: STK preload/extraction (paper-aligned: FIXED frame)
% ============================================================
function [leoPosDPs, leoLlaDPs, beamMap] = preloadLeoBeams_Paper(root, leoList, NbeamTarget)
leoPosDPs = containers.Map;
leoLlaDPs = containers.Map;
beamMap = containers.Map;

beamNames = arrayfun(@(k) sprintf('Beam_%02d',k), 1:NbeamTarget, 'UniformOutput', false);
for i = 1:numel(leoList)
    leoName = leoList{i};
    satObj = root.GetObjectFromPath(['*/Satellite/' leoName]);
    leoPosDPs(leoName) = satObj.DataProviders.Item('Cartesian Position').Group.Item('Fixed');
    leoLlaDPs(leoName) = satObj.DataProviders.Item('LLA State').Group.Item('Fixed');

    beams = {};
    for b = 1:numel(beamNames)
        beamPath = sprintf('*/Satellite/%s/Sensor/%s', leoName, beamNames{b});
        try
            root.GetObjectFromPath(beamPath);
            beams{end+1} = beamPath; %#ok<AGROW>
        catch
        end
    end
    if ~isempty(beams)
        beamMap(leoName) = beams;
    end
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

    % GS latitude (deg) (Facility 固定位置，可從 LLA 或 xyz 推)
    lat = NaN;
    try
        res = gsObj.DataProviders.Item('LLA State').Exec;
        arr = res.DataSets.ToArray;
        lat = stkGetLat_FromArray(arr);
    catch
        res = gsObj.DataProviders.Item('Cartesian Position').Exec;
        arr = res.DataSets.ToArray;
        P = stkGetXYZ_FromArray(arr);
        lat = geoLatFromFixedXYZ(P);
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

% ============================================================
% Helpers: geometry
% ============================================================
function alpha = angleDeg_columns(v1_all, v2_all)
num = sum(v1_all .* v2_all, 1);
den = sqrt(sum(v1_all.^2,1)) .* sqrt(sum(v2_all.^2,1)) + eps;
c = num ./ den;
c = min(1, max(-1, c));
alpha = acosd(c);
end

function val = g_func(psi_rad, RE_km, RS_km)
% g(psi) = (RS*sin^2(psi) + cos(psi)*sqrt(RE^2 - RS^2*sin^2(psi))) / RE
s = sin(psi_rad);
c = cos(psi_rad);
under = RE_km^2 - (RS_km^2)*(s.^2);
under = max(under, 0);
val = (RS_km*(s.^2) + c.*sqrt(under)) / RE_km;
val = min(1, max(-1, val));
end

function lat = geoLatFromFixedXYZ(P)
x = P(1); y = P(2); z = P(3);
lat = atan2d(z, sqrt(x^2 + y^2)); % geocentric latitude
end

% ============================================================
% Helpers: STK extraction
% ============================================================
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
        vals(end+1,1) = double(a); %#ok<AGROW>
    end
end
if numel(vals) < 3
    error('STK XYZ extraction failed: found only %d numeric scalars.', numel(vals));
end
P = vals(1:3);
P = P(:);
end

function lat = stkGetLat_FromArray(arr)
vals = [];
for k = 1:numel(arr)
    a = arr{k};
    if isnumeric(a) && isscalar(a)
        vals(end+1,1) = double(a); %#ok<AGROW>
    end
end
if isempty(vals)
    error('STK LLA extraction failed: no numeric scalars found.');
end
lat = vals(1);
end

% ============================================================
% Helpers: config / utils / results
% ============================================================
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
    error('leoList/geoList must be cellstr or string array.');
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
figure('Name', 'pitch2 paper metrics', 'Position', [100 100 1100 700]);

subplot(3,1,1);
plot(ts.activeBeams, 'LineWidth', 1.8);
ylabel('Active beams (proxy capacity)');
grid on;
title(sprintf('Active beams (theta=%.2f deg)', results.thetaBestDeg));

subplot(3,1,2);
plot(ts.minAlphaDeg, 'LineWidth', 1.8);
hold on;
plot([1 numel(ts.minAlphaDeg)], [results.config.alphaThDeg results.config.alphaThDeg], 'r--', 'LineWidth', 1.2);
ylabel('min \\alpha (deg)');
grid on;
title('Minimum discrimination angle (in covered GS)');
legend('min \\alpha', '\\alpha_{th}', 'Location', 'best');

subplot(3,1,3);
plot(ts.minOverlapDeg, 'LineWidth', 1.8);
hold on;
plot([1 numel(ts.minOverlapDeg)], [0 0], 'r--', 'LineWidth', 1.2);
ylabel('min overlap (deg)');
xlabel('time step');
grid on;
title('Coverage overlap proxy (negative = gap)');
legend('min overlap', '0 (no gap)', 'Location', 'best');
end

