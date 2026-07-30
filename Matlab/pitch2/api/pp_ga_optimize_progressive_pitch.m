function best = pp_ga_optimize_progressive_pitch(P, opts)
%PP_GA_OPTIMIZE_PROGRESSIVE_PITCH Genetic algorithm for progressive pitch (Section 3).
%
% This implements a lightweight version of the paper's GA using our capacity approximation.

if nargin < 2 || isempty(opts)
    opts = struct();
end
if ~isfield(opts, 'rng_seed') || isempty(opts.rng_seed)
    opts.rng_seed = 1;
end
if ~isfield(opts, 'verbose') || isempty(opts.verbose)
    opts.verbose = true;
end
if ~isfield(opts, 'verbose_every') || isempty(opts.verbose_every)
    opts.verbose_every = 10; % print every N generations
end

rng(opts.rng_seed);

mu_th_deg = pp_compute_mu_threshold(P);
if opts.verbose
    fprintf('[pitch2] Computed mu_th = %.2f deg (Table 2: %.2f deg)\n', mu_th_deg, P.mu_th_deg_table);
end

G = P.Npsi;
popN = P.GA.pop_size;

% Population: popN x G integers in {1,2,3,4}
pop = randi(4, popN, G);

fitness = -inf(popN, 1);
evalCache = cell(popN, 1);

% Helper to evaluate one individual
    function [fit, R] = eval_individual(genes)
        S = pp_decode_chromosome(P, genes);
        R = pp_evaluate_schedule(P, S.lat_asc, S.chi_asc, S.K_asc, mu_th_deg);
        base = R.avg_capacity;
        penalty_per = max(1, abs(base)) * 1e3; % strong penalty
        fit = base - penalty_per * R.violations.total;
    end

best.fit = -inf;
best.genes = [];
best.S = [];
best.R = [];
best.mu_th_deg = mu_th_deg;
best.history.best_fit = zeros(P.GA.generations, 1);
best.history.best_avg_capacity = zeros(P.GA.generations, 1);
best.history.best_violations = zeros(P.GA.generations, 1);

eliteN = max(1, round(P.GA.election_rate * popN));

t0 = tic;
for gen = 1:P.GA.generations
    % Evaluate population
    for n = 1:popN
        [fitness(n), evalCache{n}] = eval_individual(pop(n, :));
    end

    [fitness, order] = sort(fitness, 'descend');
    pop = pop(order, :);
    evalCache = evalCache(order);

    % Track best
    if fitness(1) > best.fit
        best.fit = fitness(1);
        best.genes = pop(1, :);
        best.S = pp_decode_chromosome(P, best.genes);
        best.R = evalCache{1};
    end
    best.history.best_fit(gen) = best.fit;
    best.history.best_avg_capacity(gen) = best.R.avg_capacity;
    best.history.best_violations(gen) = best.R.violations.total;

    if opts.verbose && (gen == 1 || mod(gen, opts.verbose_every) == 0 || gen == P.GA.generations)
        elapsed_s = toc(t0);
        rate = elapsed_s / max(gen, 1);
        eta_s = rate * (P.GA.generations - gen);
        fprintf('[pitch2] Gen %3d/%3d | bestFit=%.3e | avgCap=%.3e | viol=%d | elapsed=%.1fs | ETA=%.1fs\n', ...
            gen, P.GA.generations, best.fit, best.R.avg_capacity, best.R.violations.total, elapsed_s, eta_s);
        drawnow('limitrate');
    end

    % Selection: keep elites
    elites = pop(1:eliteN, :);

    % Create offspring
    newPop = zeros(popN, G);
    newPop(1:eliteN, :) = elites;

    for n = (eliteN+1):popN
        % choose two parents from elites
        p1 = elites(randi(eliteN), :);
        p2 = elites(randi(eliteN), :);

        child = p2;
        j0 = randi(G); % ensure at least one gene from p1 (Eq. 23)
        for l = 1:G
            if (rand <= P.GA.crossover_rate) || (l == j0)
                child(l) = p1(l);
            end
        end

        % Mutation: per-gene random replacement with rate
        for l = 1:G
            if rand <= P.GA.mutation_rate
                choices = [1,2,3,4];
                choices(choices == child(l)) = [];
                child(l) = choices(randi(3));
            end
        end

        newPop(n, :) = child;
    end

    pop = newPop;
end

% Final decode/eval for best (ensure consistent)
best.S = pp_decode_chromosome(P, best.genes);
best.R = pp_evaluate_schedule(P, best.S.lat_asc, best.S.chi_asc, best.S.K_asc, mu_th_deg);
end

