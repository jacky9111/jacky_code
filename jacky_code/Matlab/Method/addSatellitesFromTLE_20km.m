function addSatellitesFromTLE(root, sc, data, Iridium, Iridium_OMNet)
    disp("add satellites");
    root.UnitPreferences.Item('DateFormat').SetCurrentUnit('UTCG');

    for i = 1:8:length(data)
        % 解析 TLE 中的衛星名稱
        sat_name = string(data(i));
        if ~ismember(sat_name, Iridium)
            disp(sat_name + " not used");
            continue;
        else
            disp("✅ 衛星 index: " + fix(i/8)+1);
        end

        % 解析 TLE 參數
        epoch = string(data(i+1));
        Inclination = str2double(data{i+2});
        RAAN        = str2double(data{i+3});
        Eccentricity = str2double(data{i+4}) * 1e-7;
        ArgPerigee   = str2double(data{i+5});
        MeanAnomaly  = str2double(data{i+6});
        MeanMotion   = str2double(data{i+7});

        % 解析 epoch 為 datetime
        e1 = str2double(regexp(epoch, '(\d{2})(\d{3})(\.\d+)', 'tokens', 'once'));
        en = datenum(e1(1) + 2000, 0, e1(2), 24 * e1(3), 0, 0);
        et = datetime(en, 'ConvertFrom', 'datenum');
        es = datestr(et);

        % 建立衛星物件
        sat_id = string(Iridium_OMNet(find(Iridium == sat_name)));
        disp("🌐 新增衛星：" + sat_id);
        sat = sc.Children.New('eSatellite', sat_id);

        % 使用 HPOP
        sat.SetPropagatorType('ePropagatorHPOP');
        sat.Propagator.InitialState.OrbitEpoch.SetExplicitTime(es);
        kepler = sat.Propagator.InitialState.Representation.ConvertTo('eOrbitStateClassical');
        kepler.SizeShapeType = 'eSizeShapeMeanMotion';
        kepler.LocationType = 'eLocationMeanAnomaly';
        kepler.Orientation.AscNodeType = 'eAscNodeRAAN';

        % ===== 將 TLE Mean Motion 轉為半長軸 =====
        mu = 398600.4418;   % km^3/s^2
        Re = 6378.137;      % km

        n_rev_day = MeanMotion;                 % TLE value
        n_rad_s   = n_rev_day * 2*pi / 86400;   % rad/s

        a0 = (mu / n_rad_s^2)^(1/3);            % km
        a1 = a0 + 20;                            % +20 km

        % 新的 Mean Motion
        n1_rad_s   = sqrt(mu / a1^3);
        n1_rev_day = n1_rad_s * 86400 / (2*pi);

        kepler.SizeShape.MeanMotion     = n1_rev_day * 0.0041666648666622268;
        kepler.SizeShape.Eccentricity   = Eccentricity;
        kepler.Orientation.Inclination  = Inclination;
        kepler.Orientation.ArgOfPerigee = ArgPerigee;
        kepler.Orientation.AscNode.Value = RAAN;
        kepler.Location.Value           = MeanAnomaly;

        sat.Propagator.InitialState.Representation.Assign(kepler);
        sat.Propagator.Propagate;
    end

    disp("✅ 所有衛星新增完成");
end
