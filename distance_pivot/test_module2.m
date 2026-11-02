% =========================================================================
% SCRIPT KIỂM THỬ MODULE 2: LỌC TÍN HIỆU & ĐỘNG HỌC (LPF Bậc 1 + Auto FFT)
% =========================================================================

% Dọn dẹp Command Window nhưng GIỮ LẠI các biến của Module 1 trong Workspace
clc;
clearvars -except t_sync head_sync pivot_sync;

disp('====================================================');
disp('   BẮT ĐẦU KIỂM THỬ MODULE 2 (SIGNAL PROCESSING)   ');
disp('====================================================');

% 1. KIỂM TRA DỮ LIỆU ĐẦU VÀO TỪ MODULE 1
if ~exist('t_sync', 'var') || ~exist('head_sync', 'var') || ~exist('pivot_sync', 'var')
    fprintf('[!] LỖI: Không tìm thấy dữ liệu đồng bộ trong Workspace.\n');
    fprintf('    Vui lòng chạy file test_module1.m (hoặc script nạp dữ liệu) trước!\n');
    return;
end

% 2. CẤU HÌNH THAM SỐ CHẠY (USER SETTINGS)
motion_type = 'Roll'; % Đổi thành 'Pitch' hoặc 'Roll'
fc_user = 0.5;        % Tần số cắt (Cut-off Frequency)
enable_plot = true;   % Bật/tắt biểu đồ

% 3. THỰC THI MODULE 2
try
    fprintf('Đang khởi chạy thuật toán với cấu hình:\n');
    fprintf(' - Trục kiểm thử    : %s\n', motion_type);
    fprintf(' - Tần số cắt (fc)  : %.1f Hz\n', fc_user);
    fprintf('----------------------------------------------------\n');
    
    % Gọi hàm xử lý tín hiệu (hứng cả dữ liệu và metrics)
    [proc_data, filter_metrics] = module2_signal_processing(...
        t_sync, head_sync, pivot_sync, motion_type, fc_user, enable_plot);
    
    % 4. IN BÁO CÁO LƯỢNG NHIỄU ĐÃ BỊ LOẠI BỎ (RMSE)
    disp('   BÁO CÁO CHẤT LƯỢNG LỌC NHIỄU (RMSE)');
    disp('----------------------------------------------------');
    
    fprintf('1. Cảm biến HEAD (Bệ động):\n');
    fprintf('   - Gia tốc [ax, ay, az]   : [%.4f, %.4f, %.4f] m/s^2\n', ...
            filter_metrics.Head.ax.RMSE_filt, filter_metrics.Head.ay.RMSE_filt, filter_metrics.Head.az.RMSE_filt);
    fprintf('   - Vận tốc góc [wx, wy, wz]: [%.4f, %.4f, %.4f] rad/s\n', ...
            filter_metrics.Head.wx.RMSE_filt, filter_metrics.Head.wy.RMSE_filt, filter_metrics.Head.wz.RMSE_filt);
    % 5. KIỂM TRA KẾT QUẢ ĐẦU RA
    disp('----------------------------------------------------');
    disp('=> KẾT LUẬN: MODULE 2 CHẠY THÀNH CÔNG VÀ KHÔNG CÓ LỖI!');
    fprintf('\n[+] Kích thước dữ liệu đầu ra: %d mẫu\n', length(proc_data.t));
    if proc_data.isPitch
        fprintf('[+] Trục xoay chính: Y (Pitch)\n');
    else
        fprintf('[+] Trục xoay chính: X (Roll)\n');
    end
    % Mở rộng: Đánh giá chuyên sâu thuật toán bù trừ bằng trục xoay chính
     f_ex_test = 0.25; % Ghi lại đúng tần số bạn ra lệnh lắc (hoặc lấy từ f_ex_auto)
    if strcmpi(motion_type, 'Pitch')
        evaluate_compensation(proc_data.t, head_sync(:,15), fc_user, f_ex_test, 'Vận tốc góc Y (wy)');
    else
        evaluate_compensation(proc_data.t, head_sync(:,16), fc_user, f_ex_test, 'Vận tốc góc X (wx)');
    end
catch ME
    disp('----------------------------------------------------');
    fprintf('[!] CHƯƠNG TRÌNH DỪNG ĐỘT NGỘT DO LỖI:\n');
    disp(ME.message);
    fprintf('Dòng báo lỗi: %d\n', ME.stack(1).line);
end