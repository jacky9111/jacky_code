function cfg = overhead_config()
%OVERHEAD_CONFIG Pure-MATLAB configuration for the online-runtime experiment.
% No STK is required. Geometry follows the OneWeb-like Walker used by
% helper_availability, with a local 25-satellite neighborhood around the GS.
%
% Timing methodology:
%   1) Search aggregate EPFD over a wide flyover window and pick t_worst.
%   2) Measure online runtime once per 1-s slot in [t_worst-30, t_worst+29]
%      (60 slots total). Bar = mean over slots; I = min–max over slots.

moduleDir = fileparts(mfilename('fullpath'));
matlabDir = fileparts(moduleDir);

cfg.moduleDir = moduleDir;
cfg.matlabDir = matlabDir;
cfg.resultsDir = fullfile(moduleDir, 'results');
cfg.userLoads = [30, 50, 70];
cfg.warmupRuns = 2;          % warm-up on first slot only (discarded)
cfg.randomSeed = 2026;

% Worst-EPFD search around the aligned overhead (t = 0).
cfg.epfdSearchStart_s = -120;
cfg.epfdSearchEnd_s = 120;
cfg.epfdSearchStep_s = 1;

% Measurement window relative to t_worst: 30 s before + 30 s after = 60 slots.
cfg.slotHalfWindow_s = 30;
cfg.slotStep_s = 1;
% I-bar on the figure uses these percentiles (not raw min/max), so a single
% pathological slot cannot dominate the whisker.
cfg.runtimeRangePercentiles = [10, 90];

% Local evaluation geometry (MATLAB-only Walker, aligned over GS at t = 0).
cfg.gsLat_deg = 0;
cfg.gsLon_deg = 120.4;
cfg.alt_km = 1200;
cfg.inclination_deg = 87.9;
cfg.nPlanes = 12;
cfg.nSatPerPlane = 49;
cfg.walkerType = 'star';
cfg.walkerPhasingF = 1;
cfg.refPlaneIndex = 3;
cfg.refSatIndex = 25;
cfg.nLocalSats = 25;   % same local neighborhood size as jacky.m satUserTargets

cfg.beamHalfEW_deg = 34.0;
cfg.beamHalfNS_deg = 33.5 / 16;
cfg.userAreaSide_km = max(2 * cfg.alt_km * tand(cfg.beamHalfEW_deg), ...
    2 * cfg.alt_km * tand(33.5));
cfg.userDemand_Mbps = 50;
cfg.fullBeamPower_W = 1.05;
cfg.maxBeamPower_W = 2.0;
cfg.epfdThreshold_dB = -173.4;
cfg.pcTiltMax_deg = 10;
% Tilt search for overhead timing (service sim may keep 0.5 deg in RunKu16).
% Jalali et al. specify max tilt but not online grid step; coarser step is
% used here for feasible 1-s-slot runtime measurement of the reproduced logic.
cfg.pcTiltStep_deg = 2.0;          % exhaustive mode: candidates per slot ~ 2*max/step + 1
% 'max_only' | 'coarse_to_fine' | 'exhaustive'
% max_only: if PC adjusted power, try only ±tiltMax (fastest overhead timing).
cfg.pcTiltSearchMode = 'max_only';
cfg.pcTiltCoarseStep_deg = 2.0;    % coarse-to-fine: first pass
cfg.pcTiltFineStep_deg = 0.5;      % coarse-to-fine: local refine
cfg.pcTiltFineHalfWidth_deg = 2.0; % refine in [best ± this]
cfg.nBeam = 16;
cfg.recoveryPowerPoolMode = "per_sat";

cfg.Re_km = 6378.137;
cfg.mu_km3_s2 = 3.986004418e5;
cfg.we_rad_s = 7.2921159e-5;
cfg.Rgeo_km = 42164.0;

cfg.summaryCsvPath = fullfile(cfg.resultsDir, 'overhead_runtime_summary.csv');
cfg.rawMatPath = fullfile(cfg.resultsDir, 'overhead_runtime_raw.mat');
cfg.figureBasePath = fullfile(cfg.resultsDir, 'runtime_overhead_pc_tilt_vs_eabr');
% Thesis-ready export: jacky_code/Matlab_data (sibling of Matlab/).
cfg.matlabDataDir = fullfile(fileparts(matlabDir), 'Matlab_data');
cfg.matlabDataFigureBase = fullfile(cfg.matlabDataDir, 'runtime_overhead_pc_tilt_vs_eabr');
cfg.figureExportPaths = {cfg.matlabDataFigureBase, cfg.figureBasePath};
end
