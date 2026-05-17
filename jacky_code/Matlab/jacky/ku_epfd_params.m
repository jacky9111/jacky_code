function P = ku_epfd_params()
% ku_epfd_params  Ku 頻段 NGSO→GSO EPFD 工程參數（可再依 ITU/FCC 提交資料調整）
% 單一來源：功率、頻寬、門檻、噪聲溫度、天線/頻率等請只在此檔修改；jacky.m 僅呼叫本函式。
%
% 對齊你提供的 EPFD 式：
%   EPFD = 10*log10( sum_{i,b} P_{i,b}/BWref * G_{t,b}/(4*pi*d^2) * G_G^r(phi_r)/G_{G,max} )
%
% 說明：
% - 下行載波頻率：取 OneWeb filing 常見 Ku user downlink 帶（約 10.7–12.7 GHz）內代表值，
%   對應「8×250 MHz channelization」時以單一 250 MHz user link 近似（單一代表頻點）。
% - LEO 發射方向圖仍採 Joint Power and Tilt 論文式 G≈A*exp(beta*phi)（phi 單位：deg），
%   A 由 Ku 波長與口徑推回主瓣峰值增益，beta 沿用論文擬合（工程近似）。
% - ITU RR Article 22 正式檢核需 S.1503 + mask/statistics；本程式採「瞬時門檻」做排程。
% - Ku downlink(10.7-12.75 GHz)常見是以 40 kHz reference 的 operational/validation mask；
%   這裡給一個可調工程門檻：-174 dB(W/m^2/40kHz) 等效到 1 MHz 約 -160 dB。

    P.freq_GHz = 11.7; % representative center in ~10.7–12.7 GHz downlink (per filing narrative)
    P.lambda_m = 3e8 / (P.freq_GHz * 1e9);

    % EPFD reference bandwidth (ITU-R / S.1503 reference)
    P.BWref_Hz = 4e4; % 40 kHz
    % EPFD threshold is defined on current BWref_Hz (40 kHz).
    % If your ITU limit is -173.4 dB(W/m^2/40kHz), keep it directly.
    P.EPFD_thr_dB = -173.4;
    P.EPFD_thr_ref_40kHz_dB = P.EPFD_thr_dB;

    % GSO 地球站（一般設定）
    % Reference receiving antenna diameter (60 cm)
    P.GSO_D_m = 0.6;
    P.GSO_Gmax_dBi = 20 * log10(P.GSO_D_m / P.lambda_m) + 7.7;
    P.GSO_noise_temp_K = 240;

    % LEO 發射口徑（Ku，工程典型；可改）
    P.LEO_D_m = 0.55;
    P.LEO_Gmax_dBi = 20 * log10(P.LEO_D_m / P.lambda_m) + 7.7;
    P.A_fit = 10^(P.LEO_Gmax_dBi / 10);
    P.beta_fit = -0.0671;
    % Use same reference receive antenna diameter (60 cm)
    P.user_D_m = 0.6;
    P.GS_LEO_Gmax_dBi = 20 * log10(P.user_D_m / P.lambda_m) + 7.7;

    % OneWeb常見文件口徑（建議用於本模型）：
    % Downlink PSD ≈ -13.4 dBW/4kHz
    P.EIRPdens_dBW_per_4kHz = -13.4;
    P.useEIRPDensityModel = true;

    % 舊口徑（保留相容）：總功率均分 16 束
    P.Ptotal_W = 16.8;
    P.Nbeam = 16;

    P.min_elev_deg = 10;
    P.useInBeamFootprint = false; % if true: report GS-in-footprint; never gates EPFD in jacky runners
    P.B_Hz = 250e6; % user-link bandwidth for SINR/capacity evaluation
    P.Nchannel = 8; % fixed Ku user channels; beam b -> channel mod(b-1,Nchannel)+1 in baseline runner
end
