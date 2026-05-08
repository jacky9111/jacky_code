function users = Make_Users_For_Visible_Sats_STK(LEO_data, visIdx, GS_data, U, P)
% ============================================================
% Make_Users_For_Visible_Sats_STK
% 为可见的 LEO 卫星生成用户位置（在覆盖区域内）
%
% INPUTS:
%   LEO_data : struct from Extract_Positions_From_STK
%   visIdx   : indices of visible LEOs
%   GS_data  : struct from Extract_Positions_From_STK
%   U        : number of users per satellite
%   P        : parameters struct
%
% OUTPUTS:
%   users    : struct with fields
%       .lat_deg : [U*Nvis x 1] latitudes
%       .lon_deg : [U*Nvis x 1] longitudes
%       .sat_k   : [U*Nvis x 1] satellite index (into visIdx)
% ============================================================

Nvis = numel(visIdx);
tot = U * Nvis;

lat = zeros(tot, 1);
lon = zeros(tot, 1);
sat_k = zeros(tot, 1);

% 覆盖半角：采用参数中的 half 3 dB beamwidth（单位：deg，定义为 off-nadir 半角）
% （不要使用 STK sensor；STK 仅用于位置）
halfCone = P.leo_half_3dB_deg;

t = 0;
for k = 1:Nvis
    idx = visIdx(k);
    r_sat_km = LEO_data.pos_ecef_km(:, idx);
    
    % Sample random points within an off-nadir cone, intersect with Earth sphere
    for u = 1:U
        t = t + 1;
        [r_user_km, ok] = sample_user_on_earth_in_cone(r_sat_km, halfCone, P.Re_km);
        if ~ok
            % Fallback: just use sub-satellite point if intersection failed
            r_user_km = P.Re_km * (r_sat_km / max(norm(r_sat_km), 1e-12));
        end
        [lat(t), lon(t)] = ecef_to_latlon_deg(r_user_km);
        sat_k(t) = k;
    end
end

users.lat_deg = lat;
users.lon_deg = lon;
users.sat_k = sat_k;

fprintf('生成了 %d 个用户 (%d 个/卫星)\n', tot, U);

end

% ============================================================
% Helpers
% ============================================================
function [r_user_km, ok] = sample_user_on_earth_in_cone(r_sat_km, halfCone_deg, Re_km)
ok = false;
r_user_km = [NaN; NaN; NaN];

if any(~isfinite(r_sat_km)) || norm(r_sat_km) < Re_km
    return;
end

u_nadir = -r_sat_km / norm(r_sat_km); % unit vector pointing to Earth center

% Build orthonormal basis around u_nadir
ref = [0; 0; 1];
if abs(dot(ref, u_nadir)) > 0.95
    ref = [0; 1; 0];
end
u1 = cross(ref, u_nadir);
u1 = u1 / max(norm(u1), 1e-12);
u2 = cross(u_nadir, u1);

% Uniform in solid angle within cone: cos(alpha) uniform in [cos(a_max), 1]
a_max = deg2rad(max(0, halfCone_deg));
ca = 1 - rand() * (1 - cos(a_max));
sa = sqrt(max(0, 1 - ca^2));
az = 2*pi*rand();

dir = ca*u_nadir + sa*(cos(az)*u1 + sin(az)*u2); % unit vector from sat towards Earth

% Ray-sphere intersection: |r_sat + t*dir| = Re
a = dot(dir, dir);
b = 2*dot(r_sat_km, dir);
c = dot(r_sat_km, r_sat_km) - Re_km^2;
disc = b^2 - 4*a*c;
if disc < 0
    return;
end
t1 = (-b - sqrt(disc)) / (2*a);
t2 = (-b + sqrt(disc)) / (2*a);
% Choose smallest positive root
tt = [t1 t2];
tt = tt(tt > 0);
if isempty(tt)
    return;
end
tmin = min(tt);

r_user_km = r_sat_km + tmin*dir;
ok = all(isfinite(r_user_km)) && abs(norm(r_user_km) - Re_km) < 1e-2;
end

function [lat_deg, lon_deg] = ecef_to_latlon_deg(r_km)
x = r_km(1); y = r_km(2); z = r_km(3);
lon_deg = atan2d(y, x);
lat_deg = asind(z / max(norm(r_km), 1e-12));
lon_deg = wrapTo180(lon_deg);
end