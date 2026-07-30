function Create_Fixed_Ground_Users(root, latRange, lonMin, lonMax, nLat, nLon)
% ============================================================
% Create_Fixed_Users_In_Longitude_Band
%
% Create static ground users within a longitude band.
% Users are fixed and do NOT move with time.
%
% INPUTS:
%   root    : IAgStkObjectRoot
%   latRange: [latMin latMax] (deg)
%   lonMin  : minimum longitude (deg)
%   lonMax  : maximum longitude (deg)
%   nLat    : number of latitude grid points
%   nLon    : number of longitude grid points
%
% Example (paper-consistent):
%   latRange = [-40 40];
%   lonMin = -137; lonMax = -72;
%   nLat = 25; nLon = 20;
% ============================================================

    sc = root.CurrentScenario;

    fprintf("\n=== Creating FIXED Users in Longitude Band ===\n");
    fprintf("Longitude range: [%.1f°, %.1f°]\n", lonMin, lonMax);

    latList = linspace(latRange(1), latRange(2), nLat);
    lonList = linspace(lonMin, lonMax, nLon);

    userCount = 0;

    for i = 1:length(latList)
        for j = 1:length(lonList)

            userCount = userCount + 1;
            userName = sprintf("User_%03d", userCount);

            % Remove old user if exists
            try
                sc.Children.Item(userName).Unload();
            catch
            end

            % Create Facility
            user = sc.Children.New('eFacility', userName);
            user.Position.AssignGeodetic(latList(i), lonList(j), 0);

            % Graphics (optional)
            user.Graphics.LabelVisible = false;

            fprintf("  + %s at (lat=%.2f°, lon=%.2f°)\n", ...
                userName, latList(i), lonList(j));
        end
    end

    fprintf("=== Completed: %d users created ===\n\n", userCount);
end
