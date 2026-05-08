%% =========================================================
%  Paper-style schematic:
%  16 beams, planar ground, GS hit by beam #6,
%  beam shut-off and beta_b annotation
%% =========================================================
clear; close all; clc;

%% ---------------- Basic parameters ----------------
Nbeam = 16;              % total number of beams
b_hit = 6;               % GS is located in beam #6

% Beam angular span (north -> south), for illustration only
beam_span = linspace(-28, 28, Nbeam);   % degrees

% Satellite position
sat = [0, 4];

% Ground plane (tangent plane)
y_ground = 1.99;

% Ground station position (fixed, from cursor)
GS = [-0.277077, 1.98071];

% Beam ON/OFF logic
active_idx = (b_hit+1):(Nbeam-b_hit);

% Parameters for beta_b (illustrative)
beta0 = 25;              % deg
beta_ellipse = 1.5;      % deg

%% ---------------- Figure setup ----------------
figure('Color','w');
hold on; axis equal; axis off;
xlim([-3.5 6.5]);
ylim([1.2 4.6]);

%% ---------------- Draw ground plane ----------------
plot([-4, 4], [y_ground y_ground], 'k', 'LineWidth',1.5);
text(4.05, y_ground, 'Ground plane', ...
    'FontSize',10, 'VerticalAlignment','middle');

%% ---------------- Draw GS ----------------
plot(GS(1), GS(2), 'ko', 'MarkerFaceColor','k', 'MarkerSize',6);
text(GS(1)-0.12, GS(2), 'GS', ...
    'FontSize',11, ...
    'HorizontalAlignment','right', ...
    'VerticalAlignment','middle');

%% ---------------- Draw satellite ----------------
plot(sat(1), sat(2), 'ko', 'MarkerFaceColor','k', 'MarkerSize',6);
text(sat(1)+0.15, sat(2), 'Satellite', 'FontSize',11);

%% ---------------- Draw beams ----------------
beam_end_x = zeros(1, Nbeam);

for i = 1:Nbeam
    ang = deg2rad(beam_span(i));

    % Ray-plane intersection
    t = (y_ground - sat(2)) / (-cos(ang));
    beam_end = sat + t*[sin(ang), -cos(ang)];

    beam_end_x(i) = beam_end(1);

    % Draw beam (ON / OFF)
    if ismember(i, active_idx)
        plot([sat(1), beam_end(1)], ...
             [sat(2), beam_end(2)], ...
             'k', 'LineWidth',1.6);
    else
        plot([sat(1), beam_end(1)], ...
             [sat(2), beam_end(2)], ...
             'k--', 'LineWidth',1.1);
    end

    % Beam index label
    mid = (sat + beam_end)/2;
    text(mid(1)+0.03, mid(2), num2str(i), 'FontSize',9);
end



%% ---------------- Annotate beta_b under each beam interval ----------------
y_text = y_ground - 0.22;

for b = 1:(Nbeam-1)
    beta_b = beta0 - (2*b-1)*beta_ellipse;

    % midpoint between beam b and b+1
    %% ---------------- Annotate b_0 ~ b_15 aligned with beams ----------------
    y_text = y_ground - 0.25;

    for i = 1:Nbeam
        text(beam_end_x(i), y_text, ...
            sprintf('$b_{%d}$', i-1), ...
            'Interpreter','latex', ...
            'FontSize',9, ...
            'HorizontalAlignment','center', ...
            'VerticalAlignment','top');
    end


    text(x_mid, y_text, ...
        sprintf('$\\beta_{%d}$', b), ...
        'Interpreter','latex', ...
        'FontSize',9, ...
        'HorizontalAlignment','center', ...
        'VerticalAlignment','top');
end

%% ---------------- Formula annotation ----------------
xT = 3.2;
text(xT, 3.1, ...
    '$\beta_b = \beta_0 - (2b-1)\beta_{\mathrm{ellipse}}$', ...
    'Interpreter','latex', 'FontSize',12);

text(xT, 2.5, ...
    '$b=6 \Rightarrow$ beams $1\!\sim\!6$ and $11\!\sim\!16$ OFF', ...
    'Interpreter','latex', 'FontSize',12);

text(xT, 2.1, ...
    'Active beams: $7\!\sim\!10$', ...
    'Interpreter','latex', 'FontSize',12);

%% ---------------- Export (vector, paper-ready) ----------------
exportgraphics(gcf, ...
    'beam16_planar_beta_b_schematic.pdf', ...
    'ContentType','vector');

disp('Done. Figure exported: beam16_planar_beta_b_schematic.pdf');
