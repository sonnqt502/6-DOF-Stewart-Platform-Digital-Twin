% visualize_pca_steps.m
% Script minh họa từng bước thuật toán PCA áp dụng vào nắn trục hệ quy chiếu
% dựa trên nguyên lý Phân tích Trị Riêng (Eigenvalue Decomposition).

clear; clc; close all;

%% 1. CHỌN VÀ ĐỌC DỮ LIỆU
[file, path] = uigetfile('*.csv', 'Chọn file dữ liệu IMU để minh họa PCA');
if isequal(file, 0)
    disp('Đã hủy chọn file.');
    return;
end

% Kiểm tra xem đây là file Pivot (Moog) hay file IMU Python
    fid = fopen(fullfile(path, file), 'r');
    first_line = fgetl(fid);
    fclose(fid);
    
    if contains(first_line, '~M[')
        disp('Phát hiện file định dạng Pivot (Moog). Đang parse...');
        data = parseMoogFile(fullfile(path, file));
        W_raw = data(:, [16, 15, 14]); % Wx, Wy, Wz của Pivot
        Grav_raw = data(:, 11:13);     % Gx, Gy, Gz của Pivot
    else
        disp('Phát hiện file định dạng IMU CSV thông thường.');
        data = readmatrix(fullfile(path, file));
        W_raw = data(:, [18, 17, 16]); % Wx, Wy, Wz của IMU
        Grav_raw = data(:, 13:15);     % Gx, Gy, Gz của IMU
    end

% Lấy 2 giây đầu tiên (giả sử 100Hz -> 200 samples) để tính trọng trường tĩnh
n_static = min(1000, size(Grav_raw, 1));
if n_static < 10, n_static = 10; end
G_static = Grav_raw(1:n_static, :);

% Dùng toàn bộ dữ liệu (hoặc lấy tối đa để không treo máy) để tính PCA
% Trong motion_calibration2.m, PCA dùng toàn bộ W_raw
X_raw = W_raw; 
G_raw = Grav_raw;

%% TẠO FIGURE GỒM CÁC BƯỚC (FULL MÀN HÌNH ĐỂ NHÌN RÕ)
fig = figure('Name', 'Minh họa Thuật toán PCA', 'Units', 'normalized', 'Position', [0, 0, 1, 1]);
set(fig, 'WindowState', 'maximized'); % Tự động mở rộng full màn hình

%% Bước 1 & 2: Dữ liệu gốc và Chuẩn hóa trung tâm (Mean Centering)
ax1 = subplot(2, 3, 1);
scatter3(ax1, X_raw(:,1), X_raw(:,2), X_raw(:,3), 15, 'k', 'filled', 'MarkerFaceAlpha', 0.4);
title(ax1, {'1. Không gian Vận tốc góc gốc', '(Mỗi điểm là 1 vector [Wx,Wy,Wz] tại 1 thời điểm)'});
xlabel('Wx'); ylabel('Wy'); zlabel('Wz');
grid on; axis equal; hold on;
% Đánh dấu trọng tâm
mu = mean(X_raw);
plot3(mu(1), mu(2), mu(3), 'ro', 'MarkerSize', 10, 'LineWidth', 3);

% Chuẩn hóa trung tâm (Mean Centering)
X_centered = X_raw - mu;

ax2 = subplot(2, 3, 2);
scatter3(ax2, X_centered(:,1), X_centered(:,2), X_centered(:,3), 10, 'b', 'filled', 'MarkerFaceAlpha', 0.2);
title(ax2, '2. Chuẩn hóa trung tâm (Centered)');
xlabel('Wx'); ylabel('Wy'); zlabel('Wz');
grid on; axis equal; hold on;
plot3(0, 0, 0, 'ro', 'MarkerSize', 10, 'LineWidth', 3);

