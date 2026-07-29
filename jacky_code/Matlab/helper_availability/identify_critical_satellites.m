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

Nbeam = beam.Nbeam;
nVis = numel(visIdx);
fullPower_W = beam.fullBeamPower_W;
threshold_lin = 10^(double(epfdThr_dB) / 10);
linTol = threshold_lin * 1e-12;

beamEpfdLin = zeros(nVis, Nbeam);
for i = 1:nVis
    e = compute_beam_epfd(pos_vis_km(:, i), boresights_vis{i}, ...
        repmat(fullPower_W, Nbeam, 1), P_gs_km, P_geo_km, P);
    beamEpfdLin(i, :) = e.beam_lin(:).';
end

closedMask = false(nVis, Nbeam);
aggBefore_lin = sum(beamEpfdLin(:));
aggAfter_lin = aggBefore_lin;
nShut = 0;

if aggAfter_lin > threshold_lin + linTol
    % Sort all beams by descending EPFD contribution, then shut greedily.
    [vals, order] = sort(beamEpfdLin(:), 'descend');
    for r = 1:numel(order)
        if aggAfter_lin <= threshold_lin + linTol
            break;
        end
        if vals(r) <= 0
            break;   % remaining beams contribute nothing
        end
        aggAfter_lin = aggAfter_lin - vals(r);
        closedMask(order(r)) = true;
        nShut = nShut + 1;
    end
end

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
