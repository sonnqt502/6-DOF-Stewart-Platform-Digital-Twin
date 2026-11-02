% =========================================================================
% SCRIPT KIỂM THỬ MODULE 1: ĐỌC, BÙ GÁ ĐẶT VÀ ĐỒNG BỘ DỮ LIỆU
% =========================================================================
clc; clear; close all;

disp('====================================================');
disp('   BẮT ĐẦU KIỂM THỬ MODULE 1 (DATA IO & SYNC)   ');
disp('====================================================');

% 1. CẤU HÌNH ĐƯỜNG DẪN FILE
% Thay đổi tên file cho khớp với file CSV bạn đang có trong thư mục
file_head = 'IMU2_0_aligned.csv'; 
file_pivot = 'Pivot_Command.csv'; 

% 2. ĐỌC DỮ LIỆU THÔ TỪ CSV LÊN WORKSPACE
try
    fprintf('Đang tải file %s...\n', file_head);
    head_raw = readmatrix(file_head);
    
    fprintf('Đang tải file %s...\n', file_pivot);
    pivot_raw = readmatrix(file_pivot);
catch ME
    fprintf('\n[!] LỖI TẢI FILE: Không thể đọc file CSV.\n');
    fprintf('    -> Hãy chắc chắn file "%s" và "%s" đang nằm cùng thư mục với script này.\n', file_head, file_pivot);
    return;
end

% 3. CHẠY MODULE 1
enable_plot = true; % Đặt thành false nếu bạn không muốn hiện biểu đồ

try
    % Gọi hàm xử lý và hứng 4 biến đầu ra
    [t_sync, head_sync, pivot_sync, eval_metrics] = module1_data_io(head_raw, pivot_raw, enable_plot);
    
    % 4. HIỂN THỊ KẾT QUẢ TÓM TẮT
    disp('----------------------------------------------------');
    disp('=> KẾT LUẬN: MODULE 1 CHẠY THÀNH CÔNG VÀ KHÔNG CÓ LỖI!');
    fprintf(' - Thời gian chạy đồng bộ: %.2f giây\n', t_sync(end));
    fprintf(' - Tổng số điểm dữ liệu  : %d mẫu\n', length(t_sync));
    disp('----------------------------------------------------');
    disp('Dữ liệu đã sẵn sàng trên Workspace. Bạn có thể mở test_module2.m để chạy tiếp!');
    
catch ME
    % Khối bắt lỗi an toàn giúp MATLAB không bị treo nếu có sai sót
    disp('----------------------------------------------------');
    fprintf('[!] CHƯƠNG TRÌNH DỪNG ĐỘT NGỘT DO LỖI TẠI MODULE 1:\n');
    disp(ME.message);
    fprintf('Dòng báo lỗi: %d\n', ME.stack(1).line);
end