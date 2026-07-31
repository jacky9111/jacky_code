function opts = ApplyEvalEnvironmentToKu16(opts, evalEnv, userAreaSide_km)
% ApplyEvalEnvironmentToKu16
% 【中文說明】把共用環境 evalEnv 翻譯成 RunKu16BeamBaselineObservationLogExcel
% （PC + Tilt baseline，重現 Jalali et al. 的 joint power and tilt control）需要的 opts。
%
% 與 ApplyEvalEnvironmentToFullPowerSweep 的差別只在欄位命名習慣
% （Ku16 runner 用 cellstr 與 usersPerSat 等舊命名），物理設定完全相同，
% 這樣 PC+Tilt 與 EABR 才是在同一組模擬參數下比較。
%
% PC+Tilt 專屬開關（enablePowerControl / enableBaselineTilt / baselineTiltMaxDeg…）
% 是在 RunEvalFourMethodSweepsLocal.m 中另外設定。

opts.leoList = cellstr(evalEnv.leoList);
opts.geoList = cellstr(evalEnv.geoList);
opts.tStartStr = evalEnv.tStartStr;
opts.tEndStr = evalEnv.tEndStr;
opts.stepSec = evalEnv.stepSec;
opts.beamHalfEW_deg = evalEnv.beamHalfEW_deg;
opts.beamHalfNS_deg = evalEnv.beamHalfNS_deg;
opts.useIdealGsoAtGs = evalEnv.useIdealGsoAtGs;
opts.gsName = evalEnv.gsName;
opts.gsLat_deg = evalEnv.gsLat_deg;
opts.gsLon_deg = evalEnv.gsLon_deg;
opts.params = evalEnv.params;                                       % EPFD 工程參數
opts.useSimulatedUsers = evalEnv.useSimulatedUsers;
opts.reassignUsersEachSlot = evalEnv.reassignUsersEachSlot;
opts.userPlacementSatList = cellstr(evalEnv.userPlacementSatList);
opts.usersPerSat = evalEnv.numUsersPerSat;                          % 每星 user 數（U 值）
opts.userDemand_Mbps = evalEnv.userDemand_Mbps;
opts.userAreaSide_km = userAreaSide_km;
opts.userPrefix = evalEnv.userPrefix;
opts.userInBeamCenterOnly = false;                                  % false：user 均勻灑滿 beam，不只放中心
opts.excelSatelliteIds = cellstr(evalEnv.recordSats);               % Excel 明細記錄的衛星
end
