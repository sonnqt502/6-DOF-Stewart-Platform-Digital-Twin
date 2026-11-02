% evaluate_kinematic_offset.m
% Đánh giá độ hiệu quả của thuật toán bù khoảng cách động học (Kinematic Offset)
% So sánh giữa Gia tốc Pivot (Chưa bù) và Pivot (Đã bù) với Head (Mục tiêu)

clear; clc; close all;

%% 1. TẢI FILE DỮ LIỆU
disp('Vui lòng chọn file IMU PIVOT...');
[file_pivot, path_pivot] = uigetfile('*.csv', 'Chọn file Pivot');
if isequal(file_pivot, 0), return; end
pivot_raw = parseMoogFile(fullfile(path_pivot, file_pivot));

disp('Vui lòng chọn file IMU HEAD...');
[file_head, path_head] = uigetfile('*.csv', 'Chọn file Head');
if isequal(file_head, 0), return; end
head_raw = parseMoogFile(fullfile(path_head, file_head));

%% 2. NẮN TRỤC (PCA) VÀ ĐỒNG BỘ
cT=1; cAxi=8; cAyi=9; cAzi=10; cWz=14; cWy=15; cWx=16;

% PCA
[~, ~, W_p, A_p, t_p] = applyPCA(pivot_raw);
[~, move_type, W_h, A_h, t_h] = applyPCA(head_raw);

% Xcorr để đồng bộ
w_p_main = W_p(:, 2);
w_h_main = W_h(:, 2);
if strcmp(move_type, 'ROLL (Trục X)')
    w_p_main = W_p(:, 1);
    w_h_main = W_h(:, 1);
end

[c, lags] = xcorr(w_h_main - mean(w_h_main), w_p_main - mean(w_p_main));
[~, max_idx] = max(c);
delay_idx = lags(max_idx);

if delay_idx > 0
    W_h_s = W_h(delay_idx+1:end, :); A_h_s = A_h(delay_idx+1:end, :);
    W_p_s = W_p(1:end-delay_idx, :); A_p_s = A_p(1:end-delay_idx, :);
    t_sync = t_p(1:end-delay_idx);
elseif delay_idx < 0
    delay_idx = -delay_idx;
    W_p_s = W_p(delay_idx+1:end, :); A_p_s = A_p(delay_idx+1:end, :);
    W_h_s = W_h(1:end-delay_idx, :); A_h_s = A_h(1:end-delay_idx, :);
    t_sync = t_h(1:end-delay_idx);
else
    W_p_s = W_p; A_p_s = A_p;
    W_h_s = W_h; A_h_s = A_h;
    t_sync = t_p;
end

min_len = min(size(W_p_s,1), size(W_h_s,1));
W_p_s = W_p_s(1:min_len,:); A_p_s = A_p_s(1:min_len,:);
W_h_s = W_h_s(1:min_len,:); A_h_s = A_h_s(1:min_len,:);
t_sync = t_sync(1:min_len);

%% 3. LỌC TÍN HIỆU (SAVITZKY-GOLAY) VÀ TÍNH ĐẠO HÀM
% Lọc W và A
W_p_filt = smoothdata(W_p_s, 1, 'sgolay', 11);
A_p_filt = smoothdata(A_p_s, 1, 'sgolay', 11);
W_h_filt = smoothdata(W_h_s, 1, 'sgolay', 11);
A_h_filt = smoothdata(A_h_s, 1, 'sgolay', 11);

% Tính gia tốc góc Alpha
alpha_h = zeros(size(W_h_filt));
alpha_h(:,1) = gradient(W_h_filt(:,1), t_sync);
alpha_h(:,2) = gradient(W_h_filt(:,2), t_sync);
alpha_h(:,3) = gradient(W_h_filt(:,3), t_sync);

% Đóng gói dữ liệu cho Module 3
proc_data.t = t_sync;
proc_data.isPitch = strcmp(move_type, 'PITCH (Trục Y)');
if proc_data.isPitch
    proc_data.gyro_h = W_h_filt(:, 2);
    proc_data.alpha_h = alpha_h(:, 2);
else
    proc_data.gyro_h = W_h_filt(:, 1);
    proc_data.alpha_h = alpha_h(:, 1);
end

proc_data.ax_p = A_p_filt(:, 1); proc_data.ay_p = A_p_filt(:, 2); proc_data.az_p = A_p_filt(:, 3);
proc_data.ax_h = A_h_filt(:, 1); proc_data.ay_h = A_h_filt(:, 2); proc_data.az_h = A_h_filt(:, 3);

%% 3. TÍNH KHOẢNG CÁCH r BẰNG MODULE 3
[r_sol_mm, ~] = module3_math_engine(proc_data, []);
r_m = r_sol_mm / 1000; % Đổi sang mét

%% 4. TÍNH GIA TỐC ĐÃ BÙ (COMPENSATED ACCELERATION)
N = length(proc_data.t);
a_offset = zeros(N, 3);

for k = 1:N
    if proc_data.isPitch
        w  = [0; proc_data.gyro_h(k); 0];
        al = [0; proc_data.alpha_h(k); 0];
        r  = [r_m(1); 0; r_m(2)];
    else
        w  = [proc_data.gyro_h(k); 0; 0];
        al = [proc_data.alpha_h(k); 0; 0];
        r  = [0; r_m(1); r_m(2)];
    end
    
    a_c = cross(w, cross(w, r));
    a_t = cross(al, r);
    a_offset(k, :) = (a_c + a_t)';
end

