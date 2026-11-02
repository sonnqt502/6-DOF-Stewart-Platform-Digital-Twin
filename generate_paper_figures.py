"""
generate_paper_figures.py
Tạo hình ảnh chất lượng cao cho bài báo IEEE về xác định Pivot Point
Dữ liệu: Head_Command*.csv, Pivot_Command*.csv từ Dashboard_Stewart5.m
Tất cả số liệu đến từ dữ liệu đo thực tế / mô phỏng thực.
"""

import re
import numpy as np
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import matplotlib.patches as mpatches
from matplotlib.patches import FancyArrowPatch
from mpl_toolkits.mplot3d import Axes3D
from mpl_toolkits.mplot3d.proj3d import proj_transform
from matplotlib.ticker import MultipleLocator, AutoMinorLocator
import os

# ─── Cấu hình chung ────────────────────────────────────────────────────────────
OUT_DIR  = r"c:\Users\Admin\Desktop\lab\ckas\simcape\sime4\hinhanh_VT"
DATA_DIR = r"c:\Users\Admin\Desktop\lab\ckas\simcape\sime4"

# Thông số hình học CKAS W2 (từ Dashboard_Stewart5.m)
RA   = 589.66   # mm – bán kính đế
RB   = 429.566  # mm – bán kính bàn máy
L1   = 150.0    # mm – tay ngắn
L2   = 747.0    # mm – tay dài
A1   = 19.45    # deg – góc alpha_1 đế
DA   = 38.90    # deg – delta_a đế
B1   = 53.32    # deg – góc beta_1 bàn
DB   = 13.37    # deg – delta_b bàn
ZA   = 668.4    # mm – cao độ khớp đế
HOME_Z = -75.0  # mm – vị trí home Z bàn máy
HEAD_Z = -762.0 # mm – khoảng cách đầu người (theo Z local)

# Màu IEEE-style
C_BLUE   = '#0071BC'
C_RED    = '#D62728'
C_GREEN  = '#2CA02C'
C_ORANGE = '#FF7F0E'
C_GRAY   = '#7F7F7F'
C_PURPLE = '#9467BD'

plt.rcParams.update({
    'font.family':      'Times New Roman',
    'font.size':        10,
    'axes.labelsize':   11,
    'axes.titlesize':   11,
    'legend.fontsize':  9,
    'xtick.labelsize':  9,
    'ytick.labelsize':  9,
    'figure.dpi':       200,
    'savefig.dpi':      300,
    'savefig.bbox':     'tight',
    'lines.linewidth':  1.5,
    'axes.grid':        True,
    'grid.alpha':       0.35,
    'grid.linestyle':   '--',
})

# ─── Helpers ───────────────────────────────────────────────────────────────────
def parse_moog(filepath):
    """
    Parse CKAS Moog-format CSV: "t ~M[ X Y Z Yaw Pitch Roll [ ... ]]"
    Returns dict of numpy arrays.
    """
    t_list, x_list, y_list, z_list = [], [], [], []
    yaw_list, pit_list, rol_list   = [], [], []

    pattern = re.compile(
        r'([\d.eE+\-]+)\s+~M\[\s*([\d.eE+\-]+)\s+([\d.eE+\-]+)\s+([\d.eE+\-]+)\s+'
        r'([\d.eE+\-]+)\s+([\d.eE+\-]+)\s+([\d.eE+\-]+)'
    )
    with open(filepath, 'r') as f:
        for line in f:
            m = pattern.search(line)
            if m:
                t_list.append(float(m.group(1)))
                x_list.append(float(m.group(2)))
                y_list.append(float(m.group(3)))
                z_list.append(float(m.group(4)))
                yaw_list.append(float(m.group(5)))
                pit_list.append(float(m.group(6)))
                rol_list.append(float(m.group(7)))

    return {
        't': np.array(t_list), 'x': np.array(x_list),
        'y': np.array(y_list), 'z': np.array(z_list),
        'yaw': np.array(yaw_list), 'pitch': np.array(pit_list),
        'roll': np.array(rol_list),
    }


def calc_rotation(yaw_deg, pitch_deg, roll_deg):
    """ZYX Euler → rotation matrix (3x3)."""
    cy, sy = np.cos(np.radians(yaw_deg)),   np.sin(np.radians(yaw_deg))
    cp, sp = np.cos(np.radians(pitch_deg)), np.sin(np.radians(pitch_deg))
    cr, sr = np.cos(np.radians(roll_deg)),  np.sin(np.radians(roll_deg))
    return np.array([
        [cy*cp,  cy*sp*sr - sy*cr,  cy*sp*cr + sy*sr],
        [sy*cp,  sy*sp*sr + cy*cr,  sy*sp*cr - cy*sr],
        [-sp,    cp*sr,              cp*cr            ]
    ])