%% Bước 3: Tính Ma trận Hiệp phương sai & Phân tích Trị Riêng
% C = 1/(n-1) * X_c^T * X_c
n = size(X_centered, 1);
C = (X_centered' * X_centered) / (n - 1);

% Eigendecomposition: C*v = lambda*v
[EigenVectors, EigenValuesDiag] = eig(C);
EigenValues = diag(EigenValuesDiag);

% Sắp xếp giảm dần
[EigenValues, sortIdx] = sort(EigenValues, 'descend');
EigenVectors = EigenVectors(:, sortIdx);

ax3 = subplot(2, 3, 3);
scatter3(ax3, X_centered(:,1), X_centered(:,2), X_centered(:,3), 10, 'b', 'filled', 'MarkerFaceAlpha', 0.1);
title(ax3, '3. Trị Riêng & Vector Riêng (PCA)');
xlabel('Wx'); ylabel('Wy'); zlabel('Wz');
grid on; axis equal; hold on;

% Vẽ các Vector riêng (được scale theo độ lệch chuẩn để dễ nhìn)
scale_factor = sqrt(EigenValues) * 2; 
colors = {'r', 'g', 'm'};
labels = {'PC1 (Trục quay)', 'PC2', 'PC3'};
for i = 1:3
    quiver3(0, 0, 0, EigenVectors(1,i)*scale_factor(i), EigenVectors(2,i)*scale_factor(i), EigenVectors(3,i)*scale_factor(i), ...
        0, 'Color', colors{i}, 'LineWidth', 3, 'MaxHeadSize', 0.5);
    text(EigenVectors(1,i)*scale_factor(i)*1.1, EigenVectors(2,i)*scale_factor(i)*1.1, EigenVectors(3,i)*scale_factor(i)*1.1, labels{i}, 'Color', colors{i}, 'FontWeight', 'bold');
end

%% Bước 4: Xây dựng hệ tọa độ Hxyz kết hợp Trọng trường
rot_axis = EigenVectors(:, 1); % PC1

% Vector trọng trường (g_vec)
g_vec = mean(G_static)';
g_vec = g_vec / norm(g_vec);

% Quy tắc tam diện thuận
if abs(rot_axis(1)) > abs(rot_axis(2)) % Giả định ROLL
    if rot_axis(1) < 0, rot_axis = -rot_axis; end
    X_H = rot_axis;
    Y_H = cross(g_vec, X_H); Y_H = Y_H / norm(Y_H);
    Z_H = cross(X_H, Y_H); Z_H = Z_H / norm(Z_H);
    move_type = 'ROLL (Trục X)';
    triad_desc = {'   X = PC1', '   Y = cross(Gravity, X)', '   Z = cross(X, Y)'};
else % Giả định PITCH
    if rot_axis(2) < 0, rot_axis = -rot_axis; end
    Y_H = rot_axis;
    X_H = cross(Y_H, g_vec); X_H = X_H / norm(X_H);
    Z_H = cross(X_H, Y_H); Z_H = Z_H / norm(Z_H);
    move_type = 'PITCH (Trục Y)';
    triad_desc = {'   Y = PC1', '   X = cross(Y, Gravity)', '   Z = cross(X, Y)'};
end

R_matrix = [X_H, Y_H, Z_H]; % Ma trận xoay từ Khung Chuẩn về Khung Cảm biến

ax4 = subplot(2, 3, 4);
scatter3(ax4, X_centered(:,1), X_centered(:,2), X_centered(:,3), 10, 'b', 'filled', 'MarkerFaceAlpha', 0.1);
title(ax4, '4. Xây dựng Hệ Hxyz (Tam diện thuận)');
xlabel('Wx'); ylabel('Wy'); zlabel('Wz');
grid on; axis equal; hold on;

scale_axes = max(scale_factor);
quiver3(0,0,0, g_vec(1)*scale_axes, g_vec(2)*scale_axes, g_vec(3)*scale_axes, 0, 'k', 'LineWidth', 2, 'LineStyle', '--');
text(g_vec(1)*scale_axes, g_vec(2)*scale_axes, g_vec(3)*scale_axes, 'Gravity', 'Color', 'k');

quiver3(0,0,0, X_H(1)*scale_axes, X_H(2)*scale_axes, X_H(3)*scale_axes, 0, 'r', 'LineWidth', 3); text(X_H(1)*scale_axes, X_H(2)*scale_axes, X_H(3)*scale_axes, 'H_x', 'Color', 'r', 'FontWeight', 'bold');
quiver3(0,0,0, Y_H(1)*scale_axes, Y_H(2)*scale_axes, Y_H(3)*scale_axes, 0, 'g', 'LineWidth', 3); text(Y_H(1)*scale_axes, Y_H(2)*scale_axes, Y_H(3)*scale_axes, 'H_y', 'Color', 'g', 'FontWeight', 'bold');
quiver3(0,0,0, Z_H(1)*scale_axes, Z_H(2)*scale_axes, Z_H(3)*scale_axes, 0, 'b', 'LineWidth', 3); text(Z_H(1)*scale_axes, Z_H(2)*scale_axes, Z_H(3)*scale_axes, 'H_z', 'Color', 'b', 'FontWeight', 'bold');

%% Bước 5: Biến đổi về Tọa độ mới (Aligned Data)
% Z = X * W (trong đó W = R_matrix)
Z_aligned = X_raw * R_matrix;

ax5 = subplot(2, 3, 5);
scatter3(ax5, Z_aligned(:,1), Z_aligned(:,2), Z_aligned(:,3), 10, 'g', 'filled', 'MarkerFaceAlpha', 0.3);
title(ax5, '5. Dữ liệu đã nắn (Z = X * R)');
xlabel('Wx_H'); ylabel('Wy_H'); zlabel('Wz_H');
grid on; axis equal; hold on;
plot3(0, 0, 0, 'ro', 'MarkerSize', 10, 'LineWidth', 3);

% Vẽ các trục tọa độ tuyệt đối chuẩn mới
q_len = max(abs(Z_aligned(:)));
quiver3(0,0,0, q_len,0,0, 0, 'r', 'LineWidth', 2); text(q_len,0,0, 'X chuẩn');
quiver3(0,0,0, 0,q_len,0, 0, 'g', 'LineWidth', 2); text(0,q_len,0, 'Y chuẩn');
quiver3(0,0,0, 0,0,q_len, 0, 'b', 'LineWidth', 2); text(0,0,q_len, 'Z chuẩn');

%% Ghi chú các công thức toán học
ax6 = subplot(2, 3, 6);
axis(ax6, 'off');
txt = {
    'TÓM TẮT TOÁN HỌC PCA',
    '',
    '1. Centering: X_c = X - mean(X)',
    '2. Covariance: C = 1/(n-1) * X_c^T * X_c',
    '3. Eigendecomposition: C*v = \lambda*v',
    '   -> Tìm ra PC1 (Trục có \lambda lớn nhất)',
    '4. Triad Construction (Tam diện thuận):',
    sprintf('   => Đã nhận diện chuyển động: %s', move_type),
    '   Sử dụng PC1 và Vector Trọng trường (Gravity)',
    triad_desc{1},
    triad_desc{2},
    triad_desc{3},
    '   => Ma trận xoay R = [X, Y, Z]',
    '5. Alignment: Dữ_liệu_mới = X * R',
    ''
};

% Tính góc lệch thực tế (Misalignment)
Rp = R_matrix;
roll_err  = atan2d(Rp(3,2), Rp(3,3));
pitch_err = asind(max(min(-Rp(3,1), 1), -1));
yaw_err   = atan2d(Rp(2,1), Rp(1,1));

txt = [txt; {
    '=== KẾT QUẢ CĂN CHỈNH (MISALIGNMENT) ===',
    sprintf('Roll (X)  : %6.2f°', roll_err),
    sprintf('Pitch (Y) : %6.2f°', pitch_err),
    sprintf('Yaw (Z)   : %6.2f°', yaw_err)
}];

text(ax6, 0.05, 0.5, txt, 'FontSize', 12, 'FontName', 'Consolas', 'BackgroundColor', [0.95 0.95 0.95], 'EdgeColor', 'k', 'Margin', 10);
title(ax6, 'Tổng hợp Lý thuyết & Kết quả');

sgtitle('TRỰC QUAN HÓA THUẬT TOÁN PCA - MISALIGNMENT CALIBRATION', 'FontSize', 16, 'FontWeight', 'bold');
