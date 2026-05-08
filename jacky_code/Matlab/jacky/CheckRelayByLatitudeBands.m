function out = CheckRelayByLatitudeBands(root, tStr, satS1, satS2, satS3, alt_km, beamHalfV_deg)
% CheckRelayByLatitudeBands
% Simplified strict check by latitude coverage bands (no Facility / no Access).
% Uses STK satellite latitude at tStr + beam vertical half-angle projected to Earth.
%
% Geocentric half-extent d (deg) from nadir half-angle psi (deg) uses spherical
% triangle O–sat–limb: Re/sin(psi) = Rs/sin(theta+psi)  =>  theta = asin((Rs/Re)*sin(psi)) - psi.
% (The old acos((Re/Rs)*cos(psi))-psi form is wrong: it gives theta>0 at psi=0.)
%
% Limitations (still approximate):
%   - Maps a *circular* cone of half-angle beamHalfV to latitude; STK is *rectangular*
%     (H,V); along-track extent follows V only in the orbit plane — OK as rough polar-shell estimate.
%   - s2Upper = [phi2, phi2+d] assumes "upper half" toward increasing latitude; if the
%     spacecraft is southbound, along-track north may correspond to decreasing phi — use
%     CheckRelayStrictFormula for geometry-consistent halves.
%
% For near-polar shells, this is a practical approximation of your condition:
%   - S2 upper half [phi2, phi2+d] must be inside S1 band
%   - S2 lower half [phi2-d2, phi2] must be inside S3 band

    phi1 = getSatLatFixed(root, satS1, tStr);
    phi2 = getSatLatFixed(root, satS2, tStr);
    phi3 = getSatLatFixed(root, satS3, tStr);

    Re = 6378.137;
    Rs = Re + alt_km;
    d = offNadirToCentralAngleDeg(Rs, Re, beamHalfV_deg);

    band1 = [phi1 - d, phi1 + d];
    band2 = [phi2 - d, phi2 + d];
    band3 = [phi3 - d, phi3 + d];

    s2Upper = [phi2, phi2 + d];
    s2Lower = [phi2 - d, phi2];

    passUpperByS1 = containsInterval(band1, s2Upper);
    passLowerByS3 = containsInterval(band3, s2Lower);
    passAnyRelay = containsInterval(unionIntervals(band1, band3), band2);
    passStrict = passUpperByS1 && passLowerByS3 && passAnyRelay;

    out = struct();
    out.phi1_deg = phi1;
    out.phi2_deg = phi2;
    out.phi3_deg = phi3;
    out.deltaLat_deg = d;
    out.bandS1_deg = band1;
    out.bandS2_deg = band2;
    out.bandS3_deg = band3;
    out.passUpperByS1 = passUpperByS1;
    out.passLowerByS3 = passLowerByS3;
    out.passAllUsersRelay = passAnyRelay;
    out.passStrict = passStrict;
end

function phi = getSatLatFixed(root, satName, tStr)
    sat = root.GetObjectFromPath(['*/Satellite/' satName]);
    dp = sat.DataProviders.Item('LLA State').Group.Item('Fixed');
    res = dp.ExecSingle(tStr);
    vals = numericScalars(res.DataSets.ToArray);
    if numel(vals) < 1
        error('Cannot read latitude for %s at %s', satName, tStr);
    end
    phi = vals(1);
end

function ddeg = offNadirToCentralAngleDeg(Rs, Re, psiDeg)
    % Geocentric angle theta from sub-satellite to cone edge in the plane O–sat–point,
    % given nadir half-angle psi at the satellite (law of sines on triangle O–S–P).
    psi = deg2rad(psiDeg);
    if psi <= 0
        ddeg = 0;
        return;
    end
    arg = (Rs / Re) * sin(psi);
    if arg >= 1
        % Cone wide enough that sin(theta+psi)=1 on the principal branch used below
        theta = (pi / 2) - psi;
    else
        theta = asin(arg) - psi;
    end
    ddeg = max(0, rad2deg(theta));
end

function tf = containsInterval(outer, inner)
    tf = (inner(1) >= outer(1)) && (inner(2) <= outer(2));
end

function u = unionIntervals(a, b)
    u = [min(a(1), b(1)), max(a(2), b(2))];
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
                if ~isnan(n), vals(end+1) = n; end %#ok<AGROW>
            end
        end
    end
end

