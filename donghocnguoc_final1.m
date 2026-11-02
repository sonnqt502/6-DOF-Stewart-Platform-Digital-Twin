function phi_out = donghocnguoc_final1(pose, A_mat, B_mat, L1, L2, gamma_ang)
% HÀM ĐỘNG HỌC NGƯỢC (ĐỒNG BỘ CHÍNH XÁC VỚI DASHBOARD_STEWART5)
% Inputs:
%   pose      : Vector 1x6 chứa [x, y, z, roll, pitch, yaw] (mm và độ)
%   A_mat     : Ma trận 3x6 tọa độ các khớp dưới Đế (mm)
%   B_mat     : Ma trận 3x6 tọa độ các khớp trên Bàn máy (mm)
%   L1, L2    : Chiều dài tay quay (Servo Arm) và thanh truyền (Rod) (mm)
%   gamma_ang : Vector 1x6 chứa góc gá của 6 Motor (độ)
% Output:
%   phi_out   : Vector 1x6 chứa góc xuất ra servo phi_thuc (đã tính offset). 
%               Nếu điểm không khả thi, trả về NaN.

    % --- 1. TÍNH MA TRẬN QUAY (ROTATION MATRIX ZYX) ---
    roll = pose(4); pitch = pose(5); yaw = pose(6);
    cr = cosd(roll); sr = sind(roll);
    cp = cosd(pitch); sp = sind(pitch);
    cy = cosd(yaw); sy = sind(yaw);
    
    R = [cy*cp, cy*sp*sr - sy*cr, cy*sp*cr + sy*sr;
         sy*cp, sy*sp*sr + cy*cr, sy*sp*cr - cy*sr;
         -sp,   cp*sr,            cp*cr];
         
    T = [pose(1); pose(2); pose(3)]; % Vector tịnh tiến

    % --- 2. TÍNH VECTOR CHÂN ẢO (VIRTUAL LEGS) ---
    L_vec = T + R * B_mat - A_mat; 
    l_sq = sum(L_vec.^2, 1); 

    % --- 3. GIẢI PHƯƠNG TRÌNH ĐỘNG HỌC ---
    Q = l_sq - L2^2 + L1^2;
    M = 2 * L1 * L_vec(3, :);
    N = 2 * L1 * (cosd(gamma_ang) .* L_vec(1, :) + sind(gamma_ang) .* L_vec(2, :));
    
    mau_so = sqrt(M.^2 + N.^2);
    arg = Q ./ mau_so;
    
    % Kiểm tra điều kiện giới hạn hình học (vượt quá |arg| > 1)
    invalid_idx = abs(arg) > 1; 
    
    % Giới hạn arg trong [-1, 1] để tránh lỗi lượng giác
    arg = max(min(arg, 1), -1);
    
    % --- 4. TÍNH GÓC RAW THAM CHIẾU (phi_raw) ---
    phi_raw = asind(arg) - atan2d(N, M);
    
    % --- 5. BÙ OFFSET VÀ ĐỔI DẤU THEO DASHBOARD_STEWART5 ---
    % Bước 1: phi_out tuyệt đối (khớp lẻ -90-phi, khớp chẵn 90+phi)
    phi_out_step = zeros(1, 6);
    phi_out_step(1:2:5) = -(90 + phi_raw(1:2:5));
    phi_out_step(2:2:6) = (90 + phi_raw(2:2:6));
    
    % Bước 2: Bù offset [90, -90, 90, -90, 90, -90]
    phi_thuc = (phi_out_step - [90, -90, 90, -90, 90, -90]);
    
    % Bước 3: Đảo dấu động cơ lẻ theo quy ước driver
    phi_thuc(1:2:5) = -phi_thuc(1:2:5);
    
    phi_out = phi_thuc;
    
    % Trả về NaN nếu có chân không khả thi
    if any(invalid_idx)
        phi_out(:) = NaN;
    end
end