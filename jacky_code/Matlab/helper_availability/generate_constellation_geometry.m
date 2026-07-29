function geom = generate_constellation_geometry(constellation, common)
% generate_constellation_geometry
% Build the nominal Walker orbital elements (circular orbits) for one
% constellation-like geometry, BEFORE alignment to the GS. The constellation
% may contain one OR MORE shells (constellation.shells); every shell keeps
% its own altitude / inclination / mean motion, and all satellites are
% concatenated into a single flat list so that different shells share the
% same ECEF frame and time grid.
%
% Inputs:
%   constellation : one entry of cfg.constellations (see config_helper_availability)
%   common        : cfg.common (Earth constants etc.)
%
% Output geom:
%   geom.name        : geometry name
%   geom.nSat        : total number of satellites (all shells)
%   geom.sats        : struct array, one per satellite, with fields
%                        name, shell (1-based), plane (1-based),
%                        idxInPlane (1-based), RAAN_deg,
%                        u0_deg (arg. of latitude at t = 0),
%                        a_km, inc_deg, n_rad_s (per-satellite elements)
%   geom.refIndex    : linear index of the reference satellite in geom.sats
%   geom.shells      : struct array summarising each shell
%   geom.isExampleGeometry : logical flag copied from the config entry
%
% Walker notation i:T/P/F with T = P*S. RAAN spread is 180 deg for a
% near-polar Walker Star and 360 deg for a Walker Delta.
%
% Units: angles in deg, distances in km, mean motion in rad/s.

shells = constellation.shells;
if ~iscell(shells)
    shells = {shells};
end
nShell = numel(shells);

satTemplate = struct('name', "", 'shell', 0, 'plane', 0, 'idxInPlane', 0, ...
    'RAAN_deg', 0, 'u0_deg', 0, 'a_km', 0, 'inc_deg', 0, 'n_rad_s', 0);
sats = repmat(satTemplate, 0, 1);

shellSummary = repmat(struct('altitude_km', 0, 'inc_deg', 0, 'a_km', 0, ...
    'nPlanes', 0, 'nSatPerPlane', 0, 'nSat', 0, 'walkerType', ''), nShell, 1);

shellStartIdx = zeros(nShell, 1);   % linear index of the first sat of each shell
k = 0;
for sh = 1:nShell
    shell = shells{sh};
    P = double(shell.number_of_planes);
    S = double(shell.satellites_per_plane);
    F = double(shell.walker_phasing_F);
    a_km = common.Re_km + double(shell.altitude_km);
    inc_deg = double(shell.inclination_deg);
    n_rad_s = sqrt(common.mu_km3_s2 / a_km^3);

    switch lower(char(shell.walker_type))
        case 'star'
            raanSpan_deg = 180;   % near-polar Walker Star
        case 'delta'
            raanSpan_deg = 360;   % inclined Walker Delta
        otherwise
            error('generate_constellation_geometry:walkerType', ...
                'Unknown walker_type "%s" (use ''star'' or ''delta'').', ...
                char(shell.walker_type));
    end

    shellStartIdx(sh) = k + 1;
    for p = 1:P
        RAAN_deg = mod((p - 1) * raanSpan_deg / P, 360);
        for s = 1:S
            k = k + 1;
            u0_deg = mod((s - 1) * 360 / S + F * 360 / (P * S) * (p - 1), 360);
            sats(k, 1).name       = sprintf('SH%d_P%02d_S%02d', sh, p, s);
            sats(k, 1).shell      = sh;
            sats(k, 1).plane      = p;
            sats(k, 1).idxInPlane = s;
            sats(k, 1).RAAN_deg   = RAAN_deg;
            sats(k, 1).u0_deg     = u0_deg;
            sats(k, 1).a_km       = a_km;
            sats(k, 1).inc_deg    = inc_deg;
            sats(k, 1).n_rad_s    = n_rad_s;
        end
    end

    shellSummary(sh).altitude_km  = double(shell.altitude_km);
    shellSummary(sh).inc_deg      = inc_deg;
    shellSummary(sh).a_km         = a_km;
    shellSummary(sh).nPlanes      = P;
    shellSummary(sh).nSatPerPlane = S;
    shellSummary(sh).nSat         = P * S;
    shellSummary(sh).walkerType   = char(shell.walker_type);
end
nSat = k;

% Reference satellite: locate (ref_shell, ref_plane, ref_sat) in the flat list.
refShell = clampIndex(constellation.ref_shell_index, nShell);
refP = double(shells{refShell}.number_of_planes);
refS = double(shells{refShell}.satellites_per_plane);
refPlane = clampIndex(constellation.ref_plane_index, refP);
refSat   = clampIndex(constellation.ref_sat_index, refS);
refIndex = shellStartIdx(refShell) + (refPlane - 1) * refS + (refSat - 1);

geom = struct();
geom.name      = char(constellation.name);
geom.nSat      = nSat;
geom.sats      = sats;
geom.refIndex  = refIndex;
geom.refShell  = refShell;
geom.refPlane  = refPlane;
geom.refSat    = refSat;
geom.shells    = shellSummary;
geom.nShell    = nShell;
geom.isExampleGeometry = logical(constellation.isExampleGeometry);
end

% ----------------------------------------------------------------------
function idx = clampIndex(value, maxValue)
idx = round(double(value));
idx = min(max(idx, 1), maxValue);
end
