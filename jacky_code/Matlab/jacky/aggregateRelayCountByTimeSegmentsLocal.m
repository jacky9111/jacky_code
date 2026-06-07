function segOut = aggregateRelayCountByTimeSegmentsLocal(slotTable, tRelByTime, win, segmentSpec, aggregateMode)
% aggregateRelayCountByTimeSegmentsLocal
% Bin slot relay counts into time segments on relative-time axis.
% segmentSpec: scalar nSegments (equal-width bins) OR vector timeSegmentEdges
%   (same as fig.2: bars at -60,-40,...,60 using midpoint windows).

if nargin < 5 || strlength(string(aggregateMode)) == 0
    aggregateMode = "mean";
end
aggregateMode = lower(string(aggregateMode));
win = double(win(:)).';

times = string(slotTable.time);
counts = double(slotTable.relay_user_count);
tRel = nan(numel(times), 1);
for k = 1:numel(times)
    tk = times(k);
    if isKey(tRelByTime, tk)
        tRel(k) = tRelByTime(tk);
    else
        tRel(k) = alignOneTimeOffsetLocal(tk, tRelByTime);
    end
end

useEdges = isnumeric(segmentSpec) && ~isscalar(segmentSpec) && numel(segmentSpec) >= 2;
if ~useEdges
    nSegments = max(1, round(double(segmentSpec)));
    edges = linspace(win(1), win(2), nSegments + 1);
    nBar = nSegments;
    xBar = 0.5 * (edges(1:end - 1) + edges(2:end));
    segLabels = strings(nBar, 1);
    for s = 1:nBar
        segLabels(s) = sprintf('%.0f~%.0f', edges(s), edges(s + 1));
    end
    segMean = nan(nBar, 1);
    segSum = nan(nBar, 1);
    segSlotCount = zeros(nBar, 1);
    for s = 1:nBar
        lo = edges(s);
        hi = edges(s + 1);
        if s < nBar
            mask = tRel >= lo - 1e-9 & tRel < hi - 1e-9;
        else
            mask = tRel >= lo - 1e-9 & tRel <= hi + 1e-9;
        end
        vals = counts(mask);
        segSlotCount(s) = numel(vals);
        if isempty(vals)
            segMean(s) = 0;
            segSum(s) = 0;
        else
            segMean(s) = mean(vals, 'omitnan');
            segSum(s) = sum(vals, 'omitnan');
        end
    end
else
    edges = double(segmentSpec(:)).';
    nBar = numel(edges);
    xBar = edges;
    segLabels = strings(nBar, 1);
    segMean = nan(nBar, 1);
    segSum = nan(nBar, 1);
    segSlotCount = zeros(nBar, 1);
    for k = 1:nBar
        segLabels(k) = sprintf('%.0f', edges(k));
        if k == 1
            lo = edges(1);
            hi = 0.5 * (edges(1) + edges(2));
            mask = tRel >= lo - 1e-9 & tRel < hi - 1e-9;
        elseif k == nBar
            lo = 0.5 * (edges(end - 1) + edges(end));
            hi = edges(end);
            mask = tRel >= lo - 1e-9 & tRel <= hi + 1e-9;
        else
            lo = 0.5 * (edges(k - 1) + edges(k));
            hi = 0.5 * (edges(k) + edges(k + 1));
            mask = tRel >= lo - 1e-9 & tRel < hi - 1e-9;
        end
        vals = counts(mask);
        segSlotCount(k) = numel(vals);
        if isempty(vals)
            segMean(k) = 0;
            segSum(k) = 0;
        else
            segMean(k) = mean(vals, 'omitnan');
            segSum(k) = sum(vals, 'omitnan');
        end
    end
end

segOut = struct();
segOut.edges = edges;
segOut.xBar = xBar;
segOut.labels = segLabels;
segOut.center = xBar;
segOut.meanPerSlot = segMean;
segOut.sumInSegment = segSum;
segOut.slotCount = segSlotCount;
if aggregateMode == "sum"
    segOut.plotValue = segSum;
else
    segOut.plotValue = segMean;
end
end

function tRel = alignOneTimeOffsetLocal(timeStr, tRelByTime)
tRel = NaN;
refTimes = keys(tRelByTime);
if isempty(refTimes)
    return;
end
t0 = datenum(char(refTimes(1)), 'dd mmm yyyy HH:MM:SS'); %#ok<DATNM>
tk = datenum(char(timeStr), 'dd mmm yyyy HH:MM:SS'); %#ok<DATNM>
tRel = (tk - t0) * 86400;
end
