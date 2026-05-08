function P = paper_params(beam_model)
% ============================================================
% paper_params
% 论文参数定义（基于 "Joint Power and Tilt Control in Satellite 
% Constellation for NGSO-GSO Interference Mitigation" OJVT 2023)
%
% 对应论文 Table 1
% ============================================================

%% ========== 物理常数 ==========
P.kB = 1.380649e-23;  % 玻尔兹曼常数 (J/K)
P.Re_km = 6378.137;    % 地球半径 (km)

%% ========== 频率和波长 ==========
% 根据论文 Table 1
freq_GHz = 19.7;      % 载波频率 (GHz) - 论文 Table 1
P.lambda = 3e8 / (freq_GHz * 1e9);  % 波长 (m)
P.freq_GHz = freq_GHz;

%% ========== 带宽 ==========
P.B_Hz = 200e6;       % 系统带宽 200 MHz - 论文 Table 1
P.BWref_Hz = 4e4;     % EPFD 参考带宽 40 kHz

%% ========== 天线参数 ==========
% LEO 卫星发射天线 - 论文 Table 1
P.LEO_Gmax_dBi = 39.6;  % 最大增益 (dBi) - 论文 Table 1
% 根据增益反推天线直径（如果需要）
% G_max = 20*log10(D/λ) + 7.7 (论文 Eq.7)
% D = λ * 10^((G_max - 7.7)/20)
P.LEO_D_m = P.lambda * 10^((P.LEO_Gmax_dBi - 7.7)/20);

% GSO 地面站接收天线 - 论文 Table 1
P.GSO_Gmax_dBi = 40.95;  % 最大增益 (dBi) - 论文 Table 1
P.D_ref_m = 0.6;      % 参考天线直径 60 cm = 0.6 m - 论文 Table 1
% 验证：根据直径计算的增益应该接近 40.95 dBi
% G_max = 20*log10(D/λ) + 7.7 (论文 Eq.9)
GSO_Gcalc_dBi = 20*log10(P.D_ref_m/P.lambda) + 7.7;
if abs(GSO_Gcalc_dBi - P.GSO_Gmax_dBi) > 1
    warning('GSO 增益计算值 (%.2f dBi) 与论文值 (%.2f dBi) 不一致', ...
        GSO_Gcalc_dBi, P.GSO_Gmax_dBi);
end

% LEO 用户地面站接收天线 - 论文 Table 1
P.GS_LEO_Gmax_dBi = 40.95;  % 最大增益 (dBi) - 论文 Table 1
P.user_D_m = 0.6;     % 用户天线直径 (m) - 假设与 GSO 相同 (60 cm)

% ========== Beam / 覆盖参数（用于用户生成与换手） ==========
% 论文中明确假设（Simulation 部分）：
% - LEO satellites are nadir-pointing and have a single beam
% - transmit antenna half 3 dB beamwidth = 13.9 degrees
%
% 为了严格对齐论文：用户生成、覆盖判定、换手候选筛选一律使用此 half-3dB 值。
if nargin < 1 || isempty(beam_model)
    beam_model = 'paper';
end
P.beam_model = beam_model;

P.leo_half_3dB_deg_paper = 13.9; % deg, paper assumption (off-nadir half 3 dB)

% OneWeb public filing (FCC SAT-LOI-20160428-00041 Attachment A):
% states aggregate Ku-band beam coverage per satellite is ~1140 km x 1140 km.
% We approximate an "effective" single-beam off-nadir half-angle that reaches
% half-size 570 km at h=1200 km, yielding ~26.4 deg.
P.oneweb_footprint_halfsize_km = 570;     % km (1140/2)
P.oneweb_alt_km_nominal = 1200;           % km (filing: altitude 1,200 km)
P.leo_half_3dB_deg_oneweb_fcc = oneweb_offnadir_halfangle_deg(P.Re_km, P.oneweb_alt_km_nominal, P.oneweb_footprint_halfsize_km);

switch lower(string(beam_model))
    case "paper"
        P.leo_half_3dB_deg = P.leo_half_3dB_deg_paper;
    case "oneweb_fcc"
        P.leo_half_3dB_deg = P.leo_half_3dB_deg_oneweb_fcc;
    otherwise
        warning('Unknown beam_model="%s". Falling back to paper.', beam_model);
        P.leo_half_3dB_deg = P.leo_half_3dB_deg_paper;
end

P.hpbw_deg = 2 * P.leo_half_3dB_deg; % full 3 dB beamwidth (deg)

% 备注：若要用口径推回 HPBW，可用下式（度）。但该值通常远小于 13.9°，
% 与论文的“覆盖/单波束”假设不一致，因此这里只保留作参考，不用于仿真/换手。
P.hpbw_from_dish_deg = 2 * asind(1.391 * P.lambda / (pi * P.LEO_D_m));  % deg

