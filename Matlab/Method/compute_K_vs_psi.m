function out = compute_K_vs_psi(psi_deg_vec, cfg)
% compute_K_vs_psi
% Scheme C core: progressive pitch + beam shutoff based on off-axis threshold.
%
% Inputs
%   psi_deg_vec : [Nx1] satellite sub-satellite latitude (deg), from STK
%   cfg         : struct, see default_cfg() below
%
% Outputs (struct out)
%   out.K        : [Nx1] number of beams to shut off (outermost first)
%   out.muMin    : [Nx1] minimum off-axis angle among active beams (deg)
%   out.chi      : [Nx1] pitch angle used (deg)
%   out.gamma    : [Nx1] off-nadir angle from sat to worst-case equator victim (deg)
%   out.activeIx : cell(N,1) active beam indices (after shutoff)
%
% Notes
%   - This implementation is STK-independent (STK only provides psi).
%   - Worst-case victim is assumed on equator inline with satellite longitude.

    arguments
        psi_deg_vec (:,1) double
        cfg struct
    end

    % --- Validate / fill defaults ---
    cfg = fill_defaults(cfg);

    N = numel(psi_deg_vec);
    K_all     = zeros(N,1);
    muMin_all = nan(N,1);
    chi_all   = nan(N,1);
    gamma_all = nan(N,1);
    activeIx  = cell(N,1);

    for k = 1:N
        psi = psi_deg_vec(k);

        % (1) progressive pitch law chi(psi)
        chi = cfg.pitchLaw(psi);          % deg
        chi = max(cfg.chiMin_deg, min(cfg.chiMax_deg, chi));
        chi_all(k) = chi;

        % (2) compute worst-case victim off-nadir angle gamma(psi)
        gamma = offNadir_to_equator_inline(abs(psi), cfg.RE_km, cfg.RS_km);
        gamma_all(k) = gamma;

        % (3) beam boresight angles (toward equator in N-S plane)
        %     effective boresight off-nadir toward equator:
        %       theta_i = beta_i + sgn * chi
        theta = cfg.betaTowardEquator_deg(:) + cfg.pitchSign * chi;  % [Nbeam x 1]

        % (4) Off-axis angle per beam (minor-axis plane)
        mu = abs(theta - gamma);  % deg, [Nbeam x 1]

        % (5) Shutoff policy: increase K until mu_min(active) >= mu_th
        K = 0;
        while true
            act = active_beam_indices(cfg, K); % indices of active beams
            if isempty(act)
                % all beams off (should not happen unless cfg allows)
                muMin = NaN;
                break;
            end
            muMin = min(mu(act));
            if muMin >= cfg.mu_th_deg
                break;
            end
            K = K + 1;
            if K >= cfg.Nbeam
                % safety stop
                K = cfg.Nbeam;
                break;
            end
        end

        K_all(k)     = K;
        muMin_all(k) = muMin;
        activeIx{k}  = active_beam_indices(cfg, K);
    end

    out = struct();
    out.K        = K_all;
    out.muMin    = muMin_all;
    out.chi      = chi_all;
    out.gamma    = gamma_all;
    out.activeIx = activeIx;
    out.cfg      = cfg;
end

% =========================
% Helpers
% =========================
function cfg = fill_defaults(cfg)
    def = default_cfg();

    fns = fieldnames(def);
    for i = 1:numel(fns)
        fn = fns{i};
        if ~isfield(cfg, fn) || isempty(cfg.(fn))
            cfg.(fn) = def.(fn);
        end
    end

    cfg.Nbeam = numel(cfg.betaTowardEquator_deg);

    % basic sanity
    if cfg.Nbeam <= 0
        error('cfg.betaTowardEquator_deg must be a non-empty vector.');
    end
    if ~isa(cfg.pitchLaw, 'function_handle')
        error('cfg.pitchLaw must be a function handle: chi = pitchLaw(psi).');
    end
end

function cfg = default_cfg()
    cfg = struct();

    % Earth / satellite geometry
    cfg.RE_km = 6378.137;

    % If you know OneWeb altitude h (km), set RS = RE + h.
    % Example: h ~ 1200 km => RS ~ 7578 km
    cfg.RS_km = 6378.137 + 1200;

    % Off-axis threshold from paper (OneWeb Ka-band)
    cfg.mu_th_deg = 11.5;

    % Beam boresight angles toward equator (deg, off-nadir, minor-axis plane)
    % IMPORTANT:
    % - This vector should be ordered from "most likely to be shut off first" to last.
    % - If paper says shut "outermost / highest-lat beams" first, put those FIRST.
    %
    % Below is a reasonable 16-beam placeholder using your earlier beta0/betaEllipse style:
    %   beta_i = beta0 - (2*i - 1)*betaEllipse
    beta0 = 24.5;
    dB    = 1.56;
    cfg.betaTowardEquator_deg = arrayfun(@(i) beta0 - (2*i - 1)*dB, 1:16).';

    % Pitch sign convention:
    % +1 means pitching toward equator increases boresight off-nadir toward equator.
    % If your later validation shows opposite, set -1.
    cfg.pitchSign = +1;

    % Pitch law chi(psi): placeholder (replace with digitized paper curve later)
    cfg.chiMin_deg = 0;
    cfg.chiMax_deg = 12;
    cfg.pitchLaw   = @pitch_law_piecewise;

    % Shutoff order:
    % 'fromStart' means we shut beams starting from index 1 upward (outermost first).
    % If your beam ordering is opposite, use 'fromEnd'.
    cfg.shutoffOrder = 'fromStart';
end

function chi = pitch_law_piecewise(psi_deg)
% Example progressive pitch law χ(ψ). Replace later with paper curve or optimizer.
    psi = abs(psi_deg);
    if psi >= 55
        chi = 0;
    elseif psi >= 40
        chi = (55 - psi) / (55 - 40) * 8; % linear up to 8 deg
    else
        chi = 8;
    end
end

function gamma = offNadir_to_equator_inline(delta_deg, RE, RS)
% Compute off-nadir angle gamma at satellite to a ground point on equator inline.
% delta_deg is central angle between sub-sat point and the equator point (deg).
%
% 2D meridian plane model:
%   Earth center at (0,0)
%   Satellite at (0, RS)
%   Ground point at (RE*sinδ, RE*cosδ)
% Nadir direction is towards Earth center (0,0): v_nadir = [0,0] - sat
% LOS to ground: v_los = gp - sat
% gamma = angle between v_los and v_nadir

    delta = deg2rad(delta_deg);

    sat = [0; RS];
    gp  = [RE*sin(delta); RE*cos(delta)];

    v_nadir = -sat;          % from sat to center
    v_los   = gp - sat;      % from sat to ground point

    gamma = angle_deg(v_los, v_nadir);
end

function act = active_beam_indices(cfg, K)
% Return indices of beams that remain ON after shutting off K beams.
    N = cfg.Nbeam;
    K = max(0, min(N, K));

    switch lower(cfg.shutoffOrder)
        case 'fromstart'
            act = (K+1):N;
        case 'fromend'
            act = 1:(N-K);
        otherwise
            error('cfg.shutoffOrder must be ''fromStart'' or ''fromEnd''.');
    end
end

function a = angle_deg(v1, v2)
% robust angle between 2D/3D vectors (deg)
    num = dot(v1, v2);
    den = norm(v1) * norm(v2) + eps;
    c   = num / den;
    c   = min(1, max(-1, c));
    a   = acosd(c);
end
