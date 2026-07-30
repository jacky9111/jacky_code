function fId = pp_beam_freq_id(P, iBeam)
%PP_BEAM_FREQ_ID Simple reuse mapping: mod pattern with Mfreq=8.
% For Nbeam=16, this pairs (1,9), (2,10), ... (8,16).
fId = mod(iBeam-1, P.Mfreq) + 1;
end

