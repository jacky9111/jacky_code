function [users_filtered, sat_k] = assign_users_to_satellites_limited(users, LEO_data, visIdx, U_max, P)
% ============================================================
% assign_users_to_satellites_limited
% 将用户分配到最近的卫星，但限制每个卫星最多 U_max 个用户
% 只选择距离最近的用户，并过滤掉超出覆盖范围的用户
%
% INPUTS:
%   users     : struct with .lat_deg, .lon_deg
%   LEO_data  : struct with .sub_lat_deg, .sub_lon_deg
%   visIdx    : indices of visible LEOs (into LEO_data)
%   U_max     : 每个卫星最多分配的用户数（如 5）
%   P         : parameters struct (使用 P.leo_half_3dB_deg 用于覆盖范围，论文假设)
%
% OUTPUTS:
%   users_filtered : struct with filtered users
%   sat_k          : [Nusers_filtered x 1] satellite index
% ============================================================

Nvis = numel(visIdx);
Nusers = length(users.lat_deg);

% 覆盖范围：off-nadir half 3 dB beamwidth（论文假设：13.9 deg，或你切换的 beam_model）
coverage_half_angle_deg = P.leo_half_3dB_deg;
min_user_elev_deg = P.min_elev_deg;

% 计算每个用户到每个卫星的 off-nadir 角（用作“距离”）并判定覆盖
off_deg = inf(Nusers, Nvis);
is_cov = false(Nusers, Nvis);
for u = 1:Nusers
    r_user = latlon_to_ecef_km(users.lat_deg(u), users.lon_deg(u), P.Re_km);
    for k = 1:Nvis
        leo_idx = visIdx(k);
        r_sat = LEO_data.pos_ecef_km(:, leo_idx);
        if any(~isfinite(r_sat)) || norm(r_sat) < 1
            continue;
        end
        [off_u, elev_u] = off_nadir_and_user_elev_deg(r_sat, r_user);
        off_deg(u, k) = off_u;
        is_cov(u, k) = (elev_u >= min_user_elev_deg) && (off_u <= coverage_half_angle_deg);
    end
end

% 为每个卫星选择最近的 U_max 个用户（在覆盖范围内）
selected_users = false(Nusers, 1);
sat_k_list = [];
user_indices = [];

for k = 1:Nvis
    % 找到在覆盖范围内的用户
    in_coverage = is_cov(:, k);
    
    % 获取这些用户的索引和距离
    candidate_indices = find(in_coverage & ~selected_users);
    candidate_distances = off_deg(candidate_indices, k);
    
    % 按距离排序，选择最近的 U_max 个
    [~, sort_idx] = sort(candidate_distances);
    n_select = min(U_max, length(candidate_indices));
    
    for i = 1:n_select
        u_idx = candidate_indices(sort_idx(i));
        selected_users(u_idx) = true;
        sat_k_list(end+1) = k;
        user_indices(end+1) = u_idx;
    end
end

% 构建过滤后的用户结构
users_filtered.lat_deg = users.lat_deg(user_indices);
users_filtered.lon_deg = users.lon_deg(user_indices);
if isfield(users, 'names')
    users_filtered.names = users.names(user_indices);
end
sat_k = sat_k_list(:);

% 统计信息
U_per_sat = zeros(Nvis, 1);
for k = 1:Nvis
    U_per_sat(k) = sum(sat_k == k);
end

fprintf('用户分配完成：\n');
fprintf('  原始用户数: %d\n', Nusers);
fprintf('  过滤后用户数: %d\n', length(user_indices));
fprintf('  每个卫星用户数: ');
for k = 1:Nvis
    fprintf('Sat %d: %d, ', k, U_per_sat(k));
end
fprintf('\n');

end

% ============================================================
% Helpers
% ============================================================
function r = latlon_to_ecef_km(lat_deg, lon_deg, Re_km)
lat = deg2rad(lat_deg);
lon = deg2rad(lon_deg);
r = [Re_km*cos(lat)*cos(lon); Re_km*cos(lat)*sin(lon); Re_km*sin(lat)];
end

function [off_deg, elev_u_deg] = off_nadir_and_user_elev_deg(r_sat_km, r_user_km)
v_nadir = -r_sat_km;
v_su = r_user_km - r_sat_km; % sat->user
off_deg = angle_deg(v_nadir, v_su);

% user elevation to sat
v_us = r_sat_km - r_user_km; % user->sat
zenith_u = r_user_km / norm(r_user_km);
ang = acosd( max(-1, min(1, dot(v_us, zenith_u) / (norm(v_us)*norm(zenith_u))) ) );
elev_u_deg = 90 - ang;
end

function ang = angle_deg(a, b)
ang = acosd( max(-1, min(1, dot(a, b)/(norm(a)*norm(b))) ) );
end