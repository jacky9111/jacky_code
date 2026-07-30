function result = CheckSinglePlaneRelayCondition(root, sc, tStr, satS1, satS2, satS3, beamHalfH_deg, beamHalfV_deg, gridN, sensorName)
% CheckSinglePlaneRelayCondition
% Strict relay check using STK engine (not hand-derived beam math):
%   - Satellite positions: STK DataProvider "Cartesian Position / Fixed"
%   - In/out of beam: STK Access from ground Facility to Satellite/Sensor at tStr
%   - Upper/lower half of S2 footprint: split by along-track direction from STK positions
%
% Conditions (strict):
%   - Every grid point inside S2 beam (per STK Access): upper half => S1 covers; lower half => S3 covers
%   - Every such point must also be covered by S1 or S3 (redundant with above if halves are consistent)
%
% Inputs:
%   sensorName (optional): must match sensor on each sat (default "RectBeam")

    if nargin < 9 || isempty(gridN)
        gridN = 31; % STK ComputeAccess per point is heavy; keep default moderate
    end
    if nargin < 10 || isempty(sensorName)
        sensorName = "RectBeam";
    end
    sensorName = char(string(sensorName));

    if isempty(sc)
        error('CheckSinglePlaneRelayCondition: scenario (sc) is empty.');
    end

    Re_km = 6378.137;
    r1 = getSatPosFixed(root, satS1, tStr);
    r2 = getSatPosFixed(root, satS2, tStr);
    r3 = getSatPosFixed(root, satS3, tStr);

    [tMinus, tPlus] = makeSafeFiniteDiffTimes(root, tStr, 1);
    v2 = safeSatVelocity(root, satS2, tMinus, tPlus);
    v2 = v2 / max(norm(v2), eps);

    c2 = (Re_km / norm(r2)) * r2;
    nUp = c2 / norm(c2);
    eAlong = v2 - dot(v2, nUp) * nUp;
    if norm(eAlong) < 1e-9
        g13 = ((Re_km / norm(r3)) * r3) - ((Re_km / norm(r1)) * r1);
        eAlong = g13 - dot(g13, nUp) * nUp;
    end
    eAlong = eAlong / max(norm(eAlong), eps);
    eCross = cross(nUp, eAlong);
    eCross = eCross / max(norm(eCross), eps);

    dAlong = offNadirToCentralAngle(norm(r2), Re_km, beamHalfV_deg);
    dCross = offNadirToCentralAngle(norm(r2), Re_km, beamHalfH_deg);
    uList = linspace(-dAlong, dAlong, gridN);
    vList = linspace(-dCross, dCross, gridN);

    facName = 'RelayCheckProbe';
    try
        sc.Children.Item(facName).Unload();
    catch
    end
    probe = sc.Children.New('eFacility', facName);
    probe.Graphics.LabelVisible = false;

    s1s = getSensor(root, satS1, sensorName);
    s2s = getSensor(root, satS2, sensorName);
    s3s = getSensor(root, satS3, sensorName);

    acc1 = probe.GetAccessToObject(s1s);
    acc2 = probe.GetAccessToObject(s2s);
    acc3 = probe.GetAccessToObject(s3s);

    totalS2 = 0;
    upperCnt = 0; upperOk = 0;
    lowerCnt = 0; lowerOk = 0;
    anyRelayOk = 0;

    tn = parseStkTimeToDatenum(tStr);

    for iu = 1:numel(uList)
        for iv = 1:numel(vList)
            g = rotateVec(c2, eCross, uList(iu));
            g = rotateVec(g, eAlong, vList(iv));
            g = Re_km * g / norm(g);

            [lat_deg, lon_deg] = ecefKmToGeodetic(g);

            probe.Position.AssignGeodetic(lat_deg, lon_deg, 0);

            acc1.ComputeAccess();
            acc2.ComputeAccess();
            acc3.ComputeAccess();

            inS2 = timeInComputedAccessIntervals(acc2, tn);
            if ~inS2
                continue;
            end

            totalS2 = totalS2 + 1;

            inS1 = timeInComputedAccessIntervals(acc1, tn);
            inS3 = timeInComputedAccessIntervals(acc3, tn);

            if inS1 || inS3
                anyRelayOk = anyRelayOk + 1;
            end

            if uList(iu) >= 0
                upperCnt = upperCnt + 1;
                if inS1, upperOk = upperOk + 1; end
            else
                lowerCnt = lowerCnt + 1;
                if inS3, lowerOk = lowerOk + 1; end
            end
        end
    end

    passUpper = (upperCnt == 0) || (upperOk == upperCnt);
    passLower = (lowerCnt == 0) || (lowerOk == lowerCnt);
    passAnyRelay = (totalS2 == 0) || (anyRelayOk == totalS2);

    result = struct();
    result.totalS2Points = totalS2;
    result.upperCnt = upperCnt;
    result.upperCoveredByS1 = upperOk;
    result.lowerCnt = lowerCnt;
    result.lowerCoveredByS3 = lowerOk;
    result.anyRelayCovered = anyRelayOk;
    result.passUpperByS1 = passUpper;
    result.passLowerByS3 = passLower;
    result.passAllUsersRelay = passAnyRelay;
    result.passStrict = passUpper && passLower && passAnyRelay;
    result.usesSTKAccess = true;
    result.sensorName = sensorName;
