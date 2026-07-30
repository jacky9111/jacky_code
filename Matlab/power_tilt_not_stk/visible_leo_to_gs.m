function [visIdx, geom] = visible_leo_to_gs(LEO, gs, minElevDeg)

r_gs = gs.pos_ecef_km;

N = LEO.N;
vis = false(N,1);
elev = zeros(N,1);
range_km = zeros(N,1);

for i=1:N
    r_sat = LEO.pos_ecef_km(:,i);
    rho = r_sat - r_gs;
    range_km(i) = norm(rho);

    % elevation: angle between rho and local horizon
    % Use simple method: elev = 90 - angle( rho, zenith )
    zenith = r_gs / norm(r_gs);
    ang = acosd( dot(rho, zenith) / (norm(rho)*norm(zenith)) );
    elev(i) = 90 - ang;

    vis(i) = elev(i) >= minElevDeg;
end

visIdx = find(vis);

geom.elev_deg = elev(visIdx);
geom.range_km = range_km(visIdx);

end
