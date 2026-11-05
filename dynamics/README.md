# ⚙️ Động lực học — Dynamics

> Nhánh `feature/dynamics` — Moment, Newton-Euler, Jacobian động cơ, Simscape

---

## Danh sách file

| File | Mô tả |
|---|---|
| `tinh_torque.m` | Moment đầy đủ: τ_motor, F_joint, f_rod |
| `tinh_vel.m` | Vận tốc động cơ RPM từ Jacobian |
| `jacobian_motor.m` | Jacobian động cơ ∂φ/∂x, q̈ |
| `jacobi.m` | Jacobian tham khảo (không dùng pipeline chính) |
| `jacobian_RUS.m` | Jacobian vận tốc J[6×6] |
| `load_simscape_params.m` | Nạp m_p, I_p, m_arm từ Simscape |
| `run_simulink.m` | Chạy mô hình Simscape Multibody |
| `Final_CKASForSIM30_11_SIM.slx` | Mô hình Simscape 6-DOF |
| `Final_CKASForSIM30_11_SIM_DataFile.m` | Thông số vật liệu, quán tính |
| `traj_to_motor_angle.m` | Quỹ đạo CSV → góc động cơ [N×6] |
| `gui_torque_motion.m` | GUI xem moment theo quỹ đạo |
| `gui_motor_angle.m` | GUI đồ thị góc động cơ |
| `motion_calibration_gui.m` | GUI hiệu chỉnh chuyển động |
| `test_dynamic_motion.m` | Kiểm thử pipeline đầy đủ |
| `test_jacobian_motor.m` | Kiểm thử Jacobian động cơ |
| `test_tinh_torque.m` | Kiểm thử tinh_torque |

---

## Công thức cốt lõi

### Moment động cơ (Jacobian Transpose + Newton-Euler)

$$\tau = J^T F_{ext} + M(q)\ddot{q} + C(q,\dot{q})\dot{q} + G(q)$$

Trong đó:
- $J$ [6×6] — Jacobian vận tốc
- $F_{ext}$ — Lực/moment ngoại tại tâm platform
- $G(q)$ — Thành phần trọng lực

### Lực dọc trục thanh nối

$$f_{rod,i} = s_i^T \cdot (m_{rod}\cdot a_{rod,i} - m_{rod}\cdot g)$$

Dương = kéo (tension), âm = nén (compression).

---

Xem **[USAGE.md](USAGE.md)** để chạy ngay.
