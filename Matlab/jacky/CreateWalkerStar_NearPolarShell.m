function leoNames = CreateWalkerStar_NearPolarShell( ...
    root, sc, alt_km, inc_deg, numPlanes, satsPerPlane, planeIndices, satPrefix, tEpochStr, satIndices, interleaveAdjacentPlanes, walkerF)
% CreateWalkerStar_NearPolarShell
%   Build a near-polar Walker Star / shell constellation in STK (HPOP).
%
% Inputs:
%   root, sc        : STK root object and current scenario
%   alt_km          : LEO altitude above Earth [km]
%   inc_deg         : inclination [deg]
%   numPlanes       : number of orbital planes (P)
%   satsPerPlane    : satellites per plane (R)  (your "48")
%   planeIndices    : which planes to create (1-based). e.g. 1 means only plane 1
%   satPrefix       : reserved argument (kept for backward compatibility)
%   tEpochStr       : orbit epoch time string (e.g. '16 Dec 2025 12:10:03')
%   satIndices      : optional satellite indices to create in each plane (1-based).
%                     empty => create all 1..satsPerPlane
%   interleaveAdjacentPlanes : optional bool.
%                     true => adjacent planes are shifted by half slot
%                             (0, +0.5*slot, 0, +0.5*slot, ...)
%   walkerF         : optional Walker phase factor F.
%                     Mean anomaly phase increment per plane:
%                     dM_plane = F * 360 / (numPlanes * satsPerPlane)
%
% Output:
%   leoNames : string array of created satellite names

    if nargin < 7 || isempty(planeIndices)
        planeIndices = 1;
    end
    if nargin < 8 || isempty(satPrefix)
        satPrefix = "";
    end
    if nargin < 9 || isempty(tEpochStr)
        tEpochStr = datestr(datetime('now','TimeZone','UTC'), 'dd mmm yyyy HH:MM:SS');
    end
    if nargin < 10 || isempty(satIndices)
        satIndices = 1:satsPerPlane;
    end
    if nargin < 11 || isempty(interleaveAdjacentPlanes)
        interleaveAdjacentPlanes = false;
    end
    if nargin < 12 || isempty(walkerF)
        walkerF = [];
    end

    satIndices = unique(round(satIndices(:).'));
    satIndices = satIndices(satIndices >= 1 & satIndices <= satsPerPlane);
    if isempty(satIndices)
        error('satIndices is empty after range filtering. Valid range: 1..%d', satsPerPlane);
    end

    % --- Basic orbit model: assume near-circular ---
    Re_km = 6378.137;      % Earth equatorial radius [km]
    mu_km3_s2 = 398600.4418; % Earth gravitational parameter [km^3/s^2]
    a_km = Re_km + alt_km;

    % STK classical "eSizeShapeMeanMotion" uses MeanMotion in rad/min.
    n_rad_s = sqrt(mu_km3_s2 / a_km^3);     % rad/s
    meanMotion_rad_min = n_rad_s * 60;     % rad/min

    raanSpacing_deg  = 360 / numPlanes;
    phaseSpacing_deg = 360 / satsPerPlane;
    phasePerPlane_deg = 0;
    if ~isempty(walkerF)
        phasePerPlane_deg = walkerF * 360 / (numPlanes * satsPerPlane);
    elseif interleaveAdjacentPlanes
        % Backward-compatible fallback: adjacent planes half-slot stagger.
        phasePerPlane_deg = phaseSpacing_deg / 2;
    end

    % A tiny eccentricity helps numerical stability in some STK setups.
    eccentricity = 1e-4;
    argPerigee_deg = 0;

    leoNames = strings(0,1);

    root.UnitPreferences.Item('DateFormat').SetCurrentUnit('UTCG');
    root.UnitPreferences.SetCurrentUnit('Distance', 'km');
    root.UnitPreferences.SetCurrentUnit('Latitude', 'deg');
    root.UnitPreferences.SetCurrentUnit('Longitude', 'deg');

    for p = planeIndices(:).'
        raan_deg = (p-1) * raanSpacing_deg;
        phaseOffset_deg = (p-1) * phasePerPlane_deg;

        for idx = 1:numel(satIndices)
            satIdx = satIndices(idx);
            k = satIdx - 1;
            meanAnomaly_deg = mod(k * phaseSpacing_deg + phaseOffset_deg, 360);

            % Keep names short as requested: Pxx_Sxx
            satName = sprintf('P%02d_S%02d', p, satIdx);
            satName = char(satName);

            % If satellite already exists, unload it to keep reruns idempotent.
            try
                sc.Children.Item(satName).Unload();
            catch
                % ignore if not found
            end

            sat = sc.Children.New('eSatellite', satName);
            sat.SetPropagatorType('ePropagatorHPOP');
            sat.Propagator.InitialState.OrbitEpoch.SetExplicitTime(tEpochStr);

            kepler = sat.Propagator.InitialState.Representation.ConvertTo('eOrbitStateClassical');
            kepler.SizeShapeType = 'eSizeShapeMeanMotion';
            kepler.LocationType  = 'eLocationMeanAnomaly';
            kepler.Orientation.AscNodeType = 'eAscNodeRAAN';

            kepler.SizeShape.MeanMotion   = meanMotion_rad_min;
            kepler.SizeShape.Eccentricity = eccentricity;
            kepler.Orientation.ArgOfPerigee   = argPerigee_deg;
            kepler.Orientation.Inclination    = inc_deg;
            kepler.Orientation.AscNode.Value  = raan_deg;
            kepler.Location.Value             = meanAnomaly_deg;

            sat.Propagator.InitialState.Representation.Assign(kepler);

            % Keep force model lightweight (fast & stable for position queries).
            try
                fm = sat.Propagator.ForceModel;
                fm.CentralBodyGravity.Degree = 20;
                fm.CentralBodyGravity.Order  = 20;
                fm.SolarGravity = true;
                fm.LunarGravity = true;
                fm.Drag.Use = false;
                fm.SolarRadiationPressure.Use = false;
            catch
                % If some force-model fields are unavailable in this STK version, ignore.
            end

            % HPOP integrator settings (stable and reproducible across runs).
            try
                integ = sat.Propagator.Integrator;
                integ.Method = 'eIntegratorRungeKuttaFehlberg78';
                integ.InitialStepSize = 10; % sec
                integ.MinStepSize = 0.1;    % sec
                integ.MaxStepSize = 60;     % sec
                integ.ErrorTolerance = 1e-12;
            catch
                % Ignore if this STK build does not expose these integrator fields.
            end

            sat.Propagator.Propagate;

            leoNames(end+1) = satName; %#ok<AGROW>
            fprintf("Created %s (RAAN=%.2f deg, M=%.2f deg)\n", satName, raan_deg, meanAnomaly_deg);
        end
    end
end

