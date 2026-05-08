function relayCheck = RunStrictRelayCheck_FromLeoPart(root, leo_part, tEpochStr, alt_km, beamHalfV_deg, beamLabel)
% RunStrictRelayCheck_FromLeoPart
%   Take three consecutive satellites from leo_part(2:4), sort by STK latitude
%   (south -> north), then run CheckRelayByLatitudeBands:
%     north neighbor -> S2 upper half, south neighbor -> S2 lower half.
%
% Inputs:
%   beamLabel (optional): string printed in PASS/FAIL line, e.g. "-3dB"

    if nargin < 6 || strlength(string(beamLabel)) == 0
        beamLabel = "-3dB";
    end
    beamLabel = char(string(beamLabel));

    relayCheck = [];

    if numel(leo_part) < 4
        return;
    end

    trio = [string(leo_part(2)); string(leo_part(3)); string(leo_part(4))];
    trioLat = zeros(3, 1);
    for k = 1:3
        satObj = root.GetObjectFromPath(['*/Satellite/' char(trio(k))]);
        dpLLA = satObj.DataProviders.Item('LLA State').Group.Item('Fixed');
        resLLA = dpLLA.ExecSingle(tEpochStr);
        valsLLA = resLLA.DataSets.ToArray;
        if isnumeric(valsLLA)
            trioLat(k) = valsLLA(1);
        else
            trioLat(k) = str2double(valsLLA{1});
        end
    end

    [~, idxSort] = sort(trioLat, 'ascend'); % south -> north
    sSouth = char(trio(idxSort(1)));
    s2 = char(trio(idxSort(2)));
    sNorth = char(trio(idxSort(3)));

    relayCheck = CheckRelayByLatitudeBands( ...
        root, tEpochStr, sNorth, s2, sSouth, alt_km, beamHalfV_deg);

    fprintf("\n=== Strict Relay Check (Latitude Bands) ===\n");
    fprintf("north/s2/south = [%s, %s, %s], t = %s\n", sNorth, s2, sSouth, tEpochStr);
    fprintf("North-neighbor lat band: [%.3f, %.3f] deg\n", relayCheck.bandS1_deg(1), relayCheck.bandS1_deg(2));
    fprintf("S2 lat band:             [%.3f, %.3f] deg\n", relayCheck.bandS2_deg(1), relayCheck.bandS2_deg(2));
    fprintf("South-neighbor lat band: [%.3f, %.3f] deg\n", relayCheck.bandS3_deg(1), relayCheck.bandS3_deg(2));
    fprintf("deltaLat from beam = %.3f deg\n", relayCheck.deltaLat_deg);
    if relayCheck.passStrict
        fprintf("PASS: %s beam meets strict relay condition by latitude bands.\n", beamLabel);
    else
        fprintf("FAIL: %s beam does NOT meet strict relay condition by latitude bands.\n", beamLabel);
    end
end
