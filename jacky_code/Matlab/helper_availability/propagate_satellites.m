function state = propagate_satellites(geom, common, t_s)
% propagate_satellites
% Circular-orbit propagation of a Walker constellation to Earth-Centered
% Earth-Fixed (ECEF) coordinates over a time vector.
%
% Inputs:
%   geom   : output of generate/align (sats[] carry per-satellite a_km,
%            inc_deg, n_rad_s so that multiple shells are supported)
%   common : cfg.common (Earth rotation rate, epoch reference GMST = 0)
%   t_s    : 1xT vector of relative times [s] (t = 0 is the aligned epoch)
%
% Output state:
%   state.t_s          : 1xT time vector [s]
%   state.pos_ecef_km  : 3 x nSat x T ECEF positions [km]
%   state.vel_ecef_kmps: 3 x nSat x T ECEF velocities [km/s]
%   state.subLat_deg   : nSat x T sub-satellite latitude  [deg]
%   state.subLon_deg   : nSat x T sub-satellite longitude [deg]
%
% Assumptions: spherical Earth, circular orbits (e = 0), two-body mean
% motion, GMST(0) = 0 so that the ECEF frame coincides with ECI at t = 0.
% Units: km, km/s, deg, rad/s.

t_s = double(t_s(:)).';
T = numel(t_s);
nSat = geom.nSat;
% Per-satellite orbital elements (support multi-shell constellations).
a  = [geom.sats.a_km].';                   % nSat x 1 semi-major axis [km]
n  = [geom.sats.n_rad_s].';                % nSat x 1 mean motion [rad/s]
we = common.we_rad_s;

RAAN0 = deg2rad([geom.sats.RAAN_deg]).';   % nSat x 1
u0    = deg2rad([geom.sats.u0_deg]).';     % nSat x 1
ci = cosd([geom.sats.inc_deg]).';          % nSat x 1
si = sind([geom.sats.inc_deg]).';          % nSat x 1

pos_ecef_km   = zeros(3, nSat, T);
vel_ecef_kmps = zeros(3, nSat, T);
subLat_deg    = zeros(nSat, T);
subLon_deg    = zeros(nSat, T);

for it = 1:T
    tt = t_s(it);
    u = u0 + n .* tt;            % nSat x 1 argument of latitude [rad]
    cu = cos(u); su = sin(u);
    cO = cos(RAAN0); sO = sin(RAAN0);

    % ECI position (circular orbit, e = 0). All terms are per-satellite.
    x = a .* (cu .* cO - su .* ci .* sO);
    y = a .* (cu .* sO + su .* ci .* cO);
    z = a .* (su .* si);

    % ECI velocity magnitude a*n along the in-plane transverse direction.
    an = a .* n;
    vx = an .* (-su .* cO - cu .* ci .* sO);
    vy = an .* (-su .* sO + cu .* ci .* cO);
    vz = an .* (cu .* si);

    % Rotate ECI -> ECEF by the Earth rotation angle theta = we * t (GMST0 = 0).
    theta = we * tt;
    cth = cos(theta); sth = sin(theta);
    xe =  cth .* x + sth .* y;
    ye = -sth .* x + cth .* y;
    ze =  z;
    % ECEF velocity: v_ecef = R(theta)*v_eci + dR/dt * r_eci, where
    % R = [ cth sth; -sth cth ] about +z and dR/dt = we * dR/dtheta.
    vxe =  cth .* vx + sth .* vy + we * (-sth .* x + cth .* y);
    vye = -sth .* vx + cth .* vy + we * (-cth .* x - sth .* y);
    vze =  vz;

    pos_ecef_km(1, :, it) = xe.'; pos_ecef_km(2, :, it) = ye.'; pos_ecef_km(3, :, it) = ze.';
    vel_ecef_kmps(1, :, it) = vxe.'; vel_ecef_kmps(2, :, it) = vye.'; vel_ecef_kmps(3, :, it) = vze.';

    r = sqrt(xe.^2 + ye.^2 + ze.^2);
    subLat_deg(:, it) = asind(ze ./ max(r, eps));
    subLon_deg(:, it) = atan2d(ye, xe);
end

state = struct();
state.t_s           = t_s;
state.pos_ecef_km   = pos_ecef_km;
state.vel_ecef_kmps = vel_ecef_kmps;
state.subLat_deg    = subLat_deg;
state.subLon_deg    = subLon_deg;
end
