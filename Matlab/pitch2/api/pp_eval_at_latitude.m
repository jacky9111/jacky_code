function out = pp_eval_at_latitude(P, psi_deg, chi_deg, K, opts)
%PP_EVAL_AT_LATITUDE Evaluate constraints/metrics at a given satellite latitude.
%
% Uses a lightweight approximation of Eq. (15):
% - For each active beam, numerically integrate over latitude in orbit plane.
%
% Returns fields:
% - total_capacity (arbitrary units consistent across comparisons)
% - min_mu_active_deg (minimum minor-axis off-axis among active beams, inline sigma=0)
% - overlap_bounds: psi_up, psi_down

if nargin < 5 || isempty(opts)
    opts = struct();
end
if ~isfield(opts, 'sigma_deg') || isempty(opts.sigma_deg)
    opts.sigma_deg = 0;
end
if ~isfield(opts, 'n_x') || isempty(opts.n_x)
    opts.n_x = 11; % number of samples per beam for Eq. (15) integral
end

K = round(K);
K = max(min(K, P.Nbeam), 0);

% Coverage bounds for overlap constraint
[psi_up_deg, psi_down_deg] = pp_satellite_coverage_bounds(P, psi_deg, chi_deg, K);

% Interference metric: min off-axis mu among active beams (inline event)
min_mu = inf;
for iBeam = (K+1):P.Nbeam
    [mu_i, ~] = pp_offaxis_angles_inline(P, psi_deg, chi_deg, iBeam, opts.sigma_deg);
    % Paper constraints are on off-axis separation magnitude.
    min_mu = min(min_mu, abs(mu_i));
end

% Capacity evaluation (numerical integral approximation of Eq. (15))
f_Hz = P.f_GHz * 1e9;

N0 = P.kB * P.noise_T_K; % W/Hz
noise_W = N0 * P.Bw_Hz;

total_cap = 0;
activeBeams = (K+1):P.Nbeam;

% Precompute boresight elevations for all beams (needed for cochannel interference)
alpha_c = zeros(1, P.Nbeam);
for j = 1:P.Nbeam
    alpha_c(j) = chi_deg + (2*j - P.Nbeam - 1) * P.mu_b_deg;
end

for iBeam = activeBeams
    B = pp_beam_bounds(P, psi_deg, chi_deg, iBeam);
    if B.width_deg <= 0 || opts.n_x < 2
        continue;
    end

    % Integrate over latitude within beam boundaries (orbit-plane)
    x1 = min(B.psi_up_deg, B.psi_down_deg);
    x2 = max(B.psi_up_deg, B.psi_down_deg);
    xs = linspace(x1, x2, opts.n_x);

    % Co-frequency set id for iBeam
    fId = pp_beam_freq_id(P, iBeam);

    integrand = zeros(size(xs));
    for ix = 1:numel(xs)
        x_deg = xs(ix);
        alpha_x_deg = pp_elevation_from_lat(P, psi_deg, x_deg);

        % Distance satellite -> ground point at latitude x (orbit plane geometry)
        theta_deg = abs(psi_deg - x_deg);
        d_km = sqrt(P.Rn_km^2 + P.Re_km^2 - 2*P.Rn_km*P.Re_km*cosd(theta_deg));
        d_m = d_km * 1e3;
        fspl_lin = (P.c / (4*pi*d_m*f_Hz))^2;

        % Signal gain (relative to boresight), Gn(|alpha_i - alpha(x)|)
        psi_sig = abs(alpha_c(iBeam) - alpha_x_deg);
        g_sig = pp_itu_s1528_rel_gain(psi_sig, P.mu_b_deg, P.S1528);

        % Co-frequency interference, sum over other active beams with same frequency
        interf_sum = 0;
        for jBeam = activeBeams
            if jBeam == iBeam
                continue;
            end
            if pp_beam_freq_id(P, jBeam) ~= fId
                continue;
            end
            psi_int = abs(alpha_c(jBeam) - alpha_x_deg);
            interf_sum = interf_sum + pp_itu_s1528_rel_gain(psi_int, P.mu_b_deg, P.S1528);
        end

        % Received signal/interference scale with EIRP * gain * FSPL (common receive gain cancels in SINR)
        S_W = P.EIRP_W * g_sig * fspl_lin;
        I_W = P.EIRP_W * interf_sum * fspl_lin;
        sinr = S_W / (noise_W + I_W);

        integrand(ix) = log2(1 + sinr);
    end

    % Eq. (15): c_i(psi) = Bw * ∫ log2(1+SINR) dx
    ci = P.Bw_Hz * trapz(xs, integrand);
    total_cap = total_cap + ci;
end

out.total_capacity = total_cap;
out.min_mu_active_deg = min_mu;
out.psi_up_deg = psi_up_deg;
out.psi_down_deg = psi_down_deg;
end

