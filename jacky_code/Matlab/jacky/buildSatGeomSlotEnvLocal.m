function satGeom = buildSatGeomSlotEnvLocal(leoList, satPos, satVel, beamBores, beamCAxis)
% Build per-slot satGeom struct array for Ku16 / full-power user assignment.

Nsat = numel(leoList);
satGeom = repmat(struct('satName', "", 'P_leo_km', [], 'b_all', [], 'c_axis', [], ...
    'subLat', [], 'subLon', []), Nsat, 1);
for iSat = 1:Nsat
    P_leo_km = satPos(:, iSat);
    satGeom(iSat).satName = string(leoList{iSat});
    satGeom(iSat).P_leo_km = P_leo_km;
    satGeom(iSat).b_all = beamBores{iSat};
    satGeom(iSat).c_axis = beamCAxis{iSat};
    satGeom(iSat).subLat = asind(P_leo_km(3) / max(norm(P_leo_km), eps));
    satGeom(iSat).subLon = atan2d(P_leo_km(2), P_leo_km(1));
end
end
