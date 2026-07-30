function g_rel_lin = pp_itu_s1528_rel_gain(Psi_deg, Psi_b_deg, S1528)
%PP_ITU_S1528_REL_GAIN Relative gain (linear) per ITU-R S.1528 envelope.
%
% Returns g_rel_lin = Gn(Psi)/Gn(0) in linear units, so g_rel_lin(0)=1.
% Psi_deg can be scalar or array (degrees, >=0).
%
% Paper uses Eq. (1) with LN=-25 and z=1 for the minor axis.

Psi_deg = abs(Psi_deg);

LN = S1528.LN_dB;
z = S1528.z;
a = S1528.a;
b = S1528.b;
alpha = S1528.alpha;
LF = S1528.LF_dB;
LB = S1528.LB_dB;

% Avoid division by zero in log expressions
Psi_safe = max(Psi_deg, 1e-12);

% We compute relative gain in dB: Gn(Psi) - Gn(0).
g_rel_dB = zeros(size(Psi_deg));

% Region boundaries (degrees)
Psi1 = a * Psi_b_deg;
Psi2 = 0.5 * b * Psi_b_deg;
Psi3 = b * Psi_b_deg;

% Region 1: mainlobe roll-off
idx1 = (Psi_deg > 0) & (Psi_deg <= Psi1);
g_rel_dB(idx1) = -3 * (Psi_deg(idx1) ./ Psi_b_deg) .^ alpha;

% Region 2: near-in sidelobe mask
idx2 = (Psi_deg > Psi1) & (Psi_deg <= Psi2);
g_rel_dB(idx2) = LN + 25*log10(z);

% Region 3: constant sidelobe
idx3 = (Psi_deg > Psi2) & (Psi_deg <= Psi3);
g_rel_dB(idx3) = LN;

% Region 4: far-out sidelobe roll-off
idx4 = (Psi_deg > Psi3) & (Psi_deg <= 90);
g_rel_dB(idx4) = LN + 25*log10((b*Psi_b_deg) ./ Psi_safe(idx4));

% Region 5/6: clamp for completeness (rarely used here)
idx5 = (Psi_deg > 90) & (Psi_deg <= 180);
g_rel_dB(idx5) = LB; % backlobe relative level

% If Psi is extremely large, keep LB
idx6 = Psi_deg > 180;
g_rel_dB(idx6) = LB;

% If LF/LB are given as absolute levels relative to peak, then relative is LF or LB.
% Our pattern is relative-to-peak already, so LF/LB apply directly.
% (We only used LB in region 5/6; LF is not needed when Region 4 extends to 90 deg.)
if any(idx5) && ~isfinite(LB)
    error('Invalid S.1528 backlobe level (LB).');
end
if any(idx4) && ~isfinite(LF)
    % no-op (LF not used)
end

g_rel_lin = 10.^(g_rel_dB/10);

% Ensure boresight exactly 1
g_rel_lin(Psi_deg == 0) = 1;
end

