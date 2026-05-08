function SystemWide16_GSO_EPFD_Control(root, leoList, geoList, stepSec)
% ============================================================
% SystemWide16_GSO_Paper_Control  (Paper-aligned, BEAM-level OFF + symmetric option)
%
% (A) Discrimination angle (GS view):
%       alpha = angle( GS->LEO , GS->GEO )   [Eq.(4)]
%
% (B) Threshold:
%       alpha >= alpha_th                   [Eq.(8)(9)]
%
% (C) Coverage gate (per beam slice):
%       beta_b = beta0 - (2*b-1)*betaEllipse
%       phiB1_b , phiB2_b                   [Eq.(1)(2)(3)]
%
% (D) Beam-level shutoff:
%       Each beam evaluated independently
%
% (E) OPTIONAL (engineering extension):
%       symmetric shutoff: if Beam b violates, also shut Beam (Nbeam-b+1)
%
% Coordinate frame:
% - FIXED (LEO / GEO / GS)
% ============================================================

sc = root.CurrentScenario;

cfg = defaultPaperConfig();
cfg.stepSec = stepSec;

fprintf("\n=== Paper-aligned control (BEAM-level OFF) ===\n");
fprintf("step=%d sec | alpha_th=%.2f deg | beta0=%.2f deg | betaEllipse=%.2f deg | pitch(theta)=%.2f deg | symmetric=%d\n", ...
    cfg.stepSec, cfg.alpha_th_deg, cfg.beta0_deg, cfg.betaEllipse_deg, cfg.theta_pitch_deg, cfg.symmetricShutoff);

tStart = datenum('16 Dec 2025 12:10:03');
tEnd   = datenum(sc.StopTime);
step   = cfg.stepSec / 86400;

% ---------- Preload ----------
[leoPosDPs, leoLlaDPs, beamMap] = preloadLeoBeams_Paper(root, leoList);
[geoPosDPs, gsObjMap, gsLatMap] = preloadGeoAndGS_Paper(root, geoList);

