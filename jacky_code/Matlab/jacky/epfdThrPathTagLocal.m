function tag = epfdThrPathTagLocal(epfdThr_dB)
% epfdThrPathTagLocal  Filename tag for an EPFD threshold (e.g. -173.4 -> Thr173p4).
tag = sprintf('Thr%s', strrep(strrep(sprintf('%.1f', double(epfdThr_dB)), '-', ''), '.', 'p'));
end
