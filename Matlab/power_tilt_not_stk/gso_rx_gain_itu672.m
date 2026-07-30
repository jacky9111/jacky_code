function G_rel_dB = gso_rx_gain_itu672(psi_deg, D_m, lambda_m)
% ITU-R S.672-like reference receive antenna pattern (paper Eq.(9)-(10))
%
% IMPORTANT:
% In the EPFD definition, the paper uses the *relative* receive gain:
%   G_r(psi) / G_r,max
% i.e., 0 dB at boresight.
%
% This function returns that relative gain in dB (<= 0 dB).

psi = psi_deg;

Gmax = 20*log10(D_m/lambda_m) + 7.7;
G1 = 29 - 25*log10(95*lambda_m/D_m);
psi_m = (20*lambda_m/D_m) * sqrt(Gmax - G1); % in degrees (as paper)

if psi < 0
    psi = 0;
end

if psi <= psi_m
    G_dBi = Gmax - 0.0025*(psi*D_m/lambda_m)^2;
elseif psi <= (95*lambda_m/D_m)
    G_dBi = G1;
elseif psi <= 33.1
    G_dBi = 29 - 25*log10(psi);
elseif psi <= 80
    G_dBi = -9;
elseif psi <= 120
    G_dBi = -4;
else
    G_dBi = -9;
end

% convert to relative gain (ratio to boresight)
G_rel_dB = G_dBi - Gmax;

end
