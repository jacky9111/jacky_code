function metrics = compute_helper_availability_metrics(acc)
% compute_helper_availability_metrics
% Compute the four summary metrics for one constellation geometry from the
% accumulated per-slot / per-instance counters. Every ratio is guarded
% against a zero denominator (returns 0 and records the empty condition
% instead of producing an unexplained NaN or division-by-zero error).
%
% Input acc (accumulated over all time slots):
%   .criticalSlotsCount          : # slots with >= 1 critical satellite
%   .sumCriticalSatsCriticalSlot : sum_t |S_C(t)| over critical slots only
%   .totalCriticalInstances      : # (satellite,time) critical instances
%   .sumHelpersOverInstances     : sum of recovery-capable helpers over instances
%   .zeroHelperInstances         : # critical instances with 0 helpers
%   .totalClosedBeamInstances    : # closed-beam (beam,time) instances
%   .closedBeamWithHelper        : # closed-beam instances with helper coverage
%
% Output metrics:
%   .AvgCriticalSatellitesPerCriticalSlot
%   .AvgRecoveryCapableHelpersPerCriticalSatellite
%   .HelperAvailabilityRatioPercent  (% of critical instances with >=1 helper)
%   .ClosedBeamHelperCoverageRatioPercent
%   .flags : struct of booleans marking which denominators were empty

flags = struct('noCriticalSlot', false, 'noCriticalInstance', false, ...
    'noClosedBeamInstance', false);

if acc.criticalSlotsCount > 0
    m1 = acc.sumCriticalSatsCriticalSlot / acc.criticalSlotsCount;
else
    m1 = 0; flags.noCriticalSlot = true;
end

if acc.totalCriticalInstances > 0
    m2 = acc.sumHelpersOverInstances / acc.totalCriticalInstances;
    % Helper-availability ratio: fraction of critical instances that have at
    % least one recovery-capable helper (higher is better).
    m3 = 100 * (acc.totalCriticalInstances - acc.zeroHelperInstances) / acc.totalCriticalInstances;
else
    m2 = 0; m3 = 0; flags.noCriticalInstance = true;
end

if acc.totalClosedBeamInstances > 0
    m4 = 100 * acc.closedBeamWithHelper / acc.totalClosedBeamInstances;
else
    m4 = 0; flags.noClosedBeamInstance = true;
end

metrics = struct();
metrics.AvgCriticalSatellitesPerCriticalSlot          = m1;
metrics.AvgRecoveryCapableHelpersPerCriticalSatellite = m2;
metrics.HelperAvailabilityRatioPercent                = m3;
metrics.ClosedBeamHelperCoverageRatioPercent          = m4;
metrics.flags = flags;
end
