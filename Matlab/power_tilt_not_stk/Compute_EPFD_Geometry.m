function geom = Compute_EPFD_Geometry(satsVis, users, gs, geo)
% ============================================================
% Step 3 (Paper replication, no STK):
% Compute geometry for EPFD evaluation at a snapshot.
%
% INPUT
%   satsVis : struct from Step 2 (visible satellites only)
%             required fields:
%               - r_ecef_m [N x 3]
%               - id       [N x 1] (or [1 x N])
%             optional:
%               - lat_deg  [N x 1]
%               - lon_deg  [N x 1]
%
%   users   : struct array from Step 1 with fields:
%               - lat (deg)
%               - lon (deg)
%               - demand (optional)
%
%   gs      : struct with fields:
%               - lat_deg
%               - lon_deg
%               - alt_m (optional, default 0)
%
%   geo     : struct with fields:
%               - lon_deg (GEO on equator)
%               - alt_km (optional, default 35786)
%
% OUTPUT (arrays length N = numel(satsVis.id))
%   geom.d_gs_m(i)        : distance sat->GS (m)
%   geom.phi_t_deg(i)     : GS off-axis angle: angle( GS->GEO , GS->SAT ) (deg)
%   geom.phi_r_deg(i)     : sat off-axis angle: angle( SAT->USER , SAT->GS ) (deg)
%   geom.userIdx(i)       : served user index for sat i (nearest user)
%   geom.d_su_m(i)        : distance sat->served user (m)
%   geom.el_gs_deg(i)     : elevation of sat as seen by GS (deg)
%
% Notes:
% - Single-beam assumption: each visible sat serves ONE user (baseline).
% - Served user chosen as nearest (great-circle) among provided users.
% ============================================================

% --- constants WGS84 ---
Re = 6378137.0;
f  = 1/298.257223563;
e2 = f*(2-f);

if ~isfield(gs,'alt_m'), gs.alt_m = 0; end
if ~isfield(geo,'alt_km'), geo.alt_km = 35786; end

% Ensure column vector id
id = satsVis.id(:);
N = numel(id);

% --- GS ECEF (1x3) ---
r_gs = lla2ecef_wgs84_vec(gs.lat_deg, gs.lon_deg, gs.alt_m, Re, e2);

% --- GEO ECEF (1x3) ---
r_geo = lla2ecef_wgs84_vec(0, geo.lon_deg, geo.alt_km*1000, Re, e2);

% --- GS boresight direction (toward GEO) ---
u_gs_geo = unitvec(r_geo - r_gs);   % 1x3

% --- users: precompute ECEF for all (Ux3) ---
U = numel(users);
userLat = zeros(U,1);
userLon = zeros(U,1);
r_user  = zeros(U,3);

for u = 1:U
    userLat(u) = users(u).lat;
    userLon(u) = users(u).lon;
    r_user(u,:) = lla2ecef_wgs84_vec(users(u).lat, users(u).lon, 0, Re, e2);
end

% --- outputs ---
d_gs   = zeros(N,1);
phi_t  = zeros(N,1);
phi_r  = zeros(N,1);
uIdx   = zeros(N,1);
d_su   = zeros(N,1);
el_gs  = zeros(N,1);

% --- loop satellites ---
for i = 1:N
    r_sat = satsVis.r_ecef_m(i,:);     % 1x3

    % GS -> SAT
    v_gs_sat = r_sat - r_gs;          % 1x3
    u_gs_sat = unitvec(v_gs_sat);     % 1x3

    % distance sat->GS
    d_gs(i) = norm(v_gs_sat);

    % phi_t: angle between GS->GEO and GS->SAT
    phi_t(i) = ang_deg(u_gs_geo, u_gs_sat);

    % elevation at GS (sanity check)
    el_gs(i) = elevation_deg_from_gs(r_gs, r_sat, Re, e2);

    % -------- served user selection (nearest in great-circle) --------
    if isfield(satsVis,'lat_deg') && isfield(satsVis,'lon_deg')
        satLat = satsVis.lat_deg(i);
        satLon = satsVis.lon_deg(i);
    else
        [satLat, satLon] = ecef2ll_wgs84(r_sat(1), r_sat(2), r_sat(3), Re, e2);
    end

    [bestU, ~] = nearest_user_gc(satLat, satLon, userLat, userLon);
    uIdx(i) = bestU;

    % SAT -> USER (boresight baseline)
    v_sat_user = r_user(bestU,:) - r_sat;  % 1x3
    d_su(i) = norm(v_sat_user);
    u_sat_user = unitvec(v_sat_user);

    % SAT -> GS
    v_sat_gs = r_gs - r_sat;
    u_sat_gs = unitvec(v_sat_gs);

    % phi_r: angle between sat boresight (to user) and sat->GS
    phi_r(i) = ang_deg(u_sat_user, u_sat_gs);
