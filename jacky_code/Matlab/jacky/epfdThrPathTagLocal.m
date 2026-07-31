function tag = epfdThrPathTagLocal(epfdThr_dB)
% epfdThrPathTagLocal  Filename tag for an EPFD threshold (e.g. -173.4 -> Thr173p4).
%
% 【中文說明】把 EPFD 門檻數值轉成可以安全放進檔名的標籤：
% 去掉負號、小數點換成 'p'。例：-173.4 → 'Thr173p4'、-170.4 → 'Thr170p4'。
% 圖六掃多個門檻時靠這個標籤區分不同的 Excel 輸出，避免互相覆蓋。
tag = sprintf('Thr%s', strrep(strrep(sprintf('%.1f', double(epfdThr_dB)), '-', ''), '.', 'p'));
end
