function Validate_Step3_Geometry(geom, satsVis, users, gs, geo)

N = geom.N;
U = numel(users);

fprintf("\n========== Validate Step 3 Geometry ==========\n");

% ---- (0) size checks ----
mustN = { ...
    "d_gs_m","phi_t_deg","phi_r_deg","userIdx","d_su_m","el_gs_deg" ...
};
for k = 1:numel(mustN)
    f = mustN{k};
    assert(isfield(geom,f), "Missing field: %s", f);
    v = geom.(f);
    assert(numel(v)==N, "Field %s length mismatch: got %d expected %d", f, numel(v), N);
end
fprintf("[OK] (0) Vector sizes all match N=%d\n", N);

% ---- (1) visibility ----
minEl = min(geom.el_gs_deg);
maxEl = max(geom.el_gs_deg);
fprintf("[Check] (1) Elevation@GS: min=%.4f max=%.4f deg\n", minEl, maxEl);
if minEl < -0.2
    error("Elevation too negative (%.3f deg). Step2/3 frame or GS position may be wrong.", minEl);
elseif minEl < 0
    fprintf("  (Note) Slight negative min elevation (%.4f) likely numerical tolerance.\n", minEl);
else
    fprintf("[OK] (1) Elevation is non-negative (visible set consistent)\n");
end

% ---- (2) distance sanity ----
dmin = min(geom.d_gs_m);
dmax = max(geom.d_gs_m);
fprintf("[Check] (2) d_gs: min=%.0f m (%.1f km) | max=%.0f m (%.1f km)\n", ...
    dmin, dmin/1e3, dmax, dmax/1e3);

if dmin < 8e5 || dmin > 3e6
    warning("d_gs min looks unusual. Expected ~1.2e6 m order for 1200 km altitude.");
end
if dmax > 2e7
    warning("d_gs max looks very large; check elevation mask and geometry.");
end

% ---- (3) phi_t bounds ----
ptMin = min(geom.phi_t_deg);
ptMax = max(geom.phi_t_deg);
fprintf("[Check] (3) phi_t: min=%.3f max=%.3f deg\n", ptMin, ptMax);
assert(ptMin >= -1e-6 && ptMax <= 180+1e-6, "phi_t out of [0,180] bounds");

% ---- (4) phi_r bounds ----
prMin = min(geom.phi_r_deg);
prMax = max(geom.phi_r_deg);
fprintf("[Check] (4) phi_r: min=%.3f max=%.3f deg\n", prMin, prMax);
assert(prMin >= -1e-6 && prMax <= 180+1e-6, "phi_r out of [0,180] bounds");

% ---- (5) userIdx bounds ----
uiMin = min(geom.userIdx);
uiMax = max(geom.userIdx);
fprintf("[Check] (5) userIdx: min=%d max=%d (U=%d)\n", uiMin, uiMax, U);
assert(uiMin >= 1 && uiMax <= U, "userIdx out of [1,U] range");

fprintf("\n✅ Step 3 validation PASSED.\n");

% ---- optional: quick debug plots ----
figure; histogram(geom.el_gs_deg); grid on;
xlabel('Elevation at GS (deg)'); ylabel('Count'); title('Step 3: Elevation Distribution');

figure; histogram(geom.phi_t_deg); grid on;
xlabel('\phi_t (deg)'); ylabel('Count'); title('Step 3: GS off-axis angle distribution');

figure; histogram(geom.phi_r_deg); grid on;
xlabel('\phi_r (deg)'); ylabel('Count'); title('Step 3: Sat off-axis angle distribution');

end