end

function s = getSensor(root, satName, sensorName)
    p = sprintf('*/Satellite/%s/Sensor/%s', satName, sensorName);
    s = root.GetObjectFromPath(p);
end

function ok = timeInComputedAccessIntervals(accessObj, tn)
    ok = false;
    % Try common STK COM property names across versions
    candidates = { 'ComputedAccessIntervalTimes', 'ComputedAccessInterval' };
    for k = 1:numel(candidates)
        try
            col = accessObj.(candidates{k});
            n = col.Count;
            for i = 1:double(n)
                try
                    iv = col.Item(i - 1);
                catch
                    iv = col.Item(i);
                end
                stStr = tryGetIntervalField(iv, {'StartTime', 'Start'});
                enStr = tryGetIntervalField(iv, {'StopTime', 'Stop'});
                st = parseStkTimeToDatenum(stStr);
                en = parseStkTimeToDatenum(enStr);
                if tn >= st && tn <= en
                    ok = true;
                    return;
                end
            end
            return;
        catch
        end
    end
    % Fallback: DataProvider (if intervals API missing)
    try
        dp = accessObj.DataProviders.Item('Access Status');
        res = dp.ExecSingle(datestr(tn, 'dd mmm yyyy HH:MM:SS'));
        arr = res.DataSets.ToArray;
        vals = numericScalars(arr);
        if ~isempty(vals) && any(vals ~= 0)
            ok = true;
        end
    catch
    end
end

function tn = parseStkTimeToDatenum(tStr)
    s = char(string(tStr));
    try
        tn = datenum(s); %#ok<DATNM>
        return;
    catch
    end
    try
        tn = datenum(s, 'dd mmm yyyy HH:MM:SS');
        return;
    catch
    end
    s2 = regexprep(s, '\.\d+$', '');
    tn = datenum(s2, 'dd mmm yyyy HH:MM:SS'); %#ok<DATNM>
end

function r = getSatPosFixed(root, satName, tStr)
    sat = root.GetObjectFromPath(['*/Satellite/' satName]);
    dp = sat.DataProviders.Item('Cartesian Position').Group.Item('Fixed');
    res = dp.ExecSingle(tStr);
    vals = numericScalars(res.DataSets.ToArray);
    if numel(vals) < 3
        error('Cannot read XYZ for %s at %s', satName, tStr);
    end
    r = vals(1:3).';
end

function [lat_deg, lon_deg] = ecefKmToGeodetic(r)
    % Geodetic on sphere Re (matches grid points on Re_km shell)
    x = r(1); y = r(2); z = r(3);
    p = hypot(x, y);
    lat_deg = atan2d(z, p);
    lon_deg = atan2d(y, x);
end

function out = rotateVec(v, axis, angRad)
    k = axis / max(norm(axis), eps);
    out = v * cos(angRad) + cross(k, v) * sin(angRad) + k * dot(k, v) * (1 - cos(angRad));
end

function delta = offNadirToCentralAngle(Rs_km, Re_km, psi_deg)
    psi = deg2rad(psi_deg);
    delta = acos((Re_km / Rs_km) * cos(psi)) - psi;
end

function v = safeSatVelocity(root, satName, tMinus, tPlus)
    try
        v = getSatPosFixed(root, satName, tPlus) - getSatPosFixed(root, satName, tMinus);
        if norm(v) > 0, return; end
    catch
    end
    v = [0; 0; 0];
end

function [tMinusStr, tPlusStr] = makeSafeFiniteDiffTimes(root, tCenterStr, dtSec)
    sc = root.CurrentScenario;
    tCenter = parseStkTimeToDatenum(tCenterStr);
    try
        tStart = parseStkTimeToDatenum(char(sc.StartTime));
        tStop = parseStkTimeToDatenum(char(sc.StopTime));
    catch
        tStart = -inf;
        tStop = inf;
    end
    dtDay = dtSec / 86400;
    tMinus = max(tStart, tCenter - dtDay);
    tPlus = min(tStop, tCenter + dtDay);
    if tPlus <= tMinus
        tMinus = tCenter;
        tPlus = tCenter;
    end
    tMinusStr = datestr(tMinus, 'dd mmm yyyy HH:MM:SS');
    tPlusStr = datestr(tPlus, 'dd mmm yyyy HH:MM:SS');
end

function vals = numericScalars(arr)
    vals = [];
    if isnumeric(arr)
        vals = arr(:).';
        return;
    end
    if iscell(arr)
        for i = 1:numel(arr)
            v = arr{i};
            if isnumeric(v)
                vals = [vals, v(:).']; %#ok<AGROW>
            elseif ischar(v) || isstring(v)
                n = str2double(v);
                if ~isnan(n)
                    vals(end + 1) = n; %#ok<AGROW>
                end
            end
        end
    end
end

function s = tryGetIntervalField(iv, names)
    for j = 1:numel(names)
        try
            s = char(string(iv.(names{j})));
            return;
        catch
        end
    end
    s = '';
end
