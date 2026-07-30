function geomTable = Extract_LEO_User_Snapshot_Geometry(root, leoList, userPrefix)
% ============================================================
% Extract_L EO_User_Snapshot_Geometry
%
% Extract geometry between LEO satellites and fixed ground users
% at ONE snapshot time.
%
% This follows the snapshot-based system model in the paper.
%
% OUTPUT:
%   geomTable with columns:
%   [LEO, User, Distance_km, Elevation_deg, OffBoresight_deg]
% ============================================================

    sc = root.CurrentScenario;

    % --- force a valid animation time ---
    try
        root.ExecuteCommand('Animate * Reset');
        root.ExecuteCommand('Animate * Step Forward 1');
    catch
    end

    t = sc.Animation.CurrentTime;

    fprintf("\n=== Extracting LEO–User Snapshot Geometry ===\n");
    fprintf("Snapshot time: %s\n\n", t);

    rows = {};
    rowIdx = 0;

    % --------------------------------------------------------
    % Loop over LEO satellites
    % --------------------------------------------------------
    for i = 1:length(leoList)

        leoName = leoList{i};
        try
            sat = root.GetObjectFromPath(['*/Satellite/' leoName]);
        catch
            continue;
        end

        % Satellite ECEF
        dpSat = sat.DataProviders.Item('Cartesian Position') ...
                    .Group.Item('Fixed');
        resSat = dpSat.ExecSingle(t);

        rs = [ ...
            resSat.DataSets.GetDataSetByName('x').Value;
            resSat.DataSets.GetDataSetByName('y').Value;
            resSat.DataSets.GetDataSetByName('z').Value ];

        % ----------------------------------------------------
        % Loop over Users
        % ----------------------------------------------------
        facs = sc.Children.GetElements('eFacility');

        for k = 0:facs.Count-1

            user = facs.Item(k);

            if ~startsWith(user.InstanceName, userPrefix)
                continue;
            end

            % User ECEF
            dpUsr = user.DataProviders.Item('Cartesian Position') ...
                        .Group.Item('Fixed');
            resUsr = dpUsr.ExecSingle(t);

            ru = [ ...
                resUsr.DataSets.GetDataSetByName('x').Value;
                resUsr.DataSets.GetDataSetByName('y').Value;
                resUsr.DataSets.GetDataSetByName('z').Value ];

            % Geometry
            v = ru - rs;
            d = norm(v) / 1e3;   % km

            % Elevation (simple)
            zenith = ru / norm(ru);
            elev = asind(dot(v/norm(v), zenith));

            if elev < 0
                continue;   % not visible
            end

            % Off-boresight (nadir pointing assumption)
            boresight = -rs / norm(rs);
            offb = acosd(dot(v/norm(v), boresight));

            % Save
            rowIdx = rowIdx + 1;
            rows(rowIdx,:) = {leoName, user.InstanceName, d, elev, offb};
        end
    end

    geomTable = cell2table(rows, ...
        'VariableNames', {'LEO','User','Distance_km','Elevation_deg','OffBoresight_deg'});

    fprintf("=== Geometry extracted: %d links ===\n\n", height(geomTable));
end
