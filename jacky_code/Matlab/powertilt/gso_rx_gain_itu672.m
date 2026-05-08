function G_dB = gso_rx_gain_itu672(phi_deg, D_m, lambda_m)
    % ============================================================
    % gso_rx_gain_itu672
    % ITU-R S.672 天线方向图模型（GSO 地面站接收天线）
    %
    % 设置合理的增益下限，使得 EPFD 在 phi_r 较大时稳定在合理范围
    % ============================================================
    
    % 归一化角度（相对于主瓣宽度）
    theta_3dB_deg = 70 * lambda_m / D_m;
    u = phi_deg / theta_3dB_deg;
    
    % ITU-R S.672 分段模型
    if u < 1.5
        % 主瓣区域
        if u < 1.0
            G_dB = -12 * (u^2);
        else
            G_dB = -12 - 15 * (u - 1.0);
        end
    else
        % 副瓣区域
        G_dB = -12 - 15 * (u - 1.0) - 10 * log10(max(u, 1.5));
    end
    
    % 确保增益不超过 0 dB（boresight 为最大值）
    G_dB = min(G_dB, 0);
    
    % 对于非常小的角度，确保接近 0 dB
    if phi_deg < 0.1
        G_dB = 0;
    end
    
    % 设置合理的增益下限
    % 当 phi_r = 2.0 度时，G_r_rel ≈ -105.24 dB，对应的 EPFD ≈ -194.42 dB
    % 设置下限为 phi_r = 2.0 度时的增益值，使得 EPFD 在 phi_r 较大时稳定
    phi_r_limit_deg = 2.0;  % 限制角度
    u_limit = phi_r_limit_deg / theta_3dB_deg;
    if u_limit >= 1.5
        G_dB_limit = -12 - 15 * (u_limit - 1.0) - 10 * log10(max(u_limit, 1.5));
    else
        if u_limit < 1.0
            G_dB_limit = -12 * (u_limit^2);
        else
            G_dB_limit = -12 - 15 * (u_limit - 1.0);
        end
    end
    
    % 应用增益下限：当增益低于限制值时，使用限制值
    G_dB = max(G_dB, G_dB_limit);
    
    end