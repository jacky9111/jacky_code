function outPath = ku16PcTiltExcelPathLocal(file_path, numUsersPerSat, epfdThr_dB)
% ku16PcTiltExcelPathLocal  Ku16 PC+Tilt log path tagged by U and optional EPFD threshold.
if nargin < 3
    epfdThr_dB = [];
end
userTag = sprintf('U%d', round(double(numUsersPerSat)));
if isempty(epfdThr_dB) || ~isfinite(epfdThr_dB)
    baseName = sprintf('LEO16_Ku_Baseline_Observation_PC_BaselineTilt_GS01_%s_Aligned.xlsx', userTag);
else
    baseName = sprintf('LEO16_Ku_Baseline_Observation_PC_BaselineTilt_GS01_%s_%s_Aligned.xlsx', ...
        userTag, epfdThrPathTagLocal(epfdThr_dB));
end
outPath = fullfile(char(file_path), 'Matlab_data', baseName);
end
