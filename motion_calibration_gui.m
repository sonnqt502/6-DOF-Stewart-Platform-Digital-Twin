function motion_calibration_gui()
% =========================================================================
% motion_calibration_gui.m
% Tính cánh tay đòn (rx,rz) từ Pitch hoặc (ry,rz) từ Roll
%
% Cấu trúc file 15 tham số (Dashboard_Stewart3):
%   col1  = time (s)
%   col2  = X (mm),  col3 = Y (mm),  col4 = Z (mm)
%   col5  = Yaw (°), col6 = Pitch (°), col7 = Roll (°)
%   col8  = ax_i (m/s²), col9 = ay_i, col10 = az_i   ← gia tốc quán tính body
%   col11 = axg (m/s²),  col12 = ayg, col13 = azg     ← hình chiếu trọng lực
%   col14 = wz (rad/s),  col15 = wy,  col16 = wx      ← vận tốc góc body
%
% Phương trình vật lý ĐẦY ĐỦ (có centripetal term):
%   PITCH (quay quanh Y):
%     delta_ax =  alpha_y * rz  -  wy² * rx
%     delta_az = -alpha_y * rx  -  wy² * rz
%   ROLL (quay quanh X):
%     delta_ay =  -alpha_x * rz  -  wx² * ry
%     delta_az = alpha_x * ry  -  wx² * rz
% =========================================================================

    fig = uifigure('Name', 'Motion Calibration Tool (Pitch / Roll)', ...
                   'Position', [300 100 700 720], 'Resize', 'off');

    % ── Tiêu đề ──────────────────────────────────────────────────────────
    uilabel(fig, 'Text', 'MOTION CALIBRATION TOOL', ...
        'Position', [0 675 700 30], 'HorizontalAlignment', 'center', ...
        'FontSize', 16, 'FontWeight', 'bold', 'FontColor', [0.1 0.35 0.65]);

    % ── Chọn file HEAD ────────────────────────────────────────────────────
    uilabel(fig, 'Text', 'HEAD File:', ...
        'Position', [20 635 85 22], 'HorizontalAlignment', 'right', 'FontWeight', 'bold');
    txtHead = uieditfield(fig, 'text', 'Editable', 'off', ...
        'Position', [115 635 420 22], 'BackgroundColor', [0.97 0.97 0.97]);
    uibutton(fig, 'push', 'Text', 'Browse...', ...
        'Position', [545 635 110 22], ...
        'ButtonPushedFcn', @(~,~) selectFile('head'));

    % ── Chọn file PIVOT ───────────────────────────────────────────────────
    uilabel(fig, 'Text', 'PIVOT File:', ...
        'Position', [20 600 85 22], 'HorizontalAlignment', 'right', 'FontWeight', 'bold');
    txtPivot = uieditfield(fig, 'text', 'Editable', 'off', ...
        'Position', [115 600 420 22], 'BackgroundColor', [0.97 0.97 0.97]);
    uibutton(fig, 'push', 'Text', 'Browse...', ...
        'Position', [545 600 110 22], ...
        'ButtonPushedFcn', @(~,~) selectFile('pivot'));

    % ── Panel Trim thời gian ──────────────────────────────────────────────
    pnlTrim = uipanel(fig, 'Title', 'Time Trimming (giây)', ...
        'Position', [20 490 660 100], 'FontWeight', 'bold', 'FontSize', 11);

    % Tiêu đề cột
    uilabel(pnlTrim, 'Text', 'Cắt đầu (s):', ...
        'Position', [120 55 95 18], 'HorizontalAlignment', 'center', 'FontWeight', 'bold');
    uilabel(pnlTrim, 'Text', 'Cắt cuối (s):', ...
        'Position', [240 55 95 18], 'HorizontalAlignment', 'center', 'FontWeight', 'bold');
    uilabel(pnlTrim, 'Text', 'Thông tin file:', ...
        'Position', [365 55 280 18], 'HorizontalAlignment', 'left', 'FontWeight', 'bold');

    % HEAD trim controls
    uilabel(pnlTrim, 'Text', 'HEAD:', ...
        'Position', [15 30 80 22], 'HorizontalAlignment', 'right', 'FontWeight', 'bold', ...
        'FontColor', [0.15 0.45 0.75]);
    efHeadTrimStart = uieditfield(pnlTrim, 'numeric', 'Value', 0, ...
        'Position', [105 30 100 22], 'Limits', [0 Inf], ...
        'ValueChangedFcn', @(~,~) updateTrimInfo());
    efHeadTrimEnd = uieditfield(pnlTrim, 'numeric', 'Value', 0, ...
        'Position', [230 30 100 22], 'Limits', [0 Inf], ...
        'ValueChangedFcn', @(~,~) updateTrimInfo());
    lblHeadInfo = uilabel(pnlTrim, 'Text', 'Chưa load file', ...
        'Position', [355 30 290 22], 'FontColor', [0.5 0.5 0.5], 'FontSize', 10);

    % PIVOT trim controls
    uilabel(pnlTrim, 'Text', 'PIVOT:', ...
        'Position', [15 5 80 22], 'HorizontalAlignment', 'right', 'FontWeight', 'bold', ...
        'FontColor', [0.75 0.2 0.1]);
    efPivotTrimStart = uieditfield(pnlTrim, 'numeric', 'Value', 0, ...
        'Position', [105 5 100 22], 'Limits', [0 Inf], ...
        'ValueChangedFcn', @(~,~) updateTrimInfo());
    efPivotTrimEnd = uieditfield(pnlTrim, 'numeric', 'Value', 0, ...
        'Position', [230 5 100 22], 'Limits', [0 Inf], ...
        'ValueChangedFcn', @(~,~) updateTrimInfo());
    lblPivotInfo = uilabel(pnlTrim, 'Text', 'Chưa load file', ...
        'Position', [355 5 290 22], 'FontColor', [0.5 0.5 0.5], 'FontSize', 10);

    % ── Motion type ───────────────────────────────────────────────────────
    uilabel(fig, 'Text', 'Motion Type:', ...
        'Position', [20 455 85 22], 'HorizontalAlignment', 'right', 'FontWeight', 'bold');
    ddMotion = uidropdown(fig, 'Items', {'Pitch (quay quanh Y)', 'Roll (quay quanh X)'}, ...
        'Value', 'Pitch (quay quanh Y)', 'Position', [115 455 180 22]);

    % ── Tần số lọc ────────────────────────────────────────────────────────
    uilabel(fig, 'Text', 'Filter cutoff (Hz):', ...
        'Position', [310 455 115 22], 'HorizontalAlignment', 'right');
    efFc = uieditfield(fig, 'numeric', 'Value', 3.0, ...
        'Position', [435 455 60 22], 'Limits', [0.1 25]);
    uilabel(fig, 'Text', '(≈ 3× f_motion)', ...
        'Position', [505 455 150 22], 'FontColor', [0.5 0.5 0.5]);

    % ── Nút Run ───────────────────────────────────────────────────────────
    uibutton(fig, 'push', 'Text', '▶  Run Calculation', ...
        'Position', [245 410 200 34], ...
        'FontSize', 13, 'FontWeight', 'bold', ...
        'BackgroundColor', [0.18 0.60 0.25], 'FontColor', 'white', ...
        'ButtonPushedFcn', @(~,~) runCalculation());

    % ── Panel kết quả ─────────────────────────────────────────────────────
    pnl = uipanel(fig, 'Title', 'Results', ...
        'Position', [20 30 660 365], 'FontWeight', 'bold', 'FontSize', 12);

    % --- Thông tin tín hiệu ---
    uilabel(pnl, 'Text', 'Dominant frequency:', ...
        'Position', [15 310 145 22], 'HorizontalAlignment', 'right');
    lblFreq = uilabel(pnl, 'Text', '--', ...
        'Position', [165 310 200 22], 'FontWeight', 'bold');

    uilabel(pnl, 'Text', 'ω amplitude (rad/s):', ...
        'Position', [15 280 145 22], 'HorizontalAlignment', 'right');
    lblOmega = uilabel(pnl, 'Text', '--', ...
        'Position', [165 280 200 22], 'FontWeight', 'bold');

    uilabel(pnl, 'Text', 'α amplitude (rad/s²):', ...
        'Position', [15 250 145 22], 'HorizontalAlignment', 'right');
    lblAlpha = uilabel(pnl, 'Text', '--', ...
        'Position', [165 250 200 22], 'FontWeight', 'bold');

    uilabel(pnl, 'Text', 'Centripetal / Euler ratio:', ...
        'Position', [15 220 145 22], 'HorizontalAlignment', 'right');
    lblRatio = uilabel(pnl, 'Text', '--', ...
        'Position', [165 220 350 22], 'FontWeight', 'bold');

    % --- Thông tin sau khi trim ---
    uilabel(pnl, 'Text', 'Dữ liệu sau trim:', ...
        'Position', [15 190 145 22], 'HorizontalAlignment', 'right');
    lblTrimInfo = uilabel(pnl, 'Text', '--', ...
        'Position', [165 190 430 22], 'FontColor', [0.3 0.55 0.3]);

    % Separator
    uilabel(pnl, 'Text', '────────────────────────────────────────────────────────────────────', ...
        'Position', [15 172 630 18], 'FontColor', [0.7 0.7 0.7]);

    % --- Kết quả lever arm ---
    uilabel(pnl, 'Text', 'rz (mm):', ...
        'Position', [15 140 80 22], 'HorizontalAlignment', 'right', ...
        'FontSize', 13, 'FontWeight', 'bold');
    lblRz = uilabel(pnl, 'Text', '--', ...
        'Position', [100 140 150 22], 'FontSize', 14, 'FontWeight', 'bold', ...
        'FontColor', [0.1 0.35 0.65]);

    uilabel(pnl, 'Text', 'rx (mm):', ...
        'Position', [15 105 80 22], 'HorizontalAlignment', 'right', 'FontSize', 13);
    lblRx = uilabel(pnl, 'Text', '--', ...
        'Position', [100 105 200 22], 'FontSize', 13);

    uilabel(pnl, 'Text', 'ry (mm):', ...
        'Position', [340 105 80 22], 'HorizontalAlignment', 'right', 'FontSize', 13);
    lblRy = uilabel(pnl, 'Text', '--', ...
        'Position', [425 105 200 22], 'FontSize', 13);

    % --- Chất lượng fit ---
    uilabel(pnl, 'Text', 'RMSE:', ...
        'Position', [15 65 80 22], 'HorizontalAlignment', 'right');
    lblRmse = uilabel(pnl, 'Text', '--', ...
        'Position', [100 65 200 22]);

    uilabel(pnl, 'Text', 'Relative error:', ...
        'Position', [340 65 100 22], 'HorizontalAlignment', 'right');
    lblRelErr = uilabel(pnl, 'Text', '--', ...
        'Position', [445 65 150 22]);

    % --- Nút Plot thêm ---
    uibutton(pnl, 'push', 'Text', '📊 Plot Trim Preview', ...
        'Position', [15 25 160 28], ...
        'FontSize', 10, 'FontWeight', 'bold', ...
        'BackgroundColor', [0.15 0.45 0.75], 'FontColor', 'white', ...
        'ButtonPushedFcn', @(~,~) plotTrimPreview());

    % ── AppData ───────────────────────────────────────────────────────────
    setappdata(fig, 'appData', struct('headFile',[], 'pivotFile',[], ...
                                     'headData',[], 'pivotData',[]));

    % =====================================================================
    % updateTrimInfo — cập nhật nhãn thông tin sau khi thay đổi trim
    % =====================================================================
    function updateTrimInfo()
        app = getappdata(fig, 'appData');

        % HEAD
        if ~isempty(app.headData)
            t_h = app.headData(:,1);
            dur_h = t_h(end) - t_h(1);
            ts_h  = efHeadTrimStart.Value;
            te_h  = efHeadTrimEnd.Value;
            remain_h = dur_h - ts_h - te_h;
            if remain_h > 0
                lblHeadInfo.Text = sprintf('Tổng: %.2fs  →  Còn lại: %.2fs', dur_h, remain_h);
                if remain_h < 1
                    lblHeadInfo.FontColor = [0.8 0.2 0.1];
                else
                    lblHeadInfo.FontColor = [0.1 0.5 0.1];
                end
            else
                lblHeadInfo.Text = 'CẢNH BÁO: Cắt quá nhiều!';
                lblHeadInfo.FontColor = [0.8 0.1 0.1];
            end
        end

        % PIVOT
        if ~isempty(app.pivotData)
            t_p = app.pivotData(:,1);
            dur_p = t_p(end) - t_p(1);
            ts_p  = efPivotTrimStart.Value;
            te_p  = efPivotTrimEnd.Value;
            remain_p = dur_p - ts_p - te_p;
            if remain_p > 0
                lblPivotInfo.Text = sprintf('Tổng: %.2fs  →  Còn lại: %.2fs', dur_p, remain_p);
                if remain_p < 1
                    lblPivotInfo.FontColor = [0.8 0.2 0.1];
                else
                    lblPivotInfo.FontColor = [0.1 0.5 0.1];
                end
            else
                lblPivotInfo.Text = 'CẢNH BÁO: Cắt quá nhiều!';
                lblPivotInfo.FontColor = [0.8 0.1 0.1];
            end
        end
    end

    % =====================================================================
    % applyTrim — cắt dữ liệu theo thời gian
    % =====================================================================
    function dataTrimmed = applyTrim(data, trimStart, trimEnd)
        t = data(:,1);
        t_begin  = t(1) + trimStart;
        t_finish = t(end) - trimEnd;
        if t_begin >= t_finish
            error('Thời gian trim vượt quá độ dài file! Kiểm tra lại giá trị cắt đầu/cuối.');
        end
        mask = (t >= t_begin) & (t <= t_finish);
        dataTrimmed = data(mask, :);
        % Tịnh tiến gốc thời gian: t_new = t_old - t_begin
        % Ví dụ: t=3s, trimStart=1s → t_begin=t(1)+1, t_new = 3 - t_begin
        dataTrimmed(:,1) = dataTrimmed(:,1) - t_begin;
        if size(dataTrimmed, 1) < 20
            error('Sau khi trim chỉ còn %d mẫu — quá ít để tính toán.', size(dataTrimmed, 1));
        end
    end

    % =====================================================================
    % plotTrimPreview — xem trước vùng dữ liệu sau trim
    % =====================================================================
    function plotTrimPreview()
        app = getappdata(fig, 'appData');
        if isempty(app.headData) && isempty(app.pivotData)
            uialert(fig, 'Chưa load file nào.', 'Thiếu dữ liệu');
            return;
        end

        hFig = figure('Name', 'Trim Preview', 'NumberTitle', 'off', ...
                      'Position', [100 100 1000 550]);

        nPlots = (~isempty(app.headData)) + (~isempty(app.pivotData));
        plotIdx = 1;

        if ~isempty(app.headData)
            ax = subplot(nPlots, 1, plotIdx); plotIdx = plotIdx + 1;
            t_h = app.headData(:,1);
            az_h = app.headData(:,10);
            plot(t_h, az_h, 'Color', [0.7 0.7 0.7], 'LineWidth', 0.8);
            hold on;

            ts_h = efHeadTrimStart.Value;
            te_h = efHeadTrimEnd.Value;
            t_keep_start = t_h(1) + ts_h;
            t_keep_end   = t_h(end) - te_h;

            mask_h = (t_h >= t_keep_start) & (t_h <= t_keep_end);
            plot(t_h(mask_h), az_h(mask_h), 'b', 'LineWidth', 1.5);
            
            % --- Ép biên độ tối thiểu 5 cho HEAD az ---
            max_az_head = max(abs(az_h(mask_h)));
            if max_az_head < 5
                ylim([-5, 5]);
            end
            % -----------------------------------------

            % Vẽ vùng bị cắt (xanh đỏ)
            yL = ylim;
            if ts_h > 0
                xpatch = [t_h(1), t_keep_start, t_keep_start, t_h(1)];
                ypatch = [yL(1), yL(1), yL(2), yL(2)];
                fill(xpatch, ypatch, [1 0.6 0.6], 'EdgeColor','none', 'FaceAlpha', 0.35);
                xline(t_keep_start, 'r--', 'LineWidth', 1.5);
                text(t_h(1) + ts_h/2, yL(2)*0.85, sprintf('Cắt: %.2fs', ts_h), ...
                    'HorizontalAlignment','center','Color','r','FontSize',9);
            end
            if te_h > 0
                xpatch2 = [t_keep_end, t_h(end), t_h(end), t_keep_end];
                ypatch2 = [yL(1), yL(1), yL(2), yL(2)];
                fill(xpatch2, ypatch2, [1 0.6 0.6], 'EdgeColor','none', 'FaceAlpha', 0.35);
                xline(t_keep_end, 'r--', 'LineWidth', 1.5);
                text(t_keep_end + te_h/2, yL(2)*0.85, sprintf('Cắt: %.2fs', te_h), ...
                    'HorizontalAlignment','center','Color','r','FontSize',9);
            end

            ylabel('az HEAD (m/s²)');
            title(sprintf('HEAD — az  |  Giữ lại: %.2fs – %.2fs  (%.2fs)', ...
                  t_keep_start, t_keep_end, t_keep_end - t_keep_start));
            grid on;
            legend({'Bị cắt', 'Giữ lại'}, 'Location', 'best');
        end

        if ~isempty(app.pivotData)
            ax2 = subplot(nPlots, 1, plotIdx);
            t_p = app.pivotData(:,1);
            az_p = app.pivotData(:,10);
            plot(t_p, az_p, 'Color', [0.7 0.7 0.7], 'LineWidth', 0.8);
            hold on;

            ts_p = efPivotTrimStart.Value;
            te_p = efPivotTrimEnd.Value;
            t_keep_start_p = t_p(1) + ts_p;
            t_keep_end_p   = t_p(end) - te_p;

            mask_p = (t_p >= t_keep_start_p) & (t_p <= t_keep_end_p);
            plot(t_p(mask_p), az_p(mask_p), 'Color', [0.8 0.3 0.1], 'LineWidth', 1.5);
            
            % --- Ép biên độ tối thiểu 5 cho PIVOT az ---
            max_az_pivot = max(abs(az_p(mask_p)));
            if max_az_pivot < 5
                ylim([-5, 5]);
            end
            % -----------------------------------------

            yL2 = ylim;
            if ts_p > 0
                xpatch3 = [t_p(1), t_keep_start_p, t_keep_start_p, t_p(1)];
                ypatch3 = [yL2(1), yL2(1), yL2(2), yL2(2)];
                fill(xpatch3, ypatch3, [1 0.6 0.6], 'EdgeColor','none', 'FaceAlpha', 0.35);
                xline(t_keep_start_p, 'r--', 'LineWidth', 1.5);
                text(t_p(1) + ts_p/2, yL2(2)*0.85, sprintf('Cắt: %.2fs', ts_p), ...
                    'HorizontalAlignment','center','Color','r','FontSize',9);
            end
            if te_p > 0
                xpatch4 = [t_keep_end_p, t_p(end), t_p(end), t_keep_end_p];
                ypatch4 = [yL2(1), yL2(1), yL2(2), yL2(2)];
                fill(xpatch4, ypatch4, [1 0.6 0.6], 'EdgeColor','none', 'FaceAlpha', 0.35);
                xline(t_keep_end_p, 'r--', 'LineWidth', 1.5);
                text(t_keep_end_p + te_p/2, yL2(2)*0.85, sprintf('Cắt: %.2fs', te_p), ...
                    'HorizontalAlignment','center','Color','r','FontSize',9);
            end

            ylabel('az PIVOT (m/s²)');
            title(sprintf('PIVOT — az  |  Giữ lại: %.2fs – %.2fs  (%.2fs)', ...
                  t_keep_start_p, t_keep_end_p, t_keep_end_p - t_keep_start_p));
            grid on;
            legend({'Bị cắt', 'Giữ lại'}, 'Location', 'best');
        end

        sgtitle('Trim Preview — vùng đỏ sẽ bị loại, vùng màu sẽ được dùng tính toán', ...
                'FontWeight', 'bold', 'FontSize', 11);
        xlabel('Time (s)');
    end

    % =====================================================================
    % selectFile
    % =====================================================================
    function selectFile(which)
        [fname, fpath] = uigetfile({'*.csv;*.txt','Data files (*.csv,*.txt)'}, ...
                                   ['Select ' upper(which) ' file']);
        if isequal(fname, 0), return; end
        fullPath = fullfile(fpath, fname);
        app = getappdata(fig, 'appData');
        try
            data = parseMoogFile(fullPath);
            if isempty(data)
                uialert(fig, 'File contains no numeric data.', 'Read Error'); return;
            end
            if size(data,2) < 16
                uialert(fig, sprintf('File has %d columns — need at least 16.', size(data,2)), ...
                    'Format Error'); return;
            end
            switch which
                case 'head'
                    app.headData = data; app.headFile = fullPath;
                    txtHead.Value = fname;
                case 'pivot'
                    app.pivotData = data; app.pivotFile = fullPath;
                    txtPivot.Value = fname;
            end
            setappdata(fig, 'appData', app);
            % Cập nhật thông tin trim ngay sau khi load file
            updateTrimInfo();
        catch ME
            uialert(fig, ['Error reading file: ' ME.message], 'Read Error');
        end
    end

    % =====================================================================
    % runCalculation
    % =====================================================================
    function runCalculation()
        app = getappdata(fig, 'appData');
        if isempty(app.headData) || isempty(app.pivotData)
            uialert(fig, 'Please select both HEAD and PIVOT files first.', 'Missing Data');
            return;
        end

        motionStr = ddMotion.Value;
        isPitch   = startsWith(motionStr, 'Pitch');
        fc_user   = efFc.Value;

        % ------------------------------------------------------------------
        % 0. ÁP DỤNG TRIM THỜI GIAN
        % ------------------------------------------------------------------
        try
            headData  = applyTrim(app.headData,  efHeadTrimStart.Value,  efHeadTrimEnd.Value);
            pivotData = applyTrim(app.pivotData, efPivotTrimStart.Value, efPivotTrimEnd.Value);
        catch ME
            uialert(fig, ME.message, 'Trim Error');
            return;
        end

        % Hiển thị thông tin trim
        t_h_orig  = app.headData(:,1);
        t_p_orig  = app.pivotData(:,1);
        t_h_trim  = headData(:,1);
        t_p_trim  = pivotData(:,1);
        lblTrimInfo.Text = sprintf(...
            'HEAD: %.2fs→%.2fs (%.2fs)  |  PIVOT: %.2fs→%.2fs (%.2fs)', ...
            t_h_trim(1), t_h_trim(end), t_h_trim(end)-t_h_trim(1), ...
            t_p_trim(1), t_p_trim(end), t_p_trim(end)-t_p_trim(1));

        % ------------------------------------------------------------------
        % 1. ĐỌC ĐÚNG CỘT từ dữ liệu đã trim
        % ------------------------------------------------------------------
        t_h  = headData(:,1);
        ax_h = headData(:,8);
        ay_h = -headData(:,9);   % Lưu ý dấu trừ để đúng chiều
        az_h = headData(:,10);
        wy_h = headData(:,15);
        wx_h = headData(:,16);

        t_p  = pivotData(:,1);
        ax_p = pivotData(:,8);
        ay_p = pivotData(:,9);
        az_p = pivotData(:,10);
        wy_p = pivotData(:,15);
        wx_p = pivotData(:,16);

        % ------------------------------------------------------------------
        % 2. ĐỒNG BỘ THỜI GIAN VÀ NỘI SUY
        % ------------------------------------------------------------------
        dt = min(mean(diff(t_h)), mean(diff(t_p)));
        t_start = max(t_h(1), t_p(1));
        t_end   = min(t_h(end), t_p(end));
        t = (t_start : dt : t_end)';
        N = length(t);

        if N < 20
            uialert(fig, 'Insufficient overlapping time points (< 20) after trim.', 'Time Error');
            return;
        end

        I = @(tv,xv) interp1(tv, xv, t, 'linear', 'extrap');

        ax_h_i = I(t_h, ax_h); ay_h_i = I(t_h, ay_h); az_h_i = I(t_h, az_h);
        ax_p_i = I(t_p, ax_p); ay_p_i = I(t_p, ay_p); az_p_i = I(t_p, az_p);

        if isPitch
            gyro_h_raw = I(t_h, wy_h);
            gyro_p_raw = I(t_p, wy_p);
        else
            gyro_h_raw = I(t_h, wx_h);
            gyro_p_raw = I(t_p, wx_p);
        end

        % ------------------------------------------------------------------
        % 3. LỌC BUTTERWORTH (bậc 4, zero-phase)
        % ------------------------------------------------------------------
        fs  = 1 / dt;
        Wn  = min(fc_user / (fs/2), 0.99);
        [bf, af] = butter(4, Wn, 'low');

        ax_h_f = filtfilt(bf, af, ax_h_i);
        ay_h_f = filtfilt(bf, af, ay_h_i);
        az_h_f = filtfilt(bf, af, az_h_i);
        ax_p_f = filtfilt(bf, af, ax_p_i);
        ay_p_f = filtfilt(bf, af, ay_p_i);
        az_p_f = filtfilt(bf, af, az_p_i);
        gyro_h = filtfilt(bf, af, gyro_h_raw);
        gyro_p = filtfilt(bf, af, gyro_p_raw);

        dax = ax_h_f - ax_p_f;
        day = ay_h_f - ay_p_f;
        daz = az_h_f - az_p_f;

        % ------------------------------------------------------------------
        % 4. GIA TỐC GÓC
        % ------------------------------------------------------------------
        alpha_h = filtfilt(bf, af, gradient(gyro_h, t));
        alpha_p = filtfilt(bf, af, gradient(gyro_p, t));
        alpha   = alpha_h;

        % ------------------------------------------------------------------
        % 5. THỐNG KÊ TÍN HIỆU
        % ------------------------------------------------------------------
        omega_amp = max(abs(gyro_h));
        alpha_amp = max(abs(alpha));

        zc = find(diff(sign(gyro_h - mean(gyro_h))));
        f_dom = 0;
        if length(zc) >= 2
            f_dom = fs / (2 * mean(diff(zc)));
        end

        if alpha_amp > 1e-8
            centripetal_ratio = (omega_amp^2) / alpha_amp;
        else
            centripetal_ratio = Inf;
        end

        % ------------------------------------------------------------------
        % 5b. VẼ ĐỒ THỊ GIA TỐC DÀI (đã ép biên độ az)
        % ------------------------------------------------------------------
        plotAccelerations(t, ay_h_f, az_h_f, ay_p_f, az_p_f);

        % ------------------------------------------------------------------
        % 5c. VẼ SO SÁNH VẬN TỐC GÓC & GIA TỐC GÓC
        % ------------------------------------------------------------------
        plotGyroComparison(t, gyro_h, gyro_p, alpha_h, alpha_p, isPitch);

        % ------------------------------------------------------------------
        % 6. XÂY DỰNG HỆ PHƯƠNG TRÌNH LEAST SQUARES
        % ------------------------------------------------------------------
        A_mat = zeros(2*N, 2);
        B_vec = zeros(2*N, 1);

        for k = 1:N
            al = alpha(k);
            w2 = gyro_h(k)^2;

            if isPitch
                A_mat(2*k-1, :) = [ al, -w2];
                A_mat(2*k,   :) = [-w2, -al];
                B_vec(2*k-1)    = dax(k);
                B_vec(2*k)      = daz(k);
            else
                A_mat(2*k-1, :) = [-al, -w2];
                A_mat(2*k,   :) = [-w2,  al];
                B_vec(2*k-1)    = day(k);
                B_vec(2*k)      = daz(k);
            end
        end

        % ------------------------------------------------------------------
        % 7. LỌC MẪU
        % ------------------------------------------------------------------
        a_norm = repelem(abs(alpha), 2);
        thr    = prctile(a_norm, 30);
        valid  = a_norm > thr;

        A_f_ls = A_mat(valid, :);
        B_f_ls = B_vec(valid);

        n_valid = sum(valid) / 2;
        fprintf('Số mẫu hợp lệ: %d / %d (%.0f%%)\n', n_valid, N, 100*n_valid/N);

        if rank(A_f_ls) < 2
            uialert(fig, 'Ma trận A suy biến — chuyển động không đủ kích thích.', 'Rank Error');
            return;
        end

        % ------------------------------------------------------------------
        % 8. GIẢI BÌNH PHƯƠNG TỐI THIỂU
        % ------------------------------------------------------------------
        r_sol = A_f_ls \ B_f_ls;
        rz_m  = r_sol(1);
        r2_m  = r_sol(2);

        rz_mm = rz_m * 1000;
        r2_mm = r2_m * 1000;

        % ------------------------------------------------------------------
        % 9. ĐÁNH GIÁ CHẤT LƯỢNG FIT
        % ------------------------------------------------------------------
        residual = B_f_ls - A_f_ls * r_sol;
        rmse     = sqrt(mean(residual.^2));
        rel_err  = rmse / (norm(r_sol) + 1e-12) * 100;

        % ------------------------------------------------------------------
        % 10. CẬP NHẬT GUI
        % ------------------------------------------------------------------
        lblFreq.Text  = sprintf('%.4f Hz', f_dom);
        lblOmega.Text = sprintf('%.5f rad/s', omega_amp);
        lblAlpha.Text = sprintf('%.5f rad/s²', alpha_amp);
        lblRatio.Text = sprintf('%.4f  (%s)', centripetal_ratio, ...
            ternary(centripetal_ratio > 0.05, '⚠ Đáng kể — centripetal được tính vào', 'Nhỏ, ổn'));

        lblRz.Text = sprintf('%.3f mm', rz_mm);
        lblRmse.Text   = sprintf('%.6f m/s²', rmse);

        color_err = ternary(rel_err < 5, [0.1 0.5 0.1], [0.7 0.2 0.1]);

        if isPitch
            lblRx.Text = sprintf('%.3f mm', r2_mm);
            lblRy.Text = 'N/A (Pitch)';
            lblRelErr.Text = sprintf('%.2f%%', rel_err);
            lblRelErr.FontColor = color_err;
            fprintf('\n========== PITCH ==========\n');
            fprintf('f ≈ %.4f Hz\n', f_dom);
            fprintf('ω_max = %.5f rad/s,  α_max = %.5f rad/s²\n', omega_amp, alpha_amp);
            fprintf('Centripetal ratio = %.4f\n', centripetal_ratio);
            fprintf('HEAD trim: cắt đầu=%.2fs, cắt cuối=%.2fs\n', efHeadTrimStart.Value, efHeadTrimEnd.Value);
            fprintf('PIVOT trim: cắt đầu=%.2fs, cắt cuối=%.2fs\n', efPivotTrimStart.Value, efPivotTrimEnd.Value);
            fprintf('rz = %.3f mm\n', rz_mm);
            fprintf('rx = %.3f mm\n', r2_mm);
            fprintf('|r| = %.3f mm\n', norm([r2_mm, rz_mm]));
            fprintf('RMSE = %.6f m/s²,  Sai số tương đối = %.2f%%\n', rmse, rel_err);
        else
            lblRx.Text = 'N/A (Roll)';
            lblRy.Text = sprintf('%.3f mm', r2_mm);
            lblRelErr.Text = sprintf('%.2f%%', rel_err);
            lblRelErr.FontColor = color_err;
            fprintf('\n========== ROLL ==========\n');
            fprintf('f ≈ %.4f Hz\n', f_dom);
            fprintf('ω_max = %.5f rad/s,  α_max = %.5f rad/s²\n', omega_amp, alpha_amp);
            fprintf('Centripetal ratio = %.4f\n', centripetal_ratio);
            fprintf('HEAD trim: cắt đầu=%.2fs, cắt cuối=%.2fs\n', efHeadTrimStart.Value, efHeadTrimEnd.Value);
            fprintf('PIVOT trim: cắt đầu=%.2fs, cắt cuối=%.2fs\n', efPivotTrimStart.Value, efPivotTrimEnd.Value);
            fprintf('rz = %.3f mm\n', rz_mm);
            fprintf('ry = %.3f mm\n', r2_mm);
            fprintf('|r| = %.3f mm\n', norm([r2_mm, rz_mm]));
            fprintf('RMSE = %.6f m/s²,  Sai số tương đối = %.2f%%\n', rmse, rel_err);
        end
        fprintf('============================\n');

        % ------------------------------------------------------------------
        % 11. VẼ ĐỒ THỊ KIỂM TRA FIT
        % ------------------------------------------------------------------
        plotResiduals(t, alpha, gyro_h, B_vec, A_mat, r_sol, isPitch, valid);
    end

    % =====================================================================
    % plotAccelerations (đã sửa ép biên độ az ≥ 5)
    % =====================================================================
    function plotAccelerations(t, ay_h, az_h, ay_p, az_p)
        figure('Name', 'Linear Acceleration Comparison', 'NumberTitle', 'off', ...
               'Position', [100 100 900 500]);

        subplot(2,1,1);
        plot(t, ay_h, 'b', 'LineWidth', 1.2); hold on;
        plot(t, ay_p, 'r--', 'LineWidth', 1.2);
        ylabel('ay (m/s²)'); grid on;
        legend('Head ay', 'Pivot ay', 'Location','best');
        title('Gia tốc dài theo trục Y');

        subplot(2,1,2);
        plot(t, az_h, 'b', 'LineWidth', 1.2); hold on;
        plot(t, az_p, 'r--', 'LineWidth', 1.2);
        ylabel('az (m/s²)'); grid on;
        legend('Head az', 'Pivot az', 'Location','best');
        title('Gia tốc dài theo trục Z');
        xlabel('Time (s)');
        
        % --- Đảm bảo biên độ tối thiểu 5 ---
        max_az = max(abs([az_h; az_p]));
        if max_az < 5
            ylim([-5, 5]);
        end
        % -----------------------------------
        
        sgtitle('So sánh gia tốc dài Head vs Pivot (đã lọc, đã trim)', 'FontWeight','bold', 'FontSize',12);
    end

    % =====================================================================
    % plotGyroComparison
    % =====================================================================
    function plotGyroComparison(t, gyro_h, gyro_p, alpha_h, alpha_p, isPitch)
        figure('Name', 'Gyroscope & Angular Acceleration Comparison', 'NumberTitle', 'off', ...
               'Position', [150 150 900 600]);

        subplot(2,1,1);
        plot(t, gyro_h, 'b', 'LineWidth', 1.2); hold on;
        plot(t, gyro_p, 'r--', 'LineWidth', 1.2);
        ylabel('ω (rad/s)'); grid on;
        legend('Head ω', 'Pivot ω', 'Location','best');
        if isPitch
            title('Vận tốc góc ω_y');
        else
            title('Vận tốc góc ω_x');
        end

        subplot(2,1,2);
        plot(t, alpha_h, 'b', 'LineWidth', 1.2); hold on;
        plot(t, alpha_p, 'r--', 'LineWidth', 1.2);
        ylabel('α (rad/s²)'); grid on;
        legend('Head α', 'Pivot α', 'Location','best');
        if isPitch
            title('Gia tốc góc α_y');
        else
            title('Gia tốc góc α_x');
        end
        xlabel('Time (s)');
        sgtitle('So sánh vận tốc góc & gia tốc góc Head vs Pivot (đã trim)', 'FontWeight','bold', 'FontSize',12);
    end

    % =====================================================================
    % plotResiduals
    % =====================================================================
    function plotResiduals(t, alpha, gyro, B_vec, A_mat, r_sol, isPitch, valid)
        N = length(t);
        B_est = A_mat * r_sol;

        B_meas_ax = B_vec(1:2:end);
        B_meas_az = B_vec(2:2:end);
        B_est_ax  = B_est(1:2:end);
        B_est_az  = B_est(2:2:end);

        valid_t = valid(1:2:end);

        figure('Name','Calibration Residuals','NumberTitle','off', ...
               'Position',[100 100 900 600]);

        ax1 = subplot(3,1,1);
        plot(t, B_meas_ax, 'b', 'LineWidth',1.2, 'DisplayName','Đo thực tế');
        hold on;
        plot(t, B_est_ax,  'r--', 'LineWidth',1.2, 'DisplayName','Ước lượng');
        yline(0,'k:');
        ylabel(ternary(isPitch,'Δax (m/s²)','Δay (m/s²)'), 'FontSize',10);
        legend('Location','best'); grid on; title('Kiểm tra fit — Trục 1');

        ax2 = subplot(3,1,2);
        plot(t, B_meas_az, 'b', 'LineWidth',1.2, 'DisplayName','Đo thực tế');
        hold on;
        plot(t, B_est_az,  'r--', 'LineWidth',1.2, 'DisplayName','Ước lượng');
        yline(0,'k:');
        ylabel('Δaz (m/s²)', 'FontSize',10);
        legend('Location','best'); grid on; title('Kiểm tra fit — Δaz');

        ax3 = subplot(3,1,3);
        yyaxis left;
        plot(t, alpha, 'k', 'LineWidth',1.2);
        ylabel('α (rad/s²)');
        yyaxis right;
        plot(t, gyro.^2, 'Color',[0.8 0.4 0], 'LineWidth',1.0);
        ylabel('ω² (rad²/s²)');
        hold on;
        yL = ylim;
        fill_t = t(~valid_t);
        if ~isempty(fill_t)
            for kk = 1:length(fill_t)
                xpatch = [fill_t(kk)-0.01, fill_t(kk)+0.01, fill_t(kk)+0.01, fill_t(kk)-0.01];
                ypatch = [yL(1), yL(1), yL(2), yL(2)];
                fill(xpatch, ypatch, [1 0.85 0.85], 'EdgeColor','none', 'FaceAlpha',0.3);
            end
        end
        xlabel('Time (s)'); grid on;
        title('Tín hiệu góc — vùng hồng = mẫu bị loại (α nhỏ)');

        linkaxes([ax1 ax2 ax3], 'x');
        sgtitle('Kiểm tra chất lượng fit — đỏ=ước lượng, xanh=đo', ...
                'FontWeight','bold', 'FontSize',12);
    end

end

% =========================================================================
% Hàm tiện ích
% =========================================================================
function out = ternary(cond, a, b)
    if cond, out = a; else, out = b; end
end

% =========================================================================
% parseMoogFile
% =========================================================================
function data = parseMoogFile(filename)
    fid = fopen(filename, 'r');
    if fid == -1, error('Cannot open file: %s', filename); end
    raw   = fread(fid, '*char')';
    fclose(fid);
    lines = strsplit(raw, newline);
    data  = [];
    pat   = '[-+]?\d*\.?\d+(?:[eE][-+]?\d+)?';
    for i = 1:length(lines)
        line = strtrim(lines{i});
        if isempty(line), continue; end
        nums = regexp(line, pat, 'match');
        if isempty(nums), continue; end
        row  = str2double(nums);
        row(isnan(row)) = [];
        if length(row) >= 15
            data = [data; row]; %#ok<AGROW>
        end
    end
end