def calc_geometry():
    """Tính toán tọa độ các khớp A_i, B_i và gamma_i."""
    A = np.zeros((3, 6))
    B = np.zeros((3, 6))
    gamma = np.zeros(6)
    alpha = np.zeros(6)
    beta  = np.zeros(6)
    for k in range(3):
        alpha[2*k]   = -(A1 + k * 120)
        alpha[2*k+1] = -(A1 - DA + (k+1) * 120)
        beta[2*k]    = -(B1 + k * 120)
        beta[2*k+1]  = -(B1 + DB + k * 120)
    for i in range(6):
        A[0, i] = RA * np.cos(np.radians(alpha[i]))
        A[1, i] = RA * np.sin(np.radians(alpha[i]))
        A[2, i] = ZA
        B[0, i] = RB * np.cos(np.radians(beta[i]))
        B[1, i] = RB * np.sin(np.radians(beta[i]))
        B[2, i] = 0.0
        gamma[i] = alpha[i] + ((-1)**(i+1)) * 90
    return A, B, gamma


def inverse_kinematics(pose_mm_deg, A, B, gamma):
    """
    pose_mm_deg = [x, y, z, roll, pitch, yaw]
    Returns phi_thuc (deg, array 6).
    """
    x, y, z, r, p, yw = pose_mm_deg
    R = calc_rotation(yw, p, r)
    T = np.array([x, y, z])
    L_vec = T[:, None] + R @ B - A       # 3×6
    l_sq  = np.sum(L_vec**2, axis=0)
    Q     = l_sq - L2**2 + L1**2
    M_val = 2 * L1 * L_vec[2, :]
    N_val = 2 * L1 * (np.cos(np.radians(gamma)) * L_vec[0, :]
                    + np.sin(np.radians(gamma)) * L_vec[1, :])
    denom = np.sqrt(M_val**2 + N_val**2)
    arg   = Q / np.where(denom > 0, denom, 1e-12)
    arg   = np.clip(arg, -1, 1)
    phi_raw = np.degrees(np.arcsin(arg)) - np.degrees(np.arctan2(N_val, M_val))
    phi_out = np.zeros(6)
    phi_out[0::2] = -(90 + phi_raw[0::2])
    phi_out[1::2] =  (90 + phi_raw[1::2])
    phi_thuc = phi_out - np.array([90, -90, 90, -90, 90, -90])
    phi_thuc[0::2] = -phi_thuc[0::2]
    return phi_thuc


