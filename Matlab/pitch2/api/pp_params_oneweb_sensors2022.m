function P = pp_params_oneweb_sensors2022()
%PP_PARAMS_ONEWEB_SENSORS2022 Parameters from Sensors 2022, 22, 6302 (Table 2)
% "Optimal Progressive Pitch for OneWeb Constellation with Seamless Coverage"
%
% All angles are in degrees unless otherwise stated.

% ---- Physical constants
P.c = 299792458;                 % m/s
P.kB = 1.380649e-23;             % J/K

% ---- Geometry
P.Re_km = 6371;                  % km (Table 2: 6371)
P.h_leo_km = 1200;               % km (Table 2: 1200)
P.h_geo_km = 36000;              % km (Table 2: 36,000)

% ---- Frequency / bandwidth
P.f_min_GHz = 10.7;              % Table 2
P.f_max_GHz = 12.7;              % Table 2
P.f_GHz = (P.f_min_GHz + P.f_max_GHz) / 2;  % simple center frequency
P.Bw_MHz = 250;                  % Table 2
P.Bw_Hz = P.Bw_MHz * 1e6;
P.Bref_Hz = 40e3;                % EPFD reference bandwidth (Table 2 uses 40 kHz)

% ---- Beams / reuse
P.Nbeam = 16;                    % Table 2
P.Mfreq = 8;                     % Paper text: F = 8
P.beams_per_freq = P.Nbeam / P.Mfreq; % =2

% ---- EIRP / EPFD limit
P.EIRP_dBW = 34.6;               % Table 2
P.EIRP_W = 10^(P.EIRP_dBW/10);
P.EPFD_th_dBW_m2_perBref = -160; % dBW/m^2 / 40kHz (Table 2)

% ---- Beamwidth (Table 2 lists "Beamwidth", paper uses one-half 3 dB beamwidth)
P.beamwidth_minor_full_deg = 2.98;  % Table 2
P.beamwidth_major_full_deg = 47.6;  % Table 2
P.mu_b_deg = P.beamwidth_minor_full_deg/2;  % one-half 3 dB beamwidth in minor axis
P.nu_b_deg = P.beamwidth_major_full_deg/2;  % one-half 3 dB beamwidth in major axis

% ---- Antenna pattern parameters (ITU-R S.1528 as used in paper)
P.S1528.LN_dB = -25; % main beam and near-in sidelobe mask cross point below peak gain
P.S1528.z = 1;       % minor axis gain (paper sets z = 1)

% For LN = -25, ITU-R S.1528 gives:
P.S1528.b = 6.32;
P.S1528.alpha = 1.5;
P.S1528.a = 2.58 * sqrt(1 - 0.6*log10(P.S1528.z)); % reduces to 2.58 when z=1

% Far-out sidelobe / backlobe levels are not needed for our typical angles,
% but included for completeness.
P.S1528.LF_dB = -10;
P.S1528.LB_dB = -10;

% ---- Seamless coverage / progressive pitch design parameters (Table 2)
P.mu_th_deg_table = 11.5;        % Table 2 (should match computed from Eq. (6))
P.overlap_e_deg = 1;             % Table 2
P.chi_max_deg = 18;              % Table 2

P.dpsi_deg = 1.25;               % Table 2
P.Npsi = floor(90 / P.dpsi_deg); % Table 2: gene length 72

P.delta_orbit_deg = 7.5;         % implied by 48 sats/orbit: 360/48 = 7.5 deg
P.Ldelta = round(P.delta_orbit_deg / P.dpsi_deg); % should be 6

P.dchi_slow_deg = 0.5;           % Table 2
P.dchi_fast_deg = 1.5;           % Table 2

% ---- GA parameters (Table 2)
P.GA.generations = 200;
P.GA.pop_size = 100;
P.GA.mutation_rate = 0.02;
P.GA.crossover_rate = 0.5;
P.GA.election_rate = 0.2;

% ---- Receiver / noise assumptions (not explicitly listed in Table 2)
P.noise_T_K = 290; % assumed system noise temperature

% ---- Numerical evaluation knobs (not from paper; controls runtime)
% Eq. (15) integral is approximated numerically in pp_eval_at_latitude.
% Larger => more accurate but slower. Start with 5~11.
P.eval_n_x = 11;

% ---- Derived
P.Rn_km = P.Re_km + P.h_leo_km;
P.Rg_km = P.Re_km + P.h_geo_km;
end

