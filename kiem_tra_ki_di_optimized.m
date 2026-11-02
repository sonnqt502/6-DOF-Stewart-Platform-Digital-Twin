import pandas as pd
import numpy as np

df = pd.read_csv('log_000_raw_z0.csv')

t0     = df['time_us'].iloc[0]
time_s = (df['time_us'].values - t0) / 1e6

# Góc Euler — GIỮ NGUYÊN ĐỘ (Dashboard xuất độ)
yaw_deg   = df['yaw(deg)'].values
pitch_deg = df['pitch(deg)'].values
roll_deg  = df['roll(deg)'].values

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

# gia tốc đo được (body frame, đơn vị g → m/s²)
acc_raw = np.column_stack([
    df['acc_x(g)'].values * G,
    df['acc_y(g)'].values * G,
    df['acc_z(g)'].values * G
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
    # Dashboard dùng: g_body = R' * [0; 0; g]  (Z world hướng xuống → g dương)
    g_body = R.T @ np.array([0.0, 0.0, G])
    axg_arr[k] = g_body[0]
    ayg_arr[k] = g_body[1]
    azg_arr[k] = g_body[2]

    # ax_i = gia tốc quán tính = gia tốc đo (body) − hình chiếu g
    ax_i_arr[k] = acc_raw[k, 0] - g_body[0]
    ay_i_arr[k] = acc_raw[k, 1] - g_body[1]
    az_i_arr[k] = acc_raw[k, 2] - g_body[2]

# Vận tốc góc body frame qua Jacobian ZYX (giống Dashboard)
# Dashboard tính từ đạo hàm góc Euler, nhưng IMU đã có sẵn gyr
# → dùng trực tiếp gyr, đã ở body frame
wx_b = np.radians(df['gyr_x(deg/s)'].values)
wy_b = np.radians(df['gyr_y(deg/s)'].values)
wz_b = np.radians(df['gyr_z(deg/s)'].values)

# Xuất file
with open('IMU_Formatted_Like_Dashboard.csv', 'w') as f:
    for i in range(N):
        line = (
            f"{time_s[i]:.4f} ~M[ "
            f"0.0000 0.0000 0.0000 "                          # X Y Z (mm) — chưa biết
            f"{yaw_deg[i]:.4f} {pitch_deg[i]:.4f} {roll_deg[i]:.4f} [ "  # Yaw Pitch Roll (°)
            f"{ax_i_arr[i]:.4f} {ay_i_arr[i]:.4f} {az_i_arr[i]:.4f} "   # ax_i ay_i az_i
            f"{axg_arr[i]:.4f} {ayg_arr[i]:.4f} {azg_arr[i]:.4f} "       # axg ayg azg
            f"{wz_b[i]:.4f} {wy_b[i]:.4f} {wx_b[i]:.4f} ]]\n"           # wz wy wx
        )
        f.write(line)

print("Hoàn tất!")