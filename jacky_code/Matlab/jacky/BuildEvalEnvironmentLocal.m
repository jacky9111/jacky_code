function evalEnv = BuildEvalEnvironmentLocal(evalCriticalSat, evalTStartStr, evalTEndStr, evalStepSec, ...
    evalBeamHalfEW_deg, evalBeamHalfNS_deg, evalGsLat_deg, evalGsLon_deg, ...
    evalUsersPerSat, evalUserDemand_Mbps, evalFullBeamPower_W, evalMaxBeamPower_W, ...
    evalRecordSats, leo_part, satUserTargets, ku_epfd_params_fn)
% BuildEvalEnvironmentLocal  Single source for full-power sweep vs Ku16 paper-model runs.
% Physics / time / GS / user field are shared; control policy differs per runner.

evalEnv = struct();
evalEnv.criticalSat = string(evalCriticalSat);
evalEnv.recordSats = string(evalRecordSats(:));
evalEnv.tStartStr = evalTStartStr;
evalEnv.tEndStr = evalTEndStr;
evalEnv.stepSec = evalStepSec;
evalEnv.beamHalfEW_deg = evalBeamHalfEW_deg;
evalEnv.beamHalfNS_deg = evalBeamHalfNS_deg;
evalEnv.gsLat_deg = evalGsLat_deg;
evalEnv.gsLon_deg = evalGsLon_deg;
evalEnv.gsName = "GS_01";
evalEnv.geoList = "IdealGSO_GS01";
evalEnv.useIdealGsoAtGs = true;
evalEnv.numUsersPerSat = evalUsersPerSat;
evalEnv.userDemand_Mbps = evalUserDemand_Mbps;
evalEnv.fullBeamPower_W = evalFullBeamPower_W;
evalEnv.maxBeamPower_W = evalMaxBeamPower_W;
evalEnv.userPrefix = "User_";
evalEnv.leoList = string(leo_part(:));
evalEnv.satList = string(satUserTargets(:));
evalEnv.userPlacementSatList = evalEnv.leoList;
evalEnv.useSimulatedUsers = true;
evalEnv.reassignUsersEachSlot = true;

evalEnv.params = ku_epfd_params_fn();
evalEnv.params.useEIRPDensityModel = false;
evalEnv.params.EIRPdens_dBW_per_4kHz = -13.4;
evalEnv.params.Ptotal_W = evalFullBeamPower_W * 16;
end
