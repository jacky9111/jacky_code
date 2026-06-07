function curve = loadMethodSatisfactionCurveLocal(excelPath, recordSat, sourceType)
% loadMethodSatisfactionCurveLocal
% Home-cohort / satellite average user satisfaction vs time.
% sourceType: 'fullpower' (AvgUserSatisfaction) | 'ku16_pc_tilt' (PerSatellite)

curve = struct('times', strings(0, 1), 'avgSat', [], 'source', sourceType);
excelPath = char(string(excelPath));
if ~isfile(excelPath)
    error('Excel not found: %s', excelPath);
end
recordSat = string(recordSat);

switch lower(string(sourceType))
    case "fullpower"
        T = readtable(excelPath, 'Sheet', 'AvgUserSatisfaction', 'TextType', 'string');
        if isempty(T)
            error('AvgUserSatisfaction empty in %s', excelPath);
        end
        satMask = string(T.sat) == recordSat;
        if ~any(satMask)
            error('Satellite %s not found in AvgUserSatisfaction (%s).', recordSat, excelPath);
        end
        T = T(satMask, :);
        curve.times = string(T.time);
        curve.avgSat = double(T.avg_user_satisfaction);

    case {"ku16_pc_tilt", "ku16", "pc_tilt"}
        T = readtable(excelPath, 'Sheet', 'PerSatellite', 'TextType', 'string');
        if isempty(T)
            error('PerSatellite empty in %s', excelPath);
        end
        satMask = string(T.satellite_id) == recordSat;
        if ~any(satMask)
            error('Satellite %s not found in PerSatellite (%s).', recordSat, excelPath);
        end
        T = T(satMask, :);
        curve.times = string(T.time);
        curve.avgSat = double(T.satellite_average_satisfaction);

    otherwise
        error('Unknown sourceType: %s', char(sourceType));
end
end
