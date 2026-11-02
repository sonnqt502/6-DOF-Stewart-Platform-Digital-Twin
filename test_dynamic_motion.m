% TEST_DYNAMIC_MOTION.m
% Mô phỏng chuyển động bệ Stewart CKAS với Velocity Profile tam giác.
% Tại mỗi bước thời gian, tính đủ bộ:
%   (pose_k, vel_k, accel_k) --> tinh_vel --> RPM
%                             --> tinh_torque (nếu cần)
%
% Quy ước đơn vị:
%   Vị trí : mm, độ
%   Vận tốc : mm/s, độ/s
%   Gia tốc tịnh tiến : mm/s^2  (tinh_torque tự chia 1000 để ra m/s^2)
%   Gia tốc góc       : rad/s^2 (truyền thẳng)

clear; clc; close all;

%% 1. THÔNG SỐ CƠ KHÍ (Máy thực tế CKAS)
A = [ 556.009538774124, -107.962917791227, -448.046620982896, -448.046620982896, -107.962917791227,  556.009538774124;
     -196.347417584715, -579.692094117217, -383.344676532502,  383.344676532502,  579.692094117217,  196.347417584715;
      668.400000000000,  668.400000000000,  668.400000000000,  668.400000000000,  668.400000000000,  668.400000000000 ];

B = [ 256.599204538802,  169.981755823305, -426.649811653508, -426.641083944694,  170.050607114706,  256.659328121389;
     -344.505147401391, -394.503676843735,  -49.968856020786,   50.043319699002,  394.474003422177,  344.460357144733;
      0, 0, 0, 0, 0, 0 ];

gamma = [-109.45, -10.55, -229.45, -130.55, -349.45, -250.55]; % độ

L1 = 150; % mm
L2 = 747; % mm

%% 2. THAM SỐ CHUYỂN ĐỘNG (Triangular Velocity Profile)
dt      = 0.01;  % Bước thời gian (s)
t_accel = 1.0;   % Thời gian tăng tốc (s)
t_decel = 1.0;   % Thời gian giảm tốc (s)
T_total = t_accel + t_decel;
t = (0:dt:T_total)';
N = length(t);

% Vận tốc đỉnh
vx_max    = 25;  % mm/s
vroll_max = 4;   % độ/s

% Gia tốc không đổi trong từng giai đoạn (mm/s^2, độ/s^2)
ax_up   =  vx_max    / t_accel;
ax_dn   = -vx_max    / t_decel;
ar_up   =  vroll_max / t_accel;
ar_dn   = -vroll_max / t_decel;

%% 3. KHỞI TẠO BỘ NHỚ LỊCH SỬ
pose_history      = zeros(N, 6);  % [x, y, z, roll, pitch, yaw]  mm / độ
vel_history       = zeros(N, 6);  % [vx,vy,vz, vroll,vpitch,vyaw] mm/s / độ/s
accel_deg_history = zeros(N, 6);  % Gia tốc (mm/s^2 / độ/s^2) — để xuất file
motor_rpm_history = zeros(N, 6);  % Vòng/phút

% Tư thế Home
pose = [0, 0, 0, 0, 0, 0];

%% 4. VÒNG LẶP MÔ PHỎNG
for k = 1:N
    tk = t(k);

    % ---- 4a. Xác định vận tốc và gia tốc tức thời ----
    if tk <= t_accel
        vx_k  = ax_up * tk;
        vr_k  = ar_up * tk;
        ax_k  = ax_up;   % mm/s^2
        ar_k  = ar_up;   % độ/s^2
    else
        t_rem = tk - t_accel;
        vx_k  = vx_max + ax_dn * t_rem;
        vr_k  = vroll_max + ar_dn * t_rem;
        ax_k  = ax_dn;
        ar_k  = ar_dn;
    end

    % Đảm bảo không vượt ngưỡng do sai số dấu phẩy động
    vx_k = max(0, vx_k);
    vr_k = max(0, vr_k);

    vel_deg   = [vx_k, 0, 0, vr_k,  0, 0];   % mm/s, độ/s
    accel_deg = [ax_k, 0, 0, ar_k, 0, 0];     % mm/s^2, độ/s^2

    % ---- 4b. Chuyển gia tốc góc sang rad/s^2 để truyền vào tinh_vel và tinh_torque ----
    vel_rad   = vel_deg;
    vel_rad(4:6)   = deg2rad(vel_deg(4:6));   % mm/s, rad/s

    accel_rad = accel_deg;
    accel_rad(4:6) = deg2rad(accel_deg(4:6)); % mm/s^2, rad/s^2

    % ---- 4c. Tích phân vị trí (Euler Forward) ----
    if k > 1
        pose = pose + vel_deg * dt;
    end

    % ---- 4d. Tính RPM bằng Jacobian tại (pose, vel) hiện tại ----
    try
        [rpm, ~, ~] = tinh_vel(pose, vel_deg, A, B, L1, L2, gamma);
    catch
        rpm = zeros(6,1);
        warning('tinh_vel: Kịch cơ khí tại k=%d, t=%.3fs', k, tk);
    end

    % ---- 4e. Lưu lịch sử ----
    pose_history(k, :)      = pose;
    vel_history(k, :)       = vel_deg;
    accel_deg_history(k, :) = accel_deg;
    motor_rpm_history(k, :) = rpm';
