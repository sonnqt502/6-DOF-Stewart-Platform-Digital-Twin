% =========================================================================
% SCRIPT DEBUG: TỰ ĐỘNG PHÁT HIỆN MAPPING CỘT CSV
% Chạy script này TRƯỚC để xác định đúng số cột rồi mới vẽ biểu đồ
% =========================================================================
clc; clear; close all;

file_head = 'IMU2_0.csv';

% --- Đọc cả header text và data số ---
fid = fopen(file_head, 'r');
header_line = fgetl(fid);   % Dòng đầu tiên (tên cột)
fclose(fid);

data = readmatrix(file_head);
[N, num_cols] = size(data);

fprintf('=== THÔNG TIN FILE ===\n');
fprintf('Số dòng dữ liệu : %d\n', N);
fprintf('Số cột          : %d\n', num_cols);
fprintf('\n=== HEADER (nếu có) ===\n%s\n', header_line);

fprintf('\n=== THỐNG KÊ TỪNG CỘT ===\n');
fprintf('%-6s %-12s %-12s %-12s %-12s  %s\n', ...
        'Cột', 'Min', 'Max', 'Mean', 'Std', 'Gợi ý');
fprintf('%s\n', repmat('-',1,75));

for c = 1:num_cols
    col = data(:, c);
    col_valid = col(~isnan(col));
    if isempty(col_valid)
        fprintf('%-6d  [--- toàn NaN ---]\n', c);
        continue;
    end
    mn  = min(col_valid);
    mx  = max(col_valid);
    mu  = mean(col_valid);
    sg  = std(col_valid);
    
    % Gợi ý tự động dựa trên range
    hint = '';
    if c == 1 && mn >= 0 && mx > 1
        hint = '<= thời gian (t)';
    elseif abs(mu) < 5 && sg < 2 && mn >= -360 && mx <= 360 && sg > 0.01
        hint = '<= có thể là GÓC (°)';
    elseif mn >= -20 && mx <= 20 && sg > 0.01
        hint = '<= có thể là GIA TỐC (m/s²)';
    elseif abs(mu) < 10 && sg < 5 && sg > 0.001
        hint = '<= có thể là VẬN TỐC GÓC (rad/s)';
    elseif sg < 1e-6
        hint = '<= HẰNG SỐ hoặc NaN ẩn';
    end
    
    fprintf('%-6d %-12.4f %-12.4f %-12.4f %-12.4f  %s\n', c, mn, mx, mu, sg, hint);
end

fprintf('\n=== 5 DÒNG DỮ LIỆU ĐẦU ===\n');
disp(data(1:min(5,N), :));

fprintf('\n=> Dựa vào bảng trên, điền lại cột vào check_imu_alignment.m\n');