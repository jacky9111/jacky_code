%% PlotCriticalHelpersGS - chapter3 network scenario schematic
%  Three along-track LEO satellites (critical + north/south helpers)
%  and protected GSO ground station g directly below critical sat (nadir).
clear; close all; clc;

%% Output
exportPdf = true;
outName = 'ch3_critical_helpers_gs_schematic.pdf';
outDir = fullfile(fileparts(mfilename('fullpath')), '..', char([35542, 25991]));

%% Schematic geometry (not to scale; geometry only)
R = 4.2;
h = 0.95;
dTheta = 0.11;

C = [0, -R];
theta_c = pi/2;
theta_N = theta_c - dTheta;
theta_S = theta_c + dTheta;

r_orb = R + h;
posN = C + r_orb * [cos(theta_N), sin(theta_N)];
posC = C + r_orb * [cos(theta_c), sin(theta_c)];
posS = C + r_orb * [cos(theta_S), sin(theta_S)];
posG = C + R * [cos(theta_c), sin(theta_c)];

th_arc = linspace(theta_S - 0.10, theta_N + 0.10, 240);
orb_xy = C + r_orb * [cos(th_arc)', sin(th_arc)'];

th_surf = linspace(theta_S - 0.30, theta_N + 0.30, 320);
surf_xy = C + R * [cos(th_surf)', sin(th_surf)'];

%% Figure
fig = figure('Color', 'w', 'Position', [120 120 760 540]);
ax = axes('Parent', fig);
hold(ax, 'on');
axis(ax, 'equal');
axis(ax, 'off');

fill(ax, [surf_xy(:,1); C(1)], [surf_xy(:,2); C(2)], ...
    [0.93 0.95 0.98], 'EdgeColor', 'none');
plot(ax, surf_xy(:,1), surf_xy(:,2), 'k', 'LineWidth', 1.6);

plot(ax, orb_xy(:,1), orb_xy(:,2), '--', ...
    'Color', [0.38 0.38 0.38], 'LineWidth', 1.5);
text(ax, orb_xy(1,1) - 0.55, orb_xy(1,2) + 0.12, 'LEO orbit', ...
    'FontSize', 10, 'Color', [0.35 0.35 0.35], 'HorizontalAlignment', 'left');

plot(ax, [posC(1), posG(1)], [posC(2), posG(2)], ':', ...
    'Color', [0.50 0.50 0.50], 'LineWidth', 1.3);

ms = 9;
plot(ax, posN(1), posN(2), 'o', 'MarkerSize', ms, ...
    'MarkerFaceColor', [0.22 0.48 0.78], 'MarkerEdgeColor', 'k', 'LineWidth', 0.9);
plot(ax, posC(1), posC(2), 's', 'MarkerSize', ms + 2, ...
    'MarkerFaceColor', [0.88 0.28 0.18], 'MarkerEdgeColor', 'k', 'LineWidth', 1.0);
plot(ax, posS(1), posS(2), 'o', 'MarkerSize', ms, ...
    'MarkerFaceColor', [0.22 0.48 0.78], 'MarkerEdgeColor', 'k', 'LineWidth', 0.9);
plot(ax, posG(1), posG(2), '^', 'MarkerSize', 11, ...
    'MarkerFaceColor', [0.12 0.12 0.12], 'MarkerEdgeColor', 'k', 'LineWidth', 0.9);

lbl = @(p, s, dy, va) text(ax, p(1), p(2) + dy, s, ...
    'Interpreter', 'latex', 'FontSize', 11, ...
    'HorizontalAlignment', 'center', 'VerticalAlignment', va);
lbl(posN, '$s^{\mathrm{N}}(t)$', 0.24, 'bottom');
lbl(posC, '$s^{\mathrm{c}}(t)$', 0.26, 'bottom');
lbl(posS, '$s^{\mathrm{S}}(t)$', -0.30, 'top');
text(ax, posG(1), posG(2) - 0.38, 'Protected GS $g$', ...
    'Interpreter', 'latex', 'FontSize', 11, ...
    'HorizontalAlignment', 'center', 'VerticalAlignment', 'top');

arrY = posC(2) + 0.62;
arrX0 = posS(1) + 0.20;
arrX1 = posN(1) - 0.20;
quiver(ax, arrX0, arrY, arrX1 - arrX0, 0, 0, ...
    'Color', 'k', 'LineWidth', 1.2, 'MaxHeadSize', 0.75, 'AutoScale', 'off');
text(ax, 0.5 * (arrX0 + arrX1), arrY + 0.20, 'Along-track', ...
    'FontSize', 10, 'HorizontalAlignment', 'center');
text(ax, arrX1 + 0.12, arrY, 'North', ...
    'FontSize', 10, 'HorizontalAlignment', 'left', 'VerticalAlignment', 'middle');

text(ax, posC(1) - 2.35, posC(2) + 0.15, ...
    {'Critical satellite', 'North / South helpers'}, ...
    'FontSize', 9.5, 'Color', [0.25 0.25 0.25]);

xlim(ax, [-3.2, 3.2]);
ylim(ax, [-0.35, 6.35]);

if exportPdf
    if ~exist(outDir, 'dir')
        mkdir(outDir);
    end
    outPath = fullfile(outDir, outName);
    exportgraphics(fig, outPath, 'ContentType', 'vector');
    fprintf('Exported: %s\n', outPath);
end
