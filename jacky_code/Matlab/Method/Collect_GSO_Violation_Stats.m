function stats = Collect_GSO_Violation_Stats(root, leoList, geoList, thresholdDeg, stepSec)
% ============================================================
% Collect_GSO_Violation_Stats  (INTERRUPT-SAFE VERSION)
% ============================================================

sc = root.CurrentScenario;

fprintf("\n=== Collecting GSO Violation Statistics (INTERRUPT SAFE) ===\n");
fprintf("LEO=%d, GEO=%d, step=%d sec, threshold=%.1f deg\n", ...
    length(leoList), length(geoList), stepSec, thresholdDeg);

% ---------------- Time setup ----------------
tStart = datenum(sc.StartTime);
tEnd   = datenum(sc.StopTime);
step   = stepSec / 86400;

% ---------------- Initialize stats ----------------
stats.GEO = containers.Map;
stats.LEO = containers.Map;

for j = 1:length(geoList)
    stats.GEO(geoList{j}) = 0;
end
for i = 1:length(leoList)
    stats.LEO(leoList{i}) = 0;
end

stats.totalSteps = 0;
stats.meta.thresholdDeg = thresholdDeg;
stats.meta.stepSec      = stepSec;
stats.meta.startTime    = sc.StartTime;
stats.meta.stopTime     = sc.StopTime;

% ---------------- Preload DataProviders ----------------
geoDPs = containers.Map;
gsPos  = containers.Map;
leoDPs = containers.Map;

for j = 1:length(geoList)
    geoName = geoList{j};

    geoSat = root.GetObjectFromPath(['*/Satellite/' geoName]);
    geoDPs(geoName) = geoSat.DataProviders ...
        .Item('Cartesian Position').Group.Item('ICRF');

    gsObj = root.GetObjectFromPath(['*/Facility/GSO_GS_' geoName]);
    resGS = gsObj.DataProviders.Item('Cartesian Position').Exec;
    gsArr = resGS.DataSets.ToArray;
    gsPos(geoName) = cell2mat(gsArr(1:3));
end

for i = 1:length(leoList)
    leoName = leoList{i};
    satObj = root.GetObjectFromPath(['*/Satellite/' leoName]);

    leoDPs(leoName) = satObj.DataProviders ...
        .Item('Cartesian Position').Group.Item('ICRF');
end

cosThresh = cosd(thresholdDeg);

% ================= MAIN LOOP (PROTECTED) =================
t = tStart;

try
    while t <= tEnd

        tStr = datestr(t,'dd mmm yyyy HH:MM:SS');
        stats.totalSteps = stats.totalSteps + 1;

        fprintf('[STEP %5d] STK time = %s\n', stats.totalSteps, tStr);

        % ---- core computation ----
        for i = 1:length(leoList)

            leoName = leoList{i};
            leoArr  = leoDPs(leoName).ExecSingle(tStr).DataSets.ToArray;
            P_leo   = cell2mat(leoArr(2:4));

            leoViolated = false;

            for j = 1:length(geoList)

                geoName = geoList{j};

                geoArr = geoDPs(geoName).ExecSingle(tStr).DataSets.ToArray;
                P_geo  = cell2mat(geoArr(2:4));

                P_gs = gsPos(geoName);

                v1 = P_geo - P_gs;
                v2 = P_leo - P_gs;

                cosTheta = dot(v1,v2) / (norm(v1)*norm(v2));
                if cosTheta < cosThresh
                    continue;
                end

                if acosd(cosTheta) < thresholdDeg
                    stats.GEO(geoName) = stats.GEO(geoName) + 1;
                    leoViolated = true;
                end
            end

            if leoViolated
                stats.LEO(leoName) = stats.LEO(leoName) + 1;
            end
        end

        % ---- checkpoint every 10 steps ----
        if mod(stats.totalSteps,10) == 0
            save('GSO_stats_checkpoint.mat','stats');
        end

        t = t + step;
    end

catch ME
    fprintf('\n⚠️ Interrupted at STEP %d, saving stats...\n', stats.totalSteps);
    save('GSO_stats_interrupt.mat','stats');
    rethrow(ME);   % 讓 Ctrl+C 正常中斷
end

% ---------------- Normal end ----------------
save('GSO_stats_final.mat','stats');

fprintf("=== Statistics Collection Finished ===\n");
fprintf("Total time steps: %d\n", stats.totalSteps);

end
