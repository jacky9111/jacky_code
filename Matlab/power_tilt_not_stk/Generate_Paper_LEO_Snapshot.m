function [sats, meta] = Generate_Paper_LEO_Snapshot(cfg, tUTC, gs)
% ============================================================
% Step 2 (Paper replication):
% Generate a Walker-star NGSO constellation snapshot in MATLAB
% and (optionally) return only satellites visible to a GSO GS.
%
% Paper setup: Walker-star, altitude 1200 km, 36 planes, 49 sats/plane.
% (Total 1764).  Ref: Section IV simulation setup.
%
% INPUT
%   cfg struct fields (recommended defaults shown below):
%     cfg.alt_km        = 1200;
%     cfg.nPlanes       = 36;
%     cfg.satsPerPlane  = 49;
%     cfg.inc_deg       = 87.9;     % OneWeb-like; keep as a parameter
%     cfg.ecc           = 0;        % circular
%     cfg.argp_deg      = 0;
%     cfg.raan0_deg     = 0;
%     cfg.M0_deg        = 0;
%     cfg.walkerF       = 1;        % phasing factor
%
%   tUTC : datetime (UTC)  snapshot time
%
%   gs (optional) struct:
%     gs.lat_deg, gs.lon_deg, gs.alt_m
%     gs.minEl_deg (e.g., 0)   % elevation mask
%     If provided, function outputs satsVisible + meta.idxVisible
%
% OUTPUT
%   sats struct:
%     sats.r_eci_m   [N x 3]
%     sats.r_ecef_m  [N x 3]
%     sats.lat_deg   [N x 1]
%     sats.lon_deg   [N x 1]
%     sats.alt_m     [N x 1]
%     sats.plane     [N x 1]
%     sats.inPlane   [N x 1]
%     sats.id        [N x 1]
%
%   meta struct:
%     meta.tUTC, meta.thetaGMST_rad, meta.nTotal
%     meta.idxVisible (if gs provided)
% ============================================================

% -------- defaults ----------
if ~isfield(cfg,'alt_km'),       cfg.alt_km = 1200; end
if ~isfield(cfg,'nPlanes'),      cfg.nPlanes = 36; end
if ~isfield(cfg,'satsPerPlane'), cfg.satsPerPlane = 49; end
if ~isfield(cfg,'inc_deg'),      cfg.inc_deg = 87.9; end
if ~isfield(cfg,'ecc'),          cfg.ecc = 0; end
if ~isfield(cfg,'argp_deg'),     cfg.argp_deg = 0; end
if ~isfield(cfg,'raan0_deg'),    cfg.raan0_deg = 0; end
if ~isfield(cfg,'M0_deg'),       cfg.M0_deg = 0; end
if ~isfield(cfg,'walkerF'),      cfg.walkerF = 1; end

if ~isa(tUTC,'datetime')
    error("tUTC must be a datetime in UTC, e.g., datetime(2026,1,1,0,0,0,'TimeZone','UTC')");
end
if isempty(tUTC.TimeZone)
    tUTC.TimeZone = 'UTC';
end

% -------- constants ----------
mu = 3.986004418e14;     % Earth GM [m^3/s^2]
Re = 6378137.0;          % WGS84 semi-major [m]
we = 7.2921150e-5;       % Earth rot [rad/s]
f  = 1/298.257223563;    % flattening
e2 = f*(2-f);

alt_m = cfg.alt_km * 1000;
a = Re + alt_m;          % circular orbit radius approx [m]
n = sqrt(mu / a^3);      % mean motion [rad/s]

% -------- time -> seconds since epoch0 (we define epoch0 at J2000) ----------
% Use a simple J2000-based GMST approximation for ECI->ECEF rotation.
% It's good enough for snapshot geometry replication.
tJ2000 = datetime(2000,1,1,12,0,0,'TimeZone','UTC'); % J2000
dt_sec = seconds(tUTC - tJ2000);

thetaGMST = gmst_approx(dt_sec); % rad

% -------- build Walker-star ----------
P = cfg.nPlanes;
S = cfg.satsPerPlane;
F = cfg.walkerF;

inc = deg2rad(cfg.inc_deg);
argp = deg2rad(cfg.argp_deg);
raan0 = deg2rad(cfg.raan0_deg);
M0 = deg2rad(cfg.M0_deg);

Ntot = P*S;

r_eci = zeros(Ntot,3);
r_ecef = zeros(Ntot,3);
lat = zeros(Ntot,1);
lon = zeros(Ntot,1);
alt = zeros(Ntot,1);
plane = zeros(Ntot,1);
inPlane = zeros(Ntot,1);
sid = (1:Ntot)';

