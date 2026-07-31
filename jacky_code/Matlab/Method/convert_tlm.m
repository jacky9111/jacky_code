function convert_tlm(folderPath)
% convert_tlm(folderPath)
% ---------------------------------------------------------
% 將指定資料夾內的 TLE 檔案轉換為含 "0 ONEWEB xxxx" 格式，
% 並直接覆蓋原始檔（會自動建立 _backup.tle 備份）
%
% 參數：
%   folderPath  - (string or char) TLE 檔案所在的資料夾路徑
%
% 用法範例：
%   convert_tlm('C:\Users\jacky\Desktop\jacky_code\jacky_code\oneweb_tle\20251029_173722')

    if nargin < 1
        error('❌ 請提供 TLE 資料夾路徑，例如：convert_tlm("C:\path\to\folder")');
    end

    if ~isfolder(folderPath)
        error('❌ 找不到資料夾：%s', folderPath);
    end

    disp("🚀 開始轉換 TLE 檔案格式...");
    inFiles = dir(fullfile(folderPath, '*.tle'));
    if isempty(inFiles)
        inFiles = dir(fullfile(folderPath, '*.txt'));
    end
    assert(~isempty(inFiles), '找不到 .tle 或 .txt 檔於：%s', folderPath);

    for f = 1:numel(inFiles)
        inPath = fullfile(inFiles(f).folder, inFiles(f).name);
        fprintf('🔄 處理檔案：%s\n', inFiles(f).name);

        % --- 備份舊檔 ---
        backupPath = strrep(inPath, '.tle', '_backup.tle');
        copyfile(inPath, backupPath);
        fprintf('🧾 已建立備份：%s\n', backupPath);

        % --- 讀取原始內容 ---
        fid = fopen(inPath, 'r');
        if fid == -1
            warning('⚠️ 無法開啟檔案：%s', inPath);
            continue;
        end
        C = textscan(fid, '%s', 'Delimiter', '\n', 'Whitespace', '');
        fclose(fid);
        lines = C{1};

        % --- 轉換內容 ---
        outLines = {};
        i = 1;
        n = numel(lines);
        while i + 2 <= n
            nameLine = strtrim(lines{i});
            L1 = strtrim(lines{i+1});
            L2 = strtrim(lines{i+2});

            % 判斷是否為合法 TLE 組
            if startsWith(L1, '1 ') && startsWith(L2, '2 ')
                % 名稱清理：把 -/_ 換成空白
                nameClean = regexprep(nameLine, '[-_]', ' ');
                nameClean = strtrim(regexprep(nameClean, '\s+', ' '));
                % 固定 24 欄寬（不足補空白，超過截斷）
                if strlength(nameClean) > 24
                    nameClean = extractBefore(nameClean, 25);
                else
                    nameClean = pad(nameClean, 24, 'right');
                end
                % 轉成 "0 NAME"
                line0 = "0 " + nameClean;
                outLines = [outLines; line0; L1; L2];
                i = i + 3;
            else
                i = i + 1;
            end
        end

        % --- 寫回原檔（覆蓋） ---
        fid = fopen(inPath, 'w');
        if fid == -1
            warning('⚠️ 無法寫回檔案：%s', inPath);
            continue;
        end
        fprintf(fid, '%s\n', outLines{:});
        fclose(fid);

        fprintf('✅ 已完成並覆蓋：%s（共 %d 組 TLE）\n\n', inFiles(f).name, numel(outLines)/3);
    end

    disp('🎯 所有檔案已完成格式轉換並覆蓋！');
end
