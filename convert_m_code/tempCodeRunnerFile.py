import pandas as pd
import numpy as np
from math import sin
def format_for_matlab_code(input_csv, output_csv):
    df = pd.read_csv(input_csv)
    df_out = pd.DataFrame()
    
    # Gán theo đúng thứ tự code MATLAB cũ: t, X, Y, Z, Yaw, Pitch, Roll
    df_out['Time']  = df['t (s)']
    df_out['X']     = -df['x (m)'] * 1000.0
    df_out['Y']     = df['x (m)'] * 1000.0  # mm
    df_out['Z']     = -772-10*np.sin(0.01*df['t (s)']/3.1415926)  # mm, hằng số Z
    
    # Chú ý thứ tự 3 góc này:
    df_out['Yaw']   = 0.0                   # Cột 5 của num_data
    df_out['Pitch'] = -df['phi (deg)']                   # Cột 6 của num_data
    df_out['Roll']  = df['phi (deg)']       # Cột 7 của num_data
    
    # Không xuất header (tiêu đề) để readmatrix trong Matlab đọc dễ dàng hơn
    df_out.to_csv(output_csv, index=False, header=False, float_format='%.4f')
    print(f"✅ Đã tạo file: {output_csv}")

if __name__ == "__main__":
    format_for_matlab_code('washout_20260421_133749.csv', 'trajectory_matlab.csv')