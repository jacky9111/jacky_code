function Raise_LEO_Altitude(root, leoList, deltaH_km)
% ============================================================
% Raise LEO altitude by deltaH_km using Mean Motion
% HPOP-compatible if applied to InitialState BEFORE propagation
% ============================================================

fprintf("\n=== Raising LEO Altitude by %.2f km (Mean Motion) ===\n", deltaH_km);

mu = 398600.4418;   % Earth mu [km^3/s^2]
Re = 6378.137;      % Earth radius [km]

for i = 1:length(leoList)

    satName = leoList{i};
    satObj  = root.GetObjectFromPath(['*/Satellite/' satName]);
    prop    = satObj.Propagator;

    try
        % ===== Convert to Classical state =====
        state = prop.InitialState.Representation ...
            .ConvertTo('eOrbitStateClassical');

        % ----- Read current Mean Motion -----
        % STK Classical MeanMotion unit = rad/min
        mm0 = state.SizeShape.MeanMotion;      % rad/min

        % ----- Convert to rad/s -----
        n0 = mm0 / 60;                          % rad/s

        % ----- Compute current semi-major axis -----
        a0 = (mu / n0^2)^(1/3);                 % km
        h0 = a0 - Re;

        % ----- Raise altitude -----
        a1 = a0 + deltaH_km;

        % ----- New mean motion -----
        n1 = sqrt(mu / a1^3);                   % rad/s
        mm1 = n1 * 60;                          % rad/min

        % ----- Assign back -----
        state.SizeShape.MeanMotion = mm1;
        prop.InitialState.Representation.Assign(state);

        % ----- Propagate -----
        prop.Propagate();

        fprintf("  %-10s : h = %.2f → %.2f km | n = %.6f → %.6f rad/min\n", ...
            satName, h0, a1 - Re, mm0, mm1);

    catch ME
        warning('%s skipped (%s)', satName, ME.message);
    end
end

fprintf("=== Done ===\n\n");
end