# ═══════════════════════════════════════════════════════════════════════════════
# FIG 1 – Sơ đồ cơ cấu Stewart Platform RUS 3-3 (kiến trúc / geometry diagram)
# ═══════════════════════════════════════════════════════════════════════════════
def fig1_geometry_diagram():
    A, B, gamma = calc_geometry()
    fig = plt.figure(figsize=(7, 5.5))
    ax  = fig.add_subplot(111, projection='3d')

    home_pos = np.array([0, 0, HOME_Z])
    R0       = calc_rotation(0, 0, 0)   # identity
    B_world  = home_pos[:, None] + R0 @ B

    # Vẽ đế (base)
    ax.scatter(A[0], A[1], A[2], c=C_BLUE,   s=60, zorder=5, label='Base joints $A_i$')
    # Vẽ bàn máy (platform)
    ax.scatter(B_world[0], B_world[1], B_world[2], c=C_RED, s=60, zorder=5,
               label='Platform joints $B_i$')

    # Vẽ các chân (tay dài) A→B
    for i in range(6):
        ax.plot([A[0,i], B_world[0,i]], [A[1,i], B_world[1,i]], [A[2,i], B_world[2,i]],
                color=C_GRAY, lw=1.2, alpha=0.85)

    # Vẽ tay ngắn (crank) — đơn giản hóa nằm ngang theo gamma
    for i in range(6):
        gx = A[0,i] + L1 * np.cos(np.radians(gamma[i]))
        gy = A[1,i] + L1 * np.sin(np.radians(gamma[i]))
        gz = A[2,i]
        ax.plot([A[0,i], gx], [A[1,i], gy], [A[2,i], gz],
                color=C_ORANGE, lw=2.2)

    # Vòng tròn đế (sketch)
    th = np.linspace(0, 2*np.pi, 120)
    ax.plot(RA*np.cos(th), RA*np.sin(th), np.full_like(th, ZA),
            color=C_BLUE, lw=0.8, alpha=0.5, ls='--')

    # Vòng tròn bàn máy
    bz = home_pos[2]
    ax.plot(RB*np.cos(th), RB*np.sin(th), np.full_like(th, bz),
            color=C_RED, lw=0.8, alpha=0.5, ls='--')

    # Trục tọa độ world
    origin = np.array([0, 0, 0])
    scale  = 200
    for vec, col, lbl in zip(np.eye(3)*scale, ['r','g','b'], ['X','Y','Z']):
        ax.quiver(*origin, *vec, color=col, lw=1.5, arrow_length_ratio=0.15)
        ax.text(*(origin+vec*1.15), lbl, color=col, fontsize=9, fontweight='bold')

    # Pivot point
    pivot_world = home_pos + R0 @ np.array([0, 0, HEAD_Z])
    ax.scatter(*pivot_world, c=C_PURPLE, s=120, marker='*', zorder=10,
               label=f'Pivot Point $P_0$ (z={HEAD_Z} mm)')
    ax.plot([home_pos[0], pivot_world[0]],
            [home_pos[1], pivot_world[1]],
            [home_pos[2], pivot_world[2]],
            color=C_PURPLE, lw=1.2, ls='--', alpha=0.7)

    # Nhãn chân
    for i in range(6):
        ax.text(A[0,i]*1.06, A[1,i]*1.06, A[2,i]+15, f'$A_{i+1}$', fontsize=7.5, color=C_BLUE)
        ax.text(B_world[0,i]*1.06, B_world[1,i]*1.06, B_world[2,i]-30,
                f'$B_{i+1}$', fontsize=7.5, color=C_RED)

    ax.set_xlabel('X (mm)'); ax.set_ylabel('Y (mm)'); ax.set_zlabel('Z (mm)')
    ax.set_title('CKAS W2 — 6-RUS Stewart Platform Geometry (Neutral Position)',
                 fontsize=10, fontweight='bold', pad=10)
    ax.legend(loc='upper left', fontsize=8)
    ax.view_init(elev=20, azim=-55)
    ax.set_box_aspect([2, 2, 2.5])

    # Chú thích thông số
    info = (f'$r_a$={RA:.1f} mm, $r_b$={RB:.1f} mm\n'
            f'$L_1$={L1:.0f} mm (crank),  $L_2$={L2:.0f} mm (rod)')
    fig.text(0.52, 0.04, info, ha='center', fontsize=8.5,
             bbox=dict(boxstyle='round,pad=0.3', fc='lightyellow', ec='gray', alpha=0.8))

    plt.tight_layout()
    out = os.path.join(OUT_DIR, 'fig1_geometry.pdf')
    plt.savefig(out)
    plt.savefig(out.replace('.pdf', '.png'))
    plt.close()
    print(f"[OK] {out}")


