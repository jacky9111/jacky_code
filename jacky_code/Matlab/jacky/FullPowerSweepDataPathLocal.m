function outPath = FullPowerSweepDataPathLocal(file_path, numUsersPerSat, nameStem, ext)
% FullPowerSweepDataPathLocal  Build Matlab_data path tagged by users-per-satellite.
% Example: FullPower_BeamShutdownSweep_GS01_U50_RelayOnly.xlsx
if nargin < 4 || isempty(ext)
    ext = '.xlsx';
end
userTag = sprintf('U%d', round(double(numUsersPerSat)));
baseName = sprintf('FullPower_BeamShutdownSweep_GS01_%s_%s%s', userTag, char(nameStem), char(ext));
outPath = fullfile(char(file_path), 'Matlab_data', baseName);
end
