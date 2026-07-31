function CreateOneWebRectBeam(root, targetSats, sensorName, beamProfile)
% CreateOneWebRectBeam
% Create ONE rectangular "aggregate" beam per LEO satellite in STK.
% This matches the paper's large rectangular coverage approximation:
% - horizontal half-angle: 25 deg
% - vertical half-angle:   24.5 deg
%
% Notes:
% - The paper describes 16 elliptical beams arranged N-S to approximate a large rectangle.
%   Here we directly create that large rectangle as ONE sensor.
% - Sensor points to nadir (earth-pointing).
%
% Inputs:
% - root: STK root object
% - targetSats: string array / cellstr of satellite names (e.g. ["ow1_30","ow1_38"])
% - sensorName (optional): default "RectBeam"
% - beamProfile (optional): "-3dB" (paper) or "-5dB" (expanded estimate)
%
% =====================================================================
% 【中文說明】在 STK 裡幫衛星掛一個「大矩形 beam」sensor。
%
% 這只是視覺化用途。論文真正的 16 束 EPFD 計算是在 MATLAB 內完成的
% （見 RunFullPowerAggregateShutdownSweepExcel / RunEpfd16BeamsKuLogExcel），
% 不會去讀這個 STK sensor，所以這一段跳過也不影響論文數據。
%
% beamProfile 兩種輪廓：
%   "-3dB"  半角 25.0 / 24.5 deg —— 論文 / FCC filing 的等效矩形波束
%   "-5dB"  半角 34.0 / 33.5 deg —— 由 FCC 等高線外推的工程估計值
%           （jacky.m 用這組，且與 evalBeamHalfEW_deg=34.0、
%             evalBeamHalfNS_deg=33.5/16 一致）
%
% 【注意】下面迴圈只處理 targetSats 的前 3 顆（即使傳進 49 顆也一樣），
% 因為建 sensor 很慢而畫面上只需要幾顆做示意。
% 若要幫全部衛星都建 beam，請把 nCreate 改成 numel(targetSats)。
% =====================================================================

if nargin < 3 || strlength(string(sensorName)) == 0
    sensorName = "RectBeam";
end
sensorName = char(string(sensorName));

if nargin < 4 || strlength(string(beamProfile)) == 0
    beamProfile = "-3dB";
end
beamProfile = string(beamProfile);

% -3 dB: paper/FCC equivalent rectangular beam
% -5 dB: engineering expanded estimate from FCC contour extension
switch lower(strrep(beamProfile, " ", ""))
    case {"-5db","5db","minus5db"}
        beamHalfH = 34.0;    % 東西向半角 [deg]
        beamHalfV = 33.5;    % 南北向半角 [deg]（16 束加總後的總半角）
        beamProfileLabel = "-5 dB (estimated)";
    otherwise
        beamHalfH = 25.0;
        beamHalfV = 24.5;
        beamProfileLabel = "-3 dB (paper/FCC)";
end

targetSats = string(targetSats);

fprintf("建立 OneWeb 大長方形 beam（單一 Sensor｜Nadir pointing｜%s）\n", beamProfileLabel);

% 只建前 3 顆做示意（原因見檔頭）；用 min 避免傳入少於 3 顆時索引越界
nCreate = min(3, numel(targetSats));
for i = 1:nCreate
    satName = char(targetSats(i));
    fprintf("Processing %s\n", satName);

    sat = root.GetObjectFromPath(['Satellite/' satName]);

    % Remove old sensor with same name (if exists)
    try
        old = sat.Children.Item(sensorName);
        old.Unload();
    catch
    end

    s = sat.Children.New('eSensor', sensorName);

    % Rectangular pattern (STK expects half-angles in deg)
    s.SetPatternType('eSnRectangular');
    s.CommonTasks.SetPatternRectangular(beamHalfH, beamHalfV);

    % Nadir pointing (STK enum names can differ by version; keep robust fallbacks)
    try
        s.SetPointingType('eSnPtNadir');
    catch
        try
            % Fallback via Connect command (works in versions where COM enum name differs)
            root.ExecuteCommand(sprintf( ...
                'Point */Satellite/%s/Sensor/%s Nadir', satName, sensorName));
        catch ME
            warning("Nadir pointing fallback failed on %s/%s: %s", satName, sensorName, ME.message);
        end
    end

    % Graphics
    s.Graphics.FillVisible = true;

    fprintf("✔ Rect beam created on %s (%s)\n", satName, sensorName);
end

disp("✨ 完成（單一 RectBeam）");
end

