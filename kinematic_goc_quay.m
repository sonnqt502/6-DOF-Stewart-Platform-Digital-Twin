function [phi_motor, is_valid, messages] = kinematic_goc_quay(x, y, z, roll, pitch, yaw, config_path, cx, cy, cz)
    % KINEMATIC_GOC_QUAY Tính toán góc quay động cơ và kiểm tra giới hạn.
    % Đầu vào: x, y, z (mm), roll, pitch, yaw (độ), config_path, cx, cy, cz (tâm quay)
    % Đầu ra:
    %   phi_motor: Ma trận 6xN chứa góc động cơ (độ).
    %   is_valid: Mảng 1xN boolean cho biết trạng thái hợp lệ.
    %   messages: Cell array 1xN chứa thông báo lỗi hoặc 'OK'.

    if nargin < 7 || isempty(config_path)
        config_path = 'config.json';
    end
    if nargin < 10
        cx = 0; cy = 0; cz = 0;
    end

    % 1. Đọc file config hoặc sử dụng struct truyền vào
    if isstruct(config_path)
        cfg = config_path;
    else
        fid = fopen(config_path, 'r');
        if fid == -1
            error('Không thể mở file %s', config_path);
        end
        raw = fread(fid, '*char')';
        fclose(fid);
        cfg = jsondecode(raw);
    end
    
    % 2. Tính toán các ma trận hình học cố định
    [A_mat, B_mat, gamma_ang] = computeGeometry(cfg);
    
    N = length(x);
    phi_motor = zeros(6, N);
    is_valid = true(1, N);
    messages = cell(1, N);
    
    L1 = cfg.l1;
    L2 = cfg.l2;
    mot_min = cfg.motor_limit_min;
    mot_max = cfg.motor_limit_max;
    
    % Xử lý mảng tâm quay nếu N > 1 (phòng trường hợp truyền vào mảng)
    if length(cx) == 1, cx = repmat(cx, 1, N); end
    if length(cy) == 1, cy = repmat(cy, 1, N); end
    if length(cz) == 1, cz = repmat(cz, 1, N); end
    
    for k = 1:N
        % Ma trận quay ZYX (Yaw -> Pitch -> Roll)
        R = calcRotationMatrix(yaw(k), pitch(k), roll(k));
        T = [x(k); y(k); z(k)];
        P_pivot = [cx(k); cy(k); cz(k)];
        
        % Tính vector chân ảo theo nguyên tắc Động học Pivot Point chặt chẽ:
        % B_final = P_pivot + R*(B_mat + T - P_pivot)
        L_vec = P_pivot + R * (B_mat + repmat(T, 1, 6) - repmat(P_pivot, 1, 6)) - A_mat;
        l_sq = sum(L_vec.^2, 1);
        
        Q = l_sq - L2^2 + L1^2;
        M_val = (2 * L1 * L_vec(3, :));
        N_val = 2 * L1 * (cosd(gamma_ang) .* L_vec(1, :) + sind(gamma_ang) .* L_vec(2, :));
        arg = Q ./ sqrt(M_val.^2 + N_val.^2);
        
        if any(abs(arg) > 1)
            is_valid(k) = false;
            bad_idx = find(abs(arg) > 1, 1);
            messages{k} = sprintf('Chân %d kịch cơ khí', bad_idx);
            continue;
        end
        
        phi_raw = asind(arg) - atan2d(N_val, M_val);
        phi_out = zeros(1, 6);
        phi_out(1:2:5) = -(90 + phi_raw(1:2:5));
        phi_out(2:2:6) = (90 + phi_raw(2:2:6));
        phi_thuc = (phi_out - [90, -90, 90, -90, 90, -90]);
        phi_thuc(1:2:5) = -phi_thuc(1:2:5); % Đảo dấu động cơ lẻ
        phi_motor(:, k) = phi_thuc';
        
        if any(phi_thuc < mot_min) || any(phi_thuc > mot_max)
            bad_idx = find((phi_thuc < mot_min) | (phi_thuc > mot_max), 1);
            is_valid(k) = false;
            messages{k} = sprintf('Góc động cơ chân %d (%.1f°) vượt giới hạn [%d, %d]', bad_idx, phi_thuc(bad_idx), mot_min, mot_max);
        else
            % Kiểm tra kỳ dị
            r_vec = R * (B_mat + repmat(T, 1, 6) - repmat(P_pivot, 1, 6));
            L_norm = sqrt(l_sq);
            s_vec = L_vec ./ L_norm; 
            cross_prod = cross(r_vec, s_vec); 
            J_inv = [s_vec', cross_prod'];
            if abs(det(J_inv)) < 1e-3
                is_valid(k) = false;
                messages{k} = 'Kỳ dị toán học';
            else
                messages{k} = 'Hợp lệ';
            end
        end
    end
end

function [A_mat, B_mat, gamma_ang] = computeGeometry(cfg)
    alpha = zeros(1,6); beta = zeros(1,6);
    for k = 0:2
        alpha(2*k + 1) = -(cfg.a1 + k * 120); 
        alpha(2*k + 2) = -(cfg.a1 - cfg.da + (k+1) * 120);
        beta(2*k + 1)  = -(cfg.b1 + k * 120); 
        beta(2*k + 2)  = -(cfg.b1 + cfg.db + k * 120); 
    end
    
    if isfield(cfg, 'Z_MOTOR_OFFSET')
        Z_A =cfg.Z_MOTOR_OFFSET;
    else
        Z_A =668.4; % Mặc định chênh lệch bằng 0 nếu không được cấu hình
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

function R = calcRotationMatrix(yaw_deg, pitch_deg, roll_deg)
    cy = cosd(yaw_deg);   sy = sind(yaw_deg);
    cp = cosd(pitch_deg); sp = sind(pitch_deg);
    cr = cosd(roll_deg);  sr = sind(roll_deg);
    R = [cy*cp,  cy*sp*sr - sy*cr,  cy*sp*cr + sy*sr;
         sy*cp,  sy*sp*sr + cy*cr,  sy*sp*cr - cy*sr;
         -sp,    cp*sr,             cp*cr            ];
end