end

%% 5. ĐỒ THỊ
figure('Name', 'CKAS Stewart - Triangular Motion', 'Position', [80 80 1200 700]);

subplot(2,2,1);
plot(t, vel_history(:,1), 'b-', 'LineWidth', 2); hold on;
plot(t, vel_history(:,4), 'r-', 'LineWidth', 2);
xlabel('Thời gian (s)'); ylabel('Vận tốc');
title('Velocity Profile');
legend('v_x (mm/s)', 'v_{roll} (°/s)'); grid on;

subplot(2,2,2);
plot(t, pose_history(:,1), 'b-', 'LineWidth', 2); hold on;
plot(t, pose_history(:,4), 'r-', 'LineWidth', 2);
xlabel('Thời gian (s)'); ylabel('Vị trí');
title('Pose của Bệ động');
legend('X (mm)', 'Roll (°)'); grid on;

subplot(2,2,[3 4]);
plot(t, motor_rpm_history, 'LineWidth', 1.5);
xlabel('Thời gian (s)'); ylabel('Tốc độ (RPM)');
title('Tốc độ yêu cầu 6 Động cơ');
legend('M1','M2','M3','M4','M5','M6','Location','Best'); grid on;

disp('Mô phỏng hoàn tất!');

%% 6. XUẤT FILE 15 THAM SỐ (Định dạng Moog ~M)
disp('Đang xuất file 15 tham số...');

% Xác định đường dẫn lưu file ngay bên cạnh script này
script_dir = fileparts(mfilename('fullpath'));
if isempty(script_dir), script_dir = pwd; end
file_path = fullfile(script_dir, 'Motion_Command_15Params.csv');

fid = fopen(file_path, 'w');
if fid == -1
    error('Không thể tạo file: %s', file_path);
end

g_val = 9.81; % m/s^2

for k = 1:N
    % Trích xuất Pose tại bước k
    x_k  = pose_history(k,1); y_k = pose_history(k,2); z_k = pose_history(k,3);
    r_k  = pose_history(k,4); p_k = pose_history(k,5); yw_k = pose_history(k,6);

    % Ma trận quay R tại tư thế hiện tại
    cy = cosd(yw_k); sy = sind(yw_k);
    cp = cosd(p_k);  sp = sind(p_k);
    cr = cosd(r_k);  sr = sind(r_k);
    R_k = [cy*cp,  cy*sp*sr - sy*cr,  cy*sp*cr + sy*sr;
           sy*cp,  sy*sp*sr + cy*cr,  sy*sp*cr - cy*sr;
           -sp,    cp*sr,             cp*cr            ];

    % Gia tốc tịnh tiến World (đổi mm/s^2 -> m/s^2 để đồng nhất với g_val)
    aw_ms2 = [accel_deg_history(k,1); 0; 0] / 1000;

    % Chiếu gia tốc quán tính lên Body Frame
    a_body = R_k' * aw_ms2;
    ax_i = a_body(1); ay_i = a_body(2); az_i = a_body(3);

    % Chiếu trọng lực lên Body Frame
    g_body = R_k' * [0; 0; g_val];
    axg = g_body(1); ayg = g_body(2); azg = g_body(3);

    % Vận tốc góc Euler (độ/s) -> Body Frame (rad/s -> độ/s)
    dRoll = vel_history(k,4); dPitch = vel_history(k,5); dYaw = vel_history(k,6);
    E_body = [1,  0,          -sind(p_k);
              0,  cosd(r_k),   sind(r_k)*cosd(p_k);
              0, -sind(r_k),   cosd(r_k)*cosd(p_k)];
    w_body = E_body * [dRoll; dPitch; dYaw];
    wx_b = w_body(1); wy_b = w_body(2); wz_b = w_body(3);

    % Ghi dòng ~M 15 tham số
    fprintf(fid, '%.4f ~M[ %.4f %.4f %.4f %.4f %.4f %.4f [ %.6f %.6f %.6f %.6f %.6f %.6f %.6f %.6f %.6f ]]\n', ...
        t(k), x_k, y_k, z_k, yw_k, p_k, r_k, ...
        ax_i, ay_i, az_i, axg, ayg, azg, wz_b, wy_b, wx_b);
end

fclose(fid);
fprintf('Đã xuất thành công: %s\n', file_path);
