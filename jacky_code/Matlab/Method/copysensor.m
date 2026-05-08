function copysensor( ...
    root, sourceSatName, targetSatNames, sensorNames)

% 確保 cell array
if isstring(targetSatNames)
    targetSatNames = cellstr(targetSatNames);
end
if isstring(sensorNames)
    sensorNames = cellstr(sensorNames);
end

for iSat = 1:length(targetSatNames)

    tgtSat = targetSatNames{iSat};

    for iSen = 1:length(sensorNames)

        senName = sensorNames{iSen};

        try
            %% 1️⃣ 先刪掉目標衛星的同名 Sensor（若存在）
            delCmd = sprintf( ...
                'Unload /Satellite/%s/Sensor/%s', ...
                tgtSat, senName);
            root.ExecuteCommand(delCmd);
        catch
            % 不存在就算了，正常
        end

        try
            %% 2️⃣ Copy 來源 Sensor
            copyCmd = sprintf( ...
                'Copy /Satellite/%s/Sensor/%s', ...
                sourceSatName, senName);

            %% 3️⃣ Paste 到目標「Sensor 容器」（重點）
            pasteCmd = sprintf( ...
                'Paste /Satellite/%s/Sensor', ...
                tgtSat);

            root.ExecuteCommand(copyCmd);
            root.ExecuteCommand(pasteCmd);

            fprintf('✔ 覆蓋成功：%s → %s | %s\n', ...
                sourceSatName, tgtSat, senName);

        catch ME
            warning('❌ 覆蓋失敗：%s → %s (%s)', ...
                senName, tgtSat, ME.message);
        end
    end
end
end
