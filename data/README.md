# 📊 Chuyên đề Dữ liệu Quỹ đạo, Cảm biến IMU & Thực nghiệm

> **Nhánh:** `feature/data`  
> **Tài liệu đối chiếu:** Đồ án tốt nghiệp *ĐATN_NQTS.pdf* (Bảng 4-2: Định nghĩa cấu trúc file quỹ đạo được import & Chương 5: Thí nghiệm xác định vị trí điểm Pivot).

---

## 📌 Mục lục

- [1. Danh mục các tệp dữ liệu](#1-danh-mục-các-tệp-dữ-liệu)
- [2. Cấu trúc chuẩn lệnh chuyển động ~M (Bảng 4-2)](#2-cấu-trúc-chuẩn-lệnh-chuyển-động-m-bảng-4-2)
- [3. Dữ liệu góc động cơ (Motor_Angles.csv)](#3-dữ-liệu-góc-động-cơ-motor_anglescsv)
- [4. Dữ liệu thực nghiệm cảm biến IMU & Phân tích Pivot (Chương 5)](#4-dữ-liệu-thực-nghiệm-cảm-biến-imu--phân-tích-pivot-chương-5)
  - [4.1. Nhiễu đo và bộ lọc thông thấp (LPF)](#41-nhiễu-đo-và-bộ-lọc-thông-thấp-lpf)
  - [4.2. Hiệu chỉnh góc lệch gá đặt bằng PCA (Crosstalk Cancellation)](#42-hiệu-chỉnh-góc-lệch-gá-đặt-bằng-pca-crosstalk-cancellation)
  - [4.3. Các biểu đồ trong thư mục hinhanh_VT/](#43-các-biểu-đồ-trong-thư-mục-hinhanh_vt)
- [5. Hướng dẫn nạp và xử lý dữ liệu trong MATLAB và Python](#5-hướng-dẫn-nạp-và-xử-lý-dữ-liệu-trong-matlab-và-python)

---

## 1. Danh mục các tệp dữ liệu

| Tên file | Định dạng | Mô tả theo ĐATN |
|---|---|---|
| `Head_Command.csv` | M-Code 15 tham số | Quỹ đạo chuyển động đầu người lái dùng để nạp vào giao diện Dashboard |
| `Head_Command-200.csv`, `-400.csv`, `-600.csv`, `0.csv` | M-Code 15 tham số | Quỹ đạo đầu người tương ứng các cao độ tâm quay ảo khác nhau ($Z_p$) |
| `Head_Command_Pitch_-50-50-762.csv` | M-Code 15 tham số | Quỹ đạo thí nghiệm quay thuần Pitch phục vụ nhận dạng tâm quay Pivot |
| `Head_Command_Roll_-50-50-762.csv` | M-Code 15 tham số | Quỹ đạo thí nghiệm quay thuần Roll phục vụ nhận dạng tâm quay Pivot |
| `Motion_Command_15Params.csv` | M-Code 15 tham số | Chuỗi lệnh tổng quát chứa đầy đủ 15 tham số chuyển động |
| `Motor_Angles.csv` | CSV có tiêu đề | Bảng dữ liệu đồng bộ $[t, x, y, z, \text{yaw}, \text{pitch}, \text{roll}, \phi_1 \dots \phi_6]$ |
| `IMU1_00.csv` | CSV cảm biến | Tín hiệu đo thô từ cảm biến IMU gắn tại buồng lái |
| `config.json` | JSON | Cấu hình tham số hình học $r_a, r_b, L_1, L_2, \alpha_1, \beta_1, \delta_a, \delta_b$ và giới hạn góc động cơ |
| `hinhanh_VT/` | Thư mục ảnh | Toàn bộ hình ảnh đồ thị phân tích phổ FFT, lọc LPF, PCA crosstalk từ thực nghiệm |

---

## 2. Cấu trúc chuẩn lệnh chuyển động ~M (Bảng 4-2)

*(Trích xuất chính xác theo Bảng 4-2, Trang 61–62 của ĐATN_NQTS.pdf)*

Mỗi dòng dữ liệu trong các file `Head_Command*.csv` và `Motion_Command_15Params.csv` có cú pháp:

```text
<time> ~M[ <x> <y> <z> <yaw> <pitch> <roll> [ <axi> <ayi> <azi> <axg> <ayg> <azg> <wz> <wy> <wx> ]]
```

*Ví dụ một dòng dữ liệu thực tế:*
```text
0.0100 ~M[ 0.0000 2.0890 -836.9971 0.0000 0.0000 0.1571 [ 0.0000 -0.0052 0.0429 0.0000 0.0269 9.8100 0.0000 0.0000 0.2741 ]]
```

### Ý nghĩa vật lý 15 tham số:

| Ký hiệu | Kiểu | Đơn vị | Định nghĩa kỹ thuật trong đồ án |
|---|---|---|---|
| `<time>` | Float | giây (s) | Thời gian lấy mẫu (bước thời gian $\Delta t = 0.01\text{ s}$) |
| `<x>`, `<y>`, `<z>` | Float | mm | Tọa độ tịnh tiến thủ công (tiến, phải, xuống so với vị trí trung tâm) |
| `<yaw>`, `<pitch>`, `<roll>` | Float | độ ($^\circ$) | Góc xoay thủ công (Euler angles) theo thứ tự quanh trục Z, Y, X |
| `<axi>`, `<ayi>`, `<azi>` | Float | m/s² | Gia tốc quán tính trong hệ trục tọa độ của bệ (không bao gồm trọng lực) |
| `<axg>`, `<ayg>`, `<azg>` | Float | m/s² | Hình chiếu gia tốc trọng trường trên hệ bệ động (ví dụ trục $Z \approx 9.81\text{ m/s}^2$) |
| `<wz>`, `<wy>`, `<wx>` | Float | rad/s | Vận tốc góc theo các trục yaw, pitch và roll |

---

## 3. Dữ liệu góc động cơ (Motor_Angles.csv)

File lưu trữ trạng thái bám quỹ đạo của 6 động cơ servo, gồm 13 cột:
- `t`: Thời gian (s).
- `x, y, z`: Tọa độ vị trí bệ động (mm).
- `yaw, pitch, roll`: Góc hướng của bệ động (độ).
- `phi1, phi2, phi3, phi4, phi5, phi6`: Góc quay thực tế của 6 servo ($\phi_{thuc}$) theo đơn vị độ.

---

## 4. Dữ liệu thực nghiệm cảm biến IMU & Phân tích Pivot (Chương 5)

### 4.1. Nhiễu đo và bộ lọc thông thấp (LPF)

- Tín hiệu vận tốc góc $\omega$ và gia tốc tịnh tiến thu từ IMU chứa nhiễu dao động cơ khí. Khi lấy đạo hàm vi phân để tìm gia tốc góc $\alpha = \dot{\omega}$, nhiễu bị khuếch đại mạnh (tỷ số $SNR(\alpha_x) = -2.6\text{ dB}$, $SNR(\alpha_y) = -9.6\text{ dB}$).
- Phân tích phổ FFT giúp xác định dải tần rung động cơ khí cao tần để áp dụng bộ lọc thông thấp (LPF) với tần số cắt phù hợp, khôi phục dạng sóng thực tế.

### 4.2. Hiệu chỉnh góc lệch gá đặt bằng PCA (Crosstalk Cancellation)

- Do sai số cơ khí khi gá đặt IMU, hệ trục tọa độ của IMU $\{I\}$ bị nghiêng so với hệ trục chuẩn của bệ động $\{M\}$. Khi quay đơn trục (ví dụ thuần Roll), thành phần gia tốc bị rò rỉ (crosstalk) sang trục Pitch.
- Giải pháp trong ĐATN: Thuật toán Phân tích thành phần chính (PCA) tìm các vector riêng của ma trận hiệp phương sai tín hiệu, từ đó xác định ma trận xoay hiệu chỉnh để đưa hệ trục đo về trùng phương hoàn toàn với trục quay của bàn máy.

### 4.3. Các biểu đồ trong thư mục hinhanh_VT/

- `fig2_pivot_concept.png`: Sơ đồ nguyên lý tâm quay ảo đặt tại đầu phi công.
- `fig3_head_trajectory.png`: Quỹ đạo chuyển động đầu người lái.
- `fig3_fft_lpf.png`: Phổ tần số FFT và đáp ứng bộ lọc LPF.
- `fig4_pca_crosstalk.png`: Phân tích PCA khử nhiễu xuyên kênh trục đo.
- `fig4_pivot_id.png`: Quá trình hội tụ nhận dạng tọa độ tâm quay.
- `fig5_accel_comparison.png`: Đối chiếu gia tốc đo IMU thực tế so với gia tốc mô phỏng.
- `fig5_motor_angles.png`: Góc quay 6 động cơ servo theo thời gian.
- `fig6_roll_vs_pitch.png`: Biểu đồ tương quan góc Roll và Pitch trong thí nghiệm.
- `fig8_sensor_quality.png`: Đánh giá chất lượng tín hiệu và tỷ số SNR.
- `So_do_tien_xu_ly.png` & `So_do_tong_quan.png`: Sơ đồ khối xử lý tín hiệu hoàn chỉnh.

---

## 5. Hướng dẫn nạp và xử lý dữ liệu trong MATLAB và Python

### Nạp trong MATLAB:

```matlab
% Đọc file Motor_Angles.csv
T = readtable('Motor_Angles.csv');
time_s = T.t;
pos_mm = [T.x, T.y, T.z];
euler_deg = [T.roll, T.pitch, T.yaw];
phi_motors = [T.phi1, T.phi2, T.phi3, T.phi4, T.phi5, T.phi6];
```

### Nạp file M-Code 15 tham số trong MATLAB (phù hợp Dashboard_Stewart5):

```matlab
fid = fopen('Motion_Command_15Params.csv', 'r');
lines = textscan(fid, '%f ~M[ %f %f %f %f %f %f [ %f %f %f %f %f %f %f %f %f ]]');
fclose(fid);

t     = lines{1};
x     = lines{2}; y  = lines{3}; z  = lines{4};
yaw   = lines{5}; pitch = lines{6}; roll = lines{7};
axi   = lines{8}; ayi = lines{9}; azi = lines{10};
axg   = lines{11}; ayg = lines{12}; azg = lines{13};
wz    = lines{14}; wy = lines{15}; wx = lines{16};
```
