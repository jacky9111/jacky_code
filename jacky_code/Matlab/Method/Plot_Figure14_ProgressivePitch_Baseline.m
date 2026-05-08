function Plot_Figure14_ProgressivePitch_Baseline(T_user, titleStr)
% Plot_Figure14_ProgressivePitch_Baseline
% A Figure-14-like plot for the progressive pitch baseline:
% - x-axis: target satellite latitude (deg)
% - y-axis: user satisfaction (%) and EPFD violation indicator
%
% Inputs
% - T_user: output table of ComputeUserSatisfaction_ProgressivePitch
% - titleStr: optional title string

if nargin < 2 || strlength(string(titleStr)) == 0
    titleStr = "Progressive pitch baseline";
end

lat = T_user.phiS_deg;
sat = T_user.user_satisfaction_pct;
viol = T_user.epfd_violation_on;

valid = isfinite(lat) & isfinite(sat);
lat = lat(valid);
sat = sat(valid);
viol = viol(valid);

% Keep range comparable to common passing-over-GS plots
inRange = lat >= -1.5 & lat <= 1.5;
lat = lat(inRange);
sat = sat(inRange);
viol = viol(inRange);

[lat_s, idx] = sort(lat);
sat_s = sat(idx);
viol_s = viol(idx);

figure('Name', 'Figure14-like: Progressive pitch baseline');
tiledlayout(2,1,'TileSpacing','compact','Padding','compact');

nexttile;
plot(lat_s, sat_s, 'b-', 'LineWidth', 1.6);
grid on;
xlabel('Target LEO latitude \phi_S (deg)');
ylabel('User satisfaction (%)');
ylim([0 105]);
title(string(titleStr) + " - satisfaction");

nexttile;
stairs(lat_s, viol_s, 'r-', 'LineWidth', 1.6);
grid on;
xlabel('Target LEO latitude \phi_S (deg)');
ylabel('EPFD violation (ON beams)');
ylim([-0.1 1.1]);
title(string(titleStr) + " - EPFD violation");
end

