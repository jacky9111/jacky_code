function geom2 = Step6A_Apply_Tilt_Paper(geom, critIdx, tiltDeg)
% ============================================================
% Step 6-A (Paper version)
% Apply tilt ONLY to critical satellites
%
% phi_r_new = phi_r_old + tiltDeg
% ============================================================

geom2 = geom;

geom2.phi_r_deg = geom.phi_r_deg;
geom2.phi_r_deg(critIdx) = geom.phi_r_deg(critIdx) + tiltDeg;

fprintf("Step 6-A: tilt = %.1f deg applied to %d sat(s)\n", ...
    tiltDeg, numel(critIdx));
end
