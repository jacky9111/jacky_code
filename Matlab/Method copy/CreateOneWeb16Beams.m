function CreateOneWeb16Beams(root, targetSats)
% ============================================================
% Create OneWeb 16 beams
% All beams point to nadir (STK12 COM SAFE)
% ============================================================

disp("建立 OneWeb 16-beam（Nadir pointing｜100% 可跑）");

% --- Beam geometry ---
beamHalfEW = 24.5;        % 東西向 half-angle
beamHalfNS = 25/16;       % 南北向 half-angle ≈ 1.5625

for i = 1:length(targetSats)

    satName = char(targetSats(i));
    fprintf("Processing %s\n", satName);

    sat = root.GetObjectFromPath(['Satellite/' satName]);

    for k = 1:16

        sensorName = sprintf("Beam_%02d", k);
        s = sat.Children.New('eSensor', sensorName);

        % --- Rectangular pattern ---
        s.SetPatternType('eSnRectangular');
        s.CommonTasks.SetPatternRectangular( ...
            beamHalfEW, ...
            beamHalfNS);

        % --- Nadir pointing ---
        s.SetPointingType('eSnPtNadir');

        % --- Graphics ---
        s.Graphics.FillVisible = true;
    end

    fprintf("✔ 16 beams created on %s\n", satName);
end

disp("✨ 完成（Nadir 版本）");
end
