function stats = EvaluateRelayCoverage_STKGeometry(root, tStr, satS1, satS2, satS3, beamHalfH_deg, beamHalfV_deg, gridN)
% EvaluateRelayCoverage_STKGeometry
% STK-driven geometric check for "S2 off, relayed by S1/S3".
%
% Method:
%   1) Read S1/S2/S3 Cartesian (Fixed) positions from STK at tStr.
%   2) Build S2 local tangent frame and sample points across its rectangular footprint.
%   3) Keep points that are truly inside S2 beam (actual geometric test).
%   4) Compute how many of those points are still covered by S1 or S3.
%
% Output fields:
%   totalS2Points, coveredByS1S3, coveredRatio, gapRatio

    if nargin < 9 || isempty(gridN)
        gridN = 41; % odd grid keeps center sample
    end

    Re_km = 6378.137;

    % Read STK satellite position (ECEF/Fixed, km)
    r1 = getSatPosFixed(root, satS1, tStr);
    r2 = getSatPosFixed(root, satS2, tStr);
    r3 = getSatPosFixed(root, satS3, tStr);

    % Approximate velocity direction with boundary-safe finite difference.
    [tMinus, tPlus] = makeSafeFiniteDiffTimes(root, tStr, 1);
    v2 = safeSatVelocity(root, satS2, tMinus, tPlus);
    v2 = v2 / max(norm(v2), eps);

    % Local frame at S2 subsat point.
    c2 = (Re_km / norm(r2)) * r2;    % nadir point on Earth sphere
    nUp = c2 / norm(c2);

    % Along-track direction projected to local tangent.
    eAlong = v2 - dot(v2, nUp) * nUp;
    if norm(eAlong) < 1e-9
        % fallback: use S1->S3 ground direction
        g13 = ((Re_km / norm(r3)) * r3) - ((Re_km / norm(r1)) * r1);
        eAlong = g13 - dot(g13, nUp) * nUp;
    end
    eAlong = eAlong / max(norm(eAlong), eps);
    eCross = cross(nUp, eAlong);
    eCross = eCross / max(norm(eCross), eps);

    % Convert sensor half-angles to equivalent ground central half-angles.
    dAlong = offNadirToCentralAngle(norm(r2), Re_km, beamHalfV_deg); % along-track uses vertical half-angle
    dCross = offNadirToCentralAngle(norm(r2), Re_km, beamHalfH_deg); % cross-track uses horizontal half-angle

    uList = linspace(-dAlong, dAlong, gridN); % rad
    vList = linspace(-dCross, dCross, gridN); % rad

    totalS2 = 0;
    coveredRelay = 0;

    for iu = 1:numel(uList)
        for iv = 1:numel(vList)
            % Build candidate ground point by rotating center vector on sphere.
            g = rotateVec(c2, eCross, uList(iu));
            g = rotateVec(g,   eAlong, vList(iv));
            g = Re_km * g / norm(g);

            inS2 = isPointInRectBeam(r2, g, v2, beamHalfH_deg, beamHalfV_deg);
            if ~inS2
                continue;
            end

            totalS2 = totalS2 + 1;

            inS1 = isPointInRectBeam(r1, g, [], beamHalfH_deg, beamHalfV_deg);
            inS3 = isPointInRectBeam(r3, g, [], beamHalfH_deg, beamHalfV_deg);

            if inS1 || inS3
                coveredRelay = coveredRelay + 1;
            end
        end
    end

    ratio = coveredRelay / max(totalS2, 1);

    stats = struct();
    stats.totalS2Points = totalS2;
    stats.coveredByS1S3 = coveredRelay;
    stats.coveredRatio = ratio;
    stats.gapRatio = 1 - ratio;
    stats.gridN = gridN;
    stats.tStr = tStr;
    stats.sats = [string(satS1), string(satS2), string(satS3)];
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

