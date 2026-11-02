function [r_sol_mm, math_metrics] = module3_math_engine(proc_data, head_sync)
% MODULE 3: LÕI TOÁN HỌC KHÔNG GIAN 3D VÀ KHỬ SUY BIẾN MA TRẬN
% Tích hợp Ma trận quay R (Z-down) và đồng bộ hệ quy chiếu gia tốc

    % 0. Khởi tạo giá trị mặc định để chống lỗi Output not assigned
    r_sol_mm = [0; 0];
    math_metrics = struct('RMSE', NaN, 'RelativeError', NaN, ...
                          'M_mat', [], 'B_vec', [], 'valid_mask', []);

    disp('--- Chạy Module 3: Giải hệ phương trình Động lực học ---');
    N = length(proc_data.t);
    isPitch = proc_data.isPitch;
    
    alpha_1D = proc_data.alpha_h; 
    gyro_1D  = proc_data.gyro_h;

    % 1. XÂY DỰNG MA TRẬN THEO LÝ THUYẾT ĐỘNG LỰC HỌC VÀ HỆ QUY CHIẾU
    M_stack = zeros(2*N, 2);
    B_stack = zeros(2*N, 1);
    
    warn_3D_singularity = false; 
    for k = 1:N
        % Trừ gia tốc tịnh tiến trong cùng hệ tọa độ Pivot Body Frame
        % Ở Bước 1, gia tốc của Head đã được bù (Offset) về hệ tọa độ của Pivot.
        % Do đó cả ax_h và ax_p đều đang cùng nằm trong hệ tọa độ Body của Pivot.
        a_h_body = [proc_data.ax_h(k); proc_data.ay_h(k); proc_data.az_h(k)];
        a_p_body = [proc_data.ax_p(k); proc_data.ay_p(k); proc_data.az_p(k)];
        
        da = a_h_body - a_p_body;
        
        % Tái tạo vector 3D tùy theo bài test động học
        if isPitch
            w  = [0; gyro_1D(k); 0];
            al = [0; alpha_1D(k); 0];
        else 
            w  = [gyro_1D(k); 0; 0];
            al = [alpha_1D(k); 0; 0];
        end
        
        % Ma trận bất đối xứng (Skew-symmetric matrix)
        Omega_skew = [   0,  -w(3),   w(2);
                      w(3),      0,  -w(1);
                     -w(2),   w(1),     0 ];
                     
        Alpha_skew = [   0, -al(3),  al(2);
                     al(3),      0, -al(1);
                    -al(2),  al(1),     0 ];
        
        M_k = Alpha_skew + Omega_skew^2;
        
        if k == 1 && rank(M_k) < 3
            warn_3D_singularity = true;
        end
        
        % Trích xuất chuyển động để tránh bẫy suy biến ma trận 3D
        if isPitch
            M_reduced = M_k([1, 3], [1, 3]);
            B_reduced = [da(1); da(3)];
        else
            M_reduced = M_k([2, 3], [2, 3]);
            B_reduced = [da(2); da(3)];
        end
        
        idx = (2*k - 1) : 2*k;
        M_stack(idx, :) = M_reduced;
        B_stack(idx)    = B_reduced;
    end

    if warn_3D_singularity
        fprintf(' [!] CẢNH BÁO LÝ THUYẾT: Ma trận M 3D bị suy biến (do chỉ kích thích 1 trục).\n');
    end

    % 2. KHỬ CÁC ĐIỂM DỮ LIỆU YẾU (Dựa trên chuẩn Frobenius)
    norm_M = zeros(N, 1);
    for k = 1:N
        idx = (2*k - 1) : 2*k;
        norm_M(k) = norm(M_stack(idx, :), 'fro');
    end
    norm_M_rep = repelem(norm_M, 2);
    
    thr = prctile(norm_M_rep, 30); 
    valid_mask = norm_M_rep > thr;
    
    M_filtered = M_stack(valid_mask, :);
    B_filtered = B_stack(valid_mask);
    
    rank_M = rank(M_filtered);
    if rank_M < 2
        error('LỖI NGHIÊM TRỌNG: Ma trận M gộp bị suy biến (Rank = %d < 2).', rank_M);
    end

    % 3. GIẢI BÀI TOÁN BÌNH PHƯƠNG TỐI THIỂU
    r_sol_m = M_filtered \ B_filtered; 
    r_sol_mm = r_sol_m * 1000;
    
   % 4. ĐÁNH GIÁ CHẤT LƯỢNG NGHIỆM (SO SÁNH GIA TỐC THỰC TẾ VS TÍNH TOÁN)
    % Tính toán lại gia tốc mô hình trên toàn bộ tập dữ liệu (N mẫu)
    acc_calc_all = M_stack * r_sol_m;
    
    % Trích xuất gia tốc đo được (thực tế) và tính toán (mô hình) theo từng trục
    d_meas_1 = B_stack(1:2:end); % Trục ngang (X nếu Pitch, Y nếu Roll)
    d_meas_2 = B_stack(2:2:end); % Trục Z
    
    d_calc_1 = acc_calc_all(1:2:end);
    d_calc_2 = acc_calc_all(2:2:end);
    
    % Tính RMSE so sánh trực tiếp cho từng trục
    rmse_1 = sqrt(mean((d_meas_1 - d_calc_1).^2));
    rmse_2 = sqrt(mean((d_meas_2 - d_calc_2).^2));
    rmse_total = sqrt(mean((B_stack - acc_calc_all).^2));
    
    % Tính RMS tín hiệu gốc để ra % sai số tương đối
    rms_sig_1 = sqrt(mean(d_meas_1.^2));
    rms_sig_2 = sqrt(mean(d_meas_2.^2));
    rms_sig_total = sqrt(mean(B_stack.^2));
    
    rel_err_1 = (rmse_1 / rms_sig_1) * 100;
    rel_err_2 = (rmse_2 / rms_sig_2) * 100;
    rel_err_total = (rmse_total / rms_sig_total) * 100;
    
    math_metrics.RMSE = rmse_total;
    math_metrics.RelativeError = rel_err_total;
    math_metrics.M_mat = M_stack;
    math_metrics.B_vec = B_stack;
    math_metrics.valid_mask = valid_mask;
    
    % 5. IN BÁO CÁO KẾT QUẢ
    fprintf('\n--- KẾT QUẢ KHOẢNG CÁCH KHỚP A DƯỚI -> KHỚP B TRÊN ---\n');
    if isPitch
        axis_name = 'X';
    else
        axis_name = 'Y';
    end
    
    fprintf('  r%s = %8.3f mm\n', lower(axis_name), r_sol_mm(1));
    fprintf('  rz = %8.3f mm\n', r_sol_mm(2));
    fprintf('  |r| = %.3f mm\n', norm(r_sol_mm));
    fprintf('-----------------------------------------------------------\n');
    fprintf('  CHI TIẾT SAI SỐ (Gia tốc Đo đạc vs Mô hình):\n');
    fprintf('   + Trục %s: RMSE = %.6f m/s^2 | Sai số = %5.2f%%\n', axis_name, rmse_1, rel_err_1);
    fprintf('   + Trục Z: RMSE = %.6f m/s^2 | Sai số = %5.2f%%\n', rmse_2, rel_err_2);
    fprintf('   + TỔNG  : RMSE = %.6f m/s^2 | Sai số = %5.2f%%\n\n', rmse_total, rel_err_total);
