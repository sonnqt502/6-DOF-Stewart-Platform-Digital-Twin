import tkinter as tk
from tkinter import filedialog, messagebox, ttk
import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
import matplotlib
from matplotlib.backends.backend_tkagg import FigureCanvasTkAgg, NavigationToolbar2Tk
from matplotlib.widgets import SpanSelector
from scipy.signal import butter, filtfilt, correlate, welch
import sys
import argparse
import os

# ==============================================================================
# HẰNG SỐ CHUNG & LOGIC TOÁN HỌC
# ==============================================================================
TIME_UNITS = {
    "microseconds (µs)": 1e-6,
    "milliseconds (ms)": 1e-3,
    "seconds (s)":       1.0,
}
ACC_AXES = {'roll': 1, 'pitch': 0}
GYRO_AXES = {'roll': 0, 'pitch': 1}

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

def Rzyx(y, p, r):
    cy, sy = np.cos(y), np.sin(y)
    cp, sp = np.cos(p), np.sin(p)
    cr, sr = np.cos(r), np.sin(r)
    return np.array([[cy*cp, cy*sp*sr - sy*cr, cy*sp*cr + sy*sr],
                     [sy*cp, sy*sp*sr + cy*cr, sy*sp*cr - cy*sr],
                     [-sp,   cp*sr,             cp*cr           ]])

def extract_euler_zyx(R):
    sy = np.sqrt(R[0,0]**2 + R[1,0]**2)
    singular = sy < 1e-6
    if not singular:
        x = np.arctan2(R[2,1], R[2,2])
        y = np.arctan2(-R[2,0], sy)
        z = np.arctan2(R[1,0], R[0,0])
    else:
        x = np.arctan2(-R[1,2], R[1,1])
        y = np.arctan2(-R[2,0], sy)
        z = 0
    return np.degrees(z), np.degrees(y), np.degrees(x)

def pca_alignment(w_raw, a_raw, t_arr, t_start, t_end, motion="roll"):
    # Lấy vùng tĩnh
    static_mask = (t_arr >= t_start) & (t_arr <= t_end)
    if np.sum(static_mask) < 10:
        messagebox.showwarning("Cảnh báo", "Vùng tĩnh quá nhỏ (<10 mẫu). Dùng mặc định 10 mẫu đầu.")
        static_mask = np.arange(min(10, len(t_arr)))
        
    g_vec = np.mean(a_raw[static_mask], axis=0)
    g_vec = g_vec / np.linalg.norm(g_vec)
    
    # Tính C từ w_raw toàn tập để tìm trục quay chính
    X_centered = w_raw - np.mean(w_raw, axis=0)
    C = np.dot(X_centered.T, X_centered) / (X_centered.shape[0] - 1)
    eigenvalues, eigenvectors = np.linalg.eig(C)
    sort_idx = np.argsort(eigenvalues)[::-1]
    eigenvectors = eigenvectors[:, sort_idx]
    
    rot_axis = eigenvectors[:, 0]
    
    if "roll" in motion.lower():
        if rot_axis[0] < 0: rot_axis = -rot_axis
        X_p = rot_axis
        Y_p = np.cross(g_vec, X_p)
        if np.linalg.norm(Y_p) < 1e-6: Y_p = np.array([0.0, 1.0, 0.0])
        Y_p = Y_p / np.linalg.norm(Y_p)
        Z_p = np.cross(X_p, Y_p)
        Z_p = Z_p / np.linalg.norm(Z_p)
    else:
        if rot_axis[1] < 0: rot_axis = -rot_axis
        Y_p = rot_axis
        X_p = np.cross(Y_p, g_vec)
        if np.linalg.norm(X_p) < 1e-6: X_p = np.array([1.0, 0.0, 0.0])
        X_p = X_p / np.linalg.norm(X_p)
        Z_p = np.cross(X_p, Y_p)
        Z_p = Z_p / np.linalg.norm(Z_p)
        
    R_PCA = np.column_stack([X_p, Y_p, Z_p])
    return R_PCA

def time_sync(t_imu, w_imu, t_pivot, w_pivot, axis_idx):
    fs = 1.0 / np.mean(np.diff(t_pivot))
    
    t_imu_u = np.arange(t_imu[0], t_imu[-1], 1.0/fs)
    w_imu_u = np.interp(t_imu_u, t_imu, w_imu[:, axis_idx])
    
    t_piv_u = np.arange(t_pivot[0], t_pivot[-1], 1.0/fs)
    w_piv_u = np.interp(t_piv_u, t_pivot, w_pivot[:, axis_idx])
    
    # Normalize before correlation
    w_imu_norm = w_imu_u - np.mean(w_imu_u)
    w_piv_norm = w_piv_u - np.mean(w_piv_u)
    
    corr = correlate(w_imu_norm, w_piv_norm, mode='full')
    lags = np.arange(-len(w_piv_norm) + 1, len(w_imu_norm))
    lag_idx = np.argmax(np.abs(corr))
    
    delay_sec = lags[lag_idx] * (1.0/fs)
    time_delay = (t_imu_u[0] + delay_sec) - t_piv_u[0]
    
    is_inverted = bool(corr[lag_idx] < 0)
    return time_delay, is_inverted

def plot_before_after(t_imu_synced, a_linear_aligned, w_aligned, g_body_aligned, euler_raw, t_final, a_final, w_final, g_final, euler_final):
    fig, axs = plt.subplots(2, 2, figsize=(14, 8))
    fig.canvas.manager.set_window_title("Dữ liệu Trước và Sau khi cắt")
    
    axs[0, 0].plot(t_imu_synced, a_linear_aligned[:, 0], 'r--', alpha=0.3, label='X (trước)')
    axs[0, 0].plot(t_imu_synced, a_linear_aligned[:, 1], 'g--', alpha=0.3, label='Y (trước)')
    axs[0, 0].plot(t_imu_synced, a_linear_aligned[:, 2], 'b--', alpha=0.3, label='Z (trước)')
    axs[0, 0].plot(t_final, a_final[:, 0], 'r', linewidth=1.5, label='X (sau)')
    axs[0, 0].plot(t_final, a_final[:, 1], 'g', linewidth=1.5, label='Y (sau)')
    axs[0, 0].plot(t_final, a_final[:, 2], 'b', linewidth=1.5, label='Z (sau)')
    axs[0, 0].set_title('Gia tốc tịnh tiến (Acc)')
    axs[0, 0].legend()
    axs[0, 0].grid(True)
    
    axs[0, 1].plot(t_imu_synced, w_aligned[:, 0], 'r--', alpha=0.3)
    axs[0, 1].plot(t_imu_synced, w_aligned[:, 1], 'g--', alpha=0.3)
    axs[0, 1].plot(t_imu_synced, w_aligned[:, 2], 'b--', alpha=0.3)
    axs[0, 1].plot(t_final, w_final[:, 0], 'r', linewidth=1.5)
    axs[0, 1].plot(t_final, w_final[:, 1], 'g', linewidth=1.5)
    axs[0, 1].plot(t_final, w_final[:, 2], 'b', linewidth=1.5)
    axs[0, 1].set_title('Vận tốc góc (Gyro)')
    axs[0, 1].grid(True)
    
    axs[1, 0].plot(t_imu_synced, g_body_aligned[:, 0], 'r--', alpha=0.3)
    axs[1, 0].plot(t_imu_synced, g_body_aligned[:, 1], 'g--', alpha=0.3)
    axs[1, 0].plot(t_imu_synced, g_body_aligned[:, 2], 'b--', alpha=0.3)
    axs[1, 0].plot(t_final, g_final[:, 0], 'r', linewidth=1.5)
    axs[1, 0].plot(t_final, g_final[:, 1], 'g', linewidth=1.5)
    axs[1, 0].plot(t_final, g_final[:, 2], 'b', linewidth=1.5)
    axs[1, 0].set_title('Vectơ Trọng trường (Gravity)')
    axs[1, 0].grid(True)
    
    # euler_raw: 0=Yaw, 1=Pitch, 2=Roll
    axs[1, 1].plot(t_imu_synced, euler_raw[:, 0], 'r--', alpha=0.3, label='Yaw (trước)')
    axs[1, 1].plot(t_imu_synced, euler_raw[:, 1], 'g--', alpha=0.3, label='Pitch (trước)')
    axs[1, 1].plot(t_imu_synced, euler_raw[:, 2], 'b--', alpha=0.3, label='Roll (trước)')
    
    # euler_final: 0=Yaw, 1=Pitch, 2=Roll
    axs[1, 1].plot(t_final, euler_final[:, 0], 'r', linewidth=1.5, label='Yaw (sau)')
    axs[1, 1].plot(t_final, euler_final[:, 1], 'g', linewidth=1.5, label='Pitch (sau)')
    axs[1, 1].plot(t_final, euler_final[:, 2], 'b', linewidth=1.5, label='Roll (sau)')
    axs[1, 1].set_title('Góc Euler')
    axs[1, 1].legend(loc='upper right', fontsize='small', ncol=2)
    axs[1, 1].grid(True)
    
    plt.tight_layout()
    plt.show()


