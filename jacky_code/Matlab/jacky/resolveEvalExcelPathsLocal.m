function paths = resolveEvalExcelPathsLocal(file_path, numUsersPerSatPlot, epfdThr_dB)
% resolveEvalExcelPathsLocal  Build Evaluation excel paths for current U (and optional EPFD) tag.
if nargin < 3
    epfdThr_dB = [];
end

paths = struct();
paths.backoffOnly = char(FullPowerSweepDataPathLocal(file_path, ...
    numUsersPerSatPlot, 'BackoffOnly', '.xlsx', epfdThr_dB));
paths.relayOnly = char(FullPowerSweepDataPathLocal(file_path, ...
    numUsersPerSatPlot, 'RelayOnly', '.xlsx', epfdThr_dB));
paths.saprR = char(FullPowerSweepDataPathLocal(file_path, ...
    numUsersPerSatPlot, 'RelayWithMiddleSwap', '.xlsx', epfdThr_dB));
paths.pcTilt = char(ku16PcTiltExcelPathLocal(file_path, numUsersPerSatPlot, epfdThr_dB));
end