t = tStart;
while t <= tEnd
    tStr = datestr(t,'dd mmm yyyy HH:MM:SS');
    root.ExecuteCommand(['Animate * SetTime "' tStr '"']);
    fprintf("\n[Time] %s\n", tStr);

    Ngeo = length(geoList);

    % ----- GEO positions -----
    P_geo_all = zeros(3, Ngeo);
    for j = 1:Ngeo
        geoName = geoList{j};
        P_geo_all(:,j) = stkGetXYZ_ExecSingle(geoPosDPs(geoName), tStr);
    end

    % ----- GS positions & latitudes -----
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
        if ~isKey(beamMap, leoName), continue; end

        beamPaths = beamMap(leoName);
        Nbeam = length(beamPaths);

        % LEO position & sub-sat latitude
        P_leo = stkGetXYZ_ExecSingle(leoPosDPs(leoName), tStr);
        phiS  = stkGetLat_ExecSingle(leoLlaDPs(leoName), tStr);

        % --- Progressive pitch (paper Figure 7, approximate mapping) ---
        % Determine motion direction by comparing latitude a moment later.
        tStr2 = datestr(t + (1/86400), 'dd mmm yyyy HH:MM:SS');
        phiS2 = stkGetLat_ExecSingle(leoLlaDPs(leoName), tStr2);
        dphi  = phiS2 - phiS;
        [thetaAbs_deg, Noff] = progressivePitchParamsApprox(phiS, cfg);

        % Sign rule (paper): depends on ascending/descending and hemisphere.
        % Ascending (dphi>0): theta has opposite sign of phiS.
        % Descending (dphi<0): theta has same sign as phiS.
        if abs(phiS) < 1e-6
            hemiSign = sign(dphi);
            if hemiSign == 0, hemiSign = 1; end
        else
            hemiSign = sign(phiS);
        end
        if dphi >= 0
            thetaPitch_deg = -hemiSign * thetaAbs_deg;
        else
            thetaPitch_deg = +hemiSign * thetaAbs_deg;
        end

        % Geometry constants
        RS_km = norm(P_leo);
        RE_km = cfg.RE_km;

        % Discrimination angle alpha (GS view) — shared by all beams
        vLEO = P_leo(:,ones(1,Ngeo)) - P_gs_all;
        vGEO = P_geo_all - P_gs_all;
        alpha_all = angleDeg_columns(vLEO, vGEO);   % 1 x Ngeo

        % --------------------------------------------------------
        % 1) First pass: evaluate each beam -> decide violate(b)
        % 2) Optional symmetric: propagate violate to symmetric pair
        % 3) Apply ALL beams once (avoid "re-open" issues)
        % --------------------------------------------------------
        violateBeam = false(1, Nbeam);

        % Force shutoff beams away from equator (paper rule).
        % Convention here: Beam_01 is the "farther from equator" side when phiS>0 (north),
        % and Beam_16 is the "farther from equator" side when phiS<0 (south).
        forceOff = false(1, Nbeam);
        if Noff > 0
            Noff_eff = min(Nbeam, max(0, round(Noff)));
            if phiS >= 0
                forceOff(1:Noff_eff) = true;
            else
                forceOff((Nbeam - Noff_eff + 1):Nbeam) = true;
            end
        end

        % Store logs per beam (so we can print after symmetric propagation)
        log_inCovCount = zeros(1, Nbeam);
        log_worstGS    = strings(1, Nbeam);
        log_alphaMin   = nan(1, Nbeam);
        log_coversWorst = false(1, Nbeam);

        log_phiB1   = nan(1, Nbeam);
        log_phiB2   = nan(1, Nbeam);
        log_phiES  = nan(1, Nbeam);
        % ===== Beam-by-beam evaluation (paper gate) =====
        for b = 1:Nbeam

            % ---- Mapping: STK Beam_01 is OUTERMOST ----
            % Paper index "bp": 1 = outermost (largest beta), Nbeam = innermost (smallest beta)
            % If your STK Beam_01 is outermost, then:
            bp = Nbeam - b + 1;  % paper-equivalent index

            beta_b = cfg.beta0_deg - (2*bp - 1)*cfg.betaEllipse_deg;

            % ---- Eq.(2) aligned gate ----
            psi_upper = deg2rad(beta_b - thetaPitch_deg);
            psi_lower = deg2rad(cfg.beta0_deg + thetaPitch_deg);

            delta_upper = rad2deg(acos(g_func(psi_upper, RE_km, RS_km)));
            delta_lower = rad2deg(acos(g_func(psi_lower, RE_km, RS_km)));

            phiB1 = phiS + delta_upper;
            phiB2 = phiS - delta_lower;
            
            log_phiB1(b) = phiB1;
            log_phiB2(b) = phiB2;
            
            inCov = (phiES_all >= phiB2) & (phiES_all <= phiB1);
            log_inCovCount(b) = sum(inCov);

            if any(inCov)
                alpha_b = alpha_all(inCov);

                [alphaMin, idxLocal] = min(alpha_b);
                covIdx  = find(inCov);
                jWorst  = covIdx(idxLocal);

                log_alphaMin(b) = alphaMin;
                log_worstGS(b)  = string(geoList{jWorst});
                log_coversWorst(b) = true;   % 因為 worstGS 就是在 inCov 中選出來的

                violateBeam(b) = forceOff(b) || (alphaMin < cfg.alpha_th_deg);
                log_phiES(b) = phiES_all(jWorst);
            else
                log_alphaMin(b) = NaN;
                log_worstGS(b)  = "NONE";
                log_coversWorst(b) = false;
                violateBeam(b) = forceOff(b);
            end
        end

        % % ===== Optional: symmetric shutoff =====
        % if cfg.symmetricShutoff
        %     for b = 1:Nbeam
        %         if violateBeam(b)
        %             b_sym = Nbeam - b + 1;
        %             violateBeam(b_sym) = true;
        %         end
        %     end
        % end

        % ===== Apply beams ON/OFF once =====
        fprintf("  %-8s | phiS=%.2f deg | thetaAbs=%.2f deg | thetaSigned=%.2f deg | Noff=%d\n", ...
            leoName, phiS, thetaAbs_deg, thetaPitch_deg, Noff);
        for b = 1:Nbeam
            if violateBeam(b)
                root.ExecuteCommand(sprintf('Graphics %s Show Off', beamPaths{b}));
                beamState = "OFF";
            else
                root.ExecuteCommand(sprintf('Graphics %s Show On', beamPaths{b}));
                beamState = "ON";
            end
            % ---- Print ALWAYS ----
            fprintf("    %-8s | Beam %02d | state=%s | inCov=%d | coversWorstGS=%d | worstGS=%s | minAlpha=%s | phiB1=%.2f | phiB2=%.2f | phiES=%.2f\n", ...
                leoName, ...
                b, ...
                beamState, ...
                log_inCovCount(b), ...
                log_coversWorst(b), ...
                log_worstGS(b), ...
                num2str(log_alphaMin(b), '%.2f'), ...
                log_phiB1(b), ...
                log_phiB2(b), ...
                log_phiES(b));

        end
    end

    pause(cfg.pauseSec);
    t = t + step;
