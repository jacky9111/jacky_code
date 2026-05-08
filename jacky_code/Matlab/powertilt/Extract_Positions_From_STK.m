function [LEO_data, GEO_data, GS_data] = Extract_Positions_From_STK(root, leoList, geoList, tStr)
    % ============================================================
    % Extract_Positions_From_STK
    % 从 STK 提取 LEO、GEO、GS 的位置信息（Fixed 坐标系，单位：km）
    %
    % INPUTS:
    %   root    : IAgStkObjectRoot
    %   leoList : cell array of LEO satellite names
    %   geoList : cell array of GEO satellite names
    %   tStr    : time string (e.g., '16 Dec 2025 12:14:33')
    %
    % OUTPUTS:
    %   LEO_data: struct with fields
    %       .pos_ecef_km  : [3 x N] ECEF positions (km)
    %       .sub_lat_deg  : [1 x N] sub-satellite latitude (deg)
    %       .sub_lon_deg  : [1 x N] sub-satellite longitude (deg)
    %       .names        : cell array of names
    %   GEO_data: struct with fields
    %       .pos_ecef_km  : [3 x M] ECEF positions (km)
    %       .names        : cell array of names
    %   GS_data : struct with fields
    %       .pos_ecef_km  : [3 x M] ECEF positions (km)
    %       .lat_deg      : [1 x M] latitude (deg)
    %       .names        : cell array of names
    % ============================================================
    
    fprintf('提取 LEO 位置...\n');
    N_leo = length(leoList);
    LEO_pos = zeros(3, N_leo);
    LEO_sub_lat = zeros(1, N_leo);
    LEO_sub_lon = zeros(1, N_leo);
    % #region agent log
    try, fid=fopen('c:\Users\jacky\Desktop\jacky_code\.cursor\debug.log','a'); fprintf(fid,'{"location":"Extract_Positions_From_STK.m:29","message":"LEO extract start","data":{"N_leo":%d,"first3":["%s","%s","%s"]},"hypothesisId":"A","timestamp":%.0f}\n', N_leo, leoList{1}, leoList{min(2,numel(leoList))}, leoList{min(3,numel(leoList))}, fix(now*86400000)); fclose(fid); catch, end
    % #endregion
    
    for i = 1:N_leo
        leoName = leoList{i};
        try
            satObj = root.GetObjectFromPath(['*/Satellite/' leoName]);
            dpPos = satObj.DataProviders.Item('Cartesian Position').Group.Item('Fixed');
            dpLLA = satObj.DataProviders.Item('LLA State').Group.Item('Fixed');
            
            % Position
            res = dpPos.ExecSingle(tStr);
            arr = res.DataSets.ToArray;
            P = stkGetXYZ_FromArray(arr);
            LEO_pos(:, i) = P;  % km
            
            % LLA
            resLLA = dpLLA.ExecSingle(tStr);
            arrLLA = resLLA.DataSets.ToArray;
            lat = stkGetLat_FromArray(arrLLA);
            LEO_sub_lat(i) = lat;
            
            % Longitude (extract from array)
            vals = [];
            for k = 1:numel(arrLLA)
                a = arrLLA{k};
                if isnumeric(a) && isscalar(a)
                    vals(end+1,1) = double(a); %#ok<AGROW>
                end
            end
            if numel(vals) >= 2
                LEO_sub_lon(i) = vals(2);  % longitude is second value
            end
            
        catch ME
            % #region agent log
            try, fid=fopen('c:\Users\jacky\Desktop\jacky_code\.cursor\debug.log','a'); fprintf(fid,'{"location":"Extract_Positions_From_STK.m:65","message":"LEO extract failed","data":{"leoIdx":%d,"leoName":"%s","err":"%s"},"hypothesisId":"A,D,E","timestamp":%.0f}\n', i, leoName, strrep(strrep(ME.message,sprintf('\n'),' '),'"',''''), fix(now*86400000)); fclose(fid); catch, end
            % #endregion
            warning('无法提取 %s 的位置: %s', leoName, ME.message);
            LEO_pos(:, i) = [0; 0; 0];
            LEO_sub_lat(i) = 0;
            LEO_sub_lon(i) = 0;
        end
    end
    % #region agent log
    try, fid=fopen('c:\Users\jacky\Desktop\jacky_code\.cursor\debug.log','a'); fprintf(fid,'{"location":"Extract_Positions_From_STK.m:74","message":"LEO extract loop done","data":{"N_leo":%d},"hypothesisId":"C,D","timestamp":%.0f}\n', N_leo, fix(now*86400000)); fclose(fid); catch, end
    % #endregion
    
    LEO_data.pos_ecef_km = LEO_pos;
    LEO_data.sub_lat_deg = LEO_sub_lat;
    LEO_data.sub_lon_deg = LEO_sub_lon;
    LEO_data.names = leoList;
    LEO_data.N = N_leo;
    
    fprintf('提取 GEO 位置...\n');
    N_geo = length(geoList);
    GEO_pos = zeros(3, N_geo);
    
    for j = 1:N_geo
        geoName = geoList{j};
        try
            satObj = root.GetObjectFromPath(['*/Satellite/' geoName]);
            dpPos = satObj.DataProviders.Item('Cartesian Position').Group.Item('Fixed');
            
            res = dpPos.ExecSingle(tStr);
            arr = res.DataSets.ToArray;
            P = stkGetXYZ_FromArray(arr);
            GEO_pos(:, j) = P;  % km
            
        catch ME
            warning('无法提取 %s 的位置: %s', geoName, ME.message);
            GEO_pos(:, j) = [0; 0; 0];
        end
    end
    
    GEO_data.pos_ecef_km = GEO_pos;
    GEO_data.names = geoList;
    GEO_data.N = N_geo;
    
    fprintf('提取 GS 位置...\n');
    GS_pos = zeros(3, N_geo);
    GS_lat = zeros(1, N_geo);
    
    for j = 1:N_geo
        geoName = geoList{j};
        gsName = ['GSO_GS_' geoName];
        try
            gsObj = root.GetObjectFromPath(['*/Facility/' gsName]);
            
            % Position
            res = gsObj.DataProviders.Item('Cartesian Position').Exec;
            arr = res.DataSets.ToArray;
            P = stkGetXYZ_FromArray(arr);
            GS_pos(:, j) = P;  % km
            
            % Latitude
            try
                resLLA = gsObj.DataProviders.Item('LLA State').Exec;
                arrLLA = resLLA.DataSets.ToArray;
                lat = stkGetLat_FromArray(arrLLA);
                GS_lat(j) = lat;
            catch
                % Fallback: compute from Cartesian
                GS_lat(j) = geoLatFromFixedXYZ(P);
            end
            
        catch ME
            warning('无法提取 %s 的位置: %s', gsName, ME.message);
            GS_pos(:, j) = [0; 0; 0];
            GS_lat(j) = 0;
        end
    end
    
    GS_data.pos_ecef_km = GS_pos;
    GS_data.lat_deg = GS_lat;
    GS_data.names = geoList;
    GS_data.N = N_geo;
    
    fprintf('完成位置提取: LEO=%d, GEO=%d, GS=%d\n', N_leo, N_geo, N_geo);
    
    end
    
    % ============================================================
    % Helper functions (same as SystemWide16_GSO_EPFD_Control.m)
    % ============================================================
    function P = stkGetXYZ_FromArray(arr)
    vals = [];
    for k = 1:numel(arr)
        a = arr{k};
        if isnumeric(a) && isscalar(a)
            vals(end+1,1) = double(a); %#ok<AGROW>
        end
    end
    if numel(vals) < 3
        error('STK XYZ extraction failed: found only %d numeric scalars.', numel(vals));
    end
    P = vals(1:3);
    P = P(:);
    end
    
    function lat = stkGetLat_FromArray(arr)
    vals = [];
    for k = 1:numel(arr)
        a = arr{k};
        if isnumeric(a) && isscalar(a)
            vals(end+1,1) = double(a); %#ok<AGROW>
        end
    end
    if isempty(vals)
        error('STK LLA extraction failed: no numeric scalars found.');
    end
    lat = vals(1);
    end
    
    function lat = geoLatFromFixedXYZ(P)
    x = P(1); y = P(2); z = P(3);
    lat = atan2d(z, sqrt(x^2 + y^2)); % geocentric latitude
    end