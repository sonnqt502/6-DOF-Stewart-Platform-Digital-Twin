% test_donghocthuan.m
% Script kiểm tra hàm donghocthuan_NR

clear; clc;

% 1. Thiết lập thông số cơ bản (giống config của hệ thống)
ra = 589.7;
rb = 429.6;
alpha1 = 19.45;
beta1 = 53.32;
d_a = 38.9; % Chỉnh lại nếu có
d_b = 13.37; % Chỉnh lại nếu có
L1 = 150;
L2 = 747;

% Tính toán ma trận hình học
[A_mat, B_mat, gamma_ang] = calc_Geometry(ra, rb, alpha1, beta1, d_a, d_b);

% 2. Đặt một tư thế mẫu (Pose)
pose_true = [0, 0, 0, 0, 0, 0]; % [x, y, z, roll, pitch, yaw] mm và độ

% 3. Tính Động học ngược (IK) để lấy góc thực tế
[phi_raw_target, phi_out_target] = donghocnguoc_raw(pose_true, A_mat, B_mat, L1, L2, gamma_ang);

disp('--- KẾT QUẢ ĐỘNG HỌC NGƯỢC (IK) ---');
disp('Pose ban đầu (Tư thế thực):');
disp(pose_true);
disp('Góc servo tương ứng (phi_raw):');
disp(phi_raw_target);

% 4. Dùng thuật toán Newton-Raphson để giải Động học thuận (FK)
% Cần một điểm bắt đầu dự đoán (ví dụ [0, 0, 0, 0, 0, 0])
pose_guess = [0, 0, 0, 0, 0, 0];

[pose_solved, iter, err] = donghocthuan_NR(phi_raw_target, pose_guess, A_mat, B_mat, L1, L2, gamma_ang, 'raw');

disp('--- KẾT QUẢ ĐỘNG HỌC THUẬN (FK) - NEWTON RAPHSON ---');
disp(['Số vòng lặp hội tụ: ', num2str(iter)]);
disp(['Sai số góc lớn nhất (độ): ', num2str(err)]);
disp('Pose giải được (Từ FK):');
disp(pose_solved);

% Kiểm tra sai số pose
pose_error = pose_true - pose_solved;
disp('Sai lệch Pose (Thực tế vs FK):');
disp(pose_error);
