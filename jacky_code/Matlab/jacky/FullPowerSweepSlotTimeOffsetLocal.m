function tRel = FullPowerSweepSlotTimeOffsetLocal(T, opts)
% FullPowerSweepSlotTimeOffsetLocal  Seconds relative to worst pre-backoff EPFD slot (t=0).
% Uses gs_epfd_before_dB maximum unless opts.timeReference = 'criticalOverhead'.
if nargin < 2
    opts = struct();
end
if isfield(opts, 'timeReference') && strlength(string(opts.timeReference)) > 0
    timeRef = lower(string(opts.timeReference));
else
    timeRef = "worstepfd";
end
if timeRef == "criticaloverhead" && ismember('seconds_from_critical', T.Properties.VariableNames)
    tRel = double(T.seconds_from_critical);
    return;
end
if ismember('seconds_from_worst_epfd_slot', T.Properties.VariableNames) ...
        && any(isfinite(double(T.seconds_from_worst_epfd_slot)))
    tRel = double(T.seconds_from_worst_epfd_slot);
    return;
end
if ~ismember('gs_epfd_before_dB', T.Properties.VariableNames)
    error('Slot table needs gs_epfd_before_dB for worst-EPFD time offset.');
end
epfdCol = double(T.gs_epfd_before_dB);
times = string(T.time);
if ~all(isfinite(epfdCol))
    error('Cannot compute worst EPFD time offset from Slot_EPFD.');
end
[~, iWorst] = max(epfdCol);
t0 = datenum(char(times(iWorst)), 'dd mmm yyyy HH:MM:SS'); %#ok<DATNM>
tRel = nan(height(T), 1);
for k = 1:height(T)
    tk = datenum(char(times(k)), 'dd mmm yyyy HH:MM:SS'); %#ok<DATNM>
    tRel(k) = (tk - t0) * 86400;
end
end
