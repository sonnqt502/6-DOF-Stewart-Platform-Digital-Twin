# 🔁 Chuyên đề Động học ngược & Động học thuận 6-RUS

> **Nhánh:** `feature/inverse-kinematics`  
> **Tài liệu đối chiếu:** Đồ án tốt nghiệp *ĐATN_NQTS.pdf* (Chương 3: Cơ sở toán học và động học hệ thống).

---

## 📌 Mục lục

- [1. Định nghĩa các tham số cấu hình cơ khí (Bảng 3-1)](#1-định-nghĩa-các-tham-số-cấu-hình-cơ-khí-bảng-3-1)
- [2. Thuật toán Động học ngược IK (Mục 3.2)](#2-thuật-toán-động-học-ngược-ik-mục-32)
  - [2.1. Vector chân ảo và phương trình vòng khép kín](#21-vector-chân-ảo-và-phương-trình-vòng-khép-kín)
  - [2.2. Nghiệm giải tích góc quay động cơ](#22-nghiệm-giải-tích-góc-quay-động-cơ)
  - [2.3. Quy đổi góc servo thực tế có bù offset](#23-quy-đổi-góc-servo-thực-tế-có-bù-offset)
- [3. Thuật toán Động học thuận FK (Newton-Raphson)](#3-thuật-toán-động-học-thuận-fk-newton-raphson)
- [4. Kiểm tra giới hạn không gian hoạt động & 3 lớp an toàn (Mục 3.3)](#4-kiểm-tra-giới-hạn-không-gian-hoạt-động--3-lớp-an-toàn-mục-33)
- [5. Danh mục file mã nguồn](#5-danh-mục-file-mã-nguồn)
- [6. Hướng dẫn sử dụng & Mẫu code kiểm thử](#6-hướng-dẫn-sử-dụng--mẫu-code-kiểm-thử)

---

## 1. Định nghĩa các tham số cấu hình cơ khí (Bảng 3-1)

Cơ cấu Stewart Platform trong đồ án thuộc kiểu **6-RUS** với 6 chuỗi động học song song gồm: khớp xoay $R$, khớp chữ Y/các-đăng $U$, và khớp cầu $S$.

| Tham số | Giá trị | Đơn vị | Định nghĩa kỹ thuật trong đồ án |
|---|---|---|---|
| $r_a$ | **589.66** | mm | Bán kính đường tròn ngoại tiếp đi qua tâm 6 trục động cơ dưới bệ đế ($A_1 \dots A_6$) |
| $r_b$ | **429.57** (429.566) | mm | Bán kính đường tròn ngoại tiếp đi qua 6 khớp cầu tại mặt dưới bàn máy ($B_1 \dots B_6$) |
| $\alpha_1$ | **19.45** | độ | Góc lắp đặt của động cơ 1 ($A_1$) hợp với trục $OX$ |
| $\Delta\alpha$ ($\delta_a$) | **38.9** | độ | Khoảng cách góc giữa hai động cơ trong cùng một cặp ($OA_1$ và $OA_2$) |
| $\beta_1$ | **53.32** | độ | Góc định vị khớp cầu 1 ($B_1$) hợp với trục $OX$ |
| $\Delta\beta$ ($\delta_b$) | **13.37** (10.0) | độ | Góc kẹp giữa hai khớp cầu liền kề cùng một cặp ($OB_2$ và $OB_3$) |
| $L_1$ | **150** | mm | Vector biểu diễn tay quay với độ dài không đổi (khâu 1) |
| $L_2$ | **747** | mm | Vector biểu diễn thanh truyền với độ dài không đổi (khâu 2) |
| $z_A$ | **592.4** (hoặc 795.4) | mm | Độ cao trung hòa của tâm khớp cầu so với tâm trục động cơ |
| $\gamma_i$ | $\alpha_i + ((-1)^i) \cdot 90^\circ$ | độ | Góc giữa hình chiếu cánh tay đòn gắn với động cơ thứ $i$ xuống $Oxy$ với trục $OX$ |

---

## 2. Thuật toán Động học ngược IK (Mục 3.2)

### 2.1. Vector chân ảo và phương trình vòng khép kín

Với điểm $A_i$ (đế) và $B_i$ (bàn máy) trong hệ tọa độ cố định:
$$B_i = T + R \cdot b_i$$
$$\vec{L}_i = B_i - A_i = [L_{ix}, L_{iy}, L_{iz}]^T$$
$$d_i = \|\vec{L}_i\| = \sqrt{L_{ix}^2 + L_{iy}^2 + L_{iz}^2}$$

Tọa độ đầu tay quay $C_i$:
$$C_i = A_i + L_1 \begin{bmatrix} \cos\gamma_i \cos\phi_{raw,i} \\ \sin\gamma_i \cos\phi_{raw,i} \\ \sin\phi_{raw,i} \end{bmatrix}$$

Khoảng cách $\|B_i - C_i\|^2 = L_2^2$ dẫn đến phương trình:
$$Q_i = M_i \sin\phi_{raw,i} + N_i \cos\phi_{raw,i}$$

Với:
- $Q_i = d_i^2 - L_2^2 + L_1^2$
- $M_i = 2 L_1 L_{iz}$
- $N_i = 2 L_1 (L_{ix}\cos\gamma_i + L_{iy}\sin\gamma_i)$

### 2.2. Nghiệm giải tích góc quay động cơ

$$\phi_{raw,i} = \arcsin\left(\frac{Q_i}{\sqrt{M_i^2 + N_i^2}}\right) - \text{atan2}(N_i, M_i)$$

### 2.3. Quy đổi góc servo thực tế có bù offset

Theo thiết kế phần cứng của CKAS W2, hai động cơ trong một cụm có chiều quay ngược nhau và driver nhận góc $\phi_{thuc}$:
$$\begin{cases}
\phi_{step}(1:2:5) = -(90^\circ + \phi_{raw}(1:2:5)) \\
\phi_{step}(2:2:6) = +(90^\circ + \phi_{raw}(2:2:6))
\end{cases}$$
$$\phi_{thuc} = \phi_{step} - [90^\circ, -90^\circ, 90^\circ, -90^\circ, 90^\circ, -90^\circ]$$
$$\phi_{thuc}(1:2:5) = -\phi_{thuc}(1:2:5)$$

---

## 3. Thuật toán Động học thuận FK (Newton-Raphson)

Tìm nghiệm vị trí $X = [x, y, z, \phi, \theta, \psi]^T$ thỏa mãn:
$$F(X) = \text{IK}(X) - \phi_{target} = 0$$

Công thức lặp Newton-Raphson:
$$X_{k+1} = X_k - J^\dagger(X_k) \cdot F(X_k)$$
- Dùng ma trận giả nghịch đảo $J^\dagger$ (Moore-Penrose Pseudo-Inverse) để đảm bảo ổn định số.
- Ngưỡng dừng sai số góc: $\max |\Delta\phi| < 10^{-6}$ độ.

---

## 4. Kiểm tra giới hạn không gian hoạt động & 3 lớp an toàn (Mục 3.3)

Trước khi gửi lệnh điều khiển, hàm `check_pose_safety.m` thực hiện kiểm định qua 3 lớp:

1. **Lớp 1 — Giới hạn kích thước vật lý (Tầm với):**
   $$\left|\frac{Q_i}{\sqrt{M_i^2 + N_i^2}}\right| \le 1$$
   Nếu giá trị vượt quá 1, điểm nằm ngoài tầm với hình học, hàm IK trả về `NaN`.
2. **Lớp 2 — Giới hạn góc quay động cơ:**
   Góc $\phi_{thuc}$ của cả 6 động cơ phải nằm trong dải an toàn $[-50^\circ, +90^\circ]$ (hoặc $[-60^\circ, +100^\circ]$) để tránh va chạm cơ khí.
3. **Lớp 3 — Giới hạn điểm kỳ dị (Singularity):**
   Kiểm tra định thức ma trận Jacobian: $|\det(J)| > 10^{-3}$. Nếu định thức triệt tiêu hoặc quá nhỏ, cơ cấu bị mất bậc tự do hoặc lực nội tại tăng vọt, tiềm ẩn nguy cơ gãy vỡ cơ học.

---

## 5. Danh mục file mã nguồn

| Tên file | Chức năng theo ĐATN |
|---|---|
| [`calc_Geometry.m`](calc_Geometry.m) | Tính ma trận $A$, $B$ và góc gá động cơ $\gamma$ *(Bảng 3-1)* |
| [`donghocnguoc_final1.m`](donghocnguoc_final1.m) | Hàm IK cốt lõi, tính góc servo thực tế $\phi_{thuc}$ có bù offset |
| [`donghocthuan_NR.m`](donghocthuan_NR.m) | Hàm FK giải bằng phương pháp lặp Newton-Raphson |
| [`check_pose_safety.m`](check_pose_safety.m) | Hàm gác cổng an toàn 3 lớp (tầm với $\rightarrow$ góc servo $\rightarrow$ kỳ dị) |
| [`jacobian_RUS.m`](jacobian_RUS.m) | Tính ma trận Jacobian vận tốc 6×6 theo phương pháp giải tích |
| [`matranquay.m`](matranquay.m) | Ma trận quay chuẩn ZYX Euler |
| [`run_forward_kinematics.m`](run_forward_kinematics.m) | Script kiểm tra nhanh FK: nhập góc động cơ $\rightarrow$ xuất vị trí |
| [`test_donghocthuan.m`](test_donghocthuan.m) | Script đối chiếu sai số chéo giữa IK và FK |
| [`verify_ik_match.m`](verify_ik_match.m) | Script xác minh nghiệm IK với mô hình Simscape |

---

## 6. Hướng dẫn sử dụng & Mẫu code kiểm thử

```matlab
% 1. Khởi tạo cấu hình hình học tĩnh
[A_mat, B_mat, gamma_ang] = calc_Geometry(589.66, 429.566, 19.45, 53.32, 38.9, 10.0);
L1 = 150; L2 = 747;

% 2. Tính IK cho tư thế Home z = 795.4 mm
pose_home = [0, 0, 795.4, 0, 0, 0];
phi_home = donghocnguoc_final1(pose_home, A_mat, B_mat, L1, L2, gamma_ang);
fprintf('Góc servo tại vị trí Home (độ):\n');
disp(phi_home);

% 3. Kiểm tra an toàn trước khi di chuyển
pose_test = [50, -30, 820, 5, -3, 2];
[is_safe, error_msg, phi_test] = check_pose_safety(pose_test, A_mat, B_mat, L1, L2, gamma_ang);
if is_safe
    disp('>> Trạng thái: Quỹ đạo hợp lệ và an toàn.');
else
    warning('>> Cảnh báo lỗi: %s', error_msg);
end

% 4. Tính FK từ góc servo
[pose_out, iter, err] = donghocthuan_NR(phi_home, pose_home, A_mat, B_mat, L1, L2, gamma_ang);
fprintf('FK hội tụ sau %d bước lặp, sai số = %.2e độ\n', iter, err);
```
