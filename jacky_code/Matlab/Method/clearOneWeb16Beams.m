function clearOneWeb16Beams(root, satList)
% clearOneWeb16Beams
% Remove existing OneWeb 16-beam sensors named Beam_01..Beam_16.

beamNames = arrayfun(@(k) sprintf('Beam_%02d', k), 1:16, 'UniformOutput', false);

for i = 1:length(satList)
    satName = char(satList(i));
    try
        sat = root.GetObjectFromPath(['Satellite/' satName]);
    catch
        continue;
    end

    for b = 1:numel(beamNames)
        try
            s = sat.Children.Item(beamNames{b});
            s.Unload();
        catch
        end
    end
end
end

