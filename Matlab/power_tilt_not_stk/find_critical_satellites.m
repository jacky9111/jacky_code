function critIdx = find_critical_satellites(gamma_vec, zeta_thr)
% Algorithm 1: find critical satellites using gamma vector
% Condition: gamma_i / max(gamma) >= zeta_thr
g = gamma_vec(:);
gmax = max(g);

if ~isfinite(gmax) || gmax <= 0
    critIdx = [];
    return;
end

critIdx = find( (g ./ gmax) >= zeta_thr );

fprintf('[Critical] zeta_thr=%.2f | critical=%d/%d\n', zeta_thr, numel(critIdx), numel(g));
end