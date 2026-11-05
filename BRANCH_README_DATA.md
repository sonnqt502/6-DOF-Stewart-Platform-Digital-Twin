# 📊 Nhánh: `feature/data`

> **Chủ đề:** Dữ liệu quỹ đạo thực nghiệm, góc động cơ đo được, dữ liệu IMU và kết quả xử lý của Stewart Platform CKAS W2.

---

## Nội dung nhánh

Nhánh này chứa toàn bộ **dữ liệu thô và đã xử lý** từ các thực nghiệm, bao gồm quỹ đạo đặt cho platform, góc động cơ ghi lại, dữ liệu cảm biến IMU, và các script kiểm tra/phân tích dữ liệu.

---

## Cấu trúc dữ liệu

### File M-Code (định dạng CSV từ bộ điều khiển CKAS)

#### Định dạng 7 tham số — `Platform_Command*.csv`
```
t, x, y, z, roll, pitch, yaw
```
| Cột | Đơn vị | Mô tả |
|---|---|---|
| `t` | s | Thời gian |
| `x, y, z` | mm | Vị trí tịnh tiến (surge, sway, heave) |
| `roll, pitch, yaw` | ° | Góc Euler ZYX |

#### Định dạng 15 tham số — `Motion_Command_15Params.csv`
```
t, x, y, z, roll, pitch, yaw, dx, dy, dz, droll, dpitch, dyaw, ddx, ddy
```
Thêm vận tốc tuyến tính (mm/s), vận tốc góc (°/s), và gia tốc tuyến tính (mm/s²).

---

## Danh sách file dữ liệu

### Quỹ đạo platform

| File | Mô tả |
|---|---|
| `Platform_Command.csv` | Quỹ đạo chính bàn máy |
| `Platform_Command_huy.csv` | Quỹ đạo kiểm định (phiên Huy) |

### Quỹ đạo đầu người (Head Tracking)

| File | Mô tả |
|---|---|
| `Head_Command*.csv` | Chuỗi lệnh chuyển động đầu từ IMU |

### Quỹ đạo tâm quay (Pivot)

| File | Mô tả |
|---|---|
| `Pivot_Command*.csv` | Lệnh chuyển động tâm quay ảo |

### M-Code 15 tham số

| File | Mô tả |
|---|---|
| `Motion_Command_15Params.csv` | Quỹ đạo đầy đủ (vị trí + vận tốc + gia tốc) |

### Dữ liệu đo thực tế

| File | Mô tả |
|---|---|
| `Motor_Angles.csv` | Góc 6 servo ghi lại từ bộ điều khiển (°) |
| `IMU1_00.csv` | Dữ liệu IMU thực tế (ax, ay, az, gx, gy, gz) |

### Cấu hình & kết quả

| File | Mô tả |
|---|---|
| `RobotConfig.mat` | Thông số hình học đã tối ưu |
| `simulink_data.mat` | Kết quả mô phỏng Simscape |
| `config.json` | Cấu hình servo và hình học (JSON) |
| `Histogram_L_FK_Sweep.png` | Biểu đồ phân bố chiều dài chân (sweep analysis) |
| `test.csv` | Dữ liệu test nhỏ |

---

## Hình ảnh kết quả (`hinhanh_VT/`)

| File | Nội dung |
|---|---|
| `fig2_pivot_concept.png/pdf` | Khái niệm tâm quay ảo |
| `fig3_head_trajectory.png/pdf` | Quỹ đạo đầu người |
| `fig3_fft_lpf.png` | Phân tích FFT và lọc LPF |
| `fig4_pca_crosstalk.png` | Phân tích PCA crosstalk |
| `fig4_pivot_id.png/pdf` | Nhận dạng tâm quay |
| `fig5_accel_comparison.png` | So sánh gia tốc đo vs mô phỏng |
| `fig5_motor_angles.png/pdf` | Góc động cơ theo thời gian |
| `fig6_roll_vs_pitch.png/pdf` | Roll vs Pitch thực tế |
| `fig7_exp_setup.png/pdf` | Ảnh thực nghiệm |
| `fig8_sensor_quality.png/pdf` | Chất lượng tín hiệu cảm biến |
| `So_do_tien_xu_ly.png` | Sơ đồ tiền xử lý dữ liệu |
| `So_do_tong_quan.png` | Sơ đồ tổng quan hệ thống |

---

## Script phân tích

| File | Chức năng |
|---|---|
| `verify_csv_full.m` | Kiểm tra tính hợp lệ toàn bộ CSV (parse + sanity check) |
| `plot_workspace_limits.m` | Vẽ giới hạn không gian làm việc từ dữ liệu |

---

## Cách đọc dữ liệu

```matlab
% Đọc quỹ đạo 7 tham số
data = readtable('Platform_Command.csv');
t     = data{:,1};        % Thời gian (s)
xyz   = data{:,2:4};      % Vị trí (mm)
euler = data{:,5:7};      % Góc Euler (°)

% Đọc dữ liệu góc động cơ thực tế
angles = readmatrix('Motor_Angles.csv');  % [N×6] (°)

% Đọc config
cfg = jsondecode(fileread('config.json'));
L1 = cfg.L1_mm;
L2 = cfg.L2_mm;
```

```python
# Đọc từ Python (sim.py)
import pandas as pd
df = pd.read_csv('Platform_Command.csv', header=None)
# Tự động phân biệt 7 hay 15 cột
```

---

## Liên kết

- Nhánh `feature/inverse-kinematics` — Dùng dữ liệu này làm đầu vào IK/FK
- Nhánh `feature/dynamics` — Dùng dữ liệu này để tính moment
- `main` — Dashboard hiển thị dữ liệu
