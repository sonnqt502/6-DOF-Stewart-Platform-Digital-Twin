#!/usr/bin/env python3
"""
Dashboard Stewart Platform – PyQt5 + Vispy + Matplotlib
========================================================
Toàn bộ tính toán được gom vào `compute_all_parameters`.
Các thành phần khác (xuất file, vẽ đồ thị) chỉ sử dụng kết quả đã tính.
"""

import sys, re, json, threading, time
import numpy as np
import os
from numpy.linalg import det, norm

from PyQt5.QtWidgets import (
    QApplication, QMainWindow, QTextBrowser, QWidget, QLabel, QPushButton,
    QLineEdit, QComboBox, QGroupBox, QFileDialog, QMessageBox,
    QProgressDialog, QHBoxLayout, QVBoxLayout, QGridLayout,
    QSizePolicy, QToolBar, QAction, QTabWidget
)
from PyQt5.QtCore import Qt, QThread, pyqtSignal
from PyQt5.QtGui import QFont

import vispy.scene as scene
from vispy.scene import visuals
from vispy import app as vispy_app

import matplotlib
matplotlib.use("Qt5Agg")
from matplotlib.backends.backend_qt5agg import FigureCanvasQTAgg as FigureCanvas
from matplotlib.backends.backend_qt5agg import NavigationToolbar2QT as NavigationToolbar
from matplotlib.figure import Figure

# ========== HẰNG SỐ ==========
Z_BASE_ABSOLUTE = 795.4
Z_MOTOR_OFFSET  = 202.0
Z_A             = Z_BASE_ABSOLUTE - Z_MOTOR_OFFSET
SERVO_MIN_DEG   = -70.0
SERVO_MAX_DEG   = 100.0
SINGULARITY_TOL = 1e-3
ANIM_FS         = 50
GRAVITY         = 9.81

# ========== ĐỘNG HỌC CƠ BẢN ==========
def calc_rotation_matrix(yaw_deg, pitch_deg, roll_deg):
    cy, sy = np.cos(np.radians(yaw_deg)), np.sin(np.radians(yaw_deg))
    cp, sp = np.cos(np.radians(pitch_deg)), np.sin(np.radians(pitch_deg))
    cr, sr = np.cos(np.radians(roll_deg)), np.sin(np.radians(roll_deg))
    return np.array([
        [cy*cp, cy*sp*sr - sy*cr, cy*sp*cr + sy*sr],
        [sy*cp, sy*sp*sr + cy*cr, sy*sp*cr - cy*sr],
        [-sp,   cp*sr,            cp*cr]
    ])

def calc_geometry(ra, rb, l1, l2, a1, da, b1, db):
    A_mat = np.zeros((3,6)); B_mat = np.zeros((3,6)); gamma = np.zeros(6)
    alpha = np.zeros(6); beta = np.zeros(6)
    for k in range(3):
        alpha[2*k]   = -(a1 + k*120)
        alpha[2*k+1] = -(a1 - da + (k+1)*120)
        beta[2*k]    = -(b1 + k*120)
        beta[2*k+1]  = -(b1 + db + k*120)
    for i in range(6):
        A_mat[0,i] = ra * np.cos(np.radians(alpha[i]))
        A_mat[1,i] = ra * np.sin(np.radians(alpha[i]))
        A_mat[2,i] = Z_A
        B_mat[0,i] = rb * np.cos(np.radians(beta[i]))
        B_mat[1,i] = rb * np.sin(np.radians(beta[i]))
        B_mat[2,i] = 0.0
        gamma[i] = alpha[i] + ((-1)**(i+1)) * 90
    return A_mat, B_mat, gamma

def check_safety(pose, A_mat, B_mat, l1, l2, gamma):
    pose = np.asarray(pose, dtype=float)
    if np.any(np.isnan(pose)) or np.any(np.isinf(pose)):
        return False, "Dữ liệu chứa NaN hoặc Inf"
    roll_deg, pitch_deg, yaw_deg = pose[3], pose[4], pose[5]
    t_val = pose[6] if len(pose) > 6 else None   # thời gian (có thể không có)
    time_str = f" tại t={t_val:.2f}s" if t_val is not None else ""

    R = calc_rotation_matrix(yaw_deg, pitch_deg, roll_deg)
    T = pose[:3]
    L_vec = T[:, None] + R @ B_mat - A_mat
    l_sq = np.sum(L_vec**2, axis=0)
    Q = l_sq - l2**2 + l1**2
    M_val = 2 * l1 * L_vec[2, :]
    N_val = 2 * l1 * (np.cos(np.radians(gamma)) * L_vec[0, :] + np.sin(np.radians(gamma)) * L_vec[1, :])
    denom = np.sqrt(M_val**2 + N_val**2)
    arg = Q / denom

    # Lỗi 1: Giới hạn cơ khí (kịch)
    bad = np.where(np.abs(arg) > 1)[0]
    if len(bad):
        leg = bad[0] + 1
        return False, f"Lỗi 1: Giới hạn cơ khí (kịch) - Chân {leg} không thể với tới{time_str}"

    phi_raw = np.degrees(np.arcsin(arg)) - np.degrees(np.arctan2(N_val, M_val))
    phi_out = np.zeros(6)
    phi_out[0::2] = -(90 + phi_raw[0::2])
    phi_out[1::2] = +(90 + phi_raw[1::2])
    phi_thuc = phi_out - np.array([90, -90, 90, -90, 90, -90])

    # Lỗi 2: Vượt quá giới hạn động cơ
    bad_idx = np.where((phi_thuc < SERVO_MIN_DEG) | (phi_thuc > SERVO_MAX_DEG))[0]
    if len(bad_idx):
        leg = bad_idx[0] + 1
        val = phi_thuc[bad_idx[0]]
        return False, f"Lỗi 2: Vượt quá giới hạn động cơ - Chân {leg} góc {val:.1f}° (cho phép {SERVO_MIN_DEG}°..{SERVO_MAX_DEG}°){time_str}"

    # Lỗi 3: Điểm kỳ dị
    r_vec = R @ B_mat
    s_vec = L_vec / np.linalg.norm(L_vec, axis=0)
    cross_prod = np.cross(r_vec.T, s_vec.T)
    J_inv = np.hstack([s_vec.T, cross_prod])
    if abs(det(J_inv)) < SINGULARITY_TOL:
        return False, f"Lỗi 3: Điểm kỳ dị - det(J)=0{time_str}"

    return True, "OK"
def calculate_servo_angles(pose, A_mat, B_mat, l1, l2, gamma):
    pose = np.asarray(pose, dtype=float)
    roll_deg, pitch_deg, yaw_deg = pose[3], pose[4], pose[5]
    R = calc_rotation_matrix(yaw_deg, pitch_deg, roll_deg)
    T = pose[:3]
    L_vec = T[:, None] + R @ B_mat - A_mat
    l_sq = np.sum(L_vec**2, axis=0)
    Q = l_sq - l2**2 + l1**2
    M_val = 2 * l1 * L_vec[2, :]
    N_val = 2 * l1 * (np.cos(np.radians(gamma)) * L_vec[0, :] + np.sin(np.radians(gamma)) * L_vec[1, :])
    denom = np.sqrt(M_val**2 + N_val**2)
    arg = np.clip(Q / denom, -1.0, 1.0)
    phi_raw = np.degrees(np.arcsin(arg)) - np.degrees(np.arctan2(N_val, M_val))
    phi_out = np.zeros(6)
    phi_out[0::2] = -(90 + phi_raw[0::2])
    phi_out[1::2] = +(90 + phi_raw[1::2])
    phi_thuc = phi_out - np.array([90, -90, 90, -90, 90, -90])
    return phi_thuc

# ========== PARSING FILE ==========
def parse_moog_file(filename):
    pattern = re.compile(r'[-+]?\d*\.?\d+(?:[eE][-+]?\d+)?')
    rows = []
    with open(filename, 'r', encoding='utf-8', errors='ignore') as f:
        for line in f:
            nums = pattern.findall(line)
            if nums: rows.append([float(x) for x in nums])
    if not rows: raise ValueError("File không có dữ liệu số")
    max_cols = max(len(r) for r in rows)
    data = np.full((len(rows), max_cols), np.nan)
    for i, r in enumerate(rows): data[i, :len(r)] = r
    return data

# ========== TẠO QUỸ ĐẠO THÔ ==========
def generate_raw_trajectory(params):
    """
    Trả về dictionary chứa dữ liệu thô của quỹ đạo:
    t, xp, yp, zp, rp, pp, ywp, xv, yv, zv, x_hd, y_hd, z_hd, v_pivot,
    ax_i, ay_i, az_i, wx_i, wy_i, wz_i (nếu có từ file)
    """
    v_head_local = np.array([params['head_x'], params['head_y'], params['head_z']])
    home_z = params['home_z']
    mode_pivot = params['pivot_mode']
    if mode_pivot == 'Đỉnh Đầu Người Lái':
        v_pivot = v_head_local.copy()
    elif mode_pivot == 'Tâm Bàn Máy':
        v_pivot = np.zeros(3)
    else:
        v_pivot = np.array([params['px'], params['py'], params['pz']])

    ax_i = ay_i = az_i = wx_i = wy_i = wz_i = None
    filepath = params.get('filepath', '')
    if filepath and filepath != 'Chưa chọn file':
        num_data = parse_moog_file(filepath)
        num_data = num_data[~np.any(np.isnan(num_data), axis=1)]
        if num_data.shape[1] < 7:
            raise ValueError("File cần ít nhất 7 cột")
        t = num_data[:,0]
        file_X = num_data[:,1]; file_Y = num_data[:,2]; file_Z = num_data[:,3]
        ywp = num_data[:,4]; pp = num_data[:,5]; rp = num_data[:,6]
        if num_data.shape[1] >= 16:
            ax_i = num_data[:,7]; ay_i = num_data[:,8]; az_i = num_data[:,9]
            wz_i = num_data[:,13]; wy_i = num_data[:,14]; wx_i = num_data[:,15]
        N = len(t)
        xp = np.zeros(N); yp = np.zeros(N); zp = np.zeros(N)
        xv = np.zeros(N); yv = np.zeros(N); zv = np.zeros(N)
        x_hd = np.zeros(N); y_hd = np.zeros(N); z_hd = np.zeros(N)
        import_type = params['import_type']
        for k in range(N):
            R_k = calc_rotation_matrix(ywp[k], pp[k], rp[k])
            P_file = np.array([file_X[k], file_Y[k], file_Z[k]])
            if import_type == 'Bàn máy (Platform)':
                pos_plat = P_file
            elif import_type == 'Đầu người (Head)':
                pos_plat = P_file - R_k @ v_head_local
            else:  # Tâm quay Pivot
                pos_plat = P_file - R_k @ v_pivot
            xp[k], yp[k], zp[k] = pos_plat
            pos_piv = pos_plat + R_k @ v_pivot
            xv[k], yv[k], zv[k] = pos_piv
            pos_head = pos_plat + R_k @ v_head_local
            x_hd[k], y_hd[k], z_hd[k] = pos_head
    else:
        T_sim = params['t_sim']; freq = params['freq']
        A_lin = params['amp_lin']; A_ang = params['amp_ang']
        t = np.arange(0, T_sim + 1/ANIM_FS, 1/ANIM_FS)
        N = len(t)
        fade = np.minimum(t, 1.0)
        xv = np.zeros(N); yv = np.zeros(N); zv = np.full(N, home_z + v_pivot[2])
        ywp = np.zeros(N); pp = np.zeros(N); rp = np.zeros(N)
        mode = params['traj_mode']
        if mode == '[1D] Tịnh tiến Z (Heave)':
            zv += A_lin * np.sin(2*np.pi*freq*t) * fade
        elif mode == '[1D] Quay Pitch (Gật gù)':
            pp = A_ang * np.sin(2*np.pi*freq*t) * fade
        elif mode == '[2D] Đường tròn XY':
            xv = (A_lin * np.cos(2*np.pi*freq*t) - A_lin) * fade
            yv = A_lin * np.sin(2*np.pi*freq*t) * fade
        elif mode == '[3D] Cua chữ S (6 DOF)':
            yv = A_lin * np.sin(2*np.pi*freq*t) * fade
            xv = (A_lin/2) * np.sin(4*np.pi*freq*t) * fade
            rp = A_ang * np.sin(4*np.pi*freq*t) * fade
            pp = (A_ang/2) * (np.cos(2*np.pi*freq*t) - 1) * fade
        xp = np.zeros(N); yp = np.zeros(N); zp = np.zeros(N)
        x_hd = np.zeros(N); y_hd = np.zeros(N); z_hd = np.zeros(N)
        for k in range(N):
            R_k = calc_rotation_matrix(ywp[k], pp[k], rp[k])
            pos_plat = np.array([xv[k], yv[k], zv[k]]) - R_k @ v_pivot
            xp[k], yp[k], zp[k] = pos_plat
            pos_head = pos_plat + R_k @ v_head_local
            x_hd[k], y_hd[k], z_hd[k] = pos_head
    return {
        't': t, 'xp': xp, 'yp': yp, 'zp': zp,
        'rp': rp, 'pp': pp, 'ywp': ywp,
        'xv': xv, 'yv': yv, 'zv': zv,
        'x_hd': x_hd, 'y_hd': y_hd, 'z_hd': z_hd,
        'v_pivot': v_pivot,
        'ax_i': ax_i, 'ay_i': ay_i, 'az_i': az_i,
        'wx_i': wx_i, 'wy_i': wy_i, 'wz_i': wz_i
    }

