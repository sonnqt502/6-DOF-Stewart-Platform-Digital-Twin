function [motor_vel_rpm, J_v, phi_thuc] = tinh_vel(pose, vel, A, B, L1, L2, gamma_ang)
% TINH_VEL: Tính toán vận tốc của 6 động cơ (đơn vị: vòng/phút - RPM)
% Dựa trên Jacobian Hình học của hệ thống Rotary Stewart (6-RUS) CKAS.
%
% INPUTS:
%   pose  - [x, y, z, roll, pitch, yaw] (mm, độ) - Vị trí hiện tại
%   vel   - [vx, vy, vz, v_roll, v_pitch, v_yaw] (mm/s, độ/s) - Vận tốc mong muốn
%   A     - Tọa độ 6 khớp gốc (Matrix 3x6)
%   B     - Tọa độ 6 khớp bệ động (Matrix 3x6)
%   L1    - Chiều dài tay đòn
%   L2    - Chiều dài tay biên
%   gamma_ang - Góc bố trí các động cơ (1x6 độ)
%
% OUTPUTS:
%   motor_vel_rpm - Vận tốc 6 động cơ (vòng/phút - RPM)
%   J_v           - Ma trận Jacobian Vận tốc (6x6)
%   phi_thuc          - Góc hiện tại của động cơ (độ)

    % 1. Trích xuất tham số vị trí
    x = pose(1); y = pose(2); z = pose(3);
    yw = pose(4); p = pose(5); r = pose(6);
    
    % Trích xuất tham số vận tốc
    vx = vel(1); vy = vel(2); vz = vel(3);
    vr = vel(6); vp = vel(5); vyw = vel(4);
    
    % 2. Ma trận quay R (thứ tự Z-Y-X)
    cy = cosd(yw); sy = sind(yw);
    cp = cosd(p);  sp = sind(p);
    cr = cosd(r);  sr = sind(r);
    
    R = [cy*cp,  cy*sp*sr - sy*cr,  cy*sp*cr + sy*sr;
         sy*cp,  sy*sp*sr + cy*cr,  sy*sp*cr - cy*sr;
         -sp,    cp*sr,             cp*cr            ];
         
    % 3. Quy đổi Vận tốc góc Euler (độ/s) sang Không gian (rad/s)
    % Ma trận Jacobian Euler (Intrinsic Z-Y-X)
    E = [cy*cp, -sy, 0;
         sy*cp,  cy, 0;
        -sp,      0, 1];
    
    omega_rad_s = E * [deg2rad(vyw); deg2rad(vp); deg2rad(vr)];
    v_trans = [vx; vy; vz]; % Vận tốc tịnh tiến mm/s
    
    % Khởi tạo ma trận Jacobian
    J_geo = zeros(6, 6);
    J_phi_diag = zeros(1, 6);
    phi_raw = zeros(1, 6);
    phi_thuc = zeros(1, 6);
    
    T = [x; y; z];
    
    % 4. Tính toán động học cho từng chân
    for i = 1:6
        % Tọa độ khớp B trên mâm (đã bị xoay)
        B_prime = R * B(:, i);
        
        % Vector chân ảo L_vec (Từ tâm động cơ A đến khớp B)
        L_vec = T + B_prime - A(:, i);
        lx = L_vec(1); ly = L_vec(2); lz = L_vec(3);
        
        % Phương trình động học ngược để tìm góc phi
        l_sq = lx^2 + ly^2 + lz^2;
        Q = l_sq - L2^2 + L1^2;
        M = 2 * L1 * lz;
        N = 2 * L1 * (lx * cosd(gamma_ang(i)) + ly * sind(gamma_ang(i)));
        
        arg = Q / sqrt(M^2 + N^2);
        if abs(arg) > 1
            error('Chân %d kịch cơ khí tại tư thế hiện tại!', i);
        end
        
        % Tính góc hình học phi_raw (độ)
        phi_raw_i = asind(arg) - atan2d(N, M);
        phi_raw(i) = phi_raw_i;
        
        % Tọa độ điểm C (khớp gối tay đòn)
        C_local = L1 * [cosd(gamma_ang(i)) * cosd(phi_raw_i);
                        sind(gamma_ang(i)) * cosd(phi_raw_i);
                        sind(phi_raw_i)];
                        
        % Vector tay biên (từ C đến B)
        d_vec = L_vec - C_local; 
        
        % --- XÂY DỰNG JACOBIAN ---
        % Hàng thứ i của ma trận Không gian thao tác (J_geo)
        J_geo(i, 1:3) = d_vec';
        J_geo(i, 4:6) = cross(B_prime, d_vec)'; 
        
        % Phần tử thứ i của ma trận Không gian khớp (J_phi)
        % Hệ số 0.5 do rút gọn đạo hàm bình phương khoảng cách
        J_phi_diag(i) = 0.5 * (M * cosd(phi_raw_i) - N * sind(phi_raw_i));
    end
    
    % 5. Giải hệ phương trình Jacobian
    J_phi_mat = diag(J_phi_diag);
    vel_vector = [v_trans; omega_rad_s]; % Kích thước 6x1
    
    % Giải ra vận tốc góc hình học (rad/s)
    phi_raw_dot_rad_s = J_phi_mat \ (J_geo * vel_vector);
    
    % Chuyển sang Vòng/Phút (RPM)
    % 1 vòng = 2*pi radian. Suy ra: vòng/phút = (rad/s) * 60 / (2*pi)
    phi_raw_dot_rpm = (phi_raw_dot_rad_s / (2*pi)) * 60;
    
    % 6. Xét chiều quay của động cơ CKAS
    % Động cơ chẵn và lẻ được bù trừ dấu cơ khí đối xứng qua mã phi_thuc.
    % Sự bù trừ này triệt tiêu hoàn toàn khi chuyển sang vận tốc tương đối.
    % Tức là: d(phi_thuc) / dt  =  d(phi_raw) / dt
    motor_vel_rpm = phi_raw_dot_rpm;
    
    % --- Tính thêm góc thực tế để debug nếu cần ---
    phi_out = zeros(1,6);
    phi_out(1:2:5) = -(90 + phi_raw(1:2:5));
    phi_out(2:2:6) = (90 + phi_raw(2:2:6));
    phi_thuc = (phi_out - [90, -90, 90, -90, 90, -90]);
    phi_thuc(1:2:5) = -phi_thuc(1:2:5); 
    
    % Lưu lại ma trận tổng hợp J_v (rad/s)
    J_v = J_phi_mat \ J_geo;
end
