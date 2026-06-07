function meta = resolveWorstEpfdSlotLocal(referenceExcelPath, geoName)
% resolveWorstEpfdSlotLocal  t0 = argmax(gs_epfd_before_dB) on Slot_EPFD.

if nargin < 2
    geoName = "";
end
geoName = string(geoName);
referenceExcelPath = char(string(referenceExcelPath));

Tref = readtable(referenceExcelPath, 'Sheet', 'Slot_EPFD', 'TextType', 'string');
if isempty(Tref)
    error('Slot_EPFD empty in %s', referenceExcelPath);
end
if strlength(geoName) > 0 && ismember('geo', Tref.Properties.VariableNames)
    Tref = Tref(string(Tref.geo) == geoName, :);
end
if isempty(Tref)
    error('No Slot_EPFD rows for geo filter in %s', referenceExcelPath);
end

epfdCol = double(Tref.gs_epfd_before_dB);
[~, i0] = max(epfdCol);
meta = struct();
meta.t0_time = string(Tref.time(i0));
meta.t0_epfd_before_dB = epfdCol(i0);
meta.geo = geoName;
end
