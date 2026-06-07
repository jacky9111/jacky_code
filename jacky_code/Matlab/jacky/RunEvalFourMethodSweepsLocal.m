function RunEvalFourMethodSweepsLocal(root, file_path, evalEnv, evalUserAreaSide_km, ...
    evalCriticalSat, numUsersPerSat, epfdThr_dB, useEpfdThrTagInPaths)
% RunEvalFourMethodSweepsLocal  Four-method Excel sweep at one EPFD threshold.
% useEpfdThrTagInPaths=false -> baseline filenames (fig.1-5); true -> Thr* tag (fig.6).

evalEnv.params.EPFD_thr_dB = double(epfdThr_dB);
pathEpfdThr = [];
if nargin >= 8 && useEpfdThrTagInPaths
    pathEpfdThr = double(epfdThr_dB);
end

if isempty(pathEpfdThr)
    pathTagStr = "(none)";
else
    pathTagStr = char(epfdThrPathTagLocal(pathEpfdThr));
end
fprintf('Sweep four methods: EPFD_thr=%.1f dB, U%d, pathTag=%s\n', ...
    double(epfdThr_dB), round(double(numUsersPerSat)), pathTagStr);

optsSweepBase = struct();
optsSweepBase = ApplyEvalEnvironmentToFullPowerSweep(optsSweepBase, evalEnv, evalUserAreaSide_km);
optsSweepBase.enableRelay = true;
optsSweepBase.relayMinNativeSat = 0.9;
optsSweepBase.relayMinRelayAvgSat = 0.9;
optsSweepBase.relayPowerShiftMode = "overlapCapped";

optsBeamShutdown = optsSweepBase;
optsBeamShutdown.enableRelay = false;
optsBeamShutdown.enableMiddleHelperSwap = false;
optsBeamShutdown.excelPath = char(FullPowerSweepDataPathLocal(file_path, ...
    numUsersPerSat, 'BackoffOnly', '.xlsx', pathEpfdThr));
RunFullPowerAggregateShutdownSweepExcel(root, optsBeamShutdown);

optsPcTilt = struct();
optsPcTilt = ApplyEvalEnvironmentToKu16(optsPcTilt, evalEnv, evalUserAreaSide_km);
optsPcTilt.excelPath = char(ku16PcTiltExcelPathLocal(file_path, numUsersPerSat, pathEpfdThr));
optsPcTilt.useGsoNoiseInQualityMetric = true;
optsPcTilt.enablePowerControl = true;
optsPcTilt.enablePowerRedistribution = false;
optsPcTilt.enableBidirectionalRelay = false;
optsPcTilt.enableBaselineTilt = true;
optsPcTilt.baselineTiltSatelliteId = evalCriticalSat;
optsPcTilt.baselineTiltMaxDeg = 10;
optsPcTilt.baselineTiltStepDeg = 0.5;
RunKu16BeamBaselineObservationLogExcel(root, optsPcTilt);
fprintf('Saved PC+Tilt log: %s\n', optsPcTilt.excelPath);

optsRelayOnly = optsSweepBase;
optsRelayOnly.enableMiddleHelperSwap = false;
optsRelayOnly.excelPath = char(FullPowerSweepDataPathLocal(file_path, ...
    numUsersPerSat, 'RelayOnly', '.xlsx', pathEpfdThr));
RunFullPowerAggregateShutdownSweepExcel(root, optsRelayOnly);

optsSaprR = optsSweepBase;
optsSaprR.enableMiddleHelperSwap = true;
optsSaprR.excelPath = char(FullPowerSweepDataPathLocal(file_path, ...
    numUsersPerSat, 'RelayWithMiddleSwap', '.xlsx', pathEpfdThr));
RunFullPowerAggregateShutdownSweepExcel(root, optsSaprR);
end
