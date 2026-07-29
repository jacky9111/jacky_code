function cfg = select_helper_constellations(cfg, selection)
%SELECT_HELPER_CONSTELLATIONS Subset cfg.constellations for partial runs.
%
% selection examples:
%   "all"                    — run every row in config (default behaviour)
%   "Low-density"            — one constellation by exact name
%   ["OneWeb-like reference", "Low-density"]
%   {"High-density", "Low-density"}
%
% Names must match cfg.constellations{i}.name exactly.

if nargin < 2 || isempty(selection)
    return;
end

if ischar(selection) || (isstring(selection) && isscalar(selection))
    if strcmpi(string(selection), "all")
        return;
    end
    namesWanted = string(selection);
else
    namesWanted = string(selection(:));
end
namesWanted = namesWanted(strlength(namesWanted) > 0);
if isempty(namesWanted)
    return;
end

nConst = numel(cfg.constellations);
allNames = string(cellfun(@(c) string(c.name), cfg.constellations, 'UniformOutput', false));
allNames = allNames(:);
keep = false(nConst, 1);
for iName = 1:numel(namesWanted)
    hit = strcmp(allNames, namesWanted(iName));
    hit = hit(:);
    if ~any(hit)
        error('select_helper_constellations:UnknownName', ...
            'Unknown constellation "%s". Available: %s', ...
            namesWanted(iName), strjoin(allNames, ' | '));
    end
    keep = keep | hit;
end

cfg.constellations = cfg.constellations(keep);
fprintf('[helper] running subset: %s\n', strjoin(allNames(keep), ' | '));
end
