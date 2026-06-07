function outPath = FullPowerSweepDataPathLocal(file_path, numUsersPerSat, nameStem, ext, epfdThr_dB)
% FullPowerSweepDataPathLocal  Build Matlab_data path tagged by users-per-satellite.
% Optional epfdThr_dB adds Thr* tag (fig.6): U50_Thr174p0_RelayOnly.xlsx
if nargin < 4 || isempty(ext)
    ext = '.xlsx';
end
if nargin < 5
    epfdThr_dB = [];
end
userTag = sprintf('U%d', round(double(numUsersPerSat)));
if isempty(epfdThr_dB) || ~isfinite(epfdThr_dB)
    baseName = sprintf('FullPower_BeamShutdownSweep_GS01_%s_%s%s', userTag, char(nameStem), char(ext));
else
    thrTag = epfdThrPathTagLocal(epfdThr_dB);
    baseName = sprintf('FullPower_BeamShutdownSweep_GS01_%s_%s_%s%s', ...
        userTag, thrTag, char(nameStem), char(ext));
end
outPath = fullfile(char(file_path), 'Matlab_data', baseName);
end
