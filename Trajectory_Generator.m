function Trajectory_Generator()
    % =====================================================================
    % 1. KHỞI TẠO CỬA SỔ GIAO DIỆN
    % =====================================================================
    fig = uifigure('Name', 'TRAJECTORY GENERATOR - TRÌNH SINH QUỸ ĐẠO', 'Position', [100 100 900 650], 'Color', 'w');
    
    uilabel(fig, 'Text', 'CÔNG CỤ TẠO QUỸ ĐẠO STEWART PLATFORM', ...
        'Position', [250 600 400 30], 'FontSize', 18, 'FontWeight', 'bold', 'FontColor', [0 0.4470 0.7410], 'HorizontalAlignment', 'center');

    % =====================================================================
    % PANEL 1: CẤU HÌNH TÂM QUAY (PIVOT)
    % =====================================================================
    pnl_pivot = uipanel(fig, 'Title', '1. Thiết lập Tâm Quay (Pivot)', 'Position', [20 440 320 150], 'BackgroundColor', 'w', 'FontWeight', 'bold');
    
    uilabel(pnl_pivot, 'Text', 'Chiều Cao Đầu (H):', 'Position', [10 95 110 22]);
    ed_hhead = uieditfield(pnl_pivot, 'numeric', 'Position', [120 95 60 22], 'Value', 793, 'ValueChangedFcn', @(btn,event) updatePreview());
    
    uilabel(pnl_pivot, 'Text', 'Home Z (Bàn):', 'Position', [190 95 80 22]);
    ed_homez = uieditfield(pnl_pivot, 'numeric', 'Position', [250 95 60 22], 'Value', 795.4, 'ValueChangedFcn', @(btn,event) updatePreview());
    
    uilabel(pnl_pivot, 'Text', 'Tâm Sinh Quỹ Đạo:', 'Position', [10 60 110 22], 'FontWeight', 'bold');
    dd_pivot = uidropdown(pnl_pivot, 'Items', {'Tâm Bàn Máy (Top Platform)', 'Đỉnh Đầu Người Lái', 'Tọa Độ Bất Kỳ (Custom)'}, ...
        'Position', [120 60 190 22], 'ValueChangedFcn', @(btn,event) toggleCustomPivot());
    
    uilabel(pnl_pivot, 'Text', 'Tọa độ bù (X,Y,Z):', 'Position', [10 25 110 22]);
    ed_px = uieditfield(pnl_pivot, 'numeric', 'Position', [120 25 50 22], 'Value', 0, 'Enable', 'off', 'ValueChangedFcn', @(btn,event) updatePreview());
    ed_py = uieditfield(pnl_pivot, 'numeric', 'Position', [180 25 50 22], 'Value', 0, 'Enable', 'off', 'ValueChangedFcn', @(btn,event) updatePreview());
    ed_pz = uieditfield(pnl_pivot, 'numeric', 'Position', [240 25 50 22], 'Value', 500, 'Enable', 'off', 'ValueChangedFcn', @(btn,event) updatePreview());

    % =====================================================================
    % PANEL 2: LOẠI QUỸ ĐẠO & THÔNG SỐ
    % =====================================================================
    pnl_traj = uipanel(fig, 'Title', '2. Tùy chọn Quỹ Đạo', 'Position', [20 120 320 310], 'BackgroundColor', 'w', 'FontWeight', 'bold');
    
    uilabel(pnl_traj, 'Text', 'Loại Chuyển Động:', 'Position', [10 255 120 22], 'FontWeight', 'bold');
    dd_type = uidropdown(pnl_traj, 'Items', {...
        '--- Chuyển động 1D ---', ...
        '[1D] Tịnh tiến X (Surge)', ...
        '[1D] Tịnh tiến Y (Sway)', ...
        '[1D] Tịnh tiến Z (Heave)', ...
        '[1D] Quay Roll (Nghiêng ngang)', ...
        '[1D] Quay Pitch (Gật gù)', ...
        '[1D] Quay Yaw (Xoay hướng)', ...
        '--- Chuyển động 2D ---', ...
        '[2D] Đường tròn XY (Chỉ tịnh tiến)', ...
        '[2D] Lắc lư vòng tròn (Roll + Pitch)', ...
        '[2D] Vượt dốc (Z + Pitch)', ...
        '--- Chuyển động 3D ---', ...
        '[3D] Xoắn ốc (X, Y, Z)', ...
        '[3D] Cua chữ S (6 DOF)'}, 'Position', [10 230 300 22], 'ValueChangedFcn', @(btn,event) updatePreview());

    uilabel(pnl_traj, 'Text', 'T.Gian Mô Phỏng (s):', 'Position', [10 190 120 22]);
    ed_time = uieditfield(pnl_traj, 'numeric', 'Position', [130 190 60 22], 'Value', 10, 'ValueChangedFcn', @(btn,event) updatePreview());
    
    uilabel(pnl_traj, 'Text', 'Tần số (Hz):', 'Position', [10 150 120 22]);
    ed_freq = uieditfield(pnl_traj, 'numeric', 'Position', [130 150 60 22], 'Value', 0.2, 'ValueChangedFcn', @(btn,event) updatePreview());
    
    uilabel(pnl_traj, 'Text', 'Biên độ X,Y,Z (mm):', 'Position', [10 110 120 22]);
    ed_amp_lin = uieditfield(pnl_traj, 'numeric', 'Position', [130 110 60 22], 'Value', 50, 'ValueChangedFcn', @(btn,event) updatePreview());
    
    uilabel(pnl_traj, 'Text', 'Biên độ Góc (°):', 'Position', [10 70 120 22]);
    ed_amp_ang = uieditfield(pnl_traj, 'numeric', 'Position', [130 70 60 22], 'Value', 10, 'ValueChangedFcn', @(btn,event) updatePreview());
    
    uibutton(pnl_traj, 'Text', 'XEM TRƯỚC (PREVIEW)', 'Position', [60 15 200 35], ...
        'BackgroundColor', [0.4660 0.6740 0.1880], 'FontColor', 'w', 'FontWeight', 'bold', 'ButtonPushedFcn', @(btn,event) updatePreview());

    % =====================================================================
    % PANEL 3: NÚT XUẤT FILE
    % =====================================================================
    uibutton(fig, 'Text', '💾 XUẤT FILE CSV CHO DASHBOARD', 'Position', [20 40 320 50], ...
        'BackgroundColor', [0.8500 0.3250 0.0980], 'FontColor', 'w', 'FontSize', 14, 'FontWeight', 'bold', ...
        'ButtonPushedFcn', @(btn,event) exportCSV());

    % =====================================================================
    % PANEL 4: PREVIEW ĐỒ THỊ
    % =====================================================================
    ax = uiaxes(fig, 'Position', [360 40 520 550]);
    title(ax, 'Xem trước quỹ đạo sinh ra trong Không gian');
    grid(ax, 'on'); hold(ax, 'on'); view(ax, 3);
    xlabel(ax, 'X (mm)'); ylabel(ax, 'Y (mm)'); zlabel(ax, 'Z (mm)');

    % =====================================================================
    % CÁC HÀM XỬ LÝ (CALLBACKS)
    % =====================================================================
    
    function toggleCustomPivot()
        if strcmp(dd_pivot.Value, 'Tọa Độ Bất Kỳ (Custom)')
            ed_px.Enable = 'on'; ed_py.Enable = 'on'; ed_pz.Enable = 'on';
        else
            ed_px.Enable = 'off'; ed_py.Enable = 'off'; ed_pz.Enable = 'off';
        end
        updatePreview();
    end

    % --- THÊM TỌA ĐỘ TÂM QUAY VÀO KẾT QUẢ TRẢ VỀ ---
    function [t, x_p, y_p, z_p, r_arr, p_arr, yw_arr, x_h, y_h, z_h, x_piv, y_piv, z_piv] = generateData()
        T_sim = ed_time.Value;
        fs = 50; t = (0:1/fs:T_sim)'; N = length(t);
        
        H_head = ed_hhead.Value; Home_Z = ed_homez.Value;
        v_head = [0; 0; H_head]; 
        
        mode_pivot = dd_pivot.Value;
        if strcmp(mode_pivot, 'Tâm Bàn Máy (Top Platform)')
            v_pivot = [0; 0; 0];
        elseif strcmp(mode_pivot, 'Đỉnh Đầu Người Lái')
            v_pivot = [0; 0; H_head];
        else
            v_pivot = [ed_px.Value; ed_py.Value; ed_pz.Value];
        end
        
        Pivot_0 = [0; 0; Home_Z] + v_pivot; 
        
        dx = zeros(N, 1); dy = zeros(N, 1); dz = zeros(N, 1);
        r_arr = zeros(N, 1); p_arr = zeros(N, 1); yw_arr = zeros(N, 1);
        
        freq = ed_freq.Value; A_lin = ed_amp_lin.Value; A_ang = ed_amp_ang.Value;
        fade = min(t, 1); 
        mode_traj = dd_type.Value;
        
        switch mode_traj
            case '[1D] Tịnh tiến X (Surge)'
                dx = (A_lin * sin(2*pi*freq*t)) .* fade;
            case '[1D] Tịnh tiến Y (Sway)'
                dy = (A_lin * sin(2*pi*freq*t)) .* fade;
            case '[1D] Tịnh tiến Z (Heave)'
                dz = (A_lin * sin(2*pi*freq*t)) .* fade;
            case '[1D] Quay Roll (Nghiêng ngang)'
                r_arr = (A_ang * sin(2*pi*freq*t)) .* fade;
            case '[1D] Quay Pitch (Gật gù)'
                p_arr = (A_ang * sin(2*pi*freq*t)) .* fade;
            case '[1D] Quay Yaw (Xoay hướng)'
                yw_arr = (A_ang * sin(2*pi*freq*t)) .* fade;
            case '[2D] Đường tròn XY (Chỉ tịnh tiến)'
                dx = (A_lin * cos(2*pi*freq*t) - A_lin) .* fade; 
                dy = (A_lin * sin(2*pi*freq*t)) .* fade;
            case '[2D] Lắc lư vòng tròn (Roll + Pitch)'
                p_arr = (A_ang * (cos(2*pi*freq*t) - 1)) .* fade; 
                r_arr = (A_ang * sin(2*pi*freq*t)) .* fade;
            case '[2D] Vượt dốc (Z + Pitch)'
                dz = (A_lin/2 * sin(2*pi*freq*t)) .* fade; 
                p_arr = (A_ang * sin(2*pi*freq*t)) .* fade;
            case '[3D] Xoắn ốc (X, Y, Z)'
                dx = (A_lin * cos(2*pi*freq*t) - A_lin) .* fade; 
                dy = (A_lin * sin(2*pi*freq*t)) .* fade;
                dz = (A_lin/2 * sin(2*pi*freq*t)) .* fade;
            case '[3D] Cua chữ S (6 DOF)'
                dy = (A_lin * sin(2*pi*freq*t)) .* fade;
                dx = (A_lin/2 * sin(4*pi*freq*t)) .* fade;
                r_arr = (A_ang * sin(4*pi*freq*t)) .* fade;
                p_arr = (A_ang/2 * (cos(2*pi*freq*t) - 1)) .* fade;
                yw_arr = (A_ang/3 * sin(2*pi*freq*t)) .* fade;
        end
        
        x_p = zeros(N,1); y_p = zeros(N,1); z_p = zeros(N,1);
        x_h = zeros(N,1); y_h = zeros(N,1); z_h = zeros(N,1);
        x_piv = zeros(N,1); y_piv = zeros(N,1); z_piv = zeros(N,1);
        
        for k = 1:N
            cy = cosd(yw_arr(k));
            sy = sind(yw_arr(k)); 
            cp = cosd(p_arr(k));
            sp = sind(p_arr(k)); 
            cr = cosd(r_arr(k));
            sr = sind(r_arr(k));
            R_k = [cy*cp, cy*sp*sr - sy*cr, cy*sp*cr + sy*sr;
                   sy*cp, sy*sp*sr + cy*cr, sy*sp*cr - cy*sr; -sp, cp*sr, cp*cr];
            
            % Tọa độ Tâm Quay
            pos_pivot_k = Pivot_0 + [dx(k); dy(k); dz(k)];
            x_piv(k) = pos_pivot_k(1); 
            y_piv(k) = pos_pivot_k(2); 
            z_piv(k) = pos_pivot_k(3);
            
            % Tọa độ Bàn Máy
            pos_plat_k = pos_pivot_k - R_k * v_pivot;
            x_p(k) = pos_plat_k(1);
            y_p(k) = pos_plat_k(2);
            z_p(k) = pos_plat_k(3);
            
            % Tọa độ Đầu
            pos_head_k = pos_plat_k + R_k * v_head;
            x_h(k) = pos_head_k(1); y_h(k) = pos_head_k(2); z_h(k) = pos_head_k(3);
        end
    end

    % --- HÀM VẼ HỆ TRỤC TỌA ĐỘ ---
    function drawFrame(pos, R, name, scale)
        Vx = R * [scale; 0; 0];
        Vy = R * [0; scale; 0];
        Vz = R * [0; 0; scale];
        
        quiver3(ax, pos(1), pos(2), pos(3), Vx(1), Vx(2), Vx(3), 0, 'r', 'LineWidth', 2, 'MaxHeadSize', 0.5);
        quiver3(ax, pos(1), pos(2), pos(3), Vy(1), Vy(2), Vy(3), 0, 'g', 'LineWidth', 2, 'MaxHeadSize', 0.5);
        quiver3(ax, pos(1), pos(2), pos(3), Vz(1), Vz(2), Vz(3), 0, 'b', 'LineWidth', 2, 'MaxHeadSize', 0.5);
        
        text(ax, pos(1)+Vx(1)*1.1, pos(2)+Vx(2)*1.1, pos(3)+Vx(3)*1.1, [name 'x'], 'Color', 'r', 'FontWeight', 'bold');
        text(ax, pos(1)+Vy(1)*1.1, pos(2)+Vy(2)*1.1, pos(3)+Vy(3)*1.1, [name 'y'], 'Color', 'g', 'FontWeight', 'bold');
        text(ax, pos(1)+Vz(1)*1.1, pos(2)+Vz(2)*1.1, pos(3)+Vz(3)*1.1, [name 'z'], 'Color', 'b', 'FontWeight', 'bold');
    end

    function updatePreview()
        if contains(dd_type.Value, '---')
            return;
        end
        
        [~, x_p, y_p, z_p, r_arr, p_arr, yw_arr, x_h, y_h, z_h, x_piv, y_piv, z_piv] = generateData();
        
        cla(ax);
        
        % 1. Vẽ Quỹ Đạo
        plot3(ax, x_h, y_h, z_h, 'Color', [0.8500 0.3250 0.0980], 'LineWidth', 2.5, 'DisplayName', 'Quỹ đạo Đầu Người');
        plot3(ax, x_p, y_p, z_p, 'Color', [0 0.4470 0.7410], 'LineWidth', 2.5, 'DisplayName', 'Quỹ đạo Bàn Máy (Output)');
        plot3(ax, x_piv, y_piv, z_piv, 'm--', 'LineWidth', 1.5, 'DisplayName', 'Quỹ đạo Tâm Quay');
        
        % 2. Đánh dấu các Điểm tại t=0
        plot3(ax, x_h(1), y_h(1), z_h(1), 'ko', 'MarkerFaceColor', 'r', 'MarkerSize', 6, 'DisplayName', 'Start (Head)');
        plot3(ax, x_p(1), y_p(1), z_p(1), 'ks', 'MarkerFaceColor', 'b', 'MarkerSize', 6, 'DisplayName', 'Start (Plat)');
        plot3(ax, x_piv(1), y_piv(1), z_piv(1), 'kd', 'MarkerFaceColor', 'm', 'MarkerSize', 8, 'DisplayName', 'Tâm Quay (Pivot)');
        
        % Đường nối cứng thể hiện cấu trúc tại t=0
        plot3(ax, [x_p(1), x_h(1)], [y_p(1), y_h(1)], [z_p(1), z_h(1)], 'k-', 'LineWidth', 2, 'HandleVisibility', 'off');
        plot3(ax, [x_p(1), x_piv(1)], [y_p(1), y_piv(1)], [z_p(1), z_piv(1)], 'k:', 'LineWidth', 1.5, 'HandleVisibility', 'off');

        % 3. Vẽ 3 Hệ Trục Tọa Độ tại thời điểm t=0
        cy = cosd(yw_arr(1)); sy = sind(yw_arr(1)); 
        cp = cosd(p_arr(1));  sp = sind(p_arr(1)); 
        cr = cosd(r_arr(1));  sr = sind(r_arr(1));
        R_1 = [cy*cp, cy*sp*sr - sy*cr, cy*sp*cr + sy*sr;
               sy*cp, sy*sp*sr + cy*cr, sy*sp*cr - cy*sr; -sp, cp*sr, cp*cr];
               
        L_scale = 150; % Chiều dài mũi tên trục
        drawFrame([0; 0; 0], eye(3), 'A', L_scale); % Trục Tuyệt Đối (Absolute)
        drawFrame([x_p(1); y_p(1); z_p(1)], R_1, 'P', L_scale); % Trục Bàn Máy (Platform)
        drawFrame([x_h(1); y_h(1); z_h(1)], R_1, 'H', L_scale); % Trục Đầu Người (Head)

        legend(ax, 'show', 'Location', 'northeast');
        axis(ax, 'equal');
        
        % Tự động zoom
        lim_min = min([x_p; y_p; x_h; y_h]) - 150;
        lim_max = max([x_p; y_p; x_h; y_h]) + 150;
        xlim(ax, [lim_min lim_max]); ylim(ax, [lim_min lim_max]);
        zlim(ax, [0, max([z_p; z_h])+150]);
    end

    function exportCSV()
        if contains(dd_type.Value, '---')
            uialert(fig, 'Vui lòng chọn loại quỹ đạo hợp lệ!', 'Lỗi');
            return;
        end
        
        % Cập nhật hàm gọi để nhận đúng số lượng biến
        [t, x_p, y_p, z_p, r, p, yw, ~, ~, ~, ~, ~, ~] = generateData();
        
        T = table(t, x_p, y_p, z_p, r, p, yw, 'VariableNames', {'Time_s', 'X_Plat_mm', 'Y_Plat_mm', 'Z_Plat_mm', 'Roll_deg', 'Pitch_deg', 'Yaw_deg'});
        
        [file, path] = uiputfile('Generated_Trajectory.csv', 'Lưu file CSV cho Dashboard');
        if isequal(file, 0), return; end
        
        writetable(T, fullfile(path, file));
        uialert(fig, sprintf('Đã xuất thành công %d dòng dữ liệu quỹ đạo Top Platform!\n\nBạn có thể nạp file này vào Dashboard.', length(t)), 'Thành Công');
    end

    % Khởi chạy Preview lần đầu
    updatePreview();
end