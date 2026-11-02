import pandas as pd
import numpy as np

# 1. Đọc file với cấu trúc cột mới
df = pd.read_csv('roll_10_0.25_100._0csv.csv')

# 2. Xử lý thời gian (đã là s, chỉ cần dịch mốc về 0)
t0     = df['Time (s)'].iloc[0]
time_s = df['Time (s)'].values - t0

# 3. Góc Euler — GIỮ NGUYÊN ĐỘ (Dashboard xuất độ)
yaw_deg   = df['Yaw(deg)'].values
pitch_deg = df['Pitch(deg)'].values
roll_deg  = df['Roll(deg)'].values

# Chuyển sang rad để tính ma trận R
yaw_r   = np.radians(yaw_deg)
pitch_r = np.radians(pitch_deg)
roll_r  = np.radians(roll_deg)

G = 9.81

def Rzyx(y, p, r):
    cy, sy = np.cos(y), np.sin(y)
    cp, sp = np.cos(p), np.sin(p)
    cr, sr = np.cos(r), np.sin(r)
    return np.array([[cy*cp, cy*sp*sr - sy*cr, cy*sp*cr + sy*sr],
                     [sy*cp, sy*sp*sr + cy*cr, sy*sp*cr - cy*sr],
                     [-sp,   cp*sr,             cp*cr           ]])

N = len(time_s)

# 4. Lấy gia tốc đo được (body frame, đã là m/s²)
acc_raw = np.column_stack([
    df['Acc_X(g)'].values,
    df['Acc_Y(g)'].values,
    df['Acc_Z(g)'].values,
])

ax_i_arr = np.zeros(N)
ay_i_arr = np.zeros(N)
az_i_arr = np.zeros(N)
axg_arr  = np.zeros(N)
ayg_arr  = np.zeros(N)
azg_arr  = np.zeros(N)

for k in range(N):
    R = Rzyx(yaw_r[k], pitch_r[k], roll_r[k])

    # axg, ayg, azg = hình chiếu trọng lực lên body frame
    # Z world hướng xuống → Vector g thế giới là [0, 0, G]
    g_body = R.T @ np.array([0.0, 0.0, G])
    
    # SỬA LỖI NGHIÊM TRỌNG: Lập trình viên trước đó gán nhầm g_body[2] (trục Z) cho X
    axg_arr[k] = g_body[0]  # Phải là 0 cho X
    ayg_arr[k] = g_body[1]  # Phải là 1 cho Y
    azg_arr[k] = g_body[2]  # Phải là 2 cho Z

    # Khử trọng trường bằng phép TRỪ để lấy gia tốc tịnh tiến
    # (Vì Acc_Z lúc đứng yên đang đo được dương +9.8 m/s^2, trong khi g_body trên trục Z cũng là dương)
    ax_i_arr[k] = acc_raw[k, 0] - axg_arr[k]
    ay_i_arr[k] = acc_raw[k, 1] - ayg_arr[k]
    az_i_arr[k] = acc_raw[k, 2] - azg_arr[k]

# 5. Vận tốc góc body frame (Chuyển từ độ/s sang rad/s)
wx_b = np.radians(df['Gyro_X(deg/s)'].values)
wy_b = np.radians(df['Gyro_Y(deg/s)'].values)
wz_b = np.radians(df['Gyro_Z(deg/s)'].values)

# 6. Xuất file với cấu trúc chuỗi của Dashboard
with open('roll_10_0.25_100._0csv_dash.txt', 'w') as f:

    for i in range(N):

        line = (
            f"{time_s[i]:.4f} ~M[ "
            f"0.0000 0.0000 0.0000 "
            f"{yaw_deg[i]:.4f} {pitch_deg[i]:.4f} {roll_deg[i]:.4f} [ "
            f"{ax_i_arr[i]:.4f} {ay_i_arr[i]:.4f} {az_i_arr[i]:.4f} "
            f"{axg_arr[i]:.4f} {ayg_arr[i]:.4f} {azg_arr[i]:.4f} "
            f"{wz_b[i]:.4f} {wy_b[i]:.4f} {wx_b[i]:.4f}"
            "\n"
        )

        f.write(line)

print("Hoan tat!")