k = 0;
for p = 0:(P-1)
    % RAAN equally spaced
    RAAN = raan0 + 2*pi*(p/P);

    for sIdx = 0:(S-1)
        k = k + 1;

        % Walker phasing: shift mean anomaly between planes
        % classic: M = M0 + 2π*(s/S) + 2π*(F*p/(P*S))
        M = M0 + 2*pi*(sIdx/S) + 2*pi*(F*p/(P*S));

        % propagate mean anomaly at time t
        M_t = wrapTo2Pi(M + n*dt_sec);

        % circular => true anomaly = mean anomaly
        nu = M_t;

        % position in perifocal frame
        r_pf = [a*cos(nu); a*sin(nu); 0];

        % rotation: perifocal -> ECI
        R = R3(RAAN) * R1(inc) * R3(argp);
        r_i = (R * r_pf).'; % row vector

        % ECI -> ECEF (rotate about Z by GMST)
        r_e = (R3(-thetaGMST) * r_i.').';

        % ECEF -> lat/lon/alt (WGS84 iterative)
        [lat_k, lon_k, alt_k] = ecef2lla_wgs84(r_e(1), r_e(2), r_e(3), Re, e2);

        r_eci(k,:) = r_i;
        r_ecef(k,:) = r_e;
        lat(k) = lat_k;
        lon(k) = lon_k;
        alt(k) = alt_k;

        plane(k) = p+1;
        inPlane(k) = sIdx+1;
    end
end

sats.r_eci_m  = r_eci;
sats.r_ecef_m = r_ecef;
sats.lat_deg  = lat;
sats.lon_deg  = lon;
sats.alt_m    = alt;
sats.plane    = plane;
sats.inPlane  = inPlane;
sats.id       = sid;

meta.tUTC = tUTC;
meta.thetaGMST_rad = thetaGMST;
meta.nTotal = Ntot;

% -------- optional: filter visible satellites to a GS ----------
if nargin >= 3 && ~isempty(gs)
    if ~isfield(gs,'alt_m'), gs.alt_m = 0; end
    if ~isfield(gs,'minEl_deg'), gs.minEl_deg = 0; end

    idxVis = visible_to_gs(sats.r_ecef_m, gs.lat_deg, gs.lon_deg, gs.alt_m, gs.minEl_deg, Re, e2);

    meta.idxVisible = idxVis;

    % overwrite sats to visible only (so Step 3/4 will be fast)
    sats = subset_sats(sats, idxVis);
end

fprintf("Step2 snapshot generated: %d satellites", meta.nTotal);
if isfield(meta,'idxVisible')
    fprintf(" | visible to GS: %d\n", numel(meta.idxVisible));
else
    fprintf("\n");
end

end

% ================= helpers =================

function th = gmst_approx(dt_sec)
% Simple linear approximation of Earth rotation relative to J2000.
% th = omega * dt  (good enough for snapshot geometry)
we = 7.2921150e-5;
th = mod(we*dt_sec, 2*pi);
end

function R = R1(a)
R = [1 0 0; 0 cos(a) -sin(a); 0 sin(a) cos(a)];
end

function R = R3(a)
R = [cos(a) -sin(a) 0; sin(a) cos(a) 0; 0 0 1];
end

function [lat_deg, lon_deg, alt_m] = ecef2lla_wgs84(x, y, z, Re, e2)
% Iterative conversion ECEF->geodetic (WGS84)
lon = atan2(y, x);
p = hypot(x,y);
lat = atan2(z, p*(1-e2));
for it = 1:7
    N = Re / sqrt(1 - e2*sin(lat)^2);
    alt_m = p/cos(lat) - N;
    lat = atan2(z, p*(1 - e2*N/(N+alt_m)));
end
lat_deg = rad2deg(lat);
lon_deg = rad2deg(lon);
end

function idx = visible_to_gs(r_ecef, gsLat_deg, gsLon_deg, gsAlt_m, minEl_deg, Re, e2)
% visibility by elevation angle > minEl
% compute GS ECEF
[gsx, gsy, gsz] = lla2ecef_wgs84(gsLat_deg, gsLon_deg, gsAlt_m, Re, e2);
gs = [gsx gsy gsz];

% ENU basis at GS
lat = deg2rad(gsLat_deg);
lon = deg2rad(gsLon_deg);
E = [-sin(lon)  cos(lon) 0];
N = [-sin(lat)*cos(lon) -sin(lat)*sin(lon) cos(lat)];
U = [ cos(lat)*cos(lon)  cos(lat)*sin(lon) sin(lat)];

rho = r_ecef - gs; % [N x 3]
e = rho*E.';
n = rho*N.';
u = rho*U.';

el = atan2d(u, hypot(e,n));
idx = find(el >= minEl_deg);
end

function [x,y,z] = lla2ecef_wgs84(lat_deg, lon_deg, alt_m, Re, e2)
lat = deg2rad(lat_deg);
lon = deg2rad(lon_deg);
N = Re / sqrt(1 - e2*sin(lat)^2);
x = (N+alt_m)*cos(lat)*cos(lon);
y = (N+alt_m)*cos(lat)*sin(lon);
z = (N*(1-e2)+alt_m)*sin(lat);
end

function s2 = subset_sats(s, idx)
fields = fieldnames(s);
for k = 1:numel(fields)
    v = s.(fields{k});
    if isnumeric(v) && size(v,1) == numel(s.id)
        s2.(fields{k}) = v(idx,:);
    else
        s2.(fields{k}) = v; % keep unchanged
    end
end
end
