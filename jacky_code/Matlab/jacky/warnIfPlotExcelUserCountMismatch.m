function warnIfPlotExcelUserCountMismatch(excelPath, recordSat, expectedUsersPerSat)
% warnIfPlotExcelUserCountMismatch
% Warn when Evaluation reads an Excel tagged U* but assigned_user_count
% suggests a different sweep (common cause of identical U30 vs U50 plots).

if nargin < 3 || ~isfinite(expectedUsersPerSat)
    return;
end
excelPath = char(string(excelPath));
if ~isfile(excelPath)
    return;
end
recordSat = string(recordSat);
expectedUsersPerSat = round(double(expectedUsersPerSat));

T = readtable(excelPath, 'Sheet', 'AvgUserSatisfaction', 'TextType', 'string');
if isempty(T) || ~ismember('assigned_user_count', T.Properties.VariableNames)
    return;
end
satMask = string(T.sat) == recordSat;
if ~any(satMask)
    return;
end
nAssign = median(double(T.assigned_user_count(satMask)), 'omitnan');
if ~isfinite(nAssign)
    return;
end
if abs(nAssign - expectedUsersPerSat) > 8
    warning('jacky:ExcelUserTagMismatch', ...
        ['Plot tag U%d but %s has median assigned_user_count=%.0f on %s. ', ...
        'Set numUsersPerSatPlot to match the Excel you intend to read.'], ...
        expectedUsersPerSat, excelPath, nAssign, recordSat);
end
end
