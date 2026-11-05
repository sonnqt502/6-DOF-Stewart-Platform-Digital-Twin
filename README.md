<h1 align="center">🤖 6-DOF Stewart Platform Digital Twin — CKAS W2</h1>

<p align="center">
  <b>Đồ án tốt nghiệp</b> — Thiết kế, mô phỏng số và phân tích động lực học<br>
  Bàn nâng hạ 6 bậc tự do Stewart Platform kiểu <b>RUS</b> ứng dụng trong buồng lái mô phỏng <b>CKAS W2</b>
</p>

<p align="center">
  <img src="docs/platform_diagram.png" width="600" alt="Stewart Platform CKAS W2"/>
</p>

---

## 📌 Mục lục

- [Tổng quan đồ án](#-tổng-quan-đồ-án)
- [Tiến độ & Thành tựu](#-tiến-độ--thành-tựu)
- [Thông số hệ thống](#-thông-số-hệ-thống)
- [Kiến trúc phần mềm](#-kiến-trúc-phần-mềm)
- [Chi tiết Input / Output toàn hệ thống](#-chi-tiết-input--output-toàn-hệ-thống)
- [Catalogue từng file code](#-catalogue-từng-file-code)
- [Sơ đồ liên kết giữa các function](#-sơ-đồ-liên-kết-giữa-các-function)
- [Nhánh chuyên đề](#-nhánh-chuyên-đề)
- [Cài đặt & Chạy nhanh](#-cài-đặt--chạy-nhanh)

---

## 🎯 Tổng quan đồ án

Dự án xây dựng **Digital Twin** hoàn chỉnh cho hệ thống buồng lái mô phỏng chuyển động **CKAS W2**, sử dụng cơ cấu **Stewart Platform 6 bậc tự do** kiểu **RUS** (Revolute – Universal – Spherical joint).

| Hạng mục | Mô tả |
|---|---|
| **Loại cơ cấu** | 6-RUS Stewart Platform (Rotary Actuator) |
| **Phần mềm** | MATLAB R2023b, Simscape Multibody, Python 3.11 |
| **Phương pháp IK** | Hình học giải tích — phương trình vòng kín |
| **Phương pháp FK** | Newton-Raphson lặp (hội tụ < 100 iter) |
| **Phương pháp động lực học** | Newton-Euler ngược + Virtual Work |
| **Mô hình 3D** | Simscape Multibody + VisPy (Python) |
| **Dữ liệu đầu vào** | M-Code CSV từ bộ điều khiển CKAS (7 hoặc 15 tham số) |

### Mục tiêu đồ án

1. **Giải bài toán động học ngược (IK)** từ pose `[x, y, z, roll, pitch, yaw]` → 6 góc servo
2. **Giải bài toán động học thuận (FK)** từ 6 góc servo → pose thực tế (Newton-Raphson)
3. **Tính Jacobian vận tốc** cho cơ cấu RUS → từ đó tính vận tốc và gia tốc khâu
4. **Tính moment động cơ** (Inverse Dynamics) theo Newton-Euler + Nguyên lý Công ảo
5. **Mô phỏng Simscape Multibody** để xác minh kết quả lý thuyết
6. **Dashboard MATLAB** hiển thị real-time 3D + đồ thị + kiểm định an toàn
7. **Python Viewer** (VisPy) để phát lại mô phỏng độc lập không cần MATLAB

---

## ✅ Tiến độ & Thành tựu

### Đã hoàn thành

| # | Hạng mục | Trạng thái | Ghi chú |
|---|---|---|---|
| 1 | **Mô hình hình học** (calc_Geometry) | ✅ Hoàn thành | Tính A_i, B_i, γ_i từ 6 tham số đầu vào |
| 2 | **Động học ngược IK** (donghocnguoc_final1) | ✅ Hoàn thành | Hình học giải tích, 3-layer safety check |
| 3 | **Jacobian vận tốc** (jacobian_RUS) | ✅ Hoàn thành | Loop closure velocity method |
| 4 | **Động học thuận FK** (donghocthuan_NR) | ✅ Hoàn thành | Newton-Raphson, dung sai 1e-6° |
| 5 | **Vận tốc động cơ** (tinh_vel) | ✅ Hoàn thành | Xuất RPM + Jacobian 6×6 |
| 6 | **Moment động cơ** (tinh_torque) | ✅ Hoàn thành | Newton-Euler đầy đủ, 6 output |
| 7 | **Jacobian động cơ** (jacobian_motor) | ✅ Hoàn thành | ∂φ/∂x, ∂²φ/∂t² |
| 8 | **Kiểm định an toàn 3 lớp** (check_pose_safety) | ✅ Hoàn thành | IK + giới hạn servo + kỳ dị |
| 9 | **Dashboard MATLAB** (Dashboard_Stewart5) | ✅ Hoàn thành | Real-time 3D, 30 FPS, real-time sync |
| 10 | **Sinh quỹ đạo** (Trajectory_Generator) | ✅ Hoàn thành | 13 loại quỹ đạo, tâm quay ảo |
| 11 | **Mô hình Simscape** (.slx) | ✅ Hoàn thành | Xác minh kết quả lý thuyết |
| 12 | **Python 3D Viewer** (sim.py) | ✅ Hoàn thành | VisPy + PyQt5, animation thread |
| 13 | **Phân tích workspace** | ✅ Hoàn thành | Monte Carlo, giới hạn không gian |

### Đang phát triển / Mở rộng

| # | Hạng mục | Trạng thái | Kế hoạch |
|---|---|---|---|
| 14 | Bộ điều khiển PID / adaptive | 🔄 Chưa bắt đầu | Điều khiển vòng kín |
| 15 | Xuất M-Code từ dữ liệu IMU thực | 🔄 Một phần | Đã có pipeline xử lý |
| 16 | Tích hợp hardware-in-loop | 🔄 Chưa bắt đầu | Kết nối ESP32/STM32 |

---

## ⚙️ Thông số hệ thống

### Thông số hình học

| Ký hiệu | Giá trị | Đơn vị | Mô tả |
|---|---|---|---|
| `ra` | 589.66 | mm | Bán kính vòng tròn phân bố khớp đế |
| `rb` | 429.566 | mm | Bán kính vòng tròn phân bố khớp bàn máy |
| `L1` | 150 | mm | Chiều dài tay quay servo (servo arm) |
| `L2` | 747 | mm | Chiều dài thanh nối (connecting rod) |
| `α₁` | 19.45 | ° | Góc phân bố cặp khớp đầu tiên ở đế |
| `δ_a` | 38.9 | ° | Góc lệch giữa 2 khớp trong mỗi cặp ở đế |
| `β₁` | 53.32 | ° | Góc phân bố cặp khớp đầu tiên ở bàn máy |
| `δ_b` | 10.0 | ° | Góc lệch giữa 2 khớp trong mỗi cặp ở bàn máy |
| `Z_base` | 795.4−202+75 | mm | Độ cao mặt phẳng đế (hệ tọa độ thế giới) |

### Thông số servo & giới hạn an toàn

| Thông số | Giá trị | Đơn vị |
|---|---|---|
| Giới hạn góc servo min | −50 | ° |
| Giới hạn góc servo max | +90 | ° |
| Ngưỡng kỳ dị `abs(det(J))` | > 1×10⁻³ | — |
| Khối lượng bàn máy `m_p` | 30.065 | kg |
| Quán tính `I_xx = I_zz` | 9.85 | kg·m² |
| Quán tính `I_yy` | 19.65 | kg·m² |
| Khối lượng tay quay `m_arm` | 1.585 | kg |

### Không gian làm việc (Workspace)

| DOF | Phạm vi | Đơn vị |
|---|---|---|
| Surge (X) | ±80 | mm |
| Sway (Y) | ±80 | mm |
| Heave (Z) | +650 ÷ +950 | mm |
| Roll | ±20 | ° |
| Pitch | ±20 | ° |
| Yaw | ±15 | ° |

---

## 🏗️ Kiến trúc phần mềm

```
┌─────────────────────────────────────────────────────────────┐
│                    INPUT LAYER                              │
│  config.json │ Platform_Command.csv │ Motor_Angles.csv      │
│  (cấu hình)  │  (quỹ đạo M-Code)   │  (đo thực tế)         │
└──────┬───────────────┬──────────────────────┬───────────────┘
       │               │                      │
       ▼               ▼                      ▼
┌──────────────┐ ┌───────────────────┐ ┌──────────────────┐
│calc_Geometry │ │Trajectory_Generator│ │  donghocthuan_NR │
│  A_i,B_i,γ_i│ │  sinh quỹ đạo    │ │  FK (góc→pose)   │
└──────┬───────┘ └────────┬──────────┘ └────────┬─────────┘
       │                  │                     │
       └────────┬─────────┘                     │
                ▼                               │
┌───────────────────────────────────┐           │
│       KINEMATICS LAYER            │           │
│  donghocnguoc_final1 (IK)         │◄──────────┘
│  jacobian_RUS (Jacobian J)        │
│  check_pose_safety (3-layer)      │
└──────┬────────────────────────────┘
       │
       ▼
┌───────────────────────────────────┐
│       DYNAMICS LAYER              │
│  tinh_vel   (RPM động cơ)         │
│  jacobian_motor (∂φ/∂x)          │
│  tinh_torque (τ Newton-Euler)     │
└──────┬────────────────────────────┘
       │
       ▼
┌───────────────────────────────────────────────────────────┐
│                   VISUALIZATION LAYER                     │
│  Dashboard_Stewart5.m (MATLAB App)  │  sim.py (Python)   │
│  - 3D real-time (30 FPS)            │  - VisPy + PyQt5   │
│  - 6 đồ thị góc, RPM, torque        │  - Animation thread│
│  - Safety check hiển thị trực quan  │  - M-Code parser   │
└───────────────────────────────────────────────────────────┘
```

---

## 📥📤 Chi tiết Input / Output toàn hệ thống

### Luồng dữ liệu chính (Pipeline IK)

```
pose [x,y,z,R,P,Y]  ──►  IK  ──►  phi_out [φ₁..φ₆]  ──►  Servo Driver
        (mm, °)              (°)              (°)
```

### Luồng dữ liệu ngược (Pipeline FK)

```
phi_measured [φ₁..φ₆]  ──►  FK (NR)  ──►  pose_out [x,y,z,R,P,Y]
        (°)                  (~iter)             (mm, °)
```

### Luồng tính động lực học

```
pose + pose_dot + pose_ddot  ──►  tinh_torque  ──►  τ [N·m] × 6 động cơ
        (mm, °, °/s, °/s²)                           + F_joint [N] × 6 khớp
```

---

## 📚 Catalogue từng file code

### Nhóm 1 — Hình học (Geometry)

#### `calc_Geometry.m`
> Tính toán cấu hình hình học tĩnh của Stewart Platform — **hàm khởi đầu bắt buộc gọi trước tất cả**.

| | Chi tiết |
|---|---|
| **Input** | `ra` (mm), `rb` (mm), `alpha1` (°), `beta1` (°), `d_a` (°), `d_b` (°) |
| **Output** | `A_mat` [3×6 mm], `B_mat` [3×6 mm], `gamma_ang` [1×6 °] |
| **Phụ thuộc** | Không |
| **Gọi bởi** | `Dashboard_Stewart5`, `Trajectory_Generator`, tất cả hàm kinematics |
| **Chú ý** | Comment "Đừng sửa file này" — đây là file chuẩn tham chiếu |

#### `tinhvitriA.m`
| | Chi tiết |
|---|---|
| **Input** | `ra` (mm), `alpha1` (°), `d_a` (°) |
| **Output** | `A` [3×6 mm], `alpha` [1×6 °] |
| **Chú ý** | Phiên bản độc lập (không tích hợp B và gamma). Z cứng = −593.4 mm |

#### `tinhvitriB.m`
| | Chi tiết |
|---|---|
| **Input** | `rb` (mm), `beta1` (°), `d_b` (°) |
| **Output** | `B` [3×6 mm] |

#### `tinhgamma.m`
| | Chi tiết |
|---|---|
| **Input** | `alpha1` (°), `d_a` (°) |
| **Output** | `g` [1×6 °] — góc gá motor |

#### `matranquay.m`
| | Chi tiết |
|---|---|
| **Input** | `roll` (°), `pitch` (°), `yaw` (°) |
| **Output** | `R` [3×3] — ma trận quay ZYX |
| **Phụ thuộc** | Không |

---

### Nhóm 2 — Động học ngược (Inverse Kinematics)

#### `donghocnguoc_final1.m` ⭐ CORE
> Hàm IK chính thức, đồng bộ với Dashboard_Stewart5. Trả về góc servo **sau offset** sẵn sàng gửi driver.

| | Chi tiết |
|---|---|
| **Input** | `pose` [1×6: x,y,z,roll,pitch,yaw] (mm,°), `A_mat` [3×6], `B_mat` [3×6], `L1` (mm), `L2` (mm), `gamma_ang` [1×6 °] |
| **Output** | `phi_out` [1×6 °] — góc servo thực (`phi_thuc`). Trả về `NaN` nếu không khả thi |
| **Phụ thuộc** | Không (tự tính) |
| **Gọi bởi** | `check_pose_safety`, `donghocthuan_NR`, `Dashboard_Stewart5`, `jacobian_RUS` |
| **Công thức** | `Q/(√(M²+N²)) = sin(α+φ)` → `φ_raw = asin(Q/√(M²+N²)) - atan2(N,M)` |
| **Offset** | Khớp lẻ: `-(90+φ_raw) − 90`, đảo dấu. Khớp chẵn: `(90+φ_raw) + 90` |

#### `check_pose_safety.m` ⭐ SAFETY GATE
> Cổng kiểm định 3 lớp — gọi trước mọi lệnh di chuyển.

| | Chi tiết |
|---|---|
| **Input** | `pose` [1×6], `A_mat`, `B_mat`, `L1`, `L2`, `gamma_ang` |
| **Output** | `is_safe` (bool), `error_msg` (string), `phi_out` [1×6 °] |
| **Lớp 1** | IK → NaN? → reject |
| **Lớp 2** | `phi_out` ∈ [−60°, +100°]? → reject nếu ngoài |
| **Lớp 3** | `abs(det(J)) > 1e-3`? → reject nếu kỳ dị |
| **Phụ thuộc** | `donghocnguoc_final1`, `kiem_tra_ki_di_optimized` |

#### `kiem_tra_ki_di_optimized.m`
| | Chi tiết |
|---|---|
| **Input** | `pose` [1×6], `A_mat` [3×6], `B_mat` [3×6] |
| **Output** | `is_singular` (bool), `detJ` (scalar) |
| **Chú ý** | Tính det(J) xấp xỉ nhanh (không cần L1, L2 đầy đủ) |

---

### Nhóm 3 — Động học thuận (Forward Kinematics)

#### `donghocthuan_NR.m` ⭐ CORE
> Giải FK bằng Newton-Raphson. Gọi IK lặp để tìm pose thỏa mãn góc đặt.

| | Chi tiết |
|---|---|
| **Input** | `phi_target` [1×6 °], `pose_guess` [1×6], `A_mat`, `B_mat`, `L1`, `L2`, `gamma_ang` |
| **Output** | `pose_out` [1×6], `iter` (số vòng lặp), `err` (°, sai số cuối) |
| **Dung sai** | 1×10⁻⁶ ° |
| **Max iter** | 100 |
| **Phụ thuộc** | `donghocnguoc_final1`, `jacobian_RUS` |
| **Gọi bởi** | `run_forward_kinematics`, `test_donghocthuan` |

---

### Nhóm 4 — Jacobian & Vận tốc

#### `jacobian_RUS.m` ⭐ CORE
> Jacobian vận tốc 6×6 theo phương pháp Loop Closure Velocity.

| | Chi tiết |
|---|---|
| **Input** | `pose` [1×6], `pose_dot` [1×6 mm/s, °/s], `A_mat`, `B_mat`, `L1`, `L2`, `gamma_ang` |
| **Output** | `J` [6×6] — `φ̇_raw(rad/s) = J · [v_p; ω_p]`, `theta_dot` [6×1 °/s] |
| **Phụ thuộc** | `donghocnguoc_raw` (lấy phi_raw) |
| **Gọi bởi** | `donghocthuan_NR`, `tinh_torque`, `jacobian_motor` |

#### `tinh_vel.m`
> Tính vận tốc động cơ theo RPM từ Jacobian.

| | Chi tiết |
|---|---|
| **Input** | `pose` [1×6], `vel` [1×6 mm/s, °/s], `A`, `B`, `L1`, `L2`, `gamma_ang` |
| **Output** | `motor_vel_rpm` [1×6 RPM], `J_v` [6×6], `phi_thuc` [1×6 °] |

#### `jacobian_motor.m`
| | Chi tiết |
|---|---|
| **Input** | `pose`, `pose_dot`, `pose_ddot`, `A_mat`, `B_mat`, `L1`, `L2`, `gamma_ang` |
| **Output** | `J_q` [6×6], `q_dot` [6×1 rad/s], `q_ddot` [6×1 rad/s²] |
| **Gọi bởi** | `tinh_torque` |

#### `jacobi.m`
| | Chi tiết |
|---|---|
| **Chú ý** | Phiên bản Jacobian gốc/tham khảo — không dùng trong pipeline chính |

---

### Nhóm 5 — Động lực học (Dynamics)

#### `tinh_torque.m` ⭐ CORE
> Tính đầy đủ moment động cơ và lực khớp theo Newton-Euler ngược.

| | Chi tiết |
|---|---|
| **Input** | `pose` [1×6 mm,°], `pose_dot` [1×6 mm/s,°/s], `pose_ddot` [1×6 mm/s²,°/s²], `A_mat`, `B_mat`, `L1`, `L2`, `gamma_ang`, `m_platform` (kg), `I_platform` [1×3 kg·m²], `I_rotor` (kg·m²), `m_arm` (kg), `m_rod` (kg) |
| **Output** | `tau_motor` [6×1 N·m], `tau_platform` [6×1 N·m], `tau_inertia` [6×1 N·m], `F_joint_Ci` [3×6 N], `F_joint_Bi` [3×6 N], `f_rod` [6×1 N] |
| **Phụ thuộc** | `jacobian_motor`, `load_simscape_params` |
| **Gọi bởi** | `gui_torque_motion`, `test_tinh_torque` |
| **Mặc định** | Tự nạp từ `load_simscape_params` nếu thiếu tham số |

---

### Nhóm 6 — Giao diện (GUI / Dashboard)

#### `Dashboard_Stewart5.m` ⭐ ENTRY POINT
> Giao diện tổng hợp — điểm vào chính của toàn bộ hệ thống.

| | Chi tiết |
|---|---|
| **Input (nội bộ)** | Người dùng nhập tham số trên GUI; đọc `config.json`; nạp file CSV M-Code |
| **Output** | Hiển thị 3D real-time, 6 đồ thị góc/RPM/torque, trạng thái an toàn |
| **Pipeline** | `calc_Geometry` → `donghocnguoc_final1` × N điểm → `tinh_vel` → `tinh_torque` → animation |
| **FPS** | ~30 FPS (tính `step = max(1, round(1/30/dt))`) |
| **Real-time sync** | `tic`/`toc` + `pause()` động |
| **Phụ thuộc** | Toàn bộ Nhóm 1-5 |

#### `Trajectory_Generator.m`
> Sinh và xuất quỹ đạo theo 13 kiểu chuyển động.

| | Chi tiết |
|---|---|
| **Input** | Tham số GUI: loại quỹ đạo, biên độ, tần số, thời gian, tâm quay Pivot |
| **Output** | File CSV 7-cột `[t, x, y, z, roll, pitch, yaw]` |
| **Loại quỹ đạo** | Surge, Sway, Heave, Roll, Pitch, Yaw, Circle XY, Roll+Pitch, Z+Pitch, Spiral, S-curve |
| **Pivot** | Tâm bàn máy / Đỉnh đầu người / Custom tọa độ |

#### `gui_motor_angle.m`
> Hiển thị đồ thị 6 góc động cơ theo thời gian từ file CSV.

#### `gui_torque_motion.m`
> Hiển thị phân bố moment 6 động cơ theo quỹ đạo.

#### `motion_calibration_gui.m`
> GUI hiệu chỉnh mapping giữa quỹ đạo đầu vào và phản hồi thực.

#### `kinematic_demo_gui.m`
> Demo tương tác: kéo thanh trượt → 3D cập nhật trực tiếp.

---

### Nhóm 7 — Phân tích Workspace

#### `plot_workspace_limits.m`
| | Chi tiết |
|---|---|
| **Input** | `A_mat`, `B_mat`, `L1`, `L2`, `gamma_ang` |
| **Output** | Đồ thị giới hạn workspace (Z vs Roll, Z vs Pitch, v.v.) |

#### `flat_workspace.m` / `rotate_workspace.m`
> Phân tích workspace mặt phẳng (z cố định) và workspace xoay (roll/pitch cố định).

#### `find_nominal_L_limits.m` / `find_L_limits_FK_MonteCarlo.m`
> Tìm giới hạn chiều dài chân L_i theo lý thuyết và Monte Carlo.

---

### Nhóm 8 — Hỗ trợ & Tải dữ liệu

#### `load_simscape_params.m`
| | Chi tiết |
|---|---|
| **Input** | Không |
| **Output** | `m_p`, `I_p`, `m_arm`, `I_arm` — tham số vật lý từ mô hình Simscape |
| **Gọi bởi** | `tinh_torque` (tự động) |

#### `traj_to_motor_angle.m`
| | Chi tiết |
|---|---|
| **Input** | File CSV quỹ đạo, `A_mat`, `B_mat`, `L1`, `L2`, `gamma_ang` |
| **Output** | Ma trận `[N×6]` góc động cơ theo thời gian (°) |

---

### Nhóm 9 — Python Viewer

#### `sim.py`
> Trình xem 3D độc lập, không cần MATLAB, chạy bằng Python 3.11.

| | Chi tiết |
|---|---|
| **Input** | File CSV M-Code (7 hoặc 15 tham số), `config.json` |
| **Output** | Cửa sổ 3D VisPy: platform, 6 chân, animation real-time |
| **Stack** | Python 3.11, PyQt5, VisPy, NumPy, Pandas |
| **Thread** | `AnimationThread` (QThread) — tách render khỏi UI |
| **Safety** | 3-layer check Python tương đương MATLAB |
| **Môi trường** | `venv311/` — cài sẵn tại workspace |

---

## 🕸️ Sơ đồ liên kết giữa các function

```
                        ┌──────────────────┐
                        │  Dashboard_Stewart5│ ◄── config.json
                        │  (Entry Point)    │ ◄── Platform_Command.csv
                        └───┬──────────────┘
                            │calls
              ┌─────────────▼─────────────────┐
              │        calc_Geometry           │
              │  ra,rb,α,β,d_a,d_b → A,B,γ   │
              └─────────────┬─────────────────┘
                            │ [A_mat, B_mat, gamma_ang]
           ┌────────────────┼────────────────────┐
           ▼                ▼                    ▼
  ┌─────────────┐  ┌─────────────────┐  ┌──────────────┐
  │  matranquay │  │donghocnguoc     │  │ check_pose   │
  │  (R=Rz·Ry·Rx)│  │_final1 (IK)    │  │ _safety      │
  └─────────────┘  └────────┬────────┘  └──────┬───────┘
       used by all          │                   │calls
                     phi_out│[1×6°]       ┌─────▼──────────────┐
                            │             │donghocnguoc_final1  │
                            │             │ + kiem_tra_ki_di    │
                            │             └────────────────────┘
                            ▼
              ┌─────────────────────────────┐
              │       jacobian_RUS          │
              │  pose,pose_dot → J[6×6]    │◄── donghocnguoc_raw
              └──────────┬──────────────────┘
                         │ J, theta_dot
            ┌────────────┼────────────────┐
            ▼            ▼                ▼
   ┌──────────────┐ ┌──────────────┐ ┌──────────────────┐
   │  tinh_vel    │ │jacobian_motor│ │ donghocthuan_NR  │
   │ →RPM[1×6]   │ │→J_q,q_dot   │ │ →pose_out(FK)    │
   └──────────────┘ └──────┬───────┘ └──────────────────┘
                           │
                     ┌─────▼──────────────┐
                     │    tinh_torque      │
                     │  → tau[6×1 N·m]   │◄── load_simscape_params
                     │  → F_joint[3×6]   │
                     │  → f_rod[6×1]     │
                     └────────────────────┘
```

### Sơ đồ kiểm định an toàn

```
pose [x,y,z,R,P,Y]
        │
        ▼
┌───────────────┐  NaN?  ┌──────────────────────────┐
│ donghocnguoc  │───YES──►│ REJECT: Ngoài tầm với    │
│ _final1 (IK)  │        └──────────────────────────┘
└───────┬───────┘
        │ phi_out [1×6]
        ▼
┌───────────────────┐  out?  ┌──────────────────────────┐
│ phi ∈ [−60,+100]° │──YES──►│ REJECT: Servo vượt giới  │
└─────────┬─────────┘        └──────────────────────────┘
          │
          ▼
┌────────────────────┐  YES  ┌──────────────────────────┐
│ det(J) < 1×10⁻³   │──────►│ REJECT: Điểm kỳ dị!      │
└──────────┬─────────┘       └──────────────────────────┘
           │
           ▼
     ✅ AN TOÀN — Tiến hành di chuyển
```

---

## 🗂️ Nhánh chuyên đề

| Nhánh | Nội dung | README |
|---|---|---|
| `main` | Tổng quan, catalogue đầy đủ (file này) | `README.md` |
| `feature/inverse-kinematics` | IK, FK, Jacobian, Workspace | `kinematics/README.md` + `kinematics/USAGE.md` |
| `feature/dynamics` | Moment, Newton-Euler, Simscape | `dynamics/README.md` + `dynamics/USAGE.md` |
| `feature/data` | CSV M-Code, IMU, Motor_Angles, hình ảnh | `data/README.md` + `data/USAGE.md` |
| `feature/cad` | File STEP thiết kế cơ khí | `cad/README.md` + `cad/USAGE.md` |

---

## 🚀 Cài đặt & Chạy nhanh

### MATLAB

```matlab
% 1. Khởi động Dashboard tổng hợp
Dashboard_Stewart5

% 2. Sinh quỹ đạo mới
Trajectory_Generator

% 3. FK nhanh từ góc động cơ
run_forward_kinematics
```

### Python Viewer

```powershell
# Kích hoạt venv
.\venv311\Scripts\Activate.ps1

# Chạy viewer
python sim.py
```

### Yêu cầu

| Phần mềm | Phiên bản |
|---|---|
| MATLAB | R2023b trở lên |
| Simscape Multibody | Toolbox đi kèm MATLAB |
| Python | 3.11.x |
| PyQt5 | 5.15.x |
| VisPy | 0.16.x |
| NumPy | ≥ 1.24 |
| Pandas | ≥ 2.0 |
