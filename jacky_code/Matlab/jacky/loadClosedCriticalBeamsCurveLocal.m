function curve = loadClosedCriticalBeamsCurveLocal(excelPath, critSat, sourceType)
% loadClosedCriticalBeamsCurveLocal
% sourceType: 'fullpower' (Slot_EPFD) | 'ku16_pc_tilt' (PerBeam+Global)
curve = struct('times', strings(0, 1), 'nClosed', [], 'source', sourceType);
excelPath = char(string(excelPath));
if ~isfile(excelPath)
    error('Excel not found: %s', excelPath);
end
critSat = string(critSat);

switch lower(string(sourceType))
    case "fullpower"
        T = readtable(excelPath, 'Sheet', 'Slot_EPFD', 'TextType', 'string');
        if isempty(T)
            error('Slot_EPFD empty in %s', excelPath);
        end
        curve.times = string(T.time);
        curve.nClosed = closedCriticalCountFromSlotTableLocal(T, excelPath, critSat);

    case {"ku16_pc_tilt", "ku16", "pc_tilt"}
        Tg = readtable(excelPath, 'Sheet', 'Global', 'TextType', 'string');
        Tb = readtable(excelPath, 'Sheet', 'PerBeam', 'TextType', 'string');
        times = string(Tg.time);
        nClosed = zeros(numel(times), 1);
        for k = 1:numel(times)
            tK = times(k);
            if ismember('critical_satellite_id', Tg.Properties.VariableNames)
                critK = string(Tg.critical_satellite_id(k));
                if strlength(critK) == 0
                    critK = critSat;
                end
            else
                critK = critSat;
            end
            rowMask = string(Tb.time) == tK & string(Tb.satellite_id) == critK;
            if ismember('pc_adjusted_flag', Tb.Properties.VariableNames)
                nClosed(k) = sum(rowMask & double(Tb.pc_adjusted_flag) > 0);
            elseif ismember('assigned_power_W', Tb.Properties.VariableNames)
                nClosed(k) = sum(rowMask & double(Tb.assigned_power_W) <= 1e-12);
            else
                nClosed(k) = 0;
            end
        end
        curve.times = times;
        curve.nClosed = nClosed;

    otherwise
        error('Unknown sourceType: %s', char(sourceType));
end
end

function nClosed = closedCriticalCountFromSlotTableLocal(T, excelPath, critSat)
if ismember('critical_sat_closed_beam_count', T.Properties.VariableNames)
    nClosed = double(T.critical_sat_closed_beam_count);
    return;
end
nClosed = zeros(height(T), 1);
times = string(T.time);
Tv = readtable(excelPath, 'Sheet', 'ViolatingSat_16BeamState', 'TextType', 'string');
for k = 1:height(T)
    tK = times(k);
    rowMask = string(Tv.time) == tK & string(Tv.sat) == critSat & Tv.shut_off > 0;
    nClosed(k) = sum(rowMask);
end
end
