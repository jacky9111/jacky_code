function out = graphRecoverySharedLocal(action, varargin)
% graphRecoverySharedLocal  Shared helpers for graph-based SBR/HBR simulation.
%
% 【中文說明】SBR / HBR 圖形化模擬共用的幾何與通訊工具集合。
% 用單一入口 + action 字串分派，是為了讓這些小工具能被
% runGraphSelectionPolicyLocal、overhead_evaluation 等多處共用，
% 又不必在資料夾裡散落十幾個檔案。
%
% 可用的 action：
%   "usercovered"     判斷某個 user 是否落在指定 beam 的覆蓋範圍內
%   "satisfaction"    算某個 user 掛在某條 beam 上時的滿意度
%   "footprintrect"   算一條 beam 在地面的矩形足跡
%   "beamsoverlap"    判斷兩條 beam 的足跡是否重疊（helper 資格的關鍵）
%   "userinfootprint" 判斷 user 是否落在足跡多邊形內
%   "groundxyz"       經緯度 → 地心直角座標 [km]
switch lower(string(action))
    case "usercovered"
        out = userCoveredByBeamGraph(varargin{:});
    case "satisfaction"
        out = userSatisfactionAtBeamGraph(varargin{:});
    case "footprintrect"
        out = beamFootprintRectGraph(varargin{:});
    case "beamsoverlap"
        out = beamsFootprintOverlapGraph(varargin{:});
    case "userinfootprint"
        out = userInBeamFootprintGraph(varargin{:});
    case "groundxyz"
        out = groundXYZFromLatLonGraph(varargin{:});
    otherwise
        error('graphRecoverySharedLocal:UnknownAction', 'Unknown action: %s', action);
end
end

function tf = userCoveredByBeamGraph(satGeomOne, beamIdx, P_user_km, beamHalfEW_deg, beamHalfNS_deg)
% 判斷 user 是否落在指定 beam 的矩形覆蓋內：
% 把「衛星 → user」的方向向量投影到 beam 的本體座標系，
% 分別算出水平/垂直離軸角，再與 beam 半角比較。
P_leo_km = satGeomOne.P_leo_km;
b_hat = satGeomOne.b_all(:, beamIdx);      % 該 beam 的指向單位向量
c_axis = satGeomOne.c_axis;                % beam 座標系的水平參考軸
v_user_km = P_user_km(:) - P_leo_km(:);    % 衛星指向 user 的向量
if norm(v_user_km) * 1000 < 1
    tf = false;                            % user 與衛星幾乎重合 → 視為無效
    return;
end
d_hat = v_user_km / max(norm(v_user_km), eps);
t_axis = cross(c_axis, b_hat);             % 垂直參考軸 = c × b
t_axis = t_axis / max(norm(t_axis), eps);
th_h = atan2d(dot(d_hat, c_axis), dot(d_hat, b_hat));   % 水平離軸角 [deg]
th_v = atan2d(dot(d_hat, t_axis), dot(d_hat, b_hat));   % 垂直離軸角 [deg]
% 兩個方向都在半角內才算被覆蓋（矩形波束）
tf = abs(th_h) <= beamHalfEW_deg && abs(th_v) <= beamHalfNS_deg;
end

function s = userSatisfactionAtBeamGraph(iu, iSat, b, Pbeam, usersInBeam, satGeom, P_users_km, P, userDemand_bps)
if iSat < 1 || b < 1 || ~isfinite(Pbeam) || Pbeam <= 0
    s = 0;
    return;
end
Buser = P.B_Hz;
noisePower_W = P.kB * P.user_noise_temp_K * Buser;
Gur_lin = 10^(P.GS_LEO_Gmax_dBi / 10);
demandMbps = userDemand_bps / 1e6;
channelGain = userLinkChannelGainGraph(satGeom(iSat), b, P_users_km(:, iu), P, Gur_lin);
sig = Pbeam * channelGain;
sinr = sig / max(noisePower_W, eps);
cinst_bps = Buser * log2(1 + sinr);
usersInBeam = max(double(usersInBeam), 1);
rate_Mbps = cinst_bps / usersInBeam / 1e6;
s = min(rate_Mbps / max(demandMbps, eps), 1);
end

function channelGain = userLinkChannelGainGraph(satGeomOne, beamIdx, P_user_km, P, Gur_lin)
P_leo_km = satGeomOne.P_leo_km;
b_hat = satGeomOne.b_all(:, beamIdx);
c_axis = satGeomOne.c_axis;
v_user_km = P_user_km(:) - P_leo_km(:);
d_m = norm(v_user_km) * 1000;
if d_m < 1
    channelGain = 0;
    return;
end
d_hat = v_user_km / max(norm(v_user_km), eps);
t_axis = cross(c_axis, b_hat);
t_axis = t_axis / max(norm(t_axis), eps);
th_h = atan2d(dot(d_hat, c_axis), dot(d_hat, b_hat));
th_v = atan2d(dot(d_hat, t_axis), dot(d_hat, b_hat));
phi = hypot(th_h, th_v);
Gt_lin = max(P.A_fit * exp(P.beta_fit * phi), 1e-30);
pathGain = (P.lambda_m^2) / max((4 * pi * d_m)^2, eps);
channelGain = Gt_lin * Gur_lin * pathGain;
end

