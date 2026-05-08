function AddGroundStationToSTK(root, gsName, lat_deg, lon_deg)
% AddGroundStationToSTK
% 在目前 STK 場景新增一個地面站（Facility）。
%
% Inputs:
% - root: STK root object
% - gsName: 地面站名稱
% - lat_deg: 緯度（deg）
% - lon_deg: 經度（deg）

sc = root.CurrentScenario;
gsName = char(string(gsName));

try
    sc.Children.Item(gsName).Unload();
catch
end

gs = sc.Children.New('eFacility', gsName);
gs.Position.AssignGeodetic(lat_deg, lon_deg, 0);
gs.Graphics.LabelVisible = true;

fprintf("Ground station created: %s (lat = %.4f deg, lon = %.4f deg)\n", ...
    gsName, lat_deg, lon_deg);
end
