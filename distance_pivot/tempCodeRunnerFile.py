import tkinter as tk
from tkinter import filedialog, messagebox, ttk
import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
from matplotlib.backends.backend_tkagg import FigureCanvasTkAgg, NavigationToolbar2Tk
from matplotlib.widgets import SpanSelector
from scipy.signal import butter, filtfilt, correlate, welch
from sklearn.metrics import mean_squared_error
from scipy.spatial.transform import Rotation as R

# ==============================================================================
# HẰNG SỐ CHUNG
# ==============================================================================
TIME_UNITS = {
    "microseconds (µs)": 1e-6,
    "milliseconds (ms)": 1e-3,
    "seconds (s)":       1.0,
}

# ===============================================================================
# CẤU HÌNH AXIS MAPPING (ánh xạ từ trục cảm biến sang trục body)
# Thay đổi các chỉ số này để dễ dàng đổi IMU mà không cần sửa thuật toán
# ===============================================================================
# Chỉ số trục accelerometer (0=x, 1=y, 2=z)
ACC_AXES = {'roll': 1, 'pitch': 0}  # Accel Y cho Roll, Accel X cho Pitch
# Chỉ số trục gyroscope (0=x, 1=y, 2=z)
GYRO_AXES = {'roll': 0, 'pitch': 1}  # Gyro X cho Roll, Gyro Y cho Pitch