function rect = beamFootprintRectGraph(satGeomOne, beamIdx, beamHalfEW_deg, beamHalfNS_deg, alt_km)
Re_km = 6378.137;
hit = rayEarthIntersectGraph(satGeomOne.P_leo_km * 1000, satGeomOne.b_all(:, beamIdx), Re_km * 1000);
if isempty(hit)
    lat = satGeomOne.subLat;
    lon = satGeomOne.subLon;
else
    lat = asind(hit(3) / max(norm(hit), eps));
    lon = atan2d(hit(2), hit(1));
end
halfNS_km = alt_km * tand(beamHalfNS_deg * 16); %#ok<NASGU> % caller passes per-beam half
halfEW_km = alt_km * tand(beamHalfEW_deg);
dLat = halfNS_km / 111.32;
lonScale = max(cosd(lat), 1e-6);
dLon = halfEW_km / (111.32 * lonScale);
rect.lon = [lon - dLon, lon + dLon, lon + dLon, lon - dLon];
rect.lat = [lat - dLat, lat - dLat, lat + dLat, lat + dLat];
rect.centerLat = lat;
rect.centerLon = lon;
end

function tf = beamsFootprintOverlapGraph(satGeomA, beamA, satGeomB, beamB, beamHalfEW_deg, beamHalfNS_deg, alt_km)
% Footprint overlap via rectangle intersection (ground plane approx).
halfNS_km = alt_km * tand(beamHalfNS_deg);
halfEW_km = alt_km * tand(beamHalfEW_deg);
rectA = beamFootprintRectAtSubpointGraph(satGeomA.subLat, satGeomA.subLon, halfEW_km, halfNS_km);
rectB = beamFootprintRectAtSubpointGraph(satGeomB.subLat, satGeomB.subLon, halfEW_km, halfNS_km);
tf = rectsOverlapGraph(rectA, rectB);
% Also require boresight coverage consistency for 16-beam strip: use beam index offset in NS.
nsOffsetA = (8.5 - beamA) * 2 * beamHalfNS_deg;
nsOffsetB = (8.5 - beamB) * 2 * beamHalfNS_deg;
rectA.lat = rectA.lat + nsOffsetA / 111.32 * [1 1 1 1];
rectB.lat = rectB.lat + nsOffsetB / 111.32 * [1 1 1 1];
tf = tf || rectsOverlapGraph(rectA, rectB);
end

function rect = beamFootprintRectAtSubpointGraph(lat, lon, halfEW_km, halfNS_km)
dLat = halfNS_km / 111.32;
lonScale = max(cosd(lat), 1e-6);
dLon = halfEW_km / (111.32 * lonScale);
rect.lon = [lon - dLon, lon + dLon, lon + dLon, lon - dLon];
rect.lat = [lat - dLat, lat - dLat, lat + dLat, lat + dLat];
end

function tf = rectsOverlapGraph(rectA, rectB)
lonOverlap = max(rectA.lon) >= min(rectB.lon) && max(rectB.lon) >= min(rectA.lon);
latOverlap = max(rectA.lat) >= min(rectB.lat) && max(rectB.lat) >= min(rectA.lat);
tf = lonOverlap && latOverlap;
end

function tf = userInBeamFootprintGraph(userLat_deg, userLon_deg, satGeomOne, beamIdx, beamHalfEW_deg, beamHalfNS_deg, alt_km)
% Ground footprint check (same rectangle + NS strip offset as beamsFootprintOverlapGraph).
halfNS_km = alt_km * tand(beamHalfNS_deg);
halfEW_km = alt_km * tand(beamHalfEW_deg);
rect = beamFootprintRectAtSubpointGraph(satGeomOne.subLat, satGeomOne.subLon, halfEW_km, halfNS_km);
nsOffset_deg = (8.5 - beamIdx) * 2 * beamHalfNS_deg;
rect.lat = rect.lat + nsOffset_deg / 111.32 * [1 1 1 1];
tf = userLon_deg >= min(rect.lon) && userLon_deg <= max(rect.lon) && ...
    userLat_deg >= min(rect.lat) && userLat_deg <= max(rect.lat);
end

function P_km = groundXYZFromLatLonGraph(lat_deg, lon_deg, alt_km)
Re_km = 6378.137;
r_km = Re_km + alt_km;
P_km = r_km * [cosd(lat_deg) * cosd(lon_deg); cosd(lat_deg) * sind(lon_deg); sind(lat_deg)];
end

function hit = rayEarthIntersectGraph(r_s_m, d_unit, Re_m)
a = 1.0;
b = 2.0 * dot(r_s_m, d_unit);
c = dot(r_s_m, r_s_m) - Re_m^2;
disc = b^2 - 4 * a * c;
if disc < 0
    hit = [];
    return;
end
s = sqrt(disc);
lam1 = (-b - s) / 2.0;
lam2 = (-b + s) / 2.0;
cand = [lam1, lam2];
cand = cand(cand > 0);
if isempty(cand)
    hit = [];
    return;
end
hit = r_s_m + min(cand) * d_unit;
end
