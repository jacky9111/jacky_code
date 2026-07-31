function outPath = FullPowerSweepDataPathLocal(file_path, numUsersPerSat, nameStem, ext, epfdThr_dB)
% FullPowerSweepDataPathLocal  Build Matlab_data path tagged by users-per-satellite.
% Optional epfdThr_dB adds Thr* tag (fig.6): U50_Thr174p0_RelayOnly.xlsx
%
% 【中文說明】統一產生 Evaluation 的輸出檔路徑，全部落在 <file_path>\Matlab_data\。
% 命名規則（U 標籤讓不同 user 負載的結果不會互相覆蓋）：
%   無門檻標籤：FullPower_BeamShutdownSweep_GS01_U<U>_<nameStem><ext>
%   有門檻標籤：FullPower_BeamShutdownSweep_GS01_U<U>_Thr<門檻>_<nameStem><ext>
%
% nameStem 對應四個方法 / 各張圖：
%   'BackoffOnly'          Beam shutdown only 的模擬結果
%   'RelayOnly'            Only HBR 的模擬結果
%   'RelayWithMiddleSwap'  EABR 的模擬結果
%   'P03S49_*'             各張圖輸出的 .png / 對應數據 .xlsx
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
