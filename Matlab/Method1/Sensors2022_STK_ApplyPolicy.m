function Sensors2022_STK_ApplyPolicy(mode, root, leoList, policyMatPath, stepSec)
% Sensors2022_STK_ApplyPolicy.m
% ------------------------------------------------------------
% Phase-2 (Online): Apply GA-derived policy (chi(psi), K(psi)) to STK
% by turning beams ON/OFF (no satellite attitude rotation required).
%
% Your STK setup:
% - */Satellite/<LEO>/Sensor/Beam_01 ... Beam_16
% - Beam_01 = northmost, Beam_16 = southmost
%
% Shutoff rule (paper intent): shut beams from the HIGH-LATITUDE side.
% - North hemisphere (phiS >= 0): shut Beam_01..Beam_K
% - South hemisphere (phiS < 0) : shut Beam_(N-K+1)..Beam_N
%
% USAGE:
%   Sensors2022_STK_ApplyPolicy('apply_policy', root, leoList, 'policy_Sensors2022.mat', 10);
%   Sensors2022_STK_ApplyPolicy('validate_policy', [],   [],     'policy_Sensors2022.mat', []);
%
% Notes:
% - 'validate_policy' currently uses a geometric approximation for mu_i^min.
%   It is useful for sanity-checking trends; strict Appendix-B compliance can be added later.
% ------------------------------------------------------------

if nargin < 1 || isempty(mode), mode = 'apply_policy'; end
if nargin < 5 || isempty(stepSec), stepSec = 10; end

cfg = defaultSensors2022Config();

switch lower(mode)
    case 'apply_policy'
        if nargin < 4
            error("apply_policy requires: root, leoList, policyMatPath, stepSec");
        end
        apply_policy(root, leoList, policyMatPath, stepSec, cfg);

    case 'validate_policy'
        if nargin < 4
            error("validate_policy requires: policyMatPath");
        end
        validate_policy(policyMatPath, cfg);

    otherwise
        error("Unknown mode: %s. Use 'apply_policy' or 'validate_policy'.", mode);
end
end

% ============================================================
% A) Apply policy to STK (beam ON/OFF)
% ============================================================
function apply_policy(root, leoList, policyMatPath, stepSec, cfg)

sc = root.CurrentScenario;

% ---- Load policy ----
S = load(policyMatPath);
policy = pickPolicyStruct(S);
[psi_grid_deg, chi_grid_deg, K_grid] = normalizePolicy(policy);

% ---- Preload STK providers & beam paths ----
[leoLlaDPs, beamMap] = preloadLeoBeams_STK(root, leoList, cfg.Nbeam);

% ---- Time loop ----
tStart = datenum(sc.StartTime);
tEnd   = datenum(sc.StopTime);
dt     = stepSec / 86400;

t = tStart;
while t <= tEnd
    tStr = datestr(t,'dd mmm yyyy HH:MM:SS');
    root.ExecuteCommand(['Animate * SetTime "' tStr '"']);
    fprintf("\n[Time] %s\n", tStr);

    for i = 1:numel(leoList)
        leoName = leoList{i};
        if ~isKey(beamMap, leoName), continue; end

        beamPaths = beamMap(leoName);
        N = numel(beamPaths);

        % --- 1) Read sub-sat latitude (signed) ---
        rawLat = stkGetLat_ExecSingle(leoLlaDPs(leoName), tStr);
        psi_deg = abs(rawLat);  % policy grid uses psi in [0, 90]

        % --- 2) Lookup policy (chi(psi), K(psi)) ---
        [chi_deg, K] = lookupPolicy(psi_deg, psi_grid_deg, chi_grid_deg, K_grid);
        K = max(0, min(cfg.Nbeam, round(K)));

        % --- 3) Determine OFF beams from HIGH-LATITUDE side ---
        if K <= 0
            offIdx = [];
        else
            if rawLat >= 0
                % North hemisphere: shut northmost beams
                offIdx = 1:K;
            else
                % South hemisphere: shut southmost beams
                offIdx = (cfg.Nbeam-K+1):cfg.Nbeam;
            end
        end

        % --- 4) Apply to STK ---
        for b = 1:N
            if any(b == offIdx)
                root.ExecuteCommand(sprintf('Graphics %s Show Off', beamPaths{b}));
                state = "OFF";
            else
                root.ExecuteCommand(sprintf('Graphics %s Show On', beamPaths{b}));
                state = "ON";
            end

            % Print a few representative beams only (avoid flooding)
            if b == 1 || b == K || b == K+1 || b == N
                fprintf("  %-10s | lat=%.2f | psi=%.2f | chi=%.2f | K=%d | Beam_%02d=%s\n", ...
                    leoName, rawLat, psi_deg, chi_deg, K, b, state);
            end
        end
    end

    pause(cfg.pauseSec);
    t = t + dt;
