# Hướng dẫn kỹ thuật — Sử dụng Thuật toán Động học Ngược và Thuận

> **Tham chiếu chuẩn:** Chương 3 (Trang 35–44), Đồ án tốt nghiệp *ĐATN_NQTS.pdf*.

---

## 1. Khởi tạo hình học cơ bản (bước bắt buộc đầu tiên)

Trước khi thực hiện bất kỳ phép tính động học nào, hệ thống cần khởi tạo ma trận tọa độ điểm neo ở đế $A$, ở bàn máy $B$ và góc trục động cơ $\gamma$:

```matlab
% Kích thước chuẩn theo Bảng 3-1 trong ĐATN
ra = 589.66;   % Bán kính vòng đế (mm)
rb = 429.566;  % Bán kính vòng bàn máy (mm)
alpha1 = 19.45; beta1 = 53.32;
d_a = 38.9;    d_b = 10.0;
L1 = 150;      % Chiều dài tay quay (mm)
L2 = 747;      % Chiều dài thanh truyền (mm)

% Gọi hàm khởi tạo
[A_mat, B_mat, gamma_ang] = calc_Geometry(ra, rb, alpha1, beta1, d_a, d_b);
```

---

## 2. Giải bài toán Động học ngược (IK)

```matlab
% Định nghĩa tư thế bàn máy: [x, y, z, roll, pitch, yaw] (mm và độ)
pose = [0, 0, 795.4, 0, 5, 0];  % Nghiêng Pitch 5 độ quanh vị trí trung hòa

% Gọi hàm giải động học ngược
phi_out = donghocnguoc_final1(pose, A_mat, B_mat, L1, L2, gamma_ang);

% Kiểm tra tính khả thi
if any(isnan(phi_out))
    error('LỖI: Vị trí yêu cầu nằm ngoài tầm với cơ học của cơ cấu!');
else
    fprintf('Góc xuất ra 6 servo (độ): [ %.2f, %.2f, %.2f, %.2f, %.2f, %.2f ]\n', phi_out);
end
```

---

## 3. Kiểm định an toàn 3 lớp (`check_pose_safety.m`)

```matlab
% Kiểm tra tính an toàn trước khi gửi lệnh điều khiển
pose_candidate = [80, -50, 850, 10, -8, 5];

[is_safe, error_msg, phi_safe] = check_pose_safety(pose_candidate, A_mat, B_mat, L1, L2, gamma_ang);

if is_safe
    fprintf('>> HỆ THỐNG AN TOÀN. Góc điều khiển: %s\n', num2str(phi_safe, '%.2f '));
else
    warning('>> CẢNH BÁO TỪ CHỐI LỆNH: %s', error_msg);
end
```

---

## 4. Giải bài toán Động học thuận (FK Newton-Raphson)

```matlab
% Giả sử đọc được góc 6 động cơ từ encoder phần cứng:
phi_target = [10.5, -8.2, 12.1, -9.4, 11.0, -8.9];

% Điểm đoán nhận ban đầu (thường lấy vị trí Home z = 795.4 mm)
pose_guess = [0, 0, 795.4, 0, 0, 0];

% Giải động học thuận bằng Newton-Raphson
[pose_out, iter, err] = donghocthuan_NR(phi_target, pose_guess, A_mat, B_mat, L1, L2, gamma_ang);

fprintf('Thuật toán hội tụ sau %d vòng lặp (Sai số góc: %.2e độ)\n', iter, err);
fprintf('Vị trí tìm được: X = %.2f mm, Y = %.2f mm, Z = %.2f mm\n', pose_out(1:3));
fprintf('Góc xoay: Roll = %.2f°, Pitch = %.2f°, Yaw = %.2f°\n', pose_out(4:6));
```

---

## 5. Chạy script kiểm tra nhanh từ bàn phím

```matlab
run_forward_kinematics  % Nhập góc trực tiếp tại cửa sổ lệnh và xem kết quả
test_donghocthuan       % Tự động kiểm thử đối chiếu chéo 100 điểm IK <-> FK
```
