function P = paper_params()
% Parameters from Table 1 (as in your screenshot)

% -------- LEO constellation --------
P.leo_alt_km = 1200;
P.leo_inc_deg = 87.9;
P.num_planes = 36;
P.sats_per_plane = 49;

P.f_Hz = 19.7e9;
P.lambda = 3e8 / P.f_Hz;
P.B_Hz = 200e6;

P.Pmax_dBW = 10;                % 10 dBW
P.Pmax_W = 10^(P.Pmax_dBW/10);  % W

% Beamwidth (paper uses several; typical shown includes 13.9 deg)
P.hpbw_deg = 13.9;

% Tilt
P.theta_max_deg = 10;

% Exponential fit coefficients (Table 1)
P.A_fit = 1.0632e4;
P.beta_fit = -0.0671; % per degree (keep angles in degrees)

% -------- GSO satellite --------
P.gso_alt_km = 35785.4;
P.gso_lon_deg = 30.6;
P.gso_lat_deg = 0.0;

% -------- Ground station patterns --------
P.min_elev_deg = 10;

% GSO ground station (receive)
P.GS_GSO_Gmax_dBi = 40.95;
P.GS_noise_temp_K = 240;
P.GS_ant_pattern_ref = 24; % reference tag (ITU-R S.672 / S.580 type)

% LEO user ground station (receive)
P.GS_LEO_Gmax_dBi = 40.95;
P.user_noise_temp_K = 240;
P.user_ant_pattern_ref = 24;

% EPFD
P.EPFD_thr_dB = -173.4; % dB(W/m^2/1MHz)
P.BWref_Hz = 1e6;
P.D_ref_m = 0.70;

% -------- Physical constants --------
P.Re_km = 6378.137;
P.mu_km3_s2 = 398600.4418;
P.kB = 1.380649e-23;

% Tilt heuristic threshold (paper sets zeta_thr=0.7 leading to 1 critical sat in their scenario)
P.zeta_thr = 0.7;

end
