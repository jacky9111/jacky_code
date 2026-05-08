function SystemWide16_GSO_EPFD_Control_LogExcel( ...
    root, leoList, geoList, stepSec, endTimeStr)
% ============================================================
% SystemWide16_GSO_EPFD_Control_LogExcel  (Paper-aligned alpha-gate + Excel log)
%
% Core algorithm = your "SystemWide16_GSO_EPFD_Control (paper-aligned)" version:
% (A) alpha at GS: alpha = angle( GS->LEO , GS->GEO )
% (B) threshold:   alpha >= alpha_th
% (C) coverage gate (per beam slice):
%       beta_b = beta0 - (2*bp-1)*betaEllipse     (bp: paper index, 1=outermost)
%       phiB1 = phiS + acos(g(beta_b - theta))
%       phiB2 = phiS - acos(g(beta0 + theta))     (note: lower uses beta0)
%       inCov if phiES in [phiB2, phiB1]
% (D) beam-level shutoff
% (E) OPTIONAL symmetric shutoff: if b violates -> also shut (Nbeam-b+1)
%
% Frame: FIXED (LEO/GEO/GS)
%
% Excel columns (kept original + add):
%   Time | LEO | Latitude | OFFCount | CoversGS | WorstGS
%
% endTimeStr example:
%   '16 Dec 2025 12:30:00'
%   [] -> Scenario StopTime
% ============================================================

sc = root.CurrentScenario;

cfg = defaultPaperConfig();
cfg.stepSec = stepSec;

fprintf("\n=== Paper-aligned control + Excel log (NO GPU) ===\n");
fprintf("step=%d sec | alpha_th=%.2f deg | beta0=%.2f deg | betaEllipse=%.2f deg | pitch(theta)=%.2f deg | symmetric=%d\n", ...
    cfg.stepSec, cfg.alpha_th_deg, cfg.beta0_deg, cfg.betaEllipse_deg, cfg.theta_pitch_deg, cfg.symmetricShutoff);

% ===== Time setup =====
tStart = datenum(sc.StartTime);
tScenarioEnd = datenum(sc.StopTime);

if nargin < 5 || isempty(endTimeStr)
    tEnd = tScenarioEnd;
else
    tUserEnd = datenum(endTimeStr);
    tEnd = min(tScenarioEnd, tUserEnd);
end

step = cfg.stepSec / 86400;

fprintf(">> Simulation start : %s\n", datestr(tStart));
fprintf(">> Simulation end   : %s\n", datestr(tEnd));

% ===== Log path =====
logFolder = 'C:\Users\jacky\Desktop\jacky_code\Matlab_data';
if ~exist(logFolder,'dir'), mkdir(logFolder); end
logFile = fullfile(logFolder,'LEO_Beam16_EPFD_Log.xlsx');  % keep your original name

% ===== Log buffers =====
logTime      = strings(0,1);
logLEO       = strings(0,1);
logLat       = zeros(0,1);
logOffCount  = zeros(0,1);
logCoversGS  = zeros(0,1);    % ★ NEW: 是否覆蓋到任何GS (依 paper gate)
logWorstGS   = strings(0,1);

% ===== Preload STK (paper-aligned FIXED) =====
[leoPosDPs, leoLlaDPs, beamMap] = preloadLeoBeams_Paper(root, leoList);
[geoPosDPs, gsObjMap, gsLatMap] = preloadGeoAndGS_Paper(root, geoList);

t = tStart;