%% ========== 功率参数 ==========
P.Pmax_W = 10.0;      % 最大发射功率 (W) - 论文 Table 1: 10 dBW = 10 W
P.Pmin_W = 1e-6;      % 最小发射功率 (W) - 数值稳定性

%% ========== Tilt 参数 ==========
P.theta_max_deg = 10.0;  % 最大 tilt 角度 (度) - 论文 Table 1
% 天线增益系数 - 论文 Table 1
P.A_fit = 1.0632e+04;    % 近似天线增益系数 A (线性值)
P.beta_fit = -0.0671;    % 近似天线增益系数 β (1/deg) - 论文 Table 1
                            % 注意：这是负值，表示 tilt 会降低增益
                            % 增益模型：G^r(φ^r) = A exp(βφ^r) (论文 Eq.13)

%% ========== EPFD 约束 ==========
% 论文 Table 1: EPFD limit = -173.4 dB(W/m²/1MHz)
% Convert to current BWref_Hz (dB(W/m²/BWref_Hz)).
P.EPFD_thr_1MHz_dB = -173.4;
P.EPFD_thr_dB = P.EPFD_thr_1MHz_dB - 10*log10(1e6 / P.BWref_Hz);

%% ========== 噪声参数 ==========
P.user_noise_temp_K = 240;  % 用户接收机噪声温度 (K) - 论文 Table 1
P.GSO_noise_temp_K = 240;   % GSO 地面站噪声温度 (K) - 论文 Table 1

%% ========== 可见性参数 ==========
P.min_elev_deg = 10.0;  % 最小仰角 (度) - 论文 Table 1

%% ========== Algorithm 1 参数 ==========
P.zeta_thr = 0.7;  % 关键卫星识别阈值 - 论文 Algorithm 1 Step 4
                    % 归一化贡献 >= zeta_thr 的卫星被认为是关键卫星

%% ========== 验证参数合理性 ==========
% 检查关键参数
assert(P.Pmax_W > 0, 'Pmax_W 必须 > 0');
assert(P.theta_max_deg > 0 && P.theta_max_deg <= 10, 'theta_max_deg 应在合理范围内');
assert(P.EPFD_thr_dB < 0, 'EPFD_thr_dB 应为负值');
assert(P.zeta_thr > 0 && P.zeta_thr <= 1, 'zeta_thr 应在 [0, 1] 范围内');
assert(P.min_elev_deg > 0 && P.min_elev_deg < 90, 'min_elev_deg 应在 (0, 90) 范围内');

fprintf('[paper_params] 参数加载完成（基于论文 Table 1）\n');
fprintf('  频率: %.1f GHz, 波长: %.4f m\n', P.freq_GHz, P.lambda);
fprintf('  带宽: %.0f MHz, EPFD 阈值: %.1f dB\n', P.B_Hz/1e6, P.EPFD_thr_dB);
fprintf('  最大功率: %.1f W (%.1f dBW), 最大 tilt: %.1f deg\n', ...
    P.Pmax_W, 10*log10(P.Pmax_W), P.theta_max_deg);
fprintf('  LEO 增益: %.1f dBi, GSO 增益: %.1f dBi\n', ...
    P.LEO_Gmax_dBi, P.GSO_Gmax_dBi);
fprintf('  天线系数: A = %.4e, β = %.4f\n', P.A_fit, P.beta_fit);
fprintf('  参考天线直径: %.1f m\n', P.D_ref_m);
fprintf('  LEO half-3dB beamwidth: %.2f deg (model=%s), HPBW: %.2f deg\n', ...
    P.leo_half_3dB_deg, string(P.beam_model), P.hpbw_deg);
fprintf('  OneWeb effective half-3dB (FCC 1140km footprint @1200km): %.2f deg\n', ...
    P.leo_half_3dB_deg_oneweb_fcc);
fprintf('  HPBW (from dish, ref only): %.2f deg\n', P.hpbw_from_dish_deg);
fprintf('  zeta_thr: %.2f\n', P.zeta_thr);

end

function alpha_deg = oneweb_offnadir_halfangle_deg(Re_km, h_km, ground_offset_km)
% Compute off-nadir half-angle alpha (deg) that reaches a ground point
% at central-angle psi = ground_offset/Re, for a satellite at radius r=Re+h.
% Geometry uses triangle (Earth center O, satellite S, ground point G).

r_km = Re_km + h_km;
psi = ground_offset_km / Re_km; % rad
% slant range SG
d2 = r_km^2 + Re_km^2 - 2*r_km*Re_km*cos(psi);
d = sqrt(max(d2, 0));
% angle at satellite between vector to Earth center and vector to ground point
cos_alpha = (r_km^2 + d^2 - Re_km^2) / max(2*r_km*d, 1e-12);
cos_alpha = max(-1, min(1, cos_alpha));
alpha_deg = acosd(cos_alpha);
end