function tle_data = parseTLEgeo(tle_lines)
    tle_data = [];
    count = 1;

    for i = 1:length(tle_lines)
        tline = strtrim(tle_lines{i});
        if tline == ""
            continue;   % 保險：跳過空行
        end

        tmp = split(string(tline));

        if mod(count, 3) == 1
            % 第 0 行：名稱行
            % 針對不同長度處理：
            % - 至少 3 個欄位： 0 ONEWEB 0721      -> ONEWEB_0721
            % - 至少 2 個欄位： 0 ASIASTAR         -> ASIASTAR
            % - (更長的，例如 0 SBIRS GEO 1 (USA) -> SBIRS_GEO)
            if numel(tmp) >= 3
                name = tmp(2) + "_" + tmp(3);
            elseif numel(tmp) >= 2
                name = tmp(2);
            else
                warning("無法解析名稱行: %s", tline);
                count = count + 1;
                continue;
            end

            tle_data = [tle_data, name];
            disp(name);

        elseif mod(count, 3) == 2
            % 第 1 行：line 1（含 epoch）
            tle_data = [tle_data, tmp(4)];
            epoch = tmp(4);
            a = str2double(epoch);
            y = fix(a/1000);
            [yy, mm, dd, HH, MM, SS] = datevec(datenum(y, 0, a - y*1000));
            if yy <= 56
                fprintf('20%02d/%02d/%02d %02d:%02d:%06.4f\n', yy, mm, dd, HH, MM, SS);
            else
                fprintf('19%02d/%02d/%02d %02d:%02d:%06.4f\n', yy, mm, dd, HH, MM, SS);
            end

        elseif mod(count, 3) == 0
            % 第 2 行：line 2（軌道六要素），正常情況一定 >= 8 欄
            if numel(tmp) < 8
                warning("Line 2 欄位數不足: %s", tline);
                count = count + 1;
                continue;
            end

            tle_data = [tle_data, tmp(3)]; % Inclination
            tle_data = [tle_data, tmp(4)]; % RAAN
            tle_data = [tle_data, tmp(5)]; % Eccentricity
            tle_data = [tle_data, tmp(6)]; % ArgPerigee
            tle_data = [tle_data, tmp(7)]; % MeanAnomaly
            tle_data = [tle_data, tmp(8)]; % MeanMotion
        end

        count = count + 1;
    end
end