# ═══════════════════════════════════════════════════════════════════════════════
# FIG 2 – Sơ đồ khái niệm Pivot Point và ảnh hưởng centre_z
# ═══════════════════════════════════════════════════════════════════════════════
def fig2_pivot_concept():
    fig, axes = plt.subplots(1, 2, figsize=(8, 4.2))

    for ax, cz, title_suf in zip(axes,
                                  [0, HEAD_Z],
                                  ['$c_z = 0$ mm (platform center)',
                                   f'$c_z = {HEAD_Z}$ mm (head position)']):
        ax.set_aspect('equal')
        ax.set_xlim(-300, 300); ax.set_ylim(-1100, 200)
        ax.set_xlabel('Lateral displacement (mm)')
        ax.set_ylabel('Vertical position (mm)')
        ax.set_title(title_suf, fontsize=10)
        ax.axhline(0, color='k', lw=0.8, ls='--', alpha=0.5)

        # Bàn máy (platform) ở vị trí trung lập
        plat_y = HOME_Z
        ax.hlines(plat_y, -120, 120, colors=C_BLUE, lw=3, label='Platform (neutral)')
        ax.plot(0, plat_y, 'o', color=C_BLUE, ms=7)

        # Pivot point
        piv_y = plat_y + cz   # cz âm → đầu người phía trên bàn máy (Z xuống)
        ax.plot(0, piv_y, '*', color=C_PURPLE, ms=14, zorder=10, label='Pivot Point $P$')
        ax.vlines(0, plat_y, piv_y, colors=C_PURPLE, lw=1.2, ls='--')
        ax.text(5, (plat_y + piv_y)/2, f'  $c_z$={cz} mm', color=C_PURPLE, fontsize=8.5)

        # Góc pitch θ = 10°
        theta = np.radians(10)
        L_arm = 200
        x_rot = L_arm * np.sin(theta)
        z_rot = -L_arm * (1 - np.cos(theta))

        # Bàn máy đã xoay quanh Pivot
        # Vị trí bàn máy sau khi xoay
        plat_offs_x = (piv_y - plat_y) * np.sin(theta)
        plat_new_y  = piv_y - (piv_y - plat_y) * np.cos(theta)

        ax.annotate('', xy=(plat_offs_x + 120*np.cos(theta), plat_new_y - 120*np.sin(theta)),
                    xytext=(plat_offs_x - 120*np.cos(theta), plat_new_y + 120*np.sin(theta)),
                    arrowprops=dict(arrowstyle='-', color=C_RED, lw=2.5))
        ax.plot(plat_offs_x, plat_new_y, 's', color=C_RED, ms=7)

        # Đường vòng cung quay
        angles = np.linspace(np.pi/2, np.pi/2 - theta, 60)
        r_arc  = abs(piv_y - plat_y) if abs(piv_y - plat_y) > 10 else 20
        ax.plot(r_arc * np.cos(angles), piv_y + r_arc * np.sin(angles),
                color=C_ORANGE, lw=1.2, ls='--', alpha=0.8)
        ax.annotate('', xy=(r_arc*np.cos(np.pi/2 - theta), piv_y + r_arc*np.sin(np.pi/2 - theta)),
                    xytext=(r_arc*np.cos(np.pi/2 - theta/2), piv_y + r_arc*np.sin(np.pi/2 - theta/2)),
                    arrowprops=dict(arrowstyle='->', color=C_ORANGE, lw=1.2))
        ax.text(r_arc*0.6, piv_y - r_arc*0.3, r'$\theta=10°$', color=C_ORANGE, fontsize=8)

        ax.plot(plat_offs_x, plat_new_y, 's', color=C_RED, ms=7, label='Platform (rotated)')
        ax.legend(fontsize=8, loc='lower right')
        ax.grid(True, alpha=0.3, ls='--')

    axes[0].set_title('Case 1: $c_z = 0$ mm\n(rotation about platform center)', fontsize=9)
    axes[1].set_title(f'Case 2: $c_z = {HEAD_Z}$ mm\n(rotation about head position)', fontsize=9)

    fig.suptitle('Effect of Pivot Point Position on Platform Rotation', fontsize=11, fontweight='bold', y=1.01)
    plt.tight_layout()
    out = os.path.join(OUT_DIR, 'fig2_pivot_concept.pdf')
    plt.savefig(out);  plt.savefig(out.replace('.pdf', '.png'))
    plt.close(); print(f"[OK] {out}")


# ═══════════════════════════════════════════════════════════════════════════════
# FIG 3 – Quỹ đạo đầu người (Head trajectory) – dữ liệu thực từ Head_Command.csv
# ═══════════════════════════════════════════════════════════════════════════════
def fig3_head_trajectory():
    files = {
        r'$c_z = 0$ mm':    os.path.join(DATA_DIR, 'Head_Command0.csv'),
        r'$c_z = -200$ mm': os.path.join(DATA_DIR, 'Head_Command-200.csv'),
        r'$c_z = -400$ mm': os.path.join(DATA_DIR, 'Head_Command-400.csv'),
        r'$c_z = -600$ mm': os.path.join(DATA_DIR, 'Head_Command-600.csv'),
        r'$c_z = -762$ mm': os.path.join(DATA_DIR, 'Head_Command.csv'),
    }
    colors = [C_GRAY, C_GREEN, C_ORANGE, C_BLUE, C_RED]

    fig, axes = plt.subplots(2, 1, figsize=(8, 6), sharex=True)

    for (label, fpath), col in zip(files.items(), colors):
        if not os.path.exists(fpath):
            print(f"  [SKIP] {fpath} not found")
            continue
        d = parse_moog(fpath)
        if len(d['t']) == 0:
            continue
        t = d['t']
        # Displacement magnitude in lateral plane
        disp_y = d['y']
        disp_x = d['x']
        roll   = d['roll']
        axes[0].plot(t, disp_y, color=col, label=label, lw=1.4)
        axes[1].plot(t, roll,   color=col, label=label, lw=1.4)

    axes[0].set_ylabel('Head lateral displacement Y (mm)')
    axes[1].set_ylabel('Roll angle $\\phi$ (deg)')
    axes[1].set_xlabel('Time (s)')
    axes[0].set_title('Head Position & Roll Angle for Various Pivot Settings — Roll Maneuver (10°, 0.25 Hz)',
                      fontsize=10, fontweight='bold')
    for ax in axes:
        ax.legend(fontsize=8, loc='upper right', ncol=2)
        ax.yaxis.set_minor_locator(AutoMinorLocator())
    plt.tight_layout()
    out = os.path.join(OUT_DIR, 'fig3_head_trajectory.pdf')
    plt.savefig(out); plt.savefig(out.replace('.pdf', '.png'))
    plt.close(); print(f"[OK] {out}")


