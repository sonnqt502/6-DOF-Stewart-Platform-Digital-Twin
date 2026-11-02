import numpy as np
import pandas as pd
import glob
import os

def Rzyx(y, p, r):
    cy, sy = np.cos(y), np.sin(y)
    cp, sp = np.cos(p), np.sin(p)
    cr, sr = np.cos(r), np.sin(r)
    return np.array([[cy*cp, cy*sp*sr - sy*cr, cy*sp*cr + sy*sr],
                     [sy*cp, sy*sp*sr + cy*cr, sy*sp*cr - cy*sr],
                     [-sp,   cp*sr,             cp*cr           ]])

def parse_moog_file(filepath):
    data = []
    with open(filepath, 'r') as f:
        for line in f:
            if '~M[' not in line: continue
            line = line.replace('~M[', '').replace('[', '')
            parts = line.split()
            if len(parts) >= 16:
                data.append([float(p) for p in parts[:16]])
    return np.array(data)

pivot_file = 'Pivot_Command.csv'
head_dir = 'data_after_convert/roll_2'

raw_p = parse_moog_file(pivot_file)

files = sorted(glob.glob(os.path.join(head_dir, '*.csv')))

print(f"{'centrez':<10} | {'ry (mm)':<10} | {'rz (mm)':<10} | {'pearson':<10} | {'rmse':<10}")
print("-" * 63)

alpha_cf = 0.98

