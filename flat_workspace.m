clc; clear; close all;
tic;

% --- CẤU HÌNH THÔNG SỐ QUÉT ---
% Dải tọa độ quét (Nên để bước nhảy step = 10mm cho chạy nhanh trước)
x_range = -235:5:255;
y_range = -210:5:285;
z_range = 700:5:1000; % Độ cao làm việc dự kiến

% KHAI BÁO GÓC CỐ ĐỊNH = 0 (Chỉ xét tịnh tiến XYZ)
roll = 0; 
pitch = 0; 
yaw = 0;

valid_XYZ = []; % Mảng lưu các tọa độ "sống sót"
disp('Đang quét Không gian hoạt động Tịnh tiến (XYZ)...');

for x = x_range
    for y = y_range
        for z = z_range
            is_safe = true; % Giả sử ban đầu điểm này là an toàn
            
            try
                % 1. Tính động học ngược 
                phi_out = donghocnguoc_final1(pose, A_mat, B_mat, L1, L2, gamma_ang);
              
                % Loại bỏ offset +-90 để lấy góc quay thực của Servo
                phi_thuc =phi_out;
                
                % 2. Ràng buộc cơ khí: Góc servo nằm trong khoảng [-60, 100]
                if any(phi_thuc > 100) || any(phi_thuc < -60) || any(isnan(phi_thuc))
                    is_safe = false; 
                end
                
                % 3. Ràng buộc kì dị: Chỉ kiểm tra nếu cơ khí đã an toàn (Tối ưu tốc độ)
                if is_safe
                    [is_singular, ~] = kiem_tra_ki_di(x, y, z, roll, pitch, yaw);
                    if is_singular
                        is_safe = false; 
                    end
                end
                
            catch
                is_safe = false; 
            end
            
            % Nếu vượt qua được mọi bài test, lưu tọa độ này lại
            if is_safe
                valid_XYZ = [valid_XYZ; x, y, z];
            end
        end
    end
end

disp('Hoàn thành quét! Đang xử lý đồ thị...');

% --- VẼ ĐỒ THỊ WORKSPACE (BỌC LỚP VỎ 3D) ---
if isempty(valid_XYZ)
    disp('Không tìm thấy điểm nào an toàn. Hãy kiểm tra lại cấu hình!');
else
    figure('Color', 'w'); % Chuyển nền thành màu trắng
    
    % Dùng boundary để bọc màng mây điểm thành một khối đặc
    k = boundary(valid_XYZ(:,1), valid_XYZ(:,2), valid_XYZ(:,3), 0.5); 
    trisurf(k, valid_XYZ(:,1), valid_XYZ(:,2), valid_XYZ(:,3), ...
        'FaceColor', [0 0.4470 0.7410], 'FaceAlpha', 0.6, 'EdgeColor', 'none');
    
    % Căn chỉnh ánh sáng cho khối 3D bóng bẩy
    camlight; 
    lighting gouraud;
    
    title('Vùng Hoạt Động Tịnh Tiến An Toàn (Roll = Pitch = Yaw = 0°)', 'Color', 'k', 'FontSize', 12);
    xlabel('Trục X (mm)', 'Color', 'k'); 
    ylabel('Trục Y (mm)', 'Color', 'k'); 
    zlabel('Trục Z (mm)', 'Color', 'k');
    set(gca, 'Color', 'w', 'XColor', 'k', 'YColor', 'k', 'ZColor', 'k'); 
    grid on;
    axis equal; % Rất quan trọng: Giữ cho khối 3D không bị bóp méo tỉ lệ
    
    % Xuất các giới hạn Max/Min để đưa vào báo cáo
    fprintf('\n--- KẾT QUẢ GIỚI HẠN KHÔNG GIAN TỊNH TIẾN --- \n');
    fprintf('X max/min: %.1f / %.1f (mm)\n', max(valid_XYZ(:,1)), min(valid_XYZ(:,1)));
    fprintf('Y max/min: %.1f / %.1f (mm)\n', max(valid_XYZ(:,2)), min(valid_XYZ(:,2)));
    fprintf('Z max/min: %.1f / %.1f (mm)\n', max(valid_XYZ(:,3)), min(valid_XYZ(:,3)));
end
toc;