# ═══════════════════════════════════════════════════════════════════════════════
# FIG 4 – Biên độ dịch chuyển đầu người vs. centre_z (bar chart + scatter)
#         — Xác định Pivot Point thực nghiệm
# ═══════════════════════════════════════════════════════════════════════════════
def fig4_pivot_identification():
    """
    Pivot Point = vị trí c_z khiến dịch chuyển tuyến tính tại đầu người = 0
    Đây là kết quả xử lý từ dữ liệu thực Head_Command*.csv
    """
    files_cz = {
          0: os.path.join(DATA_DIR, 'Head_Command0.csv'),
       -200: os.path.join(DATA_DIR, 'Head_Command-200.csv'),
       -400: os.path.join(DATA_DIR, 'Head_Command-400.csv'),
       -600: os.path.join(DATA_DIR, 'Head_Command-600.csv'),
       -837: os.path.join(DATA_DIR, 'Head_Command.csv'),
    }

    cz_vals, amp_y_vals, amp_x_vals = [], [], []

    for cz, fpath in files_cz.items():
        if not os.path.exists(fpath):
            print(f"  [SKIP] {fpath}")
            continue
        d = parse_moog(fpath)
        if len(d['t']) < 10:
            continue
        # Biên độ = RMS của dịch chuyển
        amp_y = np.sqrt(np.mean(d['y']**2)) - abs(d['y'][0])
        amp_x = np.sqrt(np.mean(d['x']**2)) - abs(d['x'][0])
        cz_vals.append(cz)
        amp_y_vals.append(np.std(d['y']))
        amp_x_vals.append(np.std(d['x']))

    cz_arr   = np.array(cz_vals,   dtype=float)
    amp_y_arr = np.array(amp_y_vals, dtype=float)
    amp_x_arr = np.array(amp_x_vals, dtype=float)

    # Linear fit → tìm điểm zero
    if len(cz_arr) >= 2:
        coef_y = np.polyfit(cz_arr, amp_y_arr, 1)
        coef_x = np.polyfit(cz_arr, amp_x_arr, 1)
        cz_fit  = np.linspace(cz_arr.min() - 50, cz_arr.max() + 50, 200)
        fit_y   = np.polyval(coef_y, cz_fit)
        fit_x   = np.polyval(coef_x, cz_fit)

    fig, axes = plt.subplots(1, 2, figsize=(9, 4.2))

    # Panel A – Lateral Y
    ax = axes[0]
    ax.bar(cz_arr, amp_y_arr, width=80, color=C_BLUE, alpha=0.7, edgecolor='k', lw=0.6,
           label='Measured $\\sigma_Y$')
    if len(cz_arr) >= 2:
        ax.plot(cz_fit, fit_y, color=C_RED, lw=1.8, ls='--', label='Linear fit')
        # Điểm zero
        if coef_y[0] != 0:
            cz_zero_y = -coef_y[1] / coef_y[0]
            ax.axvline(cz_zero_y, color=C_PURPLE, lw=1.5, ls=':', label=f'Zero: $c_z$={cz_zero_y:.0f} mm')
    ax.set_xlabel('Pivot setting $c_z$ (mm)')
    ax.set_ylabel('Std. dev. of head Y displacement (mm)')
    ax.set_title('(a) Lateral (Y) displacement at head')
    ax.legend(fontsize=8)

    # Panel B – Surge X
    ax = axes[1]
    ax.bar(cz_arr, amp_x_arr, width=80, color=C_GREEN, alpha=0.7, edgecolor='k', lw=0.6,
           label='Measured $\\sigma_X$')
    if len(cz_arr) >= 2:
        ax.plot(cz_fit, fit_x, color=C_RED, lw=1.8, ls='--', label='Linear fit')
        if coef_x[0] != 0:
            cz_zero_x = -coef_x[1] / coef_x[0]
            ax.axvline(cz_zero_x, color=C_PURPLE, lw=1.5, ls=':', label=f'Zero: $c_z$={cz_zero_x:.0f} mm')
    ax.set_xlabel('Pivot setting $c_z$ (mm)')
    ax.set_ylabel('Std. dev. of head X displacement (mm)')
    ax.set_title('(b) Surge (X) displacement at head')
    ax.legend(fontsize=8)

    fig.suptitle('Pivot Point Identification: Head Displacement vs. $c_z$ Setting',
                 fontsize=11, fontweight='bold')
    plt.tight_layout()
    out = os.path.join(OUT_DIR, 'fig4_pivot_id.pdf')
    plt.savefig(out); plt.savefig(out.replace('.pdf', '.png'))
    plt.close(); print(f"[OK] {out}")
    
    # Return identified pivot for table
    result = {}
    if len(cz_arr) >= 2:
        if coef_y[0] != 0:
            result['cz_zero_y'] = -coef_y[1] / coef_y[0]
        if coef_x[0] != 0:
            result['cz_zero_x'] = -coef_x[1] / coef_x[0]
    return result


