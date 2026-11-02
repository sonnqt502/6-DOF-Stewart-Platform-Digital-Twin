function gui_motor_angle()
% GUI_MOTOR_ANGLE  Giao diện tính toán và xuất quỹ đạo góc động cơ CKAS
% Nhập quỹ đạo bệ động [t, x, y, z, yaw, pitch, roll] → xuất phi_thuc 6 động cơ

    %% ================================================================
    %  KHỞI TẠO CỬA SỔ CHÍNH
    %% ================================================================
    fig = uifigure('Name', 'CKAS — Tính Quỹ Đạo Góc Động Cơ', ...
        'Position', [60 60 1280 820], ...
        'Color', [0.13 0.13 0.15], ...
        'Resize', 'off');

    % Màu sắc chủ đề
    CLR_BG      = [0.13 0.13 0.15];
    CLR_PANEL   = [0.18 0.18 0.21];
    CLR_ACCENT  = [0.20 0.60 0.95];
    CLR_GREEN   = [0.25 0.75 0.40];
    CLR_RED     = [0.90 0.25 0.25];
    CLR_ORANGE  = [0.95 0.60 0.10];
    CLR_TEXT    = [0.92 0.92 0.92];
    CLR_SUBTEXT = [0.55 0.55 0.60];

    %% ================================================================
    %  THANH TIÊU ĐỀ
    %% ================================================================
    uilabel(fig, 'Text', 'CKAS  ·  Quỹ Đạo Góc Động Cơ', ...
        'Position', [20 785 640 28], ...
        'FontSize', 18, 'FontWeight', 'bold', ...
        'FontColor', CLR_ACCENT, 'BackgroundColor', CLR_BG);
    uilabel(fig, 'Text', 'Position-Level Inverse Kinematics  |  6-RUS Stewart Platform', ...
        'Position', [20 762 640 20], ...
        'FontSize', 11, 'FontColor', CLR_SUBTEXT, 'BackgroundColor', CLR_BG);

    %% ================================================================
    %  PANEL TRÁI — CẤU HÌNH & ĐIỀU KHIỂN
    %% ================================================================
    pnl_left = uipanel(fig, 'Position', [10 10 310 748], ...
        'BackgroundColor', CLR_PANEL, 'BorderType', 'none');

    y = 700;
    function lbl = sec_label(txt, y_pos)
        lbl = uilabel(pnl_left, 'Text', txt, ...
            'Position', [10 y_pos 290 22], ...
            'FontSize', 11, 'FontWeight', 'bold', ...
            'FontColor', CLR_ACCENT, 'BackgroundColor', CLR_PANEL);
    end
    function lbl = sub_label(txt, x_pos, y_pos, w)
        lbl = uilabel(pnl_left, 'Text', txt, ...
            'Position', [x_pos y_pos w 20], ...
            'FontSize', 10, 'FontColor', CLR_TEXT, 'BackgroundColor', CLR_PANEL);
    end

    % ---- FILE ĐẦU VÀO ----
    sec_label('① FILE QUỸ ĐẠO ĐẦU VÀO', y); y = y - 28;
    lbl_file = uilabel(pnl_left, 'Text', '(Chưa chọn file)', ...
        'Position', [10 y 290 20], 'FontSize', 9, ...
        'FontColor', CLR_SUBTEXT, 'BackgroundColor', CLR_PANEL);
    y = y - 30;
    btn_load = uibutton(pnl_left, 'Text', '📂  Chọn File CSV / TXT', ...
        'Position', [10 y 290 32], ...
        'BackgroundColor', CLR_ACCENT, 'FontColor', 'w', ...
        'FontWeight', 'bold', 'FontSize', 11, ...
        'ButtonPushedFcn', @(~,~) load_file());

    y = y - 45;

    % ---- THÔNG SỐ CƠ KHÍ ----
    sec_label('② THÔNG SỐ CƠ KHÍ', y); y = y - 26;

    sub_label('L₁  Tay đòn (mm)', 10, y, 140);
    ed_L1 = uieditfield(pnl_left, 'numeric', 'Value', 150, ...
        'Position', [155 y 145 24], 'FontSize', 11, ...
        'BackgroundColor', [0.22 0.22 0.26], 'FontColor', CLR_TEXT);
    y = y - 30;

    sub_label('L₂  Tay biên (mm)', 10, y, 140);
    ed_L2 = uieditfield(pnl_left, 'numeric', 'Value', 747, ...
        'Position', [155 y 145 24], 'FontSize', 11, ...
        'BackgroundColor', [0.22 0.22 0.26], 'FontColor', CLR_TEXT);
    y = y - 36;

    sub_label('Gamma (γ₁..γ₆, độ)', 10, y, 290);
    y = y - 24;
    gamma_default = [-109.45, -10.55, -229.45, -130.55, -349.45, -250.55];
    ed_gamma = uieditfield(pnl_left, 'text', ...
        'Value', num2str(gamma_default, '%.2f  '), ...
        'Position', [10 y 290 24], 'FontSize', 9, ...
        'BackgroundColor', [0.22 0.22 0.26], 'FontColor', CLR_TEXT);
    y = y - 38;

    % ---- TUỲ CHỌN ----
    sec_label('③ TUỲ CHỌN', y); y = y - 28;

    chk_plot = uicheckbox(pnl_left, 'Text', 'Vẽ đồ thị kết quả', ...
        'Value', true, 'Position', [10 y 200 22], ...
        'FontSize', 10, 'FontColor', CLR_TEXT);
    y = y - 28;

    chk_export = uicheckbox(pnl_left, 'Text', 'Xuất file CSV', ...
        'Value', false, 'Position', [10 y 200 22], ...
        'FontSize', 10, 'FontColor', CLR_TEXT);
    y = y - 28;

    lbl_csv = sub_label('Tên file xuất:', 10, y, 90);
    ed_csv = uieditfield(pnl_left, 'text', 'Value', 'Motor_Angles.csv', ...
        'Position', [105 y 195 24], 'FontSize', 9, ...
        'BackgroundColor', [0.22 0.22 0.26], 'FontColor', CLR_TEXT);
    y = y - 42;

    % ---- NÚT CHẠY ----
    btn_run = uibutton(pnl_left, 'Text', '▶  TÍNH TOÁN', ...
        'Position', [10 y 290 40], ...
        'BackgroundColor', CLR_GREEN, 'FontColor', 'w', ...
        'FontWeight', 'bold', 'FontSize', 14, ...
        'ButtonPushedFcn', @(~,~) run_ik());
    y = y - 50;

    % ---- THỐNG KÊ KẾT QUẢ ----
    sec_label('④ KẾT QUẢ', y); y = y - 28;

    lbl_n     = sub_label('Số điểm quỹ đạo:  —', 10, y, 290); y = y - 24;
    lbl_dur   = sub_label('Thời gian:  —', 10, y, 290); y = y - 24;
    lbl_ok    = sub_label('Điểm khả thi:  —', 10, y, 290); y = y - 24;
    lbl_range = sub_label('Phạm vi góc:  —', 10, y, 290); y = y - 36;

    % ---- NÚT XUẤT THỦ CÔNG ----
    btn_export = uibutton(pnl_left, 'Text', '💾  Xuất CSV bây giờ', ...
        'Position', [10 y 290 32], ...
        'BackgroundColor', CLR_ORANGE, 'FontColor', 'w', ...
        'FontWeight', 'bold', 'FontSize', 11, ...
        'ButtonPushedFcn', @(~,~) export_now(), 'Enable', 'off');

    % ---- THANH TRẠNG THÁI ----
    lbl_status = uilabel(pnl_left, ...
        'Text', 'Sẵn sàng. Chọn file để bắt đầu.', ...
        'Position', [10 8 290 36], ...
        'FontSize', 9, 'FontColor', CLR_SUBTEXT, ...
        'BackgroundColor', CLR_PANEL, ...
        'WordWrap', 'on', 'VerticalAlignment', 'top');

    %% ================================================================
    %  PANEL PHẢI — ĐỒ THỊ
    %% ================================================================
    pnl_right = uipanel(fig, 'Position', [328 10 942 748], ...
        'BackgroundColor', CLR_BG, 'BorderType', 'none');

    ax_vel = uiaxes(pnl_right, 'Position', [10 400 450 330], ...
        'Color', CLR_PANEL, 'XColor', CLR_TEXT, 'YColor', CLR_TEXT, ...
        'GridColor', [0.3 0.3 0.35], 'GridAlpha', 0.5);
    title(ax_vel, 'Quỹ đạo Pose đầu vào', 'Color', CLR_TEXT);
    xlabel(ax_vel, 'Thời gian (s)'); ylabel(ax_vel, 'mm / độ');
    grid(ax_vel, 'on'); hold(ax_vel, 'on');

    ax_ang = uiaxes(pnl_right, 'Position', [475 400 455 330], ...
        'Color', CLR_PANEL, 'XColor', CLR_TEXT, 'YColor', CLR_TEXT, ...
        'GridColor', [0.3 0.3 0.35], 'GridAlpha', 0.5);
    title(ax_ang, 'Góc bệ động (Yaw / Pitch / Roll)', 'Color', CLR_TEXT);
    xlabel(ax_ang, 'Thời gian (s)'); ylabel(ax_ang, 'độ');
    grid(ax_ang, 'on'); hold(ax_ang, 'on');

    ax_phi = uiaxes(pnl_right, 'Position', [10 20 920 368], ...
        'Color', CLR_PANEL, 'XColor', CLR_TEXT, 'YColor', CLR_TEXT, ...
        'GridColor', [0.3 0.3 0.35], 'GridAlpha', 0.5);
    title(ax_phi, 'Quỹ đạo Góc Động Cơ (phi_thuc)', 'Color', CLR_TEXT);
    xlabel(ax_phi, 'Thời gian (s)'); ylabel(ax_phi, 'Góc (độ)');
    grid(ax_phi, 'on'); hold(ax_phi, 'on');

    %% ================================================================
    %  BIẾN NỘI BỘ
    %% ================================================================
    traj_data = [];
    phi_result = [];
    t_result = [];

    %% ================================================================
    %  HÀM NỘI BỘ
    %% ================================================================

    function load_file()
        [fname, fpath] = uigetfile({'*.csv;*.txt', 'Trajectory file (*.csv, *.txt)'}, ...
            'Chọn file quỹ đạo');
        if isequal(fname, 0), return; end

        set_status('Đang đọc file...', CLR_ORANGE);
        try
            filePath = fullfile(fpath, fname);
            fid = fopen(filePath, 'r');
            raw_lines = textscan(fid, '%s', 'Delimiter', '\n');
            fclose(fid);
            lines = raw_lines{1};
            
            num_lines = length(lines);
            raw = zeros(num_lines, 7);
            valid_cnt = 0;
            for i = 1:num_lines
                line = lines{i};
                if isempty(strtrim(line)), continue; end
                line = strrep(line, '~M[', ' ');
                line = strrep(line, ']', ' ');
                line = strrep(line, char(9), ' ');
                line = regexprep(line, '-\s+', '-');
                nums = sscanf(line, '%f');
                if length(nums) >= 6
                    valid_cnt = valid_cnt + 1;
                    n_col = min(length(nums), 7);
                    raw(valid_cnt, 1:n_col) = nums(1:n_col)';
                end
            end
            raw = raw(1:valid_cnt, :);

            if size(raw, 2) < 6 || isempty(raw)
                set_status('Lỗi: File cần ≥ 6 cột [x,y,z,yaw,pitch,roll] hoặc 7 cột có thêm t.', CLR_RED);
                return;
            end
            traj_data = raw;
            lbl_file.Text = fname;
            lbl_file.FontColor = CLR_GREEN;
            n = size(raw, 1);
            if size(raw,2) == 7
                dur = raw(end,1) - raw(1,1);
                lbl_n.Text   = sprintf('Số điểm quỹ đạo:  %d', n);
                lbl_dur.Text = sprintf('Thời gian:  %.2f s', dur);
            else
                lbl_n.Text   = sprintf('Số điểm quỹ đạo:  %d', n);
                lbl_dur.Text = sprintf('Thời gian:  (tự sinh dt=0.02s)');
            end
            set_status(sprintf('Đã nạp: %s (%d dòng × %d cột)', fname, size(raw,1), size(raw,2)), CLR_GREEN);

            % Preview pose trên đồ thị
            draw_input_preview();
        catch e
            set_status(['Lỗi đọc file: ' e.message], CLR_RED);
        end
    end

    function draw_input_preview()
        cla(ax_vel); cla(ax_ang); cla(ax_phi);
        if isempty(traj_data), return; end

        if size(traj_data,2) == 7
            t_p = traj_data(:,1);
            poses = traj_data(:,2:7);
        else
            t_p = (0:size(traj_data,1)-1)' * 0.02;
            poses = traj_data;
        end

        colors_xyz = [0.30 0.70 1.00; 0.30 1.00 0.50; 1.00 0.40 0.40];
        labels_xyz = {'X (mm)', 'Y (mm)', 'Z (mm)'};
        for c = 1:3
            plot(ax_vel, t_p, poses(:,c), 'Color', colors_xyz(c,:), 'LineWidth', 1.5, ...
                'DisplayName', labels_xyz{c});
        end
        legend(ax_vel, 'Location', 'best', 'TextColor', CLR_TEXT, 'Color', CLR_PANEL);

        colors_ang = [1.00 0.80 0.20; 0.80 0.40 1.00; 0.40 0.90 0.90];
        labels_ang = {'Yaw (°)', 'Pitch (°)', 'Roll (°)'};
        for c = 4:6
            plot(ax_ang, t_p, poses(:,c), 'Color', colors_ang(c-3,:), 'LineWidth', 1.5, ...
                'DisplayName', labels_ang{c-3});
        end
        legend(ax_ang, 'Location', 'best', 'TextColor', CLR_TEXT, 'Color', CLR_PANEL);
    end

    function run_ik()
        if isempty(traj_data)
            set_status('Chưa có dữ liệu! Hãy chọn file trước.', CLR_RED);
            return;
        end

        set_status('Đang tính IK...', CLR_ORANGE);
        drawnow;

        try
            % Đọc thông số
            L1    = ed_L1.Value;
            L2    = ed_L2.Value;
            gamma = str2num(ed_gamma.Value); %#ok<ST2NM>
            if numel(gamma) ~= 6
                set_status('Lỗi: Gamma phải có đúng 6 giá trị cách nhau bằng dấu cách.', CLR_RED);
                return;
            end

            % Tham số cơ khí mặc định (có thể mở rộng thành editable fields sau)
            A = [ 556.009538774124, -107.962917791227, -448.046620982896, ...
                 -448.046620982896, -107.962917791227,  556.009538774124;
                 -196.347417584715, -579.692094117217, -383.344676532502, ...
                  383.344676532502,  579.692094117217,  196.347417584715;
                  668.4, 668.4, 668.4, 668.4, 668.4, 668.4 ];

            B = [ 256.599204538802,  169.981755823305, -426.649811653508, ...
                 -426.641083944694,  170.050607114706,  256.659328121389;
                 -344.505147401391, -394.503676843735,  -49.968856020786, ...
                   50.043319699002,  394.474003422177,  344.460357144733;
                  0, 0, 0, 0, 0, 0 ];

            % Chạy IK
            opts.plot_result = false;  % Tự vẽ trong GUI
            opts.export_csv  = chk_export.Value;
            opts.csv_path    = ed_csv.Value;

            [phi_result, t_result] = traj_to_motor_angle(traj_data, A, B, L1, L2, gamma, opts);

            % Cập nhật thống kê
            bad = any(isnan(phi_result), 2);
            n_bad = sum(bad);
            lbl_ok.Text    = sprintf('Điểm khả thi:  %d / %d  (%.1f%%)', ...
                size(phi_result,1)-n_bad, size(phi_result,1), ...
                100*(1-n_bad/size(phi_result,1)));
            if n_bad > 0
                lbl_ok.FontColor = CLR_RED;
            else
                lbl_ok.FontColor = CLR_GREEN;
            end
            phi_min = min(phi_result(:)); phi_max = max(phi_result(:));
            lbl_range.Text = sprintf('Phạm vi góc:  %.1f° → %.1f°', phi_min, phi_max);

            % Vẽ kết quả
            draw_phi_result();

            btn_export.Enable = 'on';
            if chk_export.Value
                set_status(sprintf('Hoàn tất! Đã xuất: %s', opts.csv_path), CLR_GREEN);
            else
                set_status('Tính toán hoàn tất! Bấm "Xuất CSV" để lưu file.', CLR_GREEN);
            end

        catch e
            set_status(['Lỗi: ' e.message], CLR_RED);
        end
    end

    function draw_phi_result()
        cla(ax_phi);
        if isempty(phi_result), return; end

        colors_m = lines(6);
        motor_names = {'Motor 1', 'Motor 2', 'Motor 3', 'Motor 4', 'Motor 5', 'Motor 6'};
        for i = 1:6
            plot(ax_phi, t_result, phi_result(:,i), ...
                'Color', colors_m(i,:), 'LineWidth', 1.8, ...
                'DisplayName', motor_names{i});
        end

        % Đánh dấu điểm kịch cơ khí
        bad = any(isnan(phi_result), 2);
        if any(bad)
            scatter(ax_phi, t_result(bad), zeros(sum(bad),1), ...
                80, 'r', 'x', 'LineWidth', 2.5, 'DisplayName', 'Kịch cơ khí');
        end

        legend(ax_phi, 'Location', 'best', 'TextColor', CLR_TEXT, 'Color', CLR_PANEL);
        title(ax_phi, 'Quỹ đạo Góc Động Cơ (phi\_thuc)', 'Color', CLR_TEXT);
    end

    function export_now()
        if isempty(phi_result)
            set_status('Chưa có kết quả để xuất!', CLR_RED);
            return;
        end

        [fname, fpath] = uiputfile('Motor_Angles.csv', 'Lưu file CSV');
        if isequal(fname, 0), return; end

        fid = fopen(fullfile(fpath, fname), 'w');
        if fid == -1
            set_status('Lỗi: Không thể ghi file!', CLR_RED);
            return;
        end

        % Header
        if size(traj_data,2) == 7
            poses = traj_data(:,2:7);
        else
            poses = traj_data;
        end

        fprintf(fid, 't,x,y,z,yaw,pitch,roll,phi1,phi2,phi3,phi4,phi5,phi6\n');
        for k = 1:length(t_result)
            fprintf(fid, '%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f\n', ...
                t_result(k), poses(k,1), poses(k,2), poses(k,3), ...
                poses(k,4), poses(k,5), poses(k,6), ...
                phi_result(k,1), phi_result(k,2), phi_result(k,3), ...
                phi_result(k,4), phi_result(k,5), phi_result(k,6));
        end
        fclose(fid);
        set_status(sprintf('Đã xuất thành công: %s', fname), CLR_GREEN);
    end

    function set_status(msg, color)
        lbl_status.Text = msg;
        lbl_status.FontColor = color;
        drawnow;
    end
end
