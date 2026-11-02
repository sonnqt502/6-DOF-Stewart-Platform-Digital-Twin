"""
Dashboard_Stewart3.py
Chuyển đổi từ MATLAB Dashboard_Stewart3.m sang Python
Yêu cầu: pip install PyQt5 matplotlib numpy scipy
"""

import sys
import os
import re
import json
import numpy as np
from copy import deepcopy

from PyQt5.QtWidgets import (
    QApplication, QMainWindow, QWidget, QLabel, QLineEdit,
    QPushButton, QComboBox, QGroupBox, QFileDialog, QMessageBox,
    QProgressDialog, QHBoxLayout, QVBoxLayout, QGridLayout,
    QDoubleSpinBox, QSizePolicy
)
from PyQt5.QtCore import Qt, QThread, pyqtSignal
from PyQt5.QtGui import QFont, QColor

import matplotlib
matplotlib.use('Qt5Agg')
from matplotlib.backends.backend_qt5agg import FigureCanvasQTAgg as FigureCanvas
from matplotlib.figure import Figure
import matplotlib.pyplot as plt
from mpl_toolkits.mplot3d import Axes3D
from mpl_toolkits.mplot3d.art3d import Poly3DCollection


# =====================================================================
# Worker Thread: chạy animation không block GUI
# =====================================================================
class SimWorker(QThread):
    update_signal = pyqtSignal(int)   # phát index hiện tại
    finished_signal = pyqtSignal()

    def __init__(self, n_steps, step):
        super().__init__()
        self._n = n_steps
        self._step = step
        self._playing = True
        self._paused = False

    def run(self):
        import time
        for i in range(0, self._n, self._step):
            if not self._playing:
                break
            while self._paused:
                time.sleep(0.05)
                if not self._playing:
                    break
            if not self._playing:
                break
            self.update_signal.emit(i)
            time.sleep(0.02)
        self.finished_signal.emit()

    def pause(self):
        self._paused = not self._paused

    def stop(self):
        self._playing = False
        self._paused = False


# =====================================================================
# Lớp canvas Matplotlib 3D nhúng vào PyQt5
# =====================================================================
class Canvas3D(FigureCanvas):
    def __init__(self, parent=None):
        self.fig = Figure(figsize=(8, 5.8), facecolor='white')
        self.ax = self.fig.add_subplot(111, projection='3d')
        super().__init__(self.fig)
        self.setParent(parent)
        self._setup_axes()

    def _setup_axes(self):
        ax = self.ax
        ax.set_title('Digital Twin: Realistic Stewart Platform Kinematics')
        ax.set_xlabel('X (mm)'); ax.set_ylabel('Y (mm)'); ax.set_zlabel('Z (mm)')
        ax.set_xlim(-800, 800); ax.set_ylim(-800, 800); ax.set_zlim(-1700, 800)
        ax.invert_zaxis(); ax.invert_yaxis()
        ax.grid(True)


