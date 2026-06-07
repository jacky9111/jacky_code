function assertFig3ExcelPathsMatchPlotTag(numUsersPerSatPlot, excelPaths, recordSat)
% assertFig3ExcelPathsMatchPlotTag
% Ensure Evaluation fig.3 reads *_U* Excel that matches numUsersPerSatPlot.
% Catches stale workspace variables when only a later cell block is re-run.

if nargin < 2 || isempty(excelPaths)
    return;
end
% Must be cellstr: [path1, path2, ...] on char vectors merges into one string → 'C' per index.
if ischar(excelPaths) || isstring(excelPaths)
    excelPaths = cellstr(excelPaths);
elseif ~iscell(excelPaths)
    excelPaths = cell(excelPaths);
end
tag = sprintf('U%d', round(double(numUsersPerSatPlot)));
labels = ["BackoffOnly", "RelayOnly", "SAPR-R", "PcTilt"];
for k = 1:min(numel(labels), numel(excelPaths))
    p = char(string(excelPaths{k}));
    fprintf('Fig3 [%s]: %s\n', labels(k), p);
    if ~isfile(p)
        error('jacky:MissingFig3Excel', 'Fig3 input missing: %s', p);
    end
    if ~contains(p, tag)
        error('jacky:Fig3PathTagMismatch', ...
            ['Path for %s does not contain %s (numUsersPerSatPlot=%d). ', ...
            'Re-run Evaluation from excelBackoffOnly = ... (do not run only the optsFig3 cell).'], ...
            labels(k), tag, round(double(numUsersPerSatPlot)));
    end
end
if nargin >= 3 && strlength(string(recordSat)) > 0
    for k = 1:min(3, numel(excelPaths))
        warnIfPlotExcelUserCountMismatch(excelPaths{k}, recordSat, numUsersPerSatPlot);
    end
end
end
