# Hướng dẫn kỹ thuật — Đọc, Xử lý và Phân tích Dữ liệu Quỹ đạo

> **Tham chiếu chuẩn:** Bảng 4-2 (Trang 61–62) & Chương 5 (Trang 67–84), Đồ án tốt nghiệp *ĐATN_NQTS.pdf*.

---

## 1. Cách đọc file M-Code 15 tham số trong MATLAB

File `Motion_Command_15Params.csv` và các file `Head_Command*.csv` sử dụng cú pháp lệnh công nghiệp `~M[...]`:

```matlab
% Mở file và phân giải cấu trúc chuỗi ~M
filename = 'Motion_Command_15Params.csv';
fid = fopen(filename, 'r');
if fid == -1
    error('Không thể mở file: %s', filename);
end

% Định dạng chuỗi khớp chính xác với cú pháp Bảng 4-2 trong ĐATN
formatSpec = '%f ~M[ %f %f %f %f %f %f [ %f %f %f %f %f %f %f %f %f ]]';
data = textscan(fid, formatSpec);
fclose(fid);

% Trích xuất dữ liệu
t_s       = data{1};                  % Thời gian (giây)
pos_mm    = [data{2}, data{3}, data{4}]; % [x, y, z] (mm)
euler_deg = [data{7}, data{6}, data{5}]; % [roll, pitch, yaw] (độ)
acc_inert = [data{8}, data{9}, data{10}];% [axi, ayi, azi] (m/s²)
acc_grav  = [data{11}, data{12}, data{13}]; % [axg, ayg, azg] (m/s²)
omega_rad = [data{16}, data{15}, data{14}]; % [wx, wy, wz] (rad/s)

fprintf('Đã nạp thành công %d bước thời gian từ file %s\n', length(t_s), filename);
```

---

## 2. Cách đọc file M-Code trong Python

```python
import re
import numpy as np
import pandas as pd

def parse_m_code_file(filepath):
    """
    Phân giải định dạng lệnh ~M[ ... ] theo chuẩn Bảng 4-2 của ĐATN CKAS W2.
    """
    records = []
    # Pattern tách các số thực trong chuỗi
    pattern = re.compile(r"[-+]?\d*\.\d+|\d+")
    
    with open(filepath, 'r', encoding='utf-8') as f:
        for line in f:
            tokens = pattern.findall(line)
            if len(tokens) >= 16:
                # 1 timestamp + 6 pose + 6 acc + 3 omega
                records.append([float(x) for x in tokens[:16]])
                
    columns = [
        't', 'x', 'y', 'z', 'yaw', 'pitch', 'roll',
        'axi', 'ayi', 'azi', 'axg', 'ayg', 'azg',
        'wz', 'wy', 'wx'
    ]
    return pd.DataFrame(records, columns=columns)

# Sử dụng:
df = parse_m_code_file('Motion_Command_15Params.csv')
print(f"Số dòng nạp được: {len(df)}")
print(df.head())
```

---

## 3. Cách đọc file góc động cơ thực tế (`Motor_Angles.csv`)

```matlab
% Đọc trực tiếp qua bảng table
T = readtable('Motor_Angles.csv');

time_vector = T.t;                    % Thời gian (s)
pos_xyz     = [T.x, T.y, T.z];        % Vị trí bệ động (mm)
rot_angles  = [T.roll, T.pitch, T.yaw]; % Góc Euler (độ)
phi_actual  = [T.phi1, T.phi2, T.phi3, T.phi4, T.phi5, T.phi6]; % Góc servo (độ)

% Vẽ đồ thị 6 góc động cơ
figure('Color', 'w', 'Name', 'Motor Angles Tracking');
plot(time_vector, phi_actual, 'LineWidth', 1.5);
grid on;
xlabel('Thời gian (s)');
ylabel('Góc quay servo (độ)');
legend('\phi_1', '\phi_2', '\phi_3', '\phi_4', '\phi_5', '\phi_6');
title('Biến thiên góc quay 6 động cơ theo thời gian');
```

---

## 4. Kiểm tra tính toàn vẹn của dữ liệu

Chạy script sau trong MATLAB để tự động quét kiểm tra tất cả các file CSV trong thư mục:

```matlab
verify_csv_full
```

Script sẽ kiểm tra:
1. Số cột và định dạng cú pháp theo chuẩn ĐATN.
2. Kiểm tra không có giá trị NaN hoặc Inf.
3. Kiểm tra tính liên tục của thời gian (bước nhảy $\Delta t$ đều đặn).
4. Kiểm tra biên độ vị trí và góc có nằm trong giới hạn vật lý của CKAS W2 hay không.
