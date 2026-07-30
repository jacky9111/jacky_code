function relay = CheckRelayStrictFormula(root, tStr, satNorth, satS2, satSouth, beamHalfH_deg, beamHalfV_deg, varargin)
% CheckRelayStrictFormula
%   Strict relay condition using analytic nadir-rectangular beam geometry (no latitude-band approximation).
%
%   Model (matches STK Rectangular pattern + Nadir):
%   - Earth sphere Re = WGS84 equatorial radius.
%   - LOS from satellite to ground point; off-boresight in (cross-track, along-track) planes via atan2d.
%   - Sample S2 footprint on the sphere by scanning independent half-angles (H, V).
%   - "Upper" half: ground points whose tangent-plane direction from S2 subsatellite aligns toward
%     the north neighbor's subsatellite; "lower" half toward south neighbor.
%   - Strict PASS: every upper-half point lies in north satellite's beam AND every lower-half point
%     lies in south satellite's beam.
%
% Optional name-value:
%   'GridN' (default 41) — samples per axis in (H,V) angle space
%   'TolDeg' (default 0.05) — half-angle tolerance (deg) for inside-beam tests

    p = inputParser;
    addParameter(p, 'GridN', 41, @(x) isnumeric(x) && isscalar(x) && x >= 5);
    addParameter(p, 'TolDeg', 0.05, @(x) isnumeric(x) && isscalar(x) && x >= 0);
    parse(p, varargin{:});
    gridN = round(p.Results.GridN);
    tolDeg = p.Results.TolDeg;

    Re = 6378137.0; % WGS84 a (m), consistent with STK Earth shape for this check

    rN = getPosFixed(root, ['*/Satellite/' satNorth], tStr);
    r2 = getPosFixed(root, ['*/Satellite/' satS2], tStr);
    rS = getPosFixed(root, ['*/Satellite/' satSouth], tStr);

    vN = getVelFixed(root, ['*/Satellite/' satNorth], tStr);
    v2 = getVelFixed(root, ['*/Satellite/' satS2], tStr);
    vS = getVelFixed(root, ['*/Satellite/' satSouth], tStr);

    [b2, c2, t2] = buildNadirRectFrame(r2, v2);
    u_s2 = r2 / max(norm(r2), eps);

    % Horizontal unit vector in tangent plane at S2 subsatellite: toward north neighbor
    u_n = rN / max(norm(rN), eps);
    dirN = u_n - dot(u_n, u_s2) * u_s2;
    ndirN = norm(dirN);
    if ndirN < 1e-9
        error('CheckRelayStrictFormula:CheckFailed', ...
            'North neighbor subsatellite too close to S2 subsatellite direction (degenerate).');
    end
    dirN = dirN / ndirN;

    phi_h_list = linspace(-beamHalfH_deg, beamHalfH_deg, gridN);
    phi_v_list = linspace(-beamHalfV_deg, beamHalfV_deg, gridN);

    nTotal = 0;
    nUpper = 0;
    nLower = 0;
    nUpperFailStrict = 0;
    nLowerFailStrict = 0;
    nUnionFail = 0;

    for ih = 1:gridN
        for iv = 1:gridN
            phi_h = phi_h_list(ih);
            phi_v = phi_v_list(iv);

            d_dir = b2 + tand(phi_h) * c2 + tand(phi_v) * t2;
            nd = norm(d_dir);
            if nd < 1e-12
                continue;
            end
            d = d_dir / nd;

            hit = rayEarthIntersect(r2, d, Re);
            if isempty(hit)
                continue;
            end

            w_gs = hit / max(norm(hit), eps);

            % Must lie inside S2 beam (numerical grid can slightly exceed at corners)
            if ~pointInNadirRectBeam(r2, v2, hit, beamHalfH_deg, beamHalfV_deg, tolDeg)
                continue;
            end

            nTotal = nTotal + 1;

            w_tan = w_gs - dot(w_gs, u_s2) * u_s2;
            upper = dot(w_tan, dirN) >= -1e-9;

            inN = pointInNadirRectBeam(rN, vN, hit, beamHalfH_deg, beamHalfV_deg, tolDeg);
            inS = pointInNadirRectBeam(rS, vS, hit, beamHalfH_deg, beamHalfV_deg, tolDeg);

            if upper
                nUpper = nUpper + 1;
                if ~inN
                    nUpperFailStrict = nUpperFailStrict + 1;
                end
            else
                nLower = nLower + 1;
                if ~inS
                    nLowerFailStrict = nLowerFailStrict + 1;
                end
            end

            if ~(inN || inS)
                nUnionFail = nUnionFail + 1;
            end
        end
    end

    relay = struct();
    relay.GridN = gridN;
    relay.TolDeg = tolDeg;
    relay.beamHalfH_deg = beamHalfH_deg;
    relay.beamHalfV_deg = beamHalfV_deg;
    relay.nSampleInsideS2 = nTotal;
    relay.nUpper = nUpper;
    relay.nLower = nLower;
    relay.nUpperFailStrict = nUpperFailStrict;
    relay.nLowerFailStrict = nLowerFailStrict;
    relay.nUnionFail = nUnionFail;
    relay.passStrictHalves = (nTotal > 0) && (nUpperFailStrict == 0) && (nLowerFailStrict == 0);
    relay.passUnion = (nTotal > 0) && (nUnionFail == 0);
