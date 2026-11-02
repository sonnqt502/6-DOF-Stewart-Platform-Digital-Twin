function [is_safe, error_msg, phi_out] = check_pose_safety(pose, A_mat, B_mat, L1, L2, gamma_ang)
    % HÀM GÁC CỔNG: KIỂM TRA TÍNH KHẢ THI & AN TOÀN TỔNG THỂ CỦA 1 ĐIỂM (POSE)
    % Input: 
    %   pose      : Vector [x, y, z, roll, pitch, yaw]
    %   A_mat, B_mat, L1, L2, gamma_ang : Thông số tĩnh đã tính từ calc_Geometry
    % Output:
    %   is_safe   : Boolean (true nếu an toàn tuyệt đối, false nếu hỏng 1 tiêu chí)
    %   error_msg : Chuỗi ký tự báo lỗi (Dùng để hiển thị lên App)
    %   phi_out   : Vector 1x6 chứa góc servo (Nếu an toàn thì lưu lại dùng luôn, đỡ tính lại)

    % --- LỚP LỌC 1: TẦM VỚI CƠ KHÍ (ĐỘNG HỌC NGƯỢC) ---
    phi_out = donghocnguoc_final1(pose, A_mat, B_mat, L1, L2, gamma_ang);
    
    if any(isnan(phi_out))
        is_safe = false;
        error_msg = 'LỖI: Điểm ngoài tầm với (Chiều dài tay đòn không đủ).';
        return; % THOÁT NGAY LẬP TỨC
    end

    % --- LỚP LỌC 2: GIỚI HẠN GÓC QUAY SERVO ---
    % Giả sử servo của cậu chỉ quay được từ -60 độ đến +100 độ
    if any(phi_out < -60) || any(phi_out > 100)
        is_safe = false;
        % Tìm ra cụ thể chân nào bị lỗi để báo cáo (rất tốt cho UX/UI)
        bad_legs = find((phi_out < -50) | (phi_out > 90));
        error_msg = sprintf('LỖI: Servo %s vượt quá giới hạn [-60, 100] độ.', num2str(bad_legs));
        return; % THOÁT NGAY LẬP TỨC
    end

    % --- LỚP LỌC 3: ĐIỂM KỲ DỊ (TĨNH HỌC/JACOBIAN) ---
    % Chỉ chạy hàm này khi cơ cấu chắc chắn đã vươn tới được
    [is_singular, detJ] = kiem_tra_ki_di_optimized(pose, A_mat, B_mat);
    
    if is_singular
        is_safe = false;
        error_msg = sprintf('LỖI: Rơi vào điểm kỳ dị (det(J) = %.5f). Nguy cơ gãy cơ cấu!', detJ);
        return;
    end

    % --- PASS TOÀN BỘ CÁC BÀI TEST ---
    is_safe = true;
    error_msg = 'HỆ THỐNG AN TOÀN.';
end