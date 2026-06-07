function slotTable = loadRelayUsersPerSlotLocal(excelPath, recordSat, relayUserMetric, relaySuccessThreshold)
% loadRelayUsersPerSlotLocal
% Per-slot relay user count on home satellite recordSat.
% relayUserMetric:
%   'assigned'  — AvgUserSatisfaction.relay_served_count
%   'satisfied' — Relay_Assignment rows with user_satisfaction >= threshold

excelPath = char(string(excelPath));
recordSat = string(recordSat);
if nargin < 3 || strlength(string(relayUserMetric)) == 0
    relayUserMetric = "assigned";
end
relayUserMetric = lower(string(relayUserMetric));
if nargin < 4 || ~isfinite(relaySuccessThreshold)
    relaySuccessThreshold = 0.9;
end

slotTable = table(string.empty(0, 1), zeros(0, 1), 'VariableNames', {'time', 'relay_user_count'});

switch relayUserMetric
    case "assigned"
        T = readtable(excelPath, 'Sheet', 'AvgUserSatisfaction', 'TextType', 'string');
        if isempty(T) || ~ismember('relay_served_count', T.Properties.VariableNames)
            error('AvgUserSatisfaction.relay_served_count missing in %s', excelPath);
        end
        satMask = string(T.sat) == recordSat;
        if ~any(satMask)
            error('Satellite %s not found in AvgUserSatisfaction (%s).', recordSat, excelPath);
        end
        T = T(satMask, :);
        slotTable = table(string(T.time(:)), double(T.relay_served_count(:)), ...
            'VariableNames', {'time', 'relay_user_count'});

    case {"satisfied", "effective", "satisfiedrelay"}
        try
            T = readtable(excelPath, 'Sheet', 'Relay_Assignment', 'TextType', 'string');
        catch ME
            error('Relay_Assignment sheet missing in %s (re-run sweep with relay ON): %s', ...
                excelPath, ME.message);
        end
        if isempty(T)
            return;
        end
        homeMask = string(T.home_sat) == recordSat;
        T = T(homeMask, :);
        if isempty(T)
            return;
        end
        okMask = double(T.user_satisfaction) >= double(relaySuccessThreshold) - 1e-12;
        times = unique(string(T.time), 'stable');
        times = times(:);
        nT = numel(times);
        counts = zeros(nT, 1);
        for k = 1:nT
            tk = times(k);
            rowMask = string(T.time) == tk & okMask;
            counts(k) = sum(rowMask);
        end
        slotTable = table(times, counts, 'VariableNames', {'time', 'relay_user_count'});

    otherwise
        error('Unknown relayUserMetric: %s', char(relayUserMetric));
end
end
