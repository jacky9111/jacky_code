function addSatellitesFromTLE_HPOP(root, sc, data, Iridium, Iridium_OMNet)
    disp("add satellites (TRUE HPOP)");

    % 使用 UTCG
    root.UnitPreferences.Item('DateFormat').SetCurrentUnit('UTCG');

    for i = 1:8:length(data)

        %% ---------- 衛星名稱 ----------
        sat_name = string(data(i));
        if ~ismember(sat_name, Iridium)
            disp(sat_name + " not used");
            continue;
        else
            disp("✅ 衛星 index: " + (fix(i/8) + 1));
        end

        %% ---------- 解析 TLE ----------
        epoch         = string(data(i+1));
        Inclination   = str2double(data{i+2});
        RAAN          = str2double(data{i+3});
        Eccentricity  = str2double(data{i+4}) * 1e-7;
        ArgPerigee    = str2double(data{i+5});
        MeanAnomaly   = str2double(data{i+6});
        MeanMotion    = str2double(data{i+7});

        % TLE epoch → datetime
        e1 = str2double(regexp(epoch, '(\d{2})(\d{3})(\.\d+)', ...
                               'tokens', 'once'));
        en = datenum(e1(1) + 2000, 0, e1(2), 24 * e1(3), 0, 0);
        et = datetime(en, 'ConvertFrom', 'datenum');
        es = datestr(et);

        %% ---------- 建立 Satellite ----------
        sat_id = string(Iridium_OMNet(find(Iridium == sat_name)));
        disp("🌐 新增衛星：" + sat_id);
        sat = sc.Children.New('eSatellite', sat_id);

        %% =========================================================
        %% ① 使用真正的 HPOP
        %% =========================================================
        sat.SetPropagatorType('ePropagatorHPOP');

        %% ---------- 設定 Orbit Epoch ----------
        sat.Propagator.InitialState.OrbitEpoch.SetExplicitTime(es);

        %% ---------- 初始軌道（TLE → Classical） ----------
        kepler = sat.Propagator.InitialState.Representation ...
                    .ConvertTo('eOrbitStateClassical');

        kepler.SizeShapeType              = 'eSizeShapeMeanMotion';
        kepler.LocationType               = 'eLocationMeanAnomaly';
        kepler.Orientation.AscNodeType    = 'eAscNodeRAAN';

        kepler.SizeShape.MeanMotion       = MeanMotion * 0.0041666648666622268; % rev/day → rad/min
        kepler.SizeShape.Eccentricity     = Eccentricity;
        kepler.Orientation.Inclination    = Inclination;
        kepler.Orientation.ArgOfPerigee   = ArgPerigee;
        kepler.Orientation.AscNode.Value  = RAAN;
        kepler.Location.Value             = MeanAnomaly;

        sat.Propagator.InitialState.Representation.Assign(kepler);

        %% =========================================================
        %% ② ★★★ HPOP Force Models（關鍵）★★★
        %% =========================================================
        fm = sat.Propagator.ForceModel;

        % ---- 地球非球形重力（最重要）----
        fm.CentralBodyGravity.Degree = 20;
        fm.CentralBodyGravity.Order  = 20;

        % ---- 第三體引力 ----
        fm.SolarGravity = true;
        fm.LunarGravity = true;

        % ---- 大氣阻力（Iridium 高度仍有影響）----
        fm.Drag.Use = true;
        fm.Drag.AtmosphericModel = 'NRLMSISE2000';
        fm.Drag.Cd = 2.2;
        fm.Drag.AreaMassRatio = 0.02;   % 可之後依衛星修正

        % ---- 太陽輻射壓（建議一定要開）----
        fm.SolarRadiationPressure.Use = true;
        fm.SolarRadiationPressure.Cr  = 1.2;
        fm.SolarRadiationPressure.AreaMassRatio = 0.02;

        %% =========================================================
        %% ③ Integrator（數值精度）
        %% =========================================================
        integ = sat.Propagator.Integrator;

        integ.Method = 'eIntegratorRungeKuttaFehlberg78';
        integ.InitialStepSize = 10;     % sec
        integ.MinStepSize     = 0.1;
        integ.MaxStepSize     = 60;
        integ.ErrorTolerance = 1e-12;

        %% ---------- Propagate ----------
        sat.Propagator.Propagate;

    end

    disp("✅ 所有衛星已用【真正 HPOP】新增完成");
end
