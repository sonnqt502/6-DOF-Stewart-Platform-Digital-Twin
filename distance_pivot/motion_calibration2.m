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

    tab3b = uitab(tg, 'Title', '3B. Crop Data');

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

    

    uilabel(tab1, 'Text', 'Thời gian tĩnh (s):', 'Position', [20 670 120 22], 'FontWeight','bold');

    txtStaticTime = uieditfield(tab1, 'numeric', 'Position', [140 670 60 22], 'Value', 2.0);

    

    chkSkipPCA = uicheckbox(tab1, 'Text', 'Bỏ qua PCA (Dành cho file đã xuất từ Python Pipeline)', 'Position', [220 670 400 22], 'Value', 1, 'FontWeight', 'bold');

    btnRun1 = uibutton(tab1, 'push', 'Text', '▶ Run Step 1 (PCA Alignment)', 'Position', [20 630 250 30], 'BackgroundColor', [0.2 0.6 0.3], 'FontColor', 'w', 'FontWeight', 'bold', 'ButtonPushedFcn', @(~,~) runStep1());

    lblStatus1 = uilabel(tab1, 'Text', 'Hãy chọn file dữ liệu.', 'Position', [280 630 700 30], 'FontColor', [0.5 0.5 0.5]);

    

    btnRun1 = uibutton(tab1, 'push', 'Text', '▶ Run Step 1 (Alignment)', 'Position', [20 630 200 30], 'BackgroundColor', [0.2 0.6 0.3], 'FontColor', 'w', 'FontWeight', 'bold', 'ButtonPushedFcn', @(~,~) runStep1());

    lblStatus1 = uilabel(tab1, 'Text', 'Hãy chọn file dữ liệu.', 'Position', [240 630 700 30], 'FontColor', [0.5 0.5 0.5]);

    

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

    % TAB 3B: CROP DATA

    % =========================================================================

    uilabel(tab3b, 'Text', 'Start Time (s):', 'Position', [20 710 100 22], 'FontWeight','bold');

    txtCropStart = uieditfield(tab3b, 'numeric', 'Position', [120 710 80 22], 'Value', 0);

    uilabel(tab3b, 'Text', 'End Time (s):', 'Position', [220 710 90 22], 'FontWeight','bold');

    txtCropEnd = uieditfield(tab3b, 'numeric', 'Position', [310 710 80 22], 'Value', 100);

    

    btnRun3b = uibutton(tab3b, 'push', 'Text', '▶ Run Step 3B (Crop Data)', 'Position', [420 710 200 30], 'BackgroundColor', [0.8 0.4 0.2], 'FontColor', 'w', 'FontWeight', 'bold', 'ButtonPushedFcn', @(~,~) runStep3b());

    lblStatus3b = uilabel(tab3b, 'Text', 'Chưa chạy. Mặc định dùng toàn bộ dữ liệu.', 'Position', [640 710 500 30], 'FontColor', [0.5 0.5 0.5]);

    

    ax3b_1 = uiaxes(tab3b, 'Position', [20 20 1140 650]); title(ax3b_1, 'Dữ liệu sau khi cắt (Gia tốc góc Alpha_y)'); grid(ax3b_1, 'on');

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

        

        W_raw_p   = raw_p(:, [appData.cWx,  appData.cWy,  appData.cWz ]);

        

        Axi_raw_h = raw_h(:, [appData.cAxi, appData.cAyi, appData.cAzi]);

        % Đảo ngược ay và az của Head theo yêu cầu

        Axi_raw_h(:, 2) = -Axi_raw_h(:, 2);

        Axi_raw_h(:, 3) = -Axi_raw_h(:, 3);

        

        W_raw_h   = raw_h(:, [appData.cWx,  appData.cWy,  appData.cWz ]);

        

        if chkSkipPCA.Value == 1

            % --- BỎ QUA PCA ---

            if var(W_raw_p(:,1)) > var(W_raw_p(:,2)), move_type = 'ROLL (Trục X)'; else, move_type = 'PITCH (Trục Y)'; end

            R_PCA_p = eye(3);

            R_PCA_h = eye(3);

            

            Axi_aligned_p = Axi_raw_p;

            W_aligned_p   = W_raw_p;

            Axi_aligned_h = Axi_raw_h;

            W_aligned_h   = W_raw_h;

            

        if var(W_raw_p(:,1)) > var(W_raw_p(:,2)), move_type = 'ROLL (Trục X)'; else, move_type = 'PITCH (Trục Y)'; end

        

        t_static = txtStaticTime.Value;

        

        % --- THỰC HIỆN PCA NHƯ CŨ (KHÔNG DGCF) ---

        mask_p = (raw_p(:, appData.cT) >= 0 & raw_p(:, appData.cT) <= t_static);

        A_stat_p = Axi_raw_p(mask_p, :);

        g_vec_p = mean(A_stat_p); g_vec_p = g_vec_p / norm(g_vec_p);

        

        W_centered_p = W_raw_p - mean(W_raw_p);

        [eig_vecs_p, eig_vals_p] = eig(cov(W_centered_p));

        [~, max_idx_p] = max(diag(eig_vals_p));

        rot_axis_p = eig_vecs_p(:, max_idx_p);

        

        if contains(move_type, 'ROLL')

            if rot_axis_p(1) < 0, rot_axis_p = -rot_axis_p; end

            X_p = rot_axis_p;

            Y_p = cross(g_vec_p(:), X_p(:)); Y_p = Y_p / norm(Y_p);

            Z_p = cross(X_p(:), Y_p(:)); Z_p = Z_p / norm(Z_p);

            R_PCA_p = [X_p(:), Y_p(:), Z_p(:)];

        else

            % --- THỰC HIỆN PCA ---

            t_static = txtStaticTime.Value;

            

            % PCA Pivot

            t_p_raw = raw_p(:, appData.cT);

            n_static_p = sum(t_p_raw - t_p_raw(1) <= t_static);

            if n_static_p < 10, n_static_p = 10; end

            

            X_raw_p = W_raw_p;

            mu_p = mean(X_raw_p);

            X_centered_p = X_raw_p - mu_p;

            C_p = (X_centered_p' * X_centered_p) / (size(X_centered_p, 1) - 1);

            [EigenVectors_p, EigenValuesDiag_p] = eig(C_p);

            [~, sortIdx_p] = sort(diag(EigenValuesDiag_p), 'descend');

            rot_axis_p = EigenVectors_p(:, sortIdx_p(1));

            

            Grav_raw_p = raw_p(:, 11:13);

            g_vec_p = mean(Grav_raw_p(1:n_static_p, :))';

            g_vec_p = g_vec_p / norm(g_vec_p);

            

            if abs(rot_axis_p(1)) > abs(rot_axis_p(2))

                if rot_axis_p(1) < 0, rot_axis_p = -rot_axis_p; end 

                X_p = rot_axis_p; Y_p = cross(g_vec_p, X_p); Y_p = Y_p / norm(Y_p); Z_p = cross(X_p, Y_p); Z_p = Z_p / norm(Z_p);

                move_type = 'ROLL (Trục X)';

            else

                if rot_axis_p(2) < 0, rot_axis_p = -rot_axis_p; end 

                Y_p = rot_axis_p; X_p = cross(Y_p, g_vec_p); X_p = X_p / norm(X_p); Z_p = cross(X_p, Y_p); Z_p = Z_p / norm(Z_p);

                move_type = 'PITCH (Trục Y)';

            end

            R_PCA_p = [X_p, Y_p, Z_p];

            Axi_aligned_p = Axi_raw_p * R_PCA_p; W_aligned_p = W_raw_p * R_PCA_p;

            

            % PCA Head

            t_h_raw = raw_h(:, appData.cT);

            n_static_h = sum(t_h_raw - t_h_raw(1) <= t_static);

            if n_static_h < 10, n_static_h = 10; end

            

            X_raw_h = W_raw_h;

            mu_h = mean(X_raw_h);

            X_centered_h = X_raw_h - mu_h;

            C_h = (X_centered_h' * X_centered_h) / (size(X_centered_h, 1) - 1);

            [EigenVectors_h, EigenValuesDiag_h] = eig(C_h);

            [~, sortIdx_h] = sort(diag(EigenValuesDiag_h), 'descend');

            rot_axis_h = EigenVectors_h(:, sortIdx_h(1));

            

            Grav_raw_h = raw_h(:, 11:13);

            g_vec_h = mean(Grav_raw_h(1:n_static_h, :))';

            g_vec_h = g_vec_h / norm(g_vec_h);

            

            if abs(rot_axis_h(1)) > abs(rot_axis_h(2))

                if rot_axis_h(1) < 0, rot_axis_h = -rot_axis_h; end 

                X_h = rot_axis_h; Y_h = cross(g_vec_h, X_h); Y_h = Y_h / norm(Y_h); Z_h = cross(X_h, Y_h); Z_h = Z_h / norm(Z_h);

            else

                if rot_axis_h(2) < 0, rot_axis_h = -rot_axis_h; end 

                Y_h = rot_axis_h; X_h = cross(Y_h, g_vec_h); X_h = X_h / norm(X_h); Z_h = cross(X_h, Y_h); Z_h = Z_h / norm(Z_h);

            end

            R_PCA_h = [X_h, Y_h, Z_h];

            Axi_aligned_h = Axi_raw_h * R_PCA_h; W_aligned_h = W_raw_h * R_PCA_h;

            if rot_axis_p(2) < 0, rot_axis_p = -rot_axis_p; end

            Y_p = rot_axis_p;

            X_p = cross(Y_p(:), g_vec_p(:)); X_p = X_p / norm(X_p);

            Z_p = cross(X_p(:), Y_p(:)); Z_p = Z_p / norm(Z_p);

            R_PCA_p = [X_p(:), Y_p(:), Z_p(:)];

        end

        

        % Gắn dữ liệu vào appData

        Axi_aligned_p = (Axi_raw_p - g_vec_p * 9.81) * R_PCA_p;

        W_aligned_p = W_raw_p * R_PCA_p;

        

        % PCA cho Head

        mask_h = (raw_h(:, appData.cT) >= 0 & raw_h(:, appData.cT) <= t_static);

        A_stat_h = Axi_raw_h(mask_h, :);

        g_vec_h = mean(A_stat_h); g_vec_h = g_vec_h / norm(g_vec_h);

        

        W_centered_h = W_raw_h - mean(W_raw_h);

        [eig_vecs_h, eig_vals_h] = eig(cov(W_centered_h));

        [~, max_idx_h] = max(diag(eig_vals_h));

        rot_axis_h = eig_vecs_h(:, max_idx_h);

        

        if contains(move_type, 'ROLL')

            if rot_axis_h(1) < 0, rot_axis_h = -rot_axis_h; end

            X_h = rot_axis_h;

            Y_h = cross(g_vec_h(:), X_h(:)); Y_h = Y_h / norm(Y_h);

            Z_h = cross(X_h(:), Y_h(:)); Z_h = Z_h / norm(Z_h);

            R_PCA_h = [X_h(:), Y_h(:), Z_h(:)];

        else

            if rot_axis_h(2) < 0, rot_axis_h = -rot_axis_h; end

            Y_h = rot_axis_h;

            X_h = cross(Y_h(:), g_vec_h(:)); X_h = X_h / norm(X_h);

            Z_h = cross(X_h(:), Y_h(:)); Z_h = Z_h / norm(Z_h);

            R_PCA_h = [X_h(:), Y_h(:), Z_h(:)];

        end

        

        Axi_aligned_h = (Axi_raw_h - g_vec_h * 9.81) * R_PCA_h;

        W_aligned_h = W_raw_h * R_PCA_h;

        

        appData.R_PCA_p = R_PCA_p;

        

        appData.pivot_aligned = raw_p;

        appData.pivot_aligned(:, [appData.cAxi, appData.cAyi, appData.cAzi]) = Axi_aligned_p;

        appData.pivot_aligned(:, [appData.cWx,  appData.cWy,  appData.cWz ]) = W_aligned_p;

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
        
        rms_wx_raw_h = rms(W_raw_h(:, 1)); rms_wy_raw_h = rms(W_raw_h(:, 2));
        rms_wx_al_h = rms(W_aligned_h(:, 1)); rms_wy_al_h = rms(W_aligned_h(:, 2));
        if contains(move_type, 'ROLL')
            ratio_h_pre = rms_wy_raw_h / rms_wx_raw_h;
            ratio_h_post = rms_wy_al_h / rms_wx_al_h;
        else
            ratio_h_pre = rms_wx_raw_h / rms_wy_raw_h;
            ratio_h_post = rms_wx_al_h / rms_wy_al_h;
        end
        fprintf('
--- KẾT QUẢ CĂN CHỈNH PCA (%s) ---
', move_type);
        fprintf('Tỷ lệ nhiễu chéo Head: Trước = %.4f | Sau = %.4f
', ratio_h_pre, ratio_h_post);
        fprintf('--------------------------------------
');
        
        lblStatus1.Text = sprintf('Đã áp dụng PCA (%s). Tỷ lệ nhiễu: %.4f -> %.4f', move_type, ratio_h_pre, ratio_h_post);

        lblStatus1.FontColor = [0 0.5 0];

    end

        pivot_sync = appData.pivot_sync; % Pivot aligned

        alpha_sync = appData.alpha_sync;

        

        M_stack = zeros(2*N, 2);

        M_stack = zeros(2*N, 4); % Updated to fit 4 parameters [r1, r2, C1, C2]

        B_stack = zeros(2*N, 1);

        

        for k = 1:N

            M_k = Al + Om^2;

            

            if isPitch

                M_reduced = M_k([1, 3], [1, 3]);

                M_reduced = [M_k([1, 3], [1, 3]), eye(2)]; % [rx, rz, Cx, Cz]

                B_reduced = [da(1); da(3)];

            else

                M_reduced = M_k([2, 3], [2, 3]);

                M_reduced = [M_k([2, 3], [2, 3]), eye(2)]; % [ry, rz, Cy, Cz]

                B_reduced = [da(2); da(3)];

            end

            

        end

        

        r_sol_m = M_filt \ B_filt;

        r_sol_mm = r_sol_m * 1000;

        

        acc_calc = M_stack * r_sol_m;

        % Tách r_sol và C_sol

        r_vec = r_sol_m(1:2);

        C_vec = r_sol_m(3:4);

        

        r_sol_mm = r_vec * 1000;

        

        % Tính lại gia tốc lý thuyết

        acc_calc = zeros(2*N, 1);

        for k = 1:N

            idx = (2*k - 1) : 2*k;

            acc_calc(idx) = M_stack(idx, 1:2) * r_vec + C_vec;

        end

        d_meas_1 = B_stack(1:2:end); d_meas_2 = B_stack(2:2:end);

        d_calc_1 = acc_calc(1:2:end); d_calc_2 = acc_calc(2:2:end);

        

            res_str = sprintf('r_x = %.2f mm, r_z = %.2f mm', r_sol_mm(1), r_sol_mm(2));

            rmse_str = sprintf('RMSE(ax) = %.4f | RMSE(az) = %.4f', rmse_1, rmse_2);

            ylabel(ax4_1, 'ax'); ylabel(ax4_2, 'az');

            title(ax4_1, 'Đối chiếu trục X (ax)');

            title(ax4_2, 'Đối chiếu trục Z (az)');

            title(ax4_1, sprintf('Đối chiếu trục X (ax) | Bias Cx: %.4f', C_vec(1)));

            title(ax4_2, sprintf('Đối chiếu trục Z (az) | Bias Cz: %.4f', C_vec(2)));

            txtRx.Value = r_sol_mm(1);

            txtRz.Value = r_sol_mm(2);

        else

            res_str = sprintf('r_y = %.2f mm, r_z = %.2f mm', r_sol_mm(1), r_sol_mm(2));

            rmse_str = sprintf('RMSE(ay) = %.4f | RMSE(az) = %.4f', rmse_1, rmse_2);

            ylabel(ax4_1, 'ay'); ylabel(ax4_2, 'az');

            title(ax4_1, 'Đối chiếu trục Y (ay)');

            title(ax4_2, 'Đối chiếu trục Z (az)');

            title(ax4_1, sprintf('Đối chiếu trục Y (ay) | Bias Cy: %.4f', C_vec(1)));

            title(ax4_2, sprintf('Đối chiếu trục Z (az) | Bias Cz: %.4f', C_vec(2)));

            txtRy.Value = r_sol_mm(1);

            txtRz.Value = r_sol_mm(2);

        end

            

            a_c = a_p + M_k * r_m;

            

            % Add bias C if we want a complete reconstruction matching the IMU measurements

            % Wait, the Export step (Phase 3) aims to generate "Simulated Head".

            % If we want Simulated Head to perfectly match Real Head, we should add C_vec.

            % However, C_vec is a sensor bias. To have a clean Kinematic simulation, we shouldn't add C_vec.

            % We will just output the clean kinematic acceleration.

            

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
