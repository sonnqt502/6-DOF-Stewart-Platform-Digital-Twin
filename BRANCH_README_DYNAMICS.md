# ⚙️ Nhánh: `feature/dynamics`

> **Chủ đề:** Động lực học (Dynamics) — tính moment, vận tốc, Jacobian động cơ và mô phỏng Simscape Multibody của Stewart Platform CKAS W2.

---

## Nội dung nhánh

Nhánh này chứa toàn bộ code liên quan đến **phân tích lực/moment**, **Jacobian động cơ**, và **mô hình Simscape** dùng để kiểm tra moment phát sinh trên 6 servo trong quá trình chuyển động.

---

## Các module chính

### Tính moment (Torque)

| File | Chức năng |
|---|---|
| `tinh_torque.m` | Tính moment động cơ tau_i đầy đủ (tải trọng + quán tính) |
| `tinh_vel.m` | Tính vận tốc tuyến tính và góc các khâu |
| `gui_torque_motion.m` | GUI xem phân bố moment theo quỹ đạo |
| `test_tinh_torque.m` | Kiểm thử hàm tinh_torque |

### Jacobian động cơ

| File | Chức năng |
|---|---|
| `jacobi.m` | Jacobian cơ sở (phiên bản tham khảo) |
| `jacobian_motor.m` | Jacobian góc motor ∂phi/∂x |
| `jacobian_RUS.m` | Jacobian vận tốc đầy đủ J(q) của cơ cấu RUS |
| `test_jacobian_motor.m` | Kiểm thử Jacobian động cơ |

### Mô hình Simscape

| File | Chức năng |
|---|---|
| `Final_CKASForSIM30_11_SIM.slx` | Mô hình Simscape Multibody 6-DOF |
| `Final_CKASForSIM30_11_SIM_DataFile.m` | Thông số vật liệu, khối lượng, quán tính |
| `load_simscape_params.m` | Nạp cấu hình vào workspace Simulink |
| `run_simulink.m` | Script chạy và thu kết quả Simscape |

### Điều chỉnh & Hiệu chỉnh

| File | Chức năng |
|---|---|
| `traj_to_motor_angle.m` | Chuyển quỹ đạo platform → góc 6 động cơ |
| `motion_calibration_gui.m` | GUI hiệu chỉnh chuyển động thực nghiệm |
| `gui_motor_angle.m` | GUI xem góc động cơ theo thời gian |
| `test_dynamic_motion.m` | Kiểm thử toàn bộ pipeline động lực học |

---

## Công thức cốt lõi

### Moment động cơ (Jacobian transpose method)

```
τ = Jᵀ · F_ext + M(q)·q̈ + C(q,q̇)·q̇ + G(q)
```

Trong đó:
- `J` — Jacobian vận tốc (6×6)
- `F_ext` — Lực/moment ngoài tại tâm platform
- `M(q)` — Ma trận quán tính tổng quát
- `G(q)` — Lực tĩnh (trọng lực)

### Jacobian vận tốc

```
ẋ = J(q) · q̇
q̇ = J⁻¹(q) · ẋ

J_i = (b_i - a_i)ᵀ / |b_i - a_i|  (hàng i của J)
```

---

## Mô hình Simscape

```
Final_CKASForSIM30_11_SIM.slx
├── 6× Revolute Joint (servo)
├── 6× Rigid Body (cánh tay L1 + thanh nối L2)
├── 6× Spherical Joint (khớp cầu tại B_i)
├── Rigid Body: Platform (1.5 kg)
└── World Frame
```

**Thông số vật liệu chính:**
- Khối lượng platform: `1.5 kg`
- Khối lượng cánh tay: `0.12 kg` mỗi cái
- Khối lượng thanh nối: `0.08 kg` mỗi cái

---

## Cách sử dụng

```matlab
% Nạp thông số và chạy Simulink
load_simscape_params
run_simulink

% Tính moment tại một pose cụ thể
tau = tinh_torque(phi, dphi, ddphi, config)

% Kiểm thử pipeline đầy đủ
test_dynamic_motion
```

---

## Liên kết

- Nhánh `feature/inverse-kinematics` — Cần IK/FK làm đầu vào
- Nhánh `feature/data` — Dữ liệu quỹ đạo thực nghiệm
- `main` — Dashboard & giao diện tổng hợp