% Lấy gia tốc Pivot và Head (từ proc_data đã qua lọc)
a_p = [proc_data.ax_p, proc_data.ay_p, proc_data.az_p];
a_h = [proc_data.ax_h, proc_data.ay_h, proc_data.az_h];

% Gia tốc Pivot sau khi cộng bù động học
a_p_comp = a_p + a_offset;

%% 5. ĐÁNH GIÁ RMSE
rmse_uncomp = sqrt(mean((a_h - a_p).^2));
rmse_comp   = sqrt(mean((a_h - a_p_comp).^2));

fprintf('\n--- KẾT QUẢ ĐÁNH GIÁ BÙ ĐỘNG HỌC ---\n');
if proc_data.isPitch
    fprintf('Trục X (Chưa bù): RMSE = %.4f | (Đã bù): RMSE = %.4f -> Giảm %.2f%%\n', ...
        rmse_uncomp(1), rmse_comp(1), (rmse_uncomp(1)-rmse_comp(1))/rmse_uncomp(1)*100);
else
    fprintf('Trục Y (Chưa bù): RMSE = %.4f | (Đã bù): RMSE = %.4f -> Giảm %.2f%%\n', ...
        rmse_uncomp(2), rmse_comp(2), (rmse_uncomp(2)-rmse_comp(2))/rmse_uncomp(2)*100);
end
fprintf('Trục Z (Chưa bù): RMSE = %.4f | (Đã bù): RMSE = %.4f -> Giảm %.2f%%\n', ...
    rmse_uncomp(3), rmse_comp(3), (rmse_uncomp(3)-rmse_comp(3))/rmse_uncomp(3)*100);

%% 6. VẼ ĐỒ THỊ
fig = figure('Name', 'Kinematic Offset Evaluation', 'Position', [100, 100, 1200, 800]);
t = proc_data.t;

% --- Cột 1: So sánh biên độ ---
ax1 = subplot(2, 2, 1);
if ~proc_data.isPitch
    plot(t, a_h(:, 2), 'k', 'LineWidth', 1.5, 'DisplayName', 'Head (Thực tế)'); hold on;
    plot(t, a_p(:, 2), 'r--', 'LineWidth', 1.2, 'DisplayName', 'Pivot (Chưa bù)');
    plot(t, a_p_comp(:, 2), 'b', 'LineWidth', 1.5, 'DisplayName', 'Pivot (Đã bù)');
    title(sprintf('Gia tốc dài Trục Y\nRMSE: %.4f -> %.4f', rmse_uncomp(2), rmse_comp(2)));
else
    plot(t, a_h(:, 1), 'k', 'LineWidth', 1.5, 'DisplayName', 'Head (Thực tế)'); hold on;
    plot(t, a_p(:, 1), 'r--', 'LineWidth', 1.2, 'DisplayName', 'Pivot (Chưa bù)');
    plot(t, a_p_comp(:, 1), 'b', 'LineWidth', 1.5, 'DisplayName', 'Pivot (Đã bù)');
    title(sprintf('Gia tốc dài Trục X\nRMSE: %.4f -> %.4f', rmse_uncomp(1), rmse_comp(1)));
end
grid on; legend('Location','best'); ylabel('m/s^2');

ax2 = subplot(2, 2, 3);
plot(t, a_h(:, 3), 'k', 'LineWidth', 1.5, 'DisplayName', 'Head (Thực tế)'); hold on;
plot(t, a_p(:, 3), 'r--', 'LineWidth', 1.2, 'DisplayName', 'Pivot (Chưa bù)');
plot(t, a_p_comp(:, 3), 'b', 'LineWidth', 1.5, 'DisplayName', 'Pivot (Đã bù)');
title(sprintf('Gia tốc dài Trục Z\nRMSE: %.4f -> %.4f', rmse_uncomp(3), rmse_comp(3)));
grid on; legend('Location','best'); ylabel('m/s^2'); xlabel('Time (s)');

% --- Cột 2: Vẽ Residual (Sai số) ---
err_uncomp_y = a_h(:, 2) - a_p(:, 2);
err_comp_y   = a_h(:, 2) - a_p_comp(:, 2);
err_uncomp_z = a_h(:, 3) - a_p(:, 3);
err_comp_z   = a_h(:, 3) - a_p_comp(:, 3);
err_uncomp_x = a_h(:, 1) - a_p(:, 1);
err_comp_x   = a_h(:, 1) - a_p_comp(:, 1);

ax3 = subplot(2, 2, 2);
if ~proc_data.isPitch
    plot(t, err_uncomp_y, 'r', 'DisplayName', 'Lỗi Chưa bù (Head - Pivot)'); hold on;
    plot(t, err_comp_y, 'b', 'DisplayName', 'Lỗi Đã bù (Head - Pivot_{comp})');
else
    plot(t, err_uncomp_x, 'r', 'DisplayName', 'Lỗi Chưa bù (Head - Pivot)'); hold on;
    plot(t, err_comp_x, 'b', 'DisplayName', 'Lỗi Đã bù (Head - Pivot_{comp})');
end
title('Phần dư sai số Trục Ngang'); grid on; legend('Location','best'); ylabel('m/s^2');

ax4 = subplot(2, 2, 4);
plot(t, err_uncomp_z, 'r', 'DisplayName', 'Lỗi Chưa bù (Head - Pivot)'); hold on;
plot(t, err_comp_z, 'b', 'DisplayName', 'Lỗi Đã bù (Head - Pivot_{comp})');
title('Phần dư sai số Trục Z'); grid on; legend('Location','best'); xlabel('Time (s)'); ylabel('m/s^2');

linkaxes([ax1 ax2 ax3 ax4], 'x');

%% 7. HÀM BỔ TRỢ (PCA)
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