end
end

% ============================================================
% Config
% ============================================================
function cfg = defaultPaperConfig()
cfg.RE_km = 6378.137;

% Paper uses INR threshold (I <= 0.06 N => INR <= -12.2 dB) and derives an
% equivalent discrimination-angle threshold alpha_th. Here we keep a practical
% default aligned with typical values used in this paper's Ku downlink examples.
cfg.alpha_th_deg = 10.0;

% Beam geometry (paper Section 2.1 / Figure 3)
cfg.beta0_deg       = 24.5;  % original half-angle of equivalent rectangular beam (deg)
cfg.betaEllipse_deg = 1.56;

% Initial pitch (overridden per-satellite per-time by progressivePitchParamsApprox)
cfg.theta_pitch_deg = 0.0;

% Progressive pitch mapping breakpoints (paper Figure 7)
cfg.theta_max_deg = 10.0;
cfg.phi_theta0_deg  = 30.0;
cfg.phi_thetaMax_deg = 21.96;
cfg.Nellipse = 16;

cfg.stepSec  = 30;
cfg.pauseSec = 0.01;

% >>> Engineering extension: symmetric shutoff <<<
cfg.symmetricShutoff = false;   % true = 關 b 時也關 (Nbeam-b+1)
end

% ============================================================
% Progressive pitch params (approximate, from paper Figure 7)
% ============================================================
function [thetaAbs_deg, Noff] = progressivePitchParamsApprox(phiS_deg, cfg)
% Output:
% - thetaAbs_deg: |theta| (deg)
% - Noff: number of beams to shut off (0..Nellipse)
aphi = abs(phiS_deg);

if aphi >= cfg.phi_theta0_deg
    thetaAbs_deg = 0;
    Noff = 0;
    return;
end

% Ramp theta up to theta_max as phi decreases
if aphi > cfg.phi_thetaMax_deg
    thetaAbs_deg = cfg.theta_max_deg * (cfg.phi_theta0_deg - aphi) / (cfg.phi_theta0_deg - cfg.phi_thetaMax_deg);
    thetaAbs_deg = max(0, min(cfg.theta_max_deg, thetaAbs_deg));
    Noff = 0;
    return;
end

% Low-latitude: theta hits max, then Noff increases ladder-like towards equator.
thetaAbs_deg = cfg.theta_max_deg;

% Approximate ladder by uniform latitude steps to reach all-off at equator.
if aphi < 1e-3
    Noff = cfg.Nellipse;
else
    stepLat = cfg.phi_thetaMax_deg / cfg.Nellipse;
    Noff = ceil((cfg.phi_thetaMax_deg - aphi) / stepLat);
    Noff = max(0, min(cfg.Nellipse, Noff));
end
end

% ============================================================
% Preload functions (paper-aligned: FIXED frame)
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
s = sin(psi_rad);
c = cos(psi_rad);
under = RE_km^2 - (RS_km^2)*(s.^2);
under = max(under, 0);
val = (RS_km*(s.^2) + c.*sqrt(under)) / RE_km;
val = min(1, max(-1, val));
end

function lat = geoLatFromFixedXYZ(P)
x = P(1); y = P(2); z = P(3);
lat = atan2d(z, sqrt(x^2 + y^2));
end

% ============================================================
% STK DataProvider extraction helpers
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
