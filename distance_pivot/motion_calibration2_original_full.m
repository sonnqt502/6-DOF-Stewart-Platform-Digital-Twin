function motion_calibration2()
    % TẠO GIAO DIỆN CHÍNH
    fig = uifigure('Name', 'Motion Calibration (Phase 1-3)', 'Position', [100 50 1200 850], 'Scrollable', 'on');
    movegui(fig, 'center');
    
    % Biến dữ liệu dùng chung
    appData = struct();
    appData.cT = 1; appData.cYaw = 5; appData.cPitch = 6; appData.cRoll = 7;
    appData.cAxi = 8; appData.cAyi = 9; appData.cAzi = 10;
    appData.cWz = 14; appData.cWy = 15; appData.cWx = 16;
    
    % Nút Save All Plots
    btnSavePlots = uibutton(fig, 'push', 'Text', '💾 Save All Plots', ...
        'Position', [1040, 810, 140, 30], 'FontWeight', 'bold', ...
        'BackgroundColor', [0.9 0.9 0.9], 'ButtonPushedFcn', @(~,~) saveAllPlots());
        
    % Tab Group (Hạ chiều cao xuống để không che mất nút Save)
    tg = uitabgroup(fig, 'Position', [10 10 1180 790]);
    
    tab1 = uitab(tg, 'Title', '1. Alignment');
    tab2 = uitab(tg, 'Title', '2. Derivative');
    tab3 = uitab(tg, 'Title', '3. Sync & Interp');
    tab4 = uitab(tg, 'Title', '4. Math Engine');
    tab5 = uitab(tg, 'Title', '5. Eval & Export');

    % =========================================================================
    % TAB 1: ALIGNMENT
    % =========================================================================
    uilabel(tab1, 'Text', 'Pivot File:', 'Position', [20 710 80 22], 'FontWeight','bold');
    txtPivot = uieditfield(tab1, 'text', 'Position', [100 710 300 22], 'Editable','off');
    btnPivot = uibutton(tab1, 'push', 'Text', 'Browse...', 'Position', [410 710 80 22], 'ButtonPushedFcn', @(~,~) browseFile('pivot', txtPivot));
    
    uilabel(tab1, 'Text', 'Head File:', 'Position', [520 710 80 22], 'FontWeight','bold');
    txtHead = uieditfield(tab1, 'text', 'Position', [600 710 300 22], 'Editable','off');
    btnHead = uibutton(tab1, 'push', 'Text', 'Browse...', 'Position', [910 710 80 22], 'ButtonPushedFcn', @(~,~) browseFile('head', txtHead));
    
    btnRun1 = uibutton(tab1, 'push', 'Text', '▶ Run Step 1 (Alignment)', 'Position', [20 670 200 30], 'BackgroundColor', [0.2 0.6 0.3], 'FontColor', 'w', 'FontWeight', 'bold', 'ButtonPushedFcn', @(~,~) runStep1());
    lblStatus1 = uilabel(tab1, 'Text', 'Hãy chọn file dữ liệu.', 'Position', [240 670 900 30], 'FontColor', [0.5 0.5 0.5]);
    
    ax1_w_raw = uiaxes(tab1, 'Position', [20 350 560 300]); title(ax1_w_raw, 'Vận tốc góc (Raw)'); grid(ax1_w_raw, 'on');
    ax1_w_align = uiaxes(tab1, 'Position', [600 350 560 300]); title(ax1_w_align, 'Vận tốc góc (Aligned)'); grid(ax1_w_align, 'on');
    ax1_a_raw = uiaxes(tab1, 'Position', [20 20 560 300]); title(ax1_a_raw, 'Gia tốc dài (Raw)'); grid(ax1_a_raw, 'on');
    ax1_a_align = uiaxes(tab1, 'Position', [600 20 560 300]); title(ax1_a_align, 'Gia tốc dài (Aligned)'); grid(ax1_a_align, 'on');

    % =========================================================================
    % TAB 2: DERIVATIVE
    % =========================================================================
    uilabel(tab2, 'Text', 'Vận tốc góc (Không lọc):', 'Position', [20 710 250 22], 'FontWeight','bold');
    btnRun2 = uibutton(tab2, 'push', 'Text', '▶ Run Step 2 (Derivative)', 'Position', [20 670 200 30], 'BackgroundColor', [0.2 0.6 0.3], 'FontColor', 'w', 'FontWeight', 'bold', 'ButtonPushedFcn', @(~,~) runStep2());
    lblStatus2 = uilabel(tab2, 'Text', 'Chưa chạy.', 'Position', [240 670 800 30], 'FontColor', [0.5 0.5 0.5]);
    
    ax2_w = uiaxes(tab2, 'Position', [20 350 1140 300]); title(ax2_w, 'Vận tốc góc: Pivot (Raw) vs Head (Raw)'); grid(ax2_w, 'on');
    ax2_a = uiaxes(tab2, 'Position', [20 20 1140 300]); title(ax2_a, 'Gia tốc góc (Alpha_x, Alpha_y) của Head'); grid(ax2_a, 'on');

    % =========================================================================
    % TAB 3: SYNC & INTERP
    % =========================================================================
    btnRun3 = uibutton(tab3, 'push', 'Text', '▶ Run Step 3 (Sync)', 'Position', [20 710 200 30], 'BackgroundColor', [0.2 0.6 0.3], 'FontColor', 'w', 'FontWeight', 'bold', 'ButtonPushedFcn', @(~,~) runStep3());
    lblStatus3 = uilabel(tab3, 'Text', 'Chưa chạy.', 'Position', [240 710 800 30], 'FontColor', [0.5 0.5 0.5]);
    
    ax3_w = uiaxes(tab3, 'Position', [20 360 1140 320]); title(ax3_w, 'Đồng bộ Vận tốc góc (wx, wy) chung lưới thời gian'); grid(ax3_w, 'on');
    ax3_ay = uiaxes(tab3, 'Position', [20 20 560 320]); title(ax3_ay, 'Đồng bộ Gia tốc dài (Ay)'); grid(ax3_ay, 'on');
    ax3_az = uiaxes(tab3, 'Position', [600 20 560 320]); title(ax3_az, 'Đồng bộ Gia tốc dài (Az)'); grid(ax3_az, 'on');

    % =========================================================================
    % TAB 4: MATH ENGINE
    % =========================================================================
    uilabel(tab4, 'Text', 'Trục phân tích:', 'Position', [20 710 100 22], 'FontWeight','bold');
    ddAxis = uidropdown(tab4, 'Items', {'Pitch (wy)', 'Roll (wx)'}, 'Position', [120 710 100 22]);
    
    btnRun4 = uibutton(tab4, 'push', 'Text', '▶ Run Step 4 (Math Engine)', 'Position', [240 710 200 30], 'BackgroundColor', [0.2 0.6 0.3], 'FontColor', 'w', 'FontWeight', 'bold', 'ButtonPushedFcn', @(~,~) runStep4());
    lblStatus4 = uilabel(tab4, 'Text', 'Chưa chạy.', 'Position', [460 710 700 30], 'FontColor', [0.5 0.5 0.5], 'FontSize', 14);
    
    ax4_1 = uiaxes(tab4, 'Position', [20 360 1140 320]); title(ax4_1, 'Residuals - Axis 1'); grid(ax4_1, 'on');
    ax4_2 = uiaxes(tab4, 'Position', [20 20 1140 320]); title(ax4_2, 'Residuals - Axis 2'); grid(ax4_2, 'on');

    % =========================================================================
    % TAB 5: EVALUATION & EXPORT
    % =========================================================================
    uilabel(tab5, 'Text', 'Vector r (mm):', 'Position', [20 710 100 22], 'FontWeight','bold');
    
    uilabel(tab5, 'Text', 'X:', 'Position', [120 710 20 22]);
    txtRx = uieditfield(tab5, 'numeric', 'Position', [140 710 60 22], 'Value', 0);
    
    uilabel(tab5, 'Text', 'Y:', 'Position', [210 710 20 22]);
    txtRy = uieditfield(tab5, 'numeric', 'Position', [230 710 60 22], 'Value', 0);
    
    uilabel(tab5, 'Text', 'Z:', 'Position', [300 710 20 22]);
    txtRz = uieditfield(tab5, 'numeric', 'Position', [320 710 60 22], 'Value', 0);
    
    btnRun5 = uibutton(tab5, 'push', 'Text', '▶ Run Phase 2+3 (Translate)', 'Position', [400 710 200 30], 'BackgroundColor', [0.2 0.4 0.8], 'FontColor', 'w', 'FontWeight', 'bold', 'ButtonPushedFcn', @(~,~) runStep5());
    btnExport = uibutton(tab5, 'push', 'Text', '💾 Export Simulated Head', 'Position', [620 710 180 30], 'BackgroundColor', [0.8 0.4 0.2], 'FontColor', 'w', 'FontWeight', 'bold', 'ButtonPushedFcn', @(~,~) exportHead());
    
    lblStatus5 = uilabel(tab5, 'Text', 'Chưa chạy.', 'Position', [820 710 300 30], 'FontColor', [0.5 0.5 0.5], 'FontSize', 12);
    
    ax5_1 = uiaxes(tab5, 'Position', [20 480 1140 200]); title(ax5_1, 'Đánh giá trục X (Ax)'); grid(ax5_1, 'on');
    ax5_2 = uiaxes(tab5, 'Position', [20 250 1140 200]); title(ax5_2, 'Đánh giá trục Y (Ay)'); grid(ax5_2, 'on');
    ax5_3 = uiaxes(tab5, 'Position', [20 20 1140 200]); title(ax5_3, 'Đánh giá trục Z (Az)'); grid(ax5_3, 'on');

    % =========================================================================
    % CALLBACKS
    % =========================================================================
    function browseFile(type, txtField)
        [fname, fpath] = uigetfile('*.csv', 'Select File');
        if isequal(fname,0), return; end
        txtField.Value = fullfile(fpath, fname);
        
        try
            data = parseMoogFile(txtField.Value);
            appData.(type) = data;
            
            % Tự động plot Raw nếu đã có cả hai file
            if isfield(appData, 'head') && isfield(appData, 'pivot')
                plotRawData();
            end
        catch ME
            uialert(fig, ME.message, 'Lỗi đọc file');
        end
    end

    function plotRawData()
        t_p = appData.pivot(:, appData.cT);
        wx_p = appData.pivot(:, appData.cWx);
        wy_p = appData.pivot(:, appData.cWy);
        ax_p = appData.pivot(:, appData.cAxi);
        ay_p = appData.pivot(:, appData.cAyi);
        az_p = appData.pivot(:, appData.cAzi);
        
        t_h = appData.head(:, appData.cT);
        wx_h = appData.head(:, appData.cWx);
        wy_h = appData.head(:, appData.cWy);
        ax_h = appData.head(:, appData.cAxi);
        ay_h = appData.head(:, appData.cAyi);
        az_h = appData.head(:, appData.cAzi);
        
        cla(ax1_w_raw);
        plot(ax1_w_raw, t_p, wx_p, 'r--', 'LineWidth', 1, 'DisplayName', 'Pivot wx'); hold(ax1_w_raw, 'on');
        plot(ax1_w_raw, t_p, wy_p, 'm--', 'LineWidth', 1, 'DisplayName', 'Pivot wy');
        plot(ax1_w_raw, t_h, wx_h, 'b', 'LineWidth', 1.2, 'DisplayName', 'Head wx');
        plot(ax1_w_raw, t_h, wy_h, 'c', 'LineWidth', 1.2, 'DisplayName', 'Head wy'); hold(ax1_w_raw, 'off');
        legend(ax1_w_raw, 'Location', 'best');
        
        cla(ax1_a_raw);
        plot(ax1_a_raw, t_p, az_p, 'r--', 'LineWidth', 1, 'DisplayName', 'Pivot az'); hold(ax1_a_raw, 'on');
        plot(ax1_a_raw, t_h, az_h, 'b', 'LineWidth', 1.2, 'DisplayName', 'Head az');
        plot(ax1_a_raw, t_p, ay_p, 'm--', 'LineWidth', 1, 'DisplayName', 'Pivot ay');
        plot(ax1_a_raw, t_h, ay_h, 'c', 'LineWidth', 1.2, 'DisplayName', 'Head ay'); hold(ax1_a_raw, 'off');
        legend(ax1_a_raw, 'Location', 'best');
        
        lblStatus1.Text = 'Đã nạp 2 file. Biểu đồ trên là wx, wy thô chưa offset. Vui lòng bấm [Run Step 1] để Bù góc!';
        lblStatus1.FontColor = [0.8 0.4 0];
    end

    function runStep1()
        if ~isfield(appData, 'head') || ~isfield(appData, 'pivot')
            uialert(fig, 'Vui lòng chọn cả file Pivot và Head.', 'Lỗi'); return;
        end
        raw_h = appData.head;
        raw_p = appData.pivot;
        
        % --- 1. PCA CHO PIVOT ---
        Axi_raw_p = raw_p(:, [appData.cAxi, appData.cAyi, appData.cAzi]);
        W_raw_p   = raw_p(:, [appData.cWx,  appData.cWy,  appData.cWz ]);
        
        % --- PCA Thủ công theo visualize_pca_steps.m ---
        n_samples_p = min(2000, size(W_raw_p, 1)); 
        X_raw_p = W_raw_p(1:n_samples_p, :);
        mu_p = mean(X_raw_p);
        X_centered_p = X_raw_p - mu_p;
        
        n_p = size(X_centered_p, 1);
        C_p = (X_centered_p' * X_centered_p) / (n_p - 1);
        
        [EigenVectors_p, EigenValuesDiag_p] = eig(C_p);
        EigenValues_p = diag(EigenValuesDiag_p);
        [~, sortIdx_p] = sort(EigenValues_p, 'descend');
        EigenVectors_p = EigenVectors_p(:, sortIdx_p);
        
        rot_axis_p = EigenVectors_p(:, 1); % PC1 
        
        Grav_raw_p = raw_p(:, 11:13);
        n_use_p = n_samples_p; % D?ng chung s? lu?ng sample v?i PCA cho nh?t qun
        g_vec_p = mean(Grav_raw_p(1:n_use_p, :))';
        g_vec_p = g_vec_p / norm(g_vec_p);
        
        if abs(rot_axis_p(1)) > abs(rot_axis_p(2))
            if rot_axis_p(1) < 0, rot_axis_p = -rot_axis_p; end 
            X_p = rot_axis_p;
            Y_p = cross(g_vec_p, X_p); Y_p = Y_p / norm(Y_p);
            Z_p = cross(X_p, Y_p); Z_p = Z_p / norm(Z_p);
            move_type = 'ROLL (Trục X)';
        else
            if rot_axis_p(2) < 0, rot_axis_p = -rot_axis_p; end 
            Y_p = rot_axis_p;
            X_p = cross(Y_p, g_vec_p); X_p = X_p / norm(X_p);
            Z_p = cross(X_p, Y_p); Z_p = Z_p / norm(Z_p);
            move_type = 'PITCH (Trục Y)';
        end
        R_PCA_p = [X_p, Y_p, Z_p]; 
        
        Axi_aligned_p = Axi_raw_p * R_PCA_p;
        W_aligned_p   = W_raw_p * R_PCA_p;
        appData.pivot_aligned = raw_p;
        appData.pivot_aligned(:, [appData.cAxi, appData.cAyi, appData.cAzi]) = Axi_aligned_p;
        appData.pivot_aligned(:, [appData.cWx,  appData.cWy,  appData.cWz ]) = W_aligned_p;
        appData.R_PCA_p = R_PCA_p;
        
        % --- 2. PCA CHO HEAD ---
        Axi_raw_h = raw_h(:, [appData.cAxi, appData.cAyi, appData.cAzi]);
        % Theo yêu cầu: Đảo ngược ay và az của Head
        Axi_raw_h(:, 2) = -Axi_raw_h(:, 2);
        Axi_raw_h(:, 3) = -Axi_raw_h(:, 3);
        
        W_raw_h   = raw_h(:, [appData.cWx,  appData.cWy,  appData.cWz ]);
        
        % --- PCA Thủ công theo visualize_pca_steps.m ---
        n_samples_h = min(2000, size(W_raw_h, 1)); 
        X_raw_h = W_raw_h(1:n_samples_h, :);
        mu_h = mean(X_raw_h);
        X_centered_h = X_raw_h - mu_h;
        
        n_h = size(X_centered_h, 1);
        C_h = (X_centered_h' * X_centered_h) / (n_h - 1);
        
        [EigenVectors_h, EigenValuesDiag_h] = eig(C_h);
        EigenValues_h = diag(EigenValuesDiag_h);
        [~, sortIdx_h] = sort(EigenValues_h, 'descend');
        EigenVectors_h = EigenVectors_h(:, sortIdx_h);
        
        rot_axis_h = EigenVectors_h(:, 1); % PC1 
        
        Grav_raw_h = raw_h(:, 11:13);
        n_use_h = n_samples_h; % D?ng chung s? lu?ng sample v?i PCA cho nh?t qun
        g_vec_h = mean(Grav_raw_h(1:n_use_h, :))';
        g_vec_h = g_vec_h / norm(g_vec_h);
        
        if abs(rot_axis_h(1)) > abs(rot_axis_h(2))
            if rot_axis_h(1) < 0, rot_axis_h = -rot_axis_h; end 
            X_h = rot_axis_h;
            Y_h = cross(g_vec_h, X_h); Y_h = Y_h / norm(Y_h);
            Z_h = cross(X_h, Y_h); Z_h = Z_h / norm(Z_h);
        else
            if rot_axis_h(2) < 0, rot_axis_h = -rot_axis_h; end 
            Y_h = rot_axis_h;
            X_h = cross(Y_h, g_vec_h); X_h = X_h / norm(X_h);
            Z_h = cross(X_h, Y_h); Z_h = Z_h / norm(Z_h);
        end
        R_PCA_h = [X_h, Y_h, Z_h]; 
        
        Axi_aligned_h = Axi_raw_h * R_PCA_h;
        W_aligned_h   = W_raw_h * R_PCA_h;
        appData.head_aligned = raw_h;
        appData.head_aligned(:, [appData.cAxi, appData.cAyi, appData.cAzi]) = Axi_aligned_h;
        appData.head_aligned(:, [appData.cWx,  appData.cWy,  appData.cWz ]) = W_aligned_h;

        % Vẽ đồ thị Aligned
        t_p = raw_p(:, appData.cT);
        t_h = raw_h(:, appData.cT);
        
        cla(ax1_w_align);
        plot(ax1_w_align, t_p, W_aligned_p(:,1), 'r--', 'LineWidth', 1, 'DisplayName', 'Pivot wx (Al)'); hold(ax1_w_align, 'on');
        plot(ax1_w_align, t_p, W_aligned_p(:,2), 'm--', 'LineWidth', 1, 'DisplayName', 'Pivot wy (Al)');
        plot(ax1_w_align, t_h, W_aligned_h(:,1), 'b', 'LineWidth', 1.2, 'DisplayName', 'Head wx (Al)');
        plot(ax1_w_align, t_h, W_aligned_h(:,2), 'c', 'LineWidth', 1.2, 'DisplayName', 'Head wy (Al)'); hold(ax1_w_align, 'off');
        legend(ax1_w_align, 'Location', 'best');
        
        cla(ax1_a_align);
        plot(ax1_a_align, t_p, Axi_aligned_p(:,3), 'r--', 'LineWidth', 1, 'DisplayName', 'Pivot az (Al)'); hold(ax1_a_align, 'on');
        plot(ax1_a_align, t_h, Axi_aligned_h(:,3), 'b', 'LineWidth', 1.2, 'DisplayName', 'Head az (Al)');
        plot(ax1_a_align, t_p, Axi_aligned_p(:,2), 'm--', 'LineWidth', 1, 'DisplayName', 'Pivot ay (Al)');
        plot(ax1_a_align, t_h, Axi_aligned_h(:,2), 'c', 'LineWidth', 1.2, 'DisplayName', 'Head ay (Al)'); hold(ax1_a_align, 'off');
        legend(ax1_a_align, 'Location', 'best');
        
        % Tính góc lệch Pivot
        Rp = R_PCA_p; % Không dùng chuyển vị để in đúng góc lỗi (misalignment)
        roll_p  = atan2d(Rp(3,2), Rp(3,3));
        pitch_p = asind(max(min(-Rp(3,1), 1), -1)); % kẹp giá trị để tránh lỗi số học
        yaw_p   = atan2d(Rp(2,1), Rp(1,1));
        
        % Tính góc lệch Head
        Rh = R_PCA_h; % Không dùng chuyển vị để in đúng góc lỗi
        roll_h  = atan2d(Rh(3,2), Rh(3,3));
        pitch_h = asind(max(min(-Rh(3,1), 1), -1));
        yaw_h   = atan2d(Rh(2,1), Rh(1,1));

        lblStatus1.Text = sprintf('PCA (%s) | Pivot[R: %.1f, P: %.1f, Y: %.1f] | Head[R: %.1f, P: %.1f, Y: %.1f]', ...
            move_type, roll_p, pitch_p, yaw_p, roll_h, pitch_h, yaw_h);
        lblStatus1.FontColor = [0 0.5 0];
    end

    function runStep2()
        if ~isfield(appData, 'head_aligned')
            uialert(fig, 'Chưa chạy Bước 1.', 'Lỗi'); return;
        end
        h_al = appData.head_aligned;
        t_h = h_al(:, appData.cT);
        
        W_B = h_al(:, [appData.cWx, appData.cWy, appData.cWz]);
        
        % Lấy tín hiệu trực tiếp (Không dùng lọc)
        W_B_filt = W_B;
        
        % QUAN TRỌNG: Lưới thời gian của Head KHÔNG ĐỀU, nên phải dùng gradient với t_h
        % Nếu dùng dt trung bình sẽ gây ra các gai nhiễu khổng lồ.
        alpha_B = zeros(size(W_B));
        alpha_B(:,1) = gradient(W_B_filt(:,1), t_h);
        alpha_B(:,2) = gradient(W_B_filt(:,2), t_h);
        alpha_B(:,3) = gradient(W_B_filt(:,3), t_h);
        
        appData.alpha_B = alpha_B;
        appData.W_B_filt = W_B_filt;
        
        % Tính đạo hàm cho cả Pivot để quan sát
        t_p = appData.pivot_aligned(:, appData.cT);
        wx_p = appData.pivot_aligned(:, appData.cWx);
        wy_p = appData.pivot_aligned(:, appData.cWy);
        
        wx_p_filt = wx_p;
        wy_p_filt = wy_p;
        alpha_p_x = gradient(wx_p_filt, t_p);
        alpha_p_y = gradient(wy_p_filt, t_p);
        
        cla(ax2_w);
        plot(ax2_w, t_p, wx_p, 'r--', 'DisplayName', 'Pivot wx (Aligned)'); hold(ax2_w, 'on');
        plot(ax2_w, t_p, wy_p, 'm--', 'DisplayName', 'Pivot wy (Aligned)');
        
        plot(ax2_w, t_h, W_B_filt(:,1), 'b', 'LineWidth', 1.5, 'DisplayName', 'Head wx (Raw)');
        plot(ax2_w, t_h, W_B_filt(:,2), 'c', 'LineWidth', 1.5, 'DisplayName', 'Head wy (Raw)'); hold(ax2_w, 'off');
        legend(ax2_w, 'Location', 'best');
        
        cla(ax2_a);
        plot(ax2_a, t_p, alpha_p_x, 'r--', 'DisplayName', 'Pivot Alpha x'); hold(ax2_a, 'on');
        plot(ax2_a, t_p, alpha_p_y, 'm--', 'DisplayName', 'Pivot Alpha y');
        plot(ax2_a, t_h, alpha_B(:,1), 'b', 'LineWidth', 1.2, 'DisplayName', 'Head Alpha x');
        plot(ax2_a, t_h, alpha_B(:,2), 'c', 'LineWidth', 1.2, 'DisplayName', 'Head Alpha y'); hold(ax2_a, 'off');
        legend(ax2_a, 'Location', 'best');
        
        % --- Đánh giá SNR cho Head ---
        a_hx_smooth = smoothdata(alpha_B(:,1), 'gaussian', 15);
        noise_hx = alpha_B(:,1) - a_hx_smooth;
        snr_hx = 10 * log10(var(a_hx_smooth) / (var(noise_hx) + 1e-9));
        
        a_hy_smooth = smoothdata(alpha_B(:,2), 'gaussian', 15);
        noise_hy = alpha_B(:,2) - a_hy_smooth;
        snr_hy = 10 * log10(var(a_hy_smooth) / (var(noise_hy) + 1e-9));
        
        title(ax2_a, sprintf('Gia tốc góc (Alpha_x, Alpha_y) của Head | SNR Head: X = %.1f dB, Y = %.1f dB', snr_hx, snr_hy));
        
        lblStatus2.Text = sprintf('Hoàn tất Đạo hàm. Đánh giá nhiễu SNR Head của gia tốc góc theo x: %.1f dB, theo y: %.1f dB', snr_hx, snr_hy);
        lblStatus2.FontColor = [0 0.5 0];
    end

    function runStep3()
        if ~isfield(appData, 'alpha_B')
            uialert(fig, 'Chưa chạy Bước 2.', 'Lỗi'); return;
        end
        t_h = appData.head_aligned(:, appData.cT);
        p_aligned = appData.pivot_aligned;
        t_p = p_aligned(:, appData.cT);
        
        t_start = max(t_h(1), t_p(1));
        t_end   = min(t_h(end), t_p(end));
        
        if t_end <= t_start
            uialert(fig, 'Không có vùng chồng lấn thời gian.', 'Lỗi'); return;
        end
        
        mask_p = (t_p >= t_start & t_p <= t_end);
        t_sync = t_p(mask_p);
        pivot_sync = p_aligned(mask_p, :);
        
        head_sync = zeros(length(t_sync), size(appData.head_aligned, 2));
        head_sync(:, 1) = t_sync;
        
        for col = 2:size(appData.head_aligned, 2)
            head_sync(:, col) = interp1(t_h, appData.head_aligned(:, col), t_sync, 'linear', 'extrap');
        end
        
        alpha_sync = zeros(length(t_sync), 3);
        for i = 1:3
            alpha_sync(:, i) = interp1(t_h, appData.alpha_B(:, i), t_sync, 'linear', 'extrap');
        end
        
        appData.t_sync = t_sync;
        appData.pivot_sync = pivot_sync;
        appData.head_sync = head_sync;
        appData.alpha_sync = alpha_sync;
        
        % RMSE nội suy
        mask_h = (t_h >= t_start & t_h <= t_end);
        t_h_orig = t_h(mask_h);
        orig_az = appData.head_aligned(mask_h, appData.cAzi);
        recon_az = interp1(t_sync, head_sync(:, appData.cAzi), t_h_orig, 'linear');
        rmse_interp = sqrt(mean((orig_az - recon_az).^2, 'omitnan'));
        
        % Wx, Wy Sync Plot
        cla(ax3_w);
        plot(ax3_w, t_sync, pivot_sync(:, appData.cWx), 'r--', 'DisplayName', 'Pivot wx'); hold(ax3_w, 'on');
        plot(ax3_w, t_sync, pivot_sync(:, appData.cWy), 'm--', 'DisplayName', 'Pivot wy');
        plot(ax3_w, t_sync, head_sync(:, appData.cWx), 'b', 'LineWidth', 1.2, 'DisplayName', 'Head wx (Synced)');
        plot(ax3_w, t_sync, head_sync(:, appData.cWy), 'c', 'LineWidth', 1.2, 'DisplayName', 'Head wy (Synced)'); hold(ax3_w, 'off');
        legend(ax3_w, 'Location', 'best');
        
        % Accel Ay Sync Plot
        cla(ax3_ay);
        orig_ay = appData.head_aligned(mask_h, appData.cAyi);
        plot(ax3_ay, t_h_orig, orig_ay, 'Color', [0.7 0.7 0.7], 'DisplayName', 'Ay Head (Gốc)'); hold(ax3_ay, 'on');
        plot(ax3_ay, t_sync, head_sync(:, appData.cAyi), 'b--', 'DisplayName', 'Ay Head (Nội suy)'); 
        plot(ax3_ay, t_sync, pivot_sync(:, appData.cAyi), 'r', 'DisplayName', 'Ay Pivot'); hold(ax3_ay, 'off');
        legend(ax3_ay, 'Location', 'best');
        
        % Accel Az Sync Plot
        cla(ax3_az);
        plot(ax3_az, t_h_orig, orig_az, 'Color', [0.7 0.7 0.7], 'DisplayName', 'Az Head (Gốc)'); hold(ax3_az, 'on');
        plot(ax3_az, t_sync, head_sync(:, appData.cAzi), 'b--', 'DisplayName', 'Az Head (Nội suy)'); 
        plot(ax3_az, t_sync, pivot_sync(:, appData.cAzi), 'r', 'DisplayName', 'Az Pivot'); hold(ax3_az, 'off');
        legend(ax3_az, 'Location', 'best');
        
        lblStatus3.Text = sprintf('Hoàn tất Đồng bộ. Pivot: %d mẫu. RMSE nội suy Head (Az): %.5f', length(t_sync), rmse_interp);
        
        c_ay = corrcoef(pivot_sync(:, appData.cAyi), head_sync(:, appData.cAyi)); p_ay = c_ay(1,2);
        c_az = corrcoef(pivot_sync(:, appData.cAzi), head_sync(:, appData.cAzi)); p_az = c_az(1,2);
        
        lblStatus3.Text = [lblStatus3.Text, sprintf(' | Corr(Ay)=%.4f, Corr(Az)=%.4f', p_ay, p_az)];
        lblStatus3.FontColor = [0 0.5 0];
    end

    function runStep4()
        if ~isfield(appData, 't_sync')
            uialert(fig, 'Chưa chạy Bước 3.', 'Lỗi'); return;
        end
        
        isPitch = contains(ddAxis.Value, 'Pitch');
        
        t = appData.t_sync; N = length(t);
        
        head_sync = appData.head_sync;
        pivot_sync = appData.pivot_sync; % Pivot aligned
        alpha_sync = appData.alpha_sync;
        
        M_stack = zeros(2*N, 2);
        B_stack = zeros(2*N, 1);
        
        for k = 1:N
            a_h_world = [head_sync(k, appData.cAxi); head_sync(k, appData.cAyi); head_sync(k, appData.cAzi)];
            a_p_world = [pivot_sync(k, appData.cAxi); pivot_sync(k, appData.cAyi); pivot_sync(k, appData.cAzi)];
            
            w_world = [head_sync(k, appData.cWx); head_sync(k, appData.cWy); head_sync(k, appData.cWz)];
            al_world = alpha_sync(k, :)';
            
            % VẤN ĐỀ CỐT LÕI NẰM Ở ĐÂY:
            % Hệ phương trình Math Engine BẮT BUỘC phải giải trong Body Frame của Pivot!
            % Dữ liệu _sync hiện tại đang nằm ở World Frame (do đã qua PCA).
            % Nếu giải trực tiếp trên World Frame, r sẽ là một véc-tơ bị quay -> Least Squares sẽ cho ra nghiệm sai.
            % Giải pháp: Dùng R_PCA_p biến đổi ngược các véc-tơ này về lại Pivot Body Frame!
            % Chú ý: v_body = R_PCA * v_world (đối với véc-tơ cột)
            
            R_p = appData.R_PCA_p;
            
            a_h_body = R_p * a_h_world;
            a_p_body = R_p * a_p_world;
            da = a_h_body - a_p_body;
            
            w = R_p * w_world;
            al = R_p * al_world;
            
            Om = [0 -w(3) w(2); w(3) 0 -w(1); -w(2) w(1) 0];
            Al = [0 -al(3) al(2); al(3) 0 -al(1); -al(2) al(1) 0];
            M_k = Al + Om^2;
            
            if isPitch
                M_reduced = M_k([1, 3], [1, 3]);
                B_reduced = [da(1); da(3)];
            else
                M_reduced = M_k([2, 3], [2, 3]);
                B_reduced = [da(2); da(3)];
            end
            
            idx = (2*k - 1) : 2*k;
            M_stack(idx, :) = M_reduced;
            B_stack(idx)    = B_reduced;
        end
        
        % --- BỘ LỌC THEO TEST_MATH_ENGINE_IMPORT.M ---
        % Loại bỏ 5% dữ liệu ở hai đầu để tránh nhiễu do sai phân (gradient) ở biên
        % Không dùng ngưỡng 30% của norm_M nữa để giữ lại tối đa thông tin động học
        valid_idx = round(0.05*N) : round(0.95*N);
        valid_rows = [];
        for v = valid_idx
            valid_rows = [valid_rows, 2*v-1, 2*v];
        end
        M_filt = M_stack(valid_rows, :);
        B_filt = B_stack(valid_rows);
        % ---------------------------------------------
        
        if rank(M_filt) < 2
            uialert(fig, 'Ma trận suy biến, không thể giải!', 'Lỗi'); return;
        end
        
        r_sol_m = M_filt \ B_filt;
        r_sol_mm = r_sol_m * 1000;
        
        acc_calc = M_stack * r_sol_m;
        d_meas_1 = B_stack(1:2:end); d_meas_2 = B_stack(2:2:end);
        d_calc_1 = acc_calc(1:2:end); d_calc_2 = acc_calc(2:2:end);
        
        if isPitch
            a_p_1 = pivot_sync(:, appData.cAxi);
            a_p_2 = pivot_sync(:, appData.cAzi);
            a_meas_1 = head_sync(:, appData.cAxi);
            a_meas_2 = head_sync(:, appData.cAzi);
        else
            a_p_1 = pivot_sync(:, appData.cAyi);
            a_p_2 = pivot_sync(:, appData.cAzi);
            a_meas_1 = head_sync(:, appData.cAyi);
            a_meas_2 = head_sync(:, appData.cAzi);
        end
        
        a_calc_1 = a_p_1 + d_calc_1;
        a_calc_2 = a_p_2 + d_calc_2;
        
        rmse_1 = sqrt(mean((a_meas_1 - a_calc_1).^2));
        rmse_2 = sqrt(mean((a_meas_2 - a_calc_2).^2));
        
        [R1_mat, ~] = corrcoef(a_meas_1, a_calc_1); R_1 = R1_mat(1,2);
        [R2_mat, ~] = corrcoef(a_meas_2, a_calc_2); R_2 = R2_mat(1,2);
        
        cla(ax4_1);
        plot(ax4_1, t, a_meas_1, 'k', 'DisplayName', 'IMU Thực tế'); hold(ax4_1, 'on');
        plot(ax4_1, t, a_calc_1, 'r--', 'LineWidth', 1.5, 'DisplayName', 'Mô hình'); hold(ax4_1, 'off'); legend(ax4_1, 'Location', 'best');
        text(ax4_1, 0.02, 0.95, sprintf('Pearson: %.4f\nRMSE: %.4f', R_1, rmse_1), 'Units', 'normalized', 'VerticalAlignment', 'top', 'BackgroundColor', 'w', 'EdgeColor', 'k', 'FontSize', 11);
        
        cla(ax4_2);
        plot(ax4_2, t, a_meas_2, 'k', 'DisplayName', 'IMU Thực tế'); hold(ax4_2, 'on');
        plot(ax4_2, t, a_calc_2, 'r--', 'LineWidth', 1.5, 'DisplayName', 'Mô hình'); hold(ax4_2, 'off'); legend(ax4_2, 'Location', 'best');
        text(ax4_2, 0.02, 0.95, sprintf('Pearson: %.4f\nRMSE: %.4f', R_2, rmse_2), 'Units', 'normalized', 'VerticalAlignment', 'top', 'BackgroundColor', 'w', 'EdgeColor', 'k', 'FontSize', 11);
        
        if isPitch
            res_str = sprintf('r_x = %.2f mm, r_z = %.2f mm', r_sol_mm(1), r_sol_mm(2));
            rmse_str = sprintf('RMSE(ax) = %.4f | RMSE(az) = %.4f', rmse_1, rmse_2);
            ylabel(ax4_1, 'ax'); ylabel(ax4_2, 'az');
            title(ax4_1, 'Đối chiếu trục X (ax)');
            title(ax4_2, 'Đối chiếu trục Z (az)');
            txtRx.Value = r_sol_mm(1);
            txtRz.Value = r_sol_mm(2);
        else
            res_str = sprintf('r_y = %.2f mm, r_z = %.2f mm', r_sol_mm(1), r_sol_mm(2));
            rmse_str = sprintf('RMSE(ay) = %.4f | RMSE(az) = %.4f', rmse_1, rmse_2);
            ylabel(ax4_1, 'ay'); ylabel(ax4_2, 'az');
            title(ax4_1, 'Đối chiếu trục Y (ay)');
            title(ax4_2, 'Đối chiếu trục Z (az)');
            txtRy.Value = r_sol_mm(1);
            txtRz.Value = r_sol_mm(2);
        end
        
        lblStatus4.Text = sprintf('KẾT QUẢ: %s | %s', res_str, rmse_str);
        lblStatus4.FontColor = [0.8 0.1 0.1];
    end

    function runStep5()
        if ~isfield(appData, 'head_sync') || ~isfield(appData, 'pivot_sync') || ~isfield(appData, 'alpha_sync')
            uialert(fig, 'Chưa có dữ liệu đồng bộ (Phải chạy Step 3 trước).', 'Lỗi'); return;
        end
        
        r_m = [txtRx.Value; txtRy.Value; txtRz.Value] / 1000;
        
        N = size(appData.head_sync, 1);
        t = appData.head_sync(:, appData.cT);
        
        head_sync = appData.head_sync;
        pivot_sync = appData.pivot_sync;
        alpha_sync = appData.alpha_sync;
        
        a_calc_x = zeros(N, 1);
        a_calc_y = zeros(N, 1);
        a_calc_z = zeros(N, 1);
        
        for k = 1:N
            a_p = [pivot_sync(k, appData.cAxi); pivot_sync(k, appData.cAyi); pivot_sync(k, appData.cAzi)];
            w = [head_sync(k, appData.cWx); head_sync(k, appData.cWy); head_sync(k, appData.cWz)];
            al = alpha_sync(k, :)';
            
            Om = [0 -w(3) w(2); w(3) 0 -w(1); -w(2) w(1) 0];
            Al = [0 -al(3) al(2); al(3) 0 -al(1); -al(2) al(1) 0];
            M_k = Al + Om^2;
            
            a_c = a_p + M_k * r_m;
            
            a_calc_x(k) = a_c(1);
            a_calc_y(k) = a_c(2);
            a_calc_z(k) = a_c(3);
        end
        
        % Lưu dữ liệu xuất (Bảo toàn W từ Head)
        appData.head_translated = [t, a_calc_x, a_calc_y, a_calc_z, head_sync(:, appData.cWx), head_sync(:, appData.cWy), head_sync(:, appData.cWz)];
        
        a_imu_x = head_sync(:, appData.cAxi);
        a_imu_y = head_sync(:, appData.cAyi);
        a_imu_z = head_sync(:, appData.cAzi);
        
        rmse_2 = sqrt(mean((a_meas_2 - a_calc_2).^2));
        
        [R1_mat, ~] = corrcoef(a_meas_1, a_calc_1); R_1 = R1_mat(1,2);
        [R2_mat, ~] = corrcoef(a_meas_2, a_calc_2); R_2 = R2_mat(1,2);
        
        cla(ax4_1);
        plot(ax4_1, t_plot, a_meas_1, 'k', 'DisplayName', 'IMU Thực tế'); hold(ax4_1, 'on');
        plot(ax4_1, t_plot, a_calc_1, 'r--', 'LineWidth', 1.5, 'DisplayName', 'Mô hình'); hold(ax4_1, 'off'); legend(ax4_1, 'Location', 'best');
        text(ax4_1, 0.02, 0.95, sprintf('Pearson: %.4f\nRMSE: %.4f', R_1, rmse_1), 'Units', 'normalized', 'VerticalAlignment', 'top', 'BackgroundColor', 'w', 'EdgeColor', 'k', 'FontSize', 11);
        
        cla(ax4_2);
        plot(ax4_2, t_plot, a_meas_2, 'k', 'DisplayName', 'IMU Thực tế'); hold(ax4_2, 'on');
        plot(ax4_2, t_plot, a_calc_2, 'r--', 'LineWidth', 1.5, 'DisplayName', 'Mô hình'); hold(ax4_2, 'off'); legend(ax4_2, 'Location', 'best');
        text(ax4_2, 0.02, 0.95, sprintf('Pearson: %.4f\nRMSE: %.4f', R_2, rmse_2), 'Units', 'normalized', 'VerticalAlignment', 'top', 'BackgroundColor', 'w', 'EdgeColor', 'k', 'FontSize', 11);
        
        if isPitch
            res_str = sprintf('r_x = %.2f mm, r_z = %.2f mm', r_sol_mm(1), r_sol_mm(2));
            rmse_str = sprintf('RMSE(ax) = %.4f | RMSE(az) = %.4f', rmse_1, rmse_2);
            ylabel(ax4_1, 'ax'); ylabel(ax4_2, 'az');
            title(ax4_1, 'Đối chiếu trục X (ax)');
            title(ax4_2, 'Đối chiếu trục Z (az)');
            txtRx.Value = r_sol_mm(1);
            txtRz.Value = r_sol_mm(2);
        else
            res_str = sprintf('r_y = %.2f mm, r_z = %.2f mm', r_sol_mm(1), r_sol_mm(2));
            rmse_str = sprintf('RMSE(ay) = %.4f | RMSE(az) = %.4f', rmse_1, rmse_2);
            ylabel(ax4_1, 'ay'); ylabel(ax4_2, 'az');
            title(ax4_1, 'Đối chiếu trục Y (ay)');
            title(ax4_2, 'Đối chiếu trục Z (az)');
            txtRy.Value = r_sol_mm(1);
            txtRz.Value = r_sol_mm(2);
        end
        
        lblStatus4.Text = sprintf('KẾT QUẢ: %s | %s', res_str, rmse_str);
        lblStatus4.FontColor = [0.8 0.1 0.1];
    end

    function runStep5()
        if ~isfield(appData, 'head_sync') || ~isfield(appData, 'pivot_sync') || ~isfield(appData, 'alpha_sync')
            uialert(fig, 'Chưa có dữ liệu đồng bộ (Phải chạy Step 3 trước).', 'Lỗi'); return;
        end
        
        r_m = [txtRx.Value; txtRy.Value; txtRz.Value] / 1000;
        
        N = size(appData.head_sync, 1);
        t = appData.head_sync(:, appData.cT);
        
        head_sync = appData.head_sync;
        pivot_sync = appData.pivot_sync;
        alpha_sync = appData.alpha_sync;
        
        a_calc_x = zeros(N, 1);
        a_calc_y = zeros(N, 1);
        a_calc_z = zeros(N, 1);
        
        for k = 1:N
            a_p = [pivot_sync(k, appData.cAxi); pivot_sync(k, appData.cAyi); pivot_sync(k, appData.cAzi)];
            w = [head_sync(k, appData.cWx); head_sync(k, appData.cWy); head_sync(k, appData.cWz)];
            al = alpha_sync(k, :)';
            
            Om = [0 -w(3) w(2); w(3) 0 -w(1); -w(2) w(1) 0];
            Al = [0 -al(3) al(2); al(3) 0 -al(1); -al(2) al(1) 0];
            M_k = Al + Om^2;
            
            a_c = a_p + M_k * r_m;
            
            a_calc_x(k) = a_c(1);
            a_calc_y(k) = a_c(2);
            a_calc_z(k) = a_c(3);
        end
        
        % Lưu dữ liệu xuất (Bảo toàn W từ Head)
        appData.head_translated = [t, a_calc_x, a_calc_y, a_calc_z, head_sync(:, appData.cWx), head_sync(:, appData.cWy), head_sync(:, appData.cWz)];
        
        a_imu_x = head_sync(:, appData.cAxi);
        a_imu_y = head_sync(:, appData.cAyi);
        a_imu_z = head_sync(:, appData.cAzi);
        
        % Tính Pearson và RMSE
        [Rx, ~] = corrcoef(a_calc_x, a_imu_x); R_x = Rx(1,2);
        [Ry, ~] = corrcoef(a_calc_y, a_imu_y); R_y = Ry(1,2);
        [Rz, ~] = corrcoef(a_calc_z, a_imu_z); R_z = Rz(1,2);
        
        rmse_x = sqrt(mean((a_calc_x - a_imu_x).^2));
        rmse_y = sqrt(mean((a_calc_y - a_imu_y).^2));
        rmse_z = sqrt(mean((a_calc_z - a_imu_z).^2));
        
        plotCompare(ax5_1, t, a_imu_x, a_calc_x, 'Trục X (Ax)', R_x, rmse_x);
        plotCompare(ax5_2, t, a_imu_y, a_calc_y, 'Trục Y (Ay)', R_y, rmse_y);
        plotCompare(ax5_3, t, a_imu_z, a_calc_z, 'Trục Z (Az)', R_z, rmse_z);
        
        lblStatus5.Text = 'Đã hoàn tất tính toán Phase 2 & 3!';
        lblStatus5.FontColor = [0.1 0.6 0.1];
    end

    function plotCompare(ax, t, a_imu, a_calc, name, R, rmse)
        cla(ax);
        plot(ax, t, a_imu, 'k', 'DisplayName', 'IMU Thực tế'); hold(ax, 'on');
        plot(ax, t, a_calc, 'r--', 'LineWidth', 1.5, 'DisplayName', 'Head Ngoại suy'); hold(ax, 'off');
        title(ax, name);
        legend(ax, 'Location', 'best');
        text(ax, 0.02, 0.95, sprintf('Pearson: %.4f\nRMSE: %.4f', R, rmse), 'Units', 'normalized', 'VerticalAlignment', 'top', 'BackgroundColor', 'w', 'EdgeColor', 'k', 'FontSize', 11);
    end

    function exportHead()
        if ~isfield(appData, 'head_translated')
            uialert(fig, 'Bạn phải chạy Run Phase 2+3 trước khi Export!', 'Lỗi'); return;
        end
        [fname, fpath] = uiputfile('head_translated.csv', 'Lưu file Simulated Head');
        if isequal(fname, 0), return; end
        
        T = array2table(appData.head_translated, 'VariableNames', {'Time', 'Ax', 'Ay', 'Az', 'Wx', 'Wy', 'Wz'});
        writetable(T, fullfile(fpath, fname));
        uialert(fig, 'Đã lưu file thành công!', 'Thông báo');
    end

    function saveAllPlots()
        selpath = uigetdir('', 'Select folder to save plots');
        if isequal(selpath, 0), return; end
        
        try
            figsToSave = { ...
                ax1_w_raw, 'Step1_1_Raw_Velocity.png';
                ax1_w_align, 'Step1_2_Aligned_Velocity.png';
                ax1_a_raw, 'Step1_3_Raw_Acceleration.png';
                ax1_a_align, 'Step1_4_Aligned_Acceleration.png';
                ax2_w, 'Step2_1_Raw_Velocity.png';
                ax2_a, 'Step2_2_Angular_Acceleration.png';
                ax3_w, 'Step3_1_Synced_Velocity.png';
                ax3_ay, 'Step3_2_Synced_Acceleration_Ay.png';
                ax3_az, 'Step3_3_Synced_Acceleration_Az.png';
                ax4_1, 'Step4_1_Residuals_Axis_1.png';
                ax4_2, 'Step4_2_Residuals_Axis_2.png';
                ax5_1, 'Step5_1_Evaluation_Ax.png';
                ax5_2, 'Step5_2_Evaluation_Ay.png';
                ax5_3, 'Step5_3_Evaluation_Az.png'
            };
            
            for i = 1:size(figsToSave, 1)
                ax = figsToSave{i, 1};
                fname = figsToSave{i, 2};
                exportgraphics(ax, fullfile(selpath, fname), 'Resolution', 300);
            end
            
            uialert(fig, 'Đã lưu toàn bộ biểu đồ thành công!', 'Thông báo');
        catch ME
            uialert(fig, ['Lỗi khi lưu ảnh: ' ME.message], 'Lỗi');
        end
    end

    function out = ternary(cond, a, b)
        if cond, out = a; else, out = b; end
    end

end
