# Hướng dẫn kỹ thuật — Chạy Mô phỏng và Đánh giá Động lực học

> **Tham chiếu chuẩn:** Mục 4.1 (Trang 45–56) & Mục 4.2 (Trang 56–64), Đồ án tốt nghiệp *ĐATN_NQTS.pdf*.

---

## 1. Kiểm nghiệm Động học ngược và Mô phỏng Simscape (Double Check)

Để tái hiện quá trình kiểm chứng mức độ chính xác giữa động học ngược lý thuyết và mô phỏng Simscape như mô tả tại Trang 53–56 của ĐATN:

```matlab
% 1. Nạp cấu hình hình học và thông số vật lý
load_simscape_params;

% 2. Mở mô hình Simscape Multibody
open_system('Final_CKASForSIM30_11_SIM');

% 3. Chạy mô phỏng kiểm tra với tín hiệu thử nghiệm hình sin (ví dụ: Heave ±150 mm)
set_param('Final_CKASForSIM30_11_SIM', 'SimulationCommand', 'start');
```

---

## 2. Tính toán Moment Động cơ và Lực Khớp (`tinh_torque.m`)

```matlab
% Khởi tạo hình học chuẩn
[A_mat, B_mat, gamma_ang] = calc_Geometry(589.66, 429.566, 19.45, 53.32, 38.9, 10.0);
L1 = 150; L2 = 747;

% Định nghĩa trạng thái chuyển động tức thời
pose      = [0, 0, 795.4, 0, 5, 0];    % [x, y, z, roll, pitch, yaw] (mm, độ)
pose_dot  = [0, 0, 30, 0, 2, 0];       % [vx, vy, vz, vroll, vpitch, vyaw] (mm/s, độ/s)
pose_ddot = [0, 0, 100, 0, 10, 0];     % [ax, ay, az, aroll, apitch, ayaw] (mm/s², độ/s²)

% Tính moment và lực khớp
[tau_motor, tau_platform, tau_inertia, F_joint_Ci, F_joint_Bi, f_rod] = ...
    tinh_torque(pose, pose_dot, pose_ddot, A_mat, B_mat, L1, L2, gamma_ang);

% Xuất kết quả
fprintf('Moment yêu cầu tại 6 động cơ (N.m):\n');
disp(tau_motor');

fprintf('Lực kéo/nén trong 6 thanh truyền (N):\n');
disp(f_rod');
```

---

## 3. Khởi chạy Giao diện Giám sát Đồ họa

```matlab
% Mở giao diện xem phân bố Moment theo thời gian
gui_torque_motion;

% Mở giao diện xem biểu đồ góc động cơ
gui_motor_angle;
```
