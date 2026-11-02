function [pose_out, iter, err] = donghocthuan_NR(phi_target, pose_guess, A_mat, B_mat, L1, L2, gamma_ang)
    % Giải bài toán Động học thuận (Forward Kinematics) bằng Newton-Raphson
    % Dành cho cơ cấu RUS Stewart Platform
    %
    % Inputs:
    %   phi_target  : Góc mục tiêu của 6 servo (mảng 1x6, đơn vị độ).
    %   pose_guess  : Vector đoán nhận ban đầu [x, y, z, roll, pitch, yaw] (mm, độ)
    %   A_mat, B_mat: Tọa độ điểm neo ở Đế và Bàn máy (3x6)
    %   L1, L2      : Chiều dài tay quay (Servo Arm) và thanh truyền (Rod)
    %   gamma_ang   : Vector góc định tuyến của 6 Motor

    % Outputs:
    %   pose_out: Vector tư thế tìm được [x, y, z, roll, pitch, yaw]
    %   iter: Số lần lặp thực tế
    %   err: Sai số lớn nhất của góc servo (độ)
    
  

    phi_target = phi_target(:)';
    
    % Nếu đầu vào là phi_out, ta phải dịch ngược lại về phi_raw
    % Theo donghocnguoc_raw:
    % phi_out(1:2:5) = 180 - phi_raw(1:2:5)  => phi_raw = 180 - phi_out
    % phi_out(2:2:6) = -180 + phi_raw(2:2:6) => phi_raw = phi_out + 180
    
        phi_raw_target = zeros(1,6);
        phi_raw_target(1:2:5) =phi_target(1:2:5);
        phi_raw_target(2:2:6) = phi_target(2:2:6);
   
    
    max_iter = 100;
    tol = 1e-6; % Dung sai góc (độ)
    
    pose = pose_guess(:)';
    
    for iter = 1:max_iter
        % Tính IK để lấy góc hiện tại
        [phi_current] = donghocnguoc_final1(pose, A_mat, B_mat, L1, L2, gamma_ang);
        
        if any(isnan(phi_current))
            % Nếu pose rơi vào điểm kì dị (không có nghiệm IK thực)
            pose_out = nan(1,6);
            err = inf;
            warning('donghocthuan_NR: Rơi vào vùng kì dị/không với tới (NaN).');
            return;
        end
        
        % Sai số góc (độ) - dùng phi_raw
        delta_phi_deg = phi_raw_target - phi_current;
        
        % Tính sai số lớn nhất để kiểm tra điều kiện dừng
        err = max(abs(delta_phi_deg));
        if err < tol
            pose_out = pose;
            return;
        end
        
        % Lấy Jacobian (sử dụng hàm có sẵn jacobian_RUS)
        pose_dot_dummy = zeros(1,6);
        [J, ~] = jacobian_RUS(pose, pose_dot_dummy, A_mat, B_mat, L1, L2, gamma_ang);
        
        % J map từ [v_x, v_y, v_z, w_x, w_y, w_z]^T sang delta_phi_rad
        delta_phi_rad = delta_phi_deg * (pi / 180); % Đổi sang rad
        
        % Tính vector vận tốc bù trừ
        % Dùng pseudo-inverse để an toàn hơn khi ma trận J có thể gần suy biến
        delta_vel = pinv(J) * delta_phi_rad'; 
        
        % Cập nhật xyz
        pose(1:3) = pose(1:3) + delta_vel(1:3)';
        
        % Cập nhật góc roll, pitch, yaw (cần nghịch đảo ma trận E để suy ra tốc độ rpy)
        roll_r = pose(4) * (pi / 180);
        pitch_r = pose(5) * (pi / 180);
        
        E = [1,          0,              -sin(pitch_r);
             0,   cos(roll_r),   sin(roll_r)*cos(pitch_r);
             0,  -sin(roll_r),   cos(roll_r)*cos(pitch_r)];
             
        % [delta_roll, delta_pitch, delta_yaw]^T trong rad
        delta_rpy_rad = E \ delta_vel(4:6); 
        
        % Cập nhật roll, pitch, yaw (quy đổi về độ)
        pose(4:6) = pose(4:6) + delta_rpy_rad' * (180 / pi);
    end
    
    pose_out = pose;
    warning('donghocthuan_NR: Đã đạt số lần lặp tối đa nhưng chưa hội tụ!');
end
