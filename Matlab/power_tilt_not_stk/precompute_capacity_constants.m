function Kc = precompute_capacity_constants(LEO, visIdx, users, gs, gso, P)
% Build constants for convex capacity expression (paper Eq.(15)):
% C = B*log2(1 + (k_i,u * exp(q_i + beta*s_i,u*theta_i))/v_u )
%
% We keep it faithful but simplified:
% - ignore inter-LEO interference (paper mentions reuse schemes making it negligible)
% - include GSO->user interference term in v_u (can be kept small or computed)

Nvis = numel(visIdx);
U = numel(users.lat_deg)/Nvis;

k = zeros(U, Nvis);
v = zeros(U, Nvis);
s = zeros(U, Nvis); % sign wrt tilting direction relative to user latitude (north-south)

% noise
N0 = P.kB * P.user_noise_temp_K;  % W/Hz

for kk=1:Nvis
    i = visIdx(kk);
    r_sat = LEO.pos_ecef_km(:,i);

    for u=1:U
        idx = (kk-1)*U + u;
        user_pos = latlon_to_ecef(users.lat_deg(idx), users.lon_deg(idx), P.Re_km);

        d_su_m = norm((r_sat - user_pos))*1000;

        % User receive gain: assume max gain (paper uses reference pattern, but for replication start with max)
        Gur_lin = 10^(P.GS_LEO_Gmax_dBi/10);

        % LEO tx gain uses exponential fit in objective:
        % k contains A*Gur*lambda^2/(4*pi*r)^2 as in paper definition
        k(u,kk) = (P.A_fit * Gur_lin * (P.lambda^2)) / ((4*pi*d_su_m)^2);

        % GSO interference at user: we keep it but simplified as small constant
        % You can later compute it using GSO EIRP etc if you model it.
        Pg_hgu2 = 0;

        v(u,kk) = Pg_hgu2 + N0*P.B_Hz;

        % sign: if user north of subsat, tilting north reduces off-boresight to user
        sat_lat = LEO.sub_lat_deg(i);
        s(u,kk) = sign(users.lat_deg(idx) - sat_lat);
        if s(u,kk)==0, s(u,kk)=1; end
    end
end

Kc.k = k;
Kc.v = v;
Kc.s = s;
Kc.U = U;
Kc.Nvis = Nvis;
end

function r = latlon_to_ecef(lat_deg, lon_deg, r_km)
lat = deg2rad(lat_deg); lon = deg2rad(lon_deg);
r = [r_km*cos(lat)*cos(lon); r_km*cos(lat)*sin(lon); r_km*sin(lat)];
end