while t <= tEnd
    tStr = datestr(t,'dd mmm yyyy HH:MM:SS');
    root.ExecuteCommand(['Animate * SetTime "' tStr '"']);
    fprintf("\n[Time] %s\n", tStr);

    Ngeo = length(geoList);

    % ----- GEO fixed positions (need time because "Fixed" DP is time-var in STK sense for satellites) -----
    P_geo_all = zeros(3, Ngeo);
    for j = 1:Ngeo
        geoName = geoList{j};
        P_geo_all(:,j) = stkGetXYZ_ExecSingle(geoPosDPs(geoName), tStr);
    end

    % ----- GS fixed XYZ + latitude (facility is effectively fixed; use Exec without time) -----
    P_gs_all  = zeros(3, Ngeo);
    phiES_all = zeros(1, Ngeo);
    for j = 1:Ngeo
        geoName = geoList{j};
        gsObj   = gsObjMap(geoName);

        res = gsObj.DataProviders.Item('Cartesian Position').Exec;
        arr = res.DataSets.ToArray;
        P_gs_all(:,j) = stkGetXYZ_FromArray(arr);

        phiES_all(j) = gsLatMap(geoName);
    end

    % ----- Per LEO -----
    for i = 1:length(leoList)
        leoName = leoList{i};
        if ~isKey(beamMap, leoName)
            continue;
        end

        beamPaths = beamMap(leoName);
        Nbeam = length(beamPaths);

        % LEO fixed XYZ & sub-sat latitude
        P_leo = stkGetXYZ_ExecSingle(leoPosDPs(leoName), tStr);
        lat   = asind(P_leo(3) / norm(P_leo));  % keep your original style (geocentric-ish)

        phiS  = stkGetLat_ExecSingle(leoLlaDPs(leoName), tStr);

        RS_km = norm(P_leo);
        RE_km = cfg.RE_km;

        % alpha for all GS (shared by all beams)
        vLEO = P_leo(:,ones(1,Ngeo)) - P_gs_all;   % GS->LEO
        vGEO = P_geo_all - P_gs_all;              % GS->GEO
        alpha_all = angleDeg_columns(vLEO, vGEO); % 1 x Ngeo

        % -----------------------------
        % Pass 1: evaluate each beam
        % -----------------------------
        violateBeam = false(1, Nbeam);

        log_inCovCount  = zeros(1, Nbeam);
        log_worstGS     = strings(1, Nbeam);
        log_alphaMin    = nan(1, Nbeam);

        % For LEO-level log:
        anyCovered = false;
        globalWorstAlpha = inf;
        globalWorstGS = "NONE";

        for b = 1:Nbeam
            % Mapping: STK Beam_01 is outermost in your setup
            % Paper index bp: 1=outermost, N=innermost
            % If STK Beam_01 is outermost, then bp = b.
            % BUT your earlier debugging showed STK naming might be reversed sometimes,
            % so we keep the same mapping you used in your paper code:
            bp = Nbeam - b + 1;

            beta_b = cfg.beta0_deg - (2*bp - 1)*cfg.betaEllipse_deg;

            % Eq.(2) aligned gate:
            psi_upper = deg2rad(beta_b - cfg.theta_pitch_deg);
            psi_lower = deg2rad(cfg.beta0_deg + cfg.theta_pitch_deg); % lower uses beta0

            delta_upper = rad2deg(acos(g_func(psi_upper, RE_km, RS_km)));
            delta_lower = rad2deg(acos(g_func(psi_lower, RE_km, RS_km)));

            phiB1 = phiS + delta_upper;
            phiB2 = phiS - delta_lower;

            inCov = (phiES_all >= phiB2) & (phiES_all <= phiB1);
            log_inCovCount(b) = sum(inCov);

            if any(inCov)
                anyCovered = true;

                alpha_b = alpha_all(inCov);

                [aMin, idxLocal] = min(alpha_b);
                covIdx = find(inCov);
                jWorst = covIdx(idxLocal);

                log_alphaMin(b) = aMin;
                log_worstGS(b)  = string(geoList{jWorst});

                violateBeam(b) = (aMin < cfg.alpha_th_deg);

                % update global worst (across beams)
                if aMin < globalWorstAlpha
                    globalWorstAlpha = aMin;
                    globalWorstGS = string(geoList{jWorst});
                end
            else
                log_alphaMin(b) = NaN;
                log_worstGS(b)  = "NONE";
                violateBeam(b)  = false;
            end
        end

        % -----------------------------
        % Pass 2: symmetric propagation
        % -----------------------------
        if cfg.symmetricShutoff
            for b = 1:Nbeam
                if violateBeam(b)
                    b_sym = Nbeam - b + 1;
                    violateBeam(b_sym) = true;
                end
            end
        end

        % -----------------------------
        % Pass 3: apply beams once + print always
        % -----------------------------
        for b = 1:Nbeam
            if violateBeam(b)
                root.ExecuteCommand(sprintf('Graphics %s Show Off', beamPaths{b}));
                beamState = "OFF";
            else
                root.ExecuteCommand(sprintf('Graphics %s Show On', beamPaths{b}));
                beamState = "ON";
            end

            fprintf("    %-8s | Beam %02d | state=%s | inCov=%d | worstGS=%s | minAlpha=%s\n", ...
                leoName, b, beamState, log_inCovCount(b), log_worstGS(b), num2str(log_alphaMin(b), '%.2f'));
        end

        offCount = sum(violateBeam);

        % LEO-level worstGS (for Excel)
        if ~anyCovered
            coversGS = 0;
            worstGS_excel = "";
        else
            coversGS = 1;
            worstGS_excel = globalWorstGS;
        end

        fprintf("  %-10s | OFF=%d/%d | coversGS=%d | WorstGS=%s\n", ...
            leoName, offCount, Nbeam, coversGS, worstGS_excel);

        % ===== Log one row per LEO per time =====
        logTime(end+1,1)     = string(tStr);
        logLEO(end+1,1)      = string(leoName);
        logLat(end+1,1)      = lat;
        logOffCount(end+1,1) = offCount;
        logCoversGS(end+1,1) = coversGS;
        logWorstGS(end+1,1)  = worstGS_excel;
    end

    pause(cfg.pauseSec);
    t = t + step;
