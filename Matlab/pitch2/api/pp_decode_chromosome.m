function S = pp_decode_chromosome(P, genes)
%PP_DECODE_CHROMOSOME Decode GA chromosome to pitch/closed-beams vs latitude.
%
% genes: 1xNpsi integer values in {1,2,3,4}
%   1: no adjustment
%   2: slow pitch increase (+dchi_slow)
%   3: fast pitch increase (+dchi_fast)
%   4: close one additional beam (K += 1)
%
% Decoding follows paper Section 3.4: latitude grid 90 - l*dpsi.

if numel(genes) ~= P.Npsi
    error('Expected %d genes, got %d.', P.Npsi, numel(genes));
end
genes = reshape(genes, 1, []);

lat_desc = 90:-P.dpsi_deg:0; % length Npsi+1
chi_desc = zeros(size(lat_desc));
K_desc = zeros(size(lat_desc));

chi = 0;
K = 0;

for l = 1:P.Npsi
    g = genes(l);
    switch g
        case 1
            % no-op
        case 2
            chi = chi + P.dchi_slow_deg;
        case 3
            chi = chi + P.dchi_fast_deg;
        case 4
            K = K + 1;
        otherwise
            error('Invalid gene value %g at index %d.', g, l);
    end

    % Enforce paper constraints (Eq. (18a), (18b)) by saturation.
    chi = max(0, min(chi, P.chi_max_deg));
    K = max(0, min(K, P.Nbeam));

    chi_desc(l+1) = chi;
    K_desc(l+1) = K;
end

% Provide both descending (90->0) and ascending (0->90) views
S.lat_desc = lat_desc;
S.chi_desc = chi_desc;
S.K_desc = K_desc;

S.lat_asc = fliplr(lat_desc);
S.chi_asc = fliplr(chi_desc);
S.K_asc = fliplr(K_desc);
end

