# 🔁 Nhánh: `feature/inverse-kinematics`

> **Chủ đề:** Động học ngược (Inverse Kinematics) và Động học thuận (Forward Kinematics) của Stewart Platform kiểu RUS 6-DOF.

---

## Nội dung nhánh

Nhánh này tập trung toàn bộ code liên quan đến **giải bài toán động học** — tính góc động cơ từ vị trí đặt (IK) và tính vị trí thực từ góc động cơ (FK).

---

## Các module chính

### Động học ngược (IK)

| File | Chức năng |
|---|---|
| `donghocnguoc_final1.m` | Hàm IK chính thức, trả về góc servo `phi_out` |
| `calc_Geometry.m` | Tính tọa độ điểm A_i (base), B_i (platform), gamma_i |
| `tinhvitriA.m` | Tính tọa độ A_i theo cấu hình hình học |
| `tinhvitriB.m` | Tính tọa độ B_i sau biến đổi frame |
| `tinhgamma.m` | Tính góc gamma_i từ hình học chân |
| `matranquay.m` | Ma trận quay Rz, Ry, Rx theo góc Euler |

### Động học thuận (FK) — Newton-Raphson

| File | Chức năng |
|---|---|
| `donghocthuan_NR.m` | FK giải bằng Newton-Raphson, hội tụ < 20 iter |
| `run_forward_kinematics.m` | Script nhanh: nhập góc động cơ → xuất vị trí |
| `test_donghocthuan.m` | Kiểm thử FK vs IK (đối chiếu kết quả) |
| `verify_ik_match.m` | Xác minh IK khớp với Simulink |

### Jacobian & Workspace

| File | Chức năng |
|---|---|
| `jacobian_RUS.m` | Ma trận Jacobian vận tốc J(q) |
| `kiem_tra_ki_di_optimized.m` | Kiểm tra cấu hình kỳ dị (det(J) ≈ 0) |
| `plot_workspace_limits.m` | Vẽ giới hạn không gian làm việc |
| `flat_workspace.m` | Phân tích workspace mặt phẳng |
| `rotate_workspace.m` | Phân tích workspace xoay |
| `find_nominal_L_limits.m` | Tìm giới hạn chiều dài chân L_i |
| `find_L_limits_FK_MonteCarlo.m` | Monte Carlo giới hạn FK |
| `Histogram_L_FK_Sweep.png` | Biểu đồ phân bố chiều dài chân |

### Kiểm định an toàn

| File | Chức năng |
|---|---|
| `check_pose_safety.m` | Kiểm tra 3 lớp an toàn (cơ học, góc servo, kỳ dị) |
| `kinematic_chan_ao.m` | Phát hiện chân ảo (không khả thi hình học) |
| `kinematic_goc_quay.m` | Tính và giới hạn góc xoay |

### GUI Demo

| File | Chức năng |
|---|---|
| `kinematic_demo_gui.m` | Giao diện demo động học tương tác |
| `kinematic_gui_v1.m` | GUI phiên bản 1 |

---

## Công thức cốt lõi

### IK — Hình học giải tích (RUS joint)

```
L_i² = |P + R·b_i - a_i|²

cos(phi_i) = (L_i² - L1² - L2²) / (2·L1·L2)

phi_i = atan2(N_i·sin(alpha), M_i + N_i·cos(alpha))
```

Với:
- `M = L2·cos(gamma_i) - e_zi · L1`
- `N = -L1·sin(gamma_i)`
- `Q = e_zi · L2·cos(gamma_i) - L1 - e_zi² · (L1 - L2·cos(gamma_i))`

### FK — Newton-Raphson

```
F(x) = [f_1(x), ..., f_6(x)]ᵀ = 0
x_{k+1} = x_k - J⁻¹(x_k) · F(x_k)
||F(x_k)|| < 1e-9  →  hội tụ
```

---

## Cách sử dụng nhanh

```matlab
% Nhập góc động cơ (độ), xuất vị trí platform
run_forward_kinematics

% Chạy kiểm thử IK ↔ FK
test_donghocthuan
```

---

## Liên kết

- Nhánh `feature/dynamics` — Động lực học & tính moment
- Nhánh `feature/data` — Dữ liệu quỹ đạo thực nghiệm
- `main` — Dashboard tổng hợp
