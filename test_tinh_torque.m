% TEST_TINH_TORQUE.m
% Kiểm tra hàm tính moment động cơ tinh_torque.m

clear; clc; close all;

%% 1. Khởi tạo cấu hình hình học (CKAS thực tế)
ra = 600; rb = 350; alpha1 = 25; beta1 = 15; da = 70; db = 50;
[A_mat, B_mat, gamma_ang] = calc_Geometry(ra, rb, alpha1, beta1, da, db);
L1 = 150; L2 = 747;

m_platform = 30.0; % kg
I_platform = [9.85, 19.65, 9.85]; % kg*m^2

fprintf('======================================================\n');
fprintf('       KIỂM TRA HÀM TÍNH MOMENT ĐỘNG CƠ (TINH_TORQUE) \n');
fprintf('======================================================\n\n');

%% TEST 1: Tải tĩnh tại vị trí Trung tính (Neutral Static Pose)
pose_home = [0, 0, 0, 0, 0, 0];
pose_dot0 = zeros(1, 6);
pose_ddot0 = zeros(1, 6);

[tau_motor_static, tau_p_static, ~] = tinh_torque(...
    pose_home, pose_dot0, pose_ddot0, A_mat, B_mat, L1, L2, gamma_ang, m_platform, I_platform);

fprintf('[TEST 1] MOMENT TĨNH TẠI POSE HOME (m_p = %.1f kg):\n', m_platform);
for i = 1:6
    fprintf('  Motor %d: %8.3f N.m  (Thành phần bệ động: %8.3f N.m)\n', ...
        i, tau_motor_static(i), tau_p_static(i));
end
fprintf('  Max moment tĩnh: %.3f N.m\n\n', max(abs(tau_motor_static)));

%% TEST 2: Chuyển động Heave Sinusoidal Z(t) = 50*sin(2*pi*f*t) mm
dt = 0.01; t = (0:dt:2)'; N = length(t);
f_freq = 1.0; Amp_z = 50; % mm

tau_hist = zeros(N, 6);
qdot_hist = zeros(N, 6);
qdeg_hist = zeros(N, 6);

for k = 1:N
    tk = t(k);
    z_k = Amp_z * sin(2*pi*f_freq*tk);
    vz_k = Amp_z * (2*pi*f_freq) * cos(2*pi*f_freq*tk);
    az_k = -Amp_z * (2*pi*f_freq)^2 * sin(2*pi*f_freq*tk);
    
    pose_k = [0, 0, z_k, 0, 0, 0];
    vel_k  = [0, 0, vz_k, 0, 0, 0];
    acc_k  = [0, 0, az_k, 0, 0, 0];
    
    [tau_k, ~, ~] = tinh_torque(...
        pose_k, vel_k, acc_k, A_mat, B_mat, L1, L2, gamma_ang, m_platform, I_platform);
    
    [~, q_dot_k, ~] = jacobian_motor(pose_k, vel_k, acc_k, A_mat, B_mat, L1, L2, gamma_ang);
    phi_k = donghocnguoc_final1(pose_k, A_mat, B_mat, L1, L2, gamma_ang);
    
    tau_hist(k, :) = tau_k';
    qdot_hist(k, :) = (q_dot_k * 30 / pi)'; % rad/s -> RPM
    qdeg_hist(k, :) = phi_k;
end

fprintf('[TEST 2] MO PHONG DAO DONG HEAVE (Amp = %d mm, f = %.1f Hz):\n', Amp_z, f_freq);
fprintf('  Max moment dong co dat duoc: %.3f N.m\n', max(abs(tau_hist(:))));
fprintf('  Min moment dong co dat duoc: %.3f N.m\n', min(tau_hist(:)));
fprintf('  Max toc do quay dat duoc   : %.3f RPM\n\n', max(abs(qdot_hist(:))));

fprintf('-> TAT CA BIEN DOI MAT-TOAN DA SAN SANG DE DUA VAO GUI!\n');
