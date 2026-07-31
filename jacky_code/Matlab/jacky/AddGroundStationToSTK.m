function AddGroundStationToSTK(root, gsName, lat_deg, lon_deg)
% AddGroundStationToSTK
% 在目前 STK 場景新增一個地面站（Facility）。
%
% Inputs:
% - root: STK root object
% - gsName: 地面站名稱
% - lat_deg: 緯度（deg）
% - lon_deg: 經度（deg）
%
% 這個地面站代表論文中「受 NGSO 干擾的 GSO 地球站」。
% EPFD 就是在這一點上累加所有 LEO beam 的干擾功率。
% 注意：實際 EPFD 計算用的是 evalGsLat_deg / evalGsLon_deg（傳給 evalEnv），
% 這裡建立的 STK Facility 主要供視覺化與檢查用。

sc = root.CurrentScenario;
gsName = char(string(gsName));

% 若已有同名地面站先卸載，避免重跑時堆疊
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
