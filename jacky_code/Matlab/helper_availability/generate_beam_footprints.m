function fp = generate_beam_footprints(pos_km, vel_kmps, beam, Re_km)
% generate_beam_footprints
% Build the 16 satellite-fixed beam footprints for one satellite at one
% time slot, from its ECEF position and nadir-pointing attitude.
%
% Method:
%   1. Build the nadir-pointing local frame (radial up, along-track,
%      cross-track) from position and velocity.
%   2. Rotate the nadir direction by the satellite-fixed beam pitch table to
%      obtain each beam boresight (same 16-beam layout for all satellites).
%   3. Intersect the boresight ray with the Earth sphere -> beam center.
%   4. Sample >= beam.boundarySamples points around the rectangular beam
%      edge (half-angles halfEW_deg x halfNS_deg), intersect each boundary
%      ray with the Earth -> beam footprint polygon (lat/lon).
%
% Inputs:
%   pos_km   : 3x1 ECEF satellite position [km]
%   vel_kmps : 3x1 ECEF satellite velocity [km/s]
%   beam     : cfg.common.beam (Nbeam, half-angles, pitch table, samples)
%   Re_km    : Earth radius [km]
%
% Output fp: 1 x Nbeam struct array with fields
%   valid        : true if the boresight hits the Earth
%   boresight    : 3x1 ECEF unit vector
%   centerLat/Lon: beam-center sub-point [deg]
%   centerEcef_km: 3x1 ECEF beam center [km]
%   polyLat/polyLon : column vectors of footprint boundary vertices [deg]
%   nBoundaryHit : number of boundary rays that hit the Earth
%
% Units: km, deg.

Nbeam = beam.Nbeam;
pos = pos_km(:);
vel = vel_kmps(:);

n_hat = pos / max(norm(pos), eps);                 % radial "up"
v_perp = vel - dot(vel, n_hat) * n_hat;
if norm(v_perp) < eps
    % Degenerate velocity: pick an arbitrary in-plane along-track direction.
    tmp = [0; 0; 1] - dot([0;0;1], n_hat) * n_hat;
    if norm(tmp) < eps, tmp = [1;0;0] - dot([1;0;0], n_hat) * n_hat; end
    v_perp = tmp;
end
t_hat = v_perp / max(norm(v_perp), eps);           % along-track
c_axis = cross(n_hat, t_hat);
c_axis = c_axis / max(norm(c_axis), eps);          % cross-track
b0 = -n_hat;                                       % nadir

halfEW = beam.halfEW_deg;
halfNS = beam.halfNS_deg;
Nb = max(beam.boundarySamples, 8);
[offEW_deg, offNS_deg] = rectangle_perimeter_samples(halfEW, halfNS, Nb);

fp = repmat(struct('valid', false, 'boresight', [0;0;0], ...
    'centerLat', NaN, 'centerLon', NaN, 'centerEcef_km', [NaN;NaN;NaN], ...
    'polyLat', [], 'polyLon', [], 'nBoundaryHit', 0), 1, Nbeam);

for b = 1:Nbeam
    b_hat = rodrigues_local(b0, c_axis, deg2rad(beam.pitchOffsets_deg(b)));
    t_axis_b = cross(c_axis, b_hat);
    t_axis_b = t_axis_b / max(norm(t_axis_b), eps);

    fp(b).boresight = b_hat;

    hitC = ray_earth_intersect(pos, b_hat, Re_km);
    if isempty(hitC)
        fp(b).valid = false;
        continue;
    end
    fp(b).valid = true;
    fp(b).centerEcef_km = hitC;
    fp(b).centerLat = asind(hitC(3) / max(norm(hitC), eps));
    fp(b).centerLon = atan2d(hitC(2), hitC(1));

    polyLat = nan(Nb, 1);
    polyLon = nan(Nb, 1);
    nHit = 0;
    for jj = 1:Nb
        % EW offset about the along-track axis, NS offset about cross-track.
        d = rodrigues_local(b_hat, t_axis_b, deg2rad(offEW_deg(jj)));
        d = rodrigues_local(d, c_axis, deg2rad(offNS_deg(jj)));
        hit = ray_earth_intersect(pos, d, Re_km);
        if isempty(hit)
            continue;
        end
        nHit = nHit + 1;
        polyLat(nHit) = asind(hit(3) / max(norm(hit), eps));
        polyLon(nHit) = atan2d(hit(2), hit(1));
    end
    fp(b).polyLat = polyLat(1:nHit);
    fp(b).polyLon = polyLon(1:nHit);
    fp(b).nBoundaryHit = nHit;
end
end

function [offEW_deg, offNS_deg] = rectangle_perimeter_samples(halfEW, halfNS, Nb)
% Evenly sample Nb points around the rectangle [-halfEW,halfEW] x
% [-halfNS,halfNS] perimeter (EW = horizontal, NS = vertical).
nSide = max(round(Nb / 4), 2);
s = linspace(-1, 1, nSide + 1);
s = s(1:end-1);            % avoid duplicating corners
top    = [ s(:) * halfEW,  ones(nSide,1) * halfNS];
right  = [ ones(nSide,1) * halfEW, -s(:) * halfNS];
bottom = [-s(:) * halfEW, -ones(nSide,1) * halfNS];
left   = [-ones(nSide,1) * halfEW,  s(:) * halfNS];
pts = [top; right; bottom; left];
offEW_deg = pts(:, 1);
offNS_deg = pts(:, 2);
end

function hit = ray_earth_intersect(r_s_km, d_unit, Re_km)
% Nearest intersection of ray (r_s + lambda*d, lambda>0) with sphere |x|=Re.
d_unit = d_unit / max(norm(d_unit), eps);
b = 2 * dot(r_s_km, d_unit);
c = dot(r_s_km, r_s_km) - Re_km^2;
disc = b^2 - 4 * c;
if disc < 0
    hit = [];
    return;
end
s = sqrt(disc);
lam = [(-b - s) / 2, (-b + s) / 2];
lam = lam(lam > 0);
if isempty(lam)
    hit = [];
    return;
end
hit = r_s_km + min(lam) * d_unit;
end

function v = rodrigues_local(u, k, ang)
% Rotate vector u about unit axis k by angle ang (rad), Rodrigues formula.
v = u * cos(ang) + cross(k, u) * sin(ang) + k * dot(k, u) * (1 - cos(ang));
v = v / max(norm(v), eps);
end