# ========== HÀM TÍNH TOÁN TỔNG HỢP ==========
def compute_all_parameters(raw_traj, A_mat, B_mat, L1, L2, gamma):
    """
    Tính toàn bộ các đại lượng động học từ quỹ đạo thô.
    Tất cả công thức khớp với MATLAB Dashboard_Stewart3.m.

    Trả về dict với các key:
        t, Xp,Yp,Zp, Rp,Pp,Yw         — vị trí & góc bàn máy
        Xv,Yv,Zv, Xh,Yh,Zh            — pivot và đầu người
        vx,vy,vz                        — vận tốc world frame (mm/s)
        ax_i,ay_i,az_i                  — gia tốc quán tính body frame (m/s²)
        ax_g,ay_g,az_g                  — hình chiếu trọng lực body frame (m/s²)
        wx_b,wy_b,wz_b                  — vận tốc góc body frame Jacobian ZYX (rad/s)
        a_px,a_py,a_pz                  — gia tốc cảm nhận = quán tính + trọng lực (m/s²)
        servo_angles                    — góc phi_thuc 6 motor (N×6, độ)
        v_pivot                         — vector pivot body frame (mm)
    """
    t  = raw_traj['t']
    Xp = raw_traj['xp']; Yp = raw_traj['yp']; Zp = raw_traj['zp']
    Rp = raw_traj['rp']; Pp = raw_traj['pp']; Yw = raw_traj['ywp']
    N  = len(t)

    dt = np.diff(t); dt[dt == 0] = 0.0125

    def _diff_pad(arr):
        """Sai phân tiến bậc 1, đệm điểm cuối."""
        d = np.diff(arr) / dt
        return np.append(d, d[-1])

    # ------------------------------------------------------------------
    # 1. Vận tốc world frame (mm/s)
    # ------------------------------------------------------------------
    vx = _diff_pad(Xp); vy = _diff_pad(Yp); vz = _diff_pad(Zp)

    # ------------------------------------------------------------------
    # 2. Gia tốc world frame (m/s²) — sai phân bậc 2 vị trí
    # ------------------------------------------------------------------
    ax_w = _diff_pad(vx) / 1000.0   # mm/s² → m/s²
    ay_w = _diff_pad(vy) / 1000.0
    az_w = _diff_pad(vz) / 1000.0

    # ------------------------------------------------------------------
    # 3. Chiếu lên body frame tại mỗi bước thời gian
    #    a_body = R(t)' @ a_world      (gia tốc quán tính, không có g)
    #    g_body = R(t)' @ [0, 0, g]   (hình chiếu trọng lực, Z world ↓ nên g > 0)
    # Khớp MATLAB: a_body = R_k' * [ax_w; ay_w; az_w]
    #              g_body = R_k' * [0; 0; 9.81]
    # ------------------------------------------------------------------
    g_val = GRAVITY
    ax_i = np.zeros(N); ay_i = np.zeros(N); az_i = np.zeros(N)
    ax_g = np.zeros(N); ay_g = np.zeros(N); az_g = np.zeros(N)
    for k in range(N):
        R_k    = calc_rotation_matrix(Yw[k], Pp[k], Rp[k])
        a_body = R_k.T @ np.array([ax_w[k], ay_w[k], az_w[k]])
        ax_i[k], ay_i[k], az_i[k] = a_body
        g_body = R_k.T @ np.array([0.0, 0.0, g_val])
        ax_g[k], ay_g[k], az_g[k] = g_body

    # ------------------------------------------------------------------
    # 4. Vận tốc góc body frame qua Jacobian ZYX
    #    Không dùng sai phân trực tiếp (sai khi góc lớn, gimbal lock).
    #    Jacobian ZYX (Ψ=Yaw, Θ=Pitch, Φ=Roll):
    #      ωx =  dΦ/dt - dΨ/dt·sin(Θ)
    #      ωy =  dΘ/dt·cos(Φ) + dΨ/dt·cos(Θ)·sin(Φ)
    #      ωz = -dΘ/dt·sin(Φ) + dΨ/dt·cos(Θ)·cos(Φ)
    #    Thứ tự output theo spec Moog: [wz_b, wy_b, wx_b] = [Yaw, Pitch, Roll body]
    # Khớp MATLAB: wx_b, wy_b, wz_b
    # ------------------------------------------------------------------
    dYaw   = _diff_pad(Yw) * (np.pi / 180)    # dΨ/dt (rad/s)
    dPitch = _diff_pad(Pp) * (np.pi / 180)    # dΘ/dt
    dRoll  = _diff_pad(Rp) * (np.pi / 180)    # dΦ/dt
    phi_r   = np.radians(Rp)    # Φ Roll (rad)
    theta_r = np.radians(Pp)    # Θ Pitch (rad)
    wx_b =  dRoll  - dYaw * np.sin(theta_r)
    wy_b =  dPitch * np.cos(phi_r) + dYaw * np.cos(theta_r) * np.sin(phi_r)
    wz_b = -dPitch * np.sin(phi_r) + dYaw * np.cos(theta_r) * np.cos(phi_r)

    # ------------------------------------------------------------------
    # 5. Gia tốc cảm nhận = quán tính + trọng lực body frame
    # ------------------------------------------------------------------
    a_px = ax_i + ax_g
    a_py = ay_i + ay_g
    a_pz = az_i + az_g

    # ------------------------------------------------------------------
    # 6. Góc servo cho toàn bộ quỹ đạo
    # ------------------------------------------------------------------
    servo_angles = np.zeros((N, 6))
    for k in range(N):
        pose = np.array([Xp[k], Yp[k], Zp[k], Rp[k], Pp[k], Yw[k]])
        servo_angles[k, :] = calculate_servo_angles(pose, A_mat, B_mat, L1, L2, gamma)

    return {
        't': t,
        'Xp': Xp, 'Yp': Yp, 'Zp': Zp,
        'Rp': Rp, 'Pp': Pp, 'Yw': Yw,
        'Xv': raw_traj['xv'], 'Yv': raw_traj['yv'], 'Zv': raw_traj['zv'],
        'Xh': raw_traj['x_hd'], 'Yh': raw_traj['y_hd'], 'Zh': raw_traj['z_hd'],
        'vx': vx, 'vy': vy, 'vz': vz,
        'ax_i': ax_i, 'ay_i': ay_i, 'az_i': az_i,   # gia tốc quán tính body
        'ax_g': ax_g, 'ay_g': ay_g, 'az_g': az_g,   # trọng lực body
        'wx_b': wx_b, 'wy_b': wy_b, 'wz_b': wz_b,   # vận tốc góc body Jacobian ZYX
        'a_px': a_px, 'a_py': a_py, 'a_pz': a_pz,   # gia tốc cảm nhận
        'servo_angles': servo_angles,
        'v_pivot': raw_traj['v_pivot']
    }

# ========== MESH 3D ==========
# (giữ nguyên các hàm _make_cylinder_mesh, _make_sphere, _make_cone_mesh như trong mã gốc)
def _make_cylinder_mesh(p_start, p_end, radius, n_pts=16):
    vec = p_end - p_start; length = norm(vec)
    if length < 1e-9: return None, None
    vec_n = vec / length
    u_z = np.array([0.,0.,1.])
    if abs(vec_n[2]) > 0.999:
        R_cyl = np.eye(3) if vec_n[2]>0 else np.diag([1,-1,-1])
    else:
        v = np.cross(u_z, vec_n); s = norm(v); c = np.dot(u_z, vec_n)
        Vx = np.array([[0,-v[2],v[1]],[v[2],0,-v[0]],[-v[1],v[0],0]])
        R_cyl = np.eye(3) + Vx + Vx@Vx*((1-c)/s**2)
    angles = np.linspace(0, 2*np.pi, n_pts, endpoint=False)
    circle_x = radius * np.cos(angles); circle_y = radius * np.sin(angles)
    pts_bot = np.column_stack([circle_x, circle_y, np.zeros(n_pts)])
    pts_top = np.column_stack([circle_x, circle_y, np.full(n_pts, length)])
    pts_bot = (R_cyl @ pts_bot.T).T + p_start
    pts_top = (R_cyl @ pts_top.T).T + p_start
    vertices = np.vstack([pts_bot, pts_top])
    faces = []
    for i in range(n_pts):
        j = (i+1)%n_pts
        faces.append([i, j, n_pts+i])
        faces.append([j, n_pts+j, n_pts+i])
    return vertices, np.array(faces)

def _make_sphere(center, radius, n=15):
    u = np.linspace(0, np.pi, n); v = np.linspace(0, 2*np.pi, n)
    uu, vv = np.meshgrid(u, v)
    x = radius * np.sin(uu)*np.cos(vv) + center[0]
    y = radius * np.sin(uu)*np.sin(vv) + center[1]
    z = radius * np.cos(uu) + center[2]
    verts = np.column_stack([x.ravel(), y.ravel(), z.ravel()])
    faces = []
    for i in range(n-1):
        for j in range(n-1):
            a = i*n+j; b = a+1; c = (i+1)*n+j; d = c+1
            faces += [[a,b,c],[b,d,c]]
    return verts, np.array(faces)

def _make_cone_mesh(base_center, tip, radius, n_pts=16):
    axis = tip - base_center; height = norm(axis)
    if height < 1e-9: return np.zeros((0,3)), np.zeros((0,3), dtype=np.uint32)
    axis_n = axis / height
    if abs(axis_n[2]) < 0.9: u = np.cross(axis_n, [0,0,1])
    else: u = np.cross(axis_n, [1,0,0])
    u = u / norm(u); v = np.cross(axis_n, u)
    angles = np.linspace(0, 2*np.pi, n_pts, endpoint=False)
    circle_pts = radius * (np.cos(angles)[:,None]*u + np.sin(angles)[:,None]*v)
    base_pts = base_center + circle_pts
    vertices = np.vstack([base_pts, tip.reshape(1,3)])
    faces = []
    for i in range(n_pts):
        j = (i+1)%n_pts
        faces.append([i, j, n_pts])
    return vertices, np.array(faces, dtype=np.uint32)

