% batch_eval_rigorous.m
function batch_eval_rigorous()
    clc;
    
    pivot_file = 'Pivot_Command.csv';
    head_dir = 'data_before_convert/roll_second';
    
    if ~exist(pivot_file, 'file')
        error('Khong tim thay Pivot_Command.csv');
    end
    if ~exist(head_dir, 'dir')
        error('Khong tim thay thu muc %s', head_dir);
    end
    
    % Doc Pivot
    raw_p = parseMoogFile(pivot_file);
    Axi_raw_p = raw_p(:, [11, 12, 13]); % Gia toc tong (Total Acceleration)
    W_raw_p   = raw_p(:, [16, 15, 14]); % w_x, w_y, w_z
    t_p_raw   = raw_p(:, 1);
    
    t_static = 3.0; % s
    
    static_mask_p = (t_p_raw >= 0) & (t_p_raw <= t_static);
    Axi_static_p = Axi_raw_p(static_mask_p, :);
    g_vec_p = mean(Axi_static_p); g_vec_p = g_vec_p / norm(g_vec_p);
    W_centered_p = W_raw_p - mean(W_raw_p);
    [eig_vecs_p, eig_vals_p] = eig(cov(W_centered_p));
    [~, max_idx_p] = max(diag(eig_vals_p));
    rot_axis_p = eig_vecs_p(:, max_idx_p);
    if rot_axis_p(1) < 0, rot_axis_p = -rot_axis_p; end % X-axis for Roll
    X_p = rot_axis_p; 
    Y_p = cross(g_vec_p(:), X_p(:)); Y_p = Y_p / norm(Y_p); 
    Z_p = cross(X_p(:), Y_p(:)); Z_p = Z_p / norm(Z_p);
    R_PCA_p = [X_p(:), Y_p(:), Z_p(:)];
    
    Axi_kinematic_p = (Axi_raw_p - g_vec_p * 9.81) * R_PCA_p;
    Axi_aligned_p = Axi_kinematic_p;
    W_aligned_p = W_raw_p * R_PCA_p;
    
    t_static = 3.0; % s
    
    % === LOOP QUA CAC FILE ===
    files = dir(fullfile(head_dir, '*.csv'));
    
    cz_list = zeros(length(files), 1);
    ry_list = zeros(length(files), 1);
    rz_list = zeros(length(files), 1);
    pearson_list = zeros(length(files), 1);
    rmse_list = zeros(length(files), 1);
    
    for i = 1:length(files)
        fname = files(i).name;
        % Parse centrez: z-100 10do 0.25hz.csv -> -100
        parts = split(fname, ' ');
        cz_str = strrep(parts{1}, 'z', '');
        cz = str2double(cz_str);
        cz_list(i) = cz;
        
        raw_h = readmatrix(fullfile(head_dir, fname), 'NumHeaderLines', 1);
        Axi_raw_h = raw_h(:, 2:4) * 9.81; % Total Acceleration
        W_raw_h   = raw_h(:, 5:7) * (pi / 180);
        Roll_h    = raw_h(:, 8);
        Pitch_h   = raw_h(:, 9);
        t_h = raw_h(:, 1);
        
        % 1. APPLY PCA CHO IMU
        static_mask_h = (t_h >= 0) & (t_h <= t_static);
        Axi_static_h = Axi_raw_h(static_mask_h, :);
        g_vec_h = mean(Axi_static_h); g_vec_h = g_vec_h / norm(g_vec_h);
        W_centered_h = W_raw_h - mean(W_raw_h);
        [eig_vecs_h, eig_vals_h] = eig(cov(W_centered_h));
        [~, max_idx_h] = max(diag(eig_vals_h));
        rot_axis_h = eig_vecs_h(:, max_idx_h);
        if rot_axis_h(1) < 0, rot_axis_h = -rot_axis_h; end % X-axis for Roll
        X_h = rot_axis_h;
        Y_h = cross(g_vec_h(:), X_h(:)); Y_h = Y_h / norm(Y_h);
        Z_h = cross(X_h(:), Y_h(:)); Z_h = Z_h / norm(Z_h);
        R_PCA_h = [X_h(:), Y_h(:), Z_h(:)];
        
        Axi_kinematic_h = (Axi_raw_h - g_vec_h * 9.81) * R_PCA_h;
        W_aligned_h = W_raw_h * R_PCA_h; 
        
        % 2. LAM MUOT W 
        W_aligned_h_smooth = smoothdata(W_aligned_h, 'sgolay', 15);
        
        % -----------------------------------
        
        % 3. TINH DAO HAM
        alpha_B = zeros(size(W_aligned_h_smooth));
        alpha_B(:,1) = gradient(W_aligned_h_smooth(:,1), t_h);
        alpha_B(:,2) = gradient(W_aligned_h_smooth(:,2), t_h);
        alpha_B(:,3) = gradient(W_aligned_h_smooth(:,3), t_h);
        
        % 4. DONG BO HOA
        t_start = max(t_h(1), t_p_raw(1));
        t_end   = min(t_h(end), t_p_raw(end));
        mask_p = (t_p_raw >= t_start & t_p_raw <= t_end);
        t_sync = t_p_raw(mask_p);
        
        pivot_sync_Axi = Axi_aligned_p(mask_p, :);
        pivot_sync_W = W_aligned_p(mask_p, :);
        
        head_sync_Axi = zeros(length(t_sync), 3);
        head_sync_W = zeros(length(t_sync), 3);
        alpha_sync = zeros(length(t_sync), 3);
        
        for c = 1:3
            head_sync_Axi(:, c) = interp1(t_h, Axi_kinematic_h(:, c), t_sync, 'linear', 'extrap');
            head_sync_W(:, c) = interp1(t_h, W_aligned_h_smooth(:, c), t_sync, 'linear', 'extrap');
            alpha_sync(:, c) = interp1(t_h, alpha_B(:, c), t_sync, 'linear', 'extrap');
        end

        % 3. TIME SYNC
        w_h_mag = vecnorm(W_aligned_h_smooth, 2, 2);
        w_p_mag = vecnorm(W_aligned_p, 2, 2);
        w_p_interp = interp1(t_p_raw, w_p_mag, t_h, 'linear', 'extrap');
        
        [xc, lags] = xcorr(w_h_mag - mean(w_h_mag), w_p_interp - mean(w_p_interp));
        [~, max_idx] = max(xc);
        delay_idx = lags(max_idx);
        dt = mean(diff(t_h));
        time_delay = delay_idx * dt;
        
        t_p_sync = t_p_raw + time_delay;
        
        Axi_kinematic_p_interp = interp1(t_p_sync, Axi_kinematic_p, t_h, 'linear', 'extrap');
        W_aligned_p_interp = interp1(t_p_sync, W_aligned_p, t_h, 'linear', 'extrap');
        
        Axi_kinematic_h_smooth = smoothdata(Axi_kinematic_h, 'movmean', 10);
        
        % Lay dao ham w de tinh alpha
        alpha_p = zeros(size(W_aligned_p_interp));
        for j = 1:3
            alpha_p(:, j) = gradient(W_aligned_p_interp(:, j), t_h);
        end
        alpha_p_smooth = smoothdata(alpha_p, 'sgolay', 15);
        
        % Giai pt: da = M * r + C -> (da - C) = M * r
        % De loai bo sai so do lech truc trong tap mo phong (sim gravity = 9.81 Z) 
        % va thuc te (IMU gravity bi lech 7 do), ta them hieu so gravity bias (C) vao Linear Solver.
        idx = (t_h >= t_static) & (t_h <= t_h(end)-1);
        
        W_h_sel = W_aligned_h_smooth(idx, :);
        A_h_sel = alpha_B(idx, :);
        da = Axi_kinematic_h_smooth(idx, :) - Axi_kinematic_p_interp(idx, :);
        
        N = sum(idx);
        % He phuong trinh cho 2 truc Y, Z
        % da_y = -wx^2 * ry - ax * rz + Cy
        % da_z =  ax * ry - wx^2 * rz + Cz
        H_all = zeros(2*N, 4);
        da_yz = zeros(2*N, 1);
        
        for k = 1:N
            wx = W_h_sel(k, 1); 
            ax = A_h_sel(k, 1); 
            
            % H_k = [ry, rz, Cy, Cz]
            H_k = [-wx^2, -ax,  1, 0;
                    ax,   -wx^2, 0, 1];
            
            row_idx = (k-1)*2 + 1 : k*2;
            H_all(row_idx, :) = H_k;
            da_yz(row_idx) = [da(k, 2); da(k, 3)];
        end
        
        % Least squares cho [ry; rz; Cy; Cz]
        sol = H_all \ da_yz;
        r_sol = [0; sol(1); sol(2)]; % rx = 0
        ry_list(i) = r_sol(2) * 1000;
        rz_list(i) = r_sol(3) * 1000;
        
        Cy = sol(3); Cz = sol(4);
        
        % Du doan da_y, da_z
        da_pred_yz = H_all * sol;
        pearson_list(i) = corr(da_yz, da_pred_yz);
        rmse_list(i) = sqrt(mean((da_yz - da_pred_yz).^2));
    end

    fprintf('=== RESULTS WITH RIGOROUS GLOBAL PCA ===\n');
    fprintf('%-10s | %-10s | %-10s | %-10s | %-10s\n', 'centrez', 'ry (mm)', 'rz (mm)', 'pearson', 'rmse');
    fprintf('---------------------------------------------------------------\n');
    
    % Sap xep theo cz giam dan
    [~, sortIdx] = sort(cz_list, 'descend');
    
    for idx = 1:length(sortIdx)
        i = sortIdx(idx);
        fprintf('%-10.1f | %-10.4f | %-10.4f | %-10.4f | %-10.4f\n', ...
            cz_list(i), ry_list(i), rz_list(i), pearson_list(i), rmse_list(i));
    end
end

function data = parseMoogFile(filepath)
    fid = fopen(filepath, 'rt');
    lines = {};
    while ~feof(fid)
        l = fgetl(fid);
        if contains(l, '~M[')
            lines{end+1} = l;
        end
    end
    fclose(fid);
    
    data = zeros(length(lines), 16);
    for i = 1:length(lines)
        s = strrep(lines{i}, '~M[', '');
        s = strrep(s, '[', '');
        parts = sscanf(s, '%f');
        data(i, 1:length(parts)) = parts';
    end
end
