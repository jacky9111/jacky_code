function mu_th_deg = pp_compute_mu_threshold(P)
%PP_COMPUTE_MU_THRESHOLD Compute off-axis threshold mu_th (Eq. (6) in paper).
%
% Solves for mu_th such that:
% 10*log10( Gn(mu_th)/Gn(0) ) = EPFD_th + 10*log10(4*pi*h^2*Bw/Bref) - EIRP - 10*log10(|Sf|)
%
% We use ITU-R S.1528 for Gn(.) in the minor axis and approximate h with LEO altitude.

rhs_dB = P.EPFD_th_dBW_m2_perBref ...
    + 10*log10(4*pi*(P.h_leo_km*1e3)^2 * (P.Bw_Hz/P.Bref_Hz)) ...
    - P.EIRP_dBW ...
    - 10*log10(P.beams_per_freq);

% rhs_dB is negative (attenuation relative to boresight)
target_rel_lin = 10^(rhs_dB/10);

% Monotone search over angle (0..90 deg) for relative gain close to target
f = @(mu) pp_itu_s1528_rel_gain(mu, P.mu_b_deg, P.S1528) - target_rel_lin;

% Bracket: start from 0 to 90
lo = 0; hi = 90;
flo = f(lo);
fhi = f(hi);
if flo < 0
    mu_th_deg = 0;
    return;
end
if fhi > 0
    mu_th_deg = 90;
    return;
end

% Bisection (robust; pattern is monotone decreasing)
for iter = 1:80
    mid = (lo + hi)/2;
    fmid = f(mid);
    if fmid > 0
        lo = mid;
    else
        hi = mid;
    end
end
mu_th_deg = (lo + hi)/2;
end

