function epfd = compute_beam_epfd(pos_km, boresights, beamPower_W, P_gs_km, P_geo_km, P)
% compute_beam_epfd
% Beam-level EPFD contribution (linear, W/m^2/reference-bandwidth) from one
% satellite's beams to the ground station, using the SAME model as the rest
% of the thesis code (per-beam power model):
%
%   epfd_lin = (Pbeam_W / BWref) * (Gt / (4*pi*d^2)) * (Gr(alpha) / Gr_max)
%
% with the LEO transmit gain Gt = A_fit * exp(beta_fit * phi) (phi in deg is
% the off-boresight angle toward the GS) and the GSO receive gain from
% ITU-R S.1428 evaluated at the topocentric angle alpha between the LEO and
% the reference GSO as seen from the GS.
%
% Inputs:
%   pos_km      : 3x1 ECEF satellite position [km]
%   boresights  : 3 x Nbeam ECEF beam boresight unit vectors
%   beamPower_W : Nbeam x 1 per-beam transmit power [W] (0 => shut beam)
%   P_gs_km     : 3x1 ECEF ground-station position [km]
%   P_geo_km    : 3x1 ECEF reference GSO position [km]
%   P           : Ku EPFD parameter struct (ku_epfd_params)
%
% Output epfd:
%   epfd.beam_lin : Nbeam x 1 per-beam EPFD contribution [linear]
%   epfd.d_m      : slant distance GS<->satellite [m]
%   epfd.alpha_deg: topocentric LEO/GSO separation at GS [deg]
%
% Units: km in, m internally for the EPFD path term, deg for angles.

Nbeam = size(boresights, 2);
beamPower_W = beamPower_W(:);
pos_km = pos_km(:); P_gs_km = P_gs_km(:); P_geo_km = P_geo_km(:);

Gmax_lin = 10^(P.GSO_Gmax_dBi / 10);

beam_lin = zeros(Nbeam, 1);

v_gs_m = (P_gs_km - pos_km) * 1000;   % satellite -> GS vector [m]
d_m = norm(v_gs_m);

% Topocentric angle between the LEO and the reference GSO as seen from GS.
alpha_deg = angle_deg(pos_km - P_gs_km, P_geo_km - P_gs_km);
Gr_dBi = gso_rx_gain_itu1428(alpha_deg, P.GSO_D_m, P.lambda_m);
Gr_lin = 10^(Gr_dBi / 10);

if d_m >= 1
    d_hat = v_gs_m / d_m;
    for b = 1:Nbeam
        if beamPower_W(b) <= 0
            continue;
        end
        phit_deg = angle_deg(boresights(:, b), d_hat);
        Gt_lin = max(P.A_fit * exp(P.beta_fit * phit_deg), 1e-30);
        beam_lin(b) = (beamPower_W(b) / P.BWref_Hz) * ...
            (Gt_lin / (4 * pi * d_m^2)) * (Gr_lin / Gmax_lin);
    end
end

epfd = struct();
epfd.beam_lin  = beam_lin;
epfd.d_m       = d_m;
epfd.alpha_deg = alpha_deg;
end

function a = angle_deg(x, y)
a = acosd(max(-1, min(1, dot(x, y) / (norm(x) * norm(y) + eps))));
end
