function LEO = build_walker_star(P, t0)
% Simplified Walker-star generator (circular orbits), snapshot at time t0.

Nplanes = P.num_planes;
Ns = P.sats_per_plane;
Ntot = Nplanes * Ns;

a_km = P.Re_km + P.leo_alt_km;
inc = deg2rad(P.leo_inc_deg);

raan_list = linspace(0, 2*pi, Nplanes+1); raan_list(end) = [];
% Mean anomaly spacing per plane
M_list = linspace(0, 2*pi, Ns+1); M_list(end) = [];

pos_ecef_km = zeros(3, Ntot);
subLat = zeros(Ntot,1);
subLon = zeros(Ntot,1);

idx = 0;
for p = 1:Nplanes
    raan = raan_list(p);
    for s = 1:Ns
        idx = idx + 1;
        M0 = M_list(s);
        % circular orbit: true anomaly approx = mean anomaly
        nu = M0 + 2*pi*(t0 / orbital_period_s(a_km, P.mu_km3_s2));
        r_eci = kep_circ_eci(a_km, inc, raan, nu);
        % For replication simplicity: treat ECI≈ECEF at snapshot (ignore Earth rotation),
        % since the paper focuses on relative geometry statistics.
        r_ecef = r_eci;

        pos_ecef_km(:,idx) = r_ecef;

        [lat, lon] = ecef_to_latlon(r_ecef);
        subLat(idx) = rad2deg(lat);
        subLon(idx) = wrapTo180(rad2deg(lon));
    end
end

LEO.pos_ecef_km = pos_ecef_km;
LEO.sub_lat_deg = subLat;
LEO.sub_lon_deg = subLon;
LEO.N = Ntot;

end

function T = orbital_period_s(a_km, mu)
T = 2*pi*sqrt(a_km^3/mu);
end

function r_eci = kep_circ_eci(a_km, inc, raan, nu)
% Circular orbit in ECI, argument of perigee=0
r_pf = [a_km*cos(nu); a_km*sin(nu); 0];

R3 = rotz(raan);
R1 = rotx(inc);
r_eci = R3*R1*r_pf;
end

function R = rotx(a)
R = [1 0 0; 0 cos(a) -sin(a); 0 sin(a) cos(a)];
end

function R = rotz(a)
R = [cos(a) -sin(a) 0; sin(a) cos(a) 0; 0 0 1];
end

function [lat, lon] = ecef_to_latlon(r_km)
x=r_km(1); y=r_km(2); z=r_km(3);
lon = atan2(y,x);
lat = atan2(z, sqrt(x^2+y^2));
end
