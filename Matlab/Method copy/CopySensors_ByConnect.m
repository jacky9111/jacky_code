function CopySensors_ByConnect(root, srcSat, dstSats)
% ============================================================
% 用 STK Connect 指令 (CopyObj / Paste)
% 等價 GUI Copy / Paste
% STK12 COM SAFE
% ============================================================

srcSat = char(srcSat);

% 取得 source 衛星
src = root.GetObjectFromPath(['Satellite/' srcSat]);
sensors = src.Children.GetElements('eSensor');

fprintf("Source satellite: %s\n", srcSat);
fprintf("Number of sensors: %d\n", sensors.Count);

for i = 1:length(dstSats)

    dstSat = char(dstSats(i));
    fprintf("\nProcessing target satellite: %s\n", dstSat);

    for s = 0:sensors.Count-1

        sensorObj  = sensors.Item(int32(s));
        sensorName = sensorObj.InstanceName;

        % ---- Copy (正確指令) ----
        copyCmd = sprintf( ...
            'CopyObj */Satellite/%s/Sensor/%s', ...
            srcSat, sensorName);
        root.ExecuteCommand(copyCmd);

        % ---- Paste ----
        pasteCmd = sprintf( ...
            'Paste */Satellite/%s', ...
            dstSat);
        root.ExecuteCommand(pasteCmd);

        fprintf("  Copied %s\n", sensorName);
    end
end

disp("✨ All sensors copied by Connect (CopyObj)");
end
