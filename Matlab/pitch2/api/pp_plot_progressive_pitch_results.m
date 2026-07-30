function pp_plot_progressive_pitch_results(P, best)
%PP_PLOT_PROGRESSIVE_PITCH_RESULTS Plot key curves similar to paper Figure 4/5/6.

lat = best.S.lat_asc;
chi = best.S.chi_asc;
K = best.S.K_asc;
R = best.R;

% Figure: convergence
figure('Name','GA Convergence');
plot(best.history.best_fit, 'LineWidth', 1.5);
grid on;
xlabel('Generation');
ylabel('Best fitness');
title('GA convergence (best fitness)');

% Figure 5a: pitch vs latitude (northern hemisphere)
figure('Name','Progressive pitch schedule');
subplot(2,1,1);
plot(lat, chi, 'LineWidth', 1.8);
grid on;
xlabel('Latitude (deg)');
ylabel('\chi (deg)');
title('Pitch angle vs latitude');

% Figure 5b: off beams vs latitude
subplot(2,1,2);
stairs(lat, K, 'LineWidth', 1.8);
grid on;
xlabel('Latitude (deg)');
ylabel('K (closed beams)');
title('Number of closed beams vs latitude');

% Figure 6a/b/c: capacity, min off-axis, overlap
figure('Name','Key metrics vs latitude');
subplot(3,1,1);
plot(lat, R.cap_vs_lat, 'LineWidth', 1.6);
grid on;
xlabel('Latitude (deg)');
ylabel('Total capacity (arb.)');
title('Total capacity vs latitude');

subplot(3,1,2);
plot(lat, R.minmu_vs_lat, 'LineWidth', 1.6);
hold on;
yline(best.mu_th_deg, '--', sprintf('\\mu_{th}=%.2f^\\circ', best.mu_th_deg));
grid on;
xlabel('Latitude (deg)');
ylabel('Min off-axis \mu (deg)');
title('Minimum off-axis angle in minor axis');
hold off;

subplot(3,1,3);
plot(lat, R.overlap_vs_lat, 'LineWidth', 1.6);
hold on;
yline(P.overlap_e_deg, '--', sprintf('e=%.2f^\\circ', P.overlap_e_deg));
grid on;
xlabel('Latitude (deg)');
ylabel('Overlap (deg)');
title('Coverage overlap with adjacent satellite');
hold off;
end

