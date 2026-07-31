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
%
% 【中文說明】只跑部分密度情境用的篩選器。完整跑四種密度（尤其 High-density
% 的 2664 顆衛星）很花時間，開發或只要補某一列數據時可以先篩掉其他列。
%
% 在 jacky.m 裡對應的變數是：
%   helperConstellationsToRun      統計表那一段（main_helper_availability）
%   helperPlotConstellationsToRun  worst-EPFD 場景圖那一段（main_worst_slot_schematic）
%
% 名稱必須與 config_helper_availability.m 裡的 c.name 完全一致：
%   "OneWeb-like reference" / "Medium-density" / "High-density" / "Low-density"
% 打錯字會直接報錯並列出可用名稱，不會安靜地跑錯情境。

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