# ========== CANVAS 3D (giữ nguyên StewartCanvas3D như mã gốc, chỉ thay đổi nhỏ để tương thích) ==========
class StewartCanvas3D(scene.SceneCanvas):
    def __init__(self):
        super().__init__(keys='interactive', bgcolor='white', show=False)
        self.unfreeze()
        self.view = self.central_widget.add_view()
        from vispy.visuals.transforms import STTransform
        self._scene_node = scene.Node(parent=self.view.scene)
        self._scene_node.transform = STTransform(scale=(1,1,-1))
        self.view.camera = scene.cameras.TurntableCamera(
            elevation=30, azimuth=-37.5, distance=3500, center=(0,0,300))
        self._base_mesh = visuals.Mesh(parent=self._scene_node)
        self._plat_mesh = visuals.Mesh(parent=self._scene_node)
        self._leg_meshes = [visuals.Mesh(parent=self._scene_node) for _ in range(12)]
        self._head_mesh = visuals.Mesh(parent=self._scene_node)
        self._pivot_mesh = visuals.Mesh(parent=self._scene_node)
        self._trail_pivot = visuals.Line(parent=self._scene_node, color=(0.2,0.5,1.0,0.8), width=2)
        self._trail_head = visuals.Line(parent=self._scene_node, color=(0.9,0.3,0.9,0.9), width=2.5)
        self._labels_A = [visuals.Text(f'A{i+1}', parent=self._scene_node, color='black', font_size=10) for i in range(6)]
        self._labels_B = [visuals.Text(f'B{i+1}', parent=self._scene_node, color='blue', font_size=10) for i in range(6)]
        self._head_connector = visuals.Line(parent=self._scene_node, color=(0.0,0.8,0.0,1.0), width=3)
        self._create_grid_and_axes()
        self.freeze()

    def _create_grid_and_axes(self):
        # giữ nguyên như mã gốc (không thay đổi)
        grid_range = 1500; grid_step = 250; axis_len = 1600
        grid_lines = []
        for i in range(-grid_range, grid_range+1, grid_step):
            grid_lines.append([[-grid_range, i, 0], [grid_range, i, 0]])
            grid_lines.append([[i, -grid_range, 0], [i, grid_range, 0]])
        grid_pos = np.array(grid_lines, dtype=np.float32).reshape(-1,3)
        visuals.Line(parent=self._scene_node, pos=grid_pos, color=(0.7,0.7,0.7,1.0), width=1.0, connect='segments')
        bbox = [
            [-grid_range, -grid_range, 0], [ grid_range, -grid_range, 0],
            [ grid_range,  grid_range, 0], [-grid_range,  grid_range, 0],
            [-grid_range, -grid_range, axis_len], [ grid_range, -grid_range, axis_len],
            [ grid_range,  grid_range, axis_len], [-grid_range,  grid_range, axis_len]
        ]
        edges = [(0,1),(1,2),(2,3),(3,0),(4,5),(5,6),(6,7),(7,4),(0,4),(1,5),(2,6),(3,7)]
        bbox_pos = []
        for e in edges: bbox_pos.append(bbox[e[0]]); bbox_pos.append(bbox[e[1]])
        visuals.Line(parent=self._scene_node, pos=np.array(bbox_pos, dtype=np.float32),
                     color=(0.5,0.5,0.5,1.0), width=1.5, connect='segments')
        def create_axis(direction, color, label):
            dir_arr = np.array(direction, dtype=float)
            start = np.zeros(3); end = dir_arr * axis_len
            cone_height = 40; cone_radius = 20; cone_base = end - dir_arr*cone_height
            visuals.Line(parent=self._scene_node, pos=np.array([start, end]), color=color, width=4, connect='segments')
            verts, faces = _make_cone_mesh(cone_base, end, cone_radius)
            visuals.Mesh(parent=self._scene_node, vertices=verts.astype(np.float32), faces=faces, color=color)
            visuals.Text(label, parent=self._scene_node, color=color, font_size=18, bold=True, pos=end+dir_arr*60)
        create_axis([1,0,0], (1.0,0.2,0.2,1.0), 'X')
        create_axis([0,-1,0], (0.2,1.0,0.2,1.0), 'Y')
        create_axis([0,0,1], (0.2,0.4,1.0,1.0), 'Z')
        tick_interval = 500; tick_length = 15
        for axis_dir, col in [([1,0,0], (1,0.5,0.5,1)), ([0,1,0], (0.5,1,0.5,1)), ([0,0,1], (0.5,0.5,1,1))]:
            dir_arr = np.array(axis_dir)
            for val in range(tick_interval, int(axis_len), tick_interval):
                base = dir_arr * val
                if axis_dir == [1,0,0]: p1, p2 = base+[0,-tick_length/2,0], base+[0,tick_length/2,0]
                elif axis_dir == [0,1,0]: p1, p2 = base+[-tick_length/2,0,0], base+[tick_length/2,0,0]
                else: p1, p2 = base+[-tick_length/2,0,0], base+[tick_length/2,0,0]
                visuals.Line(parent=self._scene_node, pos=np.array([p1,p2]), color=(0.3,0.3,0.3,1), width=2, connect='segments')
                visuals.Text(str(val), parent=self._scene_node, color=col, font_size=10, pos=base+dir_arr*30)

    def draw_frame(self, x, y, z, roll, pitch, yaw, A_mat, B_mat, gamma, l1, l2, v_head, v_piv, trail_v=None, trail_h=None):
        R = calc_rotation_matrix(yaw, pitch, roll); T = np.array([x, y, z])
        base_pts = A_mat[:2,:].T; base_z = A_mat[2,0]; base_3d = np.column_stack([base_pts, np.full(6, base_z)])
        faces_hex = np.array([[0,1,2],[0,2,3],[0,3,4],[0,4,5]])
        self._base_mesh.set_data(vertices=base_3d.astype(np.float32), faces=faces_hex,
                                 face_colors=np.tile([0.8,0.8,0.0,0.8], (4,1)))
        B_global = (T[:,None] + R @ B_mat).T
        self._plat_mesh.set_data(vertices=B_global.astype(np.float32), faces=faces_hex,
                                 face_colors=np.tile([0.0,0.6,0.0,0.9], (4,1)))
        for i in range(6):
            A_i = A_mat[:,i]; P_i = B_global[i]; L_vec = P_i - A_i
            Lx, Ly, Lz = L_vec
            Q = Lx**2+Ly**2+Lz**2 - l2**2 + l1**2
            M = 2*l1*Lz; N = 2*l1*(np.cos(np.radians(gamma[i]))*Lx + np.sin(np.radians(gamma[i]))*Ly)
            denom = np.sqrt(M**2+N**2); arg = Q/denom if denom>1e-9 else 0
            if abs(arg)<=1: phi = np.degrees(np.arcsin(arg)) - np.degrees(np.arctan2(N,M))
            else: phi = 0.0
            Cx = A_i[0] + l1*np.cos(np.radians(gamma[i]))*np.cos(np.radians(phi))
            Cy = A_i[1] + l1*np.sin(np.radians(gamma[i]))*np.cos(np.radians(phi))
            Cz = A_i[2] + l1*np.sin(np.radians(phi))   # dấu TRỪ — khớp MATLAB: Cz = A_i(3) - L1*sind(phi)
            C_i = np.array([Cx, Cy, Cz])
            for j, (p_s, p_e, r, color) in enumerate([(A_i, C_i, 18, [0.4,0.4,0.4,1.0]), (C_i, P_i, 12, [0.8,0.0,0.0,1.0])]):
                verts, faces = _make_cylinder_mesh(p_s, p_e, r, 12)
                if verts is not None:
                    self._leg_meshes[i*2+j].set_data(vertices=verts.astype(np.float32), faces=faces,
                                                     face_colors=np.tile(color, (len(faces),1)))
            self._labels_A[i].pos = A_i + [0,0,-40]
            self._labels_B[i].pos = P_i + [0,0,40]
        head_pos = T + R @ v_head
        verts_h, faces_h = _make_sphere(head_pos, 80, 15)
        self._head_mesh.set_data(vertices=verts_h.astype(np.float32), faces=faces_h,
                                 face_colors=np.tile([1.0,0.8,0.6,1.0], (len(faces_h),1)))
        self._head_connector.set_data(pos=np.array([T, head_pos]), color=(0.0,0.8,0.0,1.0), width=3)
        piv_pos = T + R @ v_piv
        verts_p, faces_p = _make_sphere(piv_pos, 15, 10)
        self._pivot_mesh.set_data(vertices=verts_p.astype(np.float32), faces=faces_p,
                                  face_colors=np.tile([1.0,0.0,0.0,1.0], (len(faces_p),1)))
        if trail_v is not None and len(trail_v)>1: self._trail_pivot.set_data(trail_v.astype(np.float32))
        if trail_h is not None and len(trail_h)>1: self._trail_head.set_data(trail_h.astype(np.float32))
        self.update()

# ========== THREAD HOẠT ẢNH ==========
class AnimationThread(QThread):
    frame_signal = pyqtSignal(int, float, float, float, float, float, float)
    done_signal = pyqtSignal()
    def __init__(self, raw_traj, step):
        super().__init__()
        self.raw_traj = raw_traj; self.step = step
        self._playing = True; self._paused = False
        self._lock = threading.Event(); self._lock.set()
    def pause(self): self._paused = True; self._lock.clear()
    def resume(self): self._paused = False; self._lock.set()
    def stop(self): self._playing = False; self._lock.set()
    def run(self):
        t = self.raw_traj['t']; xp = self.raw_traj['xp']; yp = self.raw_traj['yp']; zp = self.raw_traj['zp']
        rp = self.raw_traj['rp']; pp = self.raw_traj['pp']; ywp = self.raw_traj['ywp']
        N = len(t); dt_frame = (t[-1]-t[0])/(N/self.step) if N>1 else 0.02
        for i in range(0, N, self.step):
            if not self._playing: break
            self._lock.wait()
            if not self._playing: break
            self.frame_signal.emit(i, xp[i], yp[i], zp[i], rp[i], pp[i], ywp[i])
            self.msleep(max(1, int(dt_frame*1000)))
        self.done_signal.emit()

