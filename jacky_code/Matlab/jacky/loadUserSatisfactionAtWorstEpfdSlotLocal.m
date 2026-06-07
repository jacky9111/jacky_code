function [sat, meta] = loadUserSatisfactionAtWorstEpfdSlotLocal(excelPath, referenceExcelPath, sourceType, geoName)
% loadUserSatisfactionAtWorstEpfdSlotLocal
% All users at t0 on reference Excel (legacy helper; fig.5 uses buildCdfUserSetLocal).

if nargin < 4
    geoName = "";
end
geoName = string(geoName);
[userIds, setMeta] = buildCdfUserSetLocal(referenceExcelPath, "home_cohort", "P03_S49", geoName);
[sat, loadMeta] = loadUserSatisfactionForUserSetLocal( ...
    excelPath, sourceType, setMeta.t0_time, userIds, geoName);
sat = sat(isfinite(sat));
[~, ~, stats] = empiricalCdfLocal(sat);

meta = setMeta;
meta.n_users = stats.N;
meta.n_found = loadMeta.n_found;
meta.coverage = loadMeta.coverage;
end
