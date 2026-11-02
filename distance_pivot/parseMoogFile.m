function data = parseMoogFile(filename)
% Đọc file dữ liệu thô (Pivot/Head)
    fid = fopen(filename, 'r');
    if fid == -1
        error('Không thể mở file: %s', filename);
    end
    raw = fread(fid, '*char')'; 
    fclose(fid);
    
    lines = strsplit(raw, newline); 
    data = [];
    pat = '[-+]?\d*\.?\d+(?:[eE][-+]?\d+)?';
    
    for i = 1:length(lines)
        line = strtrim(lines{i});
        if isempty(line)
            continue;
        end
        nums = regexp(line, pat, 'match');
        if isempty(nums)
            continue;
        end
        row = str2double(nums); 
        row(isnan(row)) = [];
        if length(row) >= 15
            data = [data; row]; 
        end
    end
end
