function CreateAllOneWebBeams(root, satNames)
    disp("建立等效大矩形 OneWeb Beam (Sensor)");

    for i = 1:length(satNames)

        sat_name = satNames(i);
        sat = root.GetObjectFromPath("/Satellite/" + sat_name);

        sensorName = "RectBeam";

        % 建立 Sensor
        sensor = sat.Children.New('eSensor', sensorName);

        % --- 設定 Pattern = Rectangular FOV ---
        sensor.SetPatternType('eSnRectangular');

        % 論文的 half angles (Figure 3)
        % Horizontal = 25°, Vertical = 24.5°
        % 引用：PDF page 4, Figure 3  :contentReference[oaicite:0]{index=0}
        sensor.CommonTasks.SetPatternRectangular(...
            double(25), ...       % Horizontal half angle
            double(24.5));        % Vertical half angle

        % --- 設定 pointing：Nadir pointing (Az=0, El=-90) ---
        sensor.SetPointingType('eSnPtFixed');
        sensor.CommonTasks.SetPointingFixedAzEl(...
            0, ...                % Azimuth
            90, ...              % Elevation (Nadir)
            'eAzElAboutBoresightRotate');

        % --- 開啟 3D 顯示 ---
        sensor.Graphics.FillVisible = true;
            
        % --- 設置一點透明度（依你喜好） ---
        cmd = sprintf("Graphics */Satellite/%s/Sensor/%s FillTranslucency %d", ...
            sat_name, sensorName, 20);
        root.ExecuteCommand(cmd);

        disp(sat_name + " → RectBeam 建立完成");
    end

    disp("✨ Rectangular OneWeb Beam 全部完成");

end