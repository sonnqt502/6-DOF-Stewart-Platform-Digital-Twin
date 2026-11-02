function [A_mat, B_mat, gamma_ang] = calc_Geometry(ra, rb, alpha1, beta1, d_a, d_b) % Đừng sửa file này
    % Hàm tính toán cấu hình hình học tĩnh của Stewart Platform
    % Input: Kích thước cơ khí (bán kính ra, rb; góc lệch alpha1, beta1, d_a, d_b)
    % Output: 
    %   A_mat: Ma trận tọa độ 6 điểm neo ở Đế (3x6)
    %   B_mat: Ma trận tọa độ 6 điểm neo ở Bàn máy (3x6)
    %   gamma_ang: Vector góc định tuyến của 6 Motor (1x6)
    
    % 1. Khởi tạo mảng trống để tối ưu bộ nhớ
    A_mat = zeros(3, 6);
    B_mat = zeros(3, 6);
    gamma_ang = zeros(1, 6);
    alpha = zeros(1, 6);
    beta = zeros(1, 6);

    % 2. Tính phân bố góc alpha (Đế) và beta (Bàn máy)
    for k = 0:2
        % Cặp khớp ở Đế (A)
        alpha(2*k + 1) = -(alpha1 + k * 120); 
        alpha(2*k + 2) = -(alpha1 - d_a + (k+1) * 120);
        
        % Cặp khớp ở Bàn máy (B) - Chú ý (k+1)*120 để đảm bảo đúng thiết kế
        beta(2*k + 1) = -(beta1 + k * 120); 
        beta(2*k + 2) = -(beta1 + d_b + k * 120); 
    end

    % 3. Tính tọa độ 3D và góc Gamma
    for i = 1:6
       
        A_mat(1, i) = ra * cosd(alpha(i));
        A_mat(2, i) = ra * sind(alpha(i));
        A_mat(3, i) = 795.4-202+75; 
        
        % Tọa độ B_mat (Z_B ban đầu = 0)
        B_mat(1, i) = rb * cosd(beta(i));
        B_mat(2, i) = rb * sind(beta(i));
        B_mat(3, i) = 0;
        
        % Góc trục quay Motor
        gamma_ang(i) = (alpha(i) + ((-1)^i) * 90);
    end
end