end
end

% ============================================================
% B) Validate policy with approximate mu_i^min >= mu_th (optional)
% ============================================================
function validate_policy(policyMatPath, cfg)

S = load(policyMatPath);
policy = pickPolicyStruct(S);
[psi_grid_deg, chi_grid_deg, K_grid] = normalizePolicy(policy);

fprintf("\n=== Validate policy (approx): check mu_min >= mu_th ===\n");
fprintf("mu_th=%.2f deg | mu_b=%.2f deg | N=%d | chi_max=%.2f deg\n", ...
    cfg.mu_th_deg, cfg.mu_b_deg, cfg.Nbeam, cfg.chi_max_deg);
fprintf("sigma_max=%.2f deg | sigma_grid_N=%d\n\n", cfg.sigma_max_deg, cfg.sigma_grid_N);

sigma_samples = linspace(-cfg.sigma_max_deg, cfg.sigma_max_deg, cfg.sigma_grid_N);

violate_count = 0;

for idx = 1:numel(psi_grid_deg)
    psi = psi_grid_deg(idx);
    chi = chi_grid_deg(idx);
    K   = K_grid(idx);

    K = max(0, min(cfg.Nbeam, round(K)));

    % Active beams: i > K  => i in [K+1..N]
    active_i = (K+1):cfg.Nbeam;
    if isempty(active_i)
        continue;
    end

    mu_min_all = inf(1, numel(active_i));
    for k = 1:numel(active_i)
        ii = active_i(k);
        mu_min_all(k) = mu_i_min_over_sigma_approx(psi, chi, ii, sigma_samples, cfg);
    end

    mu_worst = min(mu_min_all);
    ok = (mu_worst >= cfg.mu_th_deg);

    if ~ok, violate_count = violate_count + 1; end

    if idx == 1 || mod(idx, 10) == 0 || ~ok
        fprintf("psi=%6.2f | chi=%5.2f | K=%2d | worst_mu=%.2f | %s\n", ...
            psi, chi, K, mu_worst, ternary(ok,"OK","VIOLATE"));
    end
end

fprintf("\nDone. violate_count=%d (out of %d psi points)\n", violate_count, numel(psi_grid_deg));
end

% ============================================================
% Approx geometry for mu_i^min over sigma (sanity-check)
% ============================================================
function muMin = mu_i_min_over_sigma_approx(psi_deg, chi_deg, iBeam, sigma_deg_list, cfg)
% Approximation:
% - Build a simple satellite position in a meridian plane (lon=0)
% - Build a beam boresight direction in the N-S plane:
%     alpha_i = chi + (2i - N - 1)*mu_b
%   interpreted as rotating from nadir toward SOUTH by alpha_i
% - Place ES points on Earth surface at equator and longitude sigma
% - mu_i = angle(boresight, ES direction), then min over sigma
%
% This is for trend checking. For strict paper Appendix-B compliance,
% replace with exact coordinate transforms and minor-axis off-axis definition.

alpha_i = chi_deg + (2*iBeam - cfg.Nbeam - 1) * cfg.mu_b_deg;  % deg

Re = cfg.Re_km;
h  = cfg.h_leo_km;
rS = Re + h;

psi = deg2rad(psi_deg);
r_sat = [rS*cos(psi); 0; rS*sin(psi)];

% Local basis at satellite
e_r     = r_sat / norm(r_sat);     % outward radial
e_nadir = -e_r;                    % nadir
e_north = [-sin(psi); 0; cos(psi)];% tangent north in meridian plane
e_south = -e_north;

theta = deg2rad(alpha_i);
u_beam = cos(theta)*e_nadir + sin(theta)*e_south; % unit

% ES at equator, Earth surface, varying longitude sigma
r_es = Re * [cosd(sigma_deg_list); sind(sigma_deg_list); zeros(size(sigma_deg_list))]; % 3 x Ns

v_es = r_es - r_sat;                 % 3 x Ns
v_es = v_es ./ vecnorm(v_es,2,1);    % normalize

