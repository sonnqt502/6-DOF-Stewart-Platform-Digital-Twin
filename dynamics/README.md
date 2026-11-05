# ⚙️ Chuyên đề Mô phỏng Động lực học & Mô hình Simscape Multibody

> **Nhánh:** `feature/dynamics`  
> **Tài liệu đối chiếu:** Đồ án tốt nghiệp *ĐATN_NQTS.pdf* (Chương 4: Xây dựng chương trình mô phỏng — Mục 4.1: Mô phỏng bằng Matlab Simulink).

---

## 📌 Mục lục

- [1. Mục đích mô phỏng kết hợp (Double Check)](#1-mục-đích-mô-phỏng-kết-hợp-double-check)
- [2. Cấu trúc mô hình Simscape Multibody (Mục 4.1)](#2-cấu-trúc-mô-hình-simscape-multibody-mục-41)
  - [2.1. Danh mục các khối chức năng chính](#21-danh-mục-các-khối-chức-năng-chính)
  - [2.2. Kiểm chứng độ chính xác động học ngược (Trang 53–56)](#22-kiểm-chứng-độ-chính-xác-động-học-ngược-trang-5356)
- [3. Tính toán tín hiệu Động học & Động lực học (Trang 63–64)](#3-tính-toán-tín-hiệu-động-học--động-lực-học-trang-6364)
- [4. Danh mục file mã nguồn](#4-danh-mục-file-mã-nguồn)
- [5. Hướng dẫn chạy mô phỏng và kiểm nghiệm](#5-hướng-dẫn-chạy-mô-phỏng-và-kiểm-nghiệm)

---

## 1. Mục đích mô phỏng kết hợp (Double Check)

*(Trích xuất theo Trang 60 của ĐATN_NQTS.pdf)*

Mục đích của việc mô phỏng là kiểm chứng quá trình chuyển động và sự an toàn của cơ cấu trước khi vận hành trên thực tế. Với đầu vào là quỹ đạo của chuyển động đầu người, hệ thống sẽ tính toán ra quỹ đạo của bệ động và góc quay của các động cơ.

Việc kết hợp mô phỏng **Simulink** (mô hình vật lý ảo Simscape Multibody) và mô phỏng **thuật toán trên Matlab** (giải tích) là bắt buộc (**Double Check**) nhằm:
- Phát hiện các sai lệch do cấu hình cơ khí trong thuật toán động học ngược.
- Đánh giá độ chính xác qua việc so sánh giữa **dịch chuyển lý thuyết (Matlab)** và **dịch chuyển ảo (Simulink)**.

---

## 2. Cấu trúc mô hình Simscape Multibody (Mục 4.1)

Mô hình vật lý `Final_CKASForSIM30_11_SIM.slx` được xây dựng tự động từ tệp `.xml` thông qua lệnh `smimport`.

### 2.1. Danh mục các khối chức năng chính *(Bảng 4-1, ĐATN)*

| Tên khối Simscape | Chức năng trong hệ thống |
|---|---|
| **World Frame** | Xây dựng tham chiếu của mô hình cơ khí. Đây là hệ tọa độ toàn cục cố định của hệ thống. |
| **Mechanism Configuration** | Định nghĩa các tham số vật lý của môi trường mô phỏng (vector gia tốc trọng trường $g = [0, 0, -9.81]\text{ m/s}^2$). |
| **Solver Configuration** | Xác định bộ giải số (solver), dung sai nhất quán (*consistent tolerance*), thời gian lấy mẫu. |
| **Transform** | Xác định chuyển đổi 3D cố định và cứng giữa các khung tọa độ của từng khâu. |
| **Rotational Joint (Revolute)** | Diễn giải chuyển động quay giữa cơ cấu chấp hành (động cơ servo) và cơ sở cố định trên bệ đế. |
| **Spherical Joint** | Diễn tả chuyển động quay 3 bậc tự do không bị hạn chế của khớp cầu tại bệ động. |

### 2.2. Kiểm chứng độ chính xác động học ngược *(Trang 53–56)*

Hệ thống được kiểm tra với các giới hạn hành trình theo từng trục bằng tín hiệu kiểm thử hình sin:
- **Trục $X$ (Surge):** $X_{\min} = -150\text{ mm}$, $X_{\max} = 150\text{ mm}$. Tín hiệu đầu vào: $X_{ref} = 150\sin(2\pi t)$.
- **Trục $Y$ (Sway):** $Y_{\min} = -150\text{ mm}$, $Y_{\max} = 150\text{ mm}$. Tín hiệu đầu vào: $Y_{ref} = 150\sin(2\pi t)$.
- **Trục $Z$ (Heave):** $Z_{\min} = -150\text{ mm}$, $Z_{\max} = 150\text{ mm}$. Tín hiệu đầu vào: $Z_{ref} = 150\sin(2\pi t)$.
- **Trục Roll:** $\text{Roll}_{\min} = -23^\circ$, $\text{Roll}_{\max} = 23^\circ$. Tín hiệu đầu vào: $\text{Roll}_{ref} = 23\sin(2\pi t)$.
- **Trục Pitch:** $\text{Pitch}_{\min} = -22^\circ$, $\text{Pitch}_{\max} = 22^\circ$. Tín hiệu đầu vào: $\text{Pitch}_{ref} = 22\sin(2\pi t)$.
- **Trục Yaw:** $\text{Yaw}_{\min} = -25^\circ$, $\text{Yaw}_{\max} = 25^\circ$. Tín hiệu đầu vào: $\text{Yaw}_{ref} = 25\sin(2\pi t)$.

**Kết luận thực nghiệm trong ĐATN:** Chương trình động học ngược và hệ mô phỏng Simscape hoạt động tương đối chính xác, sai số góc lớn nhất chỉ đạt **$5 \times 10^{-5}$ độ** trên trục Pitch (do làm tròn số thập phân của tham số hình học).

---

## 3. Tính toán tín hiệu Động học & Động lực học *(Trang 63–64)*

Chương trình dựa trên dữ liệu vị trí và góc từ quỹ đạo (được Import hoặc Sinh ra), thực hiện vi phân theo thời gian để thu được đầy đủ thông số động học và động lực học:

$$v = \frac{ds}{dt}; \quad a = \frac{dv}{dt} = \frac{d^2s}{dt^2}$$
$$\omega = \frac{dg}{dt}; \quad \alpha = \frac{d\omega}{dt} = \frac{d^2g}{dt^2}$$

Hàm `tinh_torque.m` giải quyết bài toán động lực học ngược bằng cân bằng Newton-Euler và nguyên lý công ảo để xuất ra:
- Moment tổng yêu cầu tại trục 6 động cơ servo $\tau_{\text{motor}}$.
- Lực kéo/nén dọc trục trong 6 thanh truyền $f_{\text{rod}}$ (phục vụ đối chiếu giới hạn mỏi và bền).

---

## 4. Danh mục file mã nguồn

| Tên file | Chức năng theo ĐATN |
|---|---|
| [`Final_CKASForSIM30_11_SIM.slx`](Final_CKASForSIM30_11_SIM.slx) | Mô hình vật lý hoàn chỉnh Simscape Multibody 6-DOF của CKAS W2 |
| [`load_simscape_params.m`](load_simscape_params.m) | Tự động đọc và nạp tham số khối lượng, quán tính vào Base Workspace |
| [`run_simulink.m`](run_simulink.m) | Khởi chạy mô hình Simulink và thu thập dữ liệu phản hồi cảm biến |
| [`tinh_torque.m`](tinh_torque.m) | Tính toán moment động cơ servo và lực kéo nén trên các thanh truyền |
| [`tinh_vel.m`](tinh_vel.m) | Quy đổi vận tốc bệ động ra tốc độ vòng quay động cơ (RPM) qua Jacobian |
| [`jacobian_RUS.m`](jacobian_RUS.m) | Ma trận Jacobian liên kết vận tốc bệ động và vận tốc góc servo arm |
| [`gui_torque_motion.m`](gui_torque_motion.m) | Giao diện đồ họa hiển thị phân bố moment động cơ theo quỹ đạo |
| [`gui_motor_angle.m`](gui_motor_angle.m) | Giao diện giám sát biểu đồ góc quay 6 động cơ |

---

## 5. Hướng dẫn chạy mô phỏng và kiểm nghiệm

```matlab
% 1. Nạp toàn bộ thông số Simscape
load_simscape_params;

% 2. Khởi chạy mô hình Simulink độc lập
run_simulink;

% 3. Hoặc mở giao diện tích hợp chính
Dashboard_Stewart5;
```
