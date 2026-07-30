function G_dBi = itur_sat_pattern_dBi(psi_deg, D_m, lambda_m, mode)
% ============================================================
% ITU-R style satellite antenna pattern
%
% Implements Eq.(7)(8) in the paper:
%   "Joint Power and Tilt Control in Satellite Constellation
%    for NGSO-GSO Interference Mitigation"
%
% INPUT
%   psi_deg   : off-axis angle (deg)
%   D_m       : antenna diameter (m)
%   lambda_m  : wavelength (m)
%   mode      : "LEO" or "GSO"
%
% OUTPUT
%   G_dBi     : antenna gain (dBi)
% ============================================================

psi = psi_deg(:);
psi = max(0, min(180, psi));   % clamp

% ---------- constants from paper ----------
z  = 1;
a  = 2.58;
b  = 6.32;
LF = 0;

switch upper(string(mode))
    case "LEO"
        LN = -15;
        alpha = 1.5;
    case "GSO"
        LN = -20;
        alpha = 2.0;
    otherwise
        error("mode must be 'LEO' or 'GSO'");
end

% ---------- max gain ----------
Gmax = 20*log10(D_m/lambda_m) + 7.7;

% half 3-dB beamwidth approximation
% full 3-dB beamwidth ≈ 70 * (lambda / D)
% psi_b = half beamwidth
psi_b = 0.5 * (70 * (lambda_m / D_m));   % deg

% ---------- helper thresholds ----------
X  = Gmax + LN + 25*log10(b*psi_b);
Y  = (b*psi_b) * 10^(0.04*(Gmax + LN - LF));
LB = max(0, 15 + LN + 0.25*Gmax + 5*log10(z));

G_dBi = zeros(size(psi));

% ---------- region definitions ----------
% Region 1: main lobe
idx1 = (psi <= a*psi_b);
G_dBi(idx1) = Gmax - 3*(psi(idx1)/psi_b).^alpha;

% Region 2
idx2 = (psi > a*psi_b) & (psi <= 0.5*b*psi_b);
G_dBi(idx2) = Gmax + LN + 20*log10(z);

% Region 3
idx3 = (psi > 0.5*b*psi_b) & (psi <= b*psi_b);
G_dBi(idx3) = Gmax + LN;

% Region 4
idx4 = (psi > b*psi_b) & (psi <= Y);
G_dBi(idx4) = X - 25*log10(psi(idx4));

% Region 5
idx5 = (psi > Y) & (psi <= 90);
G_dBi(idx5) = LF;

% Region 6
idx6 = (psi > 90) & (psi <= 180);
G_dBi(idx6) = LB;

end
