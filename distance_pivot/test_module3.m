% =========================================================================
% SCRIPT: test_pipeline.m
% Mục đích: Chạy toàn bộ luồng xử lý từ dữ liệu thô đến kết quả nghiệm (r)
% =========================================================================
clc; clear; close all;

disp('===========================================================');
disp('   KHỞI ĐỘNG CHƯƠNG TRÌNH TÍNH TOÁN ĐỘNG LỰC HỌC 6-RUS');
disp('===========================================================');

%% --- BƯỚC 0: CẤU HÌNH VÀ ĐỌC DỮ LIỆU ---
% 1. Tên file
file_head  = 'IMU1_00.csv'; 
file_pivot = 'Pivot_Command.csv'; 

% 2. Thông số thuật toán
motion_type = 'Roll';  % Chọn 'Pitch' (trục Y) hoặc 'Roll' (trục X)
fc_user     = 0.5;      % Tần số cắt bộ lọc (Hz)

fprintf('1. Đang đọc file thô từ thư mục...\n');
head_raw  = parseMoogFile(file_head);
pivot_raw = parseMoogFile(file_pivot);

%% --- BƯỚC 0.5: CẮT BỎ THỜI GIAN RÁC (TRIM DATA) ---
% Tùy chỉnh số giây muốn cắt ở đầu và cuối cho mỗi file
trim_head_start  = 0;  
trim_head_end    = 0;  
trim_pivot_start = 0;  
trim_pivot_end   = 0;  % [ĐÃ SỬA] Thêm số 0 vào đây để tránh lỗi cú pháp

fprintf('2. Đang cắt bỏ nhiễu khởi động...\n');
head_trimmed  = apply_trim(head_raw, trim_head_start, trim_head_end);
pivot_trimmed = apply_trim(pivot_raw, trim_pivot_start, trim_pivot_end);

%% --- BƯỚC 1: ĐỒNG BỘ THỜI GIAN (MODULE 1) ---
[t_sync, head_sync, pivot_sync, mod1_metrics] = module1_data_io(head_trimmed, pivot_trimmed, true);

%% --- BƯỚC 2: TIỀN XỬ LÝ & LỌC NHIỄU (MODULE 2) ---
[proc_data, mod2_metrics] = module2_signal_processing(t_sync, head_sync, pivot_sync, motion_type, fc_user, false);

%% --- BƯỚC 3: GIẢI HỆ PHƯƠNG TRÌNH ĐỘNG LỰC HỌC (MODULE 3) ---
[r_sol_mm, math_metrics] = module3_math_engine(proc_data, head_sync);

disp('===========================================================');
disp('   HOÀN THÀNH QUÁ TRÌNH TÍNH TOÁN!');
disp('===========================================================');

% =========================================================================
% CÁC HÀM HỖ TRỢ BÊN DƯỚI
% =========================================================================
function data_trimmed = apply_trim(data_raw, trim_start_sec, trim_end_sec)
    if isempty(data_raw)
        error('Dữ liệu đầu vào trống!');
    end
    t = data_raw(:, 1);
    t_start_target = t(1) + trim_start_sec;
    t_end_target   = t(end) - trim_end_sec;
    if t_start_target >= t_end_target
        error('Lỗi Trim: Thời gian cắt quá lớn khiến dữ liệu bị xóa sạch!');
    end
    mask = (t >= t_start_target) & (t <= t_end_target);
    data_trimmed = data_raw(mask, :);
end

function data = parseMoogFile(filename)
    fid = fopen(filename, 'r');
    if fid == -1, error('Không thể mở file: %s', filename); end
    raw = fread(fid, '*char')'; 
    fclose(fid);
    
    lines = strsplit(raw, newline); 
    data = [];
    pat = '[-+]?\d*\.?\d+(?:[eE][-+]?\d+)?';
    
    for i = 1:length(lines)
        line = strtrim(lines{i});
        if isempty(line), continue; end
        nums = regexp(line, pat, 'match');
        if isempty(nums), continue; end
        row = str2double(nums); 
        row(isnan(row)) = [];
        if length(row) >= 15
            data = [data; row]; 
        end
    end
end