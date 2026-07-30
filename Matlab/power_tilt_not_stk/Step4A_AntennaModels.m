function out = Step4A_AntennaModels(geom, cfg)
% ============================================================
% Step 4-A (Paper replication): Antenna / Beam pattern models
%   - LEO satellite Tx pattern: Eq.(7)(8) with params in paper
%   - GSO satellite Tx pattern: Eq.(7) same form, different params
%   - Ground station Rx pattern: Eq.(9)(10)
%
% INPUT
%   geom : output from Step 3 (Compute_EPFD_Geometry)
%          required fields:
%            geom.phi_t_deg  : GS off-axis angle (GS->GEO vs GS->SAT)
%            geom.phi_r_deg  : Sat off-axis angle (Sat->User vs Sat->GS)
%   cfg  : struct with fields (recommended)
%          cfg.f_Hz                : carrier frequency (Hz)
%          cfg.leo_half3dB_deg     : LEO half 3dB beamwidth (deg) (paper uses 13.9)
%          cfg.gs_diam_m           : GS antenna diameter (m) (choose per your scenario)
%          cfg.use_beamwidth_to_D  : true/false. If true, estimate D from beamwidth.
%          cfg.leo_diam_m          : (optional) if known; overrides estimate
%
% OUTPUT
%   out : struct with
%     out.Gt_leo_dBi(N,1)   : LEO Tx gain toward GS direction (use geom.phi_r_deg)
%     out.Gr_gs_dBi(N,1)    : GS Rx gain toward sat direction (use geom.phi_t_deg)
%     out.Gr_gs_max_dBi     : GS maximum gain
%     out.meta              : config summary
%
% NOTE (mapping to paper EPFD eq.(2)):
%   - Paper uses Gt(phi_t_i) = satellite Tx gain toward GS
%     Here that angle is geom.phi_r_deg (sat boresight is to served user)
%   - Paper uses Gr(phi_r_i) = GS Rx gain toward satellite
%     Here that angle is geom.phi_t_deg (GS boresight is to GEO satellite)
% ============================================================

arguments
    geom struct
    cfg struct
end

% ---------- defaults ----------
if ~isfield(cfg,'f_Hz'), cfg.f_Hz = 20e9; end                 % Ka placeholder
if ~isfield(cfg,'leo_half3dB_deg'), cfg.leo_half3dB_deg = 13.9; end
if ~isfield(cfg,'gs_diam_m'), cfg.gs_diam_m = 2.4; end        % typical big dish
if ~isfield(cfg,'use_beamwidth_to_D'), cfg.use_beamwidth_to_D = true; end

c = 299792458;
lambda = c / cfg.f_Hz;

% LEO antenna diameter D (needed for Gmax in Eq.(8))
if isfield(cfg,'leo_diam_m') && ~isempty(cfg.leo_diam_m)
    D_leo = cfg.leo_diam_m;
elseif cfg.use_beamwidth_to_D
    % crude circular-aperture relation: theta_3dB(deg) ≈ 70 * (lambda / D)
    % paper gives half 3dB beamwidth; full 3dB = 2*half
    theta3 = 2 * cfg.leo_half3dB_deg;
    D_leo = 70 * lambda / theta3;
else
    error("Need cfg.leo_diam_m or set cfg.use_beamwidth_to_D=true");
end

D_gs = cfg.gs_diam_m;

% angles
phi_sat_deg = geom.phi_r_deg(:);   % sat off-axis toward GS
phi_gs_deg  = geom.phi_t_deg(:);   % GS off-axis toward sat
N = numel(phi_sat_deg);

% ---------- compute gains ----------
Gt_leo_dBi = itur_sat_pattern_dBi(phi_sat_deg, D_leo, lambda, "LEO");
Gr_gs_dBi  = itur_gs_pattern_dBi(phi_gs_deg, D_gs, lambda);

% GS max gain (Eq.(10) / same form as Eq.(8) Gmax)
Gr_gs_max_dBi = 20*log10(D_gs/lambda) + 7.7;

out.Gt_leo_dBi = Gt_leo_dBi;
out.Gr_gs_dBi  = Gr_gs_dBi;
out.Gr_gs_max_dBi = Gr_gs_max_dBi;

out.meta = struct();
out.meta.f_Hz = cfg.f_Hz;
out.meta.lambda_m = lambda;
out.meta.leo_half3dB_deg = cfg.leo_half3dB_deg;
out.meta.leo_D_m = D_leo;
out.meta.gs_D_m  = D_gs;
out.meta.N = N;

% ---------- quick demo plots (optional) ----------
if ~isfield(cfg,'do_plot'), cfg.do_plot = true; end
if cfg.do_plot
    figure; histogram(phi_gs_deg, 12);
    title('Step 4-A: GS off-axis angles used for Gr(\phi)'); xlabel('\phi_{GS} (deg)'); ylabel('Count');

    figure; histogram(phi_sat_deg, 12);
    title('Step 4-A: Sat off-axis angles used for Gt(\phi)'); xlabel('\phi_{SAT} (deg)'); ylabel('Count');

    figure; plot(phi_gs_deg, Gr_gs_dBi, '.');
    grid on; title('Ground station receive gain samples'); xlabel('\phi_{GS} (deg)'); ylabel('Gr_{GS} (dBi)');

    figure; plot(phi_sat_deg, Gt_leo_dBi, '.');
    grid on; title('LEO satellite transmit gain samples (toward GS)'); xlabel('\phi_{SAT} (deg)'); ylabel('Gt_{LEO} (dBi)');
