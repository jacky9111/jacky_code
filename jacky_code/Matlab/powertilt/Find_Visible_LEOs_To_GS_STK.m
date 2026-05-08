function visIdx = Find_Visible_LEOs_To_GS_STK(LEO_data, GS_data, minElevDeg)
    % ============================================================
    % Find_Visible_LEOs_To_GS_STK
    % 找到对 GS 可见的 LEO 卫星（基于最小仰角）
    %
    % INPUTS:
    %   LEO_data   : struct from Extract_Positions_From_STK
    %   GS_data    : struct from Extract_Positions_From_STK
    %   minElevDeg : minimum elevation angle (deg)
    %
    % OUTPUTS:
    %   visIdx     : indices of visible LEO satellites (into LEO_data)
    % ============================================================
    
    N_leo = LEO_data.N;
    N_gs = GS_data.N;
    
    % 如果多个 GS，只要对任一 GS 可见就算可见
    vis = false(N_leo, 1);
    
    for i = 1:N_leo
        r_sat = LEO_data.pos_ecef_km(:, i);
        
        for j = 1:N_gs
            r_gs = GS_data.pos_ecef_km(:, j);
            rho = r_sat - r_gs;
            range_km = norm(rho);
            
            % Elevation: angle between rho and local horizon
            % Use simple method: elev = 90 - angle( rho, zenith )
            zenith = r_gs / norm(r_gs);
            ang = acosd( max(-1, min(1, dot(rho, zenith) / (norm(rho)*norm(zenith))) ) );
            elev = 90 - ang;
            
            if elev >= minElevDeg
                vis(i) = true;
                break;  % 只要对一个 GS 可见即可
            end
        end
    end
    
    visIdx = find(vis);
    
    fprintf('可见的 LEO 卫星: %d / %d\n', numel(visIdx), N_leo);
    
    end