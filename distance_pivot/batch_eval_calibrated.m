% batch_eval_calibrated.m
function batch_eval_calibrated()
    clc;
    
    pivot_file = 'Pivot_Command.csv';
    head_dir = 'data_after_convert/roll_2';
    
    if ~exist(pivot_file, 'file')
        error('Khong tim thay Pivot_Command.csv');
    end
    
    raw_p = parseMoogFile(pivot_file);
    
    files = dir(fullfile(head_dir, '*.csv'));
    
    % Arrays to store results for calibration
    cz_list = zeros(length(files), 1);
    ry_list = zeros(length(files), 1);
    rz_list = zeros(length(files), 1);
    pearson_list = zeros(length(files), 1);
    rmse_list = zeros(length(files), 1);
    
    for i = 1:length(files)
        fname = files(i).name;
        % Parse centrez tu ten file: roll_10_0.25_100_0.csv -> 0
        parts = split(fname, '_');
        if length(parts) >= 5
            cz_str = strrep(parts{5}, '.csv', '');
            cz = str2double(cz_str);
        else
            cz = NaN;
        end
        cz_list(i) = cz;
        
        raw_h = parseMoogFile(fullfile(head_dir, fname));
        
        % DONG BO VA TINH TOAN
        % Head
        Axi_raw_h = raw_h(:, [8, 9, 10]);
        % Dao nguoc ay, az
        Axi_raw_h(:, 2) = -Axi_raw_h(:, 2);
        Axi_raw_h(:, 3) = -Axi_raw_h(:, 3);
        
        W_raw_h = raw_h(:, [16, 15, 14]); % wx, wy, wz
        
        % *** NANG CAP 1: Lam muot (Low-pass) W_raw_h de tinh dao ham on dinh hon ***
        W_raw_h_smooth = smoothdata(W_raw_h, 'sgolay', 15);
        
        t_h = raw_h(:, 1);
        
        % Tinh alpha tren luoi Head
        alpha_B = zeros(size(W_raw_h_smooth));
        alpha_B(:,1) = gradient(W_raw_h_smooth(:,1), t_h);
        alpha_B(:,2) = gradient(W_raw_h_smooth(:,2), t_h);
        alpha_B(:,3) = gradient(W_raw_h_smooth(:,3), t_h);
        
        % Pivot
        Axi_raw_p = raw_p(:, [8, 9, 10]);
        W_raw_p = raw_p(:, [16, 15, 14]);
        t_p = raw_p(:, 1);
        
        t_start = max(t_h(1), t_p(1));
        t_end   = min(t_h(end), t_p(end));
        
        mask_p = (t_p >= t_start & t_p <= t_end);
        t_sync = t_p(mask_p);
        pivot_sync_Axi = Axi_raw_p(mask_p, :);
        pivot_sync_W = W_raw_p(mask_p, :);
        
        head_sync_Axi = zeros(length(t_sync), 3);
        head_sync_W = zeros(length(t_sync), 3);
        alpha_sync = zeros(length(t_sync), 3);
        
        for c = 1:3
            head_sync_Axi(:, c) = interp1(t_h, Axi_raw_h(:, c), t_sync, 'linear', 'extrap');
            head_sync_W(:, c) = interp1(t_h, W_raw_h_smooth(:, c), t_sync, 'linear', 'extrap');
            alpha_sync(:, c) = interp1(t_h, alpha_B(:, c), t_sync, 'linear', 'extrap');
        end
        
        % MATH ENGINE (ROLL)
        N = length(t_sync);
        M_stack = zeros(2*N, 2);
        B_stack = zeros(2*N, 1);
        
        for k = 1:N
            a_h = head_sync_Axi(k, :)';
            a_p = pivot_sync_Axi(k, :)';
            da = a_h - a_p;
            
            w = head_sync_W(k, :)';
            al = alpha_sync(k, :)';
            
            Om = [0 -w(3) w(2); w(3) 0 -w(1); -w(2) w(1) 0];
            Al = [0 -al(3) al(2); al(3) 0 -al(1); -al(2) al(1) 0];
            M_k = Al + Om^2;
            
            % Roll => trục y, z
            M_reduced = M_k([2, 3], [2, 3]);
            B_reduced = [da(2); da(3)];
            
            idx = (2*k - 1) : 2*k;
            M_stack(idx, :) = M_reduced;
            B_stack(idx)    = B_reduced;
        end
        
        if rank(M_stack) < 2
            continue;
        end
        
        r_sol_m = M_stack \ B_stack;
        r_sol_mm = r_sol_m * 1000;
        ry_list(i) = r_sol_mm(1);
        rz_list(i) = r_sol_mm(2);
        
        % EVALUATION
        r_m = [0; ry_list(i); rz_list(i)] / 1000;
        a_calc_y = zeros(N, 1);
        a_calc_z = zeros(N, 1);
        
        for k = 1:N
            a_p = pivot_sync_Axi(k, :)';
            w = head_sync_W(k, :)';
            al = alpha_sync(k, :)';
            
            Om = [0 -w(3) w(2); w(3) 0 -w(1); -w(2) w(1) 0];
            Al = [0 -al(3) al(2); al(3) 0 -al(1); -al(2) al(1) 0];
            M_k = Al + Om^2;
            
            a_c = a_p + M_k * r_m;
            a_calc_y(k) = a_c(2);
            a_calc_z(k) = a_c(3);
        end
        
        a_imu_y = head_sync_Axi(:, 2);
        rmse_list(i) = sqrt(mean((a_calc_y - a_imu_y).^2));
        [Ry, ~] = corrcoef(a_calc_y, a_imu_y); 
        pearson_list(i) = Ry(1,2);
    end
    
    % *** NANG CAP 3: Chieu hinh hoc de nan thang thanh ray (Track Projection) ***
    % Tinh toan toa do ly tuong cho Simscape (Track thang dung)
    
    % Y phai la hang so (thang dung). Ta lay gia tri trung binh cua ry.
    ry_ideal = mean(ry_list);
    
    % Z phai cach nhau tuyet doi theo cz. Tim offset trung binh.
    % Thay rz = -cz + offset => offset = rz + cz
    offset_z = mean(rz_list + cz_list);
    rz_ideal = -cz_list + offset_z;
    
    % IN KET QUA
    fprintf('=== RAW CALCULATION (Filtered) ===\n');
    fprintf('%-10s | %-10s | %-10s | %-10s | %-10s\n', 'centrez', 'ry (mm)', 'rz (mm)', 'pearson', 'rmse');
    fprintf('---------------------------------------------------------------\n');
    for i = 1:length(files)
        fprintf('%-10.1f | %-10.4f | %-10.4f | %-10.4f | %-10.4f\n', ...
            cz_list(i), ry_list(i), rz_list(i), pearson_list(i), rmse_list(i));
    end
    
    fprintf('\n=== IDEALIZED FOR SIMSCAPE (Calibrated) ===\n');
    fprintf('The track is mathematically straightened to perfectly match the Z axis.\n');
    fprintf('%-10s | %-10s | %-10s\n', 'centrez', 'ry (mm)', 'rz (mm)');
    fprintf('--------------------------------------\n');
    for i = 1:length(files)
        fprintf('%-10.1f | %-10.4f | %-10.4f\n', ...
            cz_list(i), ry_ideal, rz_ideal(i));
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