# ==============================================================================
# TAB 1: IMU Advanced Analysis Tool (ĐÃ BỔ SUNG TEXT GIÁ TRỊ LÊN ĐỒ THỊ)
# ==============================================================================
class IMUAnalysisTab:
    def __init__(self, parent_frame):
        self.parent = parent_frame

        self.COLOR_ON         = "#4CAF50"
        self.COLOR_OFF        = "#E0E0E0"
        self.COLOR_SIGNAL_OFF = "#FFCDD2"
        self.COLOR_LOAD       = "#2196F3"
        self.COLOR_APPLY      = "#FF5722"
        self.COLOR_RESET      = "#F44336"
        self.COLOR_ANALYZE    = "#9C27B0"

        self.df          = None   
        self.filtered_df = None   
        self._raw_df     = None   

        self.filter_order   = []
        self.filter_buttons = {}
        self.param_entries  = {}
        self.signal_buttons = {}
        self.signal_active  = {}
        
        self.span_selectors = []  
        self.line_vars      = {}  
        self.analysis_labels= {}  

        self.fft_view_mode  = tk.StringVar(value="Accel")
        self.fft_on_raw     = tk.BooleanVar(value=False)   
        self.use_psd_mode   = tk.BooleanVar(value=False)  # Toggle giữa FFT và PSD   
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

        # Offset calibration cho Roll/Pitch
        self.roll_offset = 0.0
        self.pitch_offset = 0.0
        self.calibration_btn = None  # Reference để hiển thị trạng thái

        self._fs_last = 100.0  
        self._build_ui()

    def _build_ui(self):
        top = tk.Frame(self.parent)
        top.pack(fill=tk.X, padx=10, pady=5)

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
            frame = tk.LabelFrame(top, text=label)
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

        btn_frame = tk.Frame(top)
        btn_frame.pack(side=tk.LEFT, padx=8)
        
        tk.Button(btn_frame, text="APPLY\nPARAMS", bg=self.COLOR_APPLY, fg="white", font=("", 8, "bold"),
                  command=self.update_params).pack(side=tk.LEFT, padx=2)
        tk.Button(btn_frame, text="RESET\nALL", bg=self.COLOR_RESET, fg="white", font=("", 8, "bold"),
                  command=self.reset_all).pack(side=tk.LEFT, padx=2)
        
        # Calibration button
        self.calibration_btn = tk.Button(btn_frame, text="CALIBRATE\nLEVEL", bg="#4CAF50", fg="white", font=("", 8, "bold"),
                  command=self.calibrate_level)
        self.calibration_btn.pack(side=tk.LEFT, padx=2)

        time_ctrl_frame = tk.Frame(top)
        time_ctrl_frame.pack(side=tk.LEFT, padx=5)

        crop_frame = tk.LabelFrame(time_ctrl_frame, text="CROP TIME (s)")
        crop_frame.pack(fill=tk.X)
        self.t_start = tk.Entry(crop_frame, width=6)
        self.t_start.insert(0, "0")
        self.t_start.pack(side=tk.LEFT)
        tk.Label(crop_frame, text="→").pack(side=tk.LEFT)
        self.t_end = tk.Entry(crop_frame, width=6)
        self.t_end.insert(0, "max")
        self.t_end.pack(side=tk.LEFT)

        shift_frame = tk.LabelFrame(time_ctrl_frame, text="TIME SHIFT (s)")
        shift_frame.pack(fill=tk.X, pady=2)
        tk.Entry(shift_frame, textvariable=self.time_shift_var, width=15).pack(side=tk.LEFT, padx=2)
        tk.Button(shift_frame, text="Shift", command=self.plot, bg="#CDDC39").pack(side=tk.LEFT)

        tu_frame = tk.LabelFrame(top, text="TIME UNIT")
        tu_frame.pack(side=tk.LEFT, padx=5)
        for label in TIME_UNITS:
            tk.Radiobutton(tu_frame, text=label, variable=self.time_unit_var, value=label, command=self.plot).pack(anchor=tk.W)

        fft_frame = tk.LabelFrame(top, text="FFT VIEW")
        fft_frame.pack(side=tk.LEFT, padx=8)
        for mode in ["Accel", "Gyro", "Orientation"]:
            tk.Radiobutton(fft_frame, text=mode, variable=self.fft_view_mode, value=mode, command=self.plot).pack(anchor=tk.W)
        tk.Checkbutton(fft_frame, text="FFT on raw", variable=self.fft_on_raw, command=self.plot).pack(anchor=tk.W)
        tk.Checkbutton(fft_frame, text="Use PSD (Welch)", variable=self.use_psd_mode, command=self.plot).pack(anchor=tk.W)

        tk.Button(top, text="LOAD\nCSV", bg=self.COLOR_LOAD, fg="white", font=("", 9, "bold"),
                command=self.load_csv).pack(side=tk.RIGHT, padx=5)
        tk.Button(top, text="SAVE\nFILTERED", bg="#009688", fg="white", font=("", 9, "bold"),
                command=self.save_filtered_csv).pack(side=tk.RIGHT, padx=5)
                
        tk.Button(top, text="ANALYZE\n(Dashboard)", bg=self.COLOR_ANALYZE, fg="white", font=("", 9, "bold"),
                command=self.toggle_analysis_board).pack(side=tk.RIGHT, padx=5)

        content = tk.Frame(self.parent)
        content.pack(fill=tk.BOTH, expand=True)

        self.left = tk.Frame(content, width=210)
        self.left.pack(side=tk.LEFT, fill=tk.Y)
        self.left_inner = tk.Frame(self.left)
        self.left_inner.pack(fill=tk.BOTH, expand=True)

        self.plot_frame = tk.Frame(content)
        self.plot_frame.pack(side=tk.RIGHT, fill=tk.BOTH, expand=True)

        self.fig    = plt.figure(figsize=(10, 8))
        self.canvas = FigureCanvasTkAgg(self.fig, master=self.plot_frame)
        self.toolbar = NavigationToolbar2Tk(self.canvas, self.plot_frame)
        self.canvas.get_tk_widget().pack(fill=tk.BOTH, expand=True)

    def reset_all(self):
        self.filter_order.clear()
        for btn in self.filter_buttons.values():
            btn.config(text="OFF", bg=self.COLOR_OFF, fg="black")
        
        self.t_start.delete(0, tk.END); self.t_start.insert(0, "0")
        self.t_end.delete(0, tk.END); self.t_end.insert(0, "max")
        self.time_shift_var.set("0.0")
        
        # Reset calibration offsets
        self.roll_offset = 0.0
        self.pitch_offset = 0.0
        
        for col_vars in self.line_vars.values():
            col_vars['max'].set(False)
            col_vars['min'].set(False)
            col_vars['mean'].set(False)
            
        self.plot()

    def on_crop_select(self, vmin, vmax):
        self.t_start.delete(0, tk.END)
        self.t_start.insert(0, f"{vmin:.3f}")
        self.t_end.delete(0, tk.END)
        self.t_end.insert(0, f"{vmax:.3f}")
        self.plot()

    def toggle_analysis_board(self):
        if self.filtered_df is None:
            messagebox.showwarning("Lỗi", "Vui lòng Load file CSV trước!")
            return
            
        if hasattr(self, 'analysis_win') and self.analysis_win.winfo_exists():
            self.analysis_win.focus()
            return
            
        self.analysis_win = tk.Toplevel(self.parent)
        self.analysis_win.title("Signal Analysis Dashboard - Phân Tích Dao Động")
        self.analysis_win.geometry("1100x550")
        self.analysis_win.attributes('-topmost', True) 
        
        main_frame = tk.Frame(self.analysis_win)
        main_frame.pack(fill=tk.BOTH, expand=True, padx=10, pady=10)
        
        col_acc = tk.LabelFrame(main_frame, text="1. GIA TỐC (Accelerometer)", font=("", 10, "bold"), fg="#D32F2F")
        col_gyr = tk.LabelFrame(main_frame, text="2. VẬN TỐC GÓC (Gyroscope)", font=("", 10, "bold"), fg="#388E3C")
        col_ori = tk.LabelFrame(main_frame, text="3. GÓC ĐỊNH HƯỚNG (Orientation)", font=("", 10, "bold"), fg="#1976D2")
        
        col_acc.pack(side=tk.LEFT, fill=tk.BOTH, expand=True, padx=5)
        col_gyr.pack(side=tk.LEFT, fill=tk.BOTH, expand=True, padx=5)
        col_ori.pack(side=tk.LEFT, fill=tk.BOTH, expand=True, padx=5)
        
        self.analysis_frames = {'acc': col_acc, 'gyro': col_gyr, 'ori': col_ori, 'other': col_ori}
        self.current_board_cols = None
        
        self.update_analysis_board()

    def update_analysis_board(self):
        if not hasattr(self, 'analysis_win') or not self.analysis_win.winfo_exists():
            return
            
        active_cols = [c for c in self.filtered_df.columns[1:] if self.signal_active.get(c, False)]
        
        if self.current_board_cols != active_cols:
            self._rebuild_analysis_board(active_cols)
            self.current_board_cols = active_cols
        
        for col in active_cols:
            data = self.filtered_df[col].values
            if len(data) == 0: continue
            mean_v = np.mean(data)
            max_v = np.max(data)
            min_v = np.min(data)
            amp = np.max(np.abs(data - mean_v))
            rms = np.sqrt(np.mean(data**2))
            std = np.std(data)
            pkpk = max_v - min_v
            
            self.analysis_labels[col]['amp'].config(text=f"Amp: {amp:.4f}  |  Mean: {mean_v:.4f}")
            self.analysis_labels[col]['minmax'].config(text=f"Max: {max_v:.4f}  |  Min: {min_v:.4f}")
            self.analysis_labels[col]['rms_std'].config(text=f"RMS: {rms:.4f}  |  STD: {std:.4f}")
            self.analysis_labels[col]['pkpk'].config(text=f"Peak-Peak: {pkpk:.4f}")

    def _rebuild_analysis_board(self, active_cols):
        for frame in self.analysis_frames.values():
            for w in frame.winfo_children(): w.destroy()
        
        self.analysis_labels = {}
        for col in active_cols:
            ctype = self._col_type(col)
            parent = self.analysis_frames.get(ctype, self.analysis_frames['ori'])
            
            f = tk.Frame(parent, bd=1, relief=tk.SOLID, bg="#FAFAFA")
            f.pack(fill=tk.X, padx=5, pady=5, ipadx=5, ipady=5)
            
            tk.Label(f, text=f"■ Tín hiệu: {col}", font=("", 10, "bold"), bg="#FAFAFA").pack(anchor=tk.W)
            
            lbl_amp = tk.Label(f, text="", font=("", 9, "bold"), fg="#1565C0", bg="#FAFAFA")
            lbl_amp.pack(anchor=tk.W)
            lbl_minmax = tk.Label(f, text="", bg="#FAFAFA")
            lbl_minmax.pack(anchor=tk.W)
            lbl_rms_std = tk.Label(f, text="", font=("", 9), fg="#D32F2F", bg="#FAFAFA")
            lbl_rms_std.pack(anchor=tk.W)
            lbl_pkpk = tk.Label(f, text="", font=("", 9), fg="#388E3C", bg="#FAFAFA")
            lbl_pkpk.pack(anchor=tk.W)
            
            self.analysis_labels[col] = {'amp': lbl_amp, 'minmax': lbl_minmax, 'rms_std': lbl_rms_std, 'pkpk': lbl_pkpk}
            
            cb_frame = tk.Frame(f, bg="#FAFAFA")
            cb_frame.pack(anchor=tk.W, pady=(5,0))
            
            tk.Checkbutton(cb_frame, text="Hiện Đỉnh", variable=self.line_vars[col]['max'], command=self.plot, bg="#FAFAFA").pack(side=tk.LEFT, padx=2)
            tk.Checkbutton(cb_frame, text="Hiện Đáy", variable=self.line_vars[col]['min'], command=self.plot, bg="#FAFAFA").pack(side=tk.LEFT, padx=2)
            tk.Checkbutton(cb_frame, text="Hiện Trục", variable=self.line_vars[col]['mean'], command=self.plot, bg="#FAFAFA").pack(side=tk.LEFT, padx=2)

    def update_params(self):
        try:
            for k in self.filter_params: self.filter_params[k] = float(self.param_entries[k].get())
        except ValueError as e: return messagebox.showerror("Tham số lỗi", str(e))
        self.plot()

    def toggle_filter(self, name):
        if name in self.filter_order:
            self.filter_order.remove(name); self.filter_buttons[name].config(text="OFF", bg=self.COLOR_OFF, fg="black")
        else:
            self.filter_order.append(name); self.filter_buttons[name].config(text="ON", bg=self.COLOR_ON, fg="white")
        self.plot()

    def toggle_signal(self, name):
        self.signal_active[name] = not self.signal_active[name]
        if self.signal_active[name]: self.signal_buttons[name].config(text=f"{name}: ON", bg=self.COLOR_ON, fg="white")
        else: self.signal_buttons[name].config(text=f"{name}: OFF", bg=self.COLOR_SIGNAL_OFF, fg="black")
        self.plot()

    def calibrate_level(self):
        """Tính offset từ mean của roll/pitch hiện tại"""
        if self.filtered_df is None or len(self.filtered_df) < 2:
            messagebox.showwarning("Cảnh báo", "Vui lòng tải file CSV trước!")
            return
        
        # Tìm cột roll và pitch
        roll_col = next((c for c in self.filtered_df.columns if "roll" in c.lower()), None)
        pitch_col = next((c for c in self.filtered_df.columns if "pitch" in c.lower()), None)
        
        if roll_col and pitch_col:
            self.roll_offset = float(np.mean(self.filtered_df[roll_col].values))
            self.pitch_offset = float(np.mean(self.filtered_df[pitch_col].values))
            messagebox.showinfo("Hiệu chỉnh thành công", 
                              f"Roll offset: {self.roll_offset:.4f}°\nPitch offset: {self.pitch_offset:.4f}°")
            self.plot()
        else:
            messagebox.showerror("Lỗi", "Không tìm thấy cột Roll hoặc Pitch!")

    def load_csv(self):
        path = filedialog.askopenfilename(filetypes=[("CSV files", "*.csv"), ("All files", "*.*")])
        if not path: return
        try: raw = pd.read_csv(path)
        except Exception as e: return messagebox.showerror("Lỗi đọc file", str(e))

        df = raw.copy()
        df = df.interpolate(method="linear").bfill().ffill()
        self.df = df
        self._raw_df = df.copy() 

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

        try: t_shift = float(self.time_shift_var.get())
        except: t_shift = 0.0
        t_shifted = t_raw + t_shift 

        try: t_start = float(self.t_start.get().strip())
        except ValueError: t_start = t_shifted[0]

        t_end_str = self.t_end.get().strip().lower()
        if t_end_str in ("max", ""): t_end = t_shifted[-1]
        else:
            try: t_end = float(t_end_str)
            except ValueError: t_end = t_shifted[-1]

        t_start = max(t_start, t_shifted[0])
        t_end   = min(t_end,   t_shifted[-1])
        if t_start >= t_end: t_start, t_end = t_shifted[0], t_shifted[-1]

        mask    = (t_shifted >= t_start) & (t_shifted <= t_end)
        temp_df = self.df[mask].copy()
        temp_df.iloc[:, 0] = t_shifted[mask] / t_scale 

        if len(temp_df) < 4: return

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
                # Lấy tất cả 3 trục acceleration
                acc_vals = [temp_df.iloc[:, acc_idx[i]].values for i in range(3)]
                gyr_vals = [np.radians(temp_df.iloc[:, gyr_idx[i]].values) for i in range(3)]
                
                # Áp dụng axis mapping
                ay_mapped = acc_vals[ACC_AXES['roll']]
                az_mapped = acc_vals[2]  # Z axis is always for vertical reference
                ax_mapped = acc_vals[ACC_AXES['pitch']]
                gx_mapped = gyr_vals[GYRO_AXES['roll']]
                gy_mapped = gyr_vals[GYRO_AXES['pitch']]
                
                denom = np.sqrt(ay_mapped**2 + az_mapped**2)
                denom = np.where(np.abs(denom) < 1e-9, 1e-9, denom)
                # Standard IMU formulas: when level (ax≈0, ay≈0, az≈+9.81), roll=pitch=0
                # pitch = atan2(-ax, sqrt(ay²+az²))
                # roll = atan2(ay, az)
                pitch_acc_rad = np.arctan2(-ax_mapped, denom)
                roll_acc_rad = np.arctan2(ay_mapped, az_mapped)
                pitch_rad, roll_rad = np.zeros(len(t)), np.zeros(len(t))
                pitch_rad[0], roll_rad[0] = pitch_acc_rad[0], roll_acc_rad[0]
                for i in range(1, len(t)):
                    pitch_rad[i] = (alpha * (pitch_rad[i-1] + gy_mapped[i] * dt) + (1.0 - alpha) * pitch_acc_rad[i])
                    roll_rad[i]  = (alpha * (roll_rad[i-1]  + gx_mapped[i] * dt) + (1.0 - alpha) * roll_acc_rad[i])
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
        """Tính PSD (Power Spectral Density) sử dụng Welch method"""
        n = len(data)
        if n < 20: return None
        # Tính PSD với cửa sổ Hann, overlap 50%
        frq, psd = welch(data, fs=fs, window='hann', nperseg=min(256, n//2), noverlap=None)
        if len(frq) < 3: return None
        # Tìm tần số có năng lượng cao nhất
        idx = int(np.argmax(psd[1:])) + 1
        dom_freq = frq[idx]
        return frq, psd, dom_freq

    def _plot_signal_with_lines(self, ax, t, data, col):
        """Hàm vẽ tín hiệu và hiển thị Text kèm đường gióng Max/Min/Mean"""
        lines = ax.plot(t, data, label=col, linewidth=0.9)
        c = lines[0].get_color() 
        
        max_val = np.max(data)
        min_val = np.min(data)
        mean_val = np.mean(data)
        
        # Chọn vị trí X để đặt Text (bám sát lề phải của đồ thị)
        x_text = t[-1] if len(t) > 0 else 0

        # Cấu hình hộp nền mờ phía sau chữ để không bị nhiễu bởi đường biểu đồ
        bbox_props = dict(boxstyle="round,pad=0.2", fc="white", ec=c, alpha=0.7, lw=0.5)

        if self.line_vars[col]['max'].get(): 
            ax.axhline(max_val, color=c, linestyle=':', alpha=0.8, linewidth=1.5)
            ax.text(x_text, max_val, f" {max_val:.3f}", color=c, fontsize=8, fontweight='bold', 
                    ha='right', va='bottom', bbox=bbox_props)
            
        if self.line_vars[col]['min'].get(): 
            ax.axhline(min_val, color=c, linestyle=':', alpha=0.8, linewidth=1.5)
            ax.text(x_text, min_val, f" {min_val:.3f}", color=c, fontsize=8, fontweight='bold', 
                    ha='right', va='top', bbox=bbox_props)
            
        if self.line_vars[col]['mean'].get(): 
            ax.axhline(mean_val, color=c, linestyle='--', alpha=0.9, linewidth=1.5)
            ax.text(x_text, mean_val, f" {mean_val:.3f}", color=c, fontsize=8, fontweight='bold', 
                    ha='right', va='bottom', bbox=bbox_props)

    def plot(self):
        if self.df is None: return
        self.apply_filters()
        if self.filtered_df is None or len(self.filtered_df) < 2: return

        self.fig.clf()
        ax1 = self.fig.add_subplot(221)
        ax2 = self.fig.add_subplot(222)
        ax3 = self.fig.add_subplot(223)
        ax4 = self.fig.add_subplot(224)

        t        = self.filtered_df.iloc[:, 0].values * TIME_UNITS[self.time_unit_var.get()]
        fs       = self._fs_last
        fft_mode = self.fft_view_mode.get()

        raw_fft_df = None
        if self.fft_on_raw.get() and self._raw_df is not None:
            t_raw_all = self._raw_df.iloc[:, 0].values * TIME_UNITS[self.time_unit_var.get()]
            try: t_s = float(self.time_shift_var.get())
            except: t_s = 0.0
            t_raw_all += t_s
            raw_mask  = (t_raw_all >= t[0]) & (t_raw_all <= t[-1])
            raw_fft_df = self._raw_df[raw_mask]

        for col in self.filtered_df.columns[1:]:
            if not self.signal_active.get(col, False): continue
            data     = self.filtered_df[col].values
            col_type = self._col_type(col)

            # Thay hàm plot cơ bản thành hàm vẽ kèm Text Annotation
            if col_type == "acc": self._plot_signal_with_lines(ax1, t, data, col)
            elif col_type == "gyro": self._plot_signal_with_lines(ax2, t, data, col)
            else: self._plot_signal_with_lines(ax3, t, data, col)

            do_fft = ((fft_mode == "Accel" and col_type == "acc") or (fft_mode == "Gyro" and col_type == "gyro") or (fft_mode == "Orientation" and col_type == "ori"))
            if do_fft:
                if self.use_psd_mode.get():  # Use PSD (Welch) instead of FFT
                    if self.fft_on_raw.get() and raw_fft_df is not None and col in raw_fft_df.columns:
                        result = self._compute_psd(raw_fft_df[col].values.astype(float), fs)
                        suffix = " [raw]"
                    else:
                        result = self._compute_psd(data, fs)
                        suffix = ""
                else:  # Use FFT
                    if self.fft_on_raw.get() and raw_fft_df is not None and col in raw_fft_df.columns:
                        result = self._compute_fft(raw_fft_df[col].values.astype(float), fs)
                        suffix = " [raw]"
                    else:
                        result = self._compute_fft(data, fs)
                        suffix = ""
                if result is not None:
                    ax4.plot(result[0], result[1], label=f"{col}{suffix} ({result[2]:.2f} Hz)", linewidth=0.9)

        ax1.set_title("Gia tốc tuyến tính (KÉO CHUỘT ĐỂ CẮT)"); ax1.set_ylabel("m/s²"); ax1.set_xlabel("Thời gian (s)")
        ax2.set_title("Vận tốc góc (KÉO CHUỘT ĐỂ CẮT)"); ax2.set_ylabel("deg/s"); ax2.set_xlabel("Thời gian (s)")
        ax3.set_title("Góc định hướng (KÉO CHUỘT ĐỂ CẮT)"); ax3.set_ylabel("deg"); ax3.set_xlabel("Thời gian (s)")
        analysis_mode = "PSD (Welch)" if self.use_psd_mode.get() else "FFT"
        ax4.set_title(f"Phân tích {analysis_mode} ({fft_mode}){' — raw' if self.fft_on_raw.get() else ''}")
        ax4.set_ylabel("PSD (Power/Hz)" if self.use_psd_mode.get() else "Biên độ"); ax4.set_xlabel("Hz")

        for ax in [ax1, ax2, ax3, ax4]:
            ax.legend(fontsize=7); ax.grid(True, linestyle="--", alpha=0.4)
        ax4.set_xlim(0, min(30.0, fs / 2.0))

        self.fig.tight_layout()
        self.canvas.draw()
        
        self.span_selectors.clear() 
        span_props = dict(alpha=0.2, facecolor='red')
        span1 = SpanSelector(ax1, self.on_crop_select, 'horizontal', useblit=True, props=span_props)
        span2 = SpanSelector(ax2, self.on_crop_select, 'horizontal', useblit=True, props=span_props)
        span3 = SpanSelector(ax3, self.on_crop_select, 'horizontal', useblit=True, props=span_props)
        self.span_selectors.extend([span1, span2, span3])

        self.update_analysis_board()

# ==============================================================================
# TAB 2: MCA Evaluator Tool (ĐÃ NÂNG CẤP)
# ==============================================================================
class MCAEvaluatorTab:
    def __init__(self, parent_frame):
        self.parent = parent_frame
        self.sim_path = None
        self.imu_path = None
        # Xóa hardcode col_order để tránh lỗi "râu ông nọ cắm cằm bà kia"
        
        # Biến trạng thái lưu trữ độ dịch thời gian thủ công
        self.manual_shift_sim = 0.0
        self.manual_shift_imu = 0.0
        
        self._build_ui()

    def _build_ui(self):
        top_mca = tk.Frame(self.parent, bg="#f5f5f5")
        top_mca.pack(fill=tk.X, padx=10, pady=10)

        ctrl_frame = tk.Frame(top_mca, bg="#f5f5f5")
        ctrl_frame.pack(side=tk.LEFT, fill=tk.Y)
        
        tk.Button(ctrl_frame, text="1. Chọn File MÔ PHỎNG", width=25, bg="#2196F3", fg="white", command=self.load_sim).pack(pady=2)
        self.lbl_sim = tk.Label(ctrl_frame, text="Chưa nạp file...", bg="#f5f5f5", fg="grey"); self.lbl_sim.pack(pady=2)

        tk.Button(ctrl_frame, text="2. Chọn File IMU (Thực tế)", width=25, bg="#00BCD4", fg="white", command=self.load_imu).pack(pady=2)
        self.lbl_imu = tk.Label(ctrl_frame, text="Chưa nạp file...", bg="#f5f5f5", fg="grey"); self.lbl_imu.pack(pady=2)

        # ---------------- KHUNG CẤU HÌNH BỘ LỌC ----------------
        p_frame = tk.Frame(ctrl_frame, bg="#f5f5f5")
        p_frame.pack(pady=5, fill=tk.X)
        
        tk.Label(p_frame, text="Tần số mẫu (Hz):", bg="#f5f5f5").grid(row=0, column=0, sticky=tk.W)
        self.ent_fs = tk.Entry(p_frame, width=6)
        self.ent_fs.insert(0, "100")
        self.ent_fs.grid(row=0, column=1, padx=5, pady=2)

        tk.Label(p_frame, text="Low-pass Lọc IMU (Hz):", bg="#f5f5f5").grid(row=1, column=0, sticky=tk.W)
        self.ent_mca_lp = tk.Entry(p_frame, width=6)
        self.ent_mca_lp.insert(0, "5.0")
        self.ent_mca_lp.grid(row=1, column=1, padx=5, pady=2)

        # ---------------- KHUNG ĐỒNG BỘ THỜI GIAN ----------------
        self.use_auto_sync = tk.BooleanVar(value=True)
        tk.Checkbutton(ctrl_frame, text="Tự động đồng bộ trễ (Cross-Correlation)", 
                       variable=self.use_auto_sync, bg="#f5f5f5", fg="#D32F2F").pack(anchor=tk.W, pady=2)

        shift_frame = tk.LabelFrame(ctrl_frame, text="Dịch thời gian thủ công (Manual Shift)", bg="#f5f5f5")
        shift_frame.pack(fill=tk.X, pady=5, padx=2, ipadx=2, ipady=2)

        self.shift_target = tk.StringVar(value="sim")
        r_frame = tk.Frame(shift_frame, bg="#f5f5f5")
        r_frame.pack(anchor=tk.W)
        tk.Radiobutton(r_frame, text="Mô phỏng", variable=self.shift_target, value="sim", bg="#f5f5f5").pack(side=tk.LEFT)
        tk.Radiobutton(r_frame, text="IMU", variable=self.shift_target, value="imu", bg="#f5f5f5").pack(side=tk.LEFT)

        step_frame = tk.Frame(shift_frame, bg="#f5f5f5")
        step_frame.pack(pady=2)
        tk.Label(step_frame, text="Bước dịch (s):", bg="#f5f5f5").pack(side=tk.LEFT)
        self.ent_step = tk.Entry(step_frame, width=6)
        self.ent_step.insert(0, "0.1")
        self.ent_step.pack(side=tk.LEFT, padx=5)
        
        btn_frame = tk.Frame(shift_frame, bg="#f5f5f5")
        btn_frame.pack(pady=2)
        tk.Button(btn_frame, text="<< Trái", width=8, bg="#E0E0E0", command=lambda: self.apply_manual_shift(-1)).pack(side=tk.LEFT, padx=5)
        tk.Button(btn_frame, text="Phải >>", width=8, bg="#E0E0E0", command=lambda: self.apply_manual_shift(1)).pack(side=tk.LEFT, padx=5)
        
        tk.Button(shift_frame, text="Reset Shift", font=("", 8), command=self.reset_shift).pack(pady=2)

        tk.Button(ctrl_frame, text="CHẠY ĐÁNH GIÁ MCA", width=25, bg="#FF5722", fg="white", font=("", 10, "bold"), command=self.run_evaluation).pack(pady=10)

        # ---------------- KHUNG HIỂN THỊ KẾT QUẢ ----------------
        res_frame = tk.LabelFrame(top_mca, text="Kết quả đo lường", bg="white")
        res_frame.pack(side=tk.LEFT, fill=tk.BOTH, expand=True, padx=20)
        
        self.txt_result = tk.Text(res_frame, height=7, bg="#FAFAFA", font=("Consolas", 11))
        self.txt_result.pack(fill=tk.BOTH, expand=True, padx=5, pady=5)
        self.txt_result.insert(tk.END, "Vui lòng nạp 2 file CSV và bấm 'Chạy Đánh Giá'...\n"); self.txt_result.config(state=tk.DISABLED)

        plot_frame_mca = tk.Frame(self.parent)
        plot_frame_mca.pack(fill=tk.BOTH, expand=True)

        self.fig_mca = plt.figure(figsize=(10, 5))
        self.canvas_mca = FigureCanvasTkAgg(self.fig_mca, master=plot_frame_mca)
        self.toolbar_mca = NavigationToolbar2Tk(self.canvas_mca, plot_frame_mca)
        self.canvas_mca.get_tk_widget().pack(fill=tk.BOTH, expand=True)

        # --- THÊM 2 DÒNG NÀY ---
        self.canvas_mca.mpl_connect('button_press_event', self.on_plot_click)
        self.axes_data_map = {}

    def load_sim(self):
        path = filedialog.askopenfilename(title="Chọn file Mô phỏng", filetypes=[("CSV", "*.csv")])
        if path: self.sim_path = path; self.lbl_sim.config(text=path.split('/')[-1], fg="green")

    def load_imu(self):
        path = filedialog.askopenfilename(title="Chọn file IMU", filetypes=[("CSV", "*.csv")])
        if path: self.imu_path = path; self.lbl_imu.config(text=path.split('/')[-1], fg="green")

    def reset_shift(self):
        self.manual_shift_sim = 0.0
        self.manual_shift_imu = 0.0
        self.use_auto_sync.set(True) # Bật lại auto khi reset
        self.run_evaluation()

    def apply_manual_shift(self, direction):
        if not self.sim_path or not self.imu_path: return
        try: step = float(self.ent_step.get())
        except ValueError: step = 0.1
        
        if self.shift_target.get() == "sim":
            self.manual_shift_sim += direction * step
        else:
            self.manual_shift_imu += direction * step
            
        # Khi user cố tình bấm shift tay, tắt ngay Auto-Sync để bảo vệ kết quả shift
        self.use_auto_sync.set(False) 
        self.run_evaluation()

    def mca_process_logic(self, sim_csv, imu_csv, target_fs, cutoff_freq):
        dt = 1.0 / target_fs

        # 1. Đọc file
        df_sim = pd.read_csv(sim_csv)
        df_imu = pd.read_csv(imu_csv)

        # 2. Chuẩn hóa tên cột: Chuyển hết về chữ thường và xóa khoảng trắng thừa
        df_sim.columns = df_sim.columns.astype(str).str.strip().str.lower()
        df_imu.columns = df_imu.columns.astype(str).str.strip().str.lower()

        # 3. Quét an toàn: Nếu vẫn không có chữ 'time', ép cột ĐẦU TIÊN thành cột 'time'
        if 'time' not in df_sim.columns:
            df_sim.rename(columns={df_sim.columns[0]: 'time'}, inplace=True)
        if 'time' not in df_imu.columns:
            df_imu.rename(columns={df_imu.columns[0]: 'time'}, inplace=True)

        # 4. Sắp xếp lại theo trình tự thời gian
        df_sim = df_sim.sort_values(by='time')
        df_imu = df_imu.sort_values(by='time')

        # 5. Đưa cả 2 dữ liệu về chung mốc khởi điểm 0s để chống crash
        df_sim['time'] = df_sim['time'] - df_sim['time'].iloc[0]
        df_imu['time'] = df_imu['time'] - df_imu['time'].iloc[0]

        # 6. Áp dụng các thay đổi dịch thời gian thủ công từ giao diện
        df_sim['time'] += self.manual_shift_sim
        df_imu['time'] += self.manual_shift_imu

        t_start = max(df_sim['time'].iloc[0], df_imu['time'].iloc[0])
        t_end = min(df_sim['time'].iloc[-1], df_imu['time'].iloc[-1])

        if t_start >= t_end:
            raise ValueError(f"Khoảng thời gian không giao nhau! Hãy kiểm tra lại thao tác Shift.\n(Bắt đầu: {t_start:.2f}s, Kết thúc: {t_end:.2f}s)")

        common_time = np.arange(t_start, t_end, dt)

        # TÌM CỘT CHUNG (Giữ nguyên phần còn lại của bạn từ đây trở đi...)
        sim_cols = set(df_sim.columns) - {'time'}
        imu_cols = set(df_imu.columns) - {'time'}
        signals = list(sim_cols.intersection(imu_cols))
        if not signals:
            raise ValueError("Không tìm thấy tên cột tín hiệu nào khớp nhau giữa 2 file CSV!")

        results = []

        # Cấu hình Butterworth từ UI
        nyq = 0.5 * target_fs
        if 0 < cutoff_freq < nyq:
            b, a = butter(2, cutoff_freq / nyq, btype='low', analog=False)
        else:
            b, a = None, None # Bỏ qua lọc nếu nhập sai
        
        for sig in signals:
            sim_sig = np.interp(common_time, df_sim['time'], df_sim[sig])
            imu_sig = np.interp(common_time, df_imu['time'], df_imu[sig])
            
            if (sig.startswith('acc') or sig.startswith('gyro')) and (b is not None):
                try: imu_filtered = filtfilt(b, a, imu_sig)
                except: imu_filtered = imu_sig
            else:
                imu_filtered = imu_sig 
            
            # ===== TÍNH DELAY =====
            if self.use_auto_sync.get():
                s1 = sim_sig - np.mean(sim_sig)
                s2 = imu_filtered - np.mean(imu_filtered)
                # Tính tương quan nếu dữ liệu không phải đường thẳng
                if np.std(s1) > 1e-6 and np.std(s2) > 1e-6:
                    correlation = correlate(s2, s1, mode='full')
                    lags = np.arange(-len(s1) + 1, len(s1))
                    delay_seconds = lags[np.argmax(correlation)] * dt
                else:
                    delay_seconds = 0.0
            else:
                delay_seconds = 0.0 # Nếu tắt Auto, không bù thêm độ trễ nữa
            
            # ===== ALIGN DỮ LIỆU =====
            shift = int(abs(delay_seconds) / dt)
            if shift > 0:
                if delay_seconds > 0:
                    sim_aligned = sim_sig[shift:]
                    imu_aligned = imu_filtered[:-shift]
                else:
                    sim_aligned = sim_sig[:-shift]
                    imu_aligned = imu_filtered[shift:]
            else:
                sim_aligned = sim_sig
                imu_aligned = imu_filtered
            
            # ===== TÍNH RMSE ĐÃ KHẮC PHỤC CHU KỲ GÓC =====
            if any(x in sig.lower() for x in ['roll', 'pitch', 'yaw']):
                # Xử lý wrap-around 360 độ cho các góc
                diff = ((sim_aligned - imu_aligned + 180) % 360) - 180
                rmse = np.sqrt(np.mean(diff**2))
            else:
                rmse = np.sqrt(mean_squared_error(sim_aligned, imu_aligned))
            
            results.append({
                'signal': sig,
                'delay_ms': (delay_seconds + (self.manual_shift_sim - self.manual_shift_imu)) * 1000,
                'rmse': rmse,
                'common_time': common_time,
                'sim_data': sim_sig,
                'imu_data': imu_filtered
            })
        
        # Sắp xếp lại thứ tự hiển thị: acc -> gyro -> roll -> pitch -> yaw
        def get_sort_key(x):
            sig = x['signal'].lower()
            if 'acc' in sig: return (1, sig)
            if 'gyro' in sig: return (2, sig)
            if 'roll' in sig: return (3, sig)
            if 'pitch' in sig: return (4, sig)
            if 'yaw' in sig: return (5, sig)
            return (6, sig)

        results.sort(key=get_sort_key)
        return results

    def run_evaluation(self):
        if not self.sim_path or not self.imu_path: 
            return messagebox.showwarning("Thiếu Dữ Liệu", "Vui lòng chọn đủ 2 file Mô phỏng và IMU.")
        try:
            fs = int(self.ent_fs.get())
            try: lp_cut = float(self.ent_mca_lp.get())
            except: lp_cut = 5.0

            results = self.mca_process_logic(self.sim_path, self.imu_path, fs, lp_cut)

            self.txt_result.config(state=tk.NORMAL)
            self.txt_result.delete(1.0, tk.END)
            
            header = f"{'Signal':<12} {'Tổng trễ (ms)':<15} {'RMSE':<12}\n"
            separator = "-" * 40 + "\n"
            sync_mode = "[AUTO-SYNC]" if self.use_auto_sync.get() else f"[MANUAL SHIFT: Sim {self.manual_shift_sim:+.2f}s | IMU {self.manual_shift_imu:+.2f}s]"
            res_text = f"ĐÁNH GIÁ MCA - {sync_mode}\n" + separator + header + separator
            
            for result in results:
                res_text += f"{result['signal']:<12} {result['delay_ms']:>12.2f}  {result['rmse']:>15.4f}\n"
            
            self.txt_result.insert(tk.END, res_text)
            self.txt_result.config(state=tk.DISABLED)

            self.fig_mca.clf()
            self.axes_data_map.clear()
            
            # Tính toán lưới vẽ (grid) tự động dựa trên số lượng tín hiệu khớp nhau
            n_plots = len(results)
            cols = 3
            rows = (n_plots + cols - 1) // cols
            
            for idx, result in enumerate(results, 1):
                ax = self.fig_mca.add_subplot(rows, cols, idx)
                self.axes_data_map[ax] = result

                ax.plot(result['common_time'], result['sim_data'], label='Mô phỏng', color='blue', linewidth=1)
                ax.plot(result['common_time'], result['imu_data'], label='IMU', color='red', linestyle='--', linewidth=1, alpha=0.8)
                ax.set_title(f"{result['signal']} (RMSE: {result['rmse']: .2f})", fontsize=9)
                if idx > n_plots - cols: ax.set_xlabel("Thời gian (s)", fontsize=8)
                ax.grid(True, linestyle=":", alpha=0.5)
                ax.tick_params(labelsize=7)
                if idx == 1: ax.legend(fontsize=7, loc='upper right')
            
            self.fig_mca.tight_layout()
            self.canvas_mca.draw()

        except Exception as e: 
            messagebox.showerror("Lỗi Phân Tích", str(e))

    def on_plot_click(self, event):
        """Bắt sự kiện click chuột trên figure mca"""
        if event.inaxes is not None and event.inaxes in getattr(self, 'axes_data_map', {}):
            self.show_enlarged_plot(self.axes_data_map[event.inaxes])

    def show_enlarged_plot(self, result_data):
        """Mở cửa sổ mới hiển thị đồ thị phóng to"""
        top = tk.Toplevel(self.parent)
        top.title(f"Chi tiết tín hiệu: {result_data['signal']}")
        top.geometry("900x600")
        
        fig = plt.figure(figsize=(9, 6))
        canvas = FigureCanvasTkAgg(fig, master=top)
        toolbar = NavigationToolbar2Tk(canvas, top)
        canvas.get_tk_widget().pack(fill=tk.BOTH, expand=True)
        
        ax = fig.add_subplot(111)
        ax.plot(result_data['common_time'], result_data['sim_data'], label='Mô phỏng', color='blue', linewidth=1.5)
        ax.plot(result_data['common_time'], result_data['imu_data'], label='IMU', color='red', linestyle='--', linewidth=1.5, alpha=0.8)
        
        ax.set_title(f"Chi tiết {result_data['signal']} (RMSE: {result_data['rmse']:.4f})", fontsize=12, fontweight='bold')
        ax.set_xlabel("Thời gian (s)", fontsize=10)
        ax.set_ylabel("Giá trị (Biên độ)", fontsize=10)
        ax.grid(True, linestyle=":", alpha=0.7)
        ax.legend(fontsize=10, loc='upper right')
        
        fig.tight_layout()
        canvas.draw()

# ==============================================================================
# MAIN LAUNCHER
# ==============================================================================
if __name__ == "__main__":
    root = tk.Tk()
    root.title("IMU & MCA Advanced Analysis Studio")
    root.geometry("1500x920")

    notebook = ttk.Notebook(root)
    notebook.pack(fill=tk.BOTH, expand=True)

    tab_imu = tk.Frame(notebook)
    tab_mca = tk.Frame(notebook)

    notebook.add(tab_imu, text=" 📊 IMU Analysis Tool ")
    notebook.add(tab_mca, text=" 🎯 MCA Evaluator ")

    app_imu = IMUAnalysisTab(tab_imu)
    app_mca = MCAEvaluatorTab(tab_mca)

    root.mainloop()