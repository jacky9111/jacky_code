function SystemWide_GSO_EPFD_SingleBeam(root, leoList, geoList, stepSec)
% ============================================================
% Single Composite Rectangular Beam – Satellite-level EPFD Check
%
% Each LEO is modeled as ONE rectangular beam (envelope of 16 beams)
% If ANY GS is covered AND violates EPFD exclusion:
%   -> hide the whole satellite
% ============================================================

sc = root.CurrentScenario;

fprintf("\n=== EPFD Check : Single Composite Beam (Satellite-level) ===\n");

cfg = defaultCfg();

tStart = datenum(sc.StartTime);
tEnd   = datenum(sc.StopTime);
step   = stepSec / 86400;

% -------- preload --------
leoDPs          = preloadLEO(root, leoList);
[geoDPs, GSpos] = preloadGeoAndGS(root, geoList);

thetaGrid = cfg.thetaGridDeg;
Ggrid     = leoTxGain_dBi(thetaGrid, cfg);

t = tStart;

while t <= tEnd
    tStr = datestr(t,'dd mmm yyyy HH:MM:SS');
    root.ExecuteCommand(['Animate * SetTime "' tStr '"']);
    fprintf("\n[Time] %s\n", tStr);

    for i = 1:length(leoList)
        leoName = leoList{i};

        % --- LEO position ---
        P_leo = stkGetXYZ_ExecSingle(leoDPs(leoName), tStr);

        % --- EPFD exclusion angle ---
        P_gs0 = GSpos(geoList{1});
        d_km  = norm(P_leo - P_gs0);
        thetaMin = invertThetaFromEpfdMask(d_km, cfg, thetaGrid, Ggrid);

        % --- Single composite beam frame (very simple) ---
        [x_hat, y_hat, z_hat] = getSingleBeamFrame();

        interfered = false;

        for j = 1:length(geoList)
            geoName = geoList{j};

            P_geo = stkGetXYZ_ExecSingle(geoDPs(geoName), tStr);
            P_gs  = GSpos(geoName);

            % ---------- Coverage gate ----------
            v = (P_gs - P_leo);
            v = v / norm(v);

            alpha_h = atan2d(dot(v, x_hat), dot(v, z_hat));
            alpha_v = atan2d(dot(v, y_hat), dot(v, z_hat));

            if abs(alpha_h) > cfg.beamHalfAngleHorzDeg || ...
               abs(alpha_v) > cfg.beamHalfAngleVertDeg
                continue;
            end

            % ---------- Exclusion angle ----------
            P_bore = P_leo + cfg.boreRangeKm * z_hat;

            v1 = P_geo  - P_gs;
            v2 = P_bore - P_gs;

            cosT = dot(v1,v2)/(norm(v1)*norm(v2));
            theta = acosd(max(-1,min(1,cosT)));

            if theta < thetaMin
                interfered = true;
                break;
            end
        end

        % ---------- Apply ----------
        if interfered
            root.ExecuteCommand(sprintf('Graphics */Satellite/%s Show Off', leoName));
            fprintf("  %-12s | IN  (hidden)\n", leoName);
        else
            root.ExecuteCommand(sprintf('Graphics */Satellite/%s Show On', leoName));
            fprintf("  %-12s | OUT\n", leoName);
        end
    end

    pause(0.01);
    t = t + step;
end

fprintf("\n=== Finished ===\n");
end

function leoDPs = preloadLEO(root, leoList)
leoDPs = containers.Map;

for i = 1:length(leoList)
    name = leoList{i};
    satObj = root.GetObjectFromPath(['*/Satellite/' name]);
    leoDPs(name) = satObj.DataProviders.Item('Cartesian Position') ...
                                .Group.Item('ICRF');
end
end

function [geoDPs, GSpos] = preloadGeoAndGS(root, geoList)
geoDPs = containers.Map;
GSpos  = containers.Map;

for j = 1:length(geoList)
    name = geoList{j};

    geoSat = root.GetObjectFromPath(['*/Satellite/' name]);
    geoDPs(name) = geoSat.DataProviders.Item('Cartesian Position') ...
                                   .Group.Item('ICRF');

    gsObj = root.GetObjectFromPath(['*/Facility/GSO_GS_' name]);
    res   = gsObj.DataProviders.Item('Cartesian Position').Exec;
    arr   = res.DataSets.ToArray;

    GSpos(name) = stkGetXYZ_FromArray(arr);
end
end

function P = stkGetXYZ_ExecSingle(dp, tStr)
res = dp.ExecSingle(tStr);
arr = res.DataSets.ToArray;
P = stkGetXYZ_FromArray(arr);
end

function P = stkGetXYZ_FromArray(arr)
vals = [];
for k = 1:numel(arr)
    if isnumeric(arr{k}) && isscalar(arr{k})
        vals(end+1,1) = double(arr{k}); %#ok<AGROW>
    end
end
P = vals(1:3);
P = P(:);
end

function [x_hat, y_hat, z_hat] = getSingleBeamFrame()
% One composite rectangular beam
z_hat = [1; 0; 0];   % nadir-like direction
x_hat = [0; 1; 0];   % horizontal
y_hat = [0; 0; 1];   % vertical
end


function cfg = defaultCfg()
cfg.f_GHz = 20;
cfg.EIRP_dBW = 35;
cfg.EPFD_limit_dB = -150;

cfg.thetaGridDeg = 0:0.5:30;
cfg.boreRangeKm = 1000;

% composite beam envelope (你說的 25°)
cfg.beamHalfAngleHorzDeg = 25;
cfg.beamHalfAngleVertDeg = 25;
end

function thetaMin = invertThetaFromEpfdMask(d_km, cfg, thetaGrid, Ggrid)
L = freeSpaceLoss_dB(d_km, cfg.f_GHz);
EPFD_grid = cfg.EIRP_dBW + Ggrid - L;
idx = find(EPFD_grid <= cfg.EPFD_limit_dB, 1,'first');
thetaMin = thetaGrid(min(end, idx));
end

function G = leoTxGain_dBi(thetaDeg, cfg)
G = zeros(size(thetaDeg));
G(thetaDeg < 2) = 30;
G(thetaDeg >= 2 & thetaDeg < 5) = 20;
G(thetaDeg >= 5 & thetaDeg < 10) = 5;
G(thetaDeg >= 10) = -5;
end

function L = freeSpaceLoss_dB(d_km, f_GHz)
L = 92.45 + 20*log10(max(d_km,1e-6)) + 20*log10(f_GHz);
end
