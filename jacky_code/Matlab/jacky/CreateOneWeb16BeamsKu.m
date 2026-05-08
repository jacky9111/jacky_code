function CreateOneWeb16BeamsKu(root, targetSats)
% CreateOneWeb16BeamsKu  （選用：jacky 主流程不呼叫）
%
% 若要在 STK 裡額外畫 16 個小矩形 sensor 才需要此函數。EPFD／Excel 已由
% RunEpfd16BeamsKuLogExcel 純 MATLAB 模擬 16 束，不需在 STK 建立 Beam_01..16。
% 主流程請保留 CreateOneWebRectBeam 單一大矩形做 seamless / relay 快速檢查。
%
% 水平半角 24.5°、南北向半角 25/16°。

    targetSats = string(targetSats);
    fprintf("建立 OneWeb 16-beam（Ku 流程｜Rect 24.5 x %.4f deg｜Nadir）\n", 25/16);

    for i = 1:numel(targetSats)
        satName = char(targetSats(i));
        sat = root.GetObjectFromPath(['Satellite/' satName]);

        for k = 1:16
            sensorName = sprintf('Beam_%02d', k);
            try
                old = sat.Children.Item(sensorName);
                old.Unload();
            catch
            end

            s = sat.Children.New('eSensor', sensorName);
            s.SetPatternType('eSnRectangular');
            s.CommonTasks.SetPatternRectangular(24.5, 25/16);

            try
                s.SetPointingType('eSnPtNadir');
            catch
                try
                    root.ExecuteCommand(sprintf( ...
                        'Point */Satellite/%s/Sensor/%s Nadir', satName, sensorName));
                catch ME
                    warning("Nadir pointing failed %s/%s: %s", satName, sensorName, ME.message);
                end
            end
            s.Graphics.FillVisible = true;
        end
        fprintf("✔ 16 beams on %s\n", satName);
    end
end
