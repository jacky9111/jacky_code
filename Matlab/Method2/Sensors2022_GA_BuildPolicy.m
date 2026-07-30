function Sensors2022_GA_BuildPolicy(mode)
% Sensors2022_GA_BuildPolicy.m
% ------------------------------------------------------------
% Offline GA to build policy {chi(psi), K(psi)}
% Based on Sensors 2022 paper (progressive pitch + beam shut-off)
%
% Output:
%   policy_Sensors2022.mat
%
% Usage:
%   Sensors2022_GA_BuildPolicy('build_policy')
% ------------------------------------------------------------

if nargin < 1
    mode = 'build_policy';
end

switch lower(mode)
    case 'build_policy'
        policy = build_policy_offline();
        assignin('base', 'policy', policy);
        fprintf("Policy assigned to base workspace as variable 'policy'.\n");
    otherwise
        error("Unknown mode: %s", mode);
end
end

% ============================================================
% A) GA main
% ============================================================
function policy = build_policy_offline()

cfg = cfg_Sensors2022();

% Gene length along psi-axis
P = cfg.P;

% Action space:
% 1 = no change
% 2 = slow pitch increase
% 3 = fast pitch increase
% 4 = close one beam
A = 4;

% Initial population
pop = randi(A, cfg.popSize, P);

bestChrom = pop(1,:);
bestFit   = -inf;

for it = 1:cfg.iterMax

    fit = zeros(cfg.popSize,1);
    for m = 1:cfg.popSize
        fit(m) = fitness_Sensors2022(pop(m,:), cfg);
    end

    % Sort (maximize)
    [fit, idx] = sort(fit, 'descend');
    pop = pop(idx,:);

    if fit(1) > bestFit
        bestFit   = fit(1);
        bestChrom = pop(1,:);
    end

    % ---- Selection (elite 20%) ----
    eliteN = max(1, round(0.2 * cfg.popSize));
    elite  = pop(1:eliteN,:);
    newPop = elite(randi(eliteN, cfg.popSize, 1), :);

    % ---- Crossover ----
    for m = 1:2:cfg.popSize-1
        p1 = newPop(m,:);
        p2 = newPop(m+1,:);
        child = p1;

        forced = randi(P);
        for l = 1:P
            if rand <= cfg.CR || l == forced
                child(l) = p1(l);
            else
                child(l) = p2(l);
            end
        end
        newPop(m,:) = child;
    end

    % ---- Mutation ----
    for m = 1:cfg.popSize
        if rand < cfg.MR
            l = randi(P);
            newPop(m,l) = randi(A);
        end
    end

    pop = newPop;

    fprintf("Iter %03d | bestFit = %.6f\n", it, bestFit);
end

% Decode best chromosome
[chi, K] = decodeChromosome(bestChrom, cfg);

psiGrid = 90 - (1:cfg.P) * cfg.dPsi_deg;
psiGrid = max(psiGrid, 0);

policy = struct();
policy.psi_grid_deg   = psiGrid;
policy.chi_deg        = chi;
policy.K              = K;
policy.bestChromosome = bestChrom;
policy.bestFit        = bestFit;
policy.cfg            = cfg;

save(cfg.policyFile, 'policy');
fprintf("Saved policy to %s\n", cfg.policyFile);

end

% ============================================================
% B) Fitness function (paper logic)
% ============================================================
function fit = fitness_Sensors2022(S, cfg)

[chi, K] = decodeChromosome(S, cfg);

psiGrid = 90 - (1:cfg.P) * cfg.dPsi_deg;
psiGrid = max(psiGrid, 0);

penalty = 0;

% ---- Seamless coverage constraint (Eq.12 / Eq.19f) ----
L = max(1, round(cfg.delta_deg / cfg.dPsi_deg));

for p = 1:(cfg.P - L)

    [psi_up_p, ~] = coverageBounds(psiGrid(p),   chi(p),   K(p),   cfg);
    [~, psi_dn_n] = coverageBounds(psiGrid(p+L), chi(p+L), K(p+L), cfg);

    if (psi_up_p - psi_dn_n) < cfg.e_deg
        penalty = penalty + 1;
    end
end

% ---- Objective: maximize active beams ----
obj = mean(cfg.Nbeam - K);

fit = obj - cfg.penaltyWeight * (penalty / cfg.P);
end

% ============================================================
% C) Decode chromosome → chi(psi), K(psi)
% ============================================================
function [chi, K] = decodeChromosome(S, cfg)

chi = zeros(1, cfg.P);
K   = zeros(1, cfg.P);

chi_now = 0;
K_now   = 0;

for l = 1:cfg.P
    switch S(l)
        case 1 % no-op
        case 2 % slow pitch
            chi_now = chi_now + cfg.dChi_deg;
        case 3 % fast pitch
            chi_now = chi_now + cfg.fastFactor * cfg.dChi_deg;
        case 4 % close beam
            K_now = K_now + 1;
    end

    chi(l) = min(max(chi_now, 0), cfg.chi_max_deg);
    K(l)   = min(max(K_now, 0), cfg.Nbeam);
end
end

% ============================================================
% D) Coverage geometry (Eq.7–11)
% ============================================================
function [psi_up, psi_down] = coverageBounds(psi, chi, K, cfg)

alpha_up   = chi + (2*K - cfg.Nbeam) * cfg.mu_b_deg;
alpha_down = chi + (cfg.Nbeam)       * cfg.mu_b_deg;

psi_up   = psi - asind(cfg.k * sind(alpha_up));
psi_down = psi - asind(cfg.k * sind(alpha_down));
end

% ============================================================
% E) Config (Sensors 2022)
% ============================================================
function cfg = cfg_Sensors2022()

cfg.Nbeam = 16;

% Geometry
cfg.Re_km  = 6371;
cfg.h_km   = 1200;
cfg.k      = (cfg.Re_km + cfg.h_km) / cfg.Re_km;

% Beam parameters (Table 2)
cfg.mu_b_deg   = 2.98;
cfg.chi_max_deg = 18;

% Seamless coverage
cfg.delta_deg = 1.25;
cfg.e_deg     = 1.0;

% Psi grid
cfg.dPsi_deg = 1.25;
cfg.P        = ceil(90 / cfg.dPsi_deg);

% GA encoding
cfg.dChi_deg    = 0.5;
cfg.fastFactor  = 3;

% GA meta
cfg.popSize  = 60;
cfg.iterMax  = 80;
cfg.CR       = 0.9;
cfg.MR       = 0.2;

% Penalty
cfg.penaltyWeight = 1e6;

% Output
cfg.policyFile = 'policy_Sensors2022.mat';
end
