function gui_torque_motion()
% GUI_TORQUE_MOTION  Giao diện tính toán & trực quan hóa Moment Động cơ 6-RUS Stewart CKAS
%
% Tự động tính toán toàn bộ:
%   - Biểu đồ Moment động cơ tau(t) (N.m)
%   - Biểu đồ Góc quay động cơ phi(t) (độ)
%   - Biểu đồ Vận tốc góc động cơ q_dot(t) (RPM)
%   - Mô hình 3D bệ Stewart chuyển động theo thời gian
%   - Thống kê Peak / RMS Torque để chọn động cơ
%   - Lực tại khớp U (Ci) và khớp S (Bi') cho 6 chân

    % 1. Khởi tạo cửa sổ GUI chính
    fig = uifigure('Name', 'Tính toán & Trực quan hóa Moment Động cơ 6-RUS CKAS', ...
        'Position', [50 50 1280 760], 'Color', [0.96 0.96 0.97]);

    % Màu sắc đại diện cho 6 Động cơ
    colors_motor = [
        0.8500  0.3250  0.0980;  % M1: Cam
        0.0000  0.4470  0.7410;  % M2: Xanh dương
        0.4660  0.6740  0.1880;  % M3: Xanh lá
        0.4940  0.1840  0.5560;  % M4: Tím
        0.9290  0.6940  0.1250;  % M5: Vàng đậm
        0.3010  0.7450  0.9330   % M6: Xanh ngọc
    ];

    % 2. Cấu hình Tham số Cơ khí CKAS mặc định
    ra = 589.66; rb = 429.566; alpha1 = 19.45; beta1 = 53.32; da = 38.9; db = 13.37;
    [A_mat, B_mat, gamma_ang] = calc_Geometry(ra, rb, alpha1, beta1, da, db);
    L1 = 150; L2 = 747;

    % Biến toàn cục trong GUI
    trajData  = [];
    isPlaying = false;
    isPaused  = false;
    currentIdx = 1;

    %% --- PANEL ĐIỀU KHIỂN (BÊN TRÁI) ---
    pnl_ctrl = uipanel(fig, 'Title', '⚙ QUẢN LÝ QUỸ ĐẠO & THAM SỐ', ...
        'Position', [15 15 340 730], 'BackgroundColor', 'w', ...
        'FontWeight', 'bold', 'FontSize', 12, 'ForegroundColor', [0.1 0.2 0.4]);

    % Section 1: Chọn Nguồn Quỹ Đạo
    uilabel(pnl_ctrl, 'Text', '1. Nạp Quỹ Đạo Chuyển Động:', ...
        'Position', [15 678 250 20], 'FontWeight', 'bold', 'FontSize', 11);
    dd_source = uidropdown(pnl_ctrl, ...
        'Items', {'Quỹ đạo Mẫu: Heave Sin (z)', 'Quỹ đạo Mẫu: Roll/Pitch Sin', ...
                  'Quỹ đạo Mẫu: Triangular Vel', 'File Import (CSV / TXT / MAT)'}, ...
        'Position', [15 648 310 26], 'Value', 'Quỹ đạo Mẫu: Heave Sin (z)', ...
        'ValueChangedFcn', @(~,~) onSourceChanged());
    btn_browse = uibutton(pnl_ctrl, 'Text', '📁 Browse File Trajectory', ...
        'Position', [15 610 310 30], 'BackgroundColor', [0.2 0.5 0.8], ...
        'FontColor', 'w', 'FontWeight', 'bold', 'Enable', 'off', ...
        'ButtonPushedFcn', @(~,~) browseTrajectoryFile());
    lbl_file_info = uilabel(pnl_ctrl, 'Text', 'Trạng thái: Đang dùng quỹ đạo mẫu', ...
        'Position', [15 588 310 18], 'FontSize', 9, 'FontAngle', 'italic', ...
        'FontColor', [0.3 0.3 0.3]);

    % Section 2: Tham số Động Lực Học
    uilabel(pnl_ctrl, 'Text', '2. Tham số Động Lực Học:', ...
        'Position', [15 562 250 20], 'FontWeight', 'bold', 'FontSize', 11);

    uilabel(pnl_ctrl, 'Text', 'Khối lượng bệ động (kg):', 'Position', [15 538 165 20]);
    edt_mass = uieditfield(pnl_ctrl, 'numeric', 'Position', [182 538 143 22], 'Value', 30.0, ...
        'Limits', [1 500], 'ValueChangedFcn', @(~,~) recalculateTrajectory());

    uilabel(pnl_ctrl, 'Text', 'Home Z bệ động (mm):', 'Position', [15 512 165 20]);
    edt_homez = uieditfield(pnl_ctrl, 'numeric', 'Position', [182 512 143 22], 'Value', -75.0, ...
        'Limits', [-500 500], 'ValueChangedFcn', @(~,~) recalculateTrajectory());

    uilabel(pnl_ctrl, 'Text', 'Inertia Rotor (kg.m²):', 'Position', [15 486 165 20]);
    edt_irotor = uieditfield(pnl_ctrl, 'numeric', 'Position', [182 486 143 22], 'Value', 0.005, ...
        'Limits', [0.0001 5], 'ValueChangedFcn', @(~,~) recalculateTrajectory(), ...
        'Tooltip', 'Chỉ quán tính rotor động cơ (không gồm tay quay)');

    % Section 2b: Khối lượng tay quay & thanh truyền
    uipanel(pnl_ctrl, 'Title', '2b. Khối lượng Tay Quay & Thanh Truyền', ...
        'Position', [10 380 320 100], 'BackgroundColor', [0.97 0.97 1.0], ...
        'FontWeight', 'bold', 'FontSize', 10);

    uilabel(pnl_ctrl, 'Text', 'Tay quay L1 m_arm (kg):', 'Position', [18 440 165 20]);
    edt_marm = uieditfield(pnl_ctrl, 'numeric', 'Position', [190 440 130 22], 'Value', 1.585, ...
        'Limits', [0 50], 'ValueChangedFcn', @(~,~) recalculateTrajectory(), ...
        'Tooltip', 'Khối lượng tay quay L1 — tính I_arm = m*L1²/3 và tau_grav_arm');

    uilabel(pnl_ctrl, 'Text', 'Thanh truyền L2 m_rod (kg):', 'Position', [18 412 165 20]);
    edt_mrod = uieditfield(pnl_ctrl, 'numeric', 'Position', [190 412 130 22], 'Value', 0.0, ...
        'Limits', [0 50], 'ValueChangedFcn', @(~,~) recalculateTrajectory(), ...
        'Tooltip', 'Khối lượng thanh truyền L2 — tính I_rod, tau_grav_rod, lực khớp Ci/Bi');

    % Nút Load Simscape & Tính Toán
    uibutton(pnl_ctrl, 'Text', '📥 Nạp từ Simscape (smiData)', ...
        'Position', [15 353 310 24], 'BackgroundColor', [0.4 0.2 0.7], ...
        'FontColor', 'w', 'FontWeight', 'bold', ...
        'ButtonPushedFcn', @(~,~) loadFromSimscape());

    uibutton(pnl_ctrl, 'Text', '🔄 Tính Toán Lại Moment', ...
        'Position', [15 322 310 26], 'BackgroundColor', [0.1 0.6 0.3], ...
        'FontColor', 'w', 'FontWeight', 'bold', ...
        'ButtonPushedFcn', @(~,~) recalculateTrajectory());

    % Section 3: Điều Khiển Phát
    uilabel(pnl_ctrl, 'Text', '3. Điều Khiển Phát Quỹ Đạo:', ...
        'Position', [15 296 250 20], 'FontWeight', 'bold', 'FontSize', 11);

    uibutton(pnl_ctrl, 'Text', '▶ Play', 'Position', [15 266 95 30], ...
        'BackgroundColor', [0.1 0.6 0.3], 'FontColor', 'w', 'FontWeight', 'bold', ...
        'ButtonPushedFcn', @(~,~) playTrajectory());
    btn_pause = uibutton(pnl_ctrl, 'Text', '⏸ Pause', 'Position', [120 266 95 30], ...
        'BackgroundColor', [0.9 0.6 0.1], 'FontColor', 'w', 'FontWeight', 'bold', ...
        'ButtonPushedFcn', @(~,~) pauseTrajectory());
    uibutton(pnl_ctrl, 'Text', '⏹ Stop', 'Position', [225 266 100 30], ...
        'BackgroundColor', [0.8 0.2 0.2], 'FontColor', 'w', 'FontWeight', 'bold', ...
        'ButtonPushedFcn', @(~,~) stopTrajectory());

    uilabel(pnl_ctrl, 'Text', 'Tốc độ mô phỏng:', 'Position', [15 238 120 20]);
    dd_speed = uidropdown(pnl_ctrl, 'Items', {'0.25x','0.5x','1.0x','2.0x','5.0x'}, ...
        'Position', [140 238 185 22], 'Value', '1.0x');

    uilabel(pnl_ctrl, 'Text', 'Thanh trượt thời gian t (s):', 'Position', [15 216 200 20]);
    sld_time = uislider(pnl_ctrl, 'Position', [25 205 290 3], 'Limits', [0 1], 'Value', 0, ...
        'ValueChangedFcn', @(sld,~) onSliderSeek(sld.Value));

    % Section 4: Monitor Thời Gian Thực
    pnl_mon = uipanel(pnl_ctrl, 'Title', '📊 MONITOR THỜI GIAN THỰC', ...
        'Position', [10 10 320 185], 'BackgroundColor', '#f8f9fa', ...
        'FontWeight', 'bold', 'FontSize', 10);

    lbl_t_val   = uilabel(pnl_mon, 'Text', 'Thời gian t: 0.00 s / 0.00 s',  'Position', [10 145 300 18], 'FontWeight','bold');
    lbl_pose    = uilabel(pnl_mon, 'Text', 'Pose: [0,0,0] mm | [0,0,0]°',    'Position', [10 122 300 18]);
    lbl_max_tau = uilabel(pnl_mon, 'Text', 'Max Moment: 0.00 N.m (M1)',       'Position', [10 99 300 18], 'FontColor',[0.8 0.1 0.1],'FontWeight','bold');
    lbl_max_rpm = uilabel(pnl_mon, 'Text', 'Max RPM: 0.00 RPM (M1)',          'Position', [10 76 300 18], 'FontColor',[0.1 0.4 0.8],'FontWeight','bold');
    uilabel(pnl_mon, 'Text', 'Moment τ₁..₆ (N.m):',                           'Position', [10 53 300 16], 'FontSize',9);
    lbl_tau_vec = uilabel(pnl_mon, 'Text', 'M1..6: 0.0|0.0|0.0|0.0|0.0|0.0', 'Position', [10 34 300 18], ...
        'FontName','Consolas','FontSize',10,'FontWeight','bold','FontColor',[0.1 0.3 0.6]);
    lbl_status_global = uilabel(pnl_mon, 'Text', 'Trạng thái: Đã sẵn sàng',   'Position', [10 6 300 24], ...
        'FontWeight','bold','FontSize',11,'FontColor',[0.1 0.6 0.2]);

    %% --- KHU VỰC TAB ĐỒ THỊ (BÊN PHẢI) ---
    tab_group = uitabgroup(fig, 'Position', [370 15 895 730]);

    % TAB 1: Moment & Động học
    tab_plots = uitab(tab_group, 'Title', '📈 MOMENT & ĐỘNG HỌC');
    ax_tau  = uiaxes(tab_plots, 'Position', [55 480 820 210]);
    title(ax_tau,  'Moment Động Cơ τ(t) (N.m)');
    xlabel(ax_tau, 'Thời gian (s)'); ylabel(ax_tau, 'Moment (N.m)'); grid(ax_tau, 'on');

    ax_qdeg = uiaxes(tab_plots, 'Position', [55 250 820 190]);
    title(ax_qdeg, 'Góc Quay Động Cơ φ(t) (°)');
    xlabel(ax_qdeg,'Thời gian (s)'); ylabel(ax_qdeg,'Góc (°)'); grid(ax_qdeg,'on');

    ax_qdot = uiaxes(tab_plots, 'Position', [55 20 820 190]);
    title(ax_qdot, 'Vận Tốc Góc Động Cơ ω(t) (RPM)');
    xlabel(ax_qdot,'Thời gian (s)'); ylabel(ax_qdot,'RPM'); grid(ax_qdot,'on');

    % TAB 2: Mô hình 3D
    tab_3d = uitab(tab_group, 'Title', '🎲 MÔ HÌNH 3D STEWART');
    ax_3d  = uiaxes(tab_3d, 'Position', [20 20 850 670]);
    title(ax_3d,'Mô hình 3D Bệ Stewart');
    xlabel(ax_3d,'X (mm)'); ylabel(ax_3d,'Y (mm)'); zlabel(ax_3d,'Z (mm)');
    grid(ax_3d,'on'); hold(ax_3d,'on'); view(ax_3d,3);
    set(ax_3d,'ZDir','reverse','YDir','reverse');
    xlim(ax_3d,[-800 800]); ylim(ax_3d,[-800 800]); zlim(ax_3d,[-1700 800]);

    % TAB 3: Lực tại khớp Ci và Bi'
    tab_force = uitab(tab_group, 'Title', '🔩 LỰC TẠI KHỚP Ci / Bi''');

    ax_fCi = uiaxes(tab_force, 'Position', [55 490 820 200]);
    title(ax_fCi, 'Lực tại khớp U — Ci (N)   [Khớp giữa tay quay và thanh truyền]');
    xlabel(ax_fCi,'Thời gian (s)'); ylabel(ax_fCi,'||F_{Ci}|| (N)'); grid(ax_fCi,'on');

    ax_fBi = uiaxes(tab_force, 'Position', [55 265 820 200]);
    title(ax_fBi, 'Lực tại khớp S — Bi'' (N)   [Khớp giữa thanh truyền và bệ]');
    xlabel(ax_fBi,'Thời gian (s)'); ylabel(ax_fBi,'||F_{B_i}''|| (N)'); grid(ax_fBi,'on');

    ax_frod = uiaxes(tab_force, 'Position', [55 40 820 190]);
    title(ax_frod, 'Lực dọc trục thanh truyền f_i (N)   [+ = kéo, - = nén]');
    xlabel(ax_frod,'Thời gian (s)'); ylabel(ax_frod,'f_i (N)'); grid(ax_frod,'on');

    % Label giải thích công thức
    uilabel(tab_force, 'Text', ...
        ['I_total = I_rotor + m_arm·L1²/3 + m_rod·(L1/2)²  |  ' ...
         'τ_grav = -(m_arm+m_rod)·g·(L1/2)·cos(q_i)  |  ' ...
         'F_Bi = f_i·ŝ_i − m_rod/2·(a_G−g)'], ...
        'Position', [20 8 850 20], 'FontSize', 9, 'FontColor', [0.4 0.4 0.4]);

    % TAB 4: Bảng thống kê
    tab_stat = uitab(tab_group, 'Title', '📋 THỐNG KÊ PEAK');
    tbl_stat = uitable(tab_stat, 'Position', [20 100 850 580], ...
        'ColumnName', {'Động cơ','τ_max (N.m)','τ_min (N.m)','τ_rms (N.m)', ...
                       'RPM max','φ_max (°)','φ_min (°)', ...
                       '|FCi| max (N)','|FBi| max (N)','f_rod max (N)'}, ...
        'ColumnFormat', {'char','numeric','numeric','numeric','numeric','numeric','numeric','numeric','numeric','numeric'}, ...
        'RowName', []);

    uibutton(tab_stat, 'Text', '💾 Xuất Kết Quả CSV', ...
        'Position', [20 30 250 40], 'BackgroundColor', [0.1 0.5 0.8], ...
        'FontColor','w','FontWeight','bold','FontSize',12, ...
        'ButtonPushedFcn', @(~,~) exportResultsCSV());

    %% --- KHỞI TẠO ---
    generateBuiltInTrajectory('Heave Sin (z)');


    %% ====================================================================
    %% HÀM XỬ LÝ SỰ KIỆN
    %% ====================================================================

    function onSourceChanged()
        val = dd_source.Value;
        if strcmp(val, 'File Import (CSV / TXT / MAT)')
            btn_browse.Enable = 'on';
        else
            btn_browse.Enable = 'off';
            lbl_file_info.Text = ['Trạng thái: Dùng ' val];
            generateBuiltInTrajectory(val);
        end
    end

    function browseTrajectoryFile()
        [file, path] = uigetfile({'*.csv;*.txt;*.mat','Trajectory Files (*.csv,*.txt,*.mat)'});
        if isequal(file,0), return; end
        full_path = fullfile(path, file);
        lbl_file_info.Text = ['File: ' file];
        try
            parseAndLoadFile(full_path);
        catch ME
            uialert(fig, ['Lỗi đọc file: ' ME.message], 'Lỗi File');
        end
    end

    function parseAndLoadFile(filePath)
        [~,~,ext] = fileparts(filePath);
        if strcmpi(ext,'.mat')
            mat_data = load(filePath);
            fnames = fieldnames(mat_data);
            raw = mat_data.(fnames{1});
        else
            fid  = fopen(filePath,'r');
            raw_lines = textscan(fid,'%s','Delimiter','\n'); fclose(fid);
            lines = raw_lines{1};
            raw   = zeros(length(lines),7);
            valid_cnt = 0;
            for i = 1:length(lines)
                line = lines{i};
                if isempty(strtrim(line)), continue; end
                line = strrep(line,'~M[',' '); line = strrep(line,']',' ');
                line = strrep(line,char(9),' ');
                line = regexprep(line,'-\s+','-');
                nums = sscanf(line,'%f');
                if length(nums) >= 7
                    valid_cnt = valid_cnt + 1;
                    raw(valid_cnt,:) = nums(1:7)';
                end
            end
            raw = raw(1:valid_cnt,:);
        end
        if isempty(raw) || size(raw,2) < 7
            error('File không đủ 7 cột dữ liệu.');
        end
        t_raw    = raw(:,1);
        raw_input = [raw(:,2), raw(:,3), raw(:,4), raw(:,5), raw(:,6), raw(:,7)];
        processTrajectory(t_raw, raw_input);
    end

    function loadFromSimscape()
        try
            [m_p, ~, m_arm_sc, I_arm_sc] = load_simscape_params();
            edt_mass.Value   = m_p;
            edt_marm.Value   = m_arm_sc;
            % I_rotor = I_arm_Simscape - I_arm_lý_thuyết
            L1_m = L1/1000;
            I_arm_theory = m_arm_sc * L1_m^2 / 3.0;
            edt_irotor.Value = max(0.001, I_arm_sc - I_arm_theory);
            recalculateTrajectory();
            uialert(fig, sprintf(['Đã nạp từ Simscape:\n' ...
                '• Khối lượng bệ: %.4f kg\n' ...
                '• m_arm: %.4f kg\n' ...
                '• I_rotor (= I_arm_sc − m_arm·L1²/3): %.5f kg.m²'], ...
                m_p, m_arm_sc, edt_irotor.Value), 'Nạp Simscape OK');
        catch ME
            uialert(fig,['Lỗi Simscape: ' ME.message],'Lỗi');
        end
    end

    function generateBuiltInTrajectory(typeStr)
        dt = 0.01; t = (0:dt:4.0)'; N = length(t);
        x_r=zeros(N,1); y_r=zeros(N,1); z_r=zeros(N,1);
        rl_r=zeros(N,1); pt_r=zeros(N,1); yw_r=zeros(N,1);
        if contains(typeStr,'Heave')
            z_r = 40*sin(2*pi*0.8*t);
        elseif contains(typeStr,'Roll')
            rl_r = 8.0*sin(2*pi*0.5*t);
            pt_r = 6.0*cos(2*pi*0.5*t);
        elseif contains(typeStr,'Triangular')
            vx = 30;
            for k = 1:N
                tk = t(k);
                if tk <= 2.0, x_r(k) = 0.5*(vx/2)*tk^2;
                else, rem_t=tk-2.0; x_r(k) = 30+vx*rem_t-0.5*(vx/2)*rem_t^2; end
            end
        end
        raw_input = [x_r, y_r, z_r, yw_r, pt_r, rl_r];
        processTrajectory(t, raw_input);
    end

    function recalculateTrajectory()
        if isempty(trajData), return; end
        processTrajectory(trajData.t, trajData.raw_input);
    end

    function processTrajectory(t_vec, raw_input_matrix)
        lbl_status_global.Text = 'Đang tính toán...'; drawnow;

        N      = length(t_vec);
        Home_Z = edt_homez.Value;
        P_0    = [0; 0; Home_Z];

        x_r=raw_input_matrix(:,1); y_r=raw_input_matrix(:,2); z_r=raw_input_matrix(:,3);
        yw_r=raw_input_matrix(:,4); pt_r=raw_input_matrix(:,5); rl_r=raw_input_matrix(:,6);

        pose_matrix = zeros(N,6);
        for k = 1:N
            R_k = calcRotationMatrix_local(yw_r(k), pt_r(k), rl_r(k));
            P_file = [x_r(k); y_r(k); z_r(k)];
            pos_plat = P_0 + R_k * P_file;
            pose_matrix(k,:) = [pos_plat(1), pos_plat(2), pos_plat(3), rl_r(k), pt_r(k), yw_r(k)];
        end
        drawnow;

        m_p      = edt_mass.Value;
        I_rotor  = edt_irotor.Value;
        m_arm    = edt_marm.Value;
        m_rod    = edt_mrod.Value;
        I_p      = [9.85, 19.65, 9.85];

        vel_matrix   = zeros(N,6);
        accel_matrix = zeros(N,6);
        for c = 1:6
            vel_matrix(:,c)   = gradient(pose_matrix(:,c), t_vec);
            accel_matrix(:,c) = gradient(vel_matrix(:,c), t_vec);
        end

        tau_hist   = zeros(N,6);
        qdeg_hist  = zeros(N,6);
        qdot_hist  = zeros(N,6);
        qddot_hist = zeros(N,6);
        % Lực khớp
        fCi_hist  = zeros(N,6);   % ||F_Ci|| cho 6 chân
        fBi_hist  = zeros(N,6);   % ||F_Bi'|| cho 6 chân
        frod_hist = zeros(N,6);   % lực dọc trục f_i

        for k = 1:N
            pk = pose_matrix(k,:);
            vk = vel_matrix(k,:);
            ak = accel_matrix(k,:);

            % Tính moment và lực khớp
            try
                [tau_k, ~, ~, F_Ci_k, F_Bi_k, f_rod_k] = tinh_torque( ...
                    pk, vk, ak, A_mat, B_mat, L1, L2, gamma_ang, ...
                    m_p, I_p, I_rotor, m_arm, m_rod);
            catch
                tau_k   = zeros(6,1);
                F_Ci_k  = zeros(3,6);
                F_Bi_k  = zeros(3,6);
                f_rod_k = zeros(6,1);
            end

            % Vận tốc góc & gia tốc góc
            try
                [~, q_dot_k, q_ddot_k] = jacobian_motor( ...
                    pk, vk, ak, A_mat, B_mat, L1, L2, gamma_ang);
            catch
                q_dot_k = zeros(6,1); q_ddot_k = zeros(6,1);
            end

            % Góc thực động cơ
            phi_k = donghocnguoc_final1(pk, A_mat, B_mat, L1, L2, gamma_ang);

            tau_hist(k,:)   = tau_k';
            qdot_hist(k,:)  = (q_dot_k * 30/pi)';
            qddot_hist(k,:) = q_ddot_k';
            qdeg_hist(k,:)  = phi_k;
            fCi_hist(k,:)   = sqrt(sum(F_Ci_k.^2, 1));
            fBi_hist(k,:)   = sqrt(sum(F_Bi_k.^2, 1));
            frod_hist(k,:)  = f_rod_k';
        end

        % Lưu toàn bộ
        trajData.t          = t_vec;
        trajData.raw_input  = raw_input_matrix;
        trajData.pose       = pose_matrix;
        trajData.vel        = vel_matrix;
        trajData.accel      = accel_matrix;
        trajData.tau        = tau_hist;
        trajData.qdeg       = qdeg_hist;
        trajData.qdot       = qdot_hist;
        trajData.qddot      = qddot_hist;
        trajData.fCi        = fCi_hist;
        trajData.fBi        = fBi_hist;
        trajData.frod       = frod_hist;

        sld_time.Limits = [t_vec(1) t_vec(end)];
        sld_time.Value  = t_vec(1);
        currentIdx = 1;

        plotStaticCurves();
        updateTableStatistics();
        updateInstantaneousDisplay(1);

        lbl_status_global.Text     = 'Trạng thái: Tính xong!';
        lbl_status_global.FontColor = [0.1 0.6 0.2];
    end

    function plotStaticCurves()
        if isempty(trajData), return; end
        t = trajData.t;

        % Đồ thị Moment
        cla(ax_tau); hold(ax_tau,'on');
        for i = 1:6
            plot(ax_tau, t, trajData.tau(:,i), 'LineWidth',1.5, 'Color',colors_motor(i,:), ...
                'DisplayName', sprintf('M%d',i));
        end
        xlabel(ax_tau,'Thời gian (s)'); ylabel(ax_tau,'Moment (N.m)');
        title(ax_tau,'Moment Động Cơ τ(t)');
        legend(ax_tau,'Location','best'); grid(ax_tau,'on'); hold(ax_tau,'off');

        % Đồ thị Góc
        cla(ax_qdeg); hold(ax_qdeg,'on');
        for i = 1:6
            plot(ax_qdeg, t, trajData.qdeg(:,i), 'LineWidth',1.5, 'Color',colors_motor(i,:), ...
                'DisplayName', sprintf('M%d',i));
        end
        xlabel(ax_qdeg,'Thời gian (s)'); ylabel(ax_qdeg,'Góc (°)');
        title(ax_qdeg,'Góc Quay Động Cơ φ(t)');
        legend(ax_qdeg,'Location','best'); grid(ax_qdeg,'on'); hold(ax_qdeg,'off');

        % Đồ thị Vận tốc
        cla(ax_qdot); hold(ax_qdot,'on');
        for i = 1:6
            plot(ax_qdot, t, trajData.qdot(:,i), 'LineWidth',1.5, 'Color',colors_motor(i,:), ...
                'DisplayName', sprintf('M%d',i));
        end
        xlabel(ax_qdot,'Thời gian (s)'); ylabel(ax_qdot,'RPM');
        title(ax_qdot,'Vận Tốc Góc Động Cơ ω(t)');
        legend(ax_qdot,'Location','best'); grid(ax_qdot,'on'); hold(ax_qdot,'off');

        % Đồ thị lực khớp Ci
        cla(ax_fCi); hold(ax_fCi,'on');
        for i = 1:6
            plot(ax_fCi, t, trajData.fCi(:,i), 'LineWidth',1.5, 'Color',colors_motor(i,:), ...
                'DisplayName', sprintf('Chân %d',i));
        end
        xlabel(ax_fCi,'Thời gian (s)'); ylabel(ax_fCi,'||F_{Ci}|| (N)');
        title(ax_fCi,'Lực tại khớp U — Ci(t)  [Khớp tay quay – thanh truyền]');
        legend(ax_fCi,'Location','best'); grid(ax_fCi,'on'); hold(ax_fCi,'off');

        % Đồ thị lực khớp Bi'
        cla(ax_fBi); hold(ax_fBi,'on');
        for i = 1:6
            plot(ax_fBi, t, trajData.fBi(:,i), 'LineWidth',1.5, 'Color',colors_motor(i,:), ...
                'DisplayName', sprintf('Chân %d',i));
        end
        xlabel(ax_fBi,'Thời gian (s)'); ylabel(ax_fBi,'||F_{Bi}''|| (N)');
        title(ax_fBi,'Lực tại khớp S — Bi''(t)  [Khớp thanh truyền – bệ]');
        legend(ax_fBi,'Location','best'); grid(ax_fBi,'on'); hold(ax_fBi,'off');

        % Đồ thị lực dọc trục thanh truyền
        cla(ax_frod); hold(ax_frod,'on');
        for i = 1:6
            plot(ax_frod, t, trajData.frod(:,i), 'LineWidth',1.5, 'Color',colors_motor(i,:), ...
                'DisplayName', sprintf('Chân %d',i));
        end
        yline(ax_frod, 0, '--k', 'LineWidth', 0.8);
        xlabel(ax_frod,'Thời gian (s)'); ylabel(ax_frod,'f_i (N)');
        title(ax_frod,'Lực dọc trục thanh truyền f_i(t)  [+ kéo / − nén]');
        legend(ax_frod,'Location','best'); grid(ax_frod,'on'); hold(ax_frod,'off');
    end

    function updateTableStatistics()
        if isempty(trajData), return; end
        tau  = trajData.tau;
        qdot = trajData.qdot;
        qdeg = trajData.qdeg;
        fCi  = trajData.fCi;
        fBi  = trajData.fBi;
        frod = trajData.frod;

        table_cell = cell(6,10);
        for i = 1:6
            table_cell{i,1}  = sprintf('Motor %d',i);
            table_cell{i,2}  = max(tau(:,i));
            table_cell{i,3}  = min(tau(:,i));
            table_cell{i,4}  = sqrt(mean(tau(:,i).^2));
            table_cell{i,5}  = max(abs(qdot(:,i)));
            table_cell{i,6}  = max(qdeg(:,i));
            table_cell{i,7}  = min(qdeg(:,i));
            table_cell{i,8}  = max(fCi(:,i));
            table_cell{i,9}  = max(fBi(:,i));
            table_cell{i,10} = max(abs(frod(:,i)));
        end
        tbl_stat.Data = table_cell;
    end

    function updateInstantaneousDisplay(idx)
        if isempty(trajData), return; end
        idx = max(1, min(idx, length(trajData.t)));
        currentIdx = idx;

        t_cur   = trajData.t(idx);
        t_max   = trajData.t(end);
        p_cur   = trajData.pose(idx,:);
        tau_cur = trajData.tau(idx,:);
        rpm_cur = trajData.qdot(idx,:);

        lbl_t_val.Text = sprintf('Thời gian t: %.2f s / %.2f s', t_cur, t_max);
        lbl_pose.Text  = sprintf('Pose: [%.1f,%.1f,%.1f] mm | [%.1f,%.1f,%.1f]°', ...
            p_cur(1),p_cur(2),p_cur(3),p_cur(4),p_cur(5),p_cur(6));

        [~,max_t_idx] = max(abs(tau_cur));
        lbl_max_tau.Text = sprintf('Max Moment: %.2f N.m (M%d)', tau_cur(max_t_idx), max_t_idx);
        [~,max_r_idx] = max(abs(rpm_cur));
        lbl_max_rpm.Text = sprintf('Max RPM: %.1f RPM (M%d)', rpm_cur(max_r_idx), max_r_idx);

        lbl_tau_vec.Text = sprintf('τ₁..₆: %.1f|%.1f|%.1f|%.1f|%.1f|%.1f', ...
            tau_cur(1),tau_cur(2),tau_cur(3),tau_cur(4),tau_cur(5),tau_cur(6));
        sld_time.Value = t_cur;
        draw3DStewartModel(p_cur);
    end

    function draw3DStewartModel(pose)
        cla(ax_3d); lighting(ax_3d,'gouraud'); material(ax_3d,'dull'); hold(ax_3d,'on');
        colorBase=[0.8 0.8 0]; colorPlatform=[0 0.6 0];
        colorL1=[0.4 0.4 0.4]; colorL2=[0.8 0 0];
        rL1=18; rL2=12; Np=16;

        fill3(ax_3d, A_mat(1,:),A_mat(2,:),A_mat(3,:), colorBase,'FaceAlpha',0.8,'EdgeColor','k');
        R = calcRotationMatrix_local(pose(6),pose(5),pose(4));
        T = pose(1:3)';
        B_global = zeros(3,6);
        for i=1:6, B_global(:,i) = T + R*B_mat(:,i); end
        fill3(ax_3d, B_global(1,:),B_global(2,:),B_global(3,:), colorPlatform,'FaceAlpha',0.9,'EdgeColor','b');

        for i = 1:6
            A_i = A_mat(:,i); P_i = B_global(:,i);
            Lx=P_i(1)-A_i(1); Ly=P_i(2)-A_i(2); Lz=P_i(3)-A_i(3);
            Q_v=Lx^2+Ly^2+Lz^2-L2^2+L1^2; M_v=2*L1*Lz;
            N_v=2*L1*(cosd(gamma_ang(i))*Lx+sind(gamma_ang(i))*Ly);
            denom=sqrt(M_v^2+N_v^2);
            if denom>1e-9
                arg_v=max(-1,min(1,Q_v/denom));
                phi=asind(arg_v)-atan2d(N_v,M_v);
            else
                phi=0;
            end
            Cx=A_i(1)+L1*cosd(gamma_ang(i))*cosd(phi);
            Cy=A_i(2)+L1*sind(gamma_ang(i))*cosd(phi);
            Cz=A_i(3)+L1*sind(phi);
            C_i=[Cx;Cy;Cz];
            draw_cylinder(ax_3d,A_i,C_i,rL1,Np,colorL1);
            draw_cylinder(ax_3d,C_i,P_i,rL2,Np,colorL2);
            text(ax_3d,A_i(1),A_i(2),A_i(3)-35,sprintf('A%d',i),'Color','k','FontSize',9,'FontWeight','bold','HorizontalAlignment','center');
            text(ax_3d,C_i(1),C_i(2),C_i(3)+20,sprintf('C%d',i),'Color',[0.5 0.5 0.5],'FontSize',8,'HorizontalAlignment','center');
            text(ax_3d,P_i(1),P_i(2),P_i(3)+35,sprintf('B%d',i),'Color','b','FontSize',9,'FontWeight','bold','HorizontalAlignment','center');
        end

        xlabel(ax_3d,'X (mm)'); ylabel(ax_3d,'Y (mm)'); zlabel(ax_3d,'Z (mm)');
        title(ax_3d,sprintf('3D  |  Z=%.1f mm  Roll=%.1f°  Pitch=%.1f°',pose(3),pose(4),pose(5)));
        grid(ax_3d,'on');
        set(ax_3d,'ZDir','reverse','YDir','reverse');
        xlim(ax_3d,[-800 800]); ylim(ax_3d,[-800 800]); zlim(ax_3d,[-1700 800]);
        camlight(ax_3d,'headlight'); hold(ax_3d,'off');
    end

    function draw_cylinder(ax, p1, p2, radius, npts, color)
        len = norm(p2-p1);
        if len<1e-6, return; end
        [Xc,Yc,Zc] = cylinder(radius, npts);
        Zc = Zc*len;
        vec = (p2-p1)/len;
        if abs(vec(3))>0.999
            if vec(3)<0, Rv=eye(3)*-1; Rv(3,3)=1; else, Rv=eye(3); end
        else
            u_z=[0;0;1]; v_=cross(u_z,vec); s_=norm(v_); c_=dot(u_z,vec);
            Vx_=[0 -v_(3) v_(2); v_(3) 0 -v_(1); -v_(2) v_(1) 0];
            Rv=eye(3)+Vx_+Vx_^2*((1-c_)/s_^2);
        end
        for j = 1:npts+1
            r1=p1+Rv*[Xc(1,j);Yc(1,j);Zc(1,j)];
            r2=p1+Rv*[Xc(2,j);Yc(2,j);Zc(2,j)];
            Xc(1,j)=r1(1); Yc(1,j)=r1(2); Zc(1,j)=r1(3);
            Xc(2,j)=r2(1); Yc(2,j)=r2(2); Zc(2,j)=r2(3);
        end
        surf(ax,Xc,Yc,Zc,'FaceColor',color,'EdgeColor','none','FaceLighting','gouraud');
    end

    function playTrajectory()
        if isempty(trajData), return; end
        isPlaying=true; isPaused=false;
        speed_mult=str2double(strrep(dd_speed.Value,'x',''));
        N=length(trajData.t);
        while isPlaying && currentIdx<=N
            if isPaused, pause(0.1); continue; end
            updateInstantaneousDisplay(currentIdx); drawnow;
            if currentIdx<N
                dt=(trajData.t(currentIdx+1)-trajData.t(currentIdx))/speed_mult;
                pause(max(0.005,dt));
            end
            currentIdx=currentIdx+1;
        end
        isPlaying=false;
        if currentIdx>N, currentIdx=1; end
    end

    function pauseTrajectory()
        isPaused=~isPaused;
        if isPaused, btn_pause.Text='▶ Resume'; else, btn_pause.Text='⏸ Pause'; end
    end

    function stopTrajectory()
        isPlaying=false; isPaused=false; currentIdx=1; updateInstantaneousDisplay(1);
    end

    function onSliderSeek(val)
        if isempty(trajData), return; end
        [~,idx]=min(abs(trajData.t-val));
        updateInstantaneousDisplay(idx);
    end

    function exportResultsCSV()
        if isempty(trajData), return; end
        [file,path] = uiputfile('Stewart_Results.csv','Lưu báo cáo CSV');
        if isequal(file,0), return; end
        fid = fopen(fullfile(path,file),'w');
        fprintf(fid, ['Time_s,X_mm,Y_mm,Z_mm,Roll_deg,Pitch_deg,Yaw_deg,' ...
            'Tau1_Nm,Tau2_Nm,Tau3_Nm,Tau4_Nm,Tau5_Nm,Tau6_Nm,' ...
            'RPM1,RPM2,RPM3,RPM4,RPM5,RPM6,' ...
            'FCi1_N,FCi2_N,FCi3_N,FCi4_N,FCi5_N,FCi6_N,' ...
            'FBi1_N,FBi2_N,FBi3_N,FBi4_N,FBi5_N,FBi6_N,' ...
            'frod1_N,frod2_N,frod3_N,frod4_N,frod5_N,frod6_N\n']);
        N=length(trajData.t);
        for k=1:N
            fprintf(fid,'%.4f,%.2f,%.2f,%.2f,%.2f,%.2f,%.2f,', ...
                trajData.t(k),trajData.pose(k,1),trajData.pose(k,2),trajData.pose(k,3), ...
                trajData.pose(k,4),trajData.pose(k,5),trajData.pose(k,6));
            fprintf(fid,'%.3f,%.3f,%.3f,%.3f,%.3f,%.3f,', trajData.tau(k,:));
            fprintf(fid,'%.2f,%.2f,%.2f,%.2f,%.2f,%.2f,', trajData.qdot(k,:));
            fprintf(fid,'%.2f,%.2f,%.2f,%.2f,%.2f,%.2f,', trajData.fCi(k,:));
            fprintf(fid,'%.2f,%.2f,%.2f,%.2f,%.2f,%.2f,', trajData.fBi(k,:));
            fprintf(fid,'%.2f,%.2f,%.2f,%.2f,%.2f,%.2f\n', trajData.frod(k,:));
        end
        fclose(fid);
        uialert(fig,['Đã xuất: ' fullfile(path,file)],'Xuất CSV OK');
    end

    function R = calcRotationMatrix_local(yaw_deg, pitch_deg, roll_deg)
        cy=cosd(yaw_deg); sy=sind(yaw_deg);
        cp=cosd(pitch_deg); sp=sind(pitch_deg);
        cr=cosd(roll_deg); sr=sind(roll_deg);
        R=[cy*cp, cy*sp*sr-sy*cr, cy*sp*cr+sy*sr;
           sy*cp, sy*sp*sr+cy*cr, sy*sp*cr-cy*sr;
           -sp,   cp*sr,          cp*cr];
    end

end
