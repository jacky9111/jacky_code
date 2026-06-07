function RunEvalSaprRSweepLocal(root, file_path, evalEnv, evalUserAreaSide_km, ...
    numUsersPerSat, epfdThr_dB, useEpfdThrTagInPaths)
% RunEvalSaprRSweepLocal  SAPR-R sweep only (fig.6 EPFD sensitivity).

evalEnv.params.EPFD_thr_dB = double(epfdThr_dB);
pathEpfdThr = [];
if nargin >= 7 && useEpfdThrTagInPaths
    pathEpfdThr = double(epfdThr_dB);
end

if isempty(pathEpfdThr)
    pathTagStr = "(none)";
else
    pathTagStr = char(epfdThrPathTagLocal(pathEpfdThr));
end
fprintf('Sweep SAPR-R: EPFD_thr=%.1f dB, U%d, pathTag=%s\n', ...
    double(epfdThr_dB), round(double(numUsersPerSat)), pathTagStr);

optsSaprR = struct();
optsSaprR = ApplyEvalEnvironmentToFullPowerSweep(optsSaprR, evalEnv, evalUserAreaSide_km);
optsSaprR.enableRelay = true;
optsSaprR.relayMinNativeSat = 0.9;
optsSaprR.relayMinRelayAvgSat = 0.9;
optsSaprR.relayPowerShiftMode = "overlapCapped";
optsSaprR.enableMiddleHelperSwap = true;
optsSaprR.excelPath = char(FullPowerSweepDataPathLocal(file_path, ...
    numUsersPerSat, 'RelayWithMiddleSwap', '.xlsx', pathEpfdThr));
RunFullPowerAggregateShutdownSweepExcel(root, optsSaprR);
end