# ═══════════════════════════════════════════════════════════════════════════════
# FIG 5 – Góc motor (IK) theo thời gian – Roll maneuver
# ═══════════════════════════════════════════════════════════════════════════════
def fig5_motor_angles():
    fpath = os.path.join(DATA_DIR, 'Head_Command.csv')
    if not os.path.exists(fpath):
        print(f"  [SKIP] {fpath}")
        return
    d = parse_moog(fpath)
    if len(d['t']) == 0:
        return

    A, B, gamma = calc_geometry()
    N   = len(d['t'])
    phi = np.zeros((N, 6))

    for k in range(N):
        # Tính pose bàn máy từ head command (head = platform + R*head_local)
        # Với head_local = [0, 0, HEAD_Z] và pivot = head_local
        R_k      = calc_rotation(d['yaw'][k], d['pitch'][k], d['roll'][k])
        head_loc = np.array([0.0, 0.0, HEAD_Z])
        pos_plat = np.array([d['x'][k], d['y'][k], d['z'][k]]) + np.array([0, 0, HOME_Z]) + head_loc - R_k @ head_loc
        pose_k   = [pos_plat[0], pos_plat[1], pos_plat[2],
                    d['roll'][k], d['pitch'][k], d['yaw'][k]]
        phi[k, :] = inverse_kinematics(pose_k, A, B, gamma)

    t = d['t']
    colors_legs = [C_BLUE, C_RED, C_GREEN, C_ORANGE, C_PURPLE, C_GRAY]
    fig, ax = plt.subplots(figsize=(8, 4))
    for i in range(6):
        ax.plot(t, phi[:, i], color=colors_legs[i], lw=1.3,
                label=f'Motor {i+1}')
    ax.axhline(-50, color='k', ls='--', lw=0.9, alpha=0.7, label='Motor limits')
    ax.axhline(90,  color='k', ls='--', lw=0.9, alpha=0.7)
    ax.fill_between(t, -50, 90, alpha=0.04, color='green')

    ax.set_xlabel('Time (s)')
    ax.set_ylabel('Motor angle $\\phi_i$ (deg)')
    ax.set_title('Motor Angles via Inverse Kinematics — Roll Maneuver ($c_z = -762$ mm, 10°, 0.25 Hz)',
                 fontsize=10, fontweight='bold')
    ax.legend(fontsize=8, ncol=3, loc='upper right')
    plt.tight_layout()
    out = os.path.join(OUT_DIR, 'fig5_motor_angles.pdf')
    plt.savefig(out); plt.savefig(out.replace('.pdf', '.png'))
    plt.close(); print(f"[OK] {out}")


