function Create_GSO_GS_Multiple_Latitudes(root, geoName, geoLongitudes, OneWeb_OMNet_geo, latRange, latStep)
% ============================================================
% Create_GSO_GS_Multiple_Latitudes
% 基于一个 GEO 卫星，生成不同纬度的 GSO 地面站
% 
% 用于生成 Figure 11 所需的地面站
%
% INPUTS:
%   root            : IAgStkObjectRoot
%   geoName         : GEO 卫星名称，例如 "geo_16_4"
%   geoLongitudes   : GEO 卫星经度数组（与 OneWeb_OMNet_geo 对应）
%   OneWeb_OMNet_geo: GEO 卫星名称数组
%   latRange        : [latMin, latMax] 纬度范围（度），例如 [-0.5, 0.5]
%   latStep         : 纬度步长（度），例如 0.1
%
% OUTPUTS:
%   在 STK 中创建多个地面站，名称格式：GSO_GS_geo_16_4_..（.. 是纬度值）
%
% Example:
%   Create_GSO_GS_Multiple_Latitudes(root, "geo_16_4", geoLongitudes, ...
%       OneWeb_OMNet_geo, [-0.5, 0.5], 0.1);
% ============================================================

    fprintf("\n=== Creating GSO Ground Stations for %s at Multiple Latitudes ===\n", geoName);
    
    % 找到 GEO 卫星在数组中的索引
    geoIdx = find(strcmp(OneWeb_OMNet_geo, geoName));
    if isempty(geoIdx)
        error('找不到 GEO 卫星: %s', geoName);
    end
    
    % 获取该 GEO 卫星的经度
    lon = geoLongitudes(geoIdx);
    fprintf("GEO 卫星 %s 的经度: %.3f°\n", geoName, lon);
    
    % 生成纬度列表
    latList = latRange(1):latStep:latRange(2);
    fprintf("纬度范围: [%.1f°, %.1f°], 步长: %.1f°\n", latRange(1), latRange(2), latStep);
    fprintf("将创建 %d 个地面站\n", length(latList));
    
    sc = root.CurrentScenario;
    
    % 为每个纬度创建地面站
    for i = 1:length(latList)
        lat = latList(i);
        
        % 地面站名称格式：GSO_GS_geo_16_4_..（纬度值）
        % 将纬度值转换为字符串，负号用下划线替代，小数点用下划线替代
        % 例如：-0.5 -> "-0_5", 0.0 -> "0_0", 0.5 -> "0_5"
        latStr = sprintf('%.1f', lat);
        latStr = strrep(latStr, '-', 'm');  % 负号用 'm' 表示（minus）
        latStr = strrep(latStr, '.', '_');  % 小数点用下划线替代
        
        gsName = sprintf("GSO_GS_%s_%s", geoName, latStr);
        
        fprintf("  → Creating %s at (lat = %.1f°, lon = %.3f°)\n", gsName, lat, lon);
        
        % 删除旧的地面站（如果存在）
        try
            sc.Children.Item(gsName).Unload();
        catch
        end
        
        % 创建 Facility
        gs = sc.Children.New('eFacility', gsName);
        gs.Position.AssignGeodetic(lat, lon, 0);
        gs.Graphics.LabelVisible = true;
    end
    
    fprintf("=== Completed: %d GSO Ground Stations created ===\n\n", length(latList));
end
