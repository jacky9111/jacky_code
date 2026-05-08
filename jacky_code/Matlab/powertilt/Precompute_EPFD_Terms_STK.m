function E = Precompute_EPFD_Terms_STK(LEO_data, visIdx, GS_data, GEO_data, P)
% ============================================================
% Precompute_EPFD_Terms_STK
% 基于 STK 数据计算 EPFD 相关项（论文 Eq.(17)）
%
% 根据论文 Eq.(17):
% gamma_i = (A * G_G^r(φ_i^r) * exp(β * φ'_i)) / (BW_ref * 4π * d_i^2 * G_Gmax)
%
% 关键实现选择（用于对齐论文 Figure 14 的行为）：
% - GSO 接收天线方向图使用 φ_i^r（地面站离轴角，phi_r）
% - LEO 发射天线近似方向图（A*exp(β*·)）应使用发射端离轴角 φ'_i
%   在本项目中，我们用 sat->GS 的离轴角（从卫星 nadir 方向量测）作为 φ'_i，即 phi_t
%
% 经验验证：若将 exp(β*·) 错用为 phi_r，会导致即使 phi_r 很大（卫星远离正上方），
% 单颗卫星在 Pmax 下仍常常 EPFD 违规，从而 Figure 14(c) 变成整段都为 1。
% ============================================================

N = numel(visIdx);

% 如果有多个 GS，使用第一个（或可以扩展为处理多个）
gs_idx = 1;
r_gs = GS_data.pos_ecef_km(:, gs_idx) * 1000;  % m
r_gso = GEO_data.pos_ecef_km(:, gs_idx) * 1000;  % m

% GS boresight vector: GS -> GSO
v_bore = (r_gso - r_gs);

% EPFD threshold (线性值)
EPFD_thr_lin_1MHz = 10^(P.EPFD_thr_dB/10);
BWref_Hz = P.BWref_Hz;

% GSO 最大增益（线性值）
G_Gmax_lin = 10^(P.GSO_Gmax_dBi/10);

% 初始化数组
phi_t = zeros(N,1);
phi_r = zeros(N,1);
d_m = zeros(N,1);
gamma_base = zeros(N,1);
elev_gs_deg = zeros(N,1);

for k = 1:N
    idx = visIdx(k);
    r_sat = LEO_data.pos_ecef_km(:, idx) * 1000;  % m
    
    % sat -> GS vector
    v_ls = (r_gs - r_sat);
    d_m(k) = norm(v_ls);
    
    % GS elevation angle to LEO (deg)
    % If satellite is below GS horizon (elev <= 0), it should not contribute
    % to EPFD at the GSO ground station (blocked by Earth). We therefore set
    % gamma_base = 0 for elev <= 0, even if we keep it in the optimization set.
    v_gs_to_leo = (r_sat - r_gs);
    zenith_gs = r_gs / norm(r_gs);
    ang_gs = acosd( max(-1, min(1, dot(v_gs_to_leo, zenith_gs) / (norm(v_gs_to_leo)*norm(zenith_gs))) ) );
    elev_gs_deg(k) = 90 - ang_gs;
    
    % sat nadir direction (sat -> Earth center)
    v_nadir = -r_sat;
    
    % phi_t: angle between nadir and sat->GS
    % 这是卫星到 GS 的离轴角（从卫星 nadir 方向）
    phi_t(k) = angle_deg(v_nadir, v_ls);
    
    % phi_r: angle at GS between boresight(GS->GSO) and GS->LEO
    % 这是 GS 到 LEO 的离轴角（从 GS boresight 方向）
    phi_r(k) = angle_deg(v_bore, v_gs_to_leo);
    
    % GSO 地面站接收增益 G_G^r(φ_i^r) - 使用 ITU-R S.1428-1
    % 重要：`gso_rx_gain_itu1428` 依照 ITU-R S.1428-1 / 论文 Eq.(9) 输出的是「绝对增益」
    % （单位 dBi，主瓣为 G_max_dB），因此这里不要再乘一次 G_Gmax，否则会 double-count。
    GGr_abs_dB = gso_rx_gain_itu1428(phi_r(k), P.D_ref_m, P.lambda);
    GGr_abs_lin = 10^(GGr_abs_dB/10);
    
    % gamma_base（用于 EPFD 约束的预计算常数）
    % 采用：GSO 接收增益使用 phi_r；LEO 发射端近似方向图使用 phi_t
    %
    % 令：
    %   gamma_base_i = (A * G_G^r(phi_r_i) * exp(beta * phi_t_i)) / (BW_ref * 4π * d_i^2 * G_Gmax)
    %
    % 则 EPFD 约束可写为：
    %   sum_i gamma_base_i * exp(q_i) * exp(beta * theta_i) <= EPFD_thr_lin
    if elev_gs_deg(k) <= 0
        gamma_base(k) = 0;
    else
        gamma_base(k) = (P.A_fit * GGr_abs_lin * exp(P.beta_fit * phi_t(k))) / ...
                        (BWref_Hz * 4*pi*d_m(k)^2 * G_Gmax_lin);
    end
end

% 输出结构
E.N = N;
E.phi_t_deg = phi_t;
E.phi_r_deg = phi_r;
E.d_m = d_m;
E.gamma_base = gamma_base;
E.EPFD_thr_lin = EPFD_thr_lin_1MHz;
E.elev_gs_deg = elev_gs_deg;

end

function ang = angle_deg(a, b)
% 计算两个向量之间的角度（度）
ang = acosd( max(-1, min(1, dot(a, b)/(norm(a)*norm(b))) ) );
end