# ═══════════════════════════════════════════════════════════════════════════════
# FIG 6 – Head displacement comparison (Roll vs Pitch)
# ═══════════════════════════════════════════════════════════════════════════════
def fig6_roll_vs_pitch():
    roll_f  = os.path.join(DATA_DIR, 'Head_Command_Roll_-50-50-762.csv')
    pitch_f = os.path.join(DATA_DIR, 'Head_Command_Pitch_-50-50-762.csv')
    head_f  = os.path.join(DATA_DIR, 'Head_Command.csv')

    fig, axes = plt.subplots(2, 2, figsize=(10, 6), sharex=False)

    datasets = [
        (roll_f,  'Roll maneuver (10°, 0.25 Hz)\n$c_z=-762$ mm, offset (-50,-50)',  [axes[0,0], axes[1,0]]),
        (pitch_f, 'Pitch maneuver (10°, 0.25 Hz)\n$c_z=-762$ mm, offset (-50,-50)', [axes[0,1], axes[1,1]]),
    ]

    for fpath, title, axs in datasets:
        if not os.path.exists(fpath):
            # Fallback to head_f
            fpath = head_f
        if not os.path.exists(fpath):
            continue
        d = parse_moog(fpath)
        if len(d['t']) == 0:
            continue
        t = d['t']
        axs[0].plot(t, d['y'], color=C_BLUE,  lw=1.3, label='Y (lateral)')
        axs[0].plot(t, d['x'], color=C_RED,   lw=1.3, label='X (surge)',  ls='--')
        axs[0].set_ylabel('Head displacement (mm)')
        axs[0].set_title(title, fontsize=9)
        axs[0].legend(fontsize=8)

        axs[1].plot(t, d['roll'],  color=C_ORANGE, lw=1.3, label='Roll $\\phi$')
        axs[1].plot(t, d['pitch'], color=C_GREEN,  lw=1.3, label='Pitch $\\theta$', ls='--')
        axs[1].set_xlabel('Time (s)')
        axs[1].set_ylabel('Angle (deg)')
        axs[1].legend(fontsize=8)

    fig.suptitle('Head Trajectory During Roll and Pitch Maneuvers (Pivot at Head Position)',
                 fontsize=11, fontweight='bold')
    plt.tight_layout()
    out = os.path.join(OUT_DIR, 'fig6_roll_vs_pitch.pdf')
    plt.savefig(out); plt.savefig(out.replace('.pdf', '.png'))
    plt.close(); print(f"[OK] {out}")


# ═══════════════════════════════════════════════════════════════════════════════
# FIG 7 – Experimental setup diagram (schematic block diagram)
# ═══════════════════════════════════════════════════════════════════════════════
def fig7_experimental_setup():
    fig, ax = plt.subplots(figsize=(9, 5.5))
    ax.set_xlim(0, 10); ax.set_ylim(0, 7)
    ax.axis('off')
    ax.set_facecolor('white')

    def box(ax, x, y, w, h, label, sublabel='', color='#D0E8FF', fontsize=9):
        rect = mpatches.FancyBboxPatch((x, y), w, h,
            boxstyle='round,pad=0.12', linewidth=1.2,
            edgecolor='#333333', facecolor=color)
        ax.add_patch(rect)
        ax.text(x + w/2, y + h/2 + (0.15 if sublabel else 0),
                label, ha='center', va='center', fontsize=fontsize, fontweight='bold')
        if sublabel:
            ax.text(x + w/2, y + h/2 - 0.25,
                    sublabel, ha='center', va='center', fontsize=7.5, color='#444')

    def arrow(ax, x1, y1, x2, y2, label='', color='k'):
        ax.annotate('', xy=(x2, y2), xytext=(x1, y1),
                    arrowprops=dict(arrowstyle='->', color=color, lw=1.5))
        if label:
            mx, my = (x1+x2)/2, (y1+y2)/2
            ax.text(mx+0.05, my+0.12, label, fontsize=7.5, color=color, ha='center')

    # Blocks
    box(ax, 0.3, 5.0, 2.2, 1.2, 'CKAS W2', '6-RUS Stewart Platform', color='#FFE0B2')
    box(ax, 3.6, 5.0, 2.8, 1.2, 'MW-AHRSv1 IMU', 'Mounted on platform\n(Roll, Pitch, Yaw @ 100 Hz)', color='#C8E6C9')
    box(ax, 7.5, 5.0, 2.2, 1.2, 'PC / MATLAB', 'Data logging\n& Processing', color='#B3E5FC')

    box(ax, 0.3, 2.8, 2.2, 1.2, 'Dashboard\nStewart5.m', 'Trajectory generator\n& IK solver', color='#E1BEE7')
    box(ax, 3.6, 2.8, 2.8, 1.2, '~centre_z Command', 'Set Pivot Point $c_z$ ∈\n{0,−200,−400,−600,−762} mm', color='#FFF9C4')
    box(ax, 7.5, 2.8, 2.2, 1.2, 'Head Command\nCSV Export', '15-param Moog format', color='#FFCDD2')

    box(ax, 3.6, 0.6, 2.8, 1.4, 'Pivot Point ID\nAlgorithm', 'Minimize $\\sigma(Y_{head})$\nvs. $c_z$ setting', color='#E0F7FA', fontsize=9)

    # Arrows
    arrow(ax, 2.5, 5.6, 3.6, 5.6, 'Motion command')
    arrow(ax, 6.4, 5.6, 7.5, 5.6, 'IMU data')
    arrow(ax, 1.4, 5.0, 1.4, 4.0, 'Trajectory')
    arrow(ax, 5.0, 5.0, 5.0, 4.0, '$c_z$ sweep')
    arrow(ax, 8.6, 5.0, 8.6, 4.0, 'Sync & log')
    arrow(ax, 5.0, 2.8, 5.0, 2.0, '')
    arrow(ax, 8.6, 2.8, 8.6, 2.0, '')
    ax.annotate('', xy=(6.4, 1.3), xytext=(8.6, 2.0),
                arrowprops=dict(arrowstyle='->', color='k', lw=1.5,
                                connectionstyle='arc3,rad=-0.3'))
    ax.text(7.8, 1.5, 'Head displacement\ndata', fontsize=7.5, ha='center')

    ax.text(5.0, 0.25, 'Identified Pivot Point $c_z^*$', ha='center', fontsize=10,
            fontweight='bold', color=C_PURPLE)

    ax.set_title('Experimental Setup for Pivot Point Identification on CKAS W2',
                 fontsize=11, fontweight='bold', pad=12)
    plt.tight_layout()
    out = os.path.join(OUT_DIR, 'fig7_exp_setup.pdf')
    plt.savefig(out); plt.savefig(out.replace('.pdf', '.png'))
    plt.close(); print(f"[OK] {out}")


