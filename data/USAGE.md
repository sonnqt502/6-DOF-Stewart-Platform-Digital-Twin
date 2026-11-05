# Hướng dẫn sử dụng — Data

## 1. Đọc file quỹ đạo M-Code (MATLAB)

```matlab
%% 7-tham số
data = readtable('Platform_Command.csv', 'HeaderLines', 0);
t     = data{:,1};          % Thời gian (s)
xyz   = data{:,2:4};        % Vị trí [x, y, z] (mm)
euler = data{:,5:7};        % [roll, pitch, yaw] (°)

%% 15-tham số
data15 = readmatrix('Motion_Command_15Params.csv');
t      = data15(:,1);
pose   = data15(:,2:7);     % [x,y,z,roll,pitch,yaw]
vel    = data15(:,8:13);    % [vx,vy,vz,vroll,vpitch,vyaw]
acc    = data15(:,14:15);   % [ax,ay] (mm/s²)
```

## 2. Đọc file quỹ đạo (Python)

```python
import pandas as pd
import numpy as np

df = pd.read_csv('Platform_Command.csv', header=None)
ncols = df.shape[1]

if ncols == 7:
    t, x, y, z, roll, pitch, yaw = df.values.T
elif ncols == 15:
    t = df[0].values
    pose = df.iloc[:, 1:7].values      # [N×6]
    vel  = df.iloc[:, 7:13].values     # [N×6]
```

## 3. Đọc góc động cơ thực tế

```matlab
angles = readmatrix('Motor_Angles.csv');  % [N×6] (°)
% Mỗi hàng: [φ₁, φ₂, φ₃, φ₄, φ₅, φ₆] tại một thời điểm
```

## 4. Đọc config.json

```matlab
cfg = jsondecode(fileread('config.json'));
L1  = cfg.L1_mm;         % 150
L2  = cfg.L2_mm;         % 747
lim_min = cfg.motor_limit_min;   % -50
lim_max = cfg.motor_limit_max;   % 90
```

```python
import json
with open('config.json') as f:
    cfg = json.load(f)
L1 = cfg['L1_mm']
```

## 5. Kiểm tra tính hợp lệ dữ liệu

```matlab
verify_csv_full   % Chạy toàn bộ kiểm tra parse + sanity check
```

## 6. Cấu trúc config.json

```json
{
  "ra_mm": 589.66,
  "rb_mm": 429.566,
  "L1_mm": 150,
  "L2_mm": 747,
  "alpha1_deg": 19.45,
  "delta_a_deg": 38.9,
  "beta1_deg": 53.32,
  "delta_b_deg": 10.0,
  "motor_limit_min": -50,
  "motor_limit_max": 90
}
```

## Lưu ý

- Tất cả file CSV **không có header row** — đọc trực tiếp bằng `readmatrix` hoặc `pd.read_csv(..., header=None)`.
- Đơn vị vị trí: **mm**. Đơn vị góc: **độ (°)**.
- File CSV từ bộ điều khiển CKAS sử dụng dấu phân cách **dấu phẩy (,)**.
