% check_pivot.m
clc;
function data = parseMoogFile(filepath)
    fid = fopen(filepath, 'rt');
    lines = {};
    while ~feof(fid)
        l = fgetl(fid);
        if contains(l, '~M[')
            lines{end+1} = l;
        end
    end
    fclose(fid);
    
    data = zeros(length(lines), 16);
    for i = 1:length(lines)
        s = strrep(lines{i}, '~M[', '');
        s = strrep(s, '[', '');
        parts = sscanf(s, '%f');
        data(i, 1:length(parts)) = parts';
    end
end

raw_p = parseMoogFile('Pivot_Command.csv');
disp('Pivot 8, 9, 10:');
disp(raw_p(10:15, 8:10));
disp('Pivot 11, 12, 13 (Gravity?):');
disp(raw_p(10:15, 11:13));
disp('Pivot 14, 15, 16 (Angular Vel?):');
disp(raw_p(10:15, 14:16));
