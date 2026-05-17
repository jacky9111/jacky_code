function inBeam = gsInBeamFootprint(th_h_deg, th_v_deg, halfEW_deg, halfNS_deg, P)
% gsInBeamFootprint  GS direction inside rectangular beam footprint (optional).
% When ku_epfd_params.useInBeamFootprint is false (default), returns NaN and
% callers should not use footprint to gate EPFD.

if nargin < 5 || isempty(P)
    P = ku_epfd_params();
end
if ~isfield(P, 'useInBeamFootprint') || isempty(P.useInBeamFootprint) || ~logical(P.useInBeamFootprint)
    inBeam = NaN;
    return;
end
inBeam = (abs(th_h_deg) <= halfEW_deg) && (abs(th_v_deg) <= halfNS_deg);
end
