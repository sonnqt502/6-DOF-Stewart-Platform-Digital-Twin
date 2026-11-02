clc; clear; close all;
tic;

% --- CẤU HÌNH THÔNG SỐ QUÉT GÓC ---
z_fixed = 795.4; % Cố định độ cao làm việc (mm)
x_fixed = 0;   % Cố định tại tâm
y_fixed = 0;

% Dải góc quét (Đơn vị: Độ)
limit_rot = 40; % Quét từ -40 đến 40 độ
step_rot = 2;   % Bước nhảy 2 độ cho mịn
rot_range = -limit_rot:step_rot:limit_rot;

valid_Angles = []; % Mảng lưu các bộ góc [Roll, Pitch, Yaw] an toàn

disp('Đang quét Không gian quay an toàn tại tâm...');

for r = rot_range
    for p_ang = rot_range
        for y_ang = rot_range
            is_safe = true;
            
            try
                % 1. Tính động học ngược
                [p1, p2, p3, p4, p5, p6] = donghocnguoc_final1(x_fixed, y_fixed, z_fixed, r, p_ang, y_ang);
                
                % Lấy góc thực của Servo
                phi_thuc = [p1, p2, p3, p4, p5, p6] - [-90, 90, -90, 90, -90, 90];
                
                % 2. Kiểm tra giới hạn Servo [-60, 100]
                if any(phi_thuc > 100) || any(phi_thuc < -60) || any(isnan(phi_thuc))
                    is_safe = false;
                end
                
                % 3. Kiểm tra kì dị (Jacobian)
                if is_safe
                    [is_singular, ~] = kiem_tra_ki_di(x_fixed, y_fixed, z_fixed, r, p_ang, y_ang);
                    if is_singular, is_safe = false; end
                end
                
            catch
                is_safe = false;
            end
            
            if is_safe
                valid_Angles = [valid_Angles; r, p_ang, y_ang];
            end
        end
    end
end

disp('Hoàn thành quét góc!');
toc;

% --- VẼ ĐỒ THỊ 3D GÓC ---
if isempty(valid_Angles)
    disp('Không tìm thấy vùng góc nào an toàn. Hãy thử thay đổi Z_fixed!');
else
    figure('Color', 'w');
    % Vẽ khối bao bằng boundary
    k = boundary(valid_Angles(:,1), valid_Angles(:,2), valid_Angles(:,3), 0.5);
    trisurf(k, valid_Angles(:,1), valid_Angles(:,2), valid_Angles(:,3), ...
        'FaceColor', [0.8500 0.3250 0.0980], 'FaceAlpha', 0.6, 'EdgeColor', 'none');
    
    camlight; lighting gouraud;
    title(['Orientation Workspace tại Z = ', num2str(z_fixed), ' mm'], 'Color', 'k');
    xlabel('Roll (deg)'); ylabel('Pitch (deg)'); zlabel('Yaw (deg)');
    grid on; axis equal;
    
    % In giới hạn góc tối đa đạt được
    fprintf('\n--- GIỚI HẠN GÓC QUAY TỐI ĐA TẠI TÂM --- \n');
    fprintf('Roll max/min:  %.1f / %.1f (deg)\n', max(valid_Angles(:,1)), min(valid_Angles(:,1)));
    fprintf('Pitch max/min: %.1f / %.1f (deg)\n', max(valid_Angles(:,2)), min(valid_Angles(:,2)));
    fprintf('Yaw max/min:   %.1f / %.1f (deg)\n', max(valid_Angles(:,3)), min(valid_Angles(:,3)));
end