function RelabelPcTiltSatisfactionFigsLocal()
% RelabelPcTiltSatisfactionFigsLocal
% Rebuild AvgUserSatisfaction 4-method figures with legend label "PC + Tilt"
% (drop "Ren et al.") from existing plot tables, then copy PNGs into thesis figures.

thisDir = fileparts(mfilename('fullpath'));
addpath(thisDir);

dataDir = fullfile(thisDir, '..', '..', 'Matlab_data');
thesisFigDir = fullfile(thisDir, '..', '..', '論文', 'figures');
userLoads = [30, 50, 70];

methodOrder = ["Beam shutdown only", "PC + Tilt", "Only HBR", "EABR"];
oldLabel = "PC + Tilt (Ren et al.)";
newLabel = "PC + Tilt";
colors = [0 0 0; 0 0.45 0.74; 0.85 0.33 0.10; 0.47 0.67 0.19];
lineStyle = linePlotStylePresetLocal(4, colors);

for iu = 1:numel(userLoads)
    U = userLoads(iu);
    base = sprintf('FullPower_BeamShutdownSweep_GS01_U%d_P03S49_AvgUserSatisfaction_4MethodCompare', U);
    xlsxPath = fullfile(dataDir, [base '.xlsx']);
    pngPath = fullfile(dataDir, [base '.png']);
    thesisPng = fullfile(thesisFigDir, sprintf('ch5_U%d_AvgUserSatisfaction_4MethodCompare.png', U));

    if ~isfile(xlsxPath)
        warning('Missing %s', xlsxPath);
        continue;
    end

    T = readtable(xlsxPath, 'TextType', 'string');
    if ~ismember('method', T.Properties.VariableNames)
        error('Sheet missing method column: %s', xlsxPath);
    end
    T.method = replace(string(T.method), oldLabel, newLabel);
    writetable(T, xlsxPath, 'Sheet', 'AvgUserSatisfaction');

    fig = figure('Color', 'w', 'Visible', 'off');
    ax = axes('Parent', fig);
    hold(ax, 'on');
    for m = 1:numel(methodOrder)
        mask = T.method == methodOrder(m);
        if ~any(mask)
            warning('No rows for method "%s" in U%d', methodOrder(m), U);
            continue;
        end
        tPlot = T.time_offset_from_worst_epfd_slot_s(mask);
        yPlot = T.avg_user_satisfaction_percent(mask);
        [tPlot, ord] = sort(tPlot, 'ascend');
        yPlot = yPlot(ord);
        plotStyledLineLocal(ax, tPlot, yPlot, m, lineStyle, 1.8, methodOrder(m));
    end
    grid(ax, 'on');
    xlabel(ax, 'Time Offset from Worst EPFD Slot (s)');
    ylabel(ax, 'Average user satisfaction (%)');
    xlim(ax, [-60, 60]);
    ylim(ax, [0, 100]);
    lg = legend(ax, 'Location', 'southeast');
    lg.FontSize = 8;
    lg.ItemTokenSize = [14, 6];
    lg.Box = 'on';
    hold(ax, 'off');

    exportgraphics(fig, pngPath, 'Resolution', 200);
    copyfile(pngPath, thesisPng);
    close(fig);
    fprintf('Updated U%d -> %s\n', U, thesisPng);
end
end
