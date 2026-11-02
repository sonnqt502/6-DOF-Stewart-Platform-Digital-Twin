import numpy as np

# Create dummy IMU and Pivot data for Pitch
t_imu = np.linspace(0, 10, 1000)
w_aligned = np.zeros((1000, 3))
w_aligned[:, 1] = np.sin(2 * np.pi * 0.25 * t_imu) # Pitch motion on Y
a_aligned = np.zeros((1000, 3))
a_aligned[:, 0] = -9.81 * np.sin(np.sin(2 * np.pi * 0.25 * t_imu)) # X acc
a_aligned[:, 2] = 9.81 * np.cos(np.sin(2 * np.pi * 0.25 * t_imu)) # Z acc
euler_aligned = np.zeros((1000, 3))
euler_aligned[:, 1] = np.degrees(np.sin(2 * np.pi * 0.25 * t_imu)) # Pitch

t_pivot = np.linspace(0, 10, 1000)
pivot_data = np.zeros((1000, 16))
pivot_data[:, 0] = t_pivot
pivot_data[:, 4:7] = euler_aligned # Roll, Pitch, Yaw... wait, if euler is [Yaw, Pitch, Roll]
# If pivot euler is [Yaw, Pitch, Roll]:
pivot_data[:, 5] = np.degrees(np.sin(2 * np.pi * 0.25 * t_pivot)) # Pitch
pivot_data[:, 14] = np.sin(2 * np.pi * 0.25 * t_pivot) # Wy

# Tab 3 logic:
w_pivot = pivot_data[:, 13:16] # [Wx, Wy, Wz]
w_pivot_xyz = np.column_stack([w_pivot[:, 2], w_pivot[:, 1], w_pivot[:, 0]]) # [Wz, Wy, Wx]

euler_pivot = pivot_data[:, 4:7] # [Yaw, Pitch, Roll]
euler_pivot_xyz = np.column_stack([euler_pivot[:, 2], euler_pivot[:, 1], euler_pivot[:, 0]]) # [Roll, Pitch, Yaw]

euler_aligned_xyz = np.column_stack([euler_aligned[:, 2], euler_aligned[:, 1], euler_aligned[:, 0]]) # [Roll, Pitch, Yaw]

axis_idx = 1 # Pitch

# test sync
w_aligned_test = w_aligned.copy()
# correlate w_aligned_test[:, 1] and w_pivot_xyz[:, 1]
print("IMU Wy:", w_aligned_test[200, 1])
print("Piv Wy:", w_pivot_xyz[200, 1])
print("IMU Pitch:", euler_aligned_xyz[200, 1])
print("Piv Pitch:", euler_pivot_xyz[200, 1])

