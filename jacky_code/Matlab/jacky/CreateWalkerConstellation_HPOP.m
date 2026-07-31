function leoNames = CreateWalkerConstellation_HPOP(root, sc, alt_km, inc_deg, numPlanes, satsPerPlane, tEpochStr)
% CreateWalkerConstellation_HPOP
% Build a Walker-like circular constellation in STK using HPOP.
% - RAAN evenly spaced by 360/numPlanes
% - In-plane phase evenly spaced by 360/satsPerPlane
% - Satellite naming: Pxx_Syy
%
% =====================================================================
% 【中文說明】在 STK 中建立 OneWeb-like 的 Walker star 極軌星座（用 HPOP 傳播）。
% 對應論文 Simulation Setup：高度 1200 km、傾角 87.9 deg。
%
% 命名規則：P<軌道面編號>_S<同軌編號>，例 P03_S49。
% 論文主模擬的 critical 衛星就是 P03_S49（第 3 軌道面第 49 顆）。
%
% 【重要 —— 很容易誤會的地方】
% 下面的迴圈寫的是 for p = 1:5，也就是「只實際建立 5 個軌道面」，
% 但 RAAN 間距 raanSpacing_deg 仍然用傳入的 numPlanes 計算。
% 這是刻意的：
%   - 幾何上仍等同完整的 numPlanes（例 12）面 Walker star 星座；
%   - 但論文評估只用到 GS 附近的 P01~P05（見 jacky.m 的 satUserTargets），
%     只建 5 面可以大幅縮短 STK 建場與傳播時間。
% 若你需要更多軌道面（例如要用到 P17/P18），
% 請把下面的 for p = 1:5 改成 for p = 1:numPlanes，
% 只改 jacky.m 的 numPlanes 是不會生效的。
% =====================================================================

    if nargin < 7 || strlength(string(tEpochStr)) == 0
        tEpochStr = datestr(datetime('now','TimeZone','UTC'), 'dd mmm yyyy HH:MM:SS');
    end

    % Walker star：RAAN 均勻分布在 180 deg（非 360 deg），例 12 面 → 每面相隔 15 deg
    raanSpacing_deg = 180 / numPlanes;
    % 同一軌道面內，各衛星的平近點角均勻分布在 360 deg
    phaseSpacing_deg = 360 / satsPerPlane;

    root.UnitPreferences.Item('DateFormat').SetCurrentUnit('UTCG');

    leoNames = strings(0,1);

    % 注意：只建前 5 個軌道面（原因見上方說明）
    for p = 1:5
        raan_deg = (p-1) * raanSpacing_deg;

        for s = 1:satsPerPlane
            meanAnomaly_deg = (s-1) * phaseSpacing_deg;
            satName = sprintf('P%02d_S%02d', p, s);

            % Remove same-name object if already exists
            % 若場景中已有同名衛星就先卸載，避免重跑時衝突
            try
                sc.Children.Item(satName).Unload();
            catch
            end

            sat = sc.Children.New('eSatellite', satName);
            sat.SetPropagatorType('ePropagatorHPOP');   % 用 HPOP 高精度傳播器
            sat.Propagator.InitialState.OrbitEpoch.SetExplicitTime(tEpochStr);

            kepler = sat.Propagator.InitialState.Representation.ConvertTo('eOrbitStateClassical');
            % Use altitude sizing (STK doc): matches Orbit GUI / LLA Alt, avoids
            % MeanMotion unit mismatches that were giving ~980 km instead of alt_km.
            % 用「高度」而非 MeanMotion 定義軌道大小，避免單位換算誤差
            % （曾經因此得到 ~980 km 而不是設定的 alt_km）
            kepler.SizeShapeType = 'eSizeShapeAltitude';
            kepler.LocationType = 'eLocationMeanAnomaly';
            kepler.Orientation.AscNodeType = 'eAscNodeRAAN';

            kepler.SizeShape.PerigeeAltitude = alt_km;   % 近地點高度 = 遠地點高度 → 圓軌道
            kepler.SizeShape.ApogeeAltitude = alt_km;
            kepler.Orientation.Inclination = inc_deg;    % 傾角，論文 87.9 deg
            kepler.Orientation.ArgOfPerigee = 0;
            kepler.Orientation.AscNode.Value = raan_deg; % 該軌道面的升交點赤經
            kepler.Location.Value = meanAnomaly_deg;     % 該衛星在軌道面內的相位

            sat.Propagator.InitialState.Representation.Assign(kepler);

            % HPOP force model + integrator
            % 力學模型：20x20 地球重力場 + 日月引力；關閉大氣阻力與太陽輻射壓
            % （模擬窗只有數分鐘，這兩項影響可忽略，關掉可加速）
            try
                fm = sat.Propagator.ForceModel;
                fm.CentralBodyGravity.Degree = 20;
                fm.CentralBodyGravity.Order = 20;
                fm.SolarGravity = true;
                fm.LunarGravity = true;
                fm.Drag.Use = false;
                fm.SolarRadiationPressure.Use = false;
            catch
            end

            try
                integ = sat.Propagator.Integrator;
                integ.Method = 'eIntegratorRungeKuttaFehlberg78';
                integ.InitialStepSize = 10;
                integ.MinStepSize = 0.1;
                integ.MaxStepSize = 60;
                integ.ErrorTolerance = 1e-12;
            catch
            end

            sat.Propagator.Propagate;
            leoNames(end+1) = string(satName); %#ok<AGROW>
        end
    end
end