end

%% --- STK Cartesian Fixed (ECEF) -------------------------------------------------

function r_m = getPosFixed(root, path, tStr)
    obj = root.GetObjectFromPath(path);
    dp = obj.DataProviders.Item('Cartesian Position');
    grp = dp.Group.Item('Fixed');
    res = grp.ExecSingle(tStr);
    u = res.DataSets.ToArray;
    [x, y, z] = parseXYZ(u);
    r_m = [x; y; z];
end

function v_mps = getVelFixed(root, path, tStr)
    obj = root.GetObjectFromPath(path);
    dp = obj.DataProviders.Item('Cartesian Velocity');
    grp = dp.Group.Item('Fixed');
    res = grp.ExecSingle(tStr);
    u = res.DataSets.ToArray;
    [vx, vy, vz] = parseXYZ(u);
    v_mps = [vx; vy; vz];
end

function [x, y, z] = parseXYZ(u)
    if isnumeric(u)
        x = u(1);
        y = u(2);
        z = u(3);
    else
        x = str2double(u{1});
        y = str2double(u{2});
        z = str2double(u{3});
    end
end

%% --- Geometry ------------------------------------------------------------------

function [b, c_hat, t_hat] = buildNadirRectFrame(r_s_m, v_s_mps)
    % b: unit boresight from satellite toward Earth center (nadir)
    % c_hat: cross-track (horizontal half-angle plane in STK sense)
    % t_hat: along-track (vertical half-angle plane)
    n_hat = r_s_m / max(norm(r_s_m), eps);
    b = -n_hat;
    v_perp = v_s_mps - dot(v_s_mps, n_hat) * n_hat;
    nv = norm(v_perp);
    if nv < 1e-6
        error('CheckRelayStrictFormula:ZeroVelocity', ...
            'Satellite velocity parallel to radial; cannot build along-track axis.');
    end
    t_hat = v_perp / nv;
    c_hat = cross(n_hat, t_hat);
    c_hat = c_hat / max(norm(c_hat), eps);
end

function hit = rayEarthIntersect(r_s_m, d_unit, Re_m)
    % Ray p = r_s + lambda * d, lambda > 0; smallest positive intersection with ||p|| = Re
    a = 1;
    b = 2 * dot(r_s_m, d_unit);
    c = dot(r_s_m, r_s_m) - Re_m^2;
    disc = b^2 - 4 * a * c;
    if disc < 0
        hit = [];
        return;
    end
    s = sqrt(disc);
    lam1 = (-b - s) / 2;
    lam2 = (-b + s) / 2;
    candidates = [lam1, lam2];
    candidates = candidates(candidates > 0);
    if isempty(candidates)
        hit = [];
        return;
    end
    lambda = min(candidates);
    hit = r_s_m + lambda * d_unit;
end

function ok = pointInNadirRectBeam(r_s_m, v_s_mps, r_g_m, beamHalfH_deg, beamHalfV_deg, tolDeg)
    [b, c_hat, t_hat] = buildNadirRectFrame(r_s_m, v_s_mps);
    los = r_g_m - r_s_m;
    nl = norm(los);
    if nl < 1
        ok = false;
        return;
    end
    d = los / nl;
    % Principal-plane off-boresight angles (deg), consistent with independent H/V limits
    th_h = atan2d(dot(d, c_hat), dot(d, b));
    th_v = atan2d(dot(d, t_hat), dot(d, b));
    ok = (abs(th_h) <= beamHalfH_deg + tolDeg) && (abs(th_v) <= beamHalfV_deg + tolDeg);
end
