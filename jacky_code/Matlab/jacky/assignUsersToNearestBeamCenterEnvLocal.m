function [userCountMat, userSatIdx, userBeamIdx] = assignUsersToNearestBeamCenterEnvLocal( ...
    satGeom, P_users_km, beamHalfEW_deg, beamHalfNS_deg)
% Same nearest-subpoint + in-footprint beam assignment as full-power sweep.

Nsat = numel(satGeom);
Nbeam = size(satGeom(1).b_all, 2);
Nuser = size(P_users_km, 2);
userCountMat = zeros(Nsat, Nbeam);
userSatIdx = zeros(Nuser, 1);
userBeamIdx = zeros(Nuser, 1);

for iu = 1:Nuser
    userLat = asind(P_users_km(3, iu) / max(norm(P_users_km(:, iu)), eps));
    userLon = atan2d(P_users_km(2, iu), P_users_km(1, iu));
    bestSat = nearestSatelliteSubpointEnvLocal(satGeom, userLat, userLon, 1:Nsat);
    [bestBeam, ~] = bestCoveredBeamForUserEnvLocal(satGeom(bestSat), P_users_km(:, iu), ...
        beamHalfEW_deg, beamHalfNS_deg);
    if bestSat > 0 && bestBeam > 0
        userCountMat(bestSat, bestBeam) = userCountMat(bestSat, bestBeam) + 1;
        userSatIdx(iu) = bestSat;
        userBeamIdx(iu) = bestBeam;
    end
end
end

function [bestBeam, bestMetric] = bestCoveredBeamForUserEnvLocal(satGeomOne, P_user_km, beamHalfEW_deg, beamHalfNS_deg)
Nbeam = size(satGeomOne.b_all, 2);
P_leo_km = satGeomOne.P_leo_km;
b_all = satGeomOne.b_all;
c_axis = satGeomOne.c_axis;
bestBeam = 0;
bestMetric = inf;
v_user_m = (P_user_km(:) - P_leo_km(:)) * 1000;
d_m = norm(v_user_m);
if d_m < 1
    return;
end
d_hat = v_user_m / d_m;
for b = 1:Nbeam
    b_hat = b_all(:, b);
    t_axis = cross(c_axis, b_hat);
    t_axis = t_axis / max(norm(t_axis), eps);
    th_h = atan2d(dot(d_hat, c_axis), dot(d_hat, b_hat));
    th_v = atan2d(dot(d_hat, t_axis), dot(d_hat, b_hat));
    if abs(th_h) > beamHalfEW_deg || abs(th_v) > beamHalfNS_deg
        continue;
    end
    metric = hypot(th_h / max(beamHalfEW_deg, eps), th_v / max(beamHalfNS_deg, eps));
    if metric < bestMetric
        bestMetric = metric;
        bestBeam = b;
    end
end
end

function bestSat = nearestSatelliteSubpointEnvLocal(satGeom, userLat, userLon, candidateIdx)
bestSat = candidateIdx(1);
bestCentralAngle = inf;
for iSat = candidateIdx
    centralAngle = greatCircleDistanceDegEnvLocal(userLat, userLon, satGeom(iSat).subLat, satGeom(iSat).subLon);
    if centralAngle < bestCentralAngle
        bestCentralAngle = centralAngle;
        bestSat = iSat;
    end
end
end

function d_deg = greatCircleDistanceDegEnvLocal(lat1, lon1, lat2, lon2)
dlat = deg2rad(lat2 - lat1);
dlon = deg2rad(lon2 - lon1);
a = sin(dlat / 2)^2 + cosd(lat1) * cosd(lat2) * sin(dlon / 2)^2;
d_deg = rad2deg(2 * atan2(sqrt(a), sqrt(max(0, 1 - a))));
end
