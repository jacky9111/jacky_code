function Tout = ComputeUserSatisfaction_ProgressivePitch(T_beam, target_sat, user_lat_deg)
% ComputeUserSatisfaction_ProgressivePitch
% Given beam-level simulation table (from SimOneWeb16Beams_ProgressivePitch),
% compute per-time user service satisfaction for a target satellite.
%
% A user is "served" at time t if there exists at least one beam with:
% - State == "ON"
% - user_lat in [phiB2_deg, phiB1_deg] for that beam
%
% Inputs
% - T_beam: table produced by SimOneWeb16Beams_ProgressivePitch
% - target_sat: string/char, e.g. "ow1_30"
% - user_lat_deg: numeric vector (deg)
%
% Output
% - Tout: table with Time, phiS_deg, Noff, user_satisfaction_pct, users_served_count,
%         users_total, worstEPFD_on_dB, epfd_thr_dB, epfd_violation_on

target_sat = string(target_sat);
user_lat_deg = user_lat_deg(:);
Nu = numel(user_lat_deg);

rows = string(T_beam.LEO) == target_sat;
Tb = T_beam(rows, :);
if isempty(Tb)
    error('No rows found for target_sat="%s" in T_beam.', target_sat);
end

times = unique(string(Tb.Time), 'stable');

Time = strings(numel(times),1);
phiS_deg = nan(numel(times),1);
Noff = nan(numel(times),1);
user_satisfaction_pct = nan(numel(times),1);
users_served_count = zeros(numel(times),1);
users_total = repmat(Nu, numel(times), 1);
worstEPFD_on_dB = nan(numel(times),1);
epfd_thr_dB = nan(numel(times),1);
epfd_violation_on = zeros(numel(times),1);

for k = 1:numel(times)
    tStr = times(k);
    Tt = Tb(string(Tb.Time) == tStr, :);
    if isempty(Tt)
        continue;
    end

    Time(k) = tStr;
    phiS_deg(k) = Tt.phiS_deg(1);
    Noff(k) = Tt.Noff(1);

    onMask = string(Tt.State) == "ON";
    phiB1 = Tt.phiB1_deg;
    phiB2 = Tt.phiB2_deg;

    served = false(Nu, 1);
    if any(onMask)
        % For each user, check if ANY ON beam covers the latitude.
        % (Beams are nested intervals in this paper-aligned model.)
        for u = 1:Nu
            lat_u = user_lat_deg(u);
            served(u) = any(onMask & (lat_u >= phiB2) & (lat_u <= phiB1));
        end
    end

    users_served_count(k) = sum(served);
    user_satisfaction_pct(k) = users_served_count(k) / max(Nu, 1) * 100;

    % EPFD violation among ON beams (if EPFD columns exist)
    if ismember('WorstEPFD_dB', Tt.Properties.VariableNames)
        epfd_thr_dB(k) = Tt.EPFD_thr_out_dB(1);
        epfd_on = Tt.WorstEPFD_dB(onMask);
        if ~isempty(epfd_on)
            worstEPFD_on_dB(k) = max(epfd_on);
            epfd_violation_on(k) = double(worstEPFD_on_dB(k) > epfd_thr_dB(k));
        end
    end
end

Tout = table(Time, phiS_deg, Noff, user_satisfaction_pct, users_served_count, users_total, ...
    worstEPFD_on_dB, epfd_thr_dB, epfd_violation_on);
end

