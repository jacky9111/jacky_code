function cfg = config_helper_availability()
% config_helper_availability
% Central configuration for the "helper availability under different
% constellation-like geometries" experiment.
%
% This experiment does NOT reproduce the real payload of any commercial
% constellation. It only changes the orbital GEOMETRY while keeping an
% identical 16-beam model, beam power, antenna pattern, EPFD model and
% helper-identification criteria, so that the effect of satellite density
% and orbital configuration on recovery-capable helper availability can be
% observed in isolation.
%
% Each constellation entry may contain ONE OR MORE orbital shells (the
% "shells" cell array). A shell is a single Walker layer with its own
% altitude, inclination, plane count, satellites-per-plane and phasing.
% Multi-shell entries (e.g. Telesat Lightspeed's polar + inclined
% sub-constellations) are propagated together so that satellites from any
% shell can act as recovery helpers for a critical satellite in any shell.
%
% ALL tunable parameters live here. Do not scatter geometry/beam/EPFD
% constants inside the processing functions.
%
% Units convention used throughout the module:
%   distance : km (positions), m (EPFD path terms)
%   angle    : deg (public API) / rad (internal trig only)
%   power    : W
%   EPFD     : linear W/m^2/reference-bandwidth internally; dB only for I/O

cfg = struct();

% ------------------------------------------------------------------
% Disclaimer shown in the command window and README.
% ------------------------------------------------------------------
cfg.disclaimer = [ ...
    'All three rows use the same OneWeb-like polar shell (1200 km, 87.9 deg); ', ...
    'only Walker plane count and satellites-per-plane change to emulate ', ...
    'reference / high / low density (high ~Starlink-scale, low ~Lightspeed-scale). ', ...
    'Beam, power and EPFD model are the thesis model; results are illustrative.'];

% ------------------------------------------------------------------
% Common scenario settings (identical for every constellation geometry).
% ------------------------------------------------------------------
common = struct();

% Ground station and reference GSO (same longitude as the GS).
common.gsLat_deg  = 0;        % GS latitude  [deg]
common.gsLon_deg  = 0;        % GS longitude [deg]
common.gsoLon_deg = 0;        % ideal GSO longitude [deg] (== GS longitude)

% Simulation time grid (relative seconds around the aligned epoch t = 0 s).
common.tStart_s = -120;
common.tEnd_s   =  120;
common.tStep_s  =  1;

% Reference-satellite-over-GS alignment tolerance [km]. If the reference
% sub-satellite point is farther than this from the GS at t = 0, warn.
common.alignTol_km = 1.0;

% Minimum elevation angle for a LEO satellite to be "visible" from GS [deg].
common.minElev_deg = 10;

% Earth and propagation constants (spherical Earth, circular orbits).
common.Re_km      = 6378.137;          % Earth mean equatorial radius [km]
common.mu_km3_s2  = 3.986004418e5;     % Earth GM [km^3/s^2]
common.we_rad_s   = 7.2921159e-5;      % Earth rotation rate [rad/s]
common.Rgeo_km    = 42164.0;           % GSO geostationary radius [km]

% ---- 16-beam satellite-fixed layout (identical for all geometries) ----
% The same satellite-fixed layout does NOT imply identical ground
% footprints; each satellite generates its own footprints from its own
% position and nadir-pointing attitude.
%
% Half-angles are NOT copied verbatim from STK -5 dB (34 / 33.5). Under
% this module's spherical-Earth + 16-beam ray/Earth polygons, that pair
% overshoots same-orbit half coverage. Instead we keep the -5 dB aspect
% ratio as a reference and calibrate halfNS_total (EW scaled with it) so
% that on the OneWeb-like geometry, along-track NS half-extent == in-plane
% SSP spacing (same-orbit ±1 neighbours cover exactly the middle N/S
% halves). That calibrated size is shared by all constellation rows.
beam = struct();
beam.Nbeam = 16;
beam.halfEW_ref_deg       = 34.0;   % thesis -5 dB aspect reference (EW)
beam.halfNS_total_ref_deg = 33.5;   % thesis -5 dB aspect reference (NS total)
beam.calibrateHalfOverlap = true;   % OneWeb-like half-overlap calibration
% Placeholders; overwritten by calibrate_beam_for_half_orbit_overlap below.
beam.halfEW_deg       = beam.halfEW_ref_deg;
beam.halfNS_total_deg = beam.halfNS_total_ref_deg;
beam.halfNS_deg       = beam.halfNS_total_deg / beam.Nbeam;
beam.pitchOffsets_deg = (8.5 - (1:beam.Nbeam)) * (2 * beam.halfNS_deg);
beam.boundarySamples  = 72;
beam.fullBeamPower_W  = 1.05;
common.beam = beam;

% ---- Footprint overlap / helper qualification ----
% Overlap is decided by polygon intersection area in a local tangent plane.
% A satellite counts as a recovery helper of a critical sat only if the SUM
% of its active-beam overlaps with that critical's closed beams is at least
% helperMinOverlapBeamFrac × (one nominal beam footprint area). This avoids
% counting tiny edge grazes that are useless for handover/recovery.
common.helperMinOverlapBeamFrac = 1.0;   % >= 1 beam area of total overlap
% oneBeamArea_km2 / helperMinOverlapArea_km2 filled after beam calibration.
common.oneBeamArea_km2 = NaN;
common.helperMinOverlapArea_km2 = NaN;
% Tiny area below which a single beam-pair is ignored as numerical noise.
common.overlapAreaTol_km2 = 1.0;