end

fprintf("\n========== Step 4-A DONE (Antenna Models) ==========\n");
fprintf("N sats: %d\n", N);
fprintf("LEO D=%.3f m (from beamwidth=%g deg) | GS D=%.3f m | f=%.3f GHz\n", ...
    D_leo, cfg.leo_half3dB_deg, D_gs, cfg.f_Hz/1e9);
fprintf("Gt_leo(dBi): min=%.2f max=%.2f\n", min(Gt_leo_dBi), max(Gt_leo_dBi));
fprintf("Gr_gs(dBi):  min=%.2f max=%.2f (Gr_max=%.2f)\n\n", min(Gr_gs_dBi), max(Gr_gs_dBi), Gr_gs_max_dBi);

end

% ============================================================
% ITU-R style satellite pattern (paper Eq.(7)(8))
%   mode="LEO": LN=-15, LF=0, z=1, alpha=1.5, a=2.58, b=6.32
%   mode="GSO": LN=-20, LF=0, z=1, alpha=2.0, a=2.58, b=6.32
% ============================================================
function G_dBi = itur_sat_pattern_dBi(psi_deg, D_m, lambda_m, mode)
psi = psi_deg(:);
psi = max(0, min(180, psi)); % clamp

% constants from paper
z  = 1;
a  = 2.58;
b  = 6.32;
LF = 0;

switch upper(string(mode))
    case "LEO"
        LN = -15; alpha = 1.5;
    case "GSO"
        LN = -20; alpha = 2.0;
    otherwise
        error("mode must be 'LEO' or 'GSO'");
end

Gmax = 20*log10(D_m/lambda_m) + 7.7;

% Need psi_b = half 3dB beamwidth, but Eq.(7) uses psi_b explicitly.
% Paper sets psi_b as half of 3 dB beamwidth; here we approximate psi_b from aperture:
%   theta_3dB ≈ 70 * (lambda/D)  => psi_b ≈ 0.5*theta_3dB
psi_b = 0.5 * (70 * (lambda_m / D_m));   % deg

% Eq.(8) helpers
X  = Gmax + LN + 25*log10(b*psi_b);
Y  = (b*psi_b) * 10^(0.04*(Gmax + LN - LF));
LB = max(0, 15 + LN + 0.25*Gmax + 5*log10(z));

G_dBi = zeros(size(psi));

% region 1: main lobe to a*psi_b
idx1 = (psi <= a*psi_b);
G_dBi(idx1) = Gmax - 3*(psi(idx1)/psi_b).^alpha;

% region 2: a*psi_b < psi <= 0.5*b*psi_b
idx2 = (psi > a*psi_b) & (psi <= 0.5*b*psi_b);
G_dBi(idx2) = Gmax + LN + 20*log10(z);

% region 3: 0.5*b*psi_b < psi <= b*psi_b
idx3 = (psi > 0.5*b*psi_b) & (psi <= b*psi_b);
G_dBi(idx3) = Gmax + LN;

% region 4: b*psi_b < psi <= Y
idx4 = (psi > b*psi_b) & (psi <= Y);
G_dBi(idx4) = X - 25*log10(psi(idx4));

% region 5: Y < psi <= 90
idx5 = (psi > Y) & (psi <= 90);
G_dBi(idx5) = LF;

% region 6: 90 < psi <= 180
idx6 = (psi > 90) & (psi <= 180);
G_dBi(idx6) = LB;

end

% ============================================================
% ITU-R style earth-station receive pattern (paper Eq.(9)(10))
% ============================================================
function Gr_dBi = itur_gs_pattern_dBi(psi_deg, D_m, lambda_m)

psi = psi_deg(:);
psi = max(0, min(180, psi)); % clamp

Gr_max = 20*log10(D_m/lambda_m) + 7.7;
G1 = 29 - 25*log10(95*lambda_m/D_m);
psi_m = (20*lambda_m/D_m) * sqrt(Gr_max - G1);

Gr_dBi = zeros(size(psi));

idx1 = (psi <= psi_m);
Gr_dBi(idx1) = Gr_max - 0.0025*(psi(idx1)*D_m/lambda_m).^2;

idx2 = (psi > psi_m) & (psi <= 95*lambda_m/D_m);
Gr_dBi(idx2) = G1;

idx3 = (psi > 95*lambda_m/D_m) & (psi <= 33.1);
Gr_dBi(idx3) = 29 - 25*log10(psi(idx3));

idx4 = (psi > 33.1) & (psi <= 80);
Gr_dBi(idx4) = -9;

idx5 = (psi > 80) & (psi <= 120);
Gr_dBi(idx5) = -4;

idx6 = (psi > 120) & (psi <= 180);
Gr_dBi(idx6) = -9;

end
