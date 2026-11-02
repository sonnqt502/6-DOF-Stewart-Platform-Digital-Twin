import pandas as pd
import numpy as np
import matplotlib.pyplot as plt

def parse_moog_file(file_path):
    data = []
    with open(file_path, 'r', encoding='utf-8') as f:
        for line in f:
            if '~M[' in line:
                line = line.replace('~M[', '').replace('[', '').replace(']', '').replace('~', '')
                parts = line.strip().split()
                try:
                    vals = [float(p) for p in parts]
                    if len(vals) >= 16:
                        data.append(vals[:16])
                except:
                    pass
    return np.array(data)

# Read Pivot
pivot_data = parse_moog_file('Pivot_Command_pitch0.25.csv')
t_pivot = pivot_data[:, 0]
euler_pivot = pivot_data[:, 4:7] # Yaw, Pitch, Roll
w_pivot = pivot_data[:, 13:16] # Wx, Wy, Wz

print("Max Euler Yaw:", np.max(np.abs(euler_pivot[:, 0])))
print("Max Euler Pitch:", np.max(np.abs(euler_pivot[:, 1])))
print("Max Euler Roll:", np.max(np.abs(euler_pivot[:, 2])))

print("Max Wx:", np.max(np.abs(w_pivot[:, 0])))
print("Max Wy:", np.max(np.abs(w_pivot[:, 1])))
print("Max Wz:", np.max(np.abs(w_pivot[:, 2])))

w_pivot_xyz = np.column_stack([w_pivot[:, 2], w_pivot[:, 1], w_pivot[:, 0]]) # Wz, Wy, Wx
euler_pivot_xyz = np.column_stack([euler_pivot[:, 2], euler_pivot[:, 1], euler_pivot[:, 0]]) # Roll, Pitch, Yaw

# We don't have the IMU pitch data file easily known. Let me check what CSVs we have.