% ---- EPFD engineering parameters (single source) ----
% Reuse the existing Ku EPFD parameter set so the EPFD/beam model stays
% consistent with the rest of the thesis code.
P = ku_epfd_params();
P.useEIRPDensityModel = false;             % use explicit per-beam power model
P.Ptotal_W = beam.fullBeamPower_W * beam.Nbeam;
common.params    = P;
common.epfdThr_dB = P.EPFD_thr_dB;         % aggregate EPFD limit [dB(W/m^2/BWref)]

cfg.common = common;

% ------------------------------------------------------------------
% Constellation-like geometries (rows of the final table).
% All three rows share the thesis OneWeb-like polar shell:
%   altitude 1200 km, inclination 87.9 deg, Walker star (RAAN over 180 deg).
% Only plane count P and satellites-per-plane S change:
%   (1) OneWeb-like reference — thesis main simulation (12 x 49 = 588)
%   (2) High-density          — Starlink-scale total (~2650 sat):
%                               more planes (12->36) AND more sats/plane (49->74)
%   (3) Low-density           — Lightspeed-scale total (~288 sat):
%                               fewer planes (12->8) AND fewer sats/plane (49->36)
% ------------------------------------------------------------------
epoch = datetime(2025,12,16,12,0,0,'TimeZone','UTC');

owAlt_km = 1200;
owInc_deg = 87.9;
owWalker = 'star';
owF = 1;

% (1) OneWeb-like reference — thesis main simulation.
c1 = struct();
c1.name              = 'OneWeb-like reference';
c1.epoch             = epoch;
c1.isExampleGeometry = false;
c1.shells            = {mkShell(owAlt_km, owInc_deg, 12, 49, owWalker, owF)};
c1.ref_shell_index   = 1;
c1.ref_plane_index   = 3;               % thesis main sim uses plane 3
c1.ref_sat_index     = 25;

% (2) High-density — same polar shell, Starlink-scale satellite count (~2652).
%     36 planes (3x OneWeb) x 74 sats/plane (~1.5x OneWeb) = 2664 total.
c2 = struct();
c2.name              = 'High-density';
c2.epoch             = epoch;
c2.isExampleGeometry = true;            % illustrative density variant
c2.shells            = {mkShell(owAlt_km, owInc_deg, 36, 74, owWalker, owF)};
c2.ref_shell_index   = 1;
c2.ref_plane_index   = 1;
c2.ref_sat_index     = 1;

% (3) Low-density — same polar shell, Lightspeed-scale satellite count (~288).
%     8 planes x 36 sats/plane = 288 total (both plane count and along-orbit
%     spacing are reduced relative to the 12 x 49 reference).
c3 = struct();
c3.name              = 'Low-density';
c3.epoch             = epoch;
c3.isExampleGeometry = true;            % illustrative density variant
c3.shells            = {mkShell(owAlt_km, owInc_deg, 8, 36, owWalker, owF)};
c3.ref_shell_index   = 1;
c3.ref_plane_index   = 1;
c3.ref_sat_index     = 1;

cfg.constellations = {c1, c2, c3};

% ------------------------------------------------------------------
% Calibrate shared beam size on OneWeb-like half-overlap, then attach.
% ------------------------------------------------------------------
if common.beam.calibrateHalfOverlap
    common.beam = calibrate_beam_for_half_orbit_overlap(common, c1, common.beam);
end
% Nominal single-beam ground area (flat-Earth at OneWeb altitude) used as
% the helper-qualification unit ("one beam of overlap").
refAlt_km = double(c1.shells{1}.altitude_km);
halfEW_km = refAlt_km * tand(common.beam.halfEW_deg);
halfNS_km = refAlt_km * tand(common.beam.halfNS_deg);
common.oneBeamArea_km2 = 4 * halfEW_km * halfNS_km;
common.helperMinOverlapArea_km2 = ...
    common.helperMinOverlapBeamFrac * common.oneBeamArea_km2;
% Plot-only equal rectangle half-sizes (km) — same for every beam drawn.
common.plotBeamHalfEW_km = halfEW_km;
common.plotBeamHalfNS_km = halfNS_km;
fprintf(['[helper thresh] oneBeamArea=%.1f km^2, min total overlap=%.1f km^2 ', ...
    '(%.2g beam)\n'], common.oneBeamArea_km2, common.helperMinOverlapArea_km2, ...
    common.helperMinOverlapBeamFrac);
cfg.common = common;

% ------------------------------------------------------------------
% Output locations (results/ and results/figures/ under the module folder).
% ------------------------------------------------------------------
moduleDir = fileparts(mfilename('fullpath'));
matlabDir = fileparts(moduleDir);   % .../Matlab
cfg.io = struct();
cfg.io.moduleDir  = moduleDir;
cfg.io.resultsDir = fullfile(moduleDir, 'results');
cfg.io.figuresDir = fullfile(moduleDir, 'results', 'figures');
% Also export thesis-ready copies under jacky_code/Matlab_data.
cfg.io.matlabDataDir = fullfile(fileparts(matlabDir), 'Matlab_data');
cfg.io.summaryBase = 'helper_availability_summary';
cfg.io.rawMat      = 'helper_availability_raw.mat';
cfg.io.texCaption  = 'Helper Availability under OneWeb-Like Density Variants';
end

% ----------------------------------------------------------------------
function s = mkShell(altitude_km, inclination_deg, number_of_planes, ...
    satellites_per_plane, walker_type, walker_phasing_F)
% mkShell  Build one Walker shell descriptor struct.
s = struct( ...
    'altitude_km',          altitude_km, ...
    'inclination_deg',      inclination_deg, ...
    'number_of_planes',     number_of_planes, ...
    'satellites_per_plane', satellites_per_plane, ...
    'walker_type',          walker_type, ...
    'walker_phasing_F',     walker_phasing_F);
end
