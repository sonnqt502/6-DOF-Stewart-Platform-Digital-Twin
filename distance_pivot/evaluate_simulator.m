% evaluate_simulator.m
% Công cụ đánh giá độ trung thực của Simulator
% So sánh dữ liệu IMU Head thực tế và IMU Head Mô phỏng

clear; clc; close all;

% TÙY CHỌN: Đảo ngược trục Y và Z của Simulator
% Do hệ tọa độ của Simulator có trục Z hướng xuống và trục Y ngược chiều
% với IMU thực tế (Z hướng lên), cần bật cờ này để so sánh đúng chiều vật lý.
FLIP_SIM_YZ = true;

%% 1. TẢI FILE DỮ LIỆU
disp('Vui lòng chọn file IMU Head THỰC TẾ (Real Head)...');
[file_real, path_real] = uigetfile('*.csv', 'Chọn file Thực tế (Real Head IMU)');
if isequal(file_real, 0), disp('Hủy bỏ.'); return; end

disp('Vui lòng chọn file IMU Head MÔ PHỎNG (Simulated Head)...');
[file_sim, path_sim] = uigetfile('*.csv', 'Chọn file Mô phỏng (Simulator Head)');
if isequal(file_sim, 0), disp('Hủy bỏ.'); return; end

data_real = parseMoogFile(fullfile(path_real, file_real));
data_sim  = parseMoogFile(fullfile(path_sim, file_sim));

%% 2. NẮN TRỤC (PCA ALIGNMENT)
% Chúng ta bắt buộc phải nắn trục để đưa cả 2 về chung Hệ quy chiếu Tuyệt đối
[~, move_type, W_real, A_real, t_real] = applyPCA(data_real);
[~, ~, W_sim, A_sim, t_sim] = applyPCA(data_sim);

if FLIP_SIM_YZ
    % Đảo chiều trục Y và Z của Simulator
    W_sim(:, 2) = -W_sim(:, 2);
    W_sim(:, 3) = -W_sim(:, 3);
    A_sim(:, 2) = -A_sim(:, 2);
    A_sim(:, 3) = -A_sim(:, 3);
    disp('Đã đảo chiều trục Y và Z của Simulator để khớp với hệ quy chiếu Thực tế!');
end

fprintf('\n--- KẾT QUẢ ĐỌC FILE ---\n');
fprintf('Real Head File: %s\n', file_real);
fprintf('Sim Head File : %s\n', file_sim);
fprintf('Nhận diện chuyển động: %s\n', move_type);

%% 3. BỎ QUA ĐỒNG BỘ THỜI GIAN (THEO YÊU CẦU)
% Lọc lấy 15 giây đầu tiên
idx_15s_sim = find(t_sim - t_sim(1) <= 15, 1, 'last');
idx_15s_real = find(t_real - t_real(1) <= 15, 1, 'last');

% Cắt cho bằng chiều dài nhỏ nhất (giữa 15s hoặc chiều dài thực tế nếu < 15s)
min_len = min([idx_15s_sim, idx_15s_real, size(A_sim, 1), size(A_real, 1)]);

A_sim_s = A_sim(1:min_len, :);
A_real_s = A_real(1:min_len, :);

% Chuẩn hóa mốc thời gian về 0 để hiển thị đẹp hơn
t_sync_sim = t_sim(1:min_len) - t_sim(1);
t_sync_real = t_real(1:min_len) - t_real(1);

%% 4. NỘI SUY VÀ TÍNH TOÁN RMSE
% Để tính RMSE chính xác từng điểm, hai tín hiệu phải nằm trên cùng một trục thời gian.
% Ta lấy thời gian của Real làm chuẩn và nội suy Sim theo mốc thời gian đó.
A_sim_interp = interp1(t_sync_sim, A_sim_s, t_sync_real, 'linear', 'extrap');

% Tính RMSE
rmse_a = sqrt(mean((A_sim_interp - A_real_s).^2));

%% 5. VẼ ĐỒ THỊ OVERLAY
fig = figure('Name', 'Simulator Fidelity (Ay, Az)', 'Position', [100, 100, 1000, 800]);

% --- Subplot 1: Ay (Aligned) ---
ax1 = subplot(2, 1, 1);
plot(t_sync_real, A_real_s(:, 2), 'c', 'LineWidth', 1.5, 'DisplayName', 'Real ay'); hold on;
plot(t_sync_real, A_sim_interp(:, 2), 'm--', 'LineWidth', 1.5, 'DisplayName', 'Sim ay (Interp)');
title(sprintf('Gia tốc dài Trục Y (RMSE: %.4f)', rmse_a(2))); grid on; legend('Location','best');
ylabel('m/s^2');

% --- Subplot 2: Az (Aligned) ---
ax2 = subplot(2, 1, 2);
plot(t_sync_real, A_real_s(:, 3), 'b', 'LineWidth', 1.5, 'DisplayName', 'Real az'); hold on;
plot(t_sync_real, A_sim_interp(:, 3), 'r--', 'LineWidth', 1.5, 'DisplayName', 'Sim az (Interp)');
title(sprintf('Gia tốc dài Trục Z (RMSE: %.4f)', rmse_a(3))); grid on; legend('Location','best');
ylabel('m/s^2'); xlabel('Time (s)');

linkaxes([ax1 ax2], 'x');
%% ========================================================================
% HÀM BỔ TRỢ: NẮN TRỤC PCA
% ========================================================================
function [R_PCA, move_type, W_aligned, A_aligned, t] = applyPCA(data)
    cT=1; cAxi=8; cAyi=9; cAzi=10; cWz=14; cWy=15; cWx=16;
    A_raw = data(:, [cAxi, cAyi, cAzi]);
    W_raw = data(:, [cWx, cWy, cWz]);
    Grav_raw = data(:, 11:13);
    t = data(:, cT);
    
    [coeff, ~, ~] = pca(W_raw);
    rot_axis = coeff(:, 1);
    
    g_vec = mean(Grav_raw(1:min(1000, size(Grav_raw,1)), :))';
    g_vec = g_vec / norm(g_vec);
    
    if abs(rot_axis(1)) > abs(rot_axis(2))
        move_type = 'ROLL (Trục X)';
        if rot_axis(1) < 0, rot_axis = -rot_axis; end
        X = rot_axis;
        Y = cross(g_vec, X); Y = Y / norm(Y);
        Z = cross(X, Y); Z = Z / norm(Z);
    else
        move_type = 'PITCH (Trục Y)';
        if rot_axis(2) < 0, rot_axis = -rot_axis; end
        Y = rot_axis;
        X = cross(Y, g_vec); X = X / norm(X);
        Z = cross(X, Y); Z = Z / norm(Z);
    end
    
    R_PCA = [X, Y, Z];
    A_aligned = A_raw * R_PCA;
    W_aligned = W_raw * R_PCA;
end