end

% pack
geom.N = N;
geom.d_gs_m     = d_gs;
geom.phi_t_deg  = phi_t;
geom.phi_r_deg  = phi_r;
geom.userIdx    = uIdx;
geom.d_su_m     = d_su;
geom.el_gs_deg  = el_gs;

% quick sanity prints
fprintf("\n=== Step 3 Geometry Summary ===\n");
fprintf("Visible sats: %d\n", N);
fprintf("Elevation@GS: min=%.2f deg, max=%.2f deg\n", min(el_gs), max(el_gs));
fprintf("phi_t (GS off-axis): min=%.2f deg, max=%.2f deg\n", min(phi_t), max(phi_t));
fprintf("phi_r (sat off-axis): min=%.2f deg, max=%.2f deg\n\n", min(phi_r), max(phi_r));

end

% ======================== helpers ========================

function u = unitvec(v)
n = norm(v);
if n < 1e-12
    u = [0 0 0];
else
    u = v / n;
end
end

function a = ang_deg(u, v)
% angle between two vectors (deg)
% (works for 1x3 vectors)
c = dot(u, v);
c = max(-1, min(1, c));
a = acosd(c);
end

function el = elevation_deg_from_gs(r_gs, r_sat, Re, e2)
% compute elevation from GS to sat using ENU
[lat_deg, lon_deg] = ecef2ll_wgs84(r_gs(1), r_gs(2), r_gs(3), Re, e2);
lat = deg2rad(lat_deg);
lon = deg2rad(lon_deg);

E = [-sin(lon)  cos(lon) 0];
N = [-sin(lat)*cos(lon) -sin(lat)*sin(lon) cos(lat)];
U = [ cos(lat)*cos(lon)  cos(lat)*sin(lon) sin(lat)];

rho = r_sat - r_gs; % 1x3
e = dot(rho, E);
n = dot(rho, N);
u = dot(rho, U);

el = atan2d(u, hypot(e,n));
end

function r = lla2ecef_wgs84_vec(lat_deg, lon_deg, alt_m, Re, e2)
% Return ECEF as a single 1x3 vector (IMPORTANT for avoiding dot-size bugs)
lat = deg2rad(lat_deg);
lon = deg2rad(lon_deg);

N = Re / sqrt(1 - e2*sin(lat)^2);

x = (N + alt_m) * cos(lat) * cos(lon);
y = (N + alt_m) * cos(lat) * sin(lon);
z = (N*(1-e2) + alt_m) * sin(lat);

r = [x y z];
end

function [lat_deg, lon_deg] = ecef2ll_wgs84(x, y, z, Re, e2)
lon = atan2(y, x);
p = hypot(x, y);
lat = atan2(z, p*(1-e2));
for i = 1:7
    N = Re / sqrt(1 - e2*sin(lat)^2);
    alt = p/cos(lat) - N; %#ok<NASGU>
    lat = atan2(z, p*(1 - e2*N/(N+alt)));
end
lat_deg = rad2deg(lat);
lon_deg = rad2deg(lon);
end

function [bestIdx, bestDist] = nearest_user_gc(lat0, lon0, latArr, lonArr)
% nearest by great-circle distance (haversine), returns index
R = 6371e3; % meters
lat0r = deg2rad(lat0);
lon0r = deg2rad(lon0);
latr  = deg2rad(latArr(:));
lonr  = deg2rad(lonArr(:));

dlat = latr - lat0r;
dlon = lonr - lon0r;
a = sin(dlat/2).^2 + cos(lat0r).*cos(latr).*sin(dlon/2).^2;
c = 2*atan2(sqrt(a), sqrt(1-a));
dist = R*c;

[bestDist, bestIdx] = min(dist);
end