dotv = u_beam.' * v_es;              % 1 x Ns
dotv = max(-1, min(1, dotv));
mu_list = acosd(dotv);

muMin = min(mu_list);
end

% ============================================================
% Config (paper + knobs)
% ============================================================
function cfg = defaultSensors2022Config()
cfg.Nbeam = 16;

% OneWeb standard altitude
cfg.h_leo_km = 1200;

% Earth radius (use one consistently)
cfg.Re_km = 6371;

% Paper parameters (Table-style)
cfg.mu_b_deg  = 2.98;
cfg.nu_b_deg  = 47.6;     %#ok<NASGU> (not used in this approx)
cfg.mu_th_deg = 11.5;
cfg.chi_max_deg = 18;

% sigma range (paper defines |sigma|<sigma_max; set here)
cfg.sigma_max_deg = 81;   % adjust when you confirm paper's sigma_max
cfg.sigma_grid_N  = 361;

cfg.pauseSec = 0.01;
end

% ============================================================
% STK preload
% ============================================================
function [leoLlaDPs, beamMap] = preloadLeoBeams_STK(root, leoList, Nbeam)

leoLlaDPs = containers.Map;
beamMap   = containers.Map;

beamNames = arrayfun(@(k) sprintf('Beam_%02d',k), 1:Nbeam, 'UniformOutput', false);

for i = 1:numel(leoList)
    leoName = leoList{i};
    satObj = root.GetObjectFromPath(['*/Satellite/' leoName]);

    leoLlaDPs(leoName) = satObj.DataProviders.Item('LLA State').Group.Item('Fixed');

    beams = cell(1, Nbeam);
    ok = true;
    for b = 1:Nbeam
        beamPath = sprintf('*/Satellite/%s/Sensor/%s', leoName, beamNames{b});
        try
            root.GetObjectFromPath(beamPath);
            beams{b} = beamPath;
        catch
            ok = false;
            break;
        end
    end
    if ok
        beamMap(leoName) = beams;
    end
end
end

% ============================================================
% Policy loader / normalizer
% ============================================================
function policy = pickPolicyStruct(S)
cands = {'policy','Policy','bestPolicy','optPolicy'};
for i = 1:numel(cands)
    if isfield(S, cands{i})
        policy = S.(cands{i});
        return;
    end
end
policy = S;
end

function [psi_grid_deg, chi_grid_deg, K_grid] = normalizePolicy(policy)
psi_grid_deg = pickField(policy, {'psi_grid_deg','psiGrid','psi','Psi','psi_deg'});
chi_grid_deg = pickField(policy, {'chi_deg','chi','Chi','pitch_deg','pitch'});
K_grid       = pickField(policy, {'K','k','K_deg','K_grid'});

psi_grid_deg = psi_grid_deg(:).';
chi_grid_deg = chi_grid_deg(:).';
K_grid       = K_grid(:).';

if ~(numel(psi_grid_deg)==numel(chi_grid_deg) && numel(psi_grid_deg)==numel(K_grid))
    error("Policy length mismatch: psi=%d, chi=%d, K=%d", ...
        numel(psi_grid_deg), numel(chi_grid_deg), numel(K_grid));
end
end

function v = pickField(S, names)
for i = 1:numel(names)
    if isfield(S, names{i})
        v = S.(names{i});
        return;
    end
end
error("Policy missing required field. Tried: %s", strjoin(names, ', '));
end

function [chi_deg, K] = lookupPolicy(psi_deg, psi_grid_deg, chi_grid_deg, K_grid)
[~, idx] = min(abs(psi_grid_deg - psi_deg));
chi_deg = chi_grid_deg(idx);
K = K_grid(idx);
end

% ============================================================
% STK DataProvider extraction
% ============================================================
function lat = stkGetLat_ExecSingle(dpLLA, tStr)
res = dpLLA.ExecSingle(tStr);
arr = res.DataSets.ToArray;
lat = stkGetLat_FromArray(arr);
end

function lat = stkGetLat_FromArray(arr)
vals = [];
for k = 1:numel(arr)
    a = arr{k};
    if isnumeric(a) && isscalar(a)
        vals(end+1,1) = double(a); %#ok<AGROW>
    end
end
if isempty(vals)
    error('STK LLA extraction failed: no numeric scalars found.');
end
lat = vals(1);
end

% ============================================================
% Utils
% ============================================================
function out = ternary(cond, a, b)
if cond, out = a; else, out = b; end
end
