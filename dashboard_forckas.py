#!/usr/bin/env python3
import sys, re, time
import numpy as np
from numpy.linalg import norm, det

from PyQt5.QtWidgets import (
    QApplication, QMainWindow, QWidget, QLabel, QPushButton,
    QVBoxLayout, QHBoxLayout, QFileDialog, QMessageBox
)
from PyQt5.QtCore import Qt, QThread, pyqtSignal
from PyQt5.QtGui import QFont

import vispy.scene as scene
from vispy.scene import visuals
from vispy import app as vispy_app

# ========== HẰNG SỐ CƠ KHÍ ==========


Z_A             = 668.4 

# Thông số cơ khí mặc định (có thể điều chỉnh nếu cần)
RA = 589.66
RB = 429.566
L1 = 150.0
L2 = 747.0
A1 = 19.45
DA = 38.9
B1 = 53.32
DB = 13.37

# ========== ĐỘNG HỌC CƠ BẢN ==========
SERVO_MIN_DEG   = -50
SERVO_MAX_DEG   = 90
SINGULARITY_TOL = 1e-3

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

# ========== MESH 3D ==========
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

# ========== CANVAS 3D ==========
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
        self._labels_A = [visuals.Text(f'A{i+1}', parent=self._scene_node, color='black', font_size=10) for i in range(6)]
        self._labels_B = [visuals.Text(f'B{i+1}', parent=self._scene_node, color='blue', font_size=10) for i in range(6)]
        self._create_grid_and_axes()
        self.freeze()

    def _create_grid_and_axes(self):
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
        create_axis([0,1,0], (0.2,1.0,0.2,1.0), 'Y')
        create_axis([0,0,1], (0.2,0.4,1.0,1.0), 'Z')

    def draw_frame(self, x, y, z, roll, pitch, yaw, A_mat, B_mat, gamma, l1, l2):
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
            Cz = A_i[2] + l1*np.sin(np.radians(phi))
            C_i = np.array([Cx, Cy, Cz])
            
            for j, (p_s, p_e, r, color) in enumerate([(A_i, C_i, 18, [0.4,0.4,0.4,1.0]), (C_i, P_i, 12, [0.8,0.0,0.0,1.0])]):
                verts, faces = _make_cylinder_mesh(p_s, p_e, r, 12)
                if verts is not None:
                    self._leg_meshes[i*2+j].set_data(vertices=verts.astype(np.float32), faces=faces,
                                                     face_colors=np.tile(color, (len(faces),1)))
            self._labels_A[i].pos = A_i + [0,0,-40]
            self._labels_B[i].pos = P_i + [0,0,40]
        self.update()

# ========== THREAD HOẠT ẢNH ==========
class AnimationThread(QThread):
    frame_signal = pyqtSignal(int, float, float, float, float, float, float)
    done_signal = pyqtSignal()
    
    def __init__(self, data):
        super().__init__()
        self.data = data # Mảng Nx7: [t, x, y, z, yaw, pitch, roll]
        self._playing = True
        
    def stop(self): 
        self._playing = False
        
    def run(self):
        N = len(self.data)
        if N == 0:
            self.done_signal.emit()
            return
            
        t0 = time.time()
        start_sim_time = self.data[0, 0]
        last_emit_time = 0
        
        for i in range(N):
            if not self._playing: break
            
            row = self.data[i]
            t_sim = row[0]
            
            # Căn chỉnh thời gian thực
            elapsed_real = time.time() - t0
            elapsed_sim = t_sim - start_sim_time
            if elapsed_sim > elapsed_real:
                self.msleep(int((elapsed_sim - elapsed_real) * 1000))
                
            # Giới hạn tốc độ cập nhật UI (~60FPS)
            if time.time() - last_emit_time > 0.016:
                # row[1..3] = X, Y, Z
                # row[4..6] = Yaw, Pitch, Roll
                self.frame_signal.emit(i, row[1], row[2], row[3], row[6], row[5], row[4]) 
                last_emit_time = time.time()
                
        # Luôn emit frame cuối cùng
        if self._playing and N > 0:
            row = self.data[-1]
            self.frame_signal.emit(N-1, row[1], row[2], row[3], row[6], row[5], row[4])
            
        self.done_signal.emit()

