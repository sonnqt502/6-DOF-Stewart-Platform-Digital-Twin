function find_L_limits_FK_MonteCarlo()
    fprintf('Dang doc file config...\n');
    cfg = jsondecode(fileread('config.json'));
    
    % Ham lay A_mat, B_mat
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
            gamma_ang(i) = (alpha(i) + ((-1)^i) * 90);
        end
    end

    [A_mat, B_mat, gamma_ang] = computeGeometryLocal(cfg);
    L1 = cfg.l1;
    L2 = cfg.l2;
    mot_min = cfg.motor_limit_min;
    mot_max = cfg.motor_limit_max;

    % Tao mang goc cho tung motor voi step = 10
    step_val = 25;
    mot_range = mot_min:step_val:mot_max;
    N_steps = length(mot_range);
    
    total_iters = N_steps^6;
    fprintf('So buoc tung motor: %d\n', N_steps);
    fprintf('Tong so vong lap can chay: %d\n', total_iters);
    
    % Xin cap phat mang de luu toan bo gia tri L (co the rat lon, ~6*11M diem)
    all_L = zeros(1, total_iters * 6, 'single'); % dung single cho tiet kiem RAM
    L_idx = 1;

    min_L = inf;
    max_L = -inf;
    valid_count = 0;
    
    pose_guess = [0, 0, 0, 0, 0, 0];
    
    fprintf('Bat dau chay 6 vong lap for...\n');
    tic_start = tic;
    
    % Khoi tao Waitbar
    wb = waitbar(0, 'Đang chuẩn bị...', 'Name', 'Tiến độ quét không gian');
    
    iter_count = 0;
    
    for idx1 = 1:N_steps
        phi1 = mot_range(idx1);
        for idx2 = 1:N_steps
            phi2 = mot_range(idx2);
            for idx3 = 1:N_steps
                phi3 = mot_range(idx3);
                for idx4 = 1:N_steps
                    phi4 = mot_range(idx4);
                    for idx5 = 1:N_steps
                        phi5 = mot_range(idx5);
                        for idx6 = 1:N_steps
                            phi6 = mot_range(idx6);
                            
                            iter_count = iter_count + 1;
                            phi_thuc = [phi1, phi2, phi3, phi4, phi5, phi6];
                            
                            [pose_out, ~, err] = donghocthuan_NR(phi_thuc, pose_guess, A_mat, B_mat, L1, L2, gamma_ang);
                            
                            if err < 1 && ~any(isnan(pose_out))
                                x = pose_out(1); y = pose_out(2); z = pose_out(3);
                                roll = pose_out(4); pitch = pose_out(5); yaw = pose_out(6);
                                
                                cy = cosd(yaw); sy = sind(yaw);
                                cp = cosd(pitch); sp = sind(pitch);
                                cr = cosd(roll); sr = sind(roll);
                                R = [cy*cp, cy*sp*sr - sy*cr, cy*sp*cr + sy*sr;
                                     sy*cp, sy*sp*sr + cy*cr, sy*sp*cr - cy*sr;
                                     -sp,   cp*sr,            cp*cr];
                                 
                                T = [x; y; z];
                                L_vec = T + R * B_mat - A_mat;
                                L_lengths = sqrt(sum(L_vec.^2, 1));
                                
                                % Cap nhat gioi han
                                current_min = min(L_lengths);
                                current_max = max(L_lengths);
                                if current_min < min_L, min_L = current_min; end
                                if current_max > max_L, max_L = current_max; end
                                
                                % Luu lai vao mang
                                all_L(L_idx : L_idx+5) = single(L_lengths);
                                L_idx = L_idx + 6;
                                valid_count = valid_count + 1;
                                
                                % Cap nhat pose_guess cho vong lanh tiep theo de nhanh hon
                                pose_guess = pose_out;
                            end
                            
                            % Cap nhat tien do moi 20,000 vong lap
                            if mod(iter_count, 20000) == 0
                                t_elap = toc(tic_start);
                                speed = iter_count / t_elap; % iterations per second
                                eta_sec = (total_iters - iter_count) / speed;
                                
                                eta_h = floor(eta_sec / 3600);
                                eta_m = floor(mod(eta_sec, 3600) / 60);
                                eta_s = floor(mod(eta_sec, 60));
                                
                                prog_pct = iter_count / total_iters;
                                
                                msg = sprintf('Tốc độ: %.0f mẫu/s | ETA: %02d:%02d:%02d', speed, eta_h, eta_m, eta_s);
                                waitbar(prog_pct, wb, msg);
                                
                                fprintf('Tiến độ: %5.2f%% | Tốc độ: %5.0f mẫu/s | ETA: %02d:%02d:%02d | Hợp lệ: %d | Min L: %.2f | Max L: %.2f\n', ...
                                    prog_pct*100, speed, eta_h, eta_m, eta_s, valid_count, min_L, max_L);
                            end
                        end
                    end
                end
            end
        end
    end
    
    if ishandle(wb), close(wb); end
    t_elap = toc(tic_start);
    
    fprintf('========================================\n');
    fprintf('HOAN THANH QUET FK (Thoi gian: %.2f giay)\n', t_elap);
    fprintf('Min L: %.2f mm\n', min_L);
    fprintf('Max L: %.2f mm\n', max_L);
    fprintf('So luong tu the hop le: %d / %d\n', valid_count, total_iters);
    fprintf('========================================\n');
    
    fid = fopen('L_limits_FK_result.txt', 'w');
    fprintf(fid, 'Min L: %.2f\n', min_L);
    fprintf(fid, 'Max L: %.2f\n', max_L);
    fclose(fid);
    
    % Ve bieu do (histogram cac chieu dai chan ao)
    if L_idx > 1
        % Cat bo phan thua cua mang
        all_L = all_L(1 : L_idx-1);
        
        fig = figure('Name', 'Histogram of Virtual Legs', 'Position', [100, 100, 800, 500]);
        histogram(all_L, 200, 'FaceColor', [0.2 0.6 0.8], 'EdgeColor', 'none');
        hold on; grid on;
        
        % Highlight min L va max L
        xl_min = xline(min_L, 'r--', sprintf('Min L = %.2f', min_L), 'LineWidth', 2, 'LabelVerticalAlignment', 'top');
        xl_max = xline(max_L, 'r--', sprintf('Max L = %.2f', max_L), 'LineWidth', 2, 'LabelVerticalAlignment', 'top');
        xl_min.FontSize = 12; xl_min.FontWeight = 'bold';
        xl_max.FontSize = 12; xl_max.FontWeight = 'bold';
        
        title('Phân bố chiều dài chân ảo L khi quét toàn bộ cấu hình Motor (Step=10)', 'FontSize', 14);
        xlabel('Chiều dài chân ảo L (mm)', 'FontSize', 12, 'FontWeight', 'bold');
        ylabel('Tần suất (Số lượng chân)', 'FontSize', 12, 'FontWeight', 'bold');
        
        saveas(fig, 'Histogram_L_FK_Sweep.png');
        fprintf('Da luu bieu do vao Histogram_L_FK_Sweep.png\n');
    else
        fprintf('Khong co diem hop le nao de ve bieu do.\n');
    end
end