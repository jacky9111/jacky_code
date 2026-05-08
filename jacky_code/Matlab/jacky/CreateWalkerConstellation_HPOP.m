function leoNames = CreateWalkerConstellation_HPOP(root, sc, alt_km, inc_deg, numPlanes, satsPerPlane, tEpochStr)
% CreateWalkerConstellation_HPOP
% Build a Walker-like circular constellation in STK using HPOP.
% - RAAN evenly spaced by 360/numPlanes
% - In-plane phase evenly spaced by 360/satsPerPlane
% - Satellite naming: Pxx_Syy

    if nargin < 7 || strlength(string(tEpochStr)) == 0
        tEpochStr = datestr(datetime('now','TimeZone','UTC'), 'dd mmm yyyy HH:MM:SS');
    end

    % Evenly space RAAN over 360 deg (e.g. 12 planes -> 30 deg spacing)
    raanSpacing_deg = 180 / numPlanes;
    phaseSpacing_deg = 360 / satsPerPlane;

    root.UnitPreferences.Item('DateFormat').SetCurrentUnit('UTCG');

    leoNames = strings(0,1);

    for p = 1:3
        raan_deg = (p-1) * raanSpacing_deg;

        for s = 1:satsPerPlane
            meanAnomaly_deg = (s-1) * phaseSpacing_deg;
            satName = sprintf('P%02d_S%02d', p, s);

            % Remove same-name object if already exists
            try
                sc.Children.Item(satName).Unload();
            catch
            end

            sat = sc.Children.New('eSatellite', satName);
            sat.SetPropagatorType('ePropagatorHPOP');
            sat.Propagator.InitialState.OrbitEpoch.SetExplicitTime(tEpochStr);

            kepler = sat.Propagator.InitialState.Representation.ConvertTo('eOrbitStateClassical');
            % Use altitude sizing (STK doc): matches Orbit GUI / LLA Alt, avoids
            % MeanMotion unit mismatches that were giving ~980 km instead of alt_km.
            kepler.SizeShapeType = 'eSizeShapeAltitude';
            kepler.LocationType = 'eLocationMeanAnomaly';
            kepler.Orientation.AscNodeType = 'eAscNodeRAAN';

            kepler.SizeShape.PerigeeAltitude = alt_km;
            kepler.SizeShape.ApogeeAltitude = alt_km;
            kepler.Orientation.Inclination = inc_deg;
            kepler.Orientation.ArgOfPerigee = 0;
            kepler.Orientation.AscNode.Value = raan_deg;
            kepler.Location.Value = meanAnomaly_deg;

            sat.Propagator.InitialState.Representation.Assign(kepler);

            % HPOP force model + integrator
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

