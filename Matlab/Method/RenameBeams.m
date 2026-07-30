function RenameBeams(root, satName)
% ============================================================
% RenameBeams
% 將指定衛星上的 16 個 Beam 重新命名為 Beam_01 ~ Beam_16
% STK 12 COM-safe version
% ============================================================

% === 強制轉成 char（關鍵） ===
satName = char(satName);

fprintf('Renaming beams on Satellite/%s\n', satName);

satPath = ['Satellite/' satName];
sat = root.GetObjectFromPath(satPath);

% ---------- 原始名稱 → 新名稱 ----------
oldNames = { ...
    'Beam_1','Beam_2','Beam_3','Beam_4','Beam_5','Beam_6','Beam_7','Beam_8','Beam_9', ...
    'Beam_17','Beam_18','Beam_19','Beam_20','Beam_21','Beam_22','Beam_23' };

newNames = { ...
    'Beam_01','Beam_02','Beam_03','Beam_04','Beam_05','Beam_06','Beam_07','Beam_08','Beam_09', ...
    'Beam_10','Beam_11','Beam_12','Beam_13','Beam_14','Beam_15','Beam_16' };

% ---------- Rename ----------
for k = 1:numel(oldNames)
    try
        sensorPath = ['Satellite/' satName '/Sensor/' oldNames{k}];
        sensor = root.GetObjectFromPath(sensorPath);
        sensor.InstanceName = newNames{k};
        fprintf('  %s -> %s\n', oldNames{k}, newNames{k});
    catch
        warning('Sensor %s not found, skipped.', oldNames{k});
    end
end

fprintf('✅ Rename completed for %s\n', satName);
end
