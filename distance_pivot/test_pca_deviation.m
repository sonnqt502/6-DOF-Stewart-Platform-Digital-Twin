% test_pca_deviation.m
function test_pca_deviation()
    pivot_file = 'Pivot_Command0.25.csv';
    
    raw_p = parseMoogFile(pivot_file);
    
    % Define columns
    cT = 1; cAxi = 8; cAyi = 9; cAzi = 10;
    cWx = 16; cWy = 15; cWz = 14;
    
    t_p_raw = raw_p(:, cT);
    W_raw_p = raw_p(:, [cWx, cWy, cWz]);
    Axi_raw_p = raw_p(:, [cAxi, cAyi, cAzi]);
    Grav_raw_p = raw_p(:, 11:13);
    
    t_static = 0.01;
    n_static_p = sum(t_p_raw - t_p_raw(1) <= t_static);
    if n_static_p < 10, n_static_p = 10; end
    
    X_raw_p = W_raw_p;
    mu_p = mean(X_raw_p);
    X_centered_p = X_raw_p - mu_p;
    C_p = (X_centered_p' * X_centered_p) / (size(X_centered_p, 1) - 1);
    [EigenVectors_p, EigenValuesDiag_p] = eig(C_p);
    [~, sortIdx_p] = sort(diag(EigenValuesDiag_p), 'descend');
    rot_axis_p = EigenVectors_p(:, sortIdx_p(1));
    
    g_vec_p = mean(Grav_raw_p(1:n_static_p, :))';
    g_vec_p = g_vec_p / norm(g_vec_p);
    
    if abs(rot_axis_p(1)) > abs(rot_axis_p(2))
        if rot_axis_p(1) < 0, rot_axis_p = -rot_axis_p; end 
        X_p = rot_axis_p; Y_p = cross(g_vec_p, X_p); Y_p = Y_p / norm(Y_p); Z_p = cross(X_p, Y_p); Z_p = Z_p / norm(Z_p);
        move_type = 'ROLL (Trục X)';
    else
        if rot_axis_p(2) < 0, rot_axis_p = -rot_axis_p; end 
        Y_p = rot_axis_p; X_p = cross(Y_p, g_vec_p); X_p = X_p / norm(X_p); Z_p = cross(X_p, Y_p); Z_p = Z_p / norm(Z_p);
        move_type = 'PITCH (Trục Y)';
    end
    R_PCA_p = [X_p, Y_p, Z_p];
    
    Rp = R_PCA_p; 
    roll_p  = atan2d(Rp(3,2), Rp(3,3));
    pitch_p = asind(max(min(-Rp(3,1), 1), -1)); 
    yaw_p   = atan2d(Rp(2,1), Rp(1,1));
    
    fprintf('PCA (%s) | Pivot[R: %f, P: %f, Y: %f]\n', move_type, roll_p, pitch_p, yaw_p);
end
