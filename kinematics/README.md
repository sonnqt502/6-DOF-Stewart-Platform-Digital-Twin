# 🔁 Động học ngược & Động học thuận — Inverse / Forward Kinematics

> Nhánh `feature/inverse-kinematics` — Stewart Platform 6-RUS CKAS W2

Tập hợp toàn bộ code giải bài toán **động học** của cơ cấu: tính góc servo từ vị trí đặt (IK) và tính vị trí thực từ góc servo (FK Newton-Raphson).

---

## Danh sách file trong nhánh này

| File | Nhóm | Mô tả ngắn |
|---|---|---|
| `calc_Geometry.m` | Hình học | Tính A_i, B_i, γ_i — khởi tạo bắt buộc |
| `tinhvitriA.m` | Hình học | Tính tọa độ 6 khớp đế |
| `tinhvitriB.m` | Hình học | Tính tọa độ 6 khớp bàn máy |
| `tinhgamma.m` | Hình học | Tính góc gá motor γ_i |
| `matranquay.m` | Tiện ích | Ma trận quay R = Rz·Ry·Rx |
| `donghocnguoc_final1.m` | IK | Hàm IK chính thức, có offset servo |
| `check_pose_safety.m` | Safety | Cổng an toàn 3 lớp |
| `kiem_tra_ki_di_optimized.m` | Safety | Kiểm tra kỳ dị det(J) |
| `jacobian_RUS.m` | Jacobian | Ma trận Jacobian J[6×6] |
| `donghocthuan_NR.m` | FK | Forward Kinematics Newton-Raphson |
| `run_forward_kinematics.m` | Script | Script nhanh: nhập góc → xuất pose |
| `kinematic_chan_ao.m` | Phân tích | Phát hiện chân ảo |
| `kinematic_goc_quay.m` | Phân tích | Phân tích góc xoay |
| `kinematic_demo_gui.m` | GUI | Demo tương tác kéo thanh trượt |
| `kinematic_gui_v1.m` | GUI | GUI phiên bản 1 |
| `flat_workspace.m` | Workspace | Workspace mặt phẳng |
| `rotate_workspace.m` | Workspace | Workspace xoay |
| `plot_workspace_limits.m` | Workspace | Vẽ giới hạn workspace |
| `find_nominal_L_limits.m` | Workspace | Giới hạn lý thuyết |
| `find_L_limits_FK_MonteCarlo.m` | Workspace | Giới hạn Monte Carlo |
| `test_donghocthuan.m` | Test | Kiểm thử FK vs IK |
| `verify_ik_match.m` | Test | Xác minh IK khớp Simulink |

---

## Công thức cốt lõi

### IK — Phương trình vòng kín

Cho vector chân ảo: `L_i = T + R·b_i − a_i`

Từ ràng buộc hình học khớp RUS:

$$Q_i = |L_i|^2 - L_2^2 + L_1^2$$
$$M_i = 2L_1 \cdot L_{iz}, \quad N_i = 2L_1(L_{ix}\cos\gamma_i + L_{iy}\sin\gamma_i)$$
$$\phi_{raw,i} = \arcsin\!\left(\frac{Q_i}{\sqrt{M_i^2+N_i^2}}\right) - \text{atan2}(N_i, M_i)$$

### FK — Newton-Raphson

$$x_{k+1} = x_k + J^{-1}(x_k)\cdot(\phi_{target} - \text{IK}(x_k))$$

Điều kiện dừng: $\|\phi_{target} - \text{IK}(x_k)\|_\infty < 10^{-6}$ °

---

Xem **[USAGE.md](USAGE.md)** để chạy ngay.
