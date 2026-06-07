function tRelByTime = buildTimeOffsetMapFromSlotEpfdLocal(referenceExcelPath)
% buildTimeOffsetMapFromSlotEpfdLocal  Map Slot_EPFD time strings -> seconds from t=0.

Tref = readtable(char(string(referenceExcelPath)), 'Sheet', 'Slot_EPFD', 'TextType', 'string');
tRelRef = FullPowerSweepSlotTimeOffsetLocal(Tref, struct());
times = string(Tref.time);
tRelByTime = containers.Map('KeyType', 'char', 'ValueType', 'double');
for k = 1:numel(times)
    tRelByTime(char(times(k))) = tRelRef(k);
end
end
