% Script: test_pipeline_pca.m
% Mục đích: Kiểm chứng thuật toán nắn trục PCA mới so với thuật toán cũ.
% Bạn hãy cấu hình 2 file ở dưới giống hệt nhau (hoặc khác nhau) để test.

clear; clc; close all;

%% CẤU HÌNH FILE
file_pivot = 'after_convert_10_0.25_0.csv';
file_head  = 'after_convert_10_0.25_0.csv';

fprintf('Đang phân tích Pivot: %s\n', file_pivot);
fprintf('Đang phân tích Head : %s\n', file_head);

% Load dữ liệu
data_p = parseMoogFile(file_pivot);
data_h = parseMoogFile(file_head);

% Các cột
cT=1; cAxi=8; cAyi=9; cAzi=10;
cWz=14; cWy=15; cWx=16;

t_p = data_p(:, cT); t_h = data_h(:, cT);
W_p_raw = data_p(:, [cWx, cWy, cWz]); W_h_raw = data_h(:, [cWx, cWy, cWz]);
Axi_p_raw = data_p(:, [cAxi, cAyi, cAzi]); Axi_h_raw = data_h(:, [cAxi, cAyi, cAzi]);
Grav_p_raw = data_p(:, 11:13); Grav_h_raw = data_h(:, 11:13);

%% 1. TÌM MA TRẬN R_PCA CHO HEAD (Thuật toán nào cũng cần)
[coeff_h, ~, ~] = pca(W_h_raw);
rot_h = coeff_h(:, 1);
if abs(rot_h(1)) > abs(rot_h(2))
    isPitch = false;
    if rot_h(1) < 0, rot_h = -rot_h; end; X = rot_h;
    g = mean(Grav_h_raw(1:1000, :))'; g = g/norm(g);
    Y = cross(g, X); Y = Y/norm(Y); Z = cross(X, Y); Z = Z/norm(Z);
else
    isPitch = true;
    if rot_h(2) < 0, rot_h = -rot_h; end; Y = rot_h;
    g = mean(Grav_h_raw(1:1000, :))'; g = g/norm(g);
    X = cross(Y, g); X = X/norm(X); Z = cross(X, Y); Z = Z/norm(Z);
end
R_PCA_H = [X, Y, Z];

%% 2. TÌM MA TRẬN R_PCA CHO PIVOT (Chỉ áp dụng cho thuật toán MỚI)
[coeff_p, ~, ~] = pca(W_p_raw);
rot_p = coeff_p(:, 1);
if abs(rot_p(1)) > abs(rot_p(2))
    if rot_p(1) < 0, rot_p = -rot_p; end; X = rot_p;
    g = mean(Grav_p_raw(1:1000, :))'; g = g/norm(g);
    Y = cross(g, X); Y = Y/norm(Y); Z = cross(X, Y); Z = Z/norm(Z);
else
    if rot_p(2) < 0, rot_p = -rot_p; end; Y = rot_p;
    g = mean(Grav_p_raw(1:1000, :))'; g = g/norm(g);
    X = cross(Y, g); X = X/norm(X); Z = cross(X, Y); Z = Z/norm(Z);
end
R_PCA_P = [X, Y, Z];


%% HÀM SOLVER: THỰC THI PIPELINE VÀ TÍNH KHOẢNG CÁCH R
solve_distance = @(W_p, Axi_p, W_h, Axi_h) calculate_r(t_p, W_p, Axi_p, t_h, W_h, Axi_h, isPitch);

%% TEST 1: THUẬT TOÁN CŨ (Pivot giữ nguyên Raw, Head được bù PCA)
fprintf('\n--- TEST 1: THUẬT TOÁN CŨ (CHỈ BÙ HEAD) ---\n');
W_h_aligned_old   = W_h_raw * R_PCA_H;
Axi_h_aligned_old = Axi_h_raw * R_PCA_H;
% Pivot KHÔNG nắn (R = Identity)
[r_old, da_old] = solve_distance(W_p_raw, Axi_p_raw, W_h_aligned_old, Axi_h_aligned_old);

if isPitch
    fprintf('Kết quả cũ: r_x = %.2f mm, r_z = %.2f mm\n', r_old(1), r_old(2));
else
    fprintf('Kết quả cũ: r_y = %.2f mm, r_z = %.2f mm\n', r_old(1), r_old(2));
end

%% TEST 2: THUẬT TOÁN MỚI (Cả Pivot và Head đều được nắn thẳng tuyệt đối bằng PCA)
fprintf('\n--- TEST 2: THUẬT TOÁN MỚI (BÙ CẢ PIVOT & HEAD) ---\n');
W_h_aligned_new   = W_h_raw * R_PCA_H;
Axi_h_aligned_new = Axi_h_raw * R_PCA_H;
% Pivot ĐƯỢC nắn
W_p_aligned_new   = W_p_raw * R_PCA_P;
Axi_p_aligned_new = Axi_p_raw * R_PCA_P;
[r_new, da_new] = solve_distance(W_p_aligned_new, Axi_p_aligned_new, W_h_aligned_new, Axi_h_aligned_new);

