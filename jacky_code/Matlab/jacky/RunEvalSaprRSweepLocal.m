function RunEvalSaprRSweepLocal(root, file_path, evalEnv, evalUserAreaSide_km, ...
    numUsersPerSat, epfdThr_dB, useEpfdThrTagInPaths)
% RunEvalSaprRSweepLocal  SAPR-R sweep only (fig.6 EPFD sensitivity).
%
% 【中文說明】只跑 EABR（程式中舊名 SAPR-R = Relay + middle safe-beam swap）一個方法，
% 專供論文圖六「不同 EPFD 門檻對使用者滿意度的影響」使用。
%
% 為什麼要獨立一支？圖六是「固定 user 數（U70）× 掃多個 EPFD 門檻」，
% 只需要 EABR 一條線，不必重跑另外三個方法，可省下大量模擬時間。
%
% 檔名會帶 Thr 標籤以免覆蓋 baseline 結果，例如
%   EPFD -172.4 → FullPower_BeamShutdownSweep_GS01_U70_Thr172p4_RelayWithMiddleSwap.xlsx
% 注意 -173.4（baseline）那條線由 RunEvalFourMethodSweepsLocal 產生，
% 檔名不帶 Thr 標籤，jacky.m 的圖六迴圈會自動跳過重跑。

evalEnv.params.EPFD_thr_dB = double(epfdThr_dB);   % 本次要掃的 EPFD 門檻
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
optsSaprR.enableRelay = true;                        % 開 HBR
optsSaprR.relayMinNativeSat = 0.9;                   % helper 自家 user 滿意度門檻
optsSaprR.relayMinRelayAvgSat = 0.9;                 % 救援成功判定門檻
optsSaprR.relayPowerShiftMode = "overlapCapped";     % 功率轉移以重疊覆蓋為上限
optsSaprR.enableMiddleHelperSwap = true;             % 開 SBR → 這才是完整的 EABR
optsSaprR.excelPath = char(FullPowerSweepDataPathLocal(file_path, ...
    numUsersPerSat, 'RelayWithMiddleSwap', '.xlsx', pathEpfdThr));
RunFullPowerAggregateShutdownSweepExcel(root, optsSaprR);
end
