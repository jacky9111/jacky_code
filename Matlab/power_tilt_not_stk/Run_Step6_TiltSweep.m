% ============================================================
% Run Step 6: tilt sweep
% Assumes you already have: geom, out4a, ep, crit
% ============================================================

critIdx = crit.idx(1:2);           % 你的 worst-case pair
Ptx_used = 0;                      % 如果你已做 Step5B power control，用你實際的 power
                                  % 例如 cfgPC.Ptx_crit_dBW 或你 Step5B 的 per-sat power
tiltList = 0:1:30;                 % sweep 0~30 deg, 1 deg step

% (paper Fig.8 style threshold) - per MHz
EPFD_th_dBWm2_MHz = -173.4;
BW_MHz = 1;
EPFD_th_dBWm2 = EPFD_th_dBWm2_MHz + 10*log10(BW_MHz*1e6);

bestTilt = NaN;
bestEPFD = NaN;

EPFDtot = zeros(numel(tiltList),1);

for t = 1:numel(tiltList)
    tiltDeg = tiltList(t);

    geom2 = Step6A_Apply_Tilt_ToCritical(geom, critIdx, tiltDeg);

    cfg6B.Ptx_dBW = Ptx_used;
    cfg6B.do_plot = false;

    ep_tilt = Step6B_Compute_EPFD_WithTilt(geom2, out4a, cfg6B);

    EPFDtot(t) = ep_tilt.EPFD_total_dBWm2;

    if isnan(bestTilt) && EPFDtot(t) <= EPFD_th_dBWm2
        bestTilt = tiltDeg;
        bestEPFD = EPFDtot(t);
    end
end

figure;
plot(tiltList, EPFDtot, '-o');
hold on;
yline(EPFD_th_dBWm2, '--');
xlabel('Tilt (deg)'); ylabel('EPFD_{total} (dBW/m^2)');
title('Step 6: Tilt sweep (Power fixed)');
grid on;

fprintf("\n========== Step 6 Result ==========\n");
fprintf("Threshold (integrated) = %.2f dBW/m^2\n", EPFD_th_dBWm2);
if isnan(bestTilt)
    fprintf("No tilt in sweep achieved compliance.\n");
else
    fprintf("Min tilt achieving compliance: %.2f deg | EPFD_total=%.2f dBW/m^2\n", bestTilt, bestEPFD);
end