# ==============================================================================
# MAIN APP (3 TABS)
# ==============================================================================
class AdvancedPipelineApp:
    def __init__(self, parent):
        self.parent = parent
        self.COLOR_ON         = "#4CAF50"
        self.COLOR_OFF        = "#E0E0E0"
        self.COLOR_SIGNAL_OFF = "#FFCDD2"
        self.COLOR_LOAD       = "#2196F3"
        self.COLOR_APPLY      = "#FF5722"
        self.COLOR_RESET      = "#F44336"

        # DỮ LIỆU DÙNG CHUNG
        self.df          = None   
        self._raw_df     = None   
        self.filtered_df = None   
        
        self.pca_aligned_df = None # Lưu kết quả sau Tab 2
        self.pivot_data = None     # Dữ liệu trục Pivot (Tab 3)
        self.synced_delay = 0.0

        # UI Setup
        self.notebook = ttk.Notebook(self.parent)
        self.notebook.pack(fill=tk.BOTH, expand=True)

        self.tab1 = tk.Frame(self.notebook)
        self.tab2 = tk.Frame(self.notebook)
        self.tab3 = tk.Frame(self.notebook)

        self.notebook.add(self.tab1, text="1. LỌC TÍN HIỆU (Filter)")
        self.notebook.add(self.tab2, text="2. ĐO TRỌNG TRƯỜNG & PCA")
        self.notebook.add(self.tab3, text="3. ĐỒNG BỘ & XUẤT M-CODE")

        self._build_tab1()
        self._build_tab2()
        self._build_tab3()
        
    # -------------------------------------------------------------------------
    # TAB 1: LỌC TÍN HIỆU
    # -------------------------------------------------------------------------
    def _build_tab1(self):
        self.filter_order   = []
        self.filter_buttons = {}
        self.param_entries  = {}
        self.signal_buttons = {}
        self.signal_active  = {}
        
        self.line_vars      = {}  
        self.fft_view_mode  = tk.StringVar(value="Accel")
        self.fft_on_raw     = tk.BooleanVar(value=False)   
        self.use_psd_mode   = tk.BooleanVar(value=False)
        self.time_unit_var  = tk.StringVar(value="microseconds (µs)")  
        self.time_shift_var = tk.StringVar(value="0.0")

        self.filter_params = {
            "lowpass":  2.0,   
            "highpass":  5,   
            "average":   5,     
            "kalman_Q":  0.1,   
            "kalman_R":  1.0,   
            "comp":      0.98,  
        }
        self.roll_offset = 0.0
        self.pitch_offset = 0.0
        self._fs_last = 100.0  

        top_container = tk.Frame(self.tab1)
        top_container.pack(fill=tk.X, padx=10, pady=5)

        filter_display = [
            ("lowpass",  "LOW-PASS\n(Hz)"),
            ("highpass", "HIGH-PASS\n(Hz)"),
            ("average",  "AVG\n(samples)"),
            ("kalman_Q", "KALMAN Q"),
            ("kalman_R", "KALMAN R"),  
            ("comp",     "COMP α"),
        ]

        toggle_filters = {"lowpass", "highpass", "average", "kalman_Q", "comp"}

        for name, label in filter_display:
            frame = tk.LabelFrame(top_container, text=label)
            frame.pack(side=tk.LEFT, padx=4)

            if name in toggle_filters:
                btn = tk.Button(frame, text="OFF", width=7, bg=self.COLOR_OFF, command=lambda n=name: self.toggle_filter(n))
                btn.pack()
                self.filter_buttons[name] = btn
            else:
                tk.Label(frame, text="(param)", font=("", 8)).pack()

            ent = tk.Entry(frame, width=6)
            ent.insert(0, str(self.filter_params[name]))
            ent.pack()
            self.param_entries[name] = ent

        btn_frame = tk.Frame(top_container)
        btn_frame.pack(side=tk.LEFT, padx=8)
        
        tk.Button(btn_frame, text="APPLY\nPARAMS", bg=self.COLOR_APPLY, fg="white", font=("", 8, "bold"),
                  command=self.update_params).pack(side=tk.LEFT, padx=2)
        tk.Button(btn_frame, text="RESET\nALL", bg=self.COLOR_RESET, fg="white", font=("", 8, "bold"),
                  command=self.reset_all).pack(side=tk.LEFT, padx=2)
        
        tk.Button(btn_frame, text="CALIBRATE\nLEVEL", bg="#4CAF50", fg="white", font=("", 8, "bold"),
                  command=self.calibrate_level).pack(side=tk.LEFT, padx=2)

        tu_frame = tk.LabelFrame(top_container, text="TIME UNIT")
        tu_frame.pack(side=tk.LEFT, padx=5)
        for label in TIME_UNITS:
            tk.Radiobutton(tu_frame, text=label, variable=self.time_unit_var, value=label, command=self.plot_tab1).pack(anchor=tk.W)

        fft_frame = tk.LabelFrame(top_container, text="FFT VIEW")
        fft_frame.pack(side=tk.LEFT, padx=8)
        for mode in ["Accel", "Gyro", "Orientation"]:
            tk.Radiobutton(fft_frame, text=mode, variable=self.fft_view_mode, value=mode, command=self.plot_tab1).pack(anchor=tk.W)
        tk.Checkbutton(fft_frame, text="FFT on raw", variable=self.fft_on_raw, command=self.plot_tab1).pack(anchor=tk.W)
        tk.Checkbutton(fft_frame, text="Use PSD (Welch)", variable=self.use_psd_mode, command=self.plot_tab1).pack(anchor=tk.W)

        btn_right_frame = tk.Frame(top_container)
        btn_right_frame.pack(side=tk.RIGHT, padx=5)
        tk.Button(btn_right_frame, text="LOAD\nIMU CSV", bg=self.COLOR_LOAD, fg="white", font=("", 9, "bold"),
                command=self.load_csv).pack(side=tk.TOP, fill=tk.X, pady=2)
        tk.Button(btn_right_frame, text="SAVE\nFILTERED", bg="#009688", fg="white", font=("", 9, "bold"),
                command=self.save_filtered_csv).pack(side=tk.TOP, fill=tk.X, pady=2)

        content = tk.Frame(self.tab1)
        content.pack(fill=tk.BOTH, expand=True)

        self.left = tk.Frame(content, width=210)
        self.left.pack(side=tk.LEFT, fill=tk.Y)
        self.left_inner = tk.Frame(self.left)
        self.left_inner.pack(fill=tk.BOTH, expand=True)

        self.plot_frame_1 = tk.Frame(content)
        self.plot_frame_1.pack(side=tk.RIGHT, fill=tk.BOTH, expand=True)

        self.fig1 = plt.figure(figsize=(10, 8))
        self.canvas1 = FigureCanvasTkAgg(self.fig1, master=self.plot_frame_1)
        self.toolbar1 = NavigationToolbar2Tk(self.canvas1, self.plot_frame_1)
        self.canvas1.get_tk_widget().pack(fill=tk.BOTH, expand=True)

    def reset_all(self):
        self.filter_order.clear()
        for btn in self.filter_buttons.values():
            btn.config(text="OFF", bg=self.COLOR_OFF, fg="black")
        self.time_shift_var.set("0.0")
        self.roll_offset = 0.0
        self.pitch_offset = 0.0
        for col_vars in self.line_vars.values():
            col_vars['max'].set(False)
            col_vars['min'].set(False)
            col_vars['mean'].set(False)
        self.plot_tab1()

    def update_params(self):
        try:
            for k in self.filter_params: self.filter_params[k] = float(self.param_entries[k].get())
        except ValueError as e: return messagebox.showerror("Tham số lỗi", str(e))
        self.plot_tab1()

    def toggle_filter(self, name):
        if name in self.filter_order:
            self.filter_order.remove(name); self.filter_buttons[name].config(text="OFF", bg=self.COLOR_OFF, fg="black")
        else:
            self.filter_order.append(name); self.filter_buttons[name].config(text="ON", bg=self.COLOR_ON, fg="white")
        self.plot_tab1()

    def toggle_signal(self, name):
        self.signal_active[name] = not self.signal_active[name]
        if self.signal_active[name]: self.signal_buttons[name].config(text=f"{name}: ON", bg=self.COLOR_ON, fg="white")
        else: self.signal_buttons[name].config(text=f"{name}: OFF", bg=self.COLOR_SIGNAL_OFF, fg="black")
        self.plot_tab1()

    def calibrate_level(self):
        if self.filtered_df is None or len(self.filtered_df) < 2: return messagebox.showwarning("Cảnh báo", "Vui lòng tải file CSV trước!")
        roll_col = next((c for c in self.filtered_df.columns if "roll" in c.lower()), None)
        pitch_col = next((c for c in self.filtered_df.columns if "pitch" in c.lower()), None)
        if roll_col and pitch_col:
            self.roll_offset = float(np.mean(self.filtered_df[roll_col].values))
            self.pitch_offset = float(np.mean(self.filtered_df[pitch_col].values))
            messagebox.showinfo("Hiệu chỉnh thành công", f"Roll offset: {self.roll_offset:.4f}°\nPitch offset: {self.pitch_offset:.4f}°")
            self.plot_tab1()

    def check_and_convert_acc_unit(self):
        if self.df is None: return
        acc_cols = [c for c in self.df.columns if self._col_type(c) == "acc"]
        if not acc_cols: return
        medians = [np.median(np.abs(self.df[c].dropna())) for c in acc_cols if len(self.df[c].dropna()) > 0]
        if not medians: return
        max_median = max(medians)
        if 0.5 <= max_median <= 2.5:
            ans = messagebox.askyesno("Phát hiện đơn vị Gia tốc", "Chuyển g sang m/s² (nhân 9.80665)?")
            if ans:
                for c in acc_cols:
                    self.df[c] = self.df[c] * 9.80665
                    self._raw_df[c] = self._raw_df[c] * 9.80665
                messagebox.showinfo("Thành công", "Đã chuyển đổi sang m/s².")

    def load_csv(self):
        path = filedialog.askopenfilename(filetypes=[("CSV files", "*.csv"), ("All files", "*.*")])
        if not path: return
        try: raw = pd.read_csv(path)
        except Exception as e: return messagebox.showerror("Lỗi đọc file", str(e))

        df = raw.copy()
        df = df.interpolate(method="linear").bfill().ffill()
        self.df = df
        self._raw_df = df.copy() 

        self.check_and_convert_acc_unit()

        self.line_vars.clear()
        for col in self.df.columns[1:]:
            self.line_vars[col] = { 'max': tk.BooleanVar(value=False), 'min': tk.BooleanVar(value=False), 'mean': tk.BooleanVar(value=False) }

        for w in self.left_inner.winfo_children(): w.destroy()
        self.signal_buttons.clear()
        self.signal_active.clear()

        for col in self.df.columns[1:]:
            self.signal_active[col] = True
            btn = tk.Button(self.left_inner, text=f"{col}: ON", bg=self.COLOR_ON, fg="white", command=lambda c=col: self.toggle_signal(c))
            btn.pack(fill=tk.X)
            self.signal_buttons[col] = btn

        self.reset_all()

    def save_filtered_csv(self):
        if self.df is None: return
        self.apply_filters()
        path = filedialog.asksaveasfilename(defaultextension=".csv", filetypes=[("CSV", "*.csv")])
        if path:
            save_df = self.filtered_df.copy()
            save_df.attrs["sampling_rate"] = self._fs_last
            save_df.to_csv(path, index=False)
            messagebox.showinfo("Thành công", f"Đã lưu:\n{path}")

    @staticmethod
    def _col_type(col_name: str) -> str:
        n = col_name.lower()
        if n.startswith("acc"): return "acc"
        if n.startswith("gyr"): return "gyro"
        if any(x in n for x in ["roll", "pitch", "yaw"]): return "ori"
        return "other"

    def apply_filters(self):
        if self.df is None: return
        t_scale = TIME_UNITS[self.time_unit_var.get()]
        t_raw   = self.df.iloc[:, 0].values * t_scale   
        t_shifted = t_raw # Tab 1 không cắt nữa

        temp_df = self.df.copy()
        temp_df.iloc[:, 0] = t_shifted / t_scale 
        t  = temp_df.iloc[:, 0].values * t_scale
        dt = float(np.mean(np.diff(t)))
        if dt <= 0 or not np.isfinite(dt): dt = 0.01
        fs = 1.0 / dt
        self._fs_last = fs

        if "comp" in self.filter_order:
            alpha = float(np.clip(self.filter_params["comp"], 0.0, 1.0))
            cols    = temp_df.columns.str.lower()
            acc_idx = [i for i, c in enumerate(cols) if c.startswith("acc")]
            gyr_idx = [i for i, c in enumerate(cols) if c.startswith("gyr")]

            if len(acc_idx) >= 3 and len(gyr_idx) >= 3:
                acc_vals = [temp_df.iloc[:, acc_idx[i]].values for i in range(3)]
                max_g = np.max(np.abs(temp_df.iloc[:, gyr_idx[0]].dropna().values))
                if max_g < 10.0:
                    gyr_vals = [temp_df.iloc[:, gyr_idx[i]].values for i in range(3)]
                else:
                    gyr_vals = [np.radians(temp_df.iloc[:, gyr_idx[i]].values) for i in range(3)]
                ay_mapped = acc_vals[ACC_AXES['roll']]
                az_mapped = acc_vals[2]
                ax_mapped = acc_vals[ACC_AXES['pitch']]
                gx_mapped = gyr_vals[GYRO_AXES['roll']]
                gy_mapped = gyr_vals[GYRO_AXES['pitch']]
                denom = np.sqrt(ay_mapped**2 + az_mapped**2)
                denom = np.where(np.abs(denom) < 1e-9, 1e-9, denom)
                pitch_acc_rad = np.arctan2(-ax_mapped, denom)
                roll_acc_rad = np.arctan2(ay_mapped, az_mapped)
                pitch_rad, roll_rad = np.zeros(len(t)), np.zeros(len(t))
                pitch_rad[0], roll_rad[0] = pitch_acc_rad[0], roll_acc_rad[0]
                # Adaptive logic
                acc_norm = np.sqrt(acc_vals[0]**2 + acc_vals[1]**2 + acc_vals[2]**2)
                g_ref = np.median(acc_norm) if len(acc_norm) > 0 else 9.81
                
                for i in range(1, len(t)):
                    err = abs(acc_norm[i] - g_ref) / g_ref if g_ref > 0 else 0
                    alpha_t = 1.0 if err > 0.1 else alpha
                    
                    pitch_rad[i] = (alpha_t * (pitch_rad[i-1] + gy_mapped[i] * dt) + (1.0 - alpha_t) * pitch_acc_rad[i])
                    roll_rad[i]  = (alpha_t * (roll_rad[i-1]  + gx_mapped[i] * dt) + (1.0 - alpha_t) * roll_acc_rad[i])
                for c in temp_df.columns:
                    cl = c.lower()
                    if "pitch" in cl: temp_df[c] = np.degrees(pitch_rad) - self.pitch_offset
                    if "roll" in cl: temp_df[c] = np.degrees(roll_rad) - self.roll_offset

        nyq = 0.5 * fs
        for f in self.filter_order:
            if f == "comp": continue
            p_val = self.filter_params[f]
            for col in temp_df.columns[1:]:
                if f in ("lowpass", "highpass", "average") and self._col_type(col) not in ("acc", "gyro"): continue
                data = temp_df[col].values.astype(float)
                if len(data) < 10: continue
                if f == "lowpass" and 0 < p_val < nyq:
                    b, a = butter(2, p_val / nyq, btype="low")
                    if len(data) > 3 * max(len(a), len(b)) - 1:
                        try: data = filtfilt(b, a, data)
                        except: pass
                elif f == "highpass" and 0 < p_val < nyq:
                    b, a = butter(2, p_val / nyq, btype="high")
                    if len(data) > 3 * max(len(a), len(b)) - 1:
                        try: data = filtfilt(b, a, data)
                        except: pass
                elif f == "average" and p_val > 1:
                    data = pd.Series(data).rolling(int(p_val), center=True, min_periods=1).mean().values
                elif f == "kalman_Q":
                    Q, R, P, x_hat = max(float(p_val), 1e-9), max(float(self.filter_params["kalman_R"]), 1e-9), float(np.var(data)) if np.var(data)>0 else 1.0, data[0]
                    out = np.empty_like(data)
                    for i, z in enumerate(data):
                        P += Q; K = P / (P + R); x_hat = x_hat + K * (z - x_hat); P = (1.0 - K) * P
                        out[i] = x_hat
                    data = out
                temp_df[col] = data
        self.filtered_df = temp_df

    def _compute_fft(self, data, fs):
        n = len(data)
        if n < 20: return None
        data_win = (data - np.mean(data)) * np.hanning(n)
        mag, frq = np.abs(np.fft.rfft(data_win)) / (n / 2), np.fft.rfftfreq(n, 1.0 / fs)
        if len(frq) < 3: return None
        idx = int(np.argmax(mag[1:])) + 1
        if 1 <= idx < len(mag) - 1:
            a_p, b_p, c_p = mag[idx-1], mag[idx], mag[idx+1]
            denom = a_p - 2*b_p + c_p
            dom_freq = frq[idx] + 0.5 * (a_p - c_p) / denom * (frq[1] - frq[0]) if abs(denom) > 1e-12 else frq[idx]
        else: dom_freq = frq[idx]
        return frq, mag, dom_freq

    def _compute_psd(self, data, fs):
        n = len(data)
        if n < 20: return None
        frq, psd = welch(data, fs=fs, window='hann', nperseg=min(256, n//2), noverlap=None)
        if len(frq) < 3: return None
        idx = int(np.argmax(psd[1:])) + 1
        return frq, psd, frq[idx]

    def plot_tab1(self):
        if self.df is None: return
        self.apply_filters()
        if self.filtered_df is None or len(self.filtered_df) < 2: return

        self.fig1.clf()
        ax1 = self.fig1.add_subplot(221)
        ax2 = self.fig1.add_subplot(222)
        ax3 = self.fig1.add_subplot(223)
        ax4 = self.fig1.add_subplot(224)

        t        = self.filtered_df.iloc[:, 0].values * TIME_UNITS[self.time_unit_var.get()]
        fs       = self._fs_last
        fft_mode = self.fft_view_mode.get()

        for col in self.filtered_df.columns[1:]:
            if not self.signal_active.get(col, False): continue
            data     = self.filtered_df[col].values
            col_type = self._col_type(col)

            target_ax = ax1 if col_type == "acc" else (ax2 if col_type == "gyro" else ax3)
            target_ax.plot(t, data, label=col, linewidth=0.9)

            do_fft = ((fft_mode == "Accel" and col_type == "acc") or (fft_mode == "Gyro" and col_type == "gyro") or (fft_mode == "Orientation" and col_type == "ori"))
            if do_fft:
                result = self._compute_psd(data, fs) if self.use_psd_mode.get() else self._compute_fft(data, fs)
                if result is not None:
                    ax4.plot(result[0], result[1], label=f"{col} ({result[2]:.2f} Hz)", linewidth=0.9)

        ax1.set_title("Gia tốc tuyến tính"); ax1.set_ylabel("m/s²"); ax1.set_xlabel("Thời gian (s)")
        ax2.set_title("Vận tốc góc"); ax2.set_ylabel("deg/s"); ax2.set_xlabel("Thời gian (s)")
        ax3.set_title("Góc định hướng"); ax3.set_ylabel("deg"); ax3.set_xlabel("Thời gian (s)")
        
        analysis_mode = "PSD (Welch)" if self.use_psd_mode.get() else "FFT"
        ax4.set_title(f"Phân tích {analysis_mode} ({fft_mode})")
        ax4.set_ylabel("Power/Hz" if self.use_psd_mode.get() else "Biên độ")
        ax4.set_xlabel("Hz")

        for ax in [ax1, ax2, ax3, ax4]:
            ax.legend(fontsize=7); ax.grid(True, linestyle="--", alpha=0.4)
        ax4.set_xlim(0, min(30.0, fs / 2.0))

        self.fig1.tight_layout()
        self.canvas1.draw()
        
    # -------------------------------------------------------------------------
    # TAB 2: ĐO TRỌNG TRƯỜNG & PCA
    # -------------------------------------------------------------------------
    def _build_tab2(self):
        top_frame = tk.Frame(self.tab2, pady=10)
        top_frame.pack(fill=tk.X)
        
        tk.Button(top_frame, text="TẢI DỮ LIỆU TỪ TAB 1 (LỌC)", bg="#2196F3", fg="white", font=("", 10, "bold"),
                  command=self.load_data_to_tab2).pack(side=tk.LEFT, padx=10)
                  
        ctrl_frame = tk.LabelFrame(top_frame, text="Khoảng thời gian đứng yên (Tĩnh)")
        ctrl_frame.pack(side=tk.LEFT, padx=20)
        
        tk.Label(ctrl_frame, text="Motion (roll/pitch):").pack(side=tk.LEFT, padx=5)
        self.pca_motion_var = tk.StringVar(value="roll")
        tk.Entry(ctrl_frame, textvariable=self.pca_motion_var, width=8).pack(side=tk.LEFT)
        
        tk.Label(ctrl_frame, text="Từ (s):").pack(side=tk.LEFT, padx=5)
        self.pca_t_start_var = tk.StringVar(value="0.0")
        tk.Entry(ctrl_frame, textvariable=self.pca_t_start_var, width=6).pack(side=tk.LEFT)
        
        tk.Label(ctrl_frame, text="Đến (s):").pack(side=tk.LEFT, padx=5)
        self.pca_t_end_var = tk.StringVar(value="2.0")
        tk.Entry(ctrl_frame, textvariable=self.pca_t_end_var, width=6).pack(side=tk.LEFT)
        
        tk.Label(ctrl_frame, text="(Kéo thả chuột trên biểu đồ)").pack(side=tk.LEFT, padx=10)
        
        tk.Button(top_frame, text="▶ THỰC HIỆN ĐO & PCA", bg="#FF9800", fg="white", font=("", 10, "bold"),
                  command=self.run_pca_alignment).pack(side=tk.RIGHT, padx=10)
                  
        self.lbl_pca_angles = tk.Label(self.tab2, text="Góc lệch IMU so với Pivot (sau PCA): Chưa có dữ liệu", font=("", 11, "bold"), fg="blue")
        self.lbl_pca_angles.pack(fill=tk.X, padx=10, pady=5)
                  
        self.plot_frame_2 = tk.Frame(self.tab2)
        self.plot_frame_2.pack(fill=tk.BOTH, expand=True)

        self.fig2, self.ax2 = plt.subplots(figsize=(10, 5))
        self.canvas2 = FigureCanvasTkAgg(self.fig2, master=self.plot_frame_2)
        self.toolbar2 = NavigationToolbar2Tk(self.canvas2, self.plot_frame_2)
        self.canvas2.get_tk_widget().pack(fill=tk.BOTH, expand=True)
        
        self.pca_span = None

    def load_data_to_tab2(self):
        if self.filtered_df is None:
            messagebox.showerror("Lỗi", "Vui lòng chọn Load CSV và áp dụng bộ lọc ở Tab 1 trước!")
            return
            
        t_scale = TIME_UNITS[self.time_unit_var.get()]
        t = self.filtered_df.iloc[:, 0].values * t_scale
        t = t - t[0] # Chuyển về bắt đầu từ 0
        
        acc_cols = [c for c in self.filtered_df.columns if "acc" in c.lower()]
        if len(acc_cols) < 3: return
        
        self.ax2.clear()
        self.ax2.plot(t, self.filtered_df[acc_cols[0]].values, label=acc_cols[0], alpha=0.8)
        self.ax2.plot(t, self.filtered_df[acc_cols[1]].values, label=acc_cols[1], alpha=0.8)
        self.ax2.plot(t, self.filtered_df[acc_cols[2]].values, label=acc_cols[2], alpha=0.8)
        self.ax2.set_title("Gia tốc - Kéo thả để chọn vùng thời gian đứng yên")
        self.ax2.set_xlabel("Thời gian (s)")
        self.ax2.set_ylabel("Gia tốc")
        self.ax2.legend()
        self.ax2.grid(True)
        
        self.fig2.tight_layout()
        self.canvas2.draw()
        
        def on_span_select(vmin, vmax):
            self.pca_t_start_var.set(f"{vmin:.3f}")
            self.pca_t_end_var.set(f"{vmax:.3f}")
            
        self.pca_span = SpanSelector(self.ax2, on_span_select, 'horizontal', useblit=True, props=dict(alpha=0.3, facecolor='green'))

    def run_pca_alignment(self):
        if self.filtered_df is None:
            return messagebox.showerror("Lỗi", "Không có dữ liệu, hãy tải từ Tab 1.")
            
        try:
            t_start = float(self.pca_t_start_var.get())
            t_end = float(self.pca_t_end_var.get())
        except ValueError:
            return messagebox.showerror("Lỗi", "Tham số thời gian không hợp lệ!")
            
        t_scale = TIME_UNITS[self.time_unit_var.get()]
        t_imu = self.filtered_df.iloc[:, 0].values * t_scale
        t_imu = t_imu - t_imu[0]
        
        acc_cols = [c for c in self.filtered_df.columns if "acc" in c.lower()]
        gyr_cols = [c for c in self.filtered_df.columns if "gyr" in c.lower()]
        yaw_col = next((c for c in self.filtered_df.columns if "yaw" in c.lower()), None)
        pitch_col = next((c for c in self.filtered_df.columns if "pitch" in c.lower()), None)
        roll_col = next((c for c in self.filtered_df.columns if "roll" in c.lower()), None)
        
        a_raw = np.column_stack([self.filtered_df[acc_cols[0]].values, self.filtered_df[acc_cols[1]].values, self.filtered_df[acc_cols[2]].values])
        w_raw = np.column_stack([np.radians(self.filtered_df[gyr_cols[0]].values), 
                                 np.radians(self.filtered_df[gyr_cols[1]].values), 
                                 np.radians(self.filtered_df[gyr_cols[2]].values)])
        
        euler_yaw = self.filtered_df[yaw_col].values if yaw_col else np.zeros_like(t_imu)
        euler_pitch = self.filtered_df[pitch_col].values if pitch_col else np.zeros_like(t_imu)
        euler_roll = self.filtered_df[roll_col].values if roll_col else np.zeros_like(t_imu)
        euler_raw = np.column_stack([euler_yaw, euler_pitch, euler_roll])
        
        G = 9.81
        motion = self.pca_motion_var.get().lower()
        if "roll" not in motion and "pitch" not in motion:
            return messagebox.showerror("Lỗi", "Tên Motion phải chứa 'roll' hoặc 'pitch'!")
            
        a_linear_body = np.zeros_like(a_raw)
        axg_arr, ayg_arr, azg_arr = np.zeros(len(t_imu)), np.zeros(len(t_imu)), np.zeros(len(t_imu))
        
        for i in range(len(t_imu)):
            y_r, p_r, r_r = np.radians(euler_raw[i])
            R_e = Rzyx(y_r, p_r, r_r)
            g_body = R_e.T @ np.array([0.0, 0.0, G])
            axg_arr[i], ayg_arr[i], azg_arr[i] = g_body[0], g_body[1], g_body[2]
            a_linear_body[i] = a_raw[i] - g_body
            
        R_PCA = pca_alignment(w_raw, a_raw, t_imu, t_start, t_end, motion=motion)
        
        a_linear_aligned = np.dot(a_linear_body, R_PCA)
        w_aligned = np.dot(w_raw, R_PCA)
        g_body_aligned = np.dot(np.column_stack([axg_arr, ayg_arr, azg_arr]), R_PCA)
        
        # Transform Euler angles
        euler_aligned = np.zeros_like(euler_raw)
        for i in range(len(t_imu)):
            R_t = Rzyx(np.radians(euler_raw[i, 0]), np.radians(euler_raw[i, 1]), np.radians(euler_raw[i, 2]))
            R_new = R_t @ R_PCA
            y, p, r = extract_euler_zyx(R_new)
            euler_aligned[i] = [y, p, r]
            
        # Dịch góc Yaw về 0 (vì Yaw ban đầu của IMU là ngẫu nhiên)
        yaw_unwrapped = np.unwrap(np.radians(euler_aligned[:, 0]))
        mean_yaw = np.mean(yaw_unwrapped)
        euler_aligned[:, 0] = np.degrees(yaw_unwrapped - mean_yaw)
            
        R_IMU_to_Pivot = R_PCA.T
        mis_y, mis_p, mis_r = extract_euler_zyx(R_IMU_to_Pivot)
        self.lbl_pca_angles.config(text=f"Góc lệch lắp đặt IMU (so với Pivot): Yaw = {mis_y:.2f}°, Pitch = {mis_p:.2f}°, Roll = {mis_r:.2f}°")
        
        self.pca_aligned_df = {
            't': t_imu,
            'a_aligned': a_linear_aligned,
            'w_aligned': w_aligned,
            'g_aligned': g_body_aligned,
            'euler_aligned': euler_aligned,
            'euler_raw': euler_raw
        }
        
        self.plot_pca_comparison(t_imu, a_linear_body, w_raw, euler_raw, a_linear_aligned, w_aligned, euler_aligned)
        
        messagebox.showinfo("Thành công", f"Đo PCA hoàn tất.\nGóc lệch lắp đặt: Yaw={mis_y:.2f}°, Pitch={mis_p:.2f}°, Roll={mis_r:.2f}°")
        
    def plot_pca_comparison(self, t, a_raw, w_raw, euler_raw, a_aligned, w_aligned, euler_aligned):
        fig, axs = plt.subplots(3, 2, figsize=(14, 10))
        fig.canvas.manager.set_window_title("So sánh Trước và Sau PCA Alignment")
        
        # W Raw
        axs[0, 0].plot(t, w_raw[:, 0], 'r--', alpha=0.7, label='wx (raw)')
        axs[0, 0].plot(t, w_raw[:, 1], 'g--', alpha=0.7, label='wy (raw)')
        axs[0, 0].plot(t, w_raw[:, 2], 'b--', alpha=0.7, label='wz (raw)')
        axs[0, 0].set_title('Vận tốc góc (Trước PCA)')
        axs[0, 0].legend()
        axs[0, 0].grid(True)
        
        # W Aligned
        axs[0, 1].plot(t, w_aligned[:, 0], 'r', label='wx (aligned)')
        axs[0, 1].plot(t, w_aligned[:, 1], 'g', label='wy (aligned)')
        axs[0, 1].plot(t, w_aligned[:, 2], 'b', label='wz (aligned)')
        axs[0, 1].set_title('Vận tốc góc (Sau PCA)')
        axs[0, 1].legend()
        axs[0, 1].grid(True)
        
        # A Raw
        axs[1, 0].plot(t, a_raw[:, 0], 'r--', alpha=0.7, label='ax (raw)')
        axs[1, 0].plot(t, a_raw[:, 1], 'g--', alpha=0.7, label='ay (raw)')
        axs[1, 0].plot(t, a_raw[:, 2], 'b--', alpha=0.7, label='az (raw)')
        axs[1, 0].set_title('Gia tốc tịnh tiến (Trước PCA)')
        axs[1, 0].legend()
        axs[1, 0].grid(True)
        
        # A Aligned
        axs[1, 1].plot(t, a_aligned[:, 0], 'r', label='ax (aligned)')
        axs[1, 1].plot(t, a_aligned[:, 1], 'g', label='ay (aligned)')
        axs[1, 1].plot(t, a_aligned[:, 2], 'b', label='az (aligned)')
        axs[1, 1].set_title('Gia tốc tịnh tiến (Sau PCA)')
        axs[1, 1].legend()
        axs[1, 1].grid(True)
        
        # Euler Raw
        axs[2, 0].plot(t, euler_raw[:, 0], 'r--', alpha=0.7, label='Yaw (raw)')
        axs[2, 0].plot(t, euler_raw[:, 1], 'g--', alpha=0.7, label='Pitch (raw)')
        axs[2, 0].plot(t, euler_raw[:, 2], 'b--', alpha=0.7, label='Roll (raw)')
        axs[2, 0].set_title('Góc Euler (Trước PCA)')
        axs[2, 0].legend()
        axs[2, 0].grid(True)
        
        # Euler Aligned
        axs[2, 1].plot(t, euler_aligned[:, 0], 'r', label='Yaw (aligned)')
        axs[2, 1].plot(t, euler_aligned[:, 1], 'g', label='Pitch (aligned)')
        axs[2, 1].plot(t, euler_aligned[:, 2], 'b', label='Roll (aligned)')
        axs[2, 1].set_title('Góc Euler (Sau PCA)')
        axs[2, 1].legend()
        axs[2, 1].grid(True)
        
        plt.tight_layout()
        plt.show(block=False)
        
    # -------------------------------------------------------------------------
    # TAB 3: ĐỒNG BỘ & XUẤT M-CODE
    # -------------------------------------------------------------------------
    def _build_tab3(self):
        top_frame = tk.Frame(self.tab3, pady=5)
        top_frame.pack(fill=tk.X, padx=10)
        
        file_frame = tk.LabelFrame(top_frame, text="File Mô Phỏng (Pivot)")
        file_frame.pack(side=tk.LEFT, fill=tk.Y, padx=5)
        
        self.pivot_file_var = tk.StringVar()
        tk.Entry(file_frame, textvariable=self.pivot_file_var, width=40).pack(side=tk.LEFT, padx=5, pady=5)
        tk.Button(file_frame, text="Browse", command=self.load_pivot).pack(side=tk.LEFT, padx=5)
        
        param_frame = tk.LabelFrame(top_frame, text="Cấu hình Xuất")
        param_frame.pack(side=tk.LEFT, fill=tk.Y, padx=10)
        
        self.p_amp = tk.StringVar(value="10")
        self.p_freq = tk.StringVar(value="0.25")
        self.p_fs = tk.StringVar(value="100")
        self.p_cz = tk.StringVar(value="0")
        
        labels = ["Amp:", "Freq:", "Fs:", "Cz:"]
        vars = [self.p_amp, self.p_freq, self.p_fs, self.p_cz]
        for i, (l, v) in enumerate(zip(labels, vars)):
            tk.Label(param_frame, text=l).pack(side=tk.LEFT, padx=(5,0))
            tk.Entry(param_frame, textvariable=v, width=5).pack(side=tk.LEFT)
            
        tk.Button(top_frame, text="TẢI PIVOT & ĐỒNG BỘ", bg="#2196F3", fg="white", font=("", 9, "bold"),
                  command=self.sync_and_plot).pack(side=tk.LEFT, padx=10, pady=5)
                  
        self.invert_axis_var = tk.BooleanVar(value=False)
        tk.Checkbutton(top_frame, text="Đảo chiều trục X/Y", variable=self.invert_axis_var, command=self.sync_and_plot).pack(side=tk.LEFT, padx=5)

        crop_frame = tk.Frame(self.tab3, pady=5)
        crop_frame.pack(fill=tk.X, padx=10)
        
        lbl_crop = tk.Label(crop_frame, text="Kéo trên đồ thị để cắt dữ liệu toàn bộ vùng trong vệt đỏ (Cắt đoạn cần giữ lại). Vùng được chọn:")
        lbl_crop.pack(side=tk.LEFT)
        
        self.crop_start_var = tk.StringVar(value="0.0")
        self.crop_end_var = tk.StringVar(value="100.0")
        tk.Entry(crop_frame, textvariable=self.crop_start_var, width=8).pack(side=tk.LEFT, padx=5)
        tk.Label(crop_frame, text="đến").pack(side=tk.LEFT)
        tk.Entry(crop_frame, textvariable=self.crop_end_var, width=8).pack(side=tk.LEFT, padx=5)
        
        tk.Button(crop_frame, text="▶ XUẤT FILE M-CODE", bg="#D32F2F", fg="white", font=("", 10, "bold"),
                  command=self.export_mcode).pack(side=tk.RIGHT, padx=10)

        self.plot_frame_3 = tk.Frame(self.tab3)
        self.plot_frame_3.pack(fill=tk.BOTH, expand=True)

        self.fig3, self.axs3 = plt.subplots(3, 1, figsize=(10, 8), sharex=True)
        self.canvas3 = FigureCanvasTkAgg(self.fig3, master=self.plot_frame_3)
        self.toolbar3 = NavigationToolbar2Tk(self.canvas3, self.plot_frame_3)
        self.canvas3.get_tk_widget().pack(fill=tk.BOTH, expand=True)
        
        self.crop_span = None
        self.t_imu_synced = None
        self.valid_t_pivot = None

    def load_pivot(self):
        p = filedialog.askopenfilename(filetypes=[("CSV files", "*.csv"), ("All files", "*.*")])
        if p: self.pivot_file_var.set(p)

    def sync_and_plot(self):
        if self.pca_aligned_df is None:
            return messagebox.showerror("Lỗi", "Chưa có dữ liệu PCA. Hãy thực hiện PCA ở Tab 2!")
        if not self.pivot_file_var.get():
            return messagebox.showerror("Lỗi", "Vui lòng chọn file Pivot Command!")
            
        # Parse pivot
        pivot_data = parse_moog_file(self.pivot_file_var.get())
        if len(pivot_data) == 0:
            return messagebox.showerror("Lỗi", "Không đọc được dữ liệu Pivot (~M[])")
            
        t_pivot = pivot_data[:, 0]
        euler_pivot = pivot_data[:, 4:7] # yaw, pitch, roll
        a_pivot = pivot_data[:, 7:10] # ax, ay, az
        w_pivot = pivot_data[:, 13:16] # [wz, wy, wx]
        
        w_pivot_xyz = np.column_stack([w_pivot[:, 2], w_pivot[:, 1], w_pivot[:, 0]]) # [wx, wy, wz]
        # Pivot Euler is [yaw, pitch, roll]. We will plot X=Roll, Y=Pitch, Z=Yaw
        euler_pivot_xyz = np.column_stack([euler_pivot[:, 2], euler_pivot[:, 1], euler_pivot[:, 0]])
        
        t_imu = self.pca_aligned_df['t']
        w_aligned = self.pca_aligned_df['w_aligned']
        a_aligned = self.pca_aligned_df['a_aligned']
        euler_aligned = self.pca_aligned_df['euler_aligned'] # [yaw, pitch, roll]
        euler_aligned_xyz = np.column_stack([euler_aligned[:, 2], euler_aligned[:, 1], euler_aligned[:, 0]])
        
        motion = self.pca_motion_var.get().lower()
        axis_idx = 0 if 'roll' in motion else 1
        
        w_aligned_test = w_aligned.copy()
        a_aligned_test = a_aligned.copy()
        euler_aligned_test = euler_aligned_xyz.copy()
        
        if self.invert_axis_var.get():
            w_aligned_test[:, 0] = -w_aligned_test[:, 0]
            w_aligned_test[:, 1] = -w_aligned_test[:, 1]
            a_aligned_test[:, 0] = -a_aligned_test[:, 0]
            a_aligned_test[:, 1] = -a_aligned_test[:, 1]
            euler_aligned_test[:, 0] = -euler_aligned_test[:, 0]
            euler_aligned_test[:, 1] = -euler_aligned_test[:, 1]
            
        delay, is_inverted = time_sync(t_imu, w_aligned_test, t_pivot, w_pivot_xyz, axis_idx)
        
        if is_inverted:
            ans = messagebox.askyesno("Cảnh báo Ngược chiều", "Tín hiệu IMU có vẻ bị NHƯỢC HƯỚNG so với Pivot (Correlation âm).\nBạn có muốn tự động đảo chiều (Invert X/Y) để R dương không?")
            if ans:
                self.invert_axis_var.set(True)
                w_aligned_test[:, 0] = -w_aligned[:, 0]
                w_aligned_test[:, 1] = -w_aligned[:, 1]
                a_aligned_test[:, 0] = -a_aligned[:, 0]
                a_aligned_test[:, 1] = -a_aligned[:, 1]
                euler_aligned_test[:, 0] = -euler_aligned_xyz[:, 0]
                euler_aligned_test[:, 1] = -euler_aligned_xyz[:, 1]
                delay, _ = time_sync(t_imu, w_aligned_test, t_pivot, w_pivot_xyz, axis_idx)
        
        self.t_imu_synced = t_imu - delay
        self.synced_delay = delay
        
        for ax in self.axs3:
            ax.clear()
            
        # 1. Gyro
        self.axs3[0].plot(t_pivot, w_pivot_xyz[:, 0], 'r--', label="P-Gyro X")
        self.axs3[0].plot(t_pivot, w_pivot_xyz[:, 1], 'g--', label="P-Gyro Y")
        self.axs3[0].plot(t_pivot, w_pivot_xyz[:, 2], 'b--', label="P-Gyro Z")
        self.axs3[0].plot(self.t_imu_synced, w_aligned_test[:, 0], 'r', alpha=0.7, label="I-Gyro X")
        self.axs3[0].plot(self.t_imu_synced, w_aligned_test[:, 1], 'g', alpha=0.7, label="I-Gyro Y")
        self.axs3[0].plot(self.t_imu_synced, w_aligned_test[:, 2], 'b', alpha=0.7, label="I-Gyro Z")
        valid_mask_corr = (t_pivot >= np.min(self.t_imu_synced)) & (t_pivot <= np.max(self.t_imu_synced))
        valid_t_pivot_corr = t_pivot[valid_mask_corr]
        
        corr_x, corr_y = 0.0, 0.0
        if len(valid_t_pivot_corr) > 2:
            w_imu_interp_x = np.interp(valid_t_pivot_corr, self.t_imu_synced, w_aligned_test[:, 0])
            w_imu_interp_y = np.interp(valid_t_pivot_corr, self.t_imu_synced, w_aligned_test[:, 1])
            w_piv_x = w_pivot_xyz[valid_mask_corr, 0]
            w_piv_y = w_pivot_xyz[valid_mask_corr, 1]
            
            # Avoid division by zero warnings if variance is 0
            if np.std(w_piv_x) > 1e-6 and np.std(w_imu_interp_x) > 1e-6:
                corr_x = np.corrcoef(w_piv_x, w_imu_interp_x)[0, 1]
            if np.std(w_piv_y) > 1e-6 and np.std(w_imu_interp_y) > 1e-6:
                corr_y = np.corrcoef(w_piv_y, w_imu_interp_y)[0, 1]
                
        self.axs3[0].set_title(f"Đồng bộ (Delay: {delay:.4f}s) | Corr(Wx)={corr_x:.3f}, Corr(Wy)={corr_y:.3f} | Đảo chiều: {self.invert_axis_var.get()}")
        self.axs3[0].set_ylabel("Vận tốc góc")
        self.axs3[0].legend(loc='upper right', fontsize='small', ncol=2)
        self.axs3[0].grid(True)
        
        # 2. Accel
        self.axs3[1].plot(t_pivot, a_pivot[:, 0], 'r--', label="P-Acc X")
        self.axs3[1].plot(t_pivot, a_pivot[:, 1], 'g--', label="P-Acc Y")
        self.axs3[1].plot(t_pivot, a_pivot[:, 2], 'b--', label="P-Acc Z")
        self.axs3[1].plot(self.t_imu_synced, a_aligned_test[:, 0], 'r', alpha=0.7, label="I-Acc X")
        self.axs3[1].plot(self.t_imu_synced, a_aligned_test[:, 1], 'g', alpha=0.7, label="I-Acc Y")
        self.axs3[1].plot(self.t_imu_synced, a_aligned_test[:, 2], 'b', alpha=0.7, label="I-Acc Z")
        self.axs3[1].set_ylabel("Gia tốc")
        self.axs3[1].legend(loc='upper right', fontsize='small', ncol=2)
        self.axs3[1].grid(True)
        
        # 3. Euler
        self.axs3[2].plot(t_pivot, euler_pivot_xyz[:, 0], 'r--', label="P-Roll")
        self.axs3[2].plot(t_pivot, euler_pivot_xyz[:, 1], 'g--', label="P-Pitch")
        self.axs3[2].plot(t_pivot, euler_pivot_xyz[:, 2], 'b--', label="P-Yaw")
        self.axs3[2].plot(self.t_imu_synced, euler_aligned_test[:, 0], 'r', alpha=0.7, label="I-Roll")
        self.axs3[2].plot(self.t_imu_synced, euler_aligned_test[:, 1], 'g', alpha=0.7, label="I-Pitch")
        self.axs3[2].plot(self.t_imu_synced, euler_aligned_test[:, 2], 'b', alpha=0.7, label="I-Yaw")
        self.axs3[2].set_ylabel("Góc (deg)")
        self.axs3[2].set_xlabel("Thời gian (s)")
        self.axs3[2].legend(loc='upper right', fontsize='small', ncol=2)
        self.axs3[2].grid(True)
        
        self.fig3.tight_layout()
        self.canvas3.draw()
        
        valid_mask = (t_pivot >= np.min(self.t_imu_synced)) & (t_pivot <= np.max(self.t_imu_synced))
        self.valid_t_pivot = t_pivot[valid_mask]
        
        if len(self.valid_t_pivot) > 0:
            self.crop_start_var.set(f"{self.valid_t_pivot[0]:.3f}")
            self.crop_end_var.set(f"{self.valid_t_pivot[-1]:.3f}")
            
        def on_crop_select(vmin, vmax):
            self.crop_start_var.set(f"{vmin:.3f}")
            self.crop_end_var.set(f"{vmax:.3f}")
            
        self.crop_span = SpanSelector(self.axs3[0], on_crop_select, 'horizontal', useblit=True, props=dict(alpha=0.3, facecolor='red'))


    def export_mcode(self):
        if self.t_imu_synced is None or self.valid_t_pivot is None:
            return messagebox.showerror("Lỗi", "Chưa đồng bộ dữ liệu. Hãy bấm 'TẢI PIVOT & ĐỒNG BỘ' trước!")
            
        try:
            t_start = float(self.crop_start_var.get())
            t_end = float(self.crop_end_var.get())
        except ValueError:
            return messagebox.showerror("Lỗi", "Thông số cắt thời gian không hợp lệ!")
            
        # Lấy vùng thời gian cuối cùng để xuất
        crop_mask = (self.valid_t_pivot >= t_start) & (self.valid_t_pivot <= t_end)
        t_final = self.valid_t_pivot[crop_mask]
        
        if len(t_final) < 2:
            return messagebox.showerror("Lỗi", "Vùng dữ liệu cắt quá ngắn!")
            
        a_aligned = self.pca_aligned_df['a_aligned'].copy()
        w_aligned = self.pca_aligned_df['w_aligned'].copy()
        g_aligned = self.pca_aligned_df['g_aligned'].copy()
        euler_aligned = self.pca_aligned_df['euler_aligned'].copy()
        euler_raw = self.pca_aligned_df['euler_raw'] # Just for the before/after plot
        
        if self.invert_axis_var.get():
            a_aligned[:, 0] = -a_aligned[:, 0]
            a_aligned[:, 1] = -a_aligned[:, 1]
            w_aligned[:, 0] = -w_aligned[:, 0]
            w_aligned[:, 1] = -w_aligned[:, 1]
            g_aligned[:, 0] = -g_aligned[:, 0]
            g_aligned[:, 1] = -g_aligned[:, 1]
            # Match Tab 3's simple negation to avoid shifting Yaw by 180
            euler_aligned[:, 2] = -euler_aligned[:, 2]  # Roll
            euler_aligned[:, 1] = -euler_aligned[:, 1]  # Pitch
        
        a_final = np.zeros((len(t_final), 3))
        w_final = np.zeros((len(t_final), 3))
        g_final = np.zeros((len(t_final), 3))
        euler_final = np.zeros((len(t_final), 3))
        
        for i in range(3):
            a_final[:, i] = np.interp(t_final, self.t_imu_synced, a_aligned[:, i])
            w_final[:, i] = np.interp(t_final, self.t_imu_synced, w_aligned[:, i])
            g_final[:, i] = np.interp(t_final, self.t_imu_synced, g_aligned[:, i])
            
            euler_unwrapped = np.unwrap(np.radians(euler_aligned[:, i]))
            euler_final[:, i] = np.degrees(np.interp(t_final, self.t_imu_synced, euler_unwrapped))
            
        motion = self.pca_motion_var.get()
        amp = self.p_amp.get()
        freq = self.p_freq.get()
        fs_out = self.p_fs.get()
        cz = self.p_cz.get()
        
        default_filename = f"{motion}_{amp}_{freq}_{fs_out}_{cz}.csv"
        out_filename = filedialog.asksaveasfilename(
            defaultextension=".csv", 
            initialfile=default_filename,
            filetypes=[("CSV files", "*.csv"), ("All files", "*.*")],
            title="Lưu file M-Code (Save As)"
        )
        
        if not out_filename:
            return  # Người dùng huỷ lưu
        
        t_export = t_final - t_final[0]
        
        with open(out_filename, 'w') as f:
            for i in range(len(t_final)):
                yaw, pitch, roll = euler_final[i, 0], euler_final[i, 1], euler_final[i, 2]
                ax, ay, az = a_final[i, 0], a_final[i, 1], a_final[i, 2]
                axg, ayg, azg = g_final[i, 0], g_final[i, 1], g_final[i, 2]
                wx, wy, wz = w_final[i, 0], w_final[i, 1], w_final[i, 2]
                
                line = (
                    f"{t_export[i]:.4f} ~M[ "
                    f"0.0000 0.0000 0.0000 "
                    f"{yaw:.4f} {pitch:.4f} {roll:.4f} [ "
                    f"{ax:.4f} {ay:.4f} {az:.4f} "
                    f"{axg:.4f} {ayg:.4f} {azg:.4f} "
                    f"{wz:.4f} {wy:.4f} {wx:.4f}\n"
                )
                f.write(line)
                
        messagebox.showinfo("Thành công", f"Đã xuất file M-Code thành công:\n{out_filename}")
        
        # Plot Before / After
        plot_before_after(self.t_imu_synced, a_aligned, w_aligned, g_aligned, euler_raw, t_final, a_final, w_final, g_final, euler_final)

if __name__ == "__main__":
    root = tk.Tk()
    root.title("IMU Advanced Pipeline Studio (Tích hợp Bộ Lọc + PCA M-Code)")
    root.geometry("1400x900")
    app = AdvancedPipelineApp(root)
    root.mainloop()
