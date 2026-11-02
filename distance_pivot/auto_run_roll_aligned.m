function auto_run_roll_aligned()
    % Định nghĩa các cột
    cT = 1; cAxi = 8; cAyi = 9; cAzi = 10;
    cWz = 14; cWy = 15; cWx = 16;
    
    % 1. Xử lý Pivot
    raw_p = parseMoogFile('Pivot_Command.csv');
    Axi_raw_p = raw_p(:, [cAxi, cAyi, cAzi]);
    W_raw_p   = raw_p(:, [cWx,  cWy,  cWz ]);
    
    n_samples_p = min(2000, size(W_raw_p, 1)); 
    X_raw_p = W_raw_p(1:n_samples_p, :);
    mu_p = mean(X_raw_p);
    X_centered_p = X_raw_p - mu_p;
    C_p = (X_centered_p' * X_centered_p) / (n_samples_p - 1);
    [EigenVectors_p, EigenValuesDiag_p] = eig(C_p);
    EigenValues_p = diag(EigenValuesDiag_p);
    [~, sortIdx_p] = sort(EigenValues_p, 'descend');
    EigenVectors_p = EigenVectors_p(:, sortIdx_p);
    rot_axis_p = EigenVectors_p(:, 1);
    
    Grav_raw_p = raw_p(:, 11:13);
    g_vec_p = mean(Grav_raw_p(1:n_samples_p, :))';
    g_vec_p = g_vec_p / norm(g_vec_p);
    
    if rot_axis_p(1) < 0, rot_axis_p = -rot_axis_p; end 
    X_p = rot_axis_p;
    Y_p = cross(g_vec_p, X_p); Y_p = Y_p / norm(Y_p);
    Z_p = cross(X_p, Y_p); Z_p = Z_p / norm(Z_p);
    R_PCA_p = [X_p, Y_p, Z_p]; 
    
    Axi_aligned_p = Axi_raw_p * R_PCA_p;
    W_aligned_p   = W_raw_p * R_PCA_p;
    pivot_aligned = raw_p;
    pivot_aligned(:, [cAxi, cAyi, cAzi]) = Axi_aligned_p;
    pivot_aligned(:, [cWx,  cWy,  cWz ]) = W_aligned_p;
    
    % 2. Tìm tất cả file _dash.txt trong data_after_convert\roll_2\
    files = dir('data_after_convert\roll_2\*_dash.txt');
    
    fprintf('%-60s | %-8s | %-8s | %-15s | %-15s | %-15s | %-15s\n', 'File Name', 'ry (mm)', 'rz (mm)', 'Pearson (ay)', 'Pearson (az)', 'RMSE (ay)', 'RMSE (az)');
    fprintf('%s\n', repmat('-', 1, 150));
    
    for f_idx = 1:length(files)
        head_file = fullfile(files(f_idx).folder, files(f_idx).name);
        
        try
            raw_h = parseMoogFile(head_file);
            if isempty(raw_h)
                continue;
            end
            
            Axi_raw_h = raw_h(:, [cAxi, cAyi, cAzi]);
            Axi_raw_h(:, 2) = -Axi_raw_h(:, 2);
            Axi_raw_h(:, 3) = -Axi_raw_h(:, 3);
            W_raw_h   = raw_h(:, [cWx,  cWy,  cWz ]);
            
            n_samples_h = min(2000, size(W_raw_h, 1)); 
            X_raw_h = W_raw_h(1:n_samples_h, :);
            mu_h = mean(X_raw_h);
            X_centered_h = X_raw_h - mu_h;
            C_h = (X_centered_h' * X_centered_h) / (n_samples_h - 1);
            [EigenVectors_h, EigenValuesDiag_h] = eig(C_h);
            EigenValues_h = diag(EigenValuesDiag_h);
            [~, sortIdx_h] = sort(EigenValues_h, 'descend');
            EigenVectors_h = EigenVectors_h(:, sortIdx_h);
            rot_axis_h = EigenVectors_h(:, 1); 
            
            Grav_raw_h = raw_h(:, 11:13);
            g_vec_h = mean(Grav_raw_h(1:n_samples_h, :))';
            g_vec_h = g_vec_h / norm(g_vec_h);
            
            if rot_axis_h(1) < 0, rot_axis_h = -rot_axis_h; end 
            X_h = rot_axis_h;
            Y_h = cross(g_vec_h, X_h); Y_h = Y_h / norm(Y_h);
            Z_h = cross(X_h, Y_h); Z_h = Z_h / norm(Z_h);
            R_PCA_h = [X_h, Y_h, Z_h]; 
            
            Axi_aligned_h = Axi_raw_h * R_PCA_h;
            W_aligned_h   = W_raw_h * R_PCA_h;
            head_aligned = raw_h;
            head_aligned(:, [cAxi, cAyi, cAzi]) = Axi_aligned_h;
            head_aligned(:, [cWx,  cWy,  cWz ]) = W_aligned_h;
            
            t_h = head_aligned(:, cT);
            W_B = head_aligned(:, [cWx, cWy, cWz]);
            alpha_B = zeros(size(W_B));
            alpha_B(:,1) = gradient(W_B(:,1), t_h);
            alpha_B(:,2) = gradient(W_B(:,2), t_h);
            alpha_B(:,3) = gradient(W_B(:,3), t_h);
            
            t_p = pivot_aligned(:, cT);
            t_start = max(t_h(1), t_p(1));
            t_end   = min(t_h(end), t_p(end));
            mask_p = (t_p >= t_start & t_p <= t_end);
            t_sync = t_p(mask_p);
            pivot_sync = pivot_aligned(mask_p, :);
            
            head_sync = zeros(length(t_sync), size(head_aligned, 2));
            head_sync(:, 1) = t_sync;
            for col = 2:size(head_aligned, 2)
                head_sync(:, col) = interp1(t_h, head_aligned(:, col), t_sync, 'linear', 'extrap');
            end
            alpha_sync = zeros(length(t_sync), 3);
            for i = 1:3
                alpha_sync(:, i) = interp1(t_h, alpha_B(:, i), t_sync, 'linear', 'extrap');
            end
            
            % Tự cắt đi 2s đầu
            t_start_crop = t_sync(1) + 2.0;
            mask = (t_sync >= t_start_crop);
            t_sync = t_sync(mask);
            head_sync = head_sync(mask, :);
            pivot_sync = pivot_sync(mask, :);
            alpha_sync = alpha_sync(mask, :);
            
            N = length(t_sync);
            M_stack = zeros(2*N, 2);
            B_stack = zeros(2*N, 1);
            for k = 1:N
                % THESE ARE IN THE ALIGNED FRAME (because of PCA)
                a_h_aligned = [head_sync(k, cAxi); head_sync(k, cAyi); head_sync(k, cAzi)];
                a_p_aligned = [pivot_sync(k, cAxi); pivot_sync(k, cAyi); pivot_sync(k, cAzi)];
                w_aligned = [head_sync(k, cWx); head_sync(k, cWy); head_sync(k, cWz)];
                al_aligned = alpha_sync(k, :)';
                
                % DIRECTLY SOLVE IN ALIGNED FRAME! NO R_p INVERSE TRANSFORM!
                da = a_h_aligned - a_p_aligned;
                w = w_aligned;
                al = al_aligned;
                
                Om = [0 -w(3) w(2); w(3) 0 -w(1); -w(2) w(1) 0];
                Al = [0 -al(3) al(2); al(3) 0 -al(1); -al(2) al(1) 0];
                M_k = Al + Om^2;
                
                M_reduced = M_k([2, 3], [2, 3]);
                B_reduced = [da(2); da(3)];
                
                idx = (2*k - 1) : 2*k;
                M_stack(idx, :) = M_reduced;
                B_stack(idx)    = B_reduced;
            end
            
            r_sol_m = M_stack \ B_stack;
            r_sol_mm = r_sol_m * 1000;
            
            acc_calc = M_stack * r_sol_m;
            d_calc_1 = acc_calc(1:2:end); 
            d_calc_2 = acc_calc(2:2:end);
            
            a_p_1 = pivot_sync(:, cAyi);
            a_p_2 = pivot_sync(:, cAzi);
            a_meas_1 = head_sync(:, cAyi);
            a_meas_2 = head_sync(:, cAzi);
            
            a_calc_1 = a_p_1 + d_calc_1;
            a_calc_2 = a_p_2 + d_calc_2;
            
            rmse_1 = sqrt(mean((a_meas_1 - a_calc_1).^2));
            rmse_2 = sqrt(mean((a_meas_2 - a_calc_2).^2));
            
            R1_mat = corrcoef(a_meas_1, a_calc_1); p_1 = R1_mat(1,2);
            R2_mat = corrcoef(a_meas_2, a_calc_2); p_2 = R2_mat(1,2);
            
            fprintf('%-60s | %-8.2f | %-8.2f | %-15.4f | %-15.4f | %-15.4f | %-15.4f\n', files(f_idx).name, r_sol_mm(1), r_sol_mm(2), p_1, p_2, rmse_1, rmse_2);
            
        catch ME
            fprintf('%-60s | ERROR: %s\n', files(f_idx).name, ME.message);
        end
    end
end