# ========== CỬA SỔ BIỂU ĐỒ 3 TAB ==========
class PlotWindowTabs(QMainWindow):
    def __init__(self, results, title_str):
        super().__init__()
        self.setWindowTitle(f"Biểu đồ chi tiết - {title_str}")
        self.resize(1400, 900)
        self.results = results
        self.title_str = title_str
        self.tabs = QTabWidget()
        self.setCentralWidget(self.tabs)
        self.tab1 = self._create_tab_motion()
        self.tabs.addTab(self.tab1, "Chuyển động (Vị trí & Góc)")
        self.tab2 = self._create_tab_acceleration()
        self.tabs.addTab(self.tab2, "Gia tốc & Vận tốc góc")
        self.tab3 = self._create_tab_workspace()
        self.tabs.addTab(self.tab3, "Quỹ đạo & Động cơ")

    def _create_tab_motion(self):
        tab = QWidget(); layout = QVBoxLayout(tab)
        fig = Figure(figsize=(14,8)); canvas = FigureCanvas(fig)
        toolbar = NavigationToolbar(canvas, self)
        layout.addWidget(toolbar); layout.addWidget(canvas)
        t = self.results['t']
        Xp, Yp, Zp = self.results['Xp'], self.results['Yp'], self.results['Zp']
        Rp, Pp, Yw = self.results['Rp'], self.results['Pp'], self.results['Yw']
        titles = ['X (mm)', 'Y (mm)', 'Z (mm)', 'Yaw (°)', 'Pitch (°)', 'Roll (°)']
        series = [Xp, Yp, Zp, Yw, Pp, Rp]
        colors = ['#0072bd','#d95319','#edb120','#4dbee0','#77ac30','#7e2f8e']
        for i in range(6):
            ax = fig.add_subplot(2,3,i+1)
            ax.plot(t, series[i], color=colors[i], linewidth=1.2)
            ax.set_xlabel('Thời gian (s)'); ax.set_ylabel(titles[i])
            ax.set_title(titles[i]); ax.grid(True, linestyle=':', alpha=0.7)
        fig.suptitle(f"Chuyển động – {self.title_str}", fontweight='bold')
        fig.tight_layout(rect=[0,0,1,0.96]); canvas.draw()
        return tab

    def _create_tab_acceleration(self):
        tab = QWidget(); layout = QVBoxLayout(tab)
        fig = Figure(figsize=(16, 9)); canvas = FigureCanvas(fig)
        toolbar = NavigationToolbar(canvas, self)
        layout.addWidget(toolbar); layout.addWidget(canvas)
        t = self.results['t']

        # Màu sắc — khớp MATLAB
        cAcc = '#789a32'; cGrav = '#0072bd'; cOmg = '#7e2f8e'; cPerc = '#d95319'

        # Hàng 1: Gia tốc quán tính body frame (axi, ayi, azi)
        for idx, (key, lbl, ttl) in enumerate([
            ('ax_i', 'axi (m/s²)', 'Gia tốc QT X (body)'),
            ('ay_i', 'ayi (m/s²)', 'Gia tốc QT Y (body)'),
            ('az_i', 'azi (m/s²)', 'Gia tốc QT Z (body)'),
        ]):
            ax = fig.add_subplot(3, 4, idx+1)
            ax.plot(t, self.results[key], color=cAcc, linewidth=1.2)
            ax.set_title(ttl, fontsize=9); ax.set_ylabel(lbl, fontsize=8)
            ax.set_xlabel('t (s)', fontsize=8); ax.grid(True, linestyle=':')
            ax.margins(y=0.15)

        # Hàng 1 subplot 4: Gia tốc cảm nhận (3 đường)
        ax4 = fig.add_subplot(3, 4, 4)
        ax4.plot(t, self.results['a_px'], color=cPerc, lw=1.2, label='a_p,x (fwd)')
        ax4.plot(t, self.results['a_py'], color='#30bfee', lw=1.2, label='a_p,y (right)')
        ax4.plot(t, self.results['a_pz'], color='#009900', lw=1.2, label='a_p,z (down)')
        ax4.set_title('Gia tốc cảm nhận (body)', fontsize=9)
        ax4.set_ylabel('m/s²', fontsize=8); ax4.set_xlabel('t (s)', fontsize=8)
        ax4.legend(fontsize=7); ax4.grid(True, linestyle=':'); ax4.margins(y=0.15)

        # Hàng 2: Hình chiếu trọng lực body frame (axg, ayg, azg)
        for idx, (key, lbl, ttl) in enumerate([
            ('ax_g', 'axg (m/s²)', 'Trọng lực X (body)'),
            ('ay_g', 'ayg (m/s²)', 'Trọng lực Y (body)'),
            ('az_g', 'azg (m/s²)', 'Trọng lực Z (body)'),
        ]):
            ax = fig.add_subplot(3, 4, idx+5)
            ax.plot(t, self.results[key], color=cGrav, linewidth=1.2)
            ax.set_title(ttl, fontsize=9); ax.set_ylabel(lbl, fontsize=8)
            ax.set_xlabel('t (s)', fontsize=8); ax.grid(True, linestyle=':')
            ax.margins(y=0.15)

        # Hàng 2 subplot 8: trống (dành cho mở rộng)
        fig.add_subplot(3, 4, 8).axis('off')

        # Hàng 3: Vận tốc góc body frame (wx_b, wy_b, wz_b)
        for idx, (key, lbl, ttl) in enumerate([
            ('wx_b', 'ωx (rad/s)', 'V.Tốc góc X (Roll body)'),
            ('wy_b', 'ωy (rad/s)', 'V.Tốc góc Y (Pitch body)'),
            ('wz_b', 'ωz (rad/s)', 'V.Tốc góc Z (Yaw body)'),
        ]):
            ax = fig.add_subplot(3, 4, idx+9)
            ax.plot(t, self.results[key], color=cOmg, linewidth=1.2)
            ax.set_title(ttl, fontsize=9); ax.set_ylabel(lbl, fontsize=8)
            ax.set_xlabel('t (s)', fontsize=8); ax.grid(True, linestyle=':')
            ax.margins(y=0.15)

        # Hàng 3 subplot 12: trống
        fig.add_subplot(3, 4, 12).axis('off')

        fig.suptitle(f"Gia tốc & Vận tốc góc – {self.title_str}", fontweight='bold')
        fig.tight_layout(rect=[0, 0, 1, 0.96]); canvas.draw()
        return tab

    def _create_tab_workspace(self):
        tab = QWidget()
        layout = QVBoxLayout(tab)
        fig = Figure(figsize=(14, 10))
        canvas = FigureCanvas(fig)
        toolbar = NavigationToolbar(canvas, self)
        layout.addWidget(toolbar)
        layout.addWidget(canvas)

        from matplotlib.gridspec import GridSpec
        gs = GridSpec(2, 6, figure=fig, height_ratios=[2, 1])

        # Quỹ đạo 3D – chiếm toàn bộ hàng trên
        ax3d = fig.add_subplot(gs[0, :], projection='3d')
        t = self.results['t']
        Xp, Yp, Zp = self.results['Xp'], self.results['Yp'], self.results['Zp']
        sc = ax3d.scatter(Xp, Yp, Zp, c=t, cmap='jet', s=4)
        ax3d.plot(Xp, Yp, Zp, 'k-', linewidth=0.6)
        ax3d.set_xlabel('X'); ax3d.set_ylabel('Y'); ax3d.set_zlabel('Z')
        ax3d.set_title('Quỹ đạo 3D')
        # Colorbar đặt riêng bên phải
        cbar = fig.colorbar(sc, ax=ax3d, shrink=0.6, pad=0.15)
        cbar.set_label('t (s)')

        # Góc servo – 6 ô ở hàng dưới
        servo = self.results['servo_angles']
        for leg in range(6):
            ax = fig.add_subplot(gs[1, leg])
            ax.plot(t, servo[:, leg], linewidth=1.0)
            ax.set_title(f'Chân {leg+1}')
            ax.set_xlabel('t (s)')
            ax.set_ylabel('°')
            ax.grid(True, linestyle=':')
            ax.axhline(y=SERVO_MIN_DEG, color='r', linestyle='--', linewidth=0.7)
            ax.axhline(y=SERVO_MAX_DEG, color='r', linestyle='--', linewidth=0.7)

        fig.suptitle(f"Quỹ đạo & Góc động cơ – {self.title_str}", fontweight='bold')
        fig.tight_layout(rect=[0, 0, 1, 0.96])
        canvas.draw()
        return tab

