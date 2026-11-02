% run_forward_kinematics.m
% Script để bạn nhập trực tiếp 6 góc động cơ và lấy ra vị trí thực tế

clear; clc;

% =========================================================================
% 1. CÀI ĐẶT THÔNG SỐ CƠ CẤU (Giữ nguyên như chương trình hiện tại của bạn)
% =========================================================================
ra = 589.7;
rb = 429.6;
alpha1 = 19.45;
beta1 = 53.32;
d_a = 39.9; 
d_b = 13.37; 
L1 = 150;
L2 = 747;

% Tính toán tọa độ chân đế và bệ
[A_mat, B_mat, gamma_ang] = calc_Geometry(ra, rb, alpha1, beta1, d_a, d_b);

% =========================================================================
% 2. NHẬP GÓC ĐỘNG CƠ CỦA BẠN VÀO ĐÂY
% =========================================================================
% Nhập mảng 6 góc của 6 motor (đơn vị độ)
phi_input = [53.1, 53.1, 53.1, 53.1, 53.1, 53.1]; 

% =========================================================================
% 3. GIẢI BÀI TOÁN TÌM VỊ TRÍ
% =========================================================================
% Điểm đoán ban đầu 
pose_guess = [0, 0, 0, 0, 0, 0]; 

disp('----------------------------------------------------');
disp('Đang giải Động học thuận (Newton-Raphson)...');
[pose_solved, iter, err] = donghocthuan_NR(phi_input, pose_guess, A_mat, B_mat, L1, L2, gamma_ang);

% =========================================================================
% 4. XUẤT KẾT QUẢ
% =========================================================================
if isinf(err)
    disp('CẢNH BÁO: Bộ góc nhập vào không hợp lệ (không tạo thành cơ cấu thật hoặc ngoài vùng làm việc)!');
else
    disp('HỘI TỤ THÀNH CÔNG!');
    disp(['Số vòng lặp: ', num2str(iter)]);
    disp(['Sai số góc cuối cùng: ', num2str(err, '%.2e'), ' độ']);
    disp(' ');
    disp('>>> VỊ TRÍ THỰC TẾ CỦA BÀN MÁY LÀ:');
    fprintf('  X     = %8.3f (mm)\n', pose_solved(1));
    fprintf('  Y     = %8.3f (mm)\n', pose_solved(2));
    fprintf('  Z     = %8.3f (mm)\n', pose_solved(3));
    fprintf('  Roll  = %8.3f (độ)\n', pose_solved(4));
    fprintf('  Pitch = %8.3f (độ)\n', pose_solved(5));
    fprintf('  Yaw   = %8.3f (độ)\n', pose_solved(6));
end
disp('----------------------------------------------------');