if isPitch
    fprintf('Kết quả MỚI: r_x = %.2f mm, r_z = %.2f mm\n', r_new(1), r_new(2));
else
    fprintf('Kết quả MỚI: r_y = %.2f mm, r_z = %.2f mm\n', r_new(1), r_new(2));
end


%% VẼ ĐỒ THỊ SO SÁNH SAI SỐ GIA TỐC (Delta Az)
figure('Name', 'So Sánh Thuật Toán', 'Position', [200, 200, 1000, 400]);
plot(da_old, 'r', 'LineWidth', 1.5, 'DisplayName', '\Delta Az (Thuật toán cũ - Sai số ảo lớn)'); hold on;
plot(da_new, 'b', 'LineWidth', 1.5, 'DisplayName', '\Delta Az (Thuật toán MỚI - Sai số bị triệt tiêu)');
title('Biểu đồ Sai số gia tốc \Delta Az sau khi trừ');
xlabel('Mẫu'); ylabel('m/s^2');
legend('Location', 'best'); grid on;


%% HÀM PHỤ TRỢ: CHẠY QUY TRÌNH KINEMATICS (Đạo hàm -> Đồng bộ -> Ma trận M)
function [r_sol_mm, da_az] = calculate_r(tp, wp, ap, th, wh, ah, isPitch)
    % 1. Lọc và Đạo hàm (Đơn giản hóa cho Head, không lọc Pivot như cũ)
    wh_filt = smoothdata(wh, 1, 'sgolay', 11);
    alpha_h = zeros(size(wh_filt));
    alpha_h(:,1) = gradient(wh_filt(:,1), th);
    alpha_h(:,2) = gradient(wh_filt(:,2), th);
    alpha_h(:,3) = gradient(wh_filt(:,3), th);
    
    % 2. Đồng bộ thời gian
    t_start = max(th(1), tp(1)); t_end = min(th(end), tp(end));
    mask_p = (tp >= t_start & tp <= t_end);
    tsync = tp(mask_p);
    
    wp_sync = wp(mask_p, :); ap_sync = ap(mask_p, :);
    
    wh_sync = zeros(length(tsync), 3); ah_sync = zeros(length(tsync), 3); alph_sync = zeros(length(tsync), 3);
    for i=1:3
        wh_sync(:,i) = interp1(th, wh(:,i), tsync, 'linear', 'extrap');
        ah_sync(:,i) = interp1(th, ah(:,i), tsync, 'linear', 'extrap');
        alph_sync(:,i) = interp1(th, alpha_h(:,i), tsync, 'linear', 'extrap');
    end
    
    % Lọc LPF (4Hz) cho Head
    Fs = 1/mean(diff(tsync)); fc = 4*2;
    [b, a] = butter(2, fc/(Fs/2), 'low');
    for i=1:3
        wh_sync(:,i) = filtfilt(b, a, wh_sync(:,i));
        ah_sync(:,i) = filtfilt(b, a, ah_sync(:,i));
        alph_sync(:,i) = filtfilt(b, a, alph_sync(:,i));
    end
    
    % 3. Tính toán Ma trận
    N = length(tsync);
    M_stack = zeros(2*N, 2); B_stack = zeros(2*N, 1);
    da_az = zeros(N, 1);
    
    for k = 1:N
        % TRỪ TRỰC TIẾP TRONG BODY FRAME (Không nhân R Euler)
        da = ah_sync(k,:)' - ap_sync(k,:)';
        da_az(k) = da(3);
        
        w = wh_sync(k,:)'; al = alph_sync(k,:)';
        Om = [0 -w(3) w(2); w(3) 0 -w(1); -w(2) w(1) 0];
        Al = [0 -al(3) al(2); al(3) 0 -al(1); -al(2) al(1) 0];
        M_k = Al + Om^2;
        
        if isPitch
            M_reduced = M_k([1, 3], [1, 3]);
            B_reduced = [da(1); da(3)];
        else
            M_reduced = M_k([2, 3], [2, 3]);
            B_reduced = [da(2); da(3)];
        end
        
        M_stack(2*k-1 : 2*k, :) = M_reduced;
        B_stack(2*k-1 : 2*k)    = B_reduced;
    end
    
    % Threshold
    norm_M = zeros(N, 1);
    for k=1:N, norm_M(k) = norm(M_stack((2*k-1):2*k, :), 'fro'); end
    norm_M_rep = repelem(norm_M, 2);
    thr = prctile(norm_M_rep, 30);
    valid_mask = norm_M_rep > thr;
    M_filt = M_stack(valid_mask, :); B_filt = B_stack(valid_mask);
    
    r_sol_m = M_filt \ B_filt;
    r_sol_mm = r_sol_m * 1000;
end