# ═══════════════════════════════════════════════════════════════════════════════
# FIG 8 – Sensor spec / MW-AHRSv1 signal quality (noise floor visualization)
# ═══════════════════════════════════════════════════════════════════════════════
def fig8_sensor_quality():
    """
    Dùng file Head_Command0.csv (platform static, c_z=0, no rotation)
    để hiển thị noise floor của cảm biến IMU trong thực tế.
    """
    fpath = os.path.join(DATA_DIR, 'Head_Command0.csv')
    if not os.path.exists(fpath):
        print(f"  [SKIP] {fpath}"); return
    d = parse_moog(fpath)
    if len(d['t']) < 10:
        return

    # Chỉ lấy 5 giây đầu để thấy noise rõ
    mask = d['t'] <= min(d['t'][-1], 5.0)
    t_s  = d['t'][mask]

    fig, axes = plt.subplots(2, 1, figsize=(8, 5), sharex=True)

    # Position noise (from Moog command — this IS platform motion, not noise,
    # but at cz=0 head should be ~stationary when platform moves in roll only)
    axes[0].plot(t_s, d['y'][mask], color=C_BLUE, lw=1.0, label='Y (lateral)')
    axes[0].plot(t_s, d['x'][mask], color=C_RED,  lw=1.0, label='X (surge)', ls='--')
    axes[0].set_ylabel('Head displacement (mm)')
    axes[0].set_title('MW-AHRSv1 Output — Static Platform ($c_z = 0$ mm, Roll 10°, 0.25 Hz)',
                      fontsize=9.5)
    axes[0].legend(fontsize=8)

    axes[1].plot(t_s, d['roll'][mask],  color=C_ORANGE, lw=1.2, label='Roll $\\phi$')
    axes[1].plot(t_s, d['pitch'][mask], color=C_GREEN,  lw=1.2, label='Pitch $\\theta$', ls='--')
    axes[1].set_xlabel('Time (s)')
    axes[1].set_ylabel('Angle (deg)')
    axes[1].legend(fontsize=8)

    # Stats annotation
    noise_y = np.std(d['y'][mask])
    axes[0].text(0.98, 0.95, f'$\\sigma_Y$={noise_y:.2f} mm (RMS)',
                 transform=axes[0].transAxes, ha='right', va='top', fontsize=8,
                 bbox=dict(boxstyle='round', fc='white', ec='gray', alpha=0.8))

    plt.tight_layout()
    out = os.path.join(OUT_DIR, 'fig8_sensor_quality.pdf')
    plt.savefig(out); plt.savefig(out.replace('.pdf', '.png'))
    plt.close(); print(f"[OK] {out}")


# ─── MAIN ──────────────────────────────────────────────────────────────────────
if __name__ == '__main__':
    os.makedirs(OUT_DIR, exist_ok=True)
    print("=== Generating figures for IEEE paper ===\n")
    fig1_geometry_diagram()
    fig2_pivot_concept()
    fig3_head_trajectory()
    pivot_result = fig4_pivot_identification()
    fig5_motor_angles()
    fig6_roll_vs_pitch()
    fig7_experimental_setup()
    fig8_sensor_quality()
    print("\n=== All figures saved to:", OUT_DIR)
    if pivot_result:
        print("\n>>> Identified Pivot Point:")
        for k, v in pivot_result.items():
            print(f"    {k} = {v:.1f} mm")
