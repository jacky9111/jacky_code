function slot = identify_critical_satellites(visIdx, pos_vis_km, boresights_vis, ...
    P_gs_km, P_geo_km, P, beam, epfdThr_dB)
% identify_critical_satellites
% For ONE time slot: compute the aggregate EPFD from all visible satellites'
% beams to the GS and, if the EPFD limit is exceeded, greedily shut down the
% highest-contributing beams (recomputing the aggregate after each shutdown)
% until the aggregate EPFD is back within the limit.
%
% A satellite with at least one shut-down beam is a critical satellite; the
% shut beams are closed beams, the remaining beams are active/safe beams.
%
% Inputs:
%   visIdx         : 1 x nVis global indices of visible satellites
%   pos_vis_km     : 3 x nVis ECEF positions of visible satellites [km]
%   boresights_vis : 1 x nVis cell, each 3 x Nbeam beam boresights
%   P_gs_km        : 3x1 ECEF GS position [km]
%   P_geo_km       : 3x1 ECEF reference GSO position [km]
%   P              : ku_epfd_params struct
%   beam           : cfg.common.beam (Nbeam, fullBeamPower_W)
%   epfdThr_dB     : aggregate EPFD limit [dB]
%
% Output slot:
%   slot.visIdx       : 1 x nVis global indices
%   slot.beamEpfdLin  : nVis x Nbeam per-beam EPFD contribution [linear]
%   slot.closedMask   : nVis x Nbeam logical (shut beams)
%   slot.activeMask   : nVis x Nbeam logical (active/safe beams)
%   slot.isCritical   : nVis x 1 logical
%   slot.aggBefore_lin/aggAfter_lin : aggregate EPFD before/after [linear]
%   slot.nShut        : total number of shut-down beams
%
% All aggregation is done in the linear domain; dB only for reporting.
%
% 【中文說明】單一 time slot 的 critical 衛星辨識。
% 邏輯與主模擬 RunFullPowerAggregateShutdownSweepExcel 的關束步驟一致：
% 先算所有可見衛星的每條 beam 對 GS 的 EPFD 貢獻，若總和超標，
% 就依貢獻由大到小貪婪關束，直到 aggregate EPFD 回到門檻以下。
%
% 名詞對應論文：
%   critical satellite  至少有一條 beam 被關掉的衛星
%   closed beam         被關掉的那些 beam
%   active / safe beam  仍然開著的 beam（可作為 helper recovery beam 的來源）
%
% 所有累加都在線性域進行，只有輸出報表時才轉 dB（避免 dB 相加的錯誤）。

Nbeam = beam.Nbeam;
nVis = numel(visIdx);
fullPower_W = beam.fullBeamPower_W;
threshold_lin = 10^(double(epfdThr_dB) / 10);   % 門檻由 dB 轉線性
linTol = threshold_lin * 1e-12;                 % 浮點比較容差

% ---- 步驟 1：算出每顆可見衛星、每條 beam 對 GS 的 EPFD 貢獻 ----
beamEpfdLin = zeros(nVis, Nbeam);
for i = 1:nVis
    e = compute_beam_epfd(pos_vis_km(:, i), boresights_vis{i}, ...
        repmat(fullPower_W, Nbeam, 1), P_gs_km, P_geo_km, P);
    beamEpfdLin(i, :) = e.beam_lin(:).';
end

% ---- 步驟 2：若 aggregate EPFD 超標，貪婪關束直到合法 ----
closedMask = false(nVis, Nbeam);
aggBefore_lin = sum(beamEpfdLin(:));
aggAfter_lin = aggBefore_lin;
nShut = 0;

if aggAfter_lin > threshold_lin + linTol
    % Sort all beams by descending EPFD contribution, then shut greedily.
    % 把「所有衛星的所有 beam」一起排序，干擾貢獻最大的先關
    [vals, order] = sort(beamEpfdLin(:), 'descend');
    for r = 1:numel(order)
        if aggAfter_lin <= threshold_lin + linTol
            break;   % 已經合法，不再關束
        end
        if vals(r) <= 0
            break;   % remaining beams contribute nothing
                     % 剩下的 beam 貢獻為 0，再關也沒用
        end
        aggAfter_lin = aggAfter_lin - vals(r);
        closedMask(order(r)) = true;
        nShut = nShut + 1;
    end
end

% ---- 步驟 3：標記 critical 衛星（只要有任一條 beam 被關就算）----
activeMask = ~closedMask;
isCritical = any(closedMask, 2);

slot = struct();
slot.visIdx       = visIdx(:).';
slot.beamEpfdLin  = beamEpfdLin;
slot.closedMask   = closedMask;
slot.activeMask   = activeMask;
slot.isCritical   = isCritical;
slot.aggBefore_lin = aggBefore_lin;
slot.aggAfter_lin  = aggAfter_lin;
slot.nShut         = nShut;
end
