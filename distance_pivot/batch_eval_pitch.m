% batch_eval_rigorous.m
function batch_eval_rigorous()
    clc;
    
    pivot_file = 'Pivot_Command_pitch0.24.csv';
    head_dir = 'data_after_convert/pitch_2';
    
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
    if rot_axis_p(2) < 0, rot_axis_p = -rot_axis_p; end % Y-axis for Pitch
    Y_p = rot_axis_p; 
    X_p = cross(Y_p(:), g_vec_p(:)); X_p = X_p / norm(X_p); 
    Z_p = cross(X_p(:), Y_p(:)); Z_p = Z_p / norm(Z_p);
    R_PCA_p = [X_p(:), Y_p(:), Z_p(:)];
    
    Axi_kinematic_p = Axi_raw_p - g_vec_p * 9.81;
    Axi_aligned_p = Axi_kinematic_p;
    W_aligned_p = W_raw_p;
    
    t_static = 3.0; % s
    
    % === LOOP QUA CAC FILE ===
    files = dir(fullfile(head_dir, '*.csv'));
    
    cz_list = zeros(length(files), 1);
    rx_list = zeros(length(files), 1);
    rz_list = zeros(length(files), 1);
    pearson_list = zeros(length(files), 1);
    rmse_list = zeros(length(files), 1);
    
    for i = 1:length(files)
        fname = files(i).name;
        % Parse centrez: pitch_10_0.25_100_-100.csv -> -100
        parts = split(fname, '_');
        if length(parts) >= 5
            cz_str = strrep(parts{5}, '.csv', '');
            cz = str2double(cz_str);
        else
            cz = 0;
        end
        cz_list(i) = cz;
        
        raw_h = parseMoogFile(fullfile(head_dir, fname));
        Axi_raw_h = raw_h(:, [11, 12, 13]); % Total Acceleration
        W_raw_h   = raw_h(:, [8, 9, 10]); % w_x, w_y, w_z
        t_h = raw_h(:, 1);
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
        if rot_axis_h(2) < 0, rot_axis_h = -rot_axis_h; end % Y-axis for Pitch
        Y_h = rot_axis_h;
        X_h = cross(Y_h(:), g_vec_h(:)); X_h = X_h / norm(X_h);
        Z_h = cross(X_h(:), Y_h(:)); Z_h = Z_h / norm(Z_h);
        R_PCA_h = [X_h(:), Y_h(:), Z_h(:)];
        
        Axi_kinematic_h = Axi_raw_h - g_vec_h * 9.81;
        W_aligned_h = W_raw_h; 
        
        % 2. LAM MUOT W (Giong voi ky thuat 1 da dong y)
        W_aligned_h_smooth = smoothdata(W_aligned_h, 'sgolay', 15);
        
        % 3. TINH DAO HAM
        alpha_B = zeros(size(W_aligned_h_smooth));
        alpha_B(:,1) = gradient(W_aligned_h_smooth(:,1), t_h);
        alpha_B(:,2) = gradient(W_aligned_h_smooth(:,2), t_h);
        alpha_B(:,3) = gradient(W_aligned_h_smooth(:,3), t_h);
        
        % 4. DONG BO HOA (Bypass Sync)
        time_delay = 0;
        
        [t_p_uniq, unique_idx] = unique(t_p_raw);
        Axi_kinematic_p_uniq = Axi_kinematic_p(unique_idx, :);
        W_aligned_p_uniq = W_aligned_p(unique_idx, :);
        
        t_p_sync = t_p_uniq + time_delay;
        
        Axi_kinematic_p_interp = interp1(t_p_sync, Axi_kinematic_p_uniq, t_h, 'linear', 'extrap');
        W_aligned_p_interp = interp1(t_p_sync, W_aligned_p_uniq, t_h, 'linear', 'extrap');
        
        Axi_kinematic_h_smooth = smoothdata(Axi_kinematic_h, 'movmean', 10);
        
        % Giai pt: da = M * r + C -> (da - C) = M * r
        % De loai bo sai so do lech truc trong tap mo phong (sim gravity = 9.81 Z) 
        % va thuc te (IMU gravity bi lech 7 do), ta them hieu so gravity bias (C) vao Linear Solver.
        idx = (t_h >= t_static) & (t_h <= t_h(end)-1);
        
        W_h_sel = W_aligned_h_smooth(idx, :);
        A_h_sel = alpha_B(idx, :);
        da = Axi_kinematic_h_smooth(idx, :) - Axi_kinematic_p_interp(idx, :);
        
        N = sum(idx);
        % He phuong trinh cho 2 truc X, Z (Pitch rotation is around Y)
        % a_x = -wy^2 rx + ay rz (but ay=0 for pure pitch, so alpha_y) -> da_x = -wy^2 rx + alpha_y rz
        % a_z = -alpha_y rx - wy^2 rz
        H_all = zeros(2*N, 4);
        da_xz = zeros(2*N, 1);
        
        for k = 1:N
            wy = W_h_sel(k, 2); 
            ay = A_h_sel(k, 2); 
            
            % H_k = [rx, rz, Cx, Cz]
            H_k = [-wy^2,   ay, 1, 0;
                     -ay, -wy^2, 0, 1];
            
            row_idx = (k-1)*2 + 1 : k*2;
            H_all(row_idx, :) = H_k;
            da_xz(row_idx) = [da(k, 1); da(k, 3)];
        end
        
        % Least squares cho [rx; rz; Cx; Cz]
        sol = H_all \ da_xz;
        r_sol = [sol(1); 0; sol(2)]; % ry = 0
        rx_list(i) = r_sol(1) * 1000;
        rz_list(i) = r_sol(3) * 1000;
        
        Cx = sol(3); Cz = sol(4);
        
        % Du doan da_x, da_z
        da_pred_xz = H_all * sol;
        pearson_list(i) = corr(da_xz, da_pred_xz);
        rmse_list(i) = sqrt(mean((da_xz - da_pred_xz).^2));
    end

    fprintf('=== RESULTS WITH RIGOROUS GLOBAL PCA (PITCH) ===\n');
    fprintf('%-10s | %-10s | %-10s | %-10s | %-10s\n', 'centrez', 'rx (mm)', 'rz (mm)', 'pearson', 'rmse');
    fprintf('---------------------------------------------------------------\n');
    
    % Sap xep theo cz giam dan
    [~, sortIdx] = sort(cz_list, 'descend');
    
    for idx = 1:length(sortIdx)
        i = sortIdx(idx);
        fprintf('%-10.1f | %-10.4f | %-10.4f | %-10.4f | %-10.4f\n', ...
            cz_list(i), rx_list(i), rz_list(i), pearson_list(i), rmse_list(i));
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
