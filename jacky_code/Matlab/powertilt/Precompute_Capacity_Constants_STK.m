function Kc = Precompute_Capacity_Constants_STK(LEO_data, visIdx, users, GS_data, GEO_data, P)
% ============================================================
% Precompute_Capacity_Constants_STK
% 基于 STK 数据计算容量常数（论文 Eq.(15)）
% 支持从STK读取的用户（每个卫星用户数可能不同）
% ============================================================

Nvis = numel(visIdx);

% 检查用户是否从STK读取（有sat_k字段）
if isfield(users, 'sat_k')
    % 从STK读取：每个卫星的用户数可能不同
    U_per_sat = zeros(Nvis, 1);
    for k = 1:Nvis
        U_per_sat(k) = sum(users.sat_k == k);
    end
    U_max = max(U_per_sat);
    
    k = zeros(U_max, Nvis);
    v = zeros(U_max, Nvis);
    s = zeros(U_max, Nvis);
    
    N0 = P.kB * P.user_noise_temp_K;  % W/Hz
    
    for kk = 1:Nvis
        idx = visIdx(kk);
        r_sat = LEO_data.pos_ecef_km(:, idx);  % km
        
        % 找到属于这个卫星的用户
        user_indices = find(users.sat_k == kk);
        U_actual = length(user_indices);
        
        for u = 1:U_actual
            user_idx = user_indices(u);
            user_pos = latlon_to_ecef(users.lat_deg(user_idx), users.lon_deg(user_idx), P.Re_km);
            
            d_su_m = norm((r_sat - user_pos)) * 1000;  % m
            
            % User receive gain (max gain)
            Gur_lin = 10^(P.GS_LEO_Gmax_dBi/10);
            
            % k contains A*Gur*lambda^2/(4*pi*r)^2
            k(u, kk) = (P.A_fit * Gur_lin * (P.lambda^2)) / ((4*pi*d_su_m)^2);
            
            % GSO interference at user (simplified as 0)
            Pg_hgu2 = 0;
            v(u, kk) = Pg_hgu2 + N0*P.B_Hz;
            
            % sign: if user north of subsat, tilting north reduces off-boresight
            sat_lat = LEO_data.sub_lat_deg(idx);
            s(u, kk) = sign(users.lat_deg(user_idx) - sat_lat);
            if s(u, kk) == 0
                s(u, kk) = 1;
            end
        end
    end
    
    Kc.U = U_max;  % 最大用户数
    Kc.U_per_sat = U_per_sat;  % 每个卫星的实际用户数
    
else
    % 生成的用户：每个卫星用户数相同
    U = numel(users.lat_deg) / Nvis;
    
    k = zeros(U, Nvis);
    v = zeros(U, Nvis);
    s = zeros(U, Nvis);
    
    N0 = P.kB * P.user_noise_temp_K;  % W/Hz
    
    for kk = 1:Nvis
        idx = visIdx(kk);
        r_sat = LEO_data.pos_ecef_km(:, idx);  % km
        
        for u = 1:U
            user_idx = (kk-1)*U + u;
            user_pos = latlon_to_ecef(users.lat_deg(user_idx), users.lon_deg(user_idx), P.Re_km);
            
            d_su_m = norm((r_sat - user_pos)) * 1000;  % m
            
            % User receive gain (max gain)
            Gur_lin = 10^(P.GS_LEO_Gmax_dBi/10);
            
            % k contains A*Gur*lambda^2/(4*pi*r)^2
            k(u, kk) = (P.A_fit * Gur_lin * (P.lambda^2)) / ((4*pi*d_su_m)^2);
            
            % GSO interference at user (simplified as 0)
            Pg_hgu2 = 0;
            v(u, kk) = Pg_hgu2 + N0*P.B_Hz;
            
            % sign: if user north of subsat, tilting north reduces off-boresight
            sat_lat = LEO_data.sub_lat_deg(idx);
            s(u, kk) = sign(users.lat_deg(user_idx) - sat_lat);
            if s(u, kk) == 0
                s(u, kk) = 1;
            end
        end
    end
    
    Kc.U = U;
    Kc.U_per_sat = repmat(U, Nvis, 1);
end

Kc.k = k;
Kc.v = v;
Kc.s = s;
Kc.Nvis = Nvis;

end

function r = latlon_to_ecef(lat_deg, lon_deg, r_km)
lat = deg2rad(lat_deg);
lon = deg2rad(lon_deg);
r = [r_km*cos(lat)*cos(lon); r_km*cos(lat)*sin(lon); r_km*sin(lat)];
end