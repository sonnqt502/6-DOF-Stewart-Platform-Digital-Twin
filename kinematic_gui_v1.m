function kinematic_gui_v1()
    % KINEMATIC_GUI_V1 Giao diện trực quan để kiểm thử động học (chân ảo / góc quay) với Tâm quay
    
    fig = uifigure('Name', 'Mô phỏng Kinematics - Stewart Platform', 'Position', [100 100 1000 700], 'Color', 'w');
    
    % Panel điều khiển tay
    pnl_manual = uipanel(fig, 'Title', 'Điều khiển vị trí thủ công', 'Position', [20 220 300 460], 'BackgroundColor', 'w', 'FontWeight', 'bold');
    
    lbl_x = uilabel(pnl_manual, 'Text', 'X (mm):', 'Position', [10 410 60 22]);
    sld_x = uislider(pnl_manual, 'Position', [80 420 140 3], 'Limits', [-300 300], 'Value', 0);
    edt_x = uieditfield(pnl_manual, 'numeric', 'Position', [230 410 60 22], 'Value', 0);
    
    lbl_y = uilabel(pnl_manual, 'Text', 'Y (mm):', 'Position', [10 370 60 22]);
    sld_y = uislider(pnl_manual, 'Position', [80 380 140 3], 'Limits', [-300 300], 'Value', 0);
    edt_y = uieditfield(pnl_manual, 'numeric', 'Position', [230 370 60 22], 'Value', 0);
    
    lbl_z = uilabel(pnl_manual, 'Text', 'Z (mm):', 'Position', [10 330 60 22]);
    sld_z = uislider(pnl_manual, 'Position', [80 340 140 3], 'Limits', [-500 1000], 'Value', 0);
    edt_z = uieditfield(pnl_manual, 'numeric', 'Position', [230 330 60 22], 'Value', 0);
    
    lbl_r = uilabel(pnl_manual, 'Text', 'Roll (°):', 'Position', [10 290 60 22]);
    sld_r = uislider(pnl_manual, 'Position', [80 300 140 3], 'Limits', [-45 45], 'Value', 0);
    edt_r = uieditfield(pnl_manual, 'numeric', 'Position', [230 290 60 22], 'Value', 0);
    
    lbl_p = uilabel(pnl_manual, 'Text', 'Pitch (°):', 'Position', [10 250 60 22]);
    sld_p = uislider(pnl_manual, 'Position', [80 260 140 3], 'Limits', [-45 45], 'Value', 0);
    edt_p = uieditfield(pnl_manual, 'numeric', 'Position', [230 250 60 22], 'Value', 0);
    
    lbl_yw = uilabel(pnl_manual, 'Text', 'Yaw (°):', 'Position', [10 210 60 22]);
    sld_yw = uislider(pnl_manual, 'Position', [80 220 140 3], 'Limits', [-45 45], 'Value', 0);
    edt_yw = uieditfield(pnl_manual, 'numeric', 'Position', [230 210 60 22], 'Value', 0);

    lbl_cx = uilabel(pnl_manual, 'Text', 'Tâm X (mm):', 'Position', [10 170 70 22]);
    sld_cx = uislider(pnl_manual, 'Position', [85 180 135 3], 'Limits', [-300 300], 'Value', 0);
    edt_cx = uieditfield(pnl_manual, 'numeric', 'Position', [230 170 60 22], 'Value', 0);
    
    lbl_cy = uilabel(pnl_manual, 'Text', 'Tâm Y (mm):', 'Position', [10 130 70 22]);
    sld_cy = uislider(pnl_manual, 'Position', [85 140 135 3], 'Limits', [-300 300], 'Value', 0);
    edt_cy = uieditfield(pnl_manual, 'numeric', 'Position', [230 130 60 22], 'Value', 0);

    lbl_cz = uilabel(pnl_manual, 'Text', 'Tâm Z (mm):', 'Position', [10 90 70 22]);
    sld_cz = uislider(pnl_manual, 'Position', [85 100 135 3], 'Limits', [-300 300], 'Value', 0);
    edt_cz = uieditfield(pnl_manual, 'numeric', 'Position', [230 90 60 22], 'Value', 0);
    
    btn_find_limits = uibutton(pnl_manual, 'Text', 'Dò Giới Hạn 1D', 'Position', [10 20 280 30], ...
        'BackgroundColor', [0.93 0.69 0.13], 'FontWeight', 'bold', ...
        'ButtonPushedFcn', @(btn,event) findLimits());
    
    % Panel chế độ và File
    pnl_mode = uipanel(fig, 'Title', 'Chế độ mô phỏng & Đọc File', 'Position', [20 10 300 200], 'BackgroundColor', 'w', 'FontWeight', 'bold');
    
    uilabel(pnl_mode, 'Text', 'Cấu hình:', 'Position', [10 160 60 22]);
    btn_cfg = uibutton(pnl_mode, 'Text', 'Chọn JSON', 'Position', [80 160 90 22], 'ButtonPushedFcn', @(btn,event) loadConfig());
    lbl_cfg = uilabel(pnl_mode, 'Text', 'config.json', 'Position', [180 160 110 22]);
    
    uilabel(pnl_mode, 'Text', 'Hàm Kinematic:', 'Position', [10 120 100 22]);
    dd_func = uidropdown(pnl_mode, 'Items', {'Kinematic Góc Quay (Động cơ)', 'Kinematic Chân Ảo'}, 'Position', [110 120 170 22]);
    
    btn_browse = uibutton(pnl_mode, 'Text', 'Browse File', 'Position', [10 70 100 30], 'ButtonPushedFcn', @(btn,event) loadFile());
    lbl_file = uilabel(pnl_mode, 'Text', 'Chưa chọn file', 'Position', [120 75 160 22]);
    
    btn_play = uibutton(pnl_mode, 'Text', '▶ Play', 'Position', [10 20 85 30], 'Enable', 'off', 'BackgroundColor', [0.47 0.67 0.19], 'FontColor', 'w', 'FontWeight', 'bold', 'ButtonPushedFcn', @(btn,event) playFile());
    btn_pause = uibutton(pnl_mode, 'Text', '⏸ Pause', 'Position', [105 20 85 30], 'Enable', 'off', 'BackgroundColor', [0.93 0.69 0.13], 'FontWeight', 'bold', 'ButtonPushedFcn', @(btn,event) pausePlay());
    btn_stop = uibutton(pnl_mode, 'Text', '⏹ Stop', 'Position', [200 20 90 30], 'Enable', 'off', 'BackgroundColor', [0.64 0.08 0.18], 'FontColor', 'w', 'FontWeight', 'bold', 'ButtonPushedFcn', @(btn,event) stopPlay());
    
    % Biểu đồ Bar hiển thị trạng thái
    ax_bar = uiaxes(fig, 'Position', [340 160 630 520]);
    title(ax_bar, 'Trực quan hóa trạng thái các khớp');
    lbl_status = uilabel(fig, 'Text', 'Trạng thái: Đang khởi tạo...', 'Position', [340 110 630 30], 'FontSize', 16, 'FontWeight', 'bold', 'FontColor', 'g');
    
    % Khung hiển thị M-code
    pnl_mcode = uipanel(fig, 'Title', 'Lệnh M-Code đang thực hiện', 'Position', [340 20 630 80], 'BackgroundColor', '#f4f4f4', 'FontWeight', 'bold');
    lbl_mcode = uilabel(pnl_mcode, 'Text', 'Chưa có lệnh', 'Position', [10 15 610 30], 'FontSize', 16, 'FontName', 'Consolas', 'FontColor', 'b');
    
    % Variables for file playback
    fileData = [];
    isPlaying = false;
    isPaused = false;
    currentConfigPath = fullfile(pwd, 'config.json');
    currentCfg = [];
    
    % Khởi tạo currentCfg
    fid_init = fopen(currentConfigPath, 'r');
    if fid_init ~= -1
        raw_init = fread(fid_init, '*char')'; fclose(fid_init);
        currentCfg = jsondecode(raw_init);
    end
    
    % Gắn callback cho slider (khi kéo slider thì vẽ lại biểu đồ)
    % Hàm đồng bộ giá trị giữa slider và edit field
    function syncValue(source, sld, edt)
        if source == sld
            edt.Value = sld.Value;
        else
            val = max(min(edt.Value, sld.Limits(2)), sld.Limits(1));
            edt.Value = val;
            sld.Value = val;
        end
        updatePlotManual();
    end
    
    % Gắn callback cho slider và edit field
    sld_x.ValueChangedFcn = @(sld,event) syncValue(sld, sld_x, edt_x);
    edt_x.ValueChangedFcn = @(edt,event) syncValue(edt, sld_x, edt_x);
    
    sld_y.ValueChangedFcn = @(sld,event) syncValue(sld, sld_y, edt_y);
    edt_y.ValueChangedFcn = @(edt,event) syncValue(edt, sld_y, edt_y);
    
    sld_z.ValueChangedFcn = @(sld,event) syncValue(sld, sld_z, edt_z);
    edt_z.ValueChangedFcn = @(edt,event) syncValue(edt, sld_z, edt_z);
    
    sld_r.ValueChangedFcn = @(sld,event) syncValue(sld, sld_r, edt_r);
    edt_r.ValueChangedFcn = @(edt,event) syncValue(edt, sld_r, edt_r);
    
    sld_p.ValueChangedFcn = @(sld,event) syncValue(sld, sld_p, edt_p);
    edt_p.ValueChangedFcn = @(edt,event) syncValue(edt, sld_p, edt_p);
    
    sld_yw.ValueChangedFcn = @(sld,event) syncValue(sld, sld_yw, edt_yw);
    edt_yw.ValueChangedFcn = @(edt,event) syncValue(edt, sld_yw, edt_yw);
    
    sld_cx.ValueChangedFcn = @(sld,event) syncValue(sld, sld_cx, edt_cx);
    edt_cx.ValueChangedFcn = @(edt,event) syncValue(edt, sld_cx, edt_cx);
    
    sld_cy.ValueChangedFcn = @(sld,event) syncValue(sld, sld_cy, edt_cy);
    edt_cy.ValueChangedFcn = @(edt,event) syncValue(edt, sld_cy, edt_cy);
    
    sld_cz.ValueChangedFcn = @(sld,event) syncValue(sld, sld_cz, edt_cz);
    edt_cz.ValueChangedFcn = @(edt,event) syncValue(edt, sld_cz, edt_cz);

    dd_func.ValueChangedFcn = @(dd,event) updatePlotManual();
    
    % Lần gọi đầu tiên để vẽ biểu đồ tại vị trí Home
    updatePlotManual();
    
    function updatePlotManual()
        if isPlaying, return; end % Nếu đang play file thì vô hiệu hóa slider
        x = sld_x.Value;
        y = sld_y.Value;
        z = sld_z.Value;
        r = sld_r.Value;
        p = sld_p.Value;
        yw = sld_yw.Value;
        cx = sld_cx.Value;
        cy = sld_cy.Value;
        cz = sld_cz.Value;
        updatePlotCore(x, y, z, r, p, yw, cx, cy, cz);
    end
    
    function updatePlotCore(x, y, z, r, p, yw, cx, cy, cz)
        mode = dd_func.Value;
        if isempty(currentCfg)
            uialert(fig, 'Không có cấu hình hợp lệ!', 'Lỗi');
            return;
        end
        cfg = currentCfg;
        
        if strcmp(mode, 'Kinematic Góc Quay (Động cơ)')
            [data_val, is_val, msg] = kinematic_goc_quay(x, y, z, r, p, yw, cfg, cx, cy, cz);
            lim_min = cfg.motor_limit_min;
            lim_max = cfg.motor_limit_max;
            ylabel(ax_bar, 'Góc quay (độ)');
            title(ax_bar, 'Góc quay 6 động cơ');
        else
            [data_val, is_val, msg] = kinematic_chan_ao(x, y, z, r, p, yw, cfg, cx, cy, cz);
            % Giới hạn chân ảo thực tế tương ứng với góc motor [-50, 90]
            lim_min = 616.49;
            lim_max = 868.20;
            ylabel(ax_bar, 'Độ dài (mm)');
            title(ax_bar, 'Độ dài 6 chân ảo');
        end
        
        cla(ax_bar);
        hold(ax_bar, 'on');
        
        % Dữ liệu data_val trả về là vector cột 6x1
        b = bar(ax_bar, 1:6, data_val);
        
        if is_val(1)
            b.FaceColor = [0.00 0.45 0.74]; % Xanh bình thường
            lbl_status.Text = ['Trạng thái: Hợp lệ - ' msg{1}];
            lbl_status.FontColor = [0 0.5 0];
        else
            b.FaceColor = [0.8 0 0]; % Đỏ báo lỗi
            lbl_status.Text = ['Trạng thái: LỖI - ' msg{1}];
            lbl_status.FontColor = [0.8 0 0];
        end
        
        % Vẽ đường giới hạn đỏ đứt nét
        yline(ax_bar, lim_min, 'r--', 'LineWidth', 2);
        yline(ax_bar, lim_max, 'r--', 'LineWidth', 2);
        
        % Text hiển thị giá trị giới hạn trên/dưới
        text(ax_bar, 0.5, lim_min, sprintf('Min: %.1f', lim_min), 'Color', 'r', 'VerticalAlignment', 'bottom');
        text(ax_bar, 0.5, lim_max, sprintf('Max: %.1f', lim_max), 'Color', 'r', 'VerticalAlignment', 'bottom');
        
        % Thêm text hiển thị giá trị cụ thể ở trên mỗi cột
        for i = 1:6
            if data_val(i) >= 0
                va = 'bottom';
                y_offset = (lim_max - lim_min) * 0.02; % Offset xíu để khỏi dính nét
            else
                va = 'top';
                y_offset = -(lim_max - lim_min) * 0.02;
            end
            text(ax_bar, i, data_val(i) + y_offset, sprintf('%.1f', data_val(i)), ...
                'HorizontalAlignment', 'center', ...
                'VerticalAlignment', va, ...
                'FontWeight', 'bold', ...
                'FontSize', 11);
        end
        
        % Cài đặt trục
        ax_bar.XTick = 1:6;
        ax_bar.XTickLabel = {'Motor 1', 'Motor 2', 'Motor 3', 'Motor 4', 'Motor 5', 'Motor 6'};
        if strcmp(mode, 'Kinematic Góc Quay (Động cơ)')
            ylim(ax_bar, [lim_min - 20, lim_max + 20]);
        else
            ylim(ax_bar, [lim_min - 50, lim_max + 50]);
        end
        grid(ax_bar, 'on');
        hold(ax_bar, 'off');
    end

    function loadFile()
        [file, path] = uigetfile({'*.csv;*.txt', 'Data Files'});
        if isequal(file,0), return; end
        lbl_file.Text = file;
        
        try
            fullPath = fullfile(path, file);
            
            % Đọc file theo từng dòng để xử lý định dạng đặc biệt (~M[...])
            fid = fopen(fullPath, 'r');
            raw_lines = textscan(fid, '%s', 'Delimiter', '\n');
            fclose(fid);
            
            lines = raw_lines{1};
            data = [];
            for i = 1:length(lines)
                line = lines{i};
                if isempty(strtrim(line)), continue; end
                
                % Loại bỏ các ký tự đặc biệt của định dạng quỹ đạo
                line = strrep(line, '~M[', ' ');
                line = strrep(line, ']', ' ');
                
                % Chuyển tab thành space
                line = strrep(line, char(9), ' ');
                
                % Sửa lỗi các khoảng trắng/tab bị chèn vào giữa số (vd: "- 75.000" hoặc "0 .000")
                line = regexprep(line, '-\s+', '-');
                line = regexprep(line, '(\d+)\s+\.(\d+)', '$1.$2');
                
                % Lấy các số trong dòng
                nums = sscanf(line, '%f');
                
                if length(nums) >= 7
                    data = [data; nums(1:7)'];
                end
            end
            
            if isempty(data)
                error('Không lấy được dữ liệu số từ file hoặc sai định dạng');
            end
            
            fileData = data;
            btn_play.Enable = 'on';
            uialert(fig, 'Tải file thành công! Bạn có thể nhấn Play để xem mô phỏng.', 'Thành công');
        catch ME
            uialert(fig, ['Lỗi tải file: ' ME.message], 'Lỗi');
            btn_play.Enable = 'off';
        end
    end

    function playFile()
        if isempty(fileData), return; end
        isPlaying = true;
        isPaused = false;
        btn_play.Enable = 'off';
        btn_pause.Enable = 'on';
        btn_pause.Text = '⏸ Pause';
        btn_stop.Enable = 'on';
        
        % Cột dữ liệu: 1=t, 2=x, 3=y, 4=z, 5=yaw, 6=pitch, 7=roll
        T_arr = fileData(:, 1);
        X_arr = fileData(:, 2);
        Y_arr = fileData(:, 3);
        Z_arr = fileData(:, 4);
        Yaw_arr = fileData(:, 5);
        Pitch_arr = fileData(:, 6);
        Roll_arr = fileData(:, 7);
        
        N = length(T_arr);
        for i = 1:N
            if ~isPlaying, break; end
            
            while isPaused && isPlaying
                pause(0.1);
                drawnow;
            end
            
            if ~isPlaying, break; end
            
            % Đồng bộ giao diện slider để người dùng thấy giá trị đang thay đổi
            try
                sld_x.Value = max(min(X_arr(i), sld_x.Limits(2)), sld_x.Limits(1));
                sld_y.Value = max(min(Y_arr(i), sld_y.Limits(2)), sld_y.Limits(1));
                sld_z.Value = max(min(Z_arr(i), sld_z.Limits(2)), sld_z.Limits(1));
                sld_r.Value = max(min(Roll_arr(i), sld_r.Limits(2)), sld_r.Limits(1));
                sld_p.Value = max(min(Pitch_arr(i), sld_p.Limits(2)), sld_p.Limits(1));
                sld_yw.Value = max(min(Yaw_arr(i), sld_yw.Limits(2)), sld_yw.Limits(1));
                
                % Cập nhật lại giá trị hiển thị trên ô nhập số
                edt_x.Value = sld_x.Value;
                edt_y.Value = sld_y.Value;
                edt_z.Value = sld_z.Value;
                edt_r.Value = sld_r.Value;
                edt_p.Value = sld_p.Value;
                edt_yw.Value = sld_yw.Value;
            catch
            end
            
            % Cập nhật M-Code frame
            mcode_str = sprintf('%.4f  ~M[ %.4f %.4f %.4f %.4f %.4f %.4f ]', ...
                T_arr(i), X_arr(i), Y_arr(i), Z_arr(i), Yaw_arr(i), Pitch_arr(i), Roll_arr(i));
            lbl_mcode.Text = mcode_str;
            
            % Lay tam quay tu giao dien cho che do doc file
            cx = sld_cx.Value;
            cy = sld_cy.Value;
            cz = sld_cz.Value;
            
            updatePlotCore(X_arr(i), Y_arr(i), Z_arr(i), Roll_arr(i), Pitch_arr(i), Yaw_arr(i), cx, cy, cz);
            drawnow;
            
            if i < N
                dt = T_arr(i+1) - T_arr(i);
                if dt > 0 && dt < 1.0  % Chỉ pause nếu dt hợp lý
                    pause(dt);
                end
            end
        end
        
        lbl_mcode.Text = 'Hoàn thành phát quỹ đạo.';
        isPlaying = false;
        isPaused = false;
        btn_play.Enable = 'on';
        btn_pause.Enable = 'off';
        btn_pause.Text = '⏸ Pause';
        btn_stop.Enable = 'off';
    end

    function stopPlay()
        isPlaying = false;
        isPaused = false;
        btn_play.Enable = 'on';
        btn_pause.Enable = 'off';
        btn_pause.Text = '⏸ Pause';
        btn_stop.Enable = 'off';
    end

    function pausePlay()
        isPaused = ~isPaused;
        if isPaused
            btn_pause.Text = '▶ Resume';
        else
            btn_pause.Text = '⏸ Pause';
        end
    end

    function loadConfig()
        [file, path] = uigetfile('*.json', 'Chọn file cấu hình JSON');
        if isequal(file,0), return; end
        currentConfigPath = fullfile(path, file);
        lbl_cfg.Text = file;
        
        % Cập nhật cache
        fid = fopen(currentConfigPath, 'r');
        if fid ~= -1
            raw = fread(fid, '*char')'; fclose(fid);
            currentCfg = jsondecode(raw);
        end
        
        updatePlotManual(); % Cập nhật lại biểu đồ với cấu hình mới
    end

    function findLimits()
        x0 = sld_x.Value; y0 = sld_y.Value; z0 = sld_z.Value;
        r0 = sld_r.Value; p0 = sld_p.Value; yw0 = sld_yw.Value;
        cx0 = sld_cx.Value; cy0 = sld_cy.Value; cz0 = sld_cz.Value;
        current_pose = [x0, y0, z0, r0, p0, yw0];
        
        btn_find_limits.Enable = 'off';
        btn_find_limits.Text = 'Đang dò...';
        drawnow;
        
        try
            % Kiểm tra điểm hiện tại
            if ~getValidMask(x0, y0, z0, r0, p0, yw0, cx0, cy0, cz0)
                uialert(fig, 'Điểm hiện tại đang báo lỗi (không an toàn)! Không thể dò từ điểm này.', 'Lỗi');
                btn_find_limits.Enable = 'on';
                btn_find_limits.Text = 'Dò Giới Hạn 1D';
                return;
            end
            
            check_safe = @(pose) getValidMask(pose(1), pose(2), pose(3), pose(4), pose(5), pose(6), cx0, cy0, cz0);
            
            lims = zeros(6, 2); % [Min, Max]
            step_lin = 1; % 1 mm
            step_ang = 0.5; % 0.5 độ
            
            for axis = 1:6
                step = step_lin; if axis > 3, step = step_ang; end
                
                % Tìm Max (+)
                test_pose = current_pose;
                while check_safe(test_pose)
                    test_pose(axis) = test_pose(axis) + step;
                    % Bảo vệ vòng lặp vô hạn
                    if test_pose(axis) > 2000, break; end
                end
                lims(axis, 2) = test_pose(axis) - step; 
                
                % Tìm Min (-)
                test_pose = current_pose;
                while check_safe(test_pose)
                    test_pose(axis) = test_pose(axis) - step;
                    if test_pose(axis) < -2000, break; end
                end
                lims(axis, 1) = test_pose(axis) + step; 
            end
            
            msg = sprintf(['GIỚI HẠN DÒ TỪ ĐIỂM HIỆN TẠI:\n\n' ...
                           'X: [%.1f,  %.1f] mm\n' ...
                           'Y: [%.1f,  %.1f] mm\n' ...
                           'Z: [%.1f,  %.1f] mm\n' ...
                           'Roll: [%.1f,  %.1f] °\n' ...
                           'Pitch: [%.1f,  %.1f] °\n' ...
                           'Yaw: [%.1f,  %.1f] °\n\n' ...
                           '(Lưu ý: Các trục khác giữ nguyên ở vị trí hiện tại)'], ...
                           lims(1,1), lims(1,2), lims(2,1), lims(2,2), lims(3,1), lims(3,2), ...
                           lims(4,1), lims(4,2), lims(5,1), lims(5,2), lims(6,1), lims(6,2));
                           
            uialert(fig, msg, 'Kết Quả Dò Tìm', 'Icon', 'info');
        catch ME
            uialert(fig, ['Lỗi: ' ME.message], 'Lỗi');
        end
        
        btn_find_limits.Enable = 'on';
        btn_find_limits.Text = 'Dò Giới Hạn 1D';
    end

    function mask = getValidMask(X, Y, Z, R, P, YW, cx, cy, cz)
        if nargin < 9
            cx = sld_cx.Value; cy = sld_cy.Value; cz = sld_cz.Value;
        end
        [~, mask, ~] = kinematic_goc_quay(X, Y, Z, R, P, YW, currentCfg, cx, cy, cz);
    end

    % Hàm tìm giới hạn liên tục quanh điểm hiện tại
    function [v_min, v_max] = getContinuousLimits(mask, val_array, current_val)
        [~, idx0] = min(abs(val_array - current_val));
        if ~mask(idx0)
            v_min = NaN; v_max = NaN; return;
        end
        
        % Tìm về bên phải (max)
        idx_max = idx0;
        while idx_max < length(mask) && mask(idx_max + 1)
            idx_max = idx_max + 1;
        end
        v_max = val_array(idx_max);
        
        % Tìm về bên trái (min)
        idx_min = idx0;
        while idx_min > 1 && mask(idx_min - 1)
            idx_min = idx_min - 1;
        end
        v_min = val_array(idx_min);
    end
end