end

% =========================================================================
% HÀM BỔ TRỢ: TÍNH MA TRẬN QUAY THEO CHUẨN Z-DOWN
% =========================================================================
function R = getRotationMatrix(yaw, pitch, roll)
    psi = deg2rad(yaw); theta = deg2rad(pitch); phi = deg2rad(roll);
    c = @cos; s = @sin;
    R = [ c(psi)*c(theta),  c(psi)*s(theta)*s(phi) - s(psi)*c(phi),  c(psi)*s(theta)*c(phi) + s(psi)*s(phi);
          s(psi)*c(theta),  s(psi)*s(theta)*s(phi) + c(psi)*c(phi),  s(psi)*s(theta)*c(phi) - c(psi)*s(phi);
         -s(theta),         c(theta)*s(phi),                         c(theta)*c(phi) ];
end

% =========================================================================
% HÀM BỔ TRỢ: VẼ ĐỒ THỊ SO SÁNH GIA TỐC THỰC TẾ VS MÔ HÌNH TOÁN HỌC
% =========================================================================
function plot_validation_internal(proc_data, head_sync, r_sol, isPitch)
    N = length(proc_data.t);
    M_full = zeros(2*N, 2);
    d_meas = zeros(N, 2);
    
    % Xây dựng lại quỹ đạo gia tốc trên hệ quy chiếu đã xoay
    for k = 1:N
        % Trừ gia tốc tịnh tiến trong cùng hệ tọa độ Pivot Body Frame
        % Ở Bước 1, gia tốc của Head đã được bù (Offset) về hệ tọa độ của Pivot.
        % Do đó cả ax_h và ax_p đều đang cùng nằm trong hệ tọa độ Body của Pivot.
        a_h_body = [proc_data.ax_h(k); proc_data.ay_h(k); proc_data.az_h(k)];
        a_p_body = [proc_data.ax_p(k); proc_data.ay_p(k); proc_data.az_p(k)];
        
        da = a_h_body - a_p_body;
        
        if isPitch
            w  = [0; proc_data.gyro_h(k); 0];
            al = [0; proc_data.alpha_h(k); 0];
            d_meas(k, :) = [da(1), da(3)];
        else
            w  = [proc_data.gyro_h(k); 0; 0];
            al = [proc_data.alpha_h(k); 0; 0];
            d_meas(k, :) = [da(2), da(3)];
        end
        
        Om = [0 -w(3) w(2); w(3) 0 -w(1); -w(2) w(1) 0];
        Al = [0 -al(3) al(2); al(3) 0 -al(1); -al(2) al(1) 0];
        M_k = Al + Om^2;
        
        if isPitch
            M_full(2*k-1:2*k, :) = M_k([1, 3], [1, 3]);
        else
            M_full(2*k-1:2*k, :) = M_k([2, 3], [2, 3]);
        end
    end
    
    acc_calc = M_full * r_sol;
    d_calc = [acc_calc(1:2:end), acc_calc(2:2:end)];
    
    if isPitch
        labels = {'\Delta ax', '\Delta az'};
    else
        labels = {'\Delta ay', '\Delta az'};
    end
    
    figure('Name', 'Module 3: Validation (Full Fidelity)', 'Position', [200 200 800 500]);
    for i = 1:2
        subplot(2,1,i);
        plot(proc_data.t, d_meas(:,i), 'k-', 'LineWidth', 1, 'DisplayName', 'Đo đạc (Đã xoay hệ trục)'); hold on;
        plot(proc_data.t, d_calc(:,i), 'r--', 'LineWidth', 1.5, 'DisplayName', 'Mô hình tính toán');
        ylabel(labels{i}); grid on; legend('Location', 'best');
        if i==1, title('Kiểm chứng nghiệm r: Gia tốc đo được vs Gia tốc mô hình'); end
    end
    xlabel('Thời gian (s)');
end