# ========== CỬA SỔ CHÍNH ==========
class DashboardMCodeApp(QMainWindow):
    def __init__(self):
        super().__init__()
        self.setWindowTitle("Trình Chơi M-Code 3D - Stewart Platform")
        self.resize(1000, 700)
        
        # Khởi tạo ma trận động học
        self.A_mat, self.B_mat, self.gamma_ang = calc_geometry(RA, RB, L1, L2, A1, DA, B1, DB)
        
        self.data = None
        self.anim_thread = None
        
        self._build_ui()
        
        # Vẽ frame đầu tiên ở vị trí gốc
        self.canvas3d.draw_frame(0, 0, 0, 0, 0, 0, self.A_mat, self.B_mat, self.gamma_ang, L1, L2)

    def _build_ui(self):
        central = QWidget()
        self.setCentralWidget(central)
        layout = QVBoxLayout(central)

        # Thanh điều khiển (Trên cùng)
        ctrl_layout = QHBoxLayout()
        
        self.btn_load = QPushButton("📂 Tải file M-Code")
        self.btn_load.clicked.connect(self._load_file)
        self.btn_load.setStyleSheet("padding: 8px; font-weight: bold; background-color: #e0e0e0;")
        ctrl_layout.addWidget(self.btn_load)
        
        self.lbl_file = QLabel("Chưa chọn file")
        self.lbl_file.setStyleSheet("color: gray; font-style: italic;")
        ctrl_layout.addWidget(self.lbl_file)
        
        ctrl_layout.addStretch()
        
        self.lbl_info = QLabel("X: 0.0 | Y: 0.0 | Z: 0.0 | Y: 0.0° | P: 0.0° | R: 0.0°")
        self.lbl_info.setFont(QFont("Arial", 10, QFont.Bold))
        ctrl_layout.addWidget(self.lbl_info)
        
        self.btn_play = QPushButton("▶ Chạy mô phỏng")
        self.btn_play.clicked.connect(self._toggle_play)
        self.btn_play.setStyleSheet("padding: 8px; font-weight: bold; background-color: #4CAF50; color: white;")
        self.btn_play.setEnabled(False)
        ctrl_layout.addWidget(self.btn_play)
        
        layout.addLayout(ctrl_layout)

        # Canvas 3D
        self.canvas3d = StewartCanvas3D()
        layout.addWidget(self.canvas3d.native, stretch=1)

    def _load_file(self):
        path, _ = QFileDialog.getOpenFileName(self, "Chọn file M-Code", "", "CSV/Text Files (*.csv *.txt);;All Files (*)")
        if not path: return
        
        try:
            pattern = re.compile(r'[-+]?\d*\.?\d+(?:[eE][-+]?\d+)?')
            rows = []
            with open(path, 'r', encoding='utf-8', errors='ignore') as f:
                for line in f:
                    nums = pattern.findall(line)
                    if nums and len(nums) >= 7:
                        # Lấy t, X, Y, Z, Yaw, Pitch, Roll
                        rows.append([float(x) for x in nums[:7]])
            
            if not rows:
                raise ValueError("Không tìm thấy dữ liệu hợp lệ trong file (cần ít nhất 7 số: t, X, Y, Z, Yaw, Pitch, Roll).")
                
            # Kiểm tra an toàn toàn bộ quỹ đạo trước khi nạp
            for i, row in enumerate(rows):
                # pose = [X, Y, Z, Roll, Pitch, Yaw, t]
                pose_for_check = np.array([row[1], row[2], row[3], row[6], row[5], row[4], row[0]])
                ok, msg = check_safety(pose_for_check, self.A_mat, self.B_mat, L1, L2, self.gamma_ang)
                if not ok:
                    raise ValueError(f"Quỹ đạo không an toàn tại dòng {i+1}:\n{msg}")
                    
            self.data = np.array(rows)
            self.lbl_file.setText(path)
            self.lbl_file.setStyleSheet("color: black;")
            self.btn_play.setEnabled(True)
            self.btn_play.setText("▶ Chạy mô phỏng")
            self.btn_play.setStyleSheet("padding: 8px; font-weight: bold; background-color: #4CAF50; color: white;")
            
            QMessageBox.information(self, "Thành công", f"Đã nạp {len(self.data)} điểm quỹ đạo.")
            
            # Reset về vị trí đầu tiên
            row0 = self.data[0]
            self._update_display(row0[1], row0[2], row0[3], row0[6], row0[5], row0[4])
            
        except Exception as e:
            QMessageBox.critical(self, "Lỗi nạp file", str(e))

    def _update_display(self, x, y, z, r, p, yw):
        self.lbl_info.setText(f"X: {x:.1f} | Y: {y:.1f} | Z: {z:.1f} | Yaw: {yw:.1f}° | Pitch: {p:.1f}° | Roll: {r:.1f}°")
        self.canvas3d.draw_frame(x, y, z, r, p, yw, self.A_mat, self.B_mat, self.gamma_ang, L1, L2)

    def _toggle_play(self):
        if self.anim_thread and self.anim_thread.isRunning():
            self.anim_thread.stop()
            self.btn_play.setText("▶ Chạy mô phỏng")
            self.btn_play.setStyleSheet("padding: 8px; font-weight: bold; background-color: #4CAF50; color: white;")
        else:
            if self.data is None: return
            self.anim_thread = AnimationThread(self.data)
            self.anim_thread.frame_signal.connect(self._on_frame)
            self.anim_thread.done_signal.connect(self._on_done)
            self.anim_thread.start()
            self.btn_play.setText("⏹ Dừng mô phỏng")
            self.btn_play.setStyleSheet("padding: 8px; font-weight: bold; background-color: #F44336; color: white;")

    def _on_frame(self, i, x, y, z, r, p, yw):
        self._update_display(x, y, z, r, p, yw)

    def _on_done(self):
        self.btn_play.setText("▶ Chạy lại")
        self.btn_play.setStyleSheet("padding: 8px; font-weight: bold; background-color: #4CAF50; color: white;")

def main():
    vispy_app.use_app('pyqt5')
    app = QApplication(sys.argv)
    app.setStyle('Fusion')
    win = DashboardMCodeApp()
    win.show()
    sys.exit(app.exec_())

if __name__ == '__main__':
    main()
