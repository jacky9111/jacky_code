function users = Extract_Users_From_STK(root, userPrefix, tStr)
% ============================================================
% Extract_Users_From_STK
% 从 STK 中提取用户位置（Facility 对象）
%
% INPUTS:
%   root      : IAgStkObjectRoot
%   userPrefix: 用户名称前缀（如 "User_"）
%   tStr      : 时间字符串（可选，Facility 固定位置，不使用）
%
% OUTPUTS:
%   users     : struct with fields
%       .lat_deg : [N x 1] latitudes (deg)
%       .lon_deg : [N x 1] longitudes (deg)
%       .names   : {N x 1} cell array of user names
% ============================================================

sc = root.CurrentScenario;
facs = sc.Children.GetElements('eFacility');

lat_list = [];
lon_list = [];
name_list = {};

fprintf('从 STK 提取用户位置 (前缀: %s)...\n', userPrefix);

% 修复：将 k 转换为 int32
for k = 0:int32(facs.Count-1)
    user = facs.Item(k);
    userName = char(user.InstanceName);
    
    if ~startsWith(userName, userPrefix)
        continue;
    end
    
    try
        % 获取 LLA 位置
        % Facility 对象是固定的，只能使用 Exec，不能使用 ExecSingle
        dpLLA = user.DataProviders.Item('LLA State');
        res = dpLLA.Exec;  % Facility 固定位置，不需要时间参数
        
        arr = res.DataSets.ToArray;
        
        % 提取经纬度
        vals = [];
        for i = 1:numel(arr)
            a = arr{i};
            if isnumeric(a) && isscalar(a)
                vals(end+1,1) = double(a); %#ok<AGROW>
            end
        end
        
        if numel(vals) >= 2
            lat = vals(1);
            lon = vals(2);
            
            lat_list(end+1,1) = lat;
            lon_list(end+1,1) = lon;
            name_list{end+1,1} = userName;
        end
        
    catch ME
        warning('无法提取 %s 的位置: %s', userName, ME.message);
    end
end

users.lat_deg = lat_list;
users.lon_deg = lon_list;
users.names = name_list;

fprintf('提取了 %d 个用户位置\n', length(lat_list));

% 如果用户数量为 0，给出提示
if isempty(lat_list)
    warning('未找到匹配前缀 "%s" 的用户。请确认用户已创建且前缀正确。', userPrefix);
end

end