end

% ===== SAVE EXCEL (ONCE) =====
T = table(logTime, logLEO, logLat, logOffCount, logCoversGS, logWorstGS, ...
    'VariableNames', {'Time','LEO','Latitude','OFFCount','CoversGS','WorstGS'});

writetable(T, logFile);
fprintf("\n=== Simulation finished, Excel saved ===\n%s\n", logFile);

end


% ============================================================
% Config (paper-aligned)
% ============================================================
function cfg = defaultPaperConfig()
cfg.RE_km = 6378.137;

% threshold
cfg.alpha_th_deg = 10.0;

% beam/coverage params
cfg.beta0_deg       = 23.41;
cfg.betaEllipse_deg = 1.56;

% progressive pitch angle
cfg.theta_pitch_deg = 0.0;

% UI
cfg.stepSec  = 30;
cfg.pauseSec = 0.01;

% engineering extension
cfg.symmetricShutoff = true;
end


% ============================================================
% Preload (paper-aligned: FIXED frame)
% ============================================================
function [leoPosDPs, leoLlaDPs, beamMap] = preloadLeoBeams_Paper(root, leoList)
leoPosDPs = containers.Map;
leoLlaDPs = containers.Map;
beamMap   = containers.Map;

beamNames = arrayfun(@(k) sprintf('Beam_%02d',k), 1:16, 'UniformOutput', false);

for i = 1:length(leoList)
    leoName = leoList{i};
    satObj = root.GetObjectFromPath(['*/Satellite/' leoName]);

    leoPosDPs(leoName) = satObj.DataProviders.Item('Cartesian Position').Group.Item('Fixed');
    leoLlaDPs(leoName) = satObj.DataProviders.Item('LLA State').Group.Item('Fixed');

    beams = {};
    for b = 1:length(beamNames)
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
gsObjMap  = containers.Map;
gsLatMap  = containers.Map;

for j = 1:length(geoList)
    geoName = geoList{j};

    geoSat = root.GetObjectFromPath(['*/Satellite/' geoName]);
    geoPosDPs(geoName) = geoSat.DataProviders.Item('Cartesian Position').Group.Item('Fixed');

    gsObj = root.GetObjectFromPath(['*/Facility/GSO_GS_' geoName]);
    gsObjMap(geoName) = gsObj;

    % GS latitude (deg)
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


% ============================================================
% Geometry helpers
% ============================================================
function alpha = angleDeg_columns(v1_all, v2_all)
num = sum(v1_all .* v2_all, 1);
den = sqrt(sum(v1_all.^2,1)) .* sqrt(sum(v2_all.^2,1)) + eps;
c   = num ./ den;
c   = min(1, max(-1, c));
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
% STK extraction helpers
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
