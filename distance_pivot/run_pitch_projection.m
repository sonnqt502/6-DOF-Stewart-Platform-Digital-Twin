% run_pitch_projection.m
clc; clear; close all;

head_dir = 'data_before_convert/pitch_second';
files = {'z0 10do 0.25hz.csv', 'z-100 10do 0.25hz.csv', 'z-200 10do 0.25hz.csv', ...
         'z-300 10do 0.25hz.csv', 'z-400 10do 0.25hz.csv', 'z-500 10do 0.25hz.csv'};
centrez_list = [0, -100, -200, -300, -400, -500];

% Read the Moog Pivot Command for Pitch
raw_p = parseMoogFile('Pivot_Command_pitch.csv');
t_p_raw = raw_p(:, 1);
W_aligned_p = raw_p(:, [16, 15, 14]); % [wx, wy, wz] -> for Pitch, rotation should be around Y
Axi_aligned_p = raw_p(:, [11, 12, 13]); % [ax, ay, az]

disp('=== GEOMETRIC PROJECTION METHOD (PITCH) ===');
fprintf('%-10s | %-10s | %-10s | %-10s | %-10s | %-10s\n', 'centrez', 'Tilt(deg)', 'rx (mm)', 'rz (mm)', 'pearson', 'rmse');
fprintf(repmat('-', 1, 75));
fprintf('\n');

for i = 1:length(files)
    file_path = fullfile(head_dir, files{i});
    raw_h = readmatrix(file_path, 'NumHeaderLines', 1);
    
    t_h = raw_h(:, 1);
    Axi_raw_h = raw_h(:, 2:4) * 9.81;
    W_raw_h = raw_h(:, 5:7) * (pi / 180);
    
    % --- GEOMETRIC PROJECTION (NẮN THẲNG) ---
    t_static = 3.0;
    
    % 1. Truc Z: Thang dung 100% (Gravity)
    Axi_static = Axi_raw_h(t_h < t_static, :);
    Z_axis = mean(Axi_static, 1);
    Z_axis = Z_axis / norm(Z_axis);
    
    % 2. Nhận diện góc nghiêng của thanh ray
    W_dynamic = W_raw_h(t_h >= t_static & t_h < t_h(end)-1, :);
    if size(W_dynamic, 1) < 2
        error('W_dynamic is empty. t_h(end)=%f', t_h(end));
    end
    W_dynamic = W_dynamic - mean(W_dynamic, 1);
    [V, ~] = pca(W_dynamic);
    rot_axis = V(:, 1)';
    if rot_axis(2) < 0 % Force Y-direction for Pitch
        rot_axis = -rot_axis;
    end
    
    % Tinh goc nghieng giua truc quay (thanh ray) va mat phang ngang
    tilt_angle_rad = asin(abs(dot(rot_axis, Z_axis)));
    tilt_deg = tilt_angle_rad * 180 / pi;
    
    % 3. Ép truc Y nằm ngang 100%
    Y_axis = rot_axis - dot(rot_axis, Z_axis) * Z_axis;
    Y_axis = Y_axis / norm(Y_axis);
    
    % 4. Truc X = Y x Z
    X_axis = cross(Y_axis, Z_axis);
    X_axis = X_axis / norm(X_axis);
    
    % Global Projection Matrix
    R_PCA = [X_axis', Y_axis', Z_axis'];
    
    Axi_aligned_h = Axi_raw_h * R_PCA;
    W_aligned_h   = W_raw_h * R_PCA;
    
    % Smooth
    W_aligned_h_smooth = smoothdata(W_aligned_h, 'sgolay', 15);
    Axi_aligned_h_smooth = smoothdata(Axi_aligned_h, 'movmean', 10);
    
    % Kinematics
    alpha_B = zeros(size(W_aligned_h_smooth));
    for j=1:3
        alpha_B(:,j) = gradient(W_aligned_h_smooth(:,j), t_h);
    end
    
    % Sync
    w_h_mag = vecnorm(W_aligned_h_smooth, 2, 2);
    w_p_mag = vecnorm(W_aligned_p, 2, 2);
    w_p_interp = interp1(t_p_raw, w_p_mag, t_h, 'linear', 'extrap');
    
    [xc, lags] = xcorr(w_h_mag - mean(w_h_mag), w_p_interp - mean(w_p_interp));
    [~, max_idx] = max(xc);
    delay_idx = lags(max_idx);
    dt = mean(diff(t_h));
    t_p_sync = t_p_raw + delay_idx * dt;
    
    Axi_aligned_p_interp = interp1(t_p_sync, Axi_aligned_p, t_h, 'linear', 'extrap');
    W_aligned_p_interp = interp1(t_p_sync, W_aligned_p, t_h, 'linear', 'extrap');
    
    alpha_p = zeros(size(W_aligned_p_interp));
    for j = 1:3
        alpha_p(:, j) = gradient(W_aligned_p_interp(:, j), t_h);
    end
    alpha_p_smooth = smoothdata(alpha_p, 'sgolay', 15);
    
    idx = (t_h >= t_static) & (t_h <= t_h(end)-1);
    W_p_sel = W_aligned_p_interp(idx, :);
    A_p_sel = alpha_p_smooth(idx, :);
    da = Axi_aligned_h_smooth(idx, :) - Axi_aligned_p_interp(idx, :);
    
    N = sum(idx);
    % For Pitch (Rotation around Y):
    % ax = -wy^2 rx + ay rz (but ay is 0, alpha is alpha_y)
    % da_x = -wy^2 rx + alpha_y rz + Cx
    % da_z = -alpha_y rx - wy^2 rz + Cz
    H_all = zeros(2*N, 4);
    da_xz = zeros(2*N, 1);
    
    for k = 1:N
        wy = W_p_sel(k, 2); 
        ay = A_p_sel(k, 2); 
        
        H_k = [-wy^2,  ay, 1, 0;
               -ay, -wy^2, 0, 1];
        
        row_idx = (k-1)*2 + 1 : k*2;
        H_all(row_idx, :) = H_k;
        da_xz(row_idx) = [da(k, 1); da(k, 3)];
    end
    
    sol = H_all \ da_xz;
    rx = sol(1) * 1000;
    rz = sol(2) * 1000;
    
    da_pred = H_all * sol;
    pearson = corr(da_xz, da_pred);
    rmse = sqrt(mean((da_xz - da_pred).^2));
    
    fprintf('%-10.1f | %-10.4f | %-10.4f | %-10.4f | %-10.4f | %-10.4f\n', centrez_list(i), tilt_deg, rx, rz, pearson, rmse);
end