# =====================================================================
# Lớp cửa sổ chính
# =====================================================================
class StewartDashboard(QMainWindow):

    def __init__(self):
        super().__init__()
        self.setWindowTitle('HỆ THỐNG ĐIỀU KHIỂN & MÔ PHỎNG STEWART PLATFORM')
        self.resize(1200, 750)

        # --- Biến dùng chung ---
        self.A_mat = None
        self.B_mat = None
        self.gamma_ang = None
        self.L1_val = 150.0
        self.L2_val = 747.0

        self.T_out = None
        self.Xp_out = self.Yp_out = self.Zp_out = None
        self.Xv_out = self.Yv_out = self.Zv_out = None
        self.Xh_out = self.Yh_out = self.Zh_out = None
        self.R_out = self.P_out = self.Yw_out = None
        self.Ax_out = self.Ay_out = self.Az_out = None
        self.Wx_out = self.Wy_out = self.Wz_out = None
        self.is_Validated = False

        self.is_Playing = False
        self.is_Paused = False
        self._worker = None

        self._build_ui()

    # ------------------------------------------------------------------
    # XÂY DỰNG GIAO DIỆN
    # ------------------------------------------------------------------
    def _build_ui(self):
        central = QWidget()
        self.setCentralWidget(central)
        main_layout = QHBoxLayout(central)
        main_layout.setContentsMargins(6, 6, 6, 6)

        # === CỘT TRÁI ===
        left_col = QVBoxLayout()
        left_col.setSpacing(6)
        main_layout.addLayout(left_col)

        # Tiêu đề
        title = QLabel('TRUNG TÂM ĐIỀU KHIỂN & GIÁM SÁT STEWART PLATFORM')
        title.setAlignment(Qt.AlignCenter)
        font = QFont(); font.setBold(True); font.setPointSize(12)
        title.setFont(font)
        title.setStyleSheet('color: rgb(162, 20, 47);')

        # === PANEL 1: CẤU HÌNH CƠ KHÍ ===
        pnl_mech = QGroupBox('1. Thông số Cơ khí')
        pnl_mech.setFixedWidth(320)
        g = QGridLayout(pnl_mech)

        def dspin(val, dec=3):
            w = QDoubleSpinBox()
            w.setDecimals(dec); w.setRange(-99999, 99999); w.setValue(val)
            return w

        g.addWidget(QLabel('r_a (Đế):'), 0, 0)
        self.ed_ra = dspin(589.66)
        g.addWidget(self.ed_ra, 0, 1)
        g.addWidget(QLabel('r_b (Bàn):'), 0, 2)
        self.ed_rb = dspin(429.566)
        g.addWidget(self.ed_rb, 0, 3)

        g.addWidget(QLabel('L1 (Tay):'), 1, 0)
        self.ed_l1 = dspin(150.0)
        g.addWidget(self.ed_l1, 1, 1)
        g.addWidget(QLabel('L2 (Cần):'), 1, 2)
        self.ed_l2 = dspin(747.0)
        g.addWidget(self.ed_l2, 1, 3)

        g.addWidget(QLabel('alpha_1:'), 2, 0)
        self.ed_a1 = dspin(19.45)
        g.addWidget(self.ed_a1, 2, 1)
        g.addWidget(QLabel('delta_a:'), 2, 2)
        self.ed_da = dspin(38.9)
        g.addWidget(self.ed_da, 2, 3)

        g.addWidget(QLabel('beta_1:'), 3, 0)
        self.ed_b1 = dspin(53.32)
        g.addWidget(self.ed_b1, 3, 1)
        g.addWidget(QLabel('delta_b:'), 3, 2)
        self.ed_db = dspin(13.37)
        g.addWidget(self.ed_db, 3, 3)

        lbl_head = QLabel('Đầu người (X, Y, Z):')
        lbl_head.setStyleSheet('color: rgb(126, 47, 142); font-weight: bold;')
        g.addWidget(lbl_head, 4, 0, 1, 2)
        self.ed_headX = dspin(0.0)
        self.ed_headY = dspin(0.0)
        self.ed_headZ = dspin(-762.0)
        g.addWidget(self.ed_headX, 4, 1)
        g.addWidget(self.ed_headY, 4, 2)
        g.addWidget(self.ed_headZ, 4, 3)

        btn_save = QPushButton('LƯU FILE')
        btn_save.setStyleSheet('background-color: #EDB120; font-weight: bold;')
        btn_save.clicked.connect(self.saveConfig)
        btn_load = QPushButton('TẢI FILE')
        btn_load.setStyleSheet('background-color: #77AC30; color: white; font-weight: bold;')
        btn_load.clicked.connect(self.loadConfig)
        g.addWidget(btn_save, 5, 0, 1, 2)
        g.addWidget(btn_load, 5, 2, 1, 2)

        self.btn_config = QPushButton('CẬP NHẬT CẤU HÌNH')
        self.btn_config.setStyleSheet('background-color: #0072BD; color: white; font-weight: bold;')
        self.btn_config.clicked.connect(self.calcGeometry)
        g.addWidget(self.btn_config, 6, 0, 1, 4)

        self.lbl_status = QLabel('Chưa nạp thông số!')
        self.lbl_status.setStyleSheet('color: red;')
        g.addWidget(self.lbl_status, 7, 0, 1, 4)

        # === PANEL 2: ĐIỀU KHIỂN ===
        pnl_ctrl = QGroupBox('2. Thiết lập Quỹ đạo & Xuất file')
        pnl_ctrl.setFixedWidth(320)
        v = QVBoxLayout(pnl_ctrl)

        v.addWidget(QLabel('Loại Quỹ Đạo:'))
        self.dd_traj = QComboBox()
        self.dd_traj.addItems([
            '[1D] Tịnh tiến Z (Heave)',
            '[1D] Quay Pitch (Gật gù)',
            '[2D] Đường tròn XY',
            '[3D] Cua chữ S (6 DOF)'
        ])
        v.addWidget(self.dd_traj)

        row_piv = QHBoxLayout()
        row_piv.addWidget(QLabel('Tâm Sinh:'))
        self.dd_pivot = QComboBox()
        self.dd_pivot.addItems(['Đỉnh Đầu Người Lái', 'Tâm Bàn Máy', 'Tọa Độ Bất Kỳ'])
        row_piv.addWidget(self.dd_pivot)
        row_piv.addWidget(QLabel('Home Z:'))
        self.ed_homez = dspin(0.0)
        row_piv.addWidget(self.ed_homez)
        v.addLayout(row_piv)

        row_pxyz = QHBoxLayout()
        lbl_p = QLabel('Pivot(X,Y,Z):')
        lbl_p.setStyleSheet('color: #D95319; font-weight: bold;')
        row_pxyz.addWidget(lbl_p)
        self.ed_px = dspin(0.0); self.ed_py = dspin(0.0); self.ed_pz = dspin(200.0)
        row_pxyz.addWidget(self.ed_px); row_pxyz.addWidget(self.ed_py); row_pxyz.addWidget(self.ed_pz)
        v.addLayout(row_pxyz)

        row_tf = QHBoxLayout()
        row_tf.addWidget(QLabel('T.Gian(s):'))
        self.ed_time = dspin(10.0, 1)
        row_tf.addWidget(self.ed_time)
        row_tf.addWidget(QLabel('Tần số(Hz):'))
        self.ed_freq = dspin(0.2)
        row_tf.addWidget(self.ed_freq)
        v.addLayout(row_tf)

        row_amp = QHBoxLayout()
        row_amp.addWidget(QLabel('Biên Độ mm:'))
        self.ed_amp_lin = dspin(50.0)
        row_amp.addWidget(self.ed_amp_lin)
        row_amp.addWidget(QLabel('Biên Độ °:'))
        self.ed_amp_ang = dspin(8.0)
        row_amp.addWidget(self.ed_amp_ang)
        v.addLayout(row_amp)

        row_file = QHBoxLayout()
        row_file.addWidget(QLabel('Import:'))
        self.lbl_file = QLabel('Chưa chọn file')
        self.lbl_file.setStyleSheet('color: gray;')
        row_file.addWidget(self.lbl_file)
        btn_browse = QPushButton('Browse')
        btn_browse.clicked.connect(self.browseFile)
        row_file.addWidget(btn_browse)
        v.addLayout(row_file)

        row_itype = QHBoxLayout()
        row_itype.addWidget(QLabel('Đối tượng trong file:'))
        self.dd_import_type = QComboBox()
        self.dd_import_type.addItems(['Bàn máy (Platform)', 'Đầu người (Head)', 'Tâm quay Pivot'])
        row_itype.addWidget(self.dd_import_type)
        v.addLayout(row_itype)

        btn_run = QPushButton('1. KIỂM ĐỊNH & CHẠY MÔ PHỎNG')
        btn_run.setStyleSheet('background-color: #77AC30; color: white; font-size: 13px; font-weight: bold; padding: 6px;')
        btn_run.clicked.connect(self.runSystem)
        v.addWidget(btn_run)

        row_exp = QHBoxLayout()
        self.dd_export = QComboBox()
        self.dd_export.addItems([
            'Bàn máy: 15 tham số (~M)',
            'Bàn máy: 7 tham số (~M)',
            'Đầu người: 15 tham số (~M)',
            'Đầu người: 7 tham số (~M)',
            'Tâm quay Pivot: 15 tham số (~M)',
            'Tâm quay Pivot: 7 tham số (~M)',
        ])
        row_exp.addWidget(self.dd_export)
        btn_export = QPushButton('2. 💾 XUẤT FILE')
        btn_export.setStyleSheet('background-color: #D95319; color: white; font-weight: bold;')
        btn_export.clicked.connect(self.exportData)
        row_exp.addWidget(btn_export)
        v.addLayout(row_exp)

        btn_plot = QPushButton('📈 VẼ ĐỒ THỊ 15 THAM SỐ')
        btn_plot.setStyleSheet('background-color: #33 99CC; color: white; font-weight: bold;')
        btn_plot.setStyleSheet('background-color: #3399CC; color: white; font-weight: bold;')
        btn_plot.clicked.connect(self.plot15Params)
        v.addWidget(btn_plot)

        # === Panel GIÁM SÁT ===
        pnl_monitor = QGroupBox('GIÁM SÁT TỌA ĐỘ HIỆN TẠI (BÀN MÁY)')
        mon_layout = QHBoxLayout(pnl_monitor)

        self.lbl_t  = QLabel('Time: 0.00 s')
        self.lbl_t.setStyleSheet('color: blue; font-size: 16px; font-weight: bold;')
        self.lbl_x  = QLabel('X: 0.0')
        self.lbl_y  = QLabel('Y: 0.0')
        self.lbl_z  = QLabel('Z: 795.4')
        self.lbl_r  = QLabel('Roll: 0.0°')
        self.lbl_p  = QLabel('Pitch: 0.0°')
        self.lbl_yw = QLabel('Yaw: 0.0°')
        for lbl in [self.lbl_x, self.lbl_y, self.lbl_z, self.lbl_r, self.lbl_p, self.lbl_yw]:
            lbl.setStyleSheet('font-size: 13px; font-weight: bold;')

        info_grid = QGridLayout()
        info_grid.addWidget(self.lbl_t,  0, 0, 2, 1)
        info_grid.addWidget(self.lbl_x,  0, 1); info_grid.addWidget(self.lbl_y,  0, 2); info_grid.addWidget(self.lbl_z,  0, 3)
        info_grid.addWidget(self.lbl_r,  1, 1); info_grid.addWidget(self.lbl_p,  1, 2); info_grid.addWidget(self.lbl_yw, 1, 3)
        mon_layout.addLayout(info_grid)

        self.btn_start = QPushButton('▶ CHẠY')
        self.btn_start.setStyleSheet('background-color: #77AC30; color: white; font-weight: bold;')
        self.btn_start.clicked.connect(self.runSystem)
        self.btn_pause = QPushButton('⏸ TẠM DỪNG')
        self.btn_pause.setStyleSheet('background-color: #7E2F8E; color: white; font-weight: bold;')
        self.btn_pause.clicked.connect(self.pauseTwin)
        self.btn_stop = QPushButton('⏹ DỪNG')
        self.btn_stop.setStyleSheet('background-color: #A2142F; color: white; font-weight: bold;')
        self.btn_stop.clicked.connect(self.stopTwin)
        mon_layout.addWidget(self.btn_start)
        mon_layout.addWidget(self.btn_pause)
        mon_layout.addWidget(self.btn_stop)

        # === Canvas 3D ===
        self.canvas = Canvas3D()

        # --- Lắp layout ---
        right_col = QVBoxLayout()
        right_col.addWidget(pnl_monitor)
        right_col.addWidget(self.canvas, stretch=1)

        left_col.addWidget(title)
        left_col.addWidget(pnl_mech)
        left_col.addWidget(pnl_ctrl)
        left_col.addStretch()

        main_layout.addLayout(right_col, stretch=1)

    # ------------------------------------------------------------------
    # saveConfig
    # ------------------------------------------------------------------
    def saveConfig(self):
        cfg = dict(
            ra=self.ed_ra.value(), rb=self.ed_rb.value(),
            l1=self.ed_l1.value(), l2=self.ed_l2.value(),
            a1=self.ed_a1.value(), da=self.ed_da.value(),
            b1=self.ed_b1.value(), db=self.ed_db.value(),
            headX=self.ed_headX.value(),
            headY=self.ed_headY.value(),
            headZ=self.ed_headZ.value(),
        )
        path, _ = QFileDialog.getSaveFileName(self, 'Lưu cấu hình', 'RobotConfig.json', 'JSON (*.json)')
        if not path:
            return
        with open(path, 'w', encoding='utf-8') as f:
            json.dump(cfg, f, indent=2)
        QMessageBox.information(self, 'Thành công', 'Đã lưu cấu hình thành công!')

    # ------------------------------------------------------------------
    # loadConfig
    # ------------------------------------------------------------------
    def loadConfig(self):
        path, _ = QFileDialog.getOpenFileName(self, 'Chọn file cấu hình', '', 'JSON (*.json)')
        if not path:
            return
        with open(path, 'r', encoding='utf-8') as f:
            cfg = json.load(f)
        self.ed_ra.setValue(cfg['ra']); self.ed_rb.setValue(cfg['rb'])
        self.ed_l1.setValue(cfg['l1']); self.ed_l2.setValue(cfg['l2'])
        self.ed_a1.setValue(cfg['a1']); self.ed_da.setValue(cfg['da'])
        self.ed_b1.setValue(cfg['b1']); self.ed_db.setValue(cfg['db'])
        self.ed_headX.setValue(cfg.get('headX', 0))
        self.ed_headY.setValue(cfg.get('headY', 0))
        self.ed_headZ.setValue(cfg.get('headZ', cfg.get('hhead', 0)))
        self.calcGeometry()
        QMessageBox.information(self, 'Thành công', 'Đã tải và áp dụng cấu hình!')

    # ------------------------------------------------------------------
    # calcGeometry : Tính A_mat, B_mat, gamma_ang
    # ------------------------------------------------------------------
    def calcGeometry(self):
        self.L1_val = self.ed_l1.value()
        self.L2_val = self.ed_l2.value()
        a1 = self.ed_a1.value(); da = self.ed_da.value()
        b1 = self.ed_b1.value(); db = self.ed_db.value()
        ra = self.ed_ra.value(); rb = self.ed_rb.value()

        alpha = np.zeros(6); beta = np.zeros(6)
        for k in range(3):
            alpha[2*k]   = -(a1 + k * 120)
            alpha[2*k+1] = -(a1 - da + (k+1) * 120)
            beta[2*k]    = -(b1 + k * 120)
            beta[2*k+1]  = -(b1 + db + k * 120)

        self.A_mat = np.zeros((3, 6))
        self.B_mat = np.zeros((3, 6))
        self.gamma_ang = np.zeros(6)

        for i in range(6):
            self.A_mat[0, i] = ra * np.cos(np.radians(alpha[i]))
            self.A_mat[1, i] = ra * np.sin(np.radians(alpha[i]))
            self.A_mat[2, i] = 795.4 - 202
            self.B_mat[0, i] = rb * np.cos(np.radians(beta[i]))
            self.B_mat[1, i] = rb * np.sin(np.radians(beta[i]))
            self.B_mat[2, i] = 0
            self.gamma_ang[i] = alpha[i] + ((-1)**(i+1)) * 90  # MATLAB 1-indexed → i+1

        self.lbl_status.setText('Đã cập nhật (Sẵn sàng)!')
        self.lbl_status.setStyleSheet('color: green;')
        v_head = np.array([self.ed_headX.value(), self.ed_headY.value(), self.ed_headZ.value()])
        self.drawStewart3D(0, 0, self.ed_homez.value(), 0, 0, 0,
                           None, None, None, None, None, None, v_head, np.zeros(3))

    # ------------------------------------------------------------------
    # browseFile
    # ------------------------------------------------------------------
    def browseFile(self):
        path, _ = QFileDialog.getOpenFileName(self, 'Chọn file dữ liệu', '', 'Data Files (*.csv *.txt)')
        if path:
            self.lbl_file.setText(path)
            self.lbl_file.setStyleSheet('color: black;')
            self.is_Validated = False

    # ------------------------------------------------------------------
    # parseMoogFile : Đọc file Moog (~M) trả về numpy array
    # ------------------------------------------------------------------
    def parseMoogFile(self, filename):
        with open(filename, 'r', encoding='utf-8', errors='replace') as f:
            raw = f.read()
        lines = raw.splitlines()
        pattern = re.compile(r'[-+]?\d*\.?\d+(?:[eE][-+]?\d+)?')
        rows = []
        for line in lines:
            line = line.strip()
            if not line:
                continue
            nums = pattern.findall(line)
            if not nums:
                continue
            row = [float(x) for x in nums]
            if row:
                rows.append(row)
        if not rows:
            return np.array([])
        # Pad rows to same length
        max_len = max(len(r) for r in rows)
        data = np.full((len(rows), max_len), np.nan)
        for i, r in enumerate(rows):
            data[i, :len(r)] = r
        return data

    # ------------------------------------------------------------------
    # generateData : Tạo quỹ đạo từ file hoặc tín hiệu mẫu
    # ------------------------------------------------------------------
    def generateData(self):
        v_head_local = np.array([self.ed_headX.value(), self.ed_headY.value(), self.ed_headZ.value()])
        Home_Z_Plat = self.ed_homez.value()
        mode_pivot = self.dd_pivot.currentText()

        axi = awi = azi = wx = wy = wz = None

        if mode_pivot == 'Đỉnh Đầu Người Lái':
            v_pivot = v_head_local.copy()
        elif mode_pivot == 'Tâm Bàn Máy':
            v_pivot = np.zeros(3)
        else:
            v_pivot = np.array([self.ed_px.value(), self.ed_py.value(), self.ed_pz.value()])

        file_path = self.lbl_file.text()
        has_file = file_path != 'Chưa chọn file' and os.path.isfile(file_path)

        def rot_matrix(yaw_d, pitch_d, roll_d):
            cy, sy = np.cos(np.radians(yaw_d)),   np.sin(np.radians(yaw_d))
            cp, sp = np.cos(np.radians(pitch_d)), np.sin(np.radians(pitch_d))
            cr, sr = np.cos(np.radians(roll_d)),  np.sin(np.radians(roll_d))
            return np.array([
                [cy*cp, cy*sp*sr - sy*cr, cy*sp*cr + sy*sr],
                [sy*cp, sy*sp*sr + cy*cr, sy*sp*cr - cy*sr],
                [-sp,   cp*sr,            cp*cr            ]
            ])

        if has_file:
            num_data = self.parseMoogFile(file_path)
            if num_data.size == 0:
                raise ValueError('File không chứa dữ liệu số hợp lệ.')
            # Xóa hàng có NaN
            mask = ~np.isnan(num_data).any(axis=1)
            num_data = num_data[mask]
            if num_data.shape[1] < 7:
                raise ValueError('File cần ít nhất 7 cột: Time, X, Y, Z, Yaw, Pitch, Roll')

            t     = num_data[:, 0]
            file_X = num_data[:, 1]; file_Y = num_data[:, 2]; file_Z = num_data[:, 3]
            ywp   = num_data[:, 4]; pp = num_data[:, 5]; rp = num_data[:, 6]

            if num_data.shape[1] >= 16:
                axi = num_data[:, 7];  awi = num_data[:, 8];  azi = num_data[:, 9]
                wz  = num_data[:, 13]; wy  = num_data[:, 14]; wx  = num_data[:, 15]

            N = len(t)
            xp = np.zeros(N); yp = np.zeros(N); zp = np.zeros(N)
            xv = np.zeros(N); yv = np.zeros(N); zv = np.zeros(N)
            x_hd = np.zeros(N); y_hd = np.zeros(N); z_hd = np.zeros(N)

            import_type = self.dd_import_type.currentText()

            for k in range(N):
                R_k = rot_matrix(ywp[k], pp[k], rp[k])
                P_file = np.array([file_X[k], file_Y[k], file_Z[k]])

                if 'Bàn máy' in import_type:
                    pos_plat = P_file
                elif 'Đầu người' in import_type:
                    pos_plat = P_file - R_k @ v_head_local
                else:
                    pos_plat = P_file - R_k @ v_pivot

                xp[k], yp[k], zp[k] = pos_plat

                pos_piv = pos_plat + R_k @ v_pivot
                xv[k], yv[k], zv[k] = pos_piv

                pos_head = pos_plat + R_k @ v_head_local
                x_hd[k], y_hd[k], z_hd[k] = pos_head

        else:
            T_sim = self.ed_time.value()
            freq  = self.ed_freq.value()
            A_lin = self.ed_amp_lin.value()
            A_ang = self.ed_amp_ang.value()
            fs = 50
            t = np.arange(0, T_sim + 1/fs, 1/fs)
            fade = np.minimum(t, 1.0)

            xv = np.zeros_like(t)
            yv = np.zeros_like(t)
            zv = (Home_Z_Plat + v_pivot[2]) * np.ones_like(t)
            ywp = np.zeros_like(t)
            pp  = np.zeros_like(t)
            rp  = np.zeros_like(t)

            mode = self.dd_traj.currentText()
            if '[1D] Tịnh tiến Z' in mode:
                zv = zv + (A_lin * np.sin(2*np.pi*freq*t)) * fade
            elif '[1D] Quay Pitch' in mode:
                pp = (A_ang * np.sin(2*np.pi*freq*t)) * fade
            elif '[2D] Đường tròn XY' in mode:
                xv = (A_lin * np.cos(2*np.pi*freq*t) - A_lin) * fade
                yv = (A_lin * np.sin(2*np.pi*freq*t)) * fade
            elif '[3D] Cua chữ S' in mode:
                yv = (A_lin * np.sin(2*np.pi*freq*t)) * fade
                xv = (A_lin/2 * np.sin(4*np.pi*freq*t)) * fade
                rp = (A_ang * np.sin(4*np.pi*freq*t)) * fade
                pp = (A_ang/2 * np.cos(2*np.pi*freq*t)) * fade

            N = len(t)
            xp = np.zeros(N); yp = np.zeros(N); zp = np.zeros(N)
            x_hd = np.zeros(N); y_hd = np.zeros(N); z_hd = np.zeros(N)

            for k in range(N):
                R_k = rot_matrix(ywp[k], pp[k], rp[k])
                pos_plat = np.array([xv[k], yv[k], zv[k]]) - R_k @ v_pivot
                xp[k], yp[k], zp[k] = pos_plat
                pos_head = pos_plat + R_k @ v_head_local
                x_hd[k], y_hd[k], z_hd[k] = pos_head

        return (t, xp, yp, zp, rp, pp, ywp,
                xv, yv, zv, x_hd, y_hd, z_hd, v_pivot,
                axi, awi, azi, wx, wy, wz)

    # ------------------------------------------------------------------
    # local_check_safety : Kiểm tra an toàn động học
    # ------------------------------------------------------------------
    def local_check_safety(self, pose):
        if np.any(np.isnan(pose)) or np.any(np.isinf(pose)):
            return False, 'NaN/Inf'

        x, y, z, r_ang, p_ang, yw_ang = pose
        cy, sy = np.cos(np.radians(yw_ang)), np.sin(np.radians(yw_ang))
        cp, sp = np.cos(np.radians(p_ang)),  np.sin(np.radians(p_ang))
        cr, sr = np.cos(np.radians(r_ang)),  np.sin(np.radians(r_ang))
        R = np.array([
            [cy*cp, cy*sp*sr - sy*cr, cy*sp*cr + sy*sr],
            [sy*cp, sy*sp*sr + cy*cr, sy*sp*cr - cy*sr],
            [-sp,   cp*sr,            cp*cr            ]
        ])

        T = np.array([x, y, z])
        L_vec = T[:, None] + R @ self.B_mat - self.A_mat   # 3×6
        l_sq = np.sum(L_vec**2, axis=0)
        Q = l_sq - self.L2_val**2 + self.L1_val**2
        M_val = 2 * self.L1_val * L_vec[2, :]
        N_val = 2 * self.L1_val * (
            np.cos(np.radians(self.gamma_ang)) * L_vec[0, :] +
            np.sin(np.radians(self.gamma_ang)) * L_vec[1, :]
        )
        denom = np.sqrt(M_val**2 + N_val**2)
        denom[denom == 0] = 1e-12
        arg = Q / denom

        if np.any(np.abs(arg) > 1):
            bad = np.where(np.abs(arg) > 1)[0]
            return False, f'Chân {bad[0]+1} kịch'

        phi_raw = np.degrees(np.arcsin(arg)) - np.degrees(np.arctan2(N_val, M_val))
        phi_out = np.zeros(6)
        phi_out[0::2] = -(90 + phi_raw[0::2])
        phi_out[1::2] =  (90 + phi_raw[1::2])
        offsets = np.array([90, -90, 90, -90, 90, -90])
        phi_thuc = phi_out - offsets

        if np.any(phi_thuc < -70) or np.any(phi_thuc > 100):
            bad = np.where((phi_thuc < -70) | (phi_thuc > 100))[0]
            return False, f'Góc Servo {bad[0]+1} là {phi_thuc[bad[0]]:.1f}°'

        r_vec = R @ self.B_mat
        L_norm = np.linalg.norm(L_vec, axis=0)
        L_norm[L_norm == 0] = 1e-12
        s_vec = L_vec / L_norm
        cross_prod = np.cross(r_vec.T, s_vec.T).T   # 3×6
        J_inv = np.vstack([s_vec.T, cross_prod.T])  # 12×6 → use 6×6
        # chỉ lấy 6 hàng đầu cho Jacobian 6×6
        J6 = np.vstack([s_vec.T, cross_prod.T])[:6, :]
        if abs(np.linalg.det(J6)) < 1e-3:
            return False, 'Kỳ dị'

        return True, 'OK'

    # ------------------------------------------------------------------
    # runSystem
    # ------------------------------------------------------------------
    def runSystem(self):
        if self.is_Playing:
            if self.is_Paused:
                self.pauseTwin()
            return
        if self.A_mat is None:
            QMessageBox.warning(self, 'Lỗi', 'Bấm CẬP NHẬT CẤU HÌNH trước!')
            return

        try:
            result = self.generateData()
        except Exception as e:
            QMessageBox.critical(self, 'Lỗi dữ liệu', f'Lỗi khi tạo dữ liệu: {e}')
            return

        (t, xp, yp, zp, rp, pp, ywp,
         xv, yv, zv, x_hd, y_hd, z_hd, v_pivot,
         axi, ayi, azi, wx, wy, wz) = result

        # Kiểm định an toàn
        dlg = QProgressDialog('Quét an toàn...', 'Hủy', 0, len(t), self)
        dlg.setWindowTitle('Đang kiểm định')
        dlg.setModal(True)
        dlg.show()
        QApplication.processEvents()

        for k in range(len(t)):
            pose_k = np.array([xp[k], yp[k], zp[k], rp[k], pp[k], ywp[k]])
            is_safe, msg = self.local_check_safety(pose_k)
            if not is_safe:
                dlg.close()
                QMessageBox.critical(self, 'Lỗi',
                    f'QUỸ ĐẠO KHÔNG KHẢ THI!\nt={t[k]:.2f}s: {msg}')
                self.is_Validated = False
                return
            dlg.setValue(k)
            if dlg.wasCanceled():
                return
            if k % 50 == 0:
                QApplication.processEvents()

        dlg.close()

        self.is_Validated = True
        self.T_out = t
        self.Xp_out = xp; self.Yp_out = yp; self.Zp_out = zp
        self.Xv_out = xv; self.Yv_out = yv; self.Zv_out = zv
        self.R_out = rp;  self.P_out = pp;  self.Yw_out = ywp
        self.Xh_out = x_hd; self.Yh_out = y_hd; self.Zh_out = z_hd
        self.Ax_out = axi; self.Ay_out = ayi; self.Az_out = azi
        self.Wx_out = wx;  self.Wy_out = wy;  self.Wz_out = wz
        self._v_pivot_run = v_pivot
        self._v_head_run = np.array([self.ed_headX.value(), self.ed_headY.value(), self.ed_headZ.value()])

        self.is_Playing = True
        self.is_Paused = False
        self.btn_pause.setText('⏸ TẠM DỪNG')
        self.btn_pause.setStyleSheet('background-color: #7E2F8E; color: white; font-weight: bold;')

        step = max(1, len(t) // 150)
        self._worker = SimWorker(len(t), step)
        self._worker.update_signal.connect(self._on_frame)
        self._worker.finished_signal.connect(self._on_finished)
        self._worker.start()

    def _on_frame(self, i):
        t = self.T_out; xp = self.Xp_out; yp = self.Yp_out; zp = self.Zp_out
        rp = self.R_out; pp = self.P_out; ywp = self.Yw_out

        self.lbl_t.setText(f'Time: {t[i]:.2f} s')
        self.lbl_x.setText(f'X: {xp[i]:.1f}')
        self.lbl_y.setText(f'Y: {yp[i]:.1f}')
        self.lbl_z.setText(f'Z: {zp[i]:.1f}')
        self.lbl_r.setText(f'Roll: {rp[i]:.1f}°')
        self.lbl_p.setText(f'Pitch: {pp[i]:.1f}°')
        self.lbl_yw.setText(f'Yaw: {ywp[i]:.1f}°')

        self.drawStewart3D(
            xp[i], yp[i], zp[i], rp[i], pp[i], ywp[i],
            self.Xv_out[:i+1], self.Yv_out[:i+1], self.Zv_out[:i+1],
            self.Xh_out[:i+1], self.Yh_out[:i+1], self.Zh_out[:i+1],
            self._v_head_run, self._v_pivot_run
        )

    def _on_finished(self):
        self.is_Playing = False

    # ------------------------------------------------------------------
    # exportData
    # ------------------------------------------------------------------
    def exportData(self):
        if not self.is_Validated or self.T_out is None:
            QMessageBox.warning(self, 'Lỗi', 'Chưa có dữ liệu an toàn! Hãy bấm KIỂM ĐỊNH & CHẠY trước.')
            return

        fmt = self.dd_export.currentText()
        if 'Đầu người' in fmt:
            X_t, Y_t, Z_t, def_name = self.Xh_out, self.Yh_out, self.Zh_out, 'Head_Command.csv'
        elif 'Tâm quay Pivot' in fmt:
            X_t, Y_t, Z_t, def_name = self.Xv_out, self.Yv_out, self.Zv_out, 'Pivot_Command.csv'
        else:
            X_t, Y_t, Z_t, def_name = self.Xp_out, self.Yp_out, self.Zp_out, 'Platform_Command.csv'

        path, _ = QFileDialog.getSaveFileName(self, 'Lưu file CSV', def_name, 'CSV (*.csv)')
        if not path:
            return

        T = self.T_out; N = len(T)
        with open(path, 'w', encoding='utf-8') as fid:
            if '15 tham số' in fmt:
                dt = np.diff(T)
                dt[dt == 0] = 0.0125
                vx = np.append(np.diff(X_t)/dt, 0)
                vy = np.append(np.diff(Y_t)/dt, 0)
                vz = np.append(np.diff(Z_t)/dt, 0)
                dt2 = np.append(dt, dt[-1])
                ax_m = np.append(np.diff(vx)/dt, 0) / 1000
                ay_m = np.append(np.diff(vy)/dt, 0) / 1000
                az_m = np.append(np.diff(vz)/dt, 0) / 1000
                wxo = np.append(np.diff(self.R_out)/dt * np.pi/180, 0)
                wyo = np.append(np.diff(self.P_out)/dt * np.pi/180, 0)
                wzo = np.append(np.diff(self.Yw_out)/dt * np.pi/180, 0)
                for k in range(N):
                    fid.write(
                        f'{T[k]:.4f} ~M[ {X_t[k]:.4f} {Y_t[k]:.4f} {Z_t[k]:.4f} '
                        f'{self.Yw_out[k]:.4f} {self.P_out[k]:.4f} {self.R_out[k]:.4f} '
                        f'[ {ax_m[k]:.4f} {ay_m[k]:.4f} {az_m[k]:.4f} '
                        f'0.0000 0.0000 9.8100 '
                        f'{wzo[k]:.4f} {wyo[k]:.4f} {wxo[k]:.4f} ]]\n'
                    )
            else:
                for k in range(N):
                    fid.write(
                        f'{T[k]:.4f} ~M[ {X_t[k]:.4f} {Y_t[k]:.4f} {Z_t[k]:.4f} '
                        f'{self.Yw_out[k]:.4f} {self.P_out[k]:.4f} {self.R_out[k]:.4f} ]\n'
                    )

        QMessageBox.information(self, 'Hoàn tất', 'Đã xuất file thành công!')

    # ------------------------------------------------------------------
    # pauseTwin / stopTwin
    # ------------------------------------------------------------------
    def pauseTwin(self):
        if self.is_Playing and self._worker:
            self._worker.pause()
            self.is_Paused = not self.is_Paused
            if self.is_Paused:
                self.btn_pause.setText('▶ TIẾP TỤC')
                self.btn_pause.setStyleSheet('background-color: #EDB120; color: black; font-weight: bold;')
            else:
                self.btn_pause.setText('⏸ TẠM DỪNG')
                self.btn_pause.setStyleSheet('background-color: #7E2F8E; color: white; font-weight: bold;')

    def stopTwin(self):
        if self._worker:
            self._worker.stop()
        self.is_Playing = False
        self.is_Paused = False
        self.btn_pause.setText('⏸ TẠM DỪNG')
        self.btn_pause.setStyleSheet('background-color: #7E2F8E; color: white; font-weight: bold;')

    # ------------------------------------------------------------------
    # plot15Params
    # ------------------------------------------------------------------
    def plot15Params(self):
        if not self.is_Validated or self.T_out is None:
            QMessageBox.warning(self, 'Lỗi', 'Chưa có dữ liệu quỹ đạo! Hãy chạy mô phỏng trước.')
            return

        fmt = self.dd_export.currentText()
        if 'Đầu người' in fmt:
            X_t, Y_t, Z_t, title_str = self.Xh_out, self.Yh_out, self.Zh_out, 'Đầu người'
        elif 'Tâm quay Pivot' in fmt:
            X_t, Y_t, Z_t, title_str = self.Xv_out, self.Yv_out, self.Zv_out, 'Tâm quay Pivot'
        else:
            X_t, Y_t, Z_t, title_str = self.Xp_out, self.Yp_out, self.Zp_out, 'Bàn máy'

        t = self.T_out
        if self.Ax_out is not None:
            ax_p, ay_p, az_p = self.Ax_out, self.Ay_out, self.Az_out
            wx_p, wy_p, wz_p = self.Wx_out, self.Wy_out, self.Wz_out
        else:
            dt = np.diff(t)
            dt[dt == 0] = 0.0125
            vx = np.append(np.diff(X_t)/dt, 0)
            vy = np.append(np.diff(Y_t)/dt, 0)
            vz = np.append(np.diff(Z_t)/dt, 0)
            ax_p = np.append(np.diff(vx)/dt, 0) / 1000
            ay_p = np.append(np.diff(vy)/dt, 0) / 1000
            az_p = np.append(np.diff(vz)/dt, 0) / 1000
            wx_p = np.append(np.diff(self.R_out)/dt * np.pi/180, 0)
            wy_p = np.append(np.diff(self.P_out)/dt * np.pi/180, 0)
            wz_p = np.append(np.diff(self.Yw_out)/dt * np.pi/180, 0)

        fig, axes = plt.subplots(3, 5, figsize=(18, 10))
        fig.suptitle(f'Biểu đồ 15 tham số quỹ đạo — {title_str}', fontsize=14, fontweight='bold')
        cPos = '#0072BD'; cAng = '#D95319'; cAcc = '#77AC30'; cOmg = '#7E2F8E'

        def sp(r, c, y_data, color, ylabel, title_):
            ax = axes[r][c]; ax.plot(t, y_data, color=color, linewidth=1.5)
            ax.set_xlabel('t (s)'); ax.set_ylabel(ylabel); ax.set_title(title_)
            ax.grid(True)

        sp(0, 0, X_t,         cPos, 'X (mm)',     'Vị trí X')
        sp(0, 1, Y_t,         cPos, 'Y (mm)',     'Vị trí Y')
        sp(0, 2, Z_t,         cPos, 'Z (mm)',     'Vị trí Z')
        sp(0, 3, self.Yw_out, cAng, 'Yaw (°)',    'Góc Yaw')
        sp(0, 4, self.P_out,  cAng, 'Pitch (°)',  'Góc Pitch')
        sp(1, 0, self.R_out,  cAng, 'Roll (°)',   'Góc Roll')
        sp(1, 1, ax_p,        cAcc, 'aₓ (m/s²)', 'Gia tốc X')
        sp(1, 2, ay_p,        cAcc, 'aᵧ (m/s²)', 'Gia tốc Y')
        sp(1, 3, az_p,        cAcc, 'a_z (m/s²)','Gia tốc Z')

        ax_comb = axes[1][4]; ax_comb.grid(True)
        ax_comb.plot(t, ax_p, color=cAcc,      linewidth=1.2, label='aₓ')
        ax_comb.plot(t, ay_p, color='#4DC8EE', linewidth=1.2, label='aᵧ')
        ax_comb.plot(t, az_p, color='#009900', linewidth=1.2, label='a_z')
        ax_comb.legend(fontsize=7); ax_comb.set_xlabel('t (s)')
        ax_comb.set_ylabel('a (m/s²)'); ax_comb.set_title('Gia tốc tổng hợp')

        sp(2, 0, wx_p, cOmg, 'ωₓ (rad/s)',  'V.Tốc góc X')
        sp(2, 1, wy_p, cOmg, 'ωᵧ (rad/s)',  'V.Tốc góc Y')
        sp(2, 2, wz_p, cOmg, 'ω_z (rad/s)', 'V.Tốc góc Z')

        ax3d = fig.add_subplot(3, 5, 14, projection='3d',
                               position=axes[2][3].get_position())
        axes[2][3].remove(); axes[2][4].remove()
        ax3d.set_position([0.62, 0.04, 0.36, 0.28])
        sc = ax3d.scatter(X_t, Y_t, Z_t, c=t, cmap='jet', s=6)
        fig.colorbar(sc, ax=ax3d, label='t (s)', shrink=0.6)
        ax3d.plot(X_t, Y_t, Z_t, 'k-', linewidth=0.8)
        ax3d.scatter([X_t[0]], [Y_t[0]], [Z_t[0]], color='g', s=60, zorder=5)
        ax3d.scatter([X_t[-1]], [Y_t[-1]], [Z_t[-1]], color='r', marker='s', s=60, zorder=5)
        ax3d.set_xlabel('X'); ax3d.set_ylabel('Y'); ax3d.set_zlabel('Z')
        ax3d.set_title(f'Quỹ đạo 3D — {title_str}')

        plt.tight_layout()
        plt.show()

    # ------------------------------------------------------------------
    # drawStewart3D
    # ------------------------------------------------------------------
    def drawStewart3D(self, x, y, z, roll, pitch, yaw,
                       x_v_trail, y_v_trail, z_v_trail,
                       x_h_trail, y_h_trail, z_h_trail,
                       v_head, v_piv):
        if self.A_mat is None:
            return

        ax = self.canvas.ax
        ax.cla()
        ax.set_title('Digital Twin: Realistic Stewart Platform Kinematics')
        ax.set_xlabel('X (mm)'); ax.set_ylabel('Y (mm)'); ax.set_zlabel('Z (mm)')
        ax.set_xlim(-800, 800); ax.set_ylim(-800, 800); ax.set_zlim(-1700, 800)
        ax.invert_zaxis(); ax.invert_yaxis()
        ax.grid(True)

        colorBase     = [0.8, 0.8, 0.0, 0.8]
        colorPlatform = [0.0, 0.6, 0.0, 0.9]
        colorL1       = [0.4, 0.4, 0.4]
        colorL2       = [0.8, 0.0, 0.0]

        # Vẽ đế
        A = self.A_mat
        verts_base = [list(zip(A[0], A[1], A[2]))]
        poly_base = Poly3DCollection(verts_base, facecolor=colorBase, edgecolor='k')
        ax.add_collection3d(poly_base)

        # Ma trận quay
        cy, sy = np.cos(np.radians(yaw)),   np.sin(np.radians(yaw))
        cp, sp = np.cos(np.radians(pitch)), np.sin(np.radians(pitch))
        cr, sr = np.cos(np.radians(roll)),  np.sin(np.radians(roll))
        R = np.array([
            [cy*cp, cy*sp*sr - sy*cr, cy*sp*cr + sy*sr],
            [sy*cp, sy*sp*sr + cy*cr, sy*sp*cr - cy*sr],
            [-sp,   cp*sr,            cp*cr            ]
        ])

        P_center = np.array([x, y, z])
        B_global = P_center[:, None] + R @ self.B_mat   # 3×6

        # Vẽ bàn máy
        verts_plat = [list(zip(B_global[0], B_global[1], B_global[2]))]
        poly_plat = Poly3DCollection(verts_plat, facecolor=colorPlatform, edgecolor='b')
        ax.add_collection3d(poly_plat)

        # Vẽ 6 chân
        for i in range(6):
            A_i = self.A_mat[:, i]
            P_i = B_global[:, i]
            Lx, Ly, Lz = P_i - A_i
            Q  = Lx**2 + Ly**2 + Lz**2 - self.L2_val**2 + self.L1_val**2
            M  = 2 * self.L1_val * Lz
            N  = 2 * self.L1_val * (
                np.cos(np.radians(self.gamma_ang[i])) * Lx +
                np.sin(np.radians(self.gamma_ang[i])) * Ly
            )
            denom = np.sqrt(M**2 + N**2)
            if denom < 1e-12:
                denom = 1e-12
            arg = Q / denom
            phi = np.degrees(np.arcsin(np.clip(arg, -1, 1))) - np.degrees(np.arctan2(N, M))

            Cx = A_i[0] + self.L1_val * np.cos(np.radians(self.gamma_ang[i])) * np.cos(np.radians(phi))
            Cy = A_i[1] + self.L1_val * np.sin(np.radians(self.gamma_ang[i])) * np.cos(np.radians(phi))
            Cz = A_i[2] - self.L1_val * np.sin(np.radians(phi))
            C_i = np.array([Cx, Cy, Cz])

            ax.plot([A_i[0], C_i[0]], [A_i[1], C_i[1]], [A_i[2], C_i[2]],
                    color=colorL1, linewidth=6)
            ax.plot([C_i[0], P_i[0]], [C_i[1], P_i[1]], [C_i[2], P_i[2]],
                    color=colorL2, linewidth=4)

            ax.text(A_i[0], A_i[1], A_i[2] - 35, f'A{i+1}',
                    color='k', fontsize=8, fontweight='bold', ha='center')
            ax.text(P_i[0], P_i[1], P_i[2] + 35, f'B{i+1}',
                    color='b', fontsize=8, fontweight='bold', ha='center')

        # Vẽ đầu người
        Head_global = P_center + R @ v_head
        ax.plot([x, Head_global[0]], [y, Head_global[1]], [z, Head_global[2]],
                color=[0.4, 0.4, 0.4], linewidth=6)
        u, v_s = np.mgrid[0:2*np.pi:20j, 0:np.pi:10j]
        r_head = 80
        ax.plot_surface(
            r_head*np.cos(u)*np.sin(v_s) + Head_global[0],
            r_head*np.sin(u)*np.sin(v_s) + Head_global[1],
            r_head*np.cos(v_s)           + Head_global[2],
            color=[1, 0.8, 0.6], alpha=0.8, linewidth=0
        )

        # Vẽ pivot
        Pivot_global = P_center + R @ v_piv
        r_piv = 15
        ax.plot_surface(
            r_piv*np.cos(u)*np.sin(v_s) + Pivot_global[0],
            r_piv*np.sin(u)*np.sin(v_s) + Pivot_global[1],
            r_piv*np.cos(v_s)           + Pivot_global[2],
            color='red', alpha=0.9, linewidth=0
        )

        # Vẽ trail
        if x_v_trail is not None and len(x_v_trail) > 1:
            ax.plot(x_v_trail, y_v_trail, z_v_trail, 'b--', linewidth=1.5)
        if x_h_trail is not None and len(x_h_trail) > 1:
            ax.plot(x_h_trail, y_h_trail, z_h_trail, 'm-', linewidth=2.5)

        self.canvas.draw()


# =====================================================================
# MAIN
# =====================================================================
def main():
    app = QApplication(sys.argv)
    app.setStyle('Fusion')
    win = StewartDashboard()
    win.show()
    sys.exit(app.exec_())


if __name__ == '__main__':
    main()
