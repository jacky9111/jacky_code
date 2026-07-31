function G_dB = gso_rx_gain_itu1428(phi_deg, D_m, lambda_m)
% ============================================================
% gso_rx_gain_itu1428
% ITU-R S.1428-1 天线方向图模型（GSO 地面站接收天线）
%
% 根据论文中的 Eq.(9) 和 ITU-R S.1428-1
% ============================================================
%
% 【中文補充｜本論文中的角色】
% 這支是全專案共用的 GSO 地球站接收天線場型，對應論文 Simulation Parameters
% 表格中 GSO ground station 的「Antenna pattern: ITU-R S.1428」。
%
% 呼叫者包含：
%   jacky/RunFullPowerAggregateShutdownSweepExcel（EABR 系列）
%   jacky/RunKu16BeamBaselineObservationLogExcel（PC + Tilt）
%   helper_availability/compute_beam_epfd
%   overhead_evaluation/run_pc_tilt_online_existing_logic
% 因為四個比較方法都用同一支，EPFD 的計算基準才是一致的。
%
% 輸入 phi_deg 是「從 GS 看出去，干擾源 LEO 與目標 GSO 之間的夾角」。
% phi 越小 → 落在主瓣、增益越高 → 干擾越嚴重，這就是 critical period 的成因。
%
% D_m 用 60 cm 參考天線徑（論文 Table 的 Reference antenna diameter），
% lambda_m 由載波頻率換算（Ku 11.7 GHz）。
%
% 【注意】本函式一次只接受一個純量 phi_deg（內部是 if/elseif 分段），
% 不支援向量化輸入；呼叫端都是在迴圈中逐一呼叫。

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