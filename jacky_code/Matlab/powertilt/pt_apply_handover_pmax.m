function P_out = pt_apply_handover_pmax(P_in, Nvis, sat_k_list)
P_out = P_in;
if Nvis <= 0
    return;
end
P_out.Pmax_W_vec = P_in.Pmax_W * ones(Nvis, 1);
if isempty(sat_k_list)
    return;
end
sat_k = unique(sat_k_list(:));
sat_k = sat_k(isfinite(sat_k) & sat_k >= 1 & sat_k <= Nvis);
if ~isempty(sat_k)
    P_out.Pmax_W_vec(sat_k) = inf;
end
end
