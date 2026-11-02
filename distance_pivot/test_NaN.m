function test_NaN()
    pivot_file = 'Pivot_Command_pitch0.24.csv';
    fname = 'data_after_convert/pitch_2/pitch_10_0.25_100_0.csv';
    
    raw_p = parseMoogFile(pivot_file);
    Axi_raw_p = raw_p(:, [11, 12, 13]); 
    W_raw_p   = raw_p(:, [16, 15, 14]); 
    t_p_raw   = raw_p(:, 1);
    
    t_static = 3.0; 
    
    static_mask_p = (t_p_raw >= 0) & (t_p_raw <= t_static);
    Axi_static_p = Axi_raw_p(static_mask_p, :);
    g_vec_p = mean(Axi_static_p); g_vec_p = g_vec_p / norm(g_vec_p);
    W_centered_p = W_raw_p - mean(W_raw_p);
    [eig_vecs_p, eig_vals_p] = eig(cov(W_centered_p));
    [~, max_idx_p] = max(diag(eig_vals_p));
    rot_axis_p = eig_vecs_p(:, max_idx_p);
    if rot_axis_p(2) < 0, rot_axis_p = -rot_axis_p; end 
    Y_p = rot_axis_p; 
    X_p = cross(Y_p(:), g_vec_p(:)); X_p = X_p / norm(X_p); 
    Z_p = cross(X_p(:), Y_p(:)); Z_p = Z_p / norm(Z_p);
    R_PCA_p = [X_p(:), Y_p(:), Z_p(:)];
    
    Axi_kinematic_p = bsxfun(@minus, Axi_raw_p, g_vec_p * 9.81) * R_PCA_p;
    W_aligned_p = W_raw_p * R_PCA_p;

    raw_h = readmatrix(fname, 'NumHeaderLines', 1);
    Axi_raw_h = raw_h(:, 2:4) * 9.81;
    W_raw_h   = raw_h(:, 5:7) * (pi / 180);
    t_h = raw_h(:, 1);

    static_mask_h = (t_h >= 0) & (t_h <= t_static);
    Axi_static_h = Axi_raw_h(static_mask_h, :);
    g_vec_h = mean(Axi_static_h); g_vec_h = g_vec_h / norm(g_vec_h);
    W_centered_h = W_raw_h - mean(W_raw_h);
    [eig_vecs_h, eig_vals_h] = eig(cov(W_centered_h));
    [~, max_idx_h] = max(diag(eig_vals_h));
    rot_axis_h = eig_vecs_h(:, max_idx_h);
    if rot_axis_h(2) < 0, rot_axis_h = -rot_axis_h; end 
    Y_h = rot_axis_h;
    X_h = cross(Y_h(:), g_vec_h(:)); X_h = X_h / norm(X_h);
    Z_h = cross(X_h(:), Y_h(:)); Z_h = Z_h / norm(Z_h);
    R_PCA_h = [X_h(:), Y_h(:), Z_h(:)];
    
    Axi_kinematic_h = bsxfun(@minus, Axi_raw_h, g_vec_h * 9.81) * R_PCA_h;
    W_aligned_h = W_raw_h * R_PCA_h; 
    
    fprintf('Axi_kinematic_p NaN: %d\n', any(isnan(Axi_kinematic_p(:))));
    fprintf('Axi_kinematic_h NaN: %d\n', any(isnan(Axi_kinematic_h(:))));
    fprintf('R_PCA_p: \n'); disp(R_PCA_p);
    fprintf('R_PCA_h: \n'); disp(R_PCA_h);
    
    W_aligned_h_smooth = smoothdata(W_aligned_h, 'sgolay', 15);
    alpha_B = zeros(size(W_aligned_h_smooth));
    alpha_B(:,1) = gradient(W_aligned_h_smooth(:,1), t_h);
    alpha_B(:,2) = gradient(W_aligned_h_smooth(:,2), t_h);
    alpha_B(:,3) = gradient(W_aligned_h_smooth(:,3), t_h);
    
    w_h_y = W_aligned_h_smooth(:, 2);
    w_p_y = W_aligned_p(:, 2);
    
    [~, unique_idx] = unique(t_p_raw);
    t_p_uniq = t_p_raw(unique_idx);
    w_p_y_uniq = w_p_y(unique_idx);
    
    w_p_interp = interp1(t_p_uniq, w_p_y_uniq, t_h, 'linear', 'extrap');
    
    [xc, lags] = xcorr(w_h_y - mean(w_h_y), w_p_interp - mean(w_p_interp));
    [~, max_idx] = max(xc);
    delay_idx = lags(max_idx);
    dt = mean(diff(t_h));
    time_delay = delay_idx * dt;
    fprintf('Delay idx: %d, time_delay: %f\n', delay_idx, time_delay);
    
    t_p_sync = t_p_uniq + time_delay;
    Axi_uniq = Axi_kinematic_p(unique_idx, :);
    
    Axi_kinematic_p_interp = interp1(t_p_sync, Axi_uniq, t_h, 'linear', 'extrap');
    fprintf('Axi_kinematic_p_interp NaN: %d\n', any(isnan(Axi_kinematic_p_interp(:))));
    
    Axi_kinematic_h_smooth = smoothdata(Axi_kinematic_h, 'movmean', 10);
    
    idx = (t_h >= t_static) & (t_h <= t_h(end)-1);
    fprintf('Sum of idx: %d\n', sum(idx));
    
    da = Axi_kinematic_h_smooth(idx, :) - Axi_kinematic_p_interp(idx, :);
    fprintf('da NaN: %d\n', any(isnan(da(:))));
end
