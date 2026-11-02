function plot_workspace_limits()
    % Đọc cấu hình
    cfg = jsondecode(fileread('config.json'));
    
    [A_mat, B_mat, gamma_ang] = computeGeometryLocal(cfg);
    L1 = cfg.l1;
    L2 = cfg.l2;
    mot_min = cfg.motor_limit_min;
    mot_max = cfg.motor_limit_max;

    % Định nghĩa các khoảng quét (Step = 10 theo yêu cầu)
    % X, Y: [-200, 200], Z: [200, 800]
    % Roll, Pitch, Yaw: [-20, 20] độ
    x_range = -200:10:200;
    y_range = -200:10:200;
    z_range = -300:10:300;
    r_range = -20:10:20;
    p_range = -20:10:20;
    yw_range = -20:10:20;

    % Mảng lưu giới hạn theo Z
    min_L_z = inf(size(z_range));
    max_L_z = -inf(size(z_range));

    fprintf('Bắt đầu quét không gian làm việc. Tổng số độ cao Z: %d\n', length(z_range));
    
    % Quét từng lớp Z để tránh tràn RAM
    for zi = 1:length(z_range)
        Z_val = z_range(zi);
        
        [X, Y, R, P, YW] = ndgrid(x_range, y_range, r_range, p_range, yw_range);
        N = numel(X);
        
        X = X(:)'; Y = Y(:)'; R = R(:)'; P = P(:)'; YW = YW(:)';
        Z = repmat(Z_val, 1, N);
        
        % Tính L và check IK trực tiếp
        valid_mask = true(1, N);
        L_lengths = zeros(6, N);
        
        for i = 1:N
            % Tối ưu bằng cách không gọi hàm con nhiều lần
            cy = cosd(YW(i)); sy = sind(YW(i));
            cp = cosd(P(i)); sp = sind(P(i));
            cr = cosd(R(i)); sr = sind(R(i));
            
            Rot = [cy*cp, cy*sp*sr - sy*cr, cy*sp*cr + sy*sr;
                   sy*cp, sy*sp*sr + cy*cr, sy*sp*cr - cy*sr;
                   -sp,   cp*sr,            cp*cr];
               
            T = [X(i); Y(i); Z(i)];
            
            L_vec = T + Rot * B_mat - A_mat;
            l_sq = sum(L_vec.^2, 1);
            L_lengths(:, i) = sqrt(l_sq)';
            
            Q = l_sq - L2^2 + L1^2;
            M_val = (2 * L1 * L_vec(3, :));
            N_val = 2 * L1 * (cosd(gamma_ang) .* L_vec(1, :) + sind(gamma_ang) .* L_vec(2, :));
            arg = Q ./ sqrt(M_val.^2 + N_val.^2);
            
            if any(abs(arg) > 1)
                valid_mask(i) = false;
                continue;
            end
            
            phi_raw = asind(arg) - atan2d(N_val, M_val);
            phi_out = zeros(1, 6);
            
            phi_out(1:2:5) = -(90 + phi_raw(1:2:5));
            phi_out(2:2:6) = (90 + phi_raw(2:2:6));
            phi_thuc = (phi_out - [90, -90, 90, -90, 90, -90]);
            phi_thuc(1:2:5) = -phi_thuc(1:2:5);
            
            % Kiểm tra giới hạn động cơ
            if any(phi_thuc < mot_min) || any(phi_thuc > mot_max)
                valid_mask(i) = false;
            end
        end
        
        % Lọc các điểm hợp lệ
        valid_L = L_lengths(:, valid_mask);
        if ~isempty(valid_L)
            min_L_z(zi) = min(valid_L(:));
            max_L_z(zi) = max(valid_L(:));
        end
        
        if mod(zi, 10) == 0
            fprintf('Đã quét xong Z = %d mm...\n', Z_val);
        end
    end
    
    % Xóa các lớp Z không có bất kỳ điểm hợp lệ nào
    valid_z_idx = ~isinf(min_L_z);
    z_plot = z_range(valid_z_idx);
    min_plot = min_L_z(valid_z_idx);
    max_plot = max_L_z(valid_z_idx);
    
    % Vẽ biểu đồ
    fig = figure('Name', 'Virtual Leg Limits by Z', 'Position', [100, 100, 800, 600]);
    plot(z_plot, min_plot, 'b-o', 'LineWidth', 2, 'MarkerFaceColor', 'b'); hold on;
    plot(z_plot, max_plot, 'r-s', 'LineWidth', 2, 'MarkerFaceColor', 'r');
    grid on;
    
    xlabel('Độ cao trục Z (mm)', 'FontSize', 12, 'FontWeight', 'bold');
    ylabel('Độ dài chân ảo L (mm)', 'FontSize', 12, 'FontWeight', 'bold');
    title('Biểu đồ giới hạn chiều dài chân ảo theo trục Z (Quét toàn không gian)', 'FontSize', 14);
    legend('Min L (mm)', 'Max L (mm)', 'Location', 'best', 'FontSize', 11);
    
    % Ghi chú Absolute Min / Max
    if ~isempty(min_plot) && ~isempty(max_plot)
        abs_min = min(min_plot);
        abs_max = max(max_plot);
        yline(abs_min, 'b--', sprintf('Absolute Min = %.2f', abs_min), 'LabelVerticalAlignment', 'bottom', 'LineWidth', 1.5);
        yline(abs_max, 'r--', sprintf('Absolute Max = %.2f', abs_max), 'LabelVerticalAlignment', 'top', 'LineWidth', 1.5);
        
        fprintf('\nKET QUA QUET TOAN BO KHOANG KHONG GIAN:\n');
        fprintf('Absolute Min L: %.2f mm\n', abs_min);
        fprintf('Absolute Max L: %.2f mm\n', abs_max);
    else
        fprintf('\nKHONG TIM THAY DIEM HOP LE NAO TRONG KHOANG QUET YEU CAU!\n');
    end
    
    saveas(fig, 'Virtual_Leg_Limits_Sweep.png');
end

function [A_mat, B_mat, gamma_ang] = computeGeometryLocal(cfg)
    alpha = zeros(1,6); beta = zeros(1,6);
    for k = 0:2
        alpha(2*k + 1) = -(cfg.a1 + k * 120); 
        alpha(2*k + 2) = -(cfg.a1 - cfg.da + (k+1) * 120);
        beta(2*k + 1)  = -(cfg.b1 + k * 120); 
        beta(2*k + 2)  = -(cfg.b1 + cfg.db + k * 120); 
    end

    if isfield(cfg, 'Z_MOTOR_OFFSET')
        Z_A = cfg.Z_MOTOR_OFFSET;
    else
        Z_A = 668.4; 
    end

    A_mat = zeros(3,6); B_mat = zeros(3,6); gamma_ang = zeros(1,6);
    for i = 1:6
        A_mat(1, i) = cfg.ra * cosd(alpha(i));
        A_mat(2, i) = cfg.ra * sind(alpha(i));
        A_mat(3, i) = Z_A;
        B_mat(1, i) = cfg.rb * cosd(beta(i)); 
        B_mat(2, i) = cfg.rb * sind(beta(i)); 
        B_mat(3, i) = 0;
        gamma_ang(i) = alpha(i) + ((-1)^(i)) * 90;
    end
end
