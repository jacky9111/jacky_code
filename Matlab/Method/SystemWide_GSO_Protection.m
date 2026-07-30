function SystemWide_GSO_Protection(root, leoList, geoList, thresholdDeg, stepSec)

sc = root.CurrentScenario;

fprintf("\n=== System-wide GSO Protection (FULL LOG MODE) ===\n");
fprintf("step = %d sec | threshold = %.1f deg\n\n", stepSec, thresholdDeg);

% -------- Time setup --------
tStart = datenum(sc.StartTime);
tEnd   = datenum(sc.StopTime);
step   = stepSec / 86400;

% -------- Containers --------
leoDPs   = containers.Map;
geoDPs   = containers.Map;
gsObjMap = containers.Map;
beamObj  = containers.Map;

% -------- Preload LEO --------
for i = 1:length(leoList)
    leoName = strtrim(leoList{i});
    satObj  = root.GetObjectFromPath(['*/Satellite/' leoName]);

    leoDPs(leoName) = satObj.DataProviders ...
        .Item('Cartesian Position').Group.Item('ICRF');

    try
        beamObj(leoName) = satObj.Children.Item('RectBeam');
    catch
    end
end

% -------- Preload GEO + GS --------
for j = 1:length(geoList)
    geoName = strtrim(geoList{j});

    geoSat = root.GetObjectFromPath(['*/Satellite/' geoName]);
    geoDPs(geoName) = geoSat.DataProviders ...
        .Item('Cartesian Position').Group.Item('ICRF');

    gsObjMap(geoName) = root.GetObjectFromPath( ...
        ['*/Facility/GSO_GS_' geoName]);
end

% -------- Main loop --------
t = tStart;

while t <= tEnd

    tStr = datestr(t,'dd mmm yyyy HH:MM:SS');
    root.ExecuteCommand(['Animate * SetTime "' tStr '"']);

    for i = 1:length(leoList)

        leoName = strtrim(leoList{i});

        if ~isKey(beamObj, leoName)
            continue;
        end

        % ---- LEO position ----
        leoArr = leoDPs(leoName).ExecSingle(tStr).DataSets.ToArray;
        P_leo  = cell2mat(leoArr(2:4));

        beamOff  = false;
        minTheta = inf;
        worstGeo = "";

        % ---- Loop GEO ----
        for j = 1:length(geoList)

            geoName = strtrim(geoList{j});

            geoArr = geoDPs(geoName).ExecSingle(tStr).DataSets.ToArray;
            P_geo  = cell2mat(geoArr(2:4));

            gsObj = gsObjMap(geoName);
            gsArr = gsObj.DataProviders ...
                .Item('Cartesian Position').Exec.DataSets.ToArray;
            P_gs  = cell2mat(gsArr(1:3));

            v1 = P_geo - P_gs;   % GS → GEO
            v2 = P_leo - P_gs;   % GS → LEO

            cosTheta = dot(v1,v2) / (norm(v1)*norm(v2));

            % numerical safety
            cosTheta = max(-1, min(1, cosTheta));
            theta = acosd(cosTheta);

            % track minimum angle
            if theta < minTheta
                minTheta  = theta;
                worstGeo = geoName;
            end

            % violation check
            if theta < thresholdDeg
                beamOff = true;
            end
        end

        % ---- Apply beam state ----
        if beamOff
            root.ExecuteCommand( ...
                sprintf('Graphics %s Show Off', beamObj(leoName).Path));
            stateStr = "OFF";
        else
            root.ExecuteCommand( ...
                sprintf('Graphics %s Show On', beamObj(leoName).Path));
            stateStr = "ON";
        end

        % ---- FULL LOG (always printed) ----
        fprintf("[%s] LEO=%s | state=%s | minTheta=%.2f deg | worstGEO=%s\n", ...
            tStr, leoName, stateStr, minTheta, worstGeo);

    end

    drawnow;
    pause(0.05);
    t = t + step;
end

fprintf("\n=== ANIMATION FINISHED ===\n");
end
