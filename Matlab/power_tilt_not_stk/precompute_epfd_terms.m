function E = precompute_epfd_terms(LEO, visIdx, gs, gso, P)
% ============================================================
% Paper-aligned EPFD precompute
% - Eq.(2): EPFD definition (linear sum, per bandwidth)
% - Eq.(13): Gt(phi) = A * exp(beta*phi)
% - Eq.(14)/(16): EPFD constraint using q_i and theta_i
% - Eq.(17): gamma-style contribution vector (relative importance)
%
% We compute EPFD in the same reference bandwidth as the paper:
%   dB(W/m^2/1MHz)
% i.e., linear EPFD is W/m^2 per 1 MHz.
% ============================================================

N = numel(visIdx);

phi_t = zeros(N,1);   % LEO tx off-boresight to GS (deg)
phi_r = zeros(N,1);   % GS rx off-axis from boresight(GSO) to LEO (deg)
d_m   = zeros(N,1);   % distance sat->GS (m)

r_gs  = gs.pos_ecef_km(:) * 1000;     % m
r_gso = gso.pos_ecef_km(:) * 1000;    % m

% GS boresight vector: GS -> GSO (points to desired GSO)
v_bore = (r_gso - r_gs);

% EPFD threshold: paper gives dB(W/m^2/1MHz)
EPFD_thr_lin_1MHz = 10^(P.EPFD_thr_dB/10);

% BWref: per paper Eq.(2) uses BW_ref in denominator.
% We set BWref_Hz = 1e6 (1 MHz) to match the paper's reference bandwidth.
BWref_Hz = P.BWref_Hz;  % set this to 1e6 in your P

% Precompute kappa_i = (A * (GGr/GGrmax)) / (BWref * 4*pi*d^2)
% units: 1/(m^2*Hz), multiplied by P_i (W) gives W/(m^2*Hz)
% then multiplying by BWref (=1MHz) yields W/m^2 per 1MHz (paper EPFD units)
kappa = zeros(N,1);
GGr_rel_lin = zeros(N,1);

for k = 1:N
    idx = visIdx(k);
    r_sat = LEO.pos_ecef_km(:,idx) * 1000; % m

    % sat -> GS vector
    v_ls = (r_gs - r_sat);
    d_m(k) = norm(v_ls);

    % sat nadir direction (sat -> Earth center)
    v_nadir = -r_sat;

    % phi_t: angle between nadir and sat->GS
    phi_t(k) = angle_deg(v_nadir, v_ls);

    % phi_r: angle at GS between boresight(GS->GSO) and GS->LEO
    v_gs_to_leo = (r_sat - r_gs);
    phi_r(k) = angle_deg(v_bore, v_gs_to_leo);

    % IMPORTANT:
    % Eq.(2) uses GGr(phi_r)/GGr_max. Your itu672 function should return
    % relative off-axis gain in dB (0 dB at boresight). That is exactly the ratio.
    % relative receive gain ratio (0 dB at boresight)
    GGr_rel_dB = gso_rx_gain_itu672(phi_r(k), P.D_ref_m, P.lambda);
    GGr_rel_lin(k) = 10^(GGr_rel_dB/10);

    % kappa_i = A * (GGr/GGrmax) / (BWref * 4*pi*d^2)
    kappa(k) = (P.A_fit * GGr_rel_lin(k)) / (BWref_Hz * 4*pi*d_m(k)^2);
end

% Eq.(17)-style "gamma vector" for critical selection:
% gamma_i proportional to kappa_i * exp(beta*phi_t)
gamma_base = kappa .* exp(P.beta_fit * phi_t);

E.N = N;
E.phi_t_deg = phi_t;
E.phi_r_deg = phi_r;
E.d_m = d_m;
E.kappa = kappa;
E.gamma_base = gamma_base;
E.EPFD_thr_lin = EPFD_thr_lin_1MHz;

end

function ang = angle_deg(a,b)
ang = acosd( max(-1,min(1, dot(a,b)/(norm(a)*norm(b))) ) );
end