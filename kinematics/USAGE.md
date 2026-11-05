# Hướng dẫn sử dụng — Kinematics

## 1. Khởi tạo hình học (bắt buộc đầu tiên)

```matlab
% Thông số CKAS W2 mặc định
ra = 589.66; rb = 429.566;
alpha1 = 19.45; beta1 = 53.32;
d_a = 38.9; d_b = 10.0;
L1 = 150; L2 = 747;

[A_mat, B_mat, gamma_ang] = calc_Geometry(ra, rb, alpha1, beta1, d_a, d_b);
```

---

## 2. Tính góc servo từ pose (IK)

```matlab
pose = [0, 0, 795.4, 0, 0, 0];  % Home position [mm, mm, mm, °, °, °]

phi_out = donghocnguoc_final1(pose, A_mat, B_mat, L1, L2, gamma_ang);
% phi_out: [φ₁ φ₂ φ₃ φ₄ φ₅ φ₆] (°) — sẵn sàng gửi driver

if any(isnan(phi_out))
    disp('Pose không khả thi!');
end
```

---

## 3. Kiểm định an toàn trước khi di chuyển

```matlab
[is_safe, msg, phi_out] = check_pose_safety(pose, A_mat, B_mat, L1, L2, gamma_ang);

if is_safe
    fprintf('An toàn. Góc: %s\n', num2str(phi_out, '%.1f '));
else
    fprintf('REJECT: %s\n', msg);
end
```

---

## 4. FK — Từ góc servo → pose thực

```matlab
phi_measured = [-15.2, 12.4, -18.1, 11.9, -16.5, 13.2];  % (°) đọc từ driver
pose_guess   = [0, 0, 795.4, 0, 0, 0];                    % Điểm đoán ban đầu

[pose_out, iter, err] = donghocthuan_NR(phi_measured, pose_guess, ...
                                         A_mat, B_mat, L1, L2, gamma_ang);
fprintf('pose = [%.2f %.2f %.2f %.2f %.2f %.2f]\n', pose_out);
fprintf('Hội tụ sau %d vòng lặp, sai số = %.2e °\n', iter, err);
```

---

## 5. Chạy script nhanh

```matlab
run_forward_kinematics   % Nhập phi thủ công → in pose ra màn hình
```

---

## 6. Tính Jacobian

```matlab
pose_dot = [0, 0, 10, 0, 0, 0];  % Vận tốc: heave 10 mm/s
[J, theta_dot] = jacobian_RUS(pose, pose_dot, A_mat, B_mat, L1, L2, gamma_ang);
% J: [6×6], theta_dot: [6×1 °/s]
```

---

## 7. Phân tích workspace

```matlab
flat_workspace      % Workspace z=const (mặt phẳng)
rotate_workspace    % Workspace với roll/pitch thay đổi
plot_workspace_limits  % Vẽ đồ thị giới hạn
```

---

## Lưu ý quan trọng

- Luôn gọi `calc_Geometry` trước mọi hàm khác.
- `donghocnguoc_final1` trả về `phi_thuc` (đã có offset driver), không phải `phi_raw`.
- `donghocthuan_NR` yêu cầu `pose_guess` gần với nghiệm thực — dùng pose trước đó làm điểm đoán.
- Không gọi `donghocthuan_NR` tại điểm kỳ dị (det(J) ≈ 0) — `pinv(J)` vẫn hoạt động nhưng hội tụ chậm.
