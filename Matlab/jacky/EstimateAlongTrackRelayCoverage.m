function stats = EstimateAlongTrackRelayCoverage(alt_km, beamHalfAlongTrack_deg, satsPerPlane)
% EstimateAlongTrackRelayCoverage
% 1D along-track approximation:
%   - S2 beam center at 0 deg (sub-satellite central angle)
%   - S1/S3 centers at +/- Delta, Delta = 360 / satsPerPlane
%   - each beam edge at +/- deltaEdge around its own center
%
% This estimates how much of S2 interval [-deltaEdge, +deltaEdge]
% can be covered by S1+S3 when S2 is turned off.

    Re_km = 6378.137;
    Rs_km = Re_km + alt_km;

    psi = deg2rad(beamHalfAlongTrack_deg);

    % Ground central half-angle from nadir beam half-angle.
    % Valid for Earth-intersecting cone.
    deltaEdge = acos((Re_km / Rs_km) * cos(psi)) - psi; % rad
    deltaEdge_deg = rad2deg(deltaEdge);

    deltaSat_deg = 360 / satsPerPlane;

    if deltaSat_deg <= deltaEdge_deg
        coveredRatio = 1.0; % full replacement along-track
    elseif deltaSat_deg >= 2 * deltaEdge_deg
        coveredRatio = 0.0; % no replacement
    else
        coveredRatio = 2 - (deltaSat_deg / deltaEdge_deg);
    end

    coveredRatio = max(0, min(1, coveredRatio));
    gapRatio = 1 - coveredRatio;

    % Minimum sats/plane for full replacement in this 1D approximation.
    minSatsPerPlaneFull = ceil(360 / max(deltaEdge_deg, eps));

    stats = struct();
    stats.deltaSat_deg = deltaSat_deg;
    stats.deltaEdge_deg = deltaEdge_deg;
    stats.coveredRatio = coveredRatio;
    stats.gapRatio = gapRatio;
    stats.minSatsPerPlaneFull = minSatsPerPlaneFull;
end

