function [summaryTable, caseResults] = main_helper_availability(cfg)
% main_helper_availability
% Compare recovery-capable helper availability under several constellation-like
% orbital geometries under an IDENTICAL 16-beam model, beam power, antenna
% pattern, EPFD model and helper-identification criteria. Only the orbital
% geometry changes. The default configuration compares three OneWeb-like polar
% density variants (same 1200 km / 87.9 deg shell; only P and S change):
%   OneWeb-like reference (12x49), High-density (36x74), Low-density (8x36).
%
% This is an independent, pure-MATLAB simulation module. It does not use STK
% and does not modify any existing main-simulation result.
%
% Usage:
%   [summaryTable, caseResults] = main_helper_availability();      % default config
%   [summaryTable, caseResults] = main_helper_availability(cfg);   % custom config
% Subset rows with select_helper_constellations(cfg, "Low-density") before calling.
%
% Outputs:
%   summaryTable : final summary table (one row per geometry; written to results/)
%   caseResults  : 1 x N cell of per-constellation raw results
%
% IMPORTANT: High-/Low-density rows are illustrative OneWeb polar variants
% (Starlink-/Lightspeed-scale totals); they do not reproduce commercial
% constellation helper counts.
%
% =====================================================================
% 【中文說明】論文 Evaluation 第二項：
%   「Helper Satellite Availability under Different Constellation Densities」
%   → 產生論文的 Table「Helper Availability under Different Constellation Densities」
%     （OneWeb-like reference / High-density / Low-density 三列）
%
% 這是一個獨立模組，純 MATLAB、不需要 STK，也不會動到主模擬的任何結果。
%
% 實驗設計：三種密度共用同一個 OneWeb 極軌殼層（1200 km / 87.9 deg / Walker star），
% 16-beam 佈局、beam 功率、天線場型、EPFD 模型、helper 判定準則全部固定，
% 只改「軌道面數 P」與「每面衛星數 S」，藉此把「密度」這個變因單獨隔離出來：
%   OneWeb-like reference  12 x 49 = 588   （論文主模擬）
%   Medium-density         24 x 50 = 1200  （介於 reference 與 high）
%   High-density           36 x 74 = 2664  （總規模參考 Starlink）
%   Low-density             8 x 36 = 288   （總規模參考 Lightspeed）
%
% 輸出的四個指標（對應論文 Table 的四個欄位）：
%   1. 每個 critical slot 的平均 critical 衛星數
%   2. 每顆 critical 衛星平均有幾顆 helper 候選
%   3. Critical-satellite helper availability（%）：至少有 1 顆 helper 的比例
%   4. Closed-beam helper-overlap availability（%）：關閉束有 helper 覆蓋的比例
%
% 執行方式：
%   [summaryTable, caseResults] = main_helper_availability();      % 用預設 config
%   [summaryTable, caseResults] = main_helper_availability(cfg);   % 自訂 config
% 只想跑其中一種密度，先用 select_helper_constellations(cfg, "Low-density") 篩選。
% 所有可調參數都集中在 config_helper_availability.m。
% =====================================================================

if nargin < 1 || isempty(cfg)
    moduleDir = fileparts(mfilename('fullpath'));
    addpath(moduleDir);
    addpath(fullfile(moduleDir, '..', 'jacky'));       % ku_epfd_params
    addpath(fullfile(moduleDir, '..', 'powertilt'));   % gso_rx_gain_itu1428
    cfg = config_helper_availability();
end

fprintf('\n==================================================================\n');
fprintf('Helper availability under different constellation-like geometries\n');
fprintf('==================================================================\n');
fprintf('WARNING: %s\n', cfg.disclaimer);
fprintf('Common: GS=(%.1f, %.1f) deg, GSO lon=%.1f deg, t=%d..%d s @ %d s, EPFD limit=%.1f dB\n', ...
    cfg.common.gsLat_deg, cfg.common.gsLon_deg, cfg.common.gsoLon_deg, ...
    cfg.common.tStart_s, cfg.common.tEnd_s, cfg.common.tStep_s, cfg.common.epfdThr_dB);

% 逐一跑每一種密度設定（每一種對應論文 Table 的一列）
N = numel(cfg.constellations);
caseResults = cell(1, N);
for i = 1:N
    c = cfg.constellations{i};
    fprintf('\n----- [%d/%d] %s -----\n', i, N, c.name);
    if c.isExampleGeometry
        fprintf('NOTE: "%s" uses an EXAMPLE geometry (partial/illustrative). %s\n', ...
            c.name, cfg.disclaimer);
    end
    shells = c.shells;
    if ~iscell(shells); shells = {shells}; end
    for sh = 1:numel(shells)
        s = shells{sh};
        fprintf('Geometry shell %d/%d: alt=%.0f km, inc=%.2f deg, planes=%d, sats/plane=%d, T=%d, Walker %s F=%d\n', ...
            sh, numel(shells), s.altitude_km, s.inclination_deg, ...
            s.number_of_planes, s.satellites_per_plane, ...
            s.number_of_planes * s.satellites_per_plane, s.walker_type, s.walker_phasing_F);
    end

    % 跑完整流程：建幾何 → 對齊 → 傳播 → 找 critical → 找 helper → 統計
    caseResults{i} = run_constellation_case(c, cfg.common);

    m = caseResults{i}.metrics;
    fprintf(['Result: avgCritSats/critSlot=%.2f, avgHelpers/critSat=%.2f, ', ...
        'helperAvailability=%.2f%%, closedBeamCoverage=%.2f%%\n'], ...
        m.AvgCriticalSatellitesPerCriticalSlot, ...
        m.AvgRecoveryCapableHelpersPerCriticalSatellite, ...
        m.HelperAvailabilityRatioPercent, m.ClosedBeamHelperCoverageRatioPercent);
    report_empty_denominators(caseResults{i});
end

summaryTable = export_helper_availability_results(caseResults, cfg);

fprintf('\n===== Helper availability summary =====\n');
disp(summaryTable);
fprintf('Reminder: %s\n', cfg.disclaimer);
end

function report_empty_denominators(caseResult)
f = caseResult.metrics.flags;
if f.noCriticalSlot
    fprintf('  (No critical slot occurred; metric 1 reported as 0.)\n');
end
if f.noCriticalInstance
    fprintf('  (No critical satellite instance; metrics 2-3 reported as 0.)\n');
end
if f.noClosedBeamInstance
    fprintf('  (No closed-beam instance; metric 4 reported as 0.)\n');
end
end