# ========== CỬA SỔ CHÍNH ==========
class DashboardWindow(QMainWindow):
    def __init__(self):
        super().__init__()
        self.setWindowTitle("HỆ THỐNG ĐIỀU KHIỂN & MÔ PHỎNG STEWART PLATFORM")
        self.resize(1200, 750)
        self.A_mat = None; self.B_mat = None; self.gamma_ang = None
        self.L1_val = 150.0; self.L2_val = 747.0
        self.raw_traj = None
        self.results  = None
        self.is_validated = False
        self.anim_thread  = None
        self.filepath     = ''
        self._plot_win    = None

        # MATLAB Engine — session liên tục, không tạo lại mỗi lần
        self._matlab_eng        = None
        self.simulink_model_name = ''   # tên model .slx (không có đuôi)

        self._build_ui()

    def closeEvent(self, event):
        """Khi đóng cửa sổ → ngắt MATLAB Engine để giải phóng bộ nhớ."""
        if hasattr(self, '_matlab_eng') and self._matlab_eng is not None:
            try:
                self._matlab_eng.quit()
            except Exception:
                pass
        event.accept()
        
    def _show_help(self):
        if not hasattr(self, '_help_dialog') or self._help_dialog is None:
            self._help_dialog = HelpDialog(self)
        self._help_dialog.show()
        self._help_dialog.raise_()
    # ---------- Giao diện (giữ nguyên như mã gốc, chỉ sửa các callback) ----------
    def _build_ui(self):
        central = QWidget()
        self.setCentralWidget(central)
        root_layout = QVBoxLayout(central)
        root_layout.setSpacing(6)

        lbl_title = QLabel("TRUNG TÂM ĐIỀU KHIỂN & GIÁM SÁT STEWART PLATFORM")
        lbl_title.setAlignment(Qt.AlignCenter)
        lbl_title.setFont(QFont("Arial", 16, QFont.Bold))
        lbl_title.setStyleSheet("color: #a21232;")
        root_layout.addWidget(lbl_title)

        content = QHBoxLayout()
        root_layout.addLayout(content, stretch=1)

        left_col = QVBoxLayout()
        left_col.setSpacing(4)
        left_col.addWidget(self._build_panel_mech())
        left_col.addWidget(self._build_panel_ctrl())
        content.addLayout(left_col)

        right_panel = QWidget()
        right_layout = QVBoxLayout(right_panel)
        right_layout.setContentsMargins(0, 0, 0, 0)
        right_layout.setSpacing(0)

        self.toolbar = QToolBar("Công cụ 3D")
        self.toolbar.setStyleSheet("QToolBar { background-color: #ececec; border: 1px solid #a0a0a0; }")
        self.action_zoom = QAction("🔍 Zoom", self)
        self.action_zoom.triggered.connect(lambda: QMessageBox.information(self, "Zoom", "Dùng nút phải chuột để zoom."))
        self.toolbar.addAction(self.action_zoom)
        self.action_pan = QAction("🖐️ Pan", self)
        self.action_pan.triggered.connect(lambda: QMessageBox.information(self, "Pan", "Dùng nút giữa hoặc Shift + kéo."))
        self.toolbar.addAction(self.action_pan)
        self.action_rotate = QAction("🔄 Rotate", self)
        self.action_rotate.triggered.connect(lambda: QMessageBox.information(self, "Rotate", "Dùng nút trái chuột để xoay."))
        self.toolbar.addAction(self.action_rotate)
        self.action_home = QAction("🏠 Home", self)
        self.action_home.triggered.connect(self._reset_camera)
        self.toolbar.addAction(self.action_home)
        right_layout.addWidget(self.toolbar)
        # ... sau các action Zoom, Pan, Rotate, Home ...
        self.action_help = QAction("📖 Hướng dẫn", self)
        self.action_help.triggered.connect(self._show_help)
        self.toolbar.addAction(self.action_help)
        self.canvas3d = StewartCanvas3D()
        native = self.canvas3d.native
        native.setSizePolicy(QSizePolicy.Expanding, QSizePolicy.Expanding)
        right_layout.addWidget(native)

        self.monitor_widget = self._build_panel_monitor()
        self.monitor_widget.setStyleSheet("""
            QGroupBox { background-color: #ececec; border: 1px solid #a0a0a0; margin-top: 1ex; font-weight: bold; }
            QGroupBox::title { subcontrol-origin: margin; left: 10px; padding: 0 5px 0 5px; }
            QLabel { color: #000000; }
        """)
        right_layout.addWidget(self.monitor_widget)

        content.addWidget(right_panel, stretch=1)
    # ------------------------------------------------------------------
    # KẾT NỐI SIMULINK — dùng matlab.engine (session liên tục)
    # ------------------------------------------------------------------
    # Nguyên tắc hoạt động:
    #   - MATLAB Engine khởi động 1 lần duy nhất (~15-30s), giữ trong
    #     self._matlab_eng suốt phiên làm việc.
    #   - Dữ liệu được đẩy trực tiếp vào workspace MATLAB (không qua file .mat).
    #   - Simulink chạy xong KHÔNG tắt — người dùng có thể quan sát kết quả.
    #   - Lần gọi tiếp theo chỉ tốn thời gian sim(), không khởi động lại.
    #
    # Cài đặt: pip install matlabengine
    # Yêu cầu: version matlabengine phải khớp với MATLAB đã cài
    #   MATLAB R2024a → pip install matlabengine==24.1.*
    # ------------------------------------------------------------------

    def _ensure_matlab_engine(self):
        """
        Khởi động MATLAB Engine nếu chưa có, giữ session trong self._matlab_eng.
        Trả về True nếu sẵn sàng, False nếu lỗi.
        """
        if hasattr(self, '_matlab_eng') and self._matlab_eng is not None:
            # Kiểm tra session còn sống không (ping nhẹ)
            try:
                self._matlab_eng.eval('1+1;', nargout=0)
                return True
            except Exception:
                self._matlab_eng = None   # session chết, tạo lại

        # Thông báo người dùng — khởi động lần đầu lâu
        self.lbl_matlab_status.setText("⏳ Đang khởi động MATLAB Engine (lần đầu ~30s)...")
        self.lbl_matlab_status.setStyleSheet("color: #cc8800; font-weight: bold;")
        QApplication.processEvents()

        try:
            import matlab.engine
        except ImportError:
            QMessageBox.critical(self, "Thiếu thư viện",
                "Chưa cài matlab.engine.\n\n"
                "Chạy lệnh sau trong terminal:\n"
                "    pip install matlabengine\n\n"
                "Lưu ý: version phải khớp MATLAB đã cài.\n"
                "MATLAB R2024a → pip install matlabengine==24.1.*")
            return False

        try:
            # Khởi động MATLAB Engine — tạo session mới
            # desktop=False: không mở cửa sổ MATLAB (chạy ẩn)
            self._matlab_eng = matlab.engine.start_matlab()

            # Thêm thư mục chứa Dashboard_Stewart3.m vào MATLAB path
            project_dir = os.path.dirname(os.path.abspath(__file__))
            self._matlab_eng.addpath(project_dir, nargout=0)

            self.lbl_matlab_status.setText("✅ MATLAB Engine sẵn sàng")
            self.lbl_matlab_status.setStyleSheet("color: green; font-weight: bold;")
            return True

        except Exception as e:
            self._matlab_eng = None
            self.lbl_matlab_status.setText("❌ Không kết nối được MATLAB")
            self.lbl_matlab_status.setStyleSheet("color: red; font-weight: bold;")
            QMessageBox.critical(self, "Lỗi MATLAB Engine", str(e))
            return False

    def _push_data_to_matlab(self):
        """
        Đẩy toàn bộ dữ liệu quỹ đạo và hình học vào workspace MATLAB.
        Dữ liệu được đẩy trực tiếp qua matlab.engine — không lưu file .mat.
        """
        import matlab
        eng = self._matlab_eng
        r   = self.results

        def _np(arr):
            """numpy (N,) → matlab.double hàng."""
            return matlab.double(arr.tolist())

        def _np2d(arr):
            """numpy (M,N) → matlab.double 2D."""
            return matlab.double(arr.tolist())

        # Hình học — cần cho Simulink block IK
        eng.workspace['A_mat']     = _np2d(self.A_mat)
        eng.workspace['B_mat']     = _np2d(self.B_mat)
        eng.workspace['gamma_ang'] = _np(self.gamma_ang)
        eng.workspace['L1']        = float(self.L1_val)
        eng.workspace['L2']        = float(self.L2_val)

        # Quỹ đạo — tên biến phải khớp với "VariableName" trong From Workspace block
        # Dùng eng.workspace để gán array trực tiếp, tránh lỗi non-ASCII khi eval chuỗi dài
        import matlab
        t_col = matlab.double(r['t'].reshape(-1, 1).tolist())   # cột (N,1)

        for var, key in [
            ('X_ref',     'Xp'),
            ('Y_ref',     'Yp'),
            ('Z_ref',     'Zp'),
            ('roll_ref',  'Rp'),
            ('pitch_ref', 'Pp'),
            ('yaw_ref',   'Yw'),
        ]:
            # Gán data và time vào workspace dưới tên tạm
            data_col = matlab.double(r[key].reshape(-1, 1).tolist())   # (N,1)
            eng.workspace['tmp_data'] = data_col
            eng.workspace['tmp_t']    = t_col
            # Build timeseries trong MATLAB — eval chuỗi ngắn, không có số lớn
            eng.eval(f"{var} = timeseries(tmp_data, tmp_t);", nargout=0)

        # Dọn biến tạm
        eng.eval("clear tmp_data tmp_t;", nargout=0)

        # Thời gian dừng
        eng.workspace['T_stop'] = float(r['t'][-1])

    def _run_simulink(self):
        """
        Chạy mô hình Simulink — MATLAB Engine session liên tục.
        Simulink GIỮ NGUYÊN sau khi chạy xong, không tắt.
        """
        if not self.is_validated or self.results is None:
            QMessageBox.warning(self, "Lỗi",
                "Chưa có dữ liệu an toàn! Hãy bấm KIỂM ĐỊNH & CHẠY trước.")
            return

        # Bước 1: Đảm bảo MATLAB Engine đang chạy
        if not self._ensure_matlab_engine():
            return

        # Bước 2: Tìm file .slx
        project_dir  = os.path.dirname(os.path.abspath(__file__))
        slx_files    = [f for f in os.listdir(project_dir) if f.endswith('.slx')]
        simulink_model = self.simulink_model_name   # tên model từ setting

        if not simulink_model:
            if len(slx_files) == 1:
                simulink_model = slx_files[0].replace('.slx', '')
            elif len(slx_files) > 1:
                # Có nhiều file .slx → hỏi người dùng
                from PyQt5.QtWidgets import QInputDialog
                simulink_model, ok = QInputDialog.getItem(
                    self, "Chọn mô hình Simulink",
                    "Tìm thấy nhiều file .slx, chọn mô hình cần chạy:",
                    slx_files, 0, False)
                if not ok: return
                simulink_model = simulink_model.replace('.slx', '')
                self.simulink_model_name = simulink_model
            else:
                QMessageBox.critical(self, "Lỗi",
                    f"Không tìm thấy file .slx trong:\n{project_dir}")
                return

        eng = self._matlab_eng

        # Bước 3: Đẩy dữ liệu vào workspace MATLAB
        self.lbl_matlab_status.setText("📤 Đang đẩy dữ liệu vào MATLAB...")
        self.lbl_matlab_status.setStyleSheet("color: #0072bb; font-weight: bold;")
        QApplication.processEvents()

        try:
            self._push_data_to_matlab()
        except Exception as e:
            QMessageBox.critical(self, "Lỗi đẩy dữ liệu", str(e))
            return

        # Bước 4: Mở model (nếu chưa mở) và cấu hình StopTime
        self.lbl_matlab_status.setText(f"🚀 Đang chạy Simulink: {simulink_model}...")
        self.lbl_matlab_status.setStyleSheet("color: #6a1a8a; font-weight: bold;")
        QApplication.processEvents()

        try:
            # Đóng model nếu đang mở (dù bất kỳ trạng thái nào) rồi load lại sạch.
            # Tránh lỗi "Cannot start simulation" khi model đang ở trạng thái
            # initializing / compiled / paused từ lần mở trước.
            eng.eval(f"""
if bdIsLoaded('{simulink_model}')
    % Dừng trước nếu đang chạy hoặc pause
    simStatus = get_param('{simulink_model}', 'SimulationStatus');
    if strcmp(simStatus, 'running') || strcmp(simStatus, 'paused')
        set_param('{simulink_model}', 'SimulationCommand', 'stop');
        waitCount = 0;
        while ~strcmp(get_param('{simulink_model}', 'SimulationStatus'), 'stopped') && waitCount < 50
            pause(0.1); waitCount = waitCount + 1;
        end
    end
    bdclose('{simulink_model}');
end
""", nargout=0)

            # Load model sạch từ file .slx
            eng.eval(f"load_system('{simulink_model}');", nargout=0)

            # Cấu hình StopTime từ dữ liệu quỹ đạo
            t_stop = float(self.results['t'][-1])
            eng.eval(
                f"set_param('{simulink_model}', 'StopTime', '{t_stop:.4f}');",
                nargout=0
            )

            # Chạy sim() — block đến khi xong
            eng.eval(f"sim('{simulink_model}');", nargout=0)

            self.lbl_matlab_status.setText(
                f"✅ Simulink hoàn tất — {simulink_model} (t={t_stop:.1f}s)")
            self.lbl_matlab_status.setStyleSheet("color: green; font-weight: bold;")

        except Exception as e:
            err = str(e)
            self.lbl_matlab_status.setText("❌ Lỗi Simulink")
            self.lbl_matlab_status.setStyleSheet("color: red; font-weight: bold;")
            QMessageBox.critical(self, "Lỗi Simulink", f"MATLAB báo lỗi:\n{err}")

    def _pause_simulink(self):
        """Tạm dừng Simulink đang chạy."""
        if not hasattr(self, '_matlab_eng') or self._matlab_eng is None:
            return
        if not self.simulink_model_name:
            return
        try:
            self._matlab_eng.eval(
                f"set_param('{self.simulink_model_name}', "
                f"'SimulationCommand', 'pause');", nargout=0)
        except Exception as e:
            QMessageBox.warning(self, "Lỗi", f"Không thể tạm dừng:\n{e}")

    def _continue_simulink(self):
        """Tiếp tục Simulink sau khi tạm dừng."""
        if not hasattr(self, '_matlab_eng') or self._matlab_eng is None:
            return
        if not self.simulink_model_name:
            return
        try:
            self._matlab_eng.eval(
                f"set_param('{self.simulink_model_name}', "
                f"'SimulationCommand', 'continue');", nargout=0)
        except Exception as e:
            QMessageBox.warning(self, "Lỗi", f"Không thể tiếp tục:\n{e}")

    def _stop_simulink(self):
        """Dừng hẳn Simulink."""
        if not hasattr(self, '_matlab_eng') or self._matlab_eng is None:
            return
        if not self.simulink_model_name:
            return
        try:
            self._matlab_eng.eval(
                f"set_param('{self.simulink_model_name}', "
                f"'SimulationCommand', 'stop');", nargout=0)
            self.lbl_matlab_status.setText("⏹ Simulink đã dừng")
            self.lbl_matlab_status.setStyleSheet("color: gray; font-weight: bold;")
        except Exception as e:
            QMessageBox.warning(self, "Lỗi", f"Không thể dừng:\n{e}")

    def _disconnect_matlab(self):
        """Ngắt kết nối MATLAB Engine — giải phóng bộ nhớ."""
        if hasattr(self, '_matlab_eng') and self._matlab_eng is not None:
            try:
                self._matlab_eng.quit()
            except Exception:
                pass
            self._matlab_eng = None
            self.lbl_matlab_status.setText("⬜ MATLAB Engine chưa kết nối")
            self.lbl_matlab_status.setStyleSheet("color: gray;")
    def _build_panel_mech(self):
        # giữ nguyên như mã gốc
        grp = QGroupBox("1. Thông số Cơ khí")
        grp.setFont(QFont("Arial", 9, QFont.Bold))
        grp.setFixedWidth(330)
        g = QGridLayout(grp)
        g.setSpacing(4)

        def _add_row(grid, row, lbl1, attr1, val1, lbl2=None, attr2=None, val2=None):
            grid.addWidget(QLabel(lbl1), row, 0)
            ed1 = QLineEdit(str(val1)); ed1.setFixedWidth(70)
            setattr(self, attr1, ed1)
            grid.addWidget(ed1, row, 1)
            if lbl2:
                grid.addWidget(QLabel(lbl2), row, 2)
                ed2 = QLineEdit(str(val2)); ed2.setFixedWidth(70)
                setattr(self, attr2, ed2)
                grid.addWidget(ed2, row, 3)

        _add_row(g, 0, 'r_a (Đế):', 'ed_ra', 589.66,   'r_b (Bàn):',  'ed_rb',  429.566)
        _add_row(g, 1, 'L1 (Tay dưới):', 'ed_l1', 150, 'L2 (Tay trên):', 'ed_l2', 747)
        _add_row(g, 2, 'alpha_1:', 'ed_a1', 19.45,      'delta_a:',    'ed_da',  38.9)
        _add_row(g, 3, 'beta_1:',  'ed_b1', 53.32,      'delta_b:',    'ed_db',  13.37)

        g.addWidget(QLabel('Đầu người (X,Y,Z):'), 4, 0, 1, 2)
        self.ed_headX = QLineEdit('0');    self.ed_headX.setFixedWidth(55)
        self.ed_headY = QLineEdit('0');    self.ed_headY.setFixedWidth(55)
        self.ed_headZ = QLineEdit('-762'); self.ed_headZ.setFixedWidth(55)
        hbox_head = QHBoxLayout()
        hbox_head.addWidget(self.ed_headX); hbox_head.addWidget(self.ed_headY); hbox_head.addWidget(self.ed_headZ)
        g.addLayout(hbox_head, 4, 2, 1, 2)

        btn_save = QPushButton("LƯU FILE")
        btn_save.setStyleSheet("background:#f0b000; font-weight:bold;")
        btn_save.clicked.connect(self._save_config)
        btn_load = QPushButton("TẢI FILE")
        btn_load.setStyleSheet("background:#4a8c20; color:white; font-weight:bold;")
        btn_load.clicked.connect(self._load_config)
        g.addWidget(btn_save, 5, 0, 1, 2)
        g.addWidget(btn_load, 5, 2, 1, 2)

        btn_update = QPushButton("CẬP NHẬT CẤU HÌNH")
        btn_update.setStyleSheet("background:#0072bb; color:white; font-weight:bold; padding:6px;")
        btn_update.clicked.connect(self._calc_geometry)
        g.addWidget(btn_update, 6, 0, 1, 4)

        self.lbl_status = QLabel("Chưa nạp thông số!")
        self.lbl_status.setStyleSheet("color:red;")
        g.addWidget(self.lbl_status, 7, 0, 1, 4)
        return grp

    def _build_panel_ctrl(self):
        # giữ nguyên như mã gốc
        grp = QGroupBox("2. Thiết lập Quỹ đạo & Xuất file")
        grp.setFont(QFont("Arial", 9, QFont.Bold))
        grp.setFixedWidth(330)
        g = QGridLayout(grp)
        g.setSpacing(4)

        g.addWidget(QLabel('Loại Q.Đạo:'), 0, 0)
        self.dd_traj = QComboBox()
        self.dd_traj.addItems(['[1D] Tịnh tiến Z (Heave)','[1D] Quay Pitch (Gật gù)','[2D] Đường tròn XY','[3D] Cua chữ S (6 DOF)'])
        g.addWidget(self.dd_traj, 0, 1, 1, 3)

        g.addWidget(QLabel('Tâm quay (Pivot):'), 1, 0)
        self.dd_pivot = QComboBox()
        self.dd_pivot.addItems(['Đỉnh Đầu Người Lái','Tâm Bàn Máy','Tọa Độ Bất Kỳ'])
        g.addWidget(self.dd_pivot, 1, 1, 1, 2)
        g.addWidget(QLabel('Home Z:'), 1, 3)
        self.ed_homez = QLineEdit('0'); self.ed_homez.setFixedWidth(50); g.addWidget(self.ed_homez, 1, 4)

        g.addWidget(QLabel('Pivot(X,Y,Z):'), 2, 0)
        self.ed_px = QLineEdit('0');   self.ed_px.setFixedWidth(55)
        self.ed_py = QLineEdit('0');   self.ed_py.setFixedWidth(55)
        self.ed_pz = QLineEdit('200'); self.ed_pz.setFixedWidth(55)
        hb = QHBoxLayout(); hb.addWidget(self.ed_px); hb.addWidget(self.ed_py); hb.addWidget(self.ed_pz)
        g.addLayout(hb, 2, 1, 1, 4)

        g.addWidget(QLabel('T.Gian(s):'), 3, 0)
        self.ed_time = QLineEdit('10'); self.ed_time.setFixedWidth(45); g.addWidget(self.ed_time, 3, 1)
        g.addWidget(QLabel('Tần số(Hz):'), 3, 2)
        self.ed_freq = QLineEdit('0.2'); self.ed_freq.setFixedWidth(45); g.addWidget(self.ed_freq, 3, 3)

        g.addWidget(QLabel('B.Độ Dài(mm):'), 4, 0)
        self.ed_amp_lin = QLineEdit('50'); self.ed_amp_lin.setFixedWidth(55); g.addWidget(self.ed_amp_lin, 4, 1)
        g.addWidget(QLabel('B.Độ Góc(°):'), 4, 2)
        self.ed_amp_ang = QLineEdit('8'); self.ed_amp_ang.setFixedWidth(55); g.addWidget(self.ed_amp_ang, 4, 3)

        g.addWidget(QLabel('Hoặc Import:'), 5, 0)
        self.lbl_file = QLabel('Chưa chọn file'); self.lbl_file.setStyleSheet("color:gray; font-style:italic;")
        g.addWidget(self.lbl_file, 5, 1, 1, 2)
        btn_browse = QPushButton('Browse'); btn_browse.clicked.connect(self._browse_file); g.addWidget(btn_browse, 5, 3)

        g.addWidget(QLabel('Đối tượng trong file:'), 6, 0, 1, 2)
        self.dd_import_type = QComboBox()
        self.dd_import_type.addItems(['Bàn máy (Platform)','Đầu người (Head)','Tâm quay Pivot'])
        g.addWidget(self.dd_import_type, 6, 2, 1, 3)

        btn_run = QPushButton("1. KIỂM ĐỊNH & CHẠY MÔ PHỎNG")
        btn_run.setStyleSheet("background:#3a7a10; color:white; font-weight:bold; font-size:13px; padding:8px;")
        btn_run.clicked.connect(self._run_system)
        g.addWidget(btn_run, 7, 0, 1, 5)

        self.dd_export = QComboBox()
        self.dd_export.addItems(['Bàn máy: 15 tham số (~M)','Bàn máy: 7 tham số (~M)','Đầu người: 15 tham số (~M)','Đầu người: 7 tham số (~M)','Tâm quay Pivot: 15 tham số (~M)','Tâm quay Pivot: 7 tham số (~M)'])
        g.addWidget(self.dd_export, 8, 0, 1, 3)
        btn_export = QPushButton("2. 💾 XUẤT FILE")
        btn_export.setStyleSheet("background:#cc4400; color:white; font-weight:bold;")
        btn_export.clicked.connect(self._export_data)
        g.addWidget(btn_export, 8, 3, 1, 2)

        btn_plot = QPushButton("📈 VẼ ĐỒ THỊ 15 THAM SỐ")
        btn_plot.setStyleSheet("background:#1e88a8; color:white; font-weight:bold;")
        btn_plot.clicked.connect(self._plot_15_params)
        g.addWidget(btn_plot, 9, 0, 1, 5)

        # --- Panel điều khiển Simulink ---
        g.addWidget(QLabel("Tên model (.slx):"), 10, 0, 1, 2)
        self.ed_slx_name = QLineEdit()
        self.ed_slx_name.setPlaceholderText("Để trống = tự tìm")
        self.ed_slx_name.textChanged.connect(
            lambda t: setattr(self, 'simulink_model_name', t.strip()))
        g.addWidget(self.ed_slx_name, 10, 2, 1, 3)

        self.btn_simulink = QPushButton("🚀 CHẠY SIMULINK")
        self.btn_simulink.setStyleSheet(
            "background:#8b0000; color:white; font-weight:bold; padding:5px;")
        self.btn_simulink.clicked.connect(self._run_simulink)
        g.addWidget(self.btn_simulink, 11, 0, 1, 2)

        btn_sim_pause = QPushButton("⏸ TẠM DỪNG")
        btn_sim_pause.setStyleSheet("background:#6a1a8a; color:white; font-weight:bold;")
        btn_sim_pause.clicked.connect(self._pause_simulink)
        g.addWidget(btn_sim_pause, 11, 2, 1, 1)

        btn_sim_continue = QPushButton("▶ TIẾP")
        btn_sim_continue.setStyleSheet("background:#3a7a10; color:white; font-weight:bold;")
        btn_sim_continue.clicked.connect(self._continue_simulink)
        g.addWidget(btn_sim_continue, 11, 3, 1, 1)

        btn_sim_stop = QPushButton("⏹ DỪNG")
        btn_sim_stop.setStyleSheet("background:#444; color:white; font-weight:bold;")
        btn_sim_stop.clicked.connect(self._stop_simulink)
        g.addWidget(btn_sim_stop, 11, 4, 1, 1)

        # Label trạng thái MATLAB Engine + nút ngắt kết nối
        self.lbl_matlab_status = QLabel("⬜ MATLAB Engine chưa kết nối")
        self.lbl_matlab_status.setStyleSheet("color: gray; font-style: italic;")
        g.addWidget(self.lbl_matlab_status, 12, 0, 1, 4)

        btn_disconnect = QPushButton("🔌 Ngắt")
        btn_disconnect.setStyleSheet("background:#555; color:white; font-size:10px;")
        btn_disconnect.setToolTip("Ngắt kết nối MATLAB Engine để giải phóng bộ nhớ")
        btn_disconnect.clicked.connect(self._disconnect_matlab)
        g.addWidget(btn_disconnect, 12, 4, 1, 1)

        return grp
    

    def _build_panel_monitor(self):
        # giữ nguyên
        grp = QGroupBox("GIÁM SÁT TỌA ĐỘ HIỆN TẠI (BÀN MÁY)")
        grp.setFont(QFont("Arial", 9, QFont.Bold))
        grp.setFixedHeight(80)
        h = QHBoxLayout(grp)
        h.setContentsMargins(5, 5, 5, 5)

        self.lbl_t = QLabel("Time: 0.00 s")
        self.lbl_t.setFont(QFont("Arial", 12, QFont.Bold))
        self.lbl_t.setStyleSheet("color: blue;")
        h.addWidget(self.lbl_t)

        coord_widget = QWidget()
        coord_layout = QGridLayout(coord_widget)
        coord_layout.setSpacing(2)
        self.lbl_x = QLabel("X: 0.0"); self.lbl_y = QLabel("Y: 0.0"); self.lbl_z = QLabel("Z: 795.4")
        self.lbl_r = QLabel("Roll: 0.0°"); self.lbl_p = QLabel("Pitch: 0.0°"); self.lbl_yw = QLabel("Yaw: 0.0°")
        for w in (self.lbl_x, self.lbl_y, self.lbl_z, self.lbl_r, self.lbl_p, self.lbl_yw):
            w.setFont(QFont("Arial", 11))
        coord_layout.addWidget(self.lbl_x,0,0); coord_layout.addWidget(self.lbl_y,0,1); coord_layout.addWidget(self.lbl_z,0,2)
        coord_layout.addWidget(self.lbl_r,1,0); coord_layout.addWidget(self.lbl_p,1,1); coord_layout.addWidget(self.lbl_yw,1,2)
        h.addWidget(coord_widget)

        self.btn_start = QPushButton("▶ CHẠY")
        self.btn_start.setStyleSheet("background:#3a7a10; color:white; font-weight:bold; padding:6px 12px;")
        self.btn_start.clicked.connect(self._run_system)
        self.btn_pause = QPushButton("⏸ TẠM DỪNG")
        self.btn_pause.setStyleSheet("background:#6a1a8a; color:white; font-weight:bold; padding:6px 12px;")
        self.btn_pause.clicked.connect(self._pause_anim)
        self.btn_stop = QPushButton("⏹ DỪNG")
        self.btn_stop.setStyleSheet("background:#8a1010; color:white; font-weight:bold; padding:6px 12px;")
        self.btn_stop.clicked.connect(self._stop_anim)
        h.addWidget(self.btn_start); h.addWidget(self.btn_pause); h.addWidget(self.btn_stop)
        return grp

    def _reset_camera(self):
        cam = self.canvas3d.view.camera
        cam.elevation = 30; cam.azimuth = -37.5; cam.distance = 3500; cam.center = (0, 0, 300)
        self.canvas3d.update()

    # ---------- Callbacks (giữ logic, thay thế tính toán) ----------
    def _save_config(self):
        path, _ = QFileDialog.getSaveFileName(self, "Lưu file cấu hình", "RobotConfig.json", "JSON (*.json)")
        if not path: return
        cfg = {k: float(getattr(self, f'ed_{k}').text()) for k in ['ra','rb','l1','l2','a1','da','b1','db','headX','headY','headZ']}
        with open(path, 'w') as f: json.dump(cfg, f, indent=2)
        QMessageBox.information(self, "Thành công", "Đã lưu cấu hình!")

    def _load_config(self):
        path, _ = QFileDialog.getOpenFileName(self, "Chọn file cấu hình", "", "JSON (*.json);;MAT (*.mat)")
        if not path: return
        try:
            with open(path, 'r') as f: cfg = json.load(f)
            for k in ['ra','rb','l1','l2','a1','da','b1','db','headX','headY','headZ']:
                if k in cfg: getattr(self, f'ed_{k}').setText(str(cfg[k]))
            self._calc_geometry()
            QMessageBox.information(self, "Thành công", "Đã tải và áp dụng cấu hình!")
        except Exception as e: QMessageBox.critical(self, "Lỗi", f"Không tải được file:\n{e}")

    def _calc_geometry(self):
        try:
            ra = float(self.ed_ra.text()); rb = float(self.ed_rb.text())
            l1 = float(self.ed_l1.text()); l2 = float(self.ed_l2.text())
            a1 = float(self.ed_a1.text()); da = float(self.ed_da.text())
            b1 = float(self.ed_b1.text()); db = float(self.ed_db.text())
        except ValueError: QMessageBox.critical(self, "Lỗi", "Thông số không hợp lệ!"); return
        self.L1_val = l1; self.L2_val = l2
        self.A_mat, self.B_mat, self.gamma_ang = calc_geometry(ra, rb, l1, l2, a1, da, b1, db)
        self.lbl_status.setText("Đã cập nhật (Sẵn sàng)!"); self.lbl_status.setStyleSheet("color:green;")
        v_head = np.array([float(self.ed_headX.text()), float(self.ed_headY.text()), float(self.ed_headZ.text())])
        home_z = float(self.ed_homez.text())
        self.canvas3d.draw_frame(0,0,home_z,0,0,0, self.A_mat, self.B_mat, self.gamma_ang, self.L1_val, self.L2_val, v_head, np.zeros(3))

    def _browse_file(self):
        path, _ = QFileDialog.getOpenFileName(self, "Chọn file dữ liệu", "", "Data Files (*.csv *.txt)")
        if path:
            self.filepath = path; self.lbl_file.setText(path); self.lbl_file.setStyleSheet("color:black;")
            self.is_validated = False

    def _collect_params(self):
        return {
            'head_x': float(self.ed_headX.text()), 'head_y': float(self.ed_headY.text()), 'head_z': float(self.ed_headZ.text()),
            'home_z': float(self.ed_homez.text()), 'pivot_mode': self.dd_pivot.currentText(),
            'px': float(self.ed_px.text()), 'py': float(self.ed_py.text()), 'pz': float(self.ed_pz.text()),
            't_sim': float(self.ed_time.text()), 'freq': float(self.ed_freq.text()),
            'amp_lin': float(self.ed_amp_lin.text()), 'amp_ang': float(self.ed_amp_ang.text()),
            'traj_mode': self.dd_traj.currentText(), 'import_type': self.dd_import_type.currentText(), 'filepath': self.filepath,
        }

    def _run_system(self):
        if self.A_mat is None: QMessageBox.warning(self, "Lỗi", "Bấm CẬP NHẬT CẤU HÌNH trước!"); return
        self._stop_anim()
        try: params = self._collect_params()
        except Exception as e: QMessageBox.critical(self, "Lỗi dữ liệu", str(e)); return
        # Sinh quỹ đạo thô
        try:
            self.raw_traj = generate_raw_trajectory(params)
        except Exception as e:
            QMessageBox.critical(self, "Lỗi tạo quỹ đạo", str(e)); return
        # Kiểm tra an toàn và tính toán tổng hợp một lần duy nhất
        N = len(self.raw_traj['t'])
        prog = QProgressDialog("Đang kiểm định và tính toán...", "Huỷ", 0, N, self)
        prog.setWindowTitle("Kiểm định"); prog.setMinimumDuration(0); prog.setValue(0)
        try:
            self.results = compute_all_parameters(self.raw_traj, self.A_mat, self.B_mat, self.L1_val, self.L2_val, self.gamma_ang)
        except Exception as e:
            QMessageBox.critical(self, "Lỗi tính toán", str(e)); return
        # Kiểm tra an toàn từng điểm (sử dụng check_safety)
        for k in range(N):
            if prog.wasCanceled(): return
            pose = np.array([self.raw_traj['xp'][k], self.raw_traj['yp'][k], self.raw_traj['zp'][k],
                 self.raw_traj['rp'][k], self.raw_traj['pp'][k], self.raw_traj['ywp'][k],
                 self.raw_traj['t'][k]])
            ok, msg = check_safety(pose, self.A_mat, self.B_mat, self.L1_val, self.L2_val, self.gamma_ang)
            if not ok:
                prog.close()
                QMessageBox.critical(self, "Lỗi", f"QUỸ ĐẠO KHÔNG KHẢ THI!\nt={self.raw_traj['t'][k]:.2f}s: {msg}")
                self.is_validated = False; return
            prog.setValue(k+1)
        prog.close()
        self.is_validated = True
        # Chạy hoạt ảnh với raw_traj
        step = max(1, N//150)
        self.anim_thread = AnimationThread(self.raw_traj, step)
        self.anim_thread.frame_signal.connect(self._on_frame)
        self.anim_thread.done_signal.connect(self._on_anim_done)
        self.anim_thread.start()

    def _on_frame(self, i, xp, yp, zp, rp, pp, ywp):
        t = self.raw_traj['t']
        self.lbl_t.setText(f"Time: {t[i]:.2f} s")
        self.lbl_x.setText(f"X: {xp:.1f}"); self.lbl_y.setText(f"Y: {yp:.1f}"); self.lbl_z.setText(f"Z: {zp:.1f}")
        self.lbl_r.setText(f"Roll: {rp:.1f}°"); self.lbl_p.setText(f"Pitch: {pp:.1f}°"); self.lbl_yw.setText(f"Yaw: {ywp:.1f}°")
        v_head = np.array([float(self.ed_headX.text()), float(self.ed_headY.text()), float(self.ed_headZ.text())])
        v_pivot = self.raw_traj['v_pivot']
        trail_v = np.column_stack([self.raw_traj['xv'][:i+1], self.raw_traj['yv'][:i+1], self.raw_traj['zv'][:i+1]]) if i>0 else None
        trail_h = np.column_stack([self.raw_traj['x_hd'][:i+1], self.raw_traj['y_hd'][:i+1], self.raw_traj['z_hd'][:i+1]]) if i>0 else None
        self.canvas3d.draw_frame(xp, yp, zp, rp, pp, ywp, self.A_mat, self.B_mat, self.gamma_ang, self.L1_val, self.L2_val, v_head, v_pivot, trail_v, trail_h)

    def _on_anim_done(self):
        self.btn_pause.setText("⏸ TẠM DỪNG"); self.btn_pause.setStyleSheet("background:#6a1a8a; color:white; font-weight:bold; padding:6px 12px;")

    def _pause_anim(self):
        if self.anim_thread and self.anim_thread.isRunning():
            if not self.anim_thread._paused:
                self.anim_thread.pause(); self.btn_pause.setText("▶ TIẾP TỤC"); self.btn_pause.setStyleSheet("background:#cc8800; color:white; font-weight:bold; padding:6px 12px;")
            else:
                self.anim_thread.resume(); self.btn_pause.setText("⏸ TẠM DỪNG"); self.btn_pause.setStyleSheet("background:#6a1a8a; color:white; font-weight:bold; padding:6px 12px;")

    def _stop_anim(self):
        if self.anim_thread:
            self.anim_thread.stop(); self.anim_thread.wait(2000); self.anim_thread = None
        self.btn_pause.setText("⏸ TẠM DỪNG"); self.btn_pause.setStyleSheet("background:#6a1a8a; color:white; font-weight:bold; padding:6px 12px;")

    def _export_data(self):
        if not self.is_validated or self.results is None:
            QMessageBox.warning(self, "Lỗi", "Chưa có dữ liệu an toàn! Hãy bấm KIỂM ĐỊNH & CHẠY trước."); return
        fmt = self.dd_export.currentText()
        if 'Đầu người' in fmt:
            X = self.results['Xh']; Y = self.results['Yh']; Z = self.results['Zh']; def_name = 'Head_Command.csv'
        elif 'Tâm quay Pivot' in fmt:
            X = self.results['Xv']; Y = self.results['Yv']; Z = self.results['Zv']; def_name = 'Pivot_Command.csv'
        else:
            X = self.results['Xp']; Y = self.results['Yp']; Z = self.results['Zp']; def_name = 'Platform_Command.csv'
        path, _ = QFileDialog.getSaveFileName(self, "Lưu file CSV (~M)", def_name, "CSV (*.csv)")
        if not path: return
        t = self.results['t']; rp = self.results['Rp']; pp = self.results['Pp']; yw = self.results['Yw']
        N = len(t)
        with open(path, 'w') as f:
            if '15 tham số' in fmt:
                # Dùng kết quả đã tính đúng từ compute_all_parameters
                # Khớp MATLAB: ax_i,ay_i,az_i + axg,ayg,azg + wz_b,wy_b,wx_b
                ax_i = self.results['ax_i']; ay_i = self.results['ay_i']; az_i = self.results['az_i']
                ax_g = self.results['ax_g']; ay_g = self.results['ay_g']; az_g = self.results['az_g']
                wz_b = self.results['wz_b']; wy_b = self.results['wy_b']; wx_b = self.results['wx_b']
                for k in range(N):
                    f.write(f"{t[k]:.4f} ~M[ {X[k]:.4f} {Y[k]:.4f} {Z[k]:.4f} "
                            f"{yw[k]:.4f} {pp[k]:.4f} {rp[k]:.4f} "
                            f"[ {ax_i[k]:.4f} {ay_i[k]:.4f} {az_i[k]:.4f} "
                            f"{ax_g[k]:.4f} {ay_g[k]:.4f} {az_g[k]:.4f} "
                            f"{wz_b[k]:.4f} {wy_b[k]:.4f} {wx_b[k]:.4f} ]]\n")
            else:
                for k in range(N):
                    f.write(f"{t[k]:.4f} ~M[ {X[k]:.4f} {Y[k]:.4f} {Z[k]:.4f} {yw[k]:.4f} {pp[k]:.4f} {rp[k]:.4f} ]\n")
        QMessageBox.information(self, "Hoàn tất", "Đã xuất file thành công!")

    def _plot_15_params(self):
        if not self.is_validated or self.results is None:
            QMessageBox.warning(self, "Lỗi", "Chưa có dữ liệu quỹ đạo! Hãy chạy mô phỏng trước."); return
        fmt = self.dd_export.currentText()
        if 'Đầu người' in fmt: title_str = 'Quỹ đạo Đầu người'
        elif 'Tâm quay Pivot' in fmt: title_str = 'Quỹ đạo Tâm quay Pivot'
        else: title_str = 'Quỹ đạo Bàn máy'
        self._plot_win = PlotWindowTabs(self.results, title_str)
        self._plot_win.show()
class HelpDialog(QMainWindow):
    """Cửa sổ hướng dẫn dạng tab, giải thích các tham số & đại lượng."""
    def __init__(self, parent=None):
        super().__init__(parent)
        self.setWindowTitle("Hướng dẫn sử dụng - Dashboard Stewart Platform")
        self.resize(900, 600)
        self.tabs = QTabWidget()
        self.setCentralWidget(self.tabs)

        # Tab 1: Thông số cơ khí
        self.tab_mech = self._create_tab_mech()
        self.tabs.addTab(self.tab_mech, "Thông số Cơ khí")

        # Tab 2: Thiết lập quỹ đạo
        self.tab_traj = self._create_tab_traj()
        self.tabs.addTab(self.tab_traj, "Thiết lập Quỹ đạo")

        # Tab 3: Đại lượng trong đồ thị
        self.tab_graph = self._create_tab_graph()
        self.tabs.addTab(self.tab_graph, "Đồ thị & File xuất")

        # Tab 4: An toàn & Giới hạn
        self.tab_safety = self._create_tab_safety()
        self.tabs.addTab(self.tab_safety, "An toàn & Giới hạn")

    def _create_tab_mech(self):
        w = QWidget()
        layout = QVBoxLayout(w)
        text = QTextBrowser()
        text.setHtml("""
        <style>
            body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
            h2 { color: #0056b3; border-bottom: 2px solid #0056b3; padding-bottom: 5px; margin-top: 20px; }
            h3 { color: #d35400; margin-bottom: 5px; }
            ul { margin-top: 5px; }
            li { margin-bottom: 8px; }
            .highlight { background-color: #f8f9fa; padding: 10px; border-left: 4px solid #28a745; margin-bottom: 15px; }
            .warning { background-color: #fff3cd; padding: 10px; border-left: 4px solid #ffc107; color: #856404; }
        </style>

        <h2>1. Ý Nghĩa Các Thông Số Cơ Khí</h2>
        <div class="highlight">
            <h3>Hệ tọa độ & Kích thước (Đơn vị: mm)</h3>
            <ul>
                <li><b>r_a (Base Radius):</b> Bán kính đường tròn đi qua tâm các khớp gắn trên bệ đế cố định.</li>
                <li><b>r_b (Platform Radius):</b> Bán kính đường tròn đi qua tâm các khớp cầu gắn trên mặt bàn di động. <i>(Thường r_a > r_b để đảm bảo độ vững chãi).</i></li>
                <li><b>L1 (Crank Length):</b> Chiều dài tay quay cơ khí (tính từ trục động cơ Servo đến khớp nối chữ U).</li>
                <li><b>L2 (Rod Length):</b> Chiều dài tay đòn / thanh đẩy (tính từ khớp nối tay quay đến khớp cầu trên bàn máy).</li>
                <li><b>Đầu người (X, Y, Z):</b> Tọa độ của điểm nhìn (đầu người lái) so với gốc tọa độ trung tâm của bàn máy. Thông số này quyết định độ văng ly tâm khi hệ thống tính toán thuật toán Tâm quay (Motion Cueing).</li>
            </ul>

            <h3>Phân bố góc (Đơn vị: Độ °)</h3>
            <ul>
                <li><b>alpha_1 & delta_a:</b> Cấu hình cụm bệ đế. <i>alpha_1</i> là góc định hướng của chân thứ nhất. <i>delta_a</i> là khoảng cách góc giữa hai chân nằm trong cùng một cụm tam giác.</li>
                <li><b>beta_1 & delta_b:</b> Cấu hình cụm bàn máy. Tương tự bệ đế, dùng để nội suy tọa độ 6 khớp trên bệ mặt di động.</li>
            </ul>
        </div>

        <h2>2. Hướng Dẫn Sử Dụng</h2>
        <ul>
            <li><b>Bước 1:</b> Đo đạc thông số thực tế của cơ cấu cơ khí và nhập chính xác vào các ô nhập liệu.</li>
            <li><b>Bước 2 (Lưu trữ):</b> Bấm nút <b>LƯU FILE</b> để xuất cấu hình ra định dạng file (.mat / .json / .ini) phục vụ cho các lần chạy sau, tránh phải nhập lại thủ công.</li>
            <li><b>Bước 3 (Khởi tạo):</b> Bấm nút <b>CẬP NHẬT CẤU HÌNH</b>. Phần mềm sẽ tính toán lại toàn bộ ma trận Động học ($A\_mat, B\_mat$) và làm mới bản sao số (Digital Twin) trên màn hình 3D dựa theo dữ liệu mới.</li>
        </ul>

        <h2>3. Lưu Ý & Cảnh Báo An Toàn</h2>
        <div class="warning">
            <ul>
                <li><b>Sai số đơn vị:</b> Đảm bảo tuyệt đối đơn vị nhập vào là <b>Milimet (mm)</b> và <b>Độ (°)</b>. Nhầm lẫn sang Mét hoặc Radian sẽ khiến hệ thống tính toán sinh ra nội lực phá vỡ cơ khí.</li>
                <li><b>Tỷ lệ L1 / L2:</b> Tay đòn (L2) phải luôn dài hơn tay quay (L1) đáng kể. Nếu nhập L1 quá lớn hoặc L2 quá ngắn, hệ thống sẽ liên tục báo lỗi "Kịch giới hạn tầm với" hoặc rơi vào điểm kỳ dị động học (Singularity).</li>
                <li><b>Chiều trục Z của Đầu người:</b> Tùy thuộc vào quy ước hệ tọa độ bạn đang dùng, hãy cẩn thận với dấu của trục Z. Nếu trục Z hướng xuống mặt đất, điểm đầu người nằm bên trên bàn máy sẽ phải mang giá trị <b>Âm (-)</b>.</li>
                <li><b>Không thay đổi khi đang chạy:</b> Mọi thao tác "Cập nhật cấu hình" chỉ được thực hiện khi bàn máy đang ở trạng thái dừng an toàn (Home/Park). Tuyệt đối không thay đổi thông số khi hệ thống đang xuất xung chạy mô phỏng.</li>
            </ul>
        </div>
        """)
        text.setOpenExternalLinks(True)
        text.setReadOnly(True)
        layout.addWidget(text)
        return w

    def _create_tab_traj(self):
        w = QWidget()
        layout = QVBoxLayout(w)
        text = QTextBrowser()
        text.setHtml("""
        <h2>Thiết lập Quỹ đạo & Xuất file</h2>
        <p><b>Loại Q.Đạo</b> – Chọn một mẫu chuyển động có sẵn (Heave, Pitch, Đường tròn, Cua chữ S).</p>
        <p><b>Tâm Sinh</b> – Điểm quy chiếu để tạo quỹ đạo (Pivot). Có thể là Đỉnh Đầu Người Lái, Tâm Bàn Máy, hoặc Tọa Độ Bất Kỳ do bạn nhập.</p>
        <p><b>Home Z (mm)</b> – Vị trí Z ban đầu của bàn máy (khi chưa có chuyển động).</p>
        <p><b>Pivot (X, Y, Z) (mm)</b> – Tọa độ của tâm quay (pivot) trong hệ bàn máy. Mặc định (0, 0, 200).</p>
        <p><b>T.Gian (s)</b> – Tổng thời gian mô phỏng.</p>
        <p><b>Tần số (Hz)</b> – Tần số của chuyển động tuần hoàn (nếu chọn quỹ đạo sin).</p>
        <p><b>B.Độ Dài (mm)</b> – Biên độ tịnh tiến (dùng cho quỹ đạo sin).</p>
        <p><b>B.Độ Góc (°)</b> – Biên độ góc quay (dùng cho quỹ đạo sin).</p>
        <p><b>Import file</b> – Cho phép tải file dữ liệu quỹ đạo định dạng Moog (~M). File có thể chứa 7 hoặc 15 tham số.</p>
        <p><b>Đối tượng trong file</b> – Cho biết file CSV đang mô tả vị trí của <b>Bàn máy</b>, <b>Đầu người</b> hay <b>Tâm quay Pivot</b>. Hệ thống sẽ tự động chuyển đổi về tọa độ bàn máy.</p>
        """)
        text.setReadOnly(True)
        layout.addWidget(text)
        return w

    def _create_tab_graph(self):
        w = QWidget()
        layout = QVBoxLayout(w)
        text = QTextBrowser()
        text.setHtml("""
        <h2>Đồ thị & File xuất</h2>
        <p><b>Vị trí X, Y, Z (mm)</b> – Tọa độ của đối tượng được chọn trong không gian thế giới (world frame).</p>
        <p><b>Góc Yaw, Pitch, Roll (°)</b> – Góc Euler (ZYX) của vật rắn.</p>
        <p><b>Gia tốc dài a<sub>x</sub>, a<sub>y</sub>, a<sub>z</sub> (m/s²)</b> – Gia tốc tịnh tiến của đối tượng trong world frame, được tính từ đạo hàm bậc hai của vị trí.</p>
        <p><b>Gia tốc cảm nhận a<sub>p,x</sub>, a<sub>p,y</sub>, a<sub>p,z</sub> (m/s²)</b> – Gia tốc tổng hợp mà người ngồi trên cabin cảm nhận được, bao gồm cả thành phần trọng lực chiếu lên hệ body.</p>
        <p><b>Vận tốc góc ω<sub>x</sub>, ω<sub>y</sub>, ω<sub>z</sub> (rad/s)</b> – Vận tốc góc của vật rắn trong hệ body frame, tính từ đạo hàm góc Euler.</p>
        <p><b>Góc động cơ (độ)</b> – Góc thực tế của từng motor (1..6), giới hạn cho phép: <span style="color:red">-70° đến 100°</span>.</p>
        <p>Khi xuất file CSV 15 tham số, các cột theo thứ tự: <i>t, X, Y, Z, Yaw, Pitch, Roll, ax, ay, az, axg, ayg, azg, ω<sub>z</sub>, ω<sub>y</sub>, ω<sub>x</sub></i> (axg,ayg,azg là hình chiếu trọng lực lên body).</p>
        """)
        text.setReadOnly(True)
        layout.addWidget(text)
        return w

    def _create_tab_safety(self):
        w = QWidget()
        layout = QVBoxLayout(w)
        text = QTextBrowser()
        text.setHtml("""
        <h2>An toàn & Giới hạn</h2>
        <p><b>Lỗi 1 – Giới hạn cơ khí (kịch)</b>: Xuất hiện khi một chân không thể duỗi đủ dài hoặc co đủ ngắn để đạt tới vị trí yêu cầu. Nguyên nhân: tay đòn L1+L2 không đủ dài. Thông báo sẽ chỉ rõ chân nào và thời điểm xảy ra.</p>
        <p><b>Lỗi 2 – Vượt quá giới hạn động cơ</b>: Góc servo tính được nằm ngoài khoảng <span style="color:red">-70° .. 100°</span>. Thông báo sẽ cho biết chân nào bị vượt, góc bao nhiêu độ.</p>
        <p><b>Lỗi 3 – Điểm kỳ dị</b>: Xảy ra khi định thức của ma trận Jacobian tiến gần bằng 0, tức platform đang ở tư thế suy biến (mất bậc tự do). Lúc này không thể điều khiển được.</p>
        <p>Hệ thống sẽ kiểm tra từng điểm trên quỹ đạo trước khi chạy mô phỏng. Nếu phát hiện lỗi, một hộp thoại sẽ hiện ra và dừng quá trình.</p>
        """)
        text.setReadOnly(True)
        layout.addWidget(text)
        return w

def main():
    vispy_app.use_app('pyqt5')
    qt_app = QApplication(sys.argv); qt_app.setStyle('Fusion')
    window = DashboardWindow(); window.show()
    sys.exit(qt_app.exec_())

if __name__ == '__main__':
    main()