# 🤖 6-DOF Stewart Platform Digital Twin — CKAS W2

> **Đồ án tốt nghiệp** | Thiết kế và mô phỏng số bàn nâng hạ 6 bậc tự do Stewart Platform kiểu RUS ứng dụng trong buồng lái mô phỏng CKAS W2.

![Platform](docs/platform_diagram.png)

---

## 📋 Mục lục

- [Giới thiệu](#-giới-thiệu)
- [Cấu hình cơ khí](#-cấu-hình-cơ-khí)
- [Kiến trúc phần mềm](#-kiến-trúc-phần-mềm)
- [Các module chính](#-các-module-chính)
- [Cài đặt và Chạy thử](#-cài-đặt-và-chạy-thử)
- [Cấu trúc thư mục](#-cấu-trúc-thư-mục)
- [Định dạng dữ liệu](#-định-dạng-dữ-liệu)
- [Thuật toán cốt lõi](#-thuật-toán-cốt-lõi)

---

## 🎯 Giới thiệu

Dự án xây dựng **Digital Twin** (bản sao số) hoàn chỉnh cho hệ thống buồng lái mô phỏng chuyển động **CKAS W2** sử dụng cơ cấu **Stewart Platform 6 bậc tự do** kiểu **RUS** (Revolute–Universal–Spherical). Hệ thống bao gồm:

- Giải **động học ngược** (IK) theo phương pháp hình học khép kín
- Giải **động học thuận** (FK) bằng phương pháp **Newton-Raphson**
- Tính **Jacobian vận tốc** cho cơ cấu RUS
- Tính **moment động cơ** (Torque) theo động lực học ngược
- **Dashboard 3D tương tác** (MATLAB App Designer + Python/VisPy)
- Kiểm định an toàn quỹ đạo theo 3 lớp bảo vệ
- Sinh và xuất file quỹ đạo định dạng Moog M-Code (7 hoặc 15 tham số)

---

## ⚙️ Cấu hình cơ khí

| Thông số | Ký hiệu | Giá trị |
|---|---|---|
| Bán kính vòng tròn Đế | ra | 589.66 mm |
| Bán kính vòng tròn Bàn máy | rb | 429.566 mm |
| Chiều dài Tay quay (Servo Arm) | L1 | 150 mm |
| Chiều dài Thanh truyền (Rod) | L2 | 747 mm |
| Góc phân bố cặp chân Đế | alpha1 / delta_a | 19.45° / 38.9° |
| Góc phân bố cặp chân Bàn | beta1 / delta_b | 53.32° / 13.37° |
| Chiều cao mặt phẳng Đế | Z_A | 668.4 mm |
| Giới hạn góc Servo | — | −50° đến 120° |

**Cơ cấu chân RUS**: Mỗi chân bao gồm 1 khớp quay (Revolute - động cơ servo), 1 khớp chữ U (Universal) và 1 khớp cầu (Spherical), cho phép đạt được 6 bậc tự do không gian (3 tịnh tiến X/Y/Z + 3 xoay Roll/Pitch/Yaw).

---

## 🏗️ Kiến trúc phần mềm

```
┌─────────────────────────────────────────────────────────┐
│                   Dashboard_Stewart5.m                  │
│          (MATLAB App Designer - Giao diện chính)        │
├──────────────┬──────────────────┬───────────────────────┤
│  Động học    │   Động lực học   │  Sinh quỹ đạo         │
│              │                  │                       │
│ IK (Ngược)   │  tinh_torque.m   │  Trajectory_Generator │
│ FK (Thuận)   │  jacobian_RUS.m  │  M-Code Export        │
│ calc_Geometry│  tinh_vel.m      │  CSV Import (Moog)    │
└──────────────┴──────────────────┴───────────────────────┘
                      │
         ┌────────────┴────────────┐
         │     sim.py              │
         │  (PyQt5 + VisPy 3D)     │
         │  Player M-Code file     │
         └─────────────────────────┘

         ┌─────────────────────────┐
         │  Final_CKAS..._SIM.slx  │
         │  (Simulink/Simscape     │
         │   Mo hinh cung da the)  │
         └─────────────────────────┘
```

---

## 📦 Các module chính

### MATLAB

| File | Chức năng |
|---|---|
| [Dashboard_Stewart5.m](Dashboard_Stewart5.m) | Giao diện điều khiển chính: mô phỏng 3D real-time, sinh/nhập quỹ đạo, kiểm định an toàn, xuất file |
| [calc_Geometry.m](calc_Geometry.m) | Tính tọa độ 6 điểm neo trên Đế (A_i) và Bàn máy (B_i), góc định hướng gamma_i từ thông số cơ khí |
| [donghocnguoc_final1.m](donghocnguoc_final1.m) | **Động học ngược (IK)**: Tính 6 góc servo phi_i từ tư thế bàn máy [x,y,z,R,P,Y] |
| [donghocnguoc_raw.m](donghocnguoc_raw.m) | Tách góc vật lý phi_raw (trước offset) dùng cho Jacobian |
| [donghocthuan_NR.m](donghocthuan_NR.m) | **Động học thuận (FK)**: Giải ngược từ 6 góc servo → tư thế bàn máy bằng Newton-Raphson |
| [jacobian_RUS.m](jacobian_RUS.m) | Xây dựng ma trận **Jacobian vận tốc** 6×6 của cơ cấu RUS |
| [tinh_torque.m](tinh_torque.m) | Tính **moment động cơ** tau_i, lực khớp cầu F_Bi, lực trên rod theo động lực học ngược |
| [tinh_vel.m](tinh_vel.m) | Tính vận tốc dài và góc của từng khâu từ Jacobian |
| [Trajectory_Generator.m](Trajectory_Generator.m) | GUI sinh quỹ đạo (sin, đường tròn, cua chữ S 6 DOF) với Motion Cueing tùy chỉnh tâm quay |
| [check_pose_safety.m](check_pose_safety.m) | Kiểm định an toàn một tư thế đơn |
| [run_forward_kinematics.m](run_forward_kinematics.m) | Script nhanh: nhập 6 góc motor → xuất tư thế bàn máy |

### Python

| File | Chức năng |
|---|---|
| [sim.py](sim.py) | Player 3D độc lập (PyQt5 + VisPy): nạp file M-Code, kiểm định an toàn, mô phỏng real-time, terminal nhập lệnh thủ công |
| [dashboard_nosimulink.py](dashboard_nosimulink.py) | Dashboard Python thuần (không phụ thuộc MATLAB/Simulink) |

### Simulink / Simscape

| File | Chức năng |
|---|---|
| `Final_CKASForSIM30_11_SIM.slx` | Mô hình đa thể cứng Simscape Multibody hoàn chỉnh |
| `Final_CKASForSIM30_11_SIM_DataFile.m` | Thông số vật liệu, khối lượng, quán tính cho mô hình Simscape |

---

## 🚀 Cài đặt và Chạy thử

### Yêu cầu hệ thống

**MATLAB:**
- MATLAB R2022b trở lên
- Toolboxes: Simulink, Simscape, Simscape Multibody

**Python:**
- Python 3.11+
- Các thư viện: `PyQt5`, `numpy`, `vispy`

---

### Chạy Dashboard MATLAB

```matlab
% Mở MATLAB, điều hướng đến thư mục dự án, sau đó:
Dashboard_Stewart5
```

**Quy trình sử dụng:**
1. Kiểm tra thông số cơ khí ở Panel 1, bấm **CẬP NHẬT CẤU HÌNH**
2. Dùng thanh trượt bên phải để điều khiển thủ công và quan sát 3D real-time
3. Chọn loại quỹ đạo mẫu hoặc **Browse** để nhập file CSV
4. Bấm **KIỂM ĐỊNH & CHẠY MÔ PHỎNG** để quét an toàn toàn quỹ đạo rồi phát hoạt ảnh
5. Bấm **XUẤT FILE** để lưu ra định dạng M-Code 7 hoặc 15 tham số

---

### Chạy sim.py (Standalone Python Viewer)

```powershell
# Kích hoạt môi trường ảo
.\venv311\Scripts\Activate.ps1

# Chạy ứng dụng
python sim.py
```

Hoặc chạy trực tiếp không cần kích hoạt venv:

```powershell
.\venv311\Scripts\python.exe sim.py
```

---

### Giải Động học thuận nhanh (Script)

```matlab
% Sửa biến phi_input trong file rồi chạy:
run_forward_kinematics
```

---

## 📁 Cấu trúc thư mục

```
sime4/
│
├── README.md
├── config.json                         # Thông số cơ khí & giới hạn servo
│
├── MATLAB - Động học & Điều khiển
│   ├── calc_Geometry.m
│   ├── donghocnguoc_final1.m           # IK chính
│   ├── donghocnguoc_raw.m              # IK (phi_raw cho Jacobian)
│   ├── donghocthuan_NR.m               # FK - Newton-Raphson
│   ├── jacobian_RUS.m                  # Jacobian vận tốc
│   ├── tinh_torque.m                   # Tính moment động cơ
│   ├── tinh_vel.m                      # Tính vận tốc khâu
│   └── check_pose_safety.m             # Kiểm tra an toàn
│
├── MATLAB - Giao diện
│   ├── Dashboard_Stewart5.m            # Dashboard chính
│   ├── Trajectory_Generator.m          # Bộ sinh quỹ đạo
│   ├── kinematic_demo_gui.m
│   ├── gui_motor_angle.m
│   └── gui_torque_motion.m
│
├── Python
│   ├── sim.py                          # Player 3D (PyQt5 + VisPy)
│   └── dashboard_nosimulink.py
│
├── Simulink/Simscape
│   ├── Final_CKASForSIM30_11_SIM.slx
│   └── Final_CKASForSIM30_11_SIM_DataFile.m
│
├── Data (M-Code CSV)
│   ├── Platform_Command.csv
│   ├── Head_Command.csv
│   └── *.csv
│
├── Tests
│   ├── test_donghocthuan.m
│   ├── test_dynamic_motion.m
│   ├── verify_ik_match.m
│   └── verify_csv_full.m
│
└── docs/
    └── platform_diagram.png
```

---

## 📊 Định dạng dữ liệu

### File M-Code 7 tham số

```
[thoi_gian] ~M[ X Y Z Yaw Pitch Roll ]
0.0000 ~M[ 0.0000 0.0000 -75.0000 0.0000 0.0000 0.0000 ]
0.0200 ~M[ 0.0000 0.0000 -74.8123 0.0000 0.2341 0.0000 ]
```

### File M-Code 15 tham số

```
[t] ~M[ X Y Z Yaw Pitch Roll [ ax ay az axg ayg azg wz wy wx ]]
```

| Cột | Ký hiệu | Đơn vị | Mô tả |
|---|---|---|---|
| 1 | t | s | Thời gian |
| 2–4 | X, Y, Z | mm | Vị trí tịnh tiến |
| 5–7 | Yaw, Pitch, Roll | ° | Góc Euler ZYX |
| 8–10 | ax, ay, az | m/s² | Gia tốc body (quán tính) |
| 11–13 | axg, ayg, azg | m/s² | Hình chiếu trọng lực lên body |
| 14–16 | wz, wy, wx | rad/s | Vận tốc góc body |

---

## 🔐 Cơ chế kiểm định an toàn (3 lớp)

Mọi tư thế đầu vào đều phải vượt qua 3 điều kiện trước khi thực thi:

```
Lớp 1: Kiểm tra khả năng với tới
  |Q / sqrt(M^2 + N^2)| <= 1  →  đảm bảo các chân không bị "kịch"

Lớp 2: Kiểm tra giới hạn góc Servo
  -50° <= phi_thuc <= 120°    →  bảo vệ cơ khí

Lớp 3: Kiểm tra điểm kỳ dị (Singularity)
  |det(J)| > 1e-3              →  đảm bảo Jacobian không suy biến
```

---

## 📐 Thuật toán cốt lõi

### Động học ngược (IK)

Từ vector chân ảo `L_i = T + R*b_i - a_i`, giải phương trình:

```
Q_i = |L_i|^2 - L2^2 + L1^2
M_i = 2 * L1 * L_iz
N_i = 2 * L1 * (cos(gamma_i)*L_ix + sin(gamma_i)*L_iy)

phi_i = arcsin(Q_i / sqrt(M_i^2 + N_i^2)) - atan2(N_i, M_i)
```

### Động học thuận (FK) — Newton-Raphson

Lặp cập nhật tư thế `q` cho đến khi sai lệch góc servo `||delta_phi|| < epsilon`:

```
delta_q   = J_pinv * delta_phi
q_(k+1)  = q_k + delta_q
```

---

## 📄 Giấy phép

Dự án được phát triển phục vụ mục đích nghiên cứu học thuật trong khuôn khổ đồ án tốt nghiệp.

---

<p align="center">
  <sub>Phát triển bởi sinh viên Khoa Cơ điện tử · Đồ án tốt nghiệp · 2026</sub>
</p>