for fpath in files:
    fname = os.path.basename(fpath)
    parts = fname.replace('.csv', '').split('_')
    if len(parts) >= 5:
        cz = float(parts[4])
    else:
        cz = np.nan
        
    raw_h = parse_moog_file(fpath)
    t_h = raw_h[:, 0]
    
    # 1. TÁI TẠO GIA TỐC VÀ GÓC EULER BẰNG COMPLEMENTARY FILTER
    # Raw data trong M-Code
    ax_h = raw_h[:, 7]; ay_h = raw_h[:, 8]; az_h = raw_h[:, 9]
    axg_h = raw_h[:, 10]; ayg_h = raw_h[:, 11]; azg_h = raw_h[:, 12]
    wz_h = raw_h[:, 13]; wy_h = raw_h[:, 14]; wx_h = raw_h[:, 15]
    
    # Đảo ngược ay, az theo logic của motion_calibration2.m
    # Chú ý: Ở đây ta khôi phục a_raw trước khi đảo ngược hay sau khi đảo ngược?
    # Tốt nhất là khôi phục a_raw theo toạ độ M-Code gốc, chạy CF, sinh ra a_linear mới, rồi mới đảo ngược ay, az.
    
    a_raw_x = ax_h + axg_h
    a_raw_y = ay_h + ayg_h
    a_raw_z = az_h + azg_h
    
    dt = np.mean(np.diff(t_h))
    
    pitch_acc = np.arctan2(-a_raw_x, np.sqrt(a_raw_y**2 + a_raw_z**2))
    roll_acc  = np.arctan2(a_raw_y, a_raw_z)
    
    pitch_rad = np.zeros(len(t_h))
    roll_rad = np.zeros(len(t_h))
    pitch_rad[0] = pitch_acc[0]
    roll_rad[0]  = roll_acc[0]
    
    for i in range(1, len(t_h)):
        pitch_rad[i] = alpha_cf * (pitch_rad[i-1] + wy_h[i]*dt) + (1-alpha_cf)*pitch_acc[i]
        roll_rad[i]  = alpha_cf * (roll_rad[i-1]  + wx_h[i]*dt) + (1-alpha_cf)*roll_acc[i]
        
    new_ax, new_ay, new_az = np.zeros(len(t_h)), np.zeros(len(t_h)), np.zeros(len(t_h))
    G = 9.81
    for i in range(len(t_h)):
        # Giả sử Yaw = 0 trong hệ toạ độ PCA
        R_e = Rzyx(0, pitch_rad[i], roll_rad[i])
        g_b = R_e.T @ np.array([0, 0, G])
        new_ax[i] = a_raw_x[i] - g_b[0]
        new_ay[i] = a_raw_y[i] - g_b[1]
        new_az[i] = a_raw_z[i] - g_b[2]
        
    # Ghi đè vào head_raw
    raw_h[:, 7] = new_ax
    raw_h[:, 8] = new_ay
    raw_h[:, 9] = new_az
    
    # 2. ĐẢO CHIỀU Y, Z NHƯ TRONG MATLAB VÀ ĐỒNG BỘ
    raw_h[:, 8] = -raw_h[:, 8]
    raw_h[:, 9] = -raw_h[:, 9]
    
    Axi_raw_h = raw_h[:, [7, 8, 9]]
    W_raw_h = raw_h[:, [15, 14, 13]] # wx, wy, wz
    
    # Tính alpha
    alpha_B = np.zeros_like(W_raw_h)
    alpha_B[:, 0] = np.gradient(W_raw_h[:, 0], t_h)
    alpha_B[:, 1] = np.gradient(W_raw_h[:, 1], t_h)
    alpha_B[:, 2] = np.gradient(W_raw_h[:, 2], t_h)
    
    Axi_raw_p = raw_p[:, [7, 8, 9]]
    W_raw_p = raw_p[:, [15, 14, 13]]
    t_p = raw_p[:, 0]
    
    t_start = max(t_h[0], t_p[0])
    t_end   = min(t_h[-1], t_p[-1])
    mask_p = (t_p >= t_start) & (t_p <= t_end)
    t_sync = t_p[mask_p]
    pivot_sync_Axi = Axi_raw_p[mask_p, :]
    
    head_sync_Axi = np.zeros((len(t_sync), 3))
    head_sync_W = np.zeros((len(t_sync), 3))
    alpha_sync = np.zeros((len(t_sync), 3))
    
    for c in range(3):
        head_sync_Axi[:, c] = np.interp(t_sync, t_h, Axi_raw_h[:, c])
        head_sync_W[:, c] = np.interp(t_sync, t_h, W_raw_h[:, c])
        alpha_sync[:, c] = np.interp(t_sync, t_h, alpha_B[:, c])
        
    # 3. MATH ENGINE (ROLL)
    N = len(t_sync)
    M_stack = np.zeros((2*N, 2))
    B_stack = np.zeros((2*N, 1))
    
    for k in range(N):
        a_h = head_sync_Axi[k, :]
        a_p = pivot_sync_Axi[k, :]
        da = a_h - a_p
        
        w = head_sync_W[k, :]
        al = alpha_sync[k, :]
        
        Om = np.array([
            [0, -w[2], w[1]],
            [w[2], 0, -w[0]],
            [-w[1], w[0], 0]
        ])
        Al = np.array([
            [0, -al[2], al[1]],
            [al[2], 0, -al[0]],
            [-al[1], al[0], 0]
        ])
        M_k = Al + Om @ Om
        
        M_reduced = M_k[np.ix_([1, 2], [1, 2])]
        B_reduced = np.array([da[1], da[2]])
        
        M_stack[2*k:2*k+2, :] = M_reduced
        B_stack[2*k:2*k+2, 0] = B_reduced
        
    if np.linalg.matrix_rank(M_stack) < 2:
        continue
        
    r_sol_m, _, _, _ = np.linalg.lstsq(M_stack, B_stack, rcond=None)
    ry = r_sol_m[0, 0] * 1000
    rz = r_sol_m[1, 0] * 1000
    
    # 4. EVALUATION
    r_m = np.array([0, ry/1000, rz/1000])
    a_calc_y = np.zeros(N)
    
    for k in range(N):
        a_p = pivot_sync_Axi[k, :]
        w = head_sync_W[k, :]
        al = alpha_sync[k, :]
        
        Om = np.array([
            [0, -w[2], w[1]],
            [w[2], 0, -w[0]],
            [-w[1], w[0], 0]
        ])
        Al = np.array([
            [0, -al[2], al[1]],
            [al[2], 0, -al[0]],
            [-al[1], al[0], 0]
        ])
        M_k = Al + Om @ Om
        
        a_c = a_p + M_k @ r_m
        a_calc_y[k] = a_c[1]
        
    a_imu_y = head_sync_Axi[:, 1]
    rmse_y = np.sqrt(np.mean((a_calc_y - a_imu_y)**2))
    pearson_y = np.corrcoef(a_calc_y, a_imu_y)[0, 1]
    
    print(f"{cz:<10.1f} | {ry:<10.4f} | {rz:<10.4f} | {pearson_y:<10.4f} | {rmse_y:<10.4f}")