function v = safeSatVelocity(root, satName, tMinus, tPlus)
    % Try central difference first; fallback to one-sided difference.
    try
        rPlus = getSatPosFixed(root, satName, tPlus);
        rMinus = getSatPosFixed(root, satName, tMinus);
        v = rPlus - rMinus;
        if norm(v) > 0
            return;
        end
    catch
    end

    try
        r0 = getSatPosFixed(root, satName, tMinus);
        r1 = getSatPosFixed(root, satName, tPlus);
        v = r1 - r0;
        if norm(v) > 0
            return;
        end
    catch
    end

    % Last resort: return zero and let caller fallback to S1->S3 direction.
    v = [0;0;0];
end

function [tMinusStr, tPlusStr] = makeSafeFiniteDiffTimes(root, tCenterStr, dtSec)
    % Clamp finite-difference times into scenario [start, stop].
    sc = root.CurrentScenario;
    tCenter = datenum(tCenterStr);

    try
        tStart = datenum(char(sc.StartTime));
        tStop = datenum(char(sc.StopTime));
    catch
        % If scenario time cannot be parsed, fall back to unclamped times.
        tStart = -inf;
        tStop = inf;
    end

    dtDay = dtSec / 86400;

    tMinus = max(tStart, tCenter - dtDay);
    tPlus  = min(tStop,  tCenter + dtDay);

    % Ensure we still have separation; if center is at boundary, use one-sided.
    if tPlus <= tMinus
        tMinus = max(tStart, tCenter - 2*dtDay);
        tPlus  = min(tStop,  tCenter);
        if tPlus <= tMinus
            tMinus = tCenter;
            tPlus = tCenter;
        end
    end

    tMinusStr = datestr(tMinus, 'dd mmm yyyy HH:MM:SS');
    tPlusStr  = datestr(tPlus,  'dd mmm yyyy HH:MM:SS');
end

function ok = isPointInRectBeam(rSat, rGround, vApprox, halfH_deg, halfV_deg)
    % Build a nadir-pointing local frame at satellite.
    zDown = -rSat / max(norm(rSat), eps);

    if isempty(vApprox)
        % fallback frame when velocity is unknown
        tmp = [0;0;1];
        if abs(dot(tmp, zDown)) > 0.95
            tmp = [0;1;0];
        end
        xAxis = cross(tmp, zDown);
    else
        xAxis = vApprox - dot(vApprox, zDown) * zDown;
    end
    xAxis = xAxis / max(norm(xAxis), eps);
    yAxis = cross(zDown, xAxis);
    yAxis = yAxis / max(norm(yAxis), eps);

    q = rGround - rSat; % sat -> ground vector
    qn = q / max(norm(q), eps);

    % Must point roughly toward nadir hemisphere.
    if dot(qn, zDown) <= 0
        ok = false;
        return;
    end

    % Decompose off-nadir into local x/y angular components.
    qx = dot(qn, xAxis);
    qy = dot(qn, yAxis);
    qz = dot(qn, zDown);

    angX = atan2d(qx, qz);
    angY = atan2d(qy, qz);

    ok = (abs(angX) <= halfH_deg) && (abs(angY) <= halfV_deg);
end

function out = rotateVec(v, axis, angRad)
    % Rodrigues rotation
    k = axis / max(norm(axis), eps);
    out = v*cos(angRad) + cross(k, v)*sin(angRad) + k*dot(k, v)*(1-cos(angRad));
end

function delta = offNadirToCentralAngle(Rs_km, Re_km, psi_deg)
    psi = deg2rad(psi_deg);
    delta = acos((Re_km / Rs_km) * cos(psi)) - psi; % rad
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
            if isnumeric(v), vals = [vals, v(:).']; %#ok<AGROW>
            elseif ischar(v) || isstring(v)
                n = str2double(v);
                if ~isnan(n), vals(end+1) = n; end %#ok<AGROW>
            end
        end
        return;
    end
    try
        c = cell(arr);
        vals = numericScalars(c);
    catch
    end
end

