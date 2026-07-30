function users = Create_Paper_Users(latRange, lonRange, nLat, nLon)
% ============================================================
% Create_Paper_Users
%
% Create fixed ground users for snapshot-based analysis.
% This follows the system model of the paper.
%
% OUTPUT:
%   users struct with fields:
%   - lat (deg)
%   - lon (deg)
%   - demand (normalized)
% ============================================================

    latList = linspace(latRange(1), latRange(2), nLat);
    lonList = linspace(lonRange(1), lonRange(2), nLon);

    idx = 0;
    for i = 1:length(latList)
        for j = 1:length(lonList)
            idx = idx + 1;
            users(idx).lat = latList(i);
            users(idx).lon = lonList(j);
            users(idx).demand = 1;   % uniform demand (paper-consistent)
        end
    end

    fprintf("Created %d fixed ground users (paper model)\n", idx);
end
