function GeoGroundStations(root, geoNames, geoLongitudes, latGS)

    fprintf("\n=== Creating GSO Ground Stations (lat = 25°N) ===\n");

    sc = root.CurrentScenario;

    for i = 1:length(geoNames)

        geoName = geoNames{i};
        lon = geoLongitudes(i);

        gsName = sprintf("GSO_GS_%s", geoName);
        fprintf("→ Creating %s at (lat = %.1f°, lon = %.3f°)\n", gsName, latGS, lon);

        % Remove old
        try
            sc.Children.Item(gsName).Unload();
        catch
        end

        % Create Facility
        gs = sc.Children.New('eFacility', gsName);
        gs.Position.AssignGeodetic(latGS, lon, 0);
        gs.Graphics.LabelVisible = true;

        % No vector creation (unsupported in your STK)
    end

    fprintf("=== Completed GSO Ground Stations ===\n\n");
end
