function paths = resolveEvalExcelPathsLocal(file_path, numUsersPerSatPlot, epfdThr_dB)
% resolveEvalExcelPathsLocal  Build Evaluation excel paths for current U (and optional EPFD) tag.
%
% 【中文說明】一次算出畫圖階段要用的四份 Excel 路徑，避免在 jacky.m 裡到處手寫路徑
% 而混用到不同 U 的結果（例如畫 U70 的圖卻讀到 U30 的檔案）。
%
% 回傳 struct 欄位 → 論文方法：
%   paths.backoffOnly  Beam shutdown only
%   paths.pcTilt       PC + Tilt
%   paths.relayOnly    Only HBR
%   paths.saprR        EABR（程式舊名 SAPR-R = Relay + middle swap）
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
