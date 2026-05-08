function G_dB = gso_rx_gain_itu1428(phi_deg, D_m, lambda_m)
% ============================================================
% gso_rx_gain_itu1428
% ITU-R S.1428-1 天线方向图模型（GSO 地面站接收天线）
%
% 根据论文中的 Eq.(9) 和 ITU-R S.1428-1
% ============================================================

% 计算最大增益
G_max_dB = 20*log10(D_m/lambda_m) + 7.7;

% 计算边界角度
psi_m_deg = (20 * lambda_m / D_m) * sqrt(G_max_dB - (29 - 25*log10(95*lambda_m/D_m)));
G_1_dB = 29 - 25*log10(95*lambda_m/D_m);

% 分段函数
if phi_deg <= psi_m_deg
    % 主瓣区域
    G_dB = G_max_dB - 0.0025 * (phi_deg * D_m / lambda_m)^2;
elseif phi_deg <= 95*lambda_m/D_m
    % 第一副瓣区域
    G_dB = G_1_dB;
elseif phi_deg <= 33.1
    % 第二副瓣区域
    G_dB = 29 - 25*log10(phi_deg);
elseif phi_deg <= 80
    % 第三副瓣区域
    G_dB = -9;
elseif phi_deg <= 120
    % 第四副瓣区域
    G_dB = -4;
else
    % 远副瓣区域
    G_dB = -9;
end

% 确保增益不超过最大值
G_dB = min(G_dB, G_max_dB);

end