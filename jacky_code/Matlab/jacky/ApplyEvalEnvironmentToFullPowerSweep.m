function opts = ApplyEvalEnvironmentToFullPowerSweep(opts, evalEnv, userAreaSide_km)
% ApplyEvalEnvironmentToFullPowerSweep
% 【中文說明】把共用環境 evalEnv 翻譯成 RunFullPowerAggregateShutdownSweepExcel
% （Beam shutdown only / Only HBR / EABR 三個方法共用的 runner）需要的 opts 欄位名稱。
%
% 這裡只搬「共用的物理與場景設定」；真正區分三個方法的開關是在
% RunEvalFourMethodSweepsLocal.m 裡另外設的：
%   enableRelay             false → Beam shutdown only
%   enableMiddleHelperSwap  false → Only HBR；true → EABR（多做 SBR 安全束換手）
%
% userAreaSide_km：user 灑點的正方形邊長 [km]，取 beam footprint 的較大邊，
%                  確保 user 覆蓋整個 16-beam 足跡。

opts.tStartStr = evalEnv.tStartStr;
opts.tEndStr = evalEnv.tEndStr;
opts.stepSec = evalEnv.stepSec;
opts.beamHalfEW_deg = evalEnv.beamHalfEW_deg;
opts.beamHalfNS_deg = evalEnv.beamHalfNS_deg;
opts.geoList = evalEnv.geoList;
opts.useIdealGsoAtGs = evalEnv.useIdealGsoAtGs;
opts.gsName = evalEnv.gsName;
opts.gsLat_deg = evalEnv.gsLat_deg;
opts.gsLon_deg = evalEnv.gsLon_deg;
opts.gsAlt_km = 0;                                        % 地面站海拔，論文設 0
opts.fullBeamPower_W = evalEnv.fullBeamPower_W;           % beam 全開功率
opts.beamAllocatePower_W = evalEnv.fullBeamPower_W;       % 分配給一般 beam 的功率
opts.maxBeamPower_W = evalEnv.maxBeamPower_W;             % helper recovery beam 功率上限
opts.params = evalEnv.params;                             % EPFD 工程參數
opts.userDemand_Mbps = evalEnv.userDemand_Mbps;
opts.useSimulatedUsers = evalEnv.useSimulatedUsers;
opts.reassignUsersEachSlot = evalEnv.reassignUsersEachSlot;
opts.userPlacementSatList = evalEnv.userPlacementSatList;
opts.numUsersPerSatellite = evalEnv.numUsersPerSat;       % 每星 user 數（U 值）
opts.userAreaSide_km = userAreaSide_km;
opts.userPrefix = evalEnv.userPrefix;
opts.criticalSatelliteForEpfd = evalEnv.criticalSat;      % 由誰負責關束來壓 EPFD
opts.satList = evalEnv.satList;
opts.satisfactionRecordSatList = evalEnv.recordSats;      % Excel 逐 user 明細只記這幾顆
opts.satisfactionSatList = evalEnv.recordSats;            % 平均滿意度統計範圍
end
