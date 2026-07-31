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
%
% 【中文說明】把逐 slot 累加的計數器換算成論文 Table 的四個欄位。
% 每個比值都先檢查分母是否為 0：分母為 0 時回傳 0 並在 flags 標記，
% 而不是丟出 NaN 或除零錯誤（這樣表格才不會出現無法解釋的空值）。
%
% 四個指標與論文欄位的對應：
%   m1 → Avg. critical satellites per critical slot
%   m2 → Avg. helper candidates per critical satellite
%   m3 → Critical-satellite helper availability (%)
%   m4 → Closed-beam helper-overlap availability (%)

flags = struct('noCriticalSlot', false, 'noCriticalInstance', false, ...
    'noClosedBeamInstance', false);

% m1：只在「至少有一顆 critical 衛星」的 slot 上取平均（分母不含沒有 critical 的 slot）
if acc.criticalSlotsCount > 0
    m1 = acc.sumCriticalSatsCriticalSlot / acc.criticalSlotsCount;
else
    m1 = 0; flags.noCriticalSlot = true;
end

if acc.totalCriticalInstances > 0
    % m2：以「(衛星, 時刻) 為一個 instance」計算平均 helper 候選數
    m2 = acc.sumHelpersOverInstances / acc.totalCriticalInstances;
    % Helper-availability ratio: fraction of critical instances that have at
    % least one recovery-capable helper (higher is better).
    % m3：至少有 1 顆 helper 的 critical instance 佔比（越高越好，論文三種密度都是 100%）
    m3 = 100 * (acc.totalCriticalInstances - acc.zeroHelperInstances) / acc.totalCriticalInstances;
else
    m2 = 0; m3 = 0; flags.noCriticalInstance = true;
end

% m4：關閉束中「有 helper recovery beam 重疊覆蓋」的比例
%     論文低密度情境掉到 69.19%，就是這個指標 —— 有 helper 不等於覆蓋得到所有關閉束
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
