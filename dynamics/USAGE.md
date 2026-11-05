# Hướng dẫn sử dụng — Dynamics

## 1. Tính moment tại một pose cụ thể

```matlab
% Khởi tạo hình học (xem kinematics/USAGE.md)
[A_mat, B_mat, gamma_ang] = calc_Geometry(589.66, 429.566, 19.45, 53.32, 38.9, 10.0);
L1 = 150; L2 = 747;

% Pose, vận tốc, gia tốc
pose      = [0, 0, 795.4, 0, 10, 0];       % (mm, °)
pose_dot  = [0, 0, 0, 0, 2, 0];            % (mm/s, °/s)
pose_ddot = [0, 0, 0, 0, 0.5, 0];          % (mm/s², °/s²)

% Tính moment (dùng thông số mặc định từ load_simscape_params)
[tau, tau_p, tau_I, Fci, Fbi, f_rod] = tinh_torque(pose, pose_dot, pose_ddot, ...
    A_mat, B_mat, L1, L2, gamma_ang);

fprintf('Moment động cơ [N·m]:\n');
disp(tau')
fprintf('Lực trục thanh nối [N]:\n');
disp(f_rod')
```

---

## 2. Tính vận tốc động cơ (RPM)

```matlab
vel = [0, 0, 20, 0, 0, 0];  % heave 20 mm/s
[rpm, J_v, phi] = tinh_vel(pose, vel, A_mat, B_mat, L1, L2, gamma_ang);
fprintf('RPM động cơ: %s\n', num2str(rpm, '%.1f '));
```

---

## 3. Chạy mô hình Simscape

```matlab
load_simscape_params   % Nạp thông số vào workspace
run_simulink           % Mở và chạy Final_CKASForSIM30_11_SIM.slx
```

---

## 4. Chuyển quỹ đạo CSV → góc động cơ

```matlab
% Xuất bảng [N×6] góc động cơ theo thời gian
phi_traj = traj_to_motor_angle('Platform_Command.csv', A_mat, B_mat, L1, L2, gamma_ang);
% phi_traj: [N×6] (°)
```

---

## 5. GUI xem moment

```matlab
gui_torque_motion   % Load file CSV và xem phân bố τ theo t
gui_motor_angle     % Xem đồ thị 6 góc động cơ
```

---

## Thông số vật lý mặc định (CKAS W2)

| Tham số | Giá trị | Đơn vị |
|---|---|---|
| Khối lượng bàn máy `m_p` | 30.065 | kg |
| I_xx = I_zz | 9.85 | kg·m² |
| I_yy | 19.65 | kg·m² |
| Khối lượng tay quay `m_arm` | 1.585 | kg |
| Quán tính rotor `I_rotor` | ~0.005 | kg·m² |

> Các giá trị này được nạp tự động từ `load_simscape_params`. Có thể override bằng cách truyền trực tiếp vào `tinh_torque`.
