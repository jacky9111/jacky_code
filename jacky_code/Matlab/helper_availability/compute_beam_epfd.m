function epfd = compute_beam_epfd(pos_km, boresights, beamPower_W, P_gs_km, P_geo_km, P)
% compute_beam_epfd
% Beam-level EPFD contribution (linear, W/m^2/reference-bandwidth) from one
% satellite's beams to the ground station, using the SAME model as the rest
% of the thesis code (per-beam power model):
%
%   epfd_lin = (Pbeam_W / BWref) * (Gt / (4*pi*d^2)) * (Gr(alpha) / Gr_max)
%
% with the LEO transmit gain Gt = A_fit * exp(beta_fit * phi) (phi in deg is
% the off-boresight angle toward the GS) and the GSO receive gain from
% ITU-R S.1428 evaluated at the topocentric angle alpha between the LEO and
% the reference GSO as seen from the GS.
%
% Inputs:
%   pos_km      : 3x1 ECEF satellite position [km]
%   boresights  : 3 x Nbeam ECEF beam boresight unit vectors
%   beamPower_W : Nbeam x 1 per-beam transmit power [W] (0 => shut beam)
%   P_gs_km     : 3x1 ECEF ground-station position [km]
%   P_geo_km    : 3x1 ECEF reference GSO position [km]
%   P           : Ku EPFD parameter struct (ku_epfd_params)
%
% Output epfd:
%   epfd.beam_lin : Nbeam x 1 per-beam EPFD contribution [linear]
%   epfd.d_m      : slant distance GS<->satellite [m]
%   epfd.alpha_deg: topocentric LEO/GSO separation at GS [deg]
%
% Units: km in, m internally for the EPFD path term, deg for angles.
%
% 【中文說明】EPFD 計算的核心公式，論文全篇共用同一個模型：
%
%   epfd_lin = (Pbeam / BWref) × (Gt / (4πd²)) × (Gr(α) / Gr_max)
%
% 三個因子的物理意義：
%   Pbeam / BWref     該 beam 在參考頻寬（40 kHz）內的發射功率密度
%   Gt / (4πd²)       LEO 發射增益除以自由空間球面擴散 → 到達 GS 的功率通量密度
%                     Gt = A_fit × exp(beta_fit × φ)，φ 是「beam 指向」與
%                     「beam→GS 方向」的離軸角 [deg]（Jalali et al. 的近似式）
%   Gr(α) / Gr_max    GSO 地球站天線的歸一化接收增益，α 是從 GS 看出去
%                     「LEO」與「參考 GSO」之間的夾角（topocentric separation）
%                     增益模型採 ITU-R S.1428（gso_rx_gain_itu1428）
%
% α 越小代表 LEO 越接近 GS→GSO 的視線方向（近 in-line），Gr(α) 越大、干擾越嚴重，
% 這正是論文「critical period」的成因。
%
% 回傳的是「線性值」，因為 aggregate EPFD 必須在線性域相加，不能直接加 dB。

Nbeam = size(boresights, 2);
beamPower_W = beamPower_W(:);
pos_km = pos_km(:); P_gs_km = P_gs_km(:); P_geo_km = P_geo_km(:);

Gmax_lin = 10^(P.GSO_Gmax_dBi / 10);   % GSO 地球站最大接收增益（歸一化用）

beam_lin = zeros(Nbeam, 1);

v_gs_m = (P_gs_km - pos_km) * 1000;   % satellite -> GS vector [m]
d_m = norm(v_gs_m);                   % 斜距 [m]

% Topocentric angle between the LEO and the reference GSO as seen from GS.
% 從 GS 看出去，LEO 與參考 GSO 的夾角 α —— 決定接收天線旁瓣增益
alpha_deg = angle_deg(pos_km - P_gs_km, P_geo_km - P_gs_km);
Gr_dBi = gso_rx_gain_itu1428(alpha_deg, P.GSO_D_m, P.lambda_m);
Gr_lin = 10^(Gr_dBi / 10);

if d_m >= 1
    d_hat = v_gs_m / d_m;
    for b = 1:Nbeam
        if beamPower_W(b) <= 0
            continue;      % 功率為 0 = 該 beam 已被關閉，不貢獻干擾
        end
        % 離軸角 φ：beam 指向 vs. beam 到 GS 的方向
        phit_deg = angle_deg(boresights(:, b), d_hat);
        Gt_lin = max(P.A_fit * exp(P.beta_fit * phit_deg), 1e-30);   % LEO 發射增益
        beam_lin(b) = (beamPower_W(b) / P.BWref_Hz) * ...
            (Gt_lin / (4 * pi * d_m^2)) * (Gr_lin / Gmax_lin);
    end
end

epfd = struct();
epfd.beam_lin  = beam_lin;
epfd.d_m       = d_m;
epfd.alpha_deg = alpha_deg;
end

function a = angle_deg(x, y)
a = acosd(max(-1, min(1, dot(x, y) / (norm(x) * norm(y) + eps))));
end
