# 📊 Dữ liệu — Data

> Nhánh `feature/data` — Quỹ đạo M-Code, IMU, Motor_Angles, kết quả thực nghiệm

---

## Cấu trúc dữ liệu

### Định dạng M-Code 7 tham số
```
t(s), x(mm), y(mm), z(mm), roll(°), pitch(°), yaw(°)
```

### Định dạng M-Code 15 tham số
```
t, x, y, z, roll, pitch, yaw,
dx(mm/s), dy, dz, droll(°/s), dpitch, dyaw,
ddx(mm/s²), ddy
```

---

## Danh sách file dữ liệu

| File | Format | Mô tả |
|---|---|---|
| `Platform_Command.csv` | 7-col | Quỹ đạo chính bàn máy |
| `Platform_Command_huy.csv` | 7-col | Quỹ đạo kiểm định |
| `Motion_Command_15Params.csv` | 15-col | Quỹ đạo đầy đủ (vị trí + vận tốc + gia tốc) |
| `Motor_Angles.csv` | N×6 | Góc 6 servo ghi thực tế (°) |
| `IMU1_00.csv` | IMU | Dữ liệu cảm biến IMU (ax,ay,az, gx,gy,gz) |
| `RobotConfig.mat` | MAT | Thông số hình học đã tối ưu |
| `simulink_data.mat` | MAT | Kết quả mô phỏng Simscape |
| `config.json` | JSON | Cấu hình servo và hình học |
| `hinhanh_VT/` | IMG | Hình ảnh kết quả thực nghiệm |
| `Histogram_L_FK_Sweep.png` | IMG | Phân bố chiều dài chân (sweep) |
| `verify_csv_full.m` | Script | Kiểm tra tính hợp lệ CSV |

---

## Giải thích hình ảnh kết quả

| File | Nội dung |
|---|---|
| `fig3_head_trajectory` | Quỹ đạo đầu người lái |
| `fig3_fft_lpf` | Phân tích FFT và bộ lọc LPF |
| `fig4_pivot_id` | Nhận dạng tâm quay ảo |
| `fig5_motor_angles` | Góc 6 động cơ theo thời gian |
| `fig6_roll_vs_pitch` | Tương quan Roll ↔ Pitch thực tế |
| `fig8_sensor_quality` | Đánh giá chất lượng tín hiệu IMU |

---

Xem **[USAGE.md](USAGE.md)** để đọc dữ liệu.
