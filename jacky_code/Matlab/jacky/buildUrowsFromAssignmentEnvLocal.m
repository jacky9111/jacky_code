function Urows = buildUrowsFromAssignmentEnvLocal(userNames, userSatIdx, userBeamIdx, P_users_km, userDemand_bps)
% Map simulated-user assignment to Ku16 Urows struct.

Urows = struct('uid', {}, 'satIdx', {}, 'pos', {}, 'demand', {}, 'servBeam', {});
Nuser = numel(userSatIdx);
for uu = 1:Nuser
    iSat = userSatIdx(uu);
    b = userBeamIdx(uu);
    if iSat < 1 || b < 1
        continue;
    end
    rec.uid = char(string(userNames(uu)));
    rec.satIdx = iSat;
    rec.pos = P_users_km(:, uu);
    rec.demand = userDemand_bps;
    rec.servBeam = 0;
    Urows(end + 1) = rec; %#ok<AGROW>
end
end
