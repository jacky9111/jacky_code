function outPath = ku16PcTiltExcelPathLocal(file_path, numUsersPerSat, epfdThr_dB)
% ku16PcTiltExcelPathLocal  Ku16 PC+Tilt log path tagged by U and optional EPFD threshold.
%
% 【中文說明】PC + Tilt baseline 的 Excel 輸出路徑。因為它走的是另一個 runner
% （RunKu16BeamBaselineObservationLogExcel），檔名格式與其他三個方法不同：
%   LEO16_Ku_Baseline_Observation_PC_BaselineTilt_GS01_U<U>_Aligned.xlsx
% 圖三、圖五要用到這份檔；若缺檔，jacky.m 會警告並跳過該張圖。
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
