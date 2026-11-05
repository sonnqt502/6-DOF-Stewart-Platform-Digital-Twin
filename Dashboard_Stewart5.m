function Dashboard_Stewart5()
    % =====================================================================
    % 0. KHỞI TẠO BIẾN DÙNG CHUNG CỦA HỆ THỐNG
    % =====================================================================
    fig = uifigure('Name', 'Dashboard 5: Tích hợp Mô Phỏng & Điều Khiển Tay', 'Position', [100 100 1550 800], 'Color', 'w');
    % A_mat: Tọa độ tâm các khớp trên đế (Base) - ma trận 3x6 (mm)
    % B_mat: Tọa độ tâm các khớp trên bàn máy (Platform) - ma trận 3x6 (mm)
    % gamma_ang: Góc định hướng của mỗi chân (độ) - vector 1x6
    % L1_val, L2_val: Chiều dài tay đòn dưới và tay đòn trên (mm)
    A_mat = []; B_mat = []; gamma_ang = []; 
    L1_val = 150; 
    L2_val = 747;
    motor_min = -50;
    motor_max = 90;
    
    % Đọc config.json nếu có
    if isfile('config.json')
        try
            cfg_txt = fileread('config.json');
            cfg = jsondecode(cfg_txt);
            if isfield(cfg, 'motor_limit_min'), motor_min = cfg.motor_limit_min; end
            if isfield(cfg, 'motor_limit_max'), motor_max = cfg.motor_limit_max; end
        catch
        end
    end
    
    % Biến lưu trữ quỹ đạo sau khi kiểm định an toàn
    T_out = [];                         % Thời gian (s)
    Xp_out = []; Yp_out = []; Zp_out = []; % Tọa độ bàn máy (mm)
    Xv_out = []; Yv_out = []; Zv_out = []; % Tọa độ tâm quay Pivot (mm)
    Xh_out = []; Yh_out = []; Zh_out = []; % Tọa độ đầu người (mm)
    R_out = []; P_out = []; Yw_out = [];   % Góc Euler (Roll, Pitch, Yaw) (độ)
    Ax_out = []; Ay_out = []; Az_out = [];  % Gia tốc dài từ file (m/s²) (nếu có)
    Wx_out = []; Wy_out = []; Wz_out = [];  % Vận tốc góc từ file (rad/s) (nếu có)
    is_Validated = false;                  % Cờ đã kiểm định an toàn
    
    % Biến điều khiển trạng thái hoạt ảnh 3D
    is_Playing = false; 
    is_Paused = false;
    
    % =====================================================================
    % 1. KHỞI TẠO CỬA SỔ GIAO DIỆN CHÍNH (Giao diện App Designer)
    % =====================================================================
    m_help = uimenu(fig, 'Text', 'Trợ Giúp');
    uimenu(m_help, 'Text', 'Hướng dẫn sử dụng', 'MenuSelectedFcn', @(src,event) showHelpDialog());
    
    uilabel(fig, 'Text', 'TRUNG TÂM ĐIỀU KHIỂN & GIÁM SÁT STEWART PLATFORM', ...
        'Position', [380 760 600 30], 'FontSize', 18, 'FontWeight', 'bold', ...
        'FontColor', [0.6350 0.0780 0.1840]);
    
    % --- PANEL 1: CẤU HÌNH CƠ KHÍ ---
    % Các thông số hình học của Stewart Platform
    pnl_mech = uipanel(fig, 'Title', '1. Thông số Cơ khí', 'Position', [10 450 320 300], ...
        'BackgroundColor', 'w', 'FontWeight', 'bold');
    
    uilabel(pnl_mech, 'Interpreter', 'latex', 'Text', '$r_a$', 'Position', [5 245 25 30], 'FontSize', 15);
    uilabel(pnl_mech, 'Text', '(Đế):', 'Position', [28 250 40 22]);
    ed_ra = uieditfield(pnl_mech, 'numeric', 'Position', [70 250 70 22], 'Value', 589.66);
    
    uilabel(pnl_mech, 'Interpreter', 'latex', 'Text', '$r_b$', 'Position', [155 245 25 30], 'FontSize', 15);
    uilabel(pnl_mech, 'Text', '(Bàn):', 'Position', [178 250 45 22]);
    ed_rb = uieditfield(pnl_mech, 'numeric', 'Position', [230 250 70 22], 'Value', 429.566);
    
    uilabel(pnl_mech, 'Interpreter', 'latex', 'Text', '$L_1$', 'Position', [5 210 25 30], 'FontSize', 15);
    uilabel(pnl_mech, 'Text', '(Dưới):', 'Position', [28 215 42 22]);
    ed_l1 = uieditfield(pnl_mech, 'numeric', 'Position', [70 215 70 22], 'Value', 150);
    
    uilabel(pnl_mech, 'Interpreter', 'latex', 'Text', '$L_2$', 'Position', [155 210 25 30], 'FontSize', 15);
    uilabel(pnl_mech, 'Text', '(Trên):', 'Position', [178 215 50 22]);
    ed_l2 = uieditfield(pnl_mech, 'numeric', 'Position', [230 215 70 22], 'Value', 747);
    
    % Góc phân bố các chân trên đế
    uilabel(pnl_mech, 'Interpreter', 'latex', 'Text', '$\alpha_1$:', 'Position', [10 178 60 26], 'FontSize', 16);
    ed_a1 = uieditfield(pnl_mech, 'numeric', 'Position', [70 180 70 22], 'Value', 19.45);
    uilabel(pnl_mech, 'Interpreter', 'latex', 'Text', '$\delta_a$:', 'Position', [160 178 60 26], 'FontSize', 16);
    ed_da = uieditfield(pnl_mech, 'numeric', 'Position', [230 180 70 22], 'Value', 38.9);
    
    % Góc phân bố các chân trên bàn máy
    uilabel(pnl_mech, 'Interpreter', 'latex', 'Text', '$\beta_1$:', 'Position', [10 143 60 26], 'FontSize', 16);
    ed_b1 = uieditfield(pnl_mech, 'numeric', 'Position', [70 145 70 22], 'Value', 53.32);
    uilabel(pnl_mech, 'Interpreter', 'latex', 'Text', '$\delta_b$:', 'Position', [160 143 60 26], 'FontSize', 16);
    ed_db = uieditfield(pnl_mech, 'numeric', 'Position', [230 145 70 22], 'Value', 13.37);
    
    % Tọa độ đầu người trong hệ tọa độ gắn với bàn máy (mm)
    uilabel(pnl_mech, 'Text', 'Đầu người (X,Y,Z):', 'Position', [10 110 110 22], ...
        'FontColor', [0.4940 0.1840 0.5560], 'FontWeight', 'bold'); 
    ed_headX = uieditfield(pnl_mech, 'numeric', 'Position', [125 110 50 22], 'Value', 0);
    ed_headY = uieditfield(pnl_mech, 'numeric', 'Position', [180 110 50 22], 'Value', 0);
    ed_headZ = uieditfield(pnl_mech, 'numeric', 'Position', [235 110 50 22], 'Value', -762);
    
    uibutton(pnl_mech, 'Text', 'LƯU FILE', 'Position', [15 70 135 30], ...
        'BackgroundColor', [0.9290 0.6940 0.1250], 'FontWeight', 'bold', ...
        'ButtonPushedFcn', @(btn,event) saveConfig());
    uibutton(pnl_mech, 'Text', 'TẢI FILE', 'Position', [165 70 135 30], ...
        'BackgroundColor', [0.4660 0.6740 0.1880], 'FontColor', 'w', 'FontWeight', 'bold', ...
        'ButtonPushedFcn', @(btn,event) loadConfig());
    
    btn_config = uibutton(pnl_mech, 'Text', 'CẬP NHẬT CẤU HÌNH', 'Position', [60 30 200 35], ...
        'BackgroundColor', [0 0.4470 0.7410], 'FontColor', 'w', 'FontWeight', 'bold', ...
        'ButtonPushedFcn', @(btn,event) calcGeometry());
    lbl_status = uilabel(pnl_mech, 'Text', 'Chưa nạp thông số!', 'Position', [100 8 200 22], 'FontColor', 'r');
    
    % --- PANEL 2: ĐIỀU KHIỂN QUỸ ĐẠO & XUẤT FILE ---
    pnl_ctrl = uipanel(fig, 'Title', '2. Thiết lập Quỹ đạo & Xuất file', ...
        'Position', [10 10 320 380], 'BackgroundColor', 'w', 'FontWeight', 'bold');
    
    dd_traj = uidropdown(pnl_ctrl, 'Items', {'[1D] Tịnh tiến Z (Heave)', ...
        '[1D] Quay Pitch (Gật gù)', '[1D] Quay Roll (Lắc ngang)', '[2D] Đường tròn XY', '[3D] Cua chữ S (6 DOF)'}, ...
        'Position', [80 330 230 22]);
    
    uilabel(pnl_ctrl, 'Text', 'Tâm Sinh:', 'Position', [10 300 80 22]);
    dd_pivot = uidropdown(pnl_ctrl, 'Items', {'Đỉnh Đầu Người Lái', 'Tâm Bàn Máy', 'Tọa Độ Bất Kỳ'}, ...
        'Position', [80 300 130 22]);
    uilabel(pnl_ctrl, 'Text', 'Home Z:', 'Position', [220 300 50 22]);
    ed_homez = uieditfield(pnl_ctrl, 'numeric', 'Position', [265 300 45 22], 'Value', 0);
    
    uilabel(pnl_ctrl, 'Text', 'Pivot(X,Y,Z):', 'Position', [10 270 80 22], ...
        'FontColor', [0.85 0.32 0.09], 'FontWeight', 'bold');
    ed_px = uieditfield(pnl_ctrl, 'numeric', 'Position', [95 270 50 22], 'Value', 0);
    ed_py = uieditfield(pnl_ctrl, 'numeric', 'Position', [160 270 50 22], 'Value', 0);
    ed_pz = uieditfield(pnl_ctrl, 'numeric', 'Position', [225 270 50 22], 'Value', 200);
    
   uilabel(pnl_ctrl, 'Text', 'T.Gian(s):', 'Position', [10 240 60 22]); 
    ed_time = uieditfield(pnl_ctrl, 'numeric', 'Position', [70 240 40 22], 'Value', 10);
    uilabel(pnl_ctrl, 'Text', 'Tần số(Hz):', 'Position', [120 240 65 22]);
    ed_freq = uieditfield(pnl_ctrl, 'numeric', 'Position', [185 240 40 22], 'Value', 0.2);
    
   
    uilabel(pnl_ctrl, 'Text', 'Fs (Hz):', 'Position', [230 240 45 22], ...
        'FontColor', [0.8500 0.3250 0.0980], 'FontWeight', 'bold');
    ed_fs = uieditfield(pnl_ctrl, 'numeric', 'Position', [275 240 35 22], 'Value', 50);
    
    uilabel(pnl_ctrl, 'Text', 'B.Độ Dài(mm):', 'Position', [10 210 85 22]);
    ed_amp_lin = uieditfield(pnl_ctrl, 'numeric', 'Position', [95 210 50 22], 'Value', 50);
    uilabel(pnl_ctrl, 'Text', 'B.Độ Góc(°):', 'Position', [155 210 70 22]);
    ed_amp_ang = uieditfield(pnl_ctrl, 'numeric', 'Position', [225 210 50 22], 'Value', 8);
    
    uilabel(pnl_ctrl, 'Text', 'Hoặc Import:', 'Position', [10 180 80 22]);
    lbl_file = uilabel(pnl_ctrl, 'Text', 'Chưa chọn file', 'Position', [90 180 150 22]);
    uibutton(pnl_ctrl, 'Text', 'Browse', 'Position', [240 180 70 22], ...
        'ButtonPushedFcn', @(btn,event) browseFile());
    
    % Lựa chọn đối tượng mà file CSV đang mô tả
    uilabel(pnl_ctrl, 'Text', 'Đối tượng trong file:', 'Position', [10 150 110 22]);
    dd_import_type = uidropdown(pnl_ctrl, 'Items', ...
        {'Bàn máy (Platform)', 'Đầu người (Head)', 'Tâm quay Pivot'}, ...
        'Position', [120 150 140 22], 'Value', 'Bàn máy (Platform)');
    
    uibutton(pnl_ctrl, 'Text', '1. KIỂM ĐỊNH & CHẠY MÔ PHỔNG', 'Position', [20 110 280 40], ...
        'BackgroundColor', [0.4660 0.6740 0.1880], 'FontColor', 'w', 'FontSize', 14, ...
        'FontWeight', 'bold', 'ButtonPushedFcn', @(btn,event) runSystem());
        
    dd_export = uidropdown(pnl_ctrl, 'Items', {...
        'Bàn máy: 15 tham số (~M)', ...
        'Bàn máy: 7 tham số (~M)', ...
        'Đầu người: 15 tham số (~M)', ...
        'Đầu người: 7 tham số (~M)', ...
        'Tâm quay Pivot: 15 tham số (~M)', ...
        'Tâm quay Pivot: 7 tham số (~M)'}, ...
        'Position', [20 55 140 30]);    
    uibutton(pnl_ctrl, 'Text', '2. 💾 XUẤT FILE', 'Position', [170 55 130 30], ...
        'BackgroundColor', [0.8500 0.3250 0.0980], 'FontColor', 'w', 'FontWeight', 'bold', ...
        'ButtonPushedFcn', @(btn,event) exportData());
    
    uibutton(pnl_ctrl, 'Text', '📈 VẼ ĐỒ THỊ 15 THAM SỐ', 'Position', [20 15 280 30], ...
        'BackgroundColor', [0.2 0.6 0.8], 'FontColor', 'w', 'FontWeight', 'bold', ...
        'ButtonPushedFcn', @(btn,event) plot15Params());
    
    % --- KHU VỰC GIÁM SÁT TỌA ĐỘ HIỆN TẠI VÀ ĐỒ HỌA 3D ---
    pnl_monitor = uipanel(fig, 'Title', 'GIÁM SÁT TỌA ĐỘ HIỆN TẠI (BÀN MÁY)', ...
        'Position', [340 700 840 100], 'BackgroundColor', [0.94 0.94 0.94], 'FontWeight', 'bold');
    
    lbl_t = uilabel(pnl_monitor, 'Text', 'Time: 0.00 s', 'Position', [10 25 140 40], ...
        'FontSize', 18, 'FontWeight', 'bold', 'FontColor', 'b');
    lbl_x = uilabel(pnl_monitor, 'Text', 'X: 0.0', 'Position', [150 40 100 30], ...
        'FontSize', 15, 'FontWeight', 'bold');
    lbl_y = uilabel(pnl_monitor, 'Text', 'Y: 0.0', 'Position', [260 40 100 30], ...
        'FontSize', 15, 'FontWeight', 'bold');
    lbl_z = uilabel(pnl_monitor, 'Text', 'Z: 795.4', 'Position', [370 40 120 30], ...
        'FontSize', 15, 'FontWeight', 'bold');
    lbl_r = uilabel(pnl_monitor, 'Text', 'Roll: 0.0°', 'Position', [150 10 100 30], ...
        'FontSize', 15, 'FontWeight', 'bold');
    lbl_p = uilabel(pnl_monitor, 'Text', 'Pitch: 0.0°', 'Position', [260 10 100 30], ...
        'FontSize', 15, 'FontWeight', 'bold');
    lbl_yw = uilabel(pnl_monitor, 'Text', 'Yaw: 0.0°', 'Position', [370 10 100 30], ...
        'FontSize', 15, 'FontWeight', 'bold');
    
    btn_start = uibutton(pnl_monitor, 'Text', '▶ CHẠY', 'Position', [520 25 90 35], ...
        'BackgroundColor', [0.4660 0.6740 0.1880], 'FontColor', 'w', 'FontWeight', 'bold', ...
        'ButtonPushedFcn', @(btn,event) runSystem());
        
    btn_pause = uibutton(pnl_monitor, 'Text', '⏸ TẠM DỪNG', 'Position', [620 25 95 35], ...
        'BackgroundColor', [0.4940 0.1840 0.5560], 'FontColor', 'w', 'FontWeight', 'bold', ...
        'ButtonPushedFcn', @(btn,event) pauseTwin());
        
    btn_stop = uibutton(pnl_monitor, 'Text', '⏹ DỪNG', 'Position', [725 25 90 35], ...
        'BackgroundColor', [0.6350 0.0780 0.1840], 'FontColor', 'w', 'FontWeight', 'bold', ...
        'ButtonPushedFcn', @(btn,event) stopTwin());

    %    % ĐỒ THỊ 3D
    ax = uiaxes(fig, 'Position', [340 60 860 640]);
    title(ax, 'Mô phỏng hệ mô phỏng lái CKAS W2 6 bậc tự do');
    xlabel(ax, 'X (mm)'); ylabel(ax, 'Y (mm)'); zlabel(ax, 'Z (mm)');
    grid(ax, 'on'); hold(ax, 'on'); view(ax, 3); axis(ax, 'equal');
    xlim(ax, [-800 800]); ylim(ax, [-800 800]); zlim(ax, [-1700 800]);
    set(ax, 'ZDir', 'reverse')
    set(ax, 'YDir', 'reverse')
    
    % --- KHÔNG GIAN HOẠT ĐỘNG CÒN LẠI ---
    pnl_workspace = uipanel(fig, 'Title', 'KHÔNG GIAN HOẠT ĐỘNG CÒN LẠI TỪ VỊ TRÍ HIỆN TẠI (±)', ...
        'Position', [340 10 840 45], 'BackgroundColor', '#e6f7ff', 'FontWeight', 'bold');
    
    lbl_marg_x = uilabel(pnl_workspace, 'Text', 'X: --/--', 'Position', [10 5 130 22], 'FontColor', 'b', 'FontWeight', 'bold');
    lbl_marg_y = uilabel(pnl_workspace, 'Text', 'Y: --/--', 'Position', [145 5 130 22], 'FontColor', 'b', 'FontWeight', 'bold');
    lbl_marg_z = uilabel(pnl_workspace, 'Text', 'Z: --/--', 'Position', [280 5 130 22], 'FontColor', 'b', 'FontWeight', 'bold');
    lbl_marg_r = uilabel(pnl_workspace, 'Text', 'R: --/--', 'Position', [415 5 130 22], 'FontColor', '#D95319', 'FontWeight', 'bold');
    lbl_marg_p = uilabel(pnl_workspace, 'Text', 'P: --/--', 'Position', [550 5 130 22], 'FontColor', '#D95319', 'FontWeight', 'bold');
    lbl_marg_yw = uilabel(pnl_workspace, 'Text', 'Yw: --/--', 'Position', [685 5 140 22], 'FontColor', '#D95319', 'FontWeight', 'bold');
    
    
    % =====================================================================
    % PANEL 5: ĐIỀU KHIỂN THỦ CÔNG (MANUAL CONTROL)
    % =====================================================================
    pnl_manual = uipanel(fig, 'Title', 'ĐIỀU KHIỂN THỦ CÔNG & TRẠNG THÁI', ...
        'Position', [1220 20 310 760], 'BackgroundColor', '#fdfdfd', 'FontWeight', 'bold');
        
    % --- Các thanh trượt ---
    y_pos = 700;
    uilabel(pnl_manual, 'Text', 'X (mm):', 'Position', [10 y_pos 60 22]);
    sld_x = uislider(pnl_manual, 'Position', [70 y_pos+10 160 3], 'Limits', [-300 300], 'Value', 0);
    edt_x = uieditfield(pnl_manual, 'numeric', 'Position', [240 y_pos 50 22], 'Value', 0);
    
    y_pos = y_pos - 40;
    uilabel(pnl_manual, 'Text', 'Y (mm):', 'Position', [10 y_pos 60 22]);
    sld_y = uislider(pnl_manual, 'Position', [70 y_pos+10 160 3], 'Limits', [-300 300], 'Value', 0);
    edt_y = uieditfield(pnl_manual, 'numeric', 'Position', [240 y_pos 50 22], 'Value', 0);
    
    y_pos = y_pos - 40;
    uilabel(pnl_manual, 'Text', 'Z (mm):', 'Position', [10 y_pos 60 22]);
    sld_z = uislider(pnl_manual, 'Position', [70 y_pos+10 160 3], 'Limits', [-300 300], 'Value', 0);
    edt_z = uieditfield(pnl_manual, 'numeric', 'Position', [240 y_pos 50 22], 'Value', 0);
    
    y_pos = y_pos - 40;
    uilabel(pnl_manual, 'Text', 'Roll (độ):', 'Position', [10 y_pos 60 22]);
    sld_r = uislider(pnl_manual, 'Position', [70 y_pos+10 160 3], 'Limits', [-45 45], 'Value', 0);
    edt_r = uieditfield(pnl_manual, 'numeric', 'Position', [240 y_pos 50 22], 'Value', 0);
    
    y_pos = y_pos - 40;
    uilabel(pnl_manual, 'Text', 'Pitch (độ):', 'Position', [10 y_pos 60 22]);
    sld_p = uislider(pnl_manual, 'Position', [70 y_pos+10 160 3], 'Limits', [-45 45], 'Value', 0);
    edt_p = uieditfield(pnl_manual, 'numeric', 'Position', [240 y_pos 50 22], 'Value', 0);
    
    y_pos = y_pos - 40;
    uilabel(pnl_manual, 'Text', 'Yaw (độ):', 'Position', [10 y_pos 60 22]);
    sld_yw = uislider(pnl_manual, 'Position', [70 y_pos+10 160 3], 'Limits', [-45 45], 'Value', 0);
    edt_yw = uieditfield(pnl_manual, 'numeric', 'Position', [240 y_pos 50 22], 'Value', 0);
    
    btn_reset = uibutton(pnl_manual, 'Text', 'Reset về 0', 'Position', [100 y_pos-55 100 30], 'ButtonPushedFcn', @(btn,event) resetManual());
    
    % --- Trạng thái chân ảo ---
    y_pos = y_pos - 90;
    uilabel(pnl_manual, 'Text', 'TRẠNG THÁI CHÂN (mm)', 'Position', [10 y_pos 200 22], 'FontWeight', 'bold');
    
    lbl_L = gobjects(6,1);
    for i=1:6
        y_pos = y_pos - 25;
        lbl_L(i) = uilabel(pnl_manual, 'Text', sprintf('Chân %d: --', i), 'Position', [20 y_pos 280 22]);
    end
    
    % --- Trạng thái An toàn ---
    y_pos = y_pos - 40;
    lbl_status_manual = uilabel(pnl_manual, 'Text', 'TRẠNG THÁI: OK', 'Position', [10 y_pos 280 40], ...
        'FontColor', [0 0.6 0], 'FontWeight', 'bold', 'FontSize', 14, ...
        'HorizontalAlignment', 'center');
        
    % Gán Callback
    sld_x.ValueChangingFcn = @(sld,event) sync_slider(sld_x, edt_x, event);
    edt_x.ValueChangedFcn = @(edt,event) sync_edit(sld_x, edt_x);
    sld_y.ValueChangingFcn = @(sld,event) sync_slider(sld_y, edt_y, event);
    edt_y.ValueChangedFcn = @(edt,event) sync_edit(sld_y, edt_y);
    sld_z.ValueChangingFcn = @(sld,event) sync_slider(sld_z, edt_z, event);
    edt_z.ValueChangedFcn = @(edt,event) sync_edit(sld_z, edt_z);
    sld_r.ValueChangingFcn = @(sld,event) sync_slider(sld_r, edt_r, event);
    edt_r.ValueChangedFcn = @(edt,event) sync_edit(sld_r, edt_r);
    sld_p.ValueChangingFcn = @(sld,event) sync_slider(sld_p, edt_p, event);
    edt_p.ValueChangedFcn = @(edt,event) sync_edit(sld_p, edt_p);
    sld_yw.ValueChangingFcn = @(sld,event) sync_slider(sld_yw, edt_yw, event);
    edt_yw.ValueChangedFcn = @(edt,event) sync_edit(sld_yw, edt_yw);
    
    % Hàm cập nhật đồng bộ slider/edit và vẽ đồ thị
    function sync_slider(sld, edt, event)
        if nargin > 2
            sld.Value = event.Value;
        end
        edt.Value = sld.Value;
        updateManualPlot();
    end
    function sync_edit(sld, edt)
        if edt.Value < sld.Limits(1), edt.Value = sld.Limits(1); end
        if edt.Value > sld.Limits(2), edt.Value = sld.Limits(2); end
        sld.Value = edt.Value;
        updateManualPlot();
    end
    function resetManual()
        sld_x.Value = 0; edt_x.Value = 0;
        sld_y.Value = 0; edt_y.Value = 0;
        sld_z.Value = 0; edt_z.Value = 0;
        sld_r.Value = 0; edt_r.Value = 0;
        sld_p.Value = 0; edt_p.Value = 0;
        sld_yw.Value = 0; edt_yw.Value = 0;
        updateManualPlot();
    end

    % ---------------------------------------------------------------------
    % calcRemainingSpace : Tính toán không gian hoạt động còn lại
    % ---------------------------------------------------------------------
    function margins = calcRemainingSpace(pose, A, B, L1, L2, gamma)
        % pose = [x, y, z, r, p, y]
        % returns [dx+, dx-, dy+, dy-, dz+, dz-, dr+, dr-, dp+, dp-, dyw+, dyw-]
        margins = zeros(1, 12);
        ranges = [300, 300, 300, 45, 45, 45]; % Max search range
        
        for dim = 1:6
            % Pos direction
            low = 0; high = ranges(dim); best = 0;
            for iter = 1:9
                mid = (low + high) / 2;
                t_pose = pose; t_pose(dim) = t_pose(dim) + mid;
                [safe, ~, ~] = local_check_safety(t_pose, A, B, L1, L2, gamma);
                if safe, best = mid; low = mid; else, high = mid; end
            end
            margins((dim-1)*2 + 1) = best;
            
            % Neg direction
            low = 0; high = ranges(dim); best = 0;
            for iter = 1:9
                mid = (low + high) / 2;
                t_pose = pose; t_pose(dim) = t_pose(dim) - mid;
                [safe, ~, ~] = local_check_safety(t_pose, A, B, L1, L2, gamma);
                if safe, best = mid; low = mid; else, high = mid; end
            end
            margins((dim-1)*2 + 2) = best;
        end
    end

    function updateManualPlot()
        if isempty(A_mat) || isempty(B_mat) || isempty(gamma_ang)
            return;
        end
        
        if strcmp(dd_pivot.Value, 'Đầu người (Head)')
            v_pivot = [ed_headX.Value; ed_headY.Value; ed_headZ.Value];
        elseif strcmp(dd_pivot.Value, 'Bàn máy (Platform)')
            v_pivot = [0;0;0];
        else 
            v_pivot = [0;0;0]; % Tâm quay mặc định tạm thời nếu thiếu
        end
        
        T_local = [sld_x.Value; sld_y.Value; sld_z.Value];
        ywp = sld_yw.Value;
        pp = sld_p.Value;
        rp = sld_r.Value;
        R_mat = calcRotationMatrix(ywp, pp, rp);
        
        % Tính toán pos_plat với Home_Z đã nạp từ UI (giả sử có ed_homeZ hoặc mặc định)
        Home_Z_val = ed_homez.Value;
        
        % Chuyển đổi tịnh tiến (T_local) theo hệ tọa độ ĐÃ BỊ XOAY (Local/Rotated Frame) - Chuẩn CKAS
        P_0 = [0; 0; Home_Z_val];
        pos_plat = P_0 + v_pivot + R_mat * (T_local - v_pivot);
        pos_piv = pos_plat + R_mat * v_pivot;
        
        pose_k = [pos_plat(1), pos_plat(2), pos_plat(3), rp, pp, ywp];
        [is_safe, msg, phi_thuc] = local_check_safety(pose_k, A_mat, B_mat, ed_l1.Value, ed_l2.Value, gamma_ang);
        
        L_vec = pos_plat + R_mat * B_mat - A_mat;
        L_norm = sqrt(sum(L_vec.^2, 1));
        
        for i=1:6
            lbl_L(i).Text = sprintf('Chân %d: %.1f mm | Góc: %.1f°', i, L_norm(i), phi_thuc(i));
            if phi_thuc(i) < motor_min || phi_thuc(i) > motor_max
                lbl_L(i).FontColor = 'r';
            else
                lbl_L(i).FontColor = 'k';
            end
        end
        
        try
            marg = calcRemainingSpace(pose_k, A_mat, B_mat, ed_l1.Value, ed_l2.Value, gamma_ang);
            lbl_marg_x.Text = sprintf('X: +%.1f/ -%.1f', marg(1), marg(2));
            lbl_marg_y.Text = sprintf('Y: +%.1f/ -%.1f', marg(3), marg(4));
            lbl_marg_z.Text = sprintf('Z: +%.1f/ -%.1f', marg(5), marg(6));
            lbl_marg_r.Text = sprintf('R: +%.1f°/ -%.1f°', marg(7), marg(8));
            lbl_marg_p.Text = sprintf('P: +%.1f°/ -%.1f°', marg(9), marg(10));
            lbl_marg_yw.Text = sprintf('Yw: +%.1f°/ -%.1f°', marg(11), marg(12));
        catch
        end
        
        if is_safe
            lbl_status_manual.Text = 'TRẠNG THÁI: OK';
            lbl_status_manual.FontColor = [0 0.6 0];
        else
            lbl_status_manual.Text = ['TRẠNG THÁI: ' msg];
            lbl_status_manual.FontColor = [0.8 0 0];
        end
        
        drawStewart3D(pos_plat(1), pos_plat(2), pos_plat(3), rp, pp, ywp, [], [], [], [], [], [], [ed_headX.Value; ed_headY.Value; ed_headZ.Value], v_pivot);
    end
    
    

    % =====================================================================
    % Khởi tạo cấu hình mặc định khi mở app
    calcGeometry();

    % 2. CÁC HÀM XỬ LÝ SỰ KIỆN (CALLBACK)
    % =====================================================================

    % ---------------------------------------------------------------------
    % calcRotationMatrix : Tính ma trận quay ZYX từ góc Euler (đơn vị: độ)
    %
    % Quy ước quay: ZYX intrinsic (Yaw → Pitch → Roll)
    %   Bước 1 - Quay quanh Z (Yaw):   định hướng mũi xe/đầu người sang trái/phải
    %   Bước 2 - Quay quanh Y' (Pitch): ngẩng/cúi đầu
    %   Bước 3 - Quay quanh X'' (Roll): nghiêng sang trái/phải
    %
    % Công thức tổng hợp: R = Rz(yaw) * Ry(pitch) * Rx(roll)
    %
    % Input:
    %   yaw_deg, pitch_deg, roll_deg — góc Euler (độ)
    % Output:
    %   R — ma trận quay 3x3 (từ hệ bàn máy/body → hệ cố định/world)
    % ---------------------------------------------------------------------
    function R = calcRotationMatrix(yaw_deg, pitch_deg, roll_deg)
        cy = cosd(yaw_deg);   sy = sind(yaw_deg);
        cp = cosd(pitch_deg); sp = sind(pitch_deg);
        cr = cosd(roll_deg);  sr = sind(roll_deg);

        R = [cy*cp,  cy*sp*sr - sy*cr,  cy*sp*cr + sy*sr;
             sy*cp,  sy*sp*sr + cy*cr,  sy*sp*cr - cy*sr;
             -sp,    cp*sr,             cp*cr            ];
    end
    
    % ---------------------------------------------------------------------
    % saveConfig : Lưu cấu hình cơ khí và tọa độ đầu người ra file .mat
    % ---------------------------------------------------------------------
    function saveConfig()
        configData.ra = ed_ra.Value; configData.rb = ed_rb.Value;
        configData.l1 = ed_l1.Value; configData.l2 = ed_l2.Value;
        configData.a1 = ed_a1.Value; configData.da = ed_da.Value;
        configData.b1 = ed_b1.Value; configData.db = ed_db.Value; 
        configData.headX = ed_headX.Value;
        configData.headY = ed_headY.Value;
        configData.headZ = ed_headZ.Value;
        [file, path] = uiputfile('RobotConfig.mat', 'Lưu file cấu hình Robot');
        if isequal(file,0), return; end
        save(fullfile(path, file), 'configData');
        uialert(fig, 'Đã lưu cấu hình thành công!', 'Thành công');
    end
    
    % ---------------------------------------------------------------------
    % loadConfig : Tải cấu hình từ file .mat hoặc .json và cập nhật giao diện
    % ---------------------------------------------------------------------
    function loadConfig()
        [file, path] = uigetfile({'*.mat;*.json', 'Tất cả cấu hình (*.mat, *.json)'}, 'Chọn file cấu hình Robot');
        if isequal(file,0), return; end
        [~,~,ext] = fileparts(file);
        if strcmp(ext, '.json')
            try
                raw = fileread(fullfile(path, file));
                cdat = jsondecode(raw);
                if isfield(cdat, 'ra'), ed_ra.Value = cdat.ra; end
                if isfield(cdat, 'rb'), ed_rb.Value = cdat.rb; end
                if isfield(cdat, 'l1'), ed_l1.Value = cdat.l1; end
                if isfield(cdat, 'l2'), ed_l2.Value = cdat.l2; end
                if isfield(cdat, 'a1'), ed_a1.Value = cdat.a1; end
                if isfield(cdat, 'da'), ed_da.Value = cdat.da; end
                if isfield(cdat, 'b1'), ed_b1.Value = cdat.b1; end
                if isfield(cdat, 'db'), ed_db.Value = cdat.db; end
                if isfield(cdat, 'motor_limit_min'), motor_min = cdat.motor_limit_min; end
                if isfield(cdat, 'motor_limit_max'), motor_max = cdat.motor_limit_max; end
                calcGeometry();
                uialert(fig, 'Đã tải cấu hình JSON thành công!', 'Thành công');
            catch ME
                uialert(fig, ['Lỗi đọc JSON: ', ME.message], 'Lỗi');
            end
        else
            data = load(fullfile(path, file));
            if isfield(data, 'configData')
                cdat = data.configData;
                ed_ra.Value = cdat.ra; ed_rb.Value = cdat.rb; 
                ed_l1.Value = cdat.l1; ed_l2.Value = cdat.l2;
                ed_a1.Value = cdat.a1; ed_da.Value = cdat.da;
                ed_b1.Value = cdat.b1; ed_db.Value = cdat.db;
            
                if isfield(cdat, 'headX')
                    ed_headX.Value = cdat.headX;
                    ed_headY.Value = cdat.headY;
                    ed_headZ.Value = cdat.headZ;
                else
                    ed_headX.Value = 0;
                    ed_headY.Value = 0;
                    ed_headZ.Value = cdat.hhead;
                end
                calcGeometry(); 
                uialert(fig, 'Đã tải và áp dụng cấu hình!', 'Thành công');
            else
                uialert(fig, 'File không đúng định dạng!', 'Lỗi');
            end
        end
    end
    
    % ---------------------------------------------------------------------
    % calcGeometry : Tính toán tọa độ các khớp A_i, B_i và góc gamma cho Stewart
    %
    % Bố cục hình học: Stewart Platform có 3 cụm, mỗi cụm 2 chân kề nhau.
    % Các chân được đánh số 1..6 theo chiều kim đồng hồ nhìn từ trên xuống.
    % Mỗi cụm (1-6), (2-3), (4-5) được phân bố cách nhau 120° trên vòng tròn.
    % ---------------------------------------------------------------------
    function calcGeometry()
        % Lấy giá trị từ giao diện
        L1_val = ed_l1.Value; L2_val = ed_l2.Value;
        a1 = ed_a1.Value; da = ed_da.Value;
        b1 = ed_b1.Value; db = ed_db.Value;
        ra = ed_ra.Value; rb = ed_rb.Value;
        
        % Khởi tạo ma trận
        A_mat = zeros(3,6); B_mat = zeros(3,6);
        gamma_ang = zeros(1,6); alpha = zeros(1,6); beta = zeros(1,6);
        
        % Tính góc phân bố góc của từng khớp trên đế (alpha) và bàn máy (beta).
        % Hai chân trong cùng một cụm lệch nhau góc delta (da hoặc db).
        % Mỗi cụm cách nhau 120° (= 360°/3 cụm).
        %   alpha(chân lẻ)  = -(a1 + k*120°)
        %   alpha(chân chẵn)= -(a1 - da + (k+1)*120°)
        % Dấu âm: đo góc theo chiều kim đồng hồ (CW) thay vì CCW chuẩn toán học.
        for k = 0:2
            alpha(2*k + 1) = -(a1 + k * 120); 
            alpha(2*k + 2) = -(a1 - da + (k+1) * 120);
            beta(2*k + 1)  = -(b1 + k * 120); 
            beta(2*k + 2)  = -(b1 + db + k * 120); 
        end

    
        % → Tọa độ Z của khớp đế A_i trong hệ tọa độ tuyệt đối:
        Z_A = 668.4;

        % Tính tọa độ các điểm A (trên đế) và B (trên bàn máy)
        for i = 1:6
            A_mat(1, i) = ra * cosd(alpha(i));
            A_mat(2, i) = ra * sind(alpha(i));
            A_mat(3, i) = Z_A; % Tất cả khớp đế cùng độ cao (đế phẳng)
            B_mat(1, i) = rb * cosd(beta(i)); 
            B_mat(2, i) = rb * sind(beta(i)); 
            B_mat(3, i) = 0; % Tọa độ B trong hệ tọa độ cục bộ của bàn máy (gốc tại tâm bàn)

            % gamma_ang(i): góc định hướng trục quay của motor i trong mặt phẳng XY (độ).
            % Trục quay motor trùng với đường nối A_i đến tâm đế,
            % chiều ±90° phụ thuộc vào hướng lắp motor trong cụm.
            %
            % ĐANG DÙNG: Động cơ 1 cùng cụm với động cơ 6 (chân 1 và 6 lắp gần nhau)
            %   → chân lẻ quay CW so với alpha (+90° lùi), chân chẵn quay CCW (-90° lùi)
            gamma_ang(i) = alpha(i) + ((-1)^(i)) * 90;
            % PHƯƠNG ÁN THAY THẾ (nếu động cơ 1 cùng cụm với động cơ 2):
            % gamma_ang(i) = alpha(i) + ((-1)^(i+1)) * 90;
        end
        
        % Gán vào workspace Simulink để dùng trong mô hình điều khiển
        assignin('base', 'A_mat', A_mat); 
        assignin('base', 'B_mat', B_mat); 
        assignin('base', 'gamma_ang', gamma_ang);
        assignin('base', 'L1', L1_val); 
        assignin('base', 'L2', L2_val);
        
        lbl_status.Text = 'Đã cập nhật (Sẵn sàng)!'; lbl_status.FontColor = 'g';
        v_head = [ed_headX.Value; ed_headY.Value; ed_headZ.Value];
        drawStewart3D(0, 0, ed_homez.Value, 0, 0, 0, [], [], [], [], [], [], v_head, [0; 0; 0]);
    end
    
    % ---------------------------------------------------------------------
    % browseFile : Mở hộp thoại chọn file dữ liệu quỹ đạo
    % ---------------------------------------------------------------------
    function browseFile()
        [filename, pathname] = uigetfile({'*.csv;*.txt', 'Data Files'});
        if ~isequal(filename,0)
            lbl_file.Text = fullfile(pathname, filename);
            is_Validated = false;   % Reset cờ xác nhận khi đổi file
        end
    end
    
    % ---------------------------------------------------------------------
    % generateData : Tạo quỹ đạo từ file import hoặc tín hiệu mẫu
    % ---------------------------------------------------------------------
    function [t, xp, yp, zp, rp, pp, ywp, xv, yv, zv, x_hd, y_hd, z_hd, v_pivot, ...
              axi, ayi, azi, wx, wy, wz] = generateData()
        % Vị trí của đầu người trong hệ tọa độ gắn với bàn máy (mm)
        v_head_local = [ed_headX.Value; ed_headY.Value; ed_headZ.Value];
        Home_Z_Plat = ed_homez.Value; 
        mode_pivot = dd_pivot.Value;
        
        axi = []; ayi = []; azi = [];
        wx = []; wy = []; wz = [];
        
        % Xác định vector pivot dựa trên lựa chọn của người dùng
        if strcmp(mode_pivot, 'Đỉnh Đầu Người Lái')
            v_pivot = v_head_local;
        elseif strcmp(mode_pivot, 'Tâm Bàn Máy')
            v_pivot = [0; 0; 0];
        else 
            v_pivot = [ed_px.Value; ed_py.Value; ed_pz.Value];
        end
        
        if ~strcmp(lbl_file.Text, 'Chưa chọn file')
            % --- Import dữ liệu từ file Moog ---
            num_data = parseMoogFile(lbl_file.Text);
            if isempty(num_data)
                error('File không chứa dữ liệu số hợp lệ. Kiểm tra định dạng.');
            end
            num_data(any(isnan(num_data), 2), :) = [];
            
            if size(num_data,2) < 7
                error('File cần ít nhất 7 cột: Time, X, Y, Z, Yaw, Pitch, Roll');
            end
            
            t = num_data(:, 1);
            file_X = num_data(:, 2);
            file_Y = num_data(:, 3);
            file_Z = num_data(:, 4);
            ywp = num_data(:, 5);
            pp  = num_data(:, 6);
            rp  = num_data(:, 7);
            
            % Nếu file có thêm dữ liệu 15 tham số (cột 8-16)
            if size(num_data,2) >= 16
                axi = num_data(:, 8);  ayi = num_data(:, 9);  azi = num_data(:, 10);
                wz  = num_data(:, 14); wy  = num_data(:, 15); wx  = num_data(:, 16);
            end
            
            N = length(t);
            xp = zeros(N,1); 
            yp = zeros(N,1);
            zp = zeros(N,1); 
            xv = zeros(N,1); 
            yv = zeros(N,1); 
            zv = zeros(N,1); 
            x_hd = zeros(N,1);
            y_hd = zeros(N,1); 
            z_hd = zeros(N,1);
            
            import_type = dd_import_type.Value;
            
            for k = 1:N
                R_k = calcRotationMatrix(ywp(k), pp(k), rp(k));
                
                P_file = [file_X(k); file_Y(k); file_Z(k)];
                
                % Chuyển đổi từ đối tượng được mô tả trong file về tọa độ bàn máy
                % Theo tài liệu CKAS: Quay quanh điểm xoay (Pivot) -> Hệ tọa độ nghiêng -> Tịnh tiến theo hệ tọa độ nghiêng (Local/Rotated Frame)
                P_0 = [0; 0; Home_Z_Plat];
                switch import_type
                    case 'Bàn máy (Platform)'
                        pos_plat = P_0 + R_k * P_file;
                    case 'Đầu người (Head)'
                        pos_plat = P_0 + v_head_local + R_k * (P_file - v_head_local);
                    case 'Tâm quay Pivot'
                        pos_plat = P_0 + v_pivot + R_k * (P_file - v_pivot);
                end
                
                xp(k) = pos_plat(1);
                yp(k) = pos_plat(2);
                zp(k) = pos_plat(3);
                
                % Tính các điểm còn lại từ bàn máy (Global position)
                pos_piv = pos_plat + R_k * v_pivot;
                xv(k) = pos_piv(1);
                yv(k) = pos_piv(2); 
                zv(k) = pos_piv(3);
                
                pos_head = pos_plat + R_k * v_head_local;
                x_hd(k) = pos_head(1);
                y_hd(k) = pos_head(2);
                z_hd(k) = pos_head(3);
            end
        else
         % --- Tạo quỹ đạo nội bộ (tín hiệu sin, đường tròn, cua chữ S) ---
            T_sim = ed_time.Value; 
            freq = ed_freq.Value;
            A_lin = ed_amp_lin.Value;  % Biên độ tịnh tiến (mm)
            A_ang = ed_amp_ang.Value;  % Biên độ góc (độ)

            % --- LẤY GIÁ TRỊ Fs TRỰC TIẾP TỪ GIAO DIỆN ---
            fs = ed_fs.Value;          
            
            t = (0:1/fs:T_sim)';

            % fade: hệ số nhân tuyến tính từ 0→1 trong 1 giây đầu tiên.
            % Mục đích: tránh "giật" đột ngột khi bắt đầu chuyển động (jerk lớn).
            % Sau t=1s, fade = 1 → biên độ đầy đủ.
            T_fade = 0; % Thời gian mồi (fade-in) kéo dài 1.5 giây (có thể tùy chỉnh)
            tau = min(t / T_fade, 1); % Chuẩn hóa trục thời gian tau trong khoảng [0, 1]
            fade = 0.5 * (1 - cos(pi * tau)); % Raised Cosine Formula
            
            xv_local = zeros(size(t)); 
            yv_local = zeros(size(t)); 
            % Vị trí Z chỉ chứa dao động T_local_z, không cộng Home_Z
            zv_local = zeros(size(t)); 
            ywp = zeros(size(t));
            pp = zeros(size(t));
            rp = zeros(size(t));
            
            mode = dd_traj.Value;
            if strcmp(mode, '[1D] Tịnh tiến Z (Heave)')
                % Chuyển động lên/xuống theo trục Z — mô phỏng nhún xe
                zv_local = zv_local + (A_lin * sin(2*pi*freq*t)) .* fade;
            elseif strcmp(mode, '[1D] Quay Pitch (Gật gù)')
                % Chuyển động gật gù (pitch) — mô phỏng phanh/tăng tốc
                pp = (A_ang * sin(2*pi*freq*t)) .* fade;
            elseif strcmp(mode, '[1D] Quay Roll (Lắc ngang)')
                % Chuyển động lắc ngang (roll) — mô phỏng chao nghiêng
                rp = (A_ang * sin(2*pi*freq*t)) .* fade;
            elseif strcmp(mode, '[2D] Đường tròn XY')
                % Quỹ đạo tròn trong mặt phẳng XY, dịch lùi A_lin để bắt đầu tại gốc
                xv_local = (A_lin * cos(2*pi*freq*t) - A_lin) .* fade; 
                yv_local = (A_lin * sin(2*pi*freq*t)) .* fade;
            elseif strcmp(mode, '[3D] Cua chữ S (6 DOF)')
                % Cua chữ S 6 DOF: kết hợp lắc ngang (Y, Roll) và nhún (X, Pitch)
                % Y và Roll: tần số cơ bản freq (lắc trái/phải theo cua)
                % X và Pitch: tần số gấp đôi 2*freq (nhún theo mặt đường)
                yv_local = (A_lin * sin(2*pi*freq*t)) .* fade; 
                xv_local = (A_lin/2 * sin(4*pi*freq*t)) .* fade;
                rp = (A_ang * sin(4*pi*freq*t)) .* fade; 
                pp = (A_ang/2 * (cos(2*pi*freq*t) - 1)) .* fade;
            end
            
            N = length(t); 
            xp = zeros(N,1); yp = zeros(N,1); zp = zeros(N,1); 
            xv = zeros(N,1); yv = zeros(N,1); zv = zeros(N,1); 
            x_hd = zeros(N,1); y_hd = zeros(N,1); z_hd = zeros(N,1);
            for k = 1:N
                R_k = calcRotationMatrix(ywp(k), pp(k), rp(k));
                T_local = [xv_local(k); yv_local(k); zv_local(k)];
                
                % Tịnh tiến Local trên hệ trục nghiêng
                pos_plat = [0; 0; Home_Z_Plat] + v_pivot + R_k * (T_local - v_pivot);
                xp(k) = pos_plat(1); yp(k) = pos_plat(2); zp(k) = pos_plat(3);
                
                pos_piv = pos_plat + R_k * v_pivot;
                xv(k) = pos_piv(1); yv(k) = pos_piv(2); zv(k) = pos_piv(3);
                
                pos_head = pos_plat + R_k * v_head_local;
                x_hd(k) = pos_head(1); y_hd(k) = pos_head(2); z_hd(k) = pos_head(3);
            end
        end
    end
    
    % ---------------------------------------------------------------------
    % runSystem : Kiểm định an toàn và chạy mô phỏng 3D
    % ---------------------------------------------------------------------
    function runSystem()
        if is_Playing
            if is_Paused, pauseTwin(); end
            return; 
        end
        if isempty(A_mat), uialert(fig, 'Bấm CẬP NHẬT CẤU HÌNH trước!', 'Lỗi'); return; end
        
        try
            [t, xp, yp, zp, rp, pp, ywp, xv, yv, zv, x_hd, y_hd, z_hd, v_pivot, ...
             axi, ayi, azi, wx, wy, wz] = generateData();
        catch ME
            uialert(fig, ['Lỗi khi tạo dữ liệu: ' ME.message], 'Lỗi dữ liệu');
            return;
        end
        
        % Kiểm tra an toàn từng điểm trên quỹ đạo
        d = uiprogressdlg(fig, 'Title', 'Đang kiểm định', 'Message', 'Quét an toàn...');
        for k = 1:length(t)
            pose_k = [xp(k), yp(k), zp(k), rp(k), pp(k), ywp(k)];
            [is_safe, msg] = local_check_safety(pose_k, A_mat, B_mat, ed_l1.Value, ed_l2.Value, gamma_ang);
            if ~is_safe
                close(d); uialert(fig, sprintf('QUỸ ĐẠO KHÔNG KHẢ THI!\nt=%.2fs: %s', t(k), msg), 'Lỗi');
                is_Validated = false; return;
            end
            d.Value = k/length(t);
        end
        close(d);
        
        is_Validated = true; T_out = t; 
        Xp_out = xp; Yp_out = yp; Zp_out = zp; 
        Xv_out = xv; Yv_out = yv; Zv_out = zv; 
        R_out = rp;  P_out = pp;  Yw_out = ywp;
        Xh_out = x_hd; Yh_out = y_hd; Zh_out = z_hd;
        Ax_out = axi; Ay_out = ayi; Az_out = azi;
        Wx_out = wx; Wy_out = wy; Wz_out = wz;
        
        is_Playing = true;
        is_Paused = false;
        btn_pause.Text = '⏸ TẠM DỪNG';
        btn_pause.BackgroundColor = [0.4940 0.1840 0.5560];
        
        % Tính toán số bước nhảy (step) để duy trì tốc độ khung hình ~30 FPS
        if length(t) > 1
            dt = t(2) - t(1);
            if dt <= 0, dt = 0.02; end
            step = max(1, round((1/30) / dt)); 
        else
            step = 1;
        end
        
        v_head_local = [ed_headX.Value; ed_headY.Value; ed_headZ.Value];
        
        sim_tic = tic; % Bắt đầu đếm thời gian thực
        pause_duration = 0; % Tổng thời gian đã tạm dừng
        
        for i = 1:step:length(t)
            if ~is_Playing, break; end
            if is_Paused
                pause_start = tic;
                while is_Paused
                    drawnow limitrate; pause(0.1);
                    if ~is_Playing, break; end
                end
                pause_duration = pause_duration + toc(pause_start);
            end
            if ~is_Playing, break; end 
            
            % --- ĐỒNG BỘ VỚI THỜI GIAN THỰC TẾ ---
            target_time = t(i);
            current_time = toc(sim_tic) - pause_duration;
            if current_time < target_time
                wait_time = target_time - current_time;
                % Chỉ gọi pause nếu thời gian chờ > 2ms để tránh hệ điều hành chặn luồng quá lố
                if wait_time > 0.002
                    pause(wait_time);
                end
            end
            
            lbl_t.Text = sprintf('Time: %.2f s', t(i)); 
            lbl_x.Text = sprintf('X: %.1f', xp(i)); lbl_y.Text = sprintf('Y: %.1f', yp(i)); 
            lbl_z.Text = sprintf('Z: %.1f', zp(i));
            lbl_r.Text = sprintf('R: %.1f°', rp(i)); lbl_p.Text = sprintf('P: %.1f°', pp(i)); 
            lbl_yw.Text = sprintf('Y: %.1f°', ywp(i));
            
            % --- ĐỒNG BỘ HIỂN THỊ CỘT BÊN PHẢI ---
            try
                % Tính lại góc motor thực tế tại điểm quỹ đạo này
                pose_i = [xp(i), yp(i), zp(i), rp(i), pp(i), ywp(i)];
                [~, ~, phi_thuc_i] = local_check_safety(pose_i, A_mat, B_mat, ed_l1.Value, ed_l2.Value, gamma_ang);
                
                % T_local từ quỹ đạo tuyệt đối xp, yp, zp (vì manual slider nhận T_local)
                R_mat_i = calcRotationMatrix(ywp(i), pp(i), rp(i));
                pos_plat_i = [xp(i); yp(i); zp(i)];
                L_vec_i = pos_plat_i + R_mat_i * B_mat - A_mat;
                L_norm_i = sqrt(sum(L_vec_i.^2, 1));
                T_loc_i = R_mat_i' * (pos_plat_i - [0;0;ed_homez.Value] - v_pivot) + v_pivot;
                
                % Cập nhật sliders và edits
                sld_x.Value = max(sld_x.Limits(1), min(sld_x.Limits(2), T_loc_i(1))); edt_x.Value = sld_x.Value;
                sld_y.Value = max(sld_y.Limits(1), min(sld_y.Limits(2), T_loc_i(2))); edt_y.Value = sld_y.Value;
                sld_z.Value = max(sld_z.Limits(1), min(sld_z.Limits(2), T_loc_i(3))); edt_z.Value = sld_z.Value;
                sld_r.Value = max(sld_r.Limits(1), min(sld_r.Limits(2), rp(i)));      edt_r.Value = sld_r.Value;
                sld_p.Value = max(sld_p.Limits(1), min(sld_p.Limits(2), pp(i)));      edt_p.Value = sld_p.Value;
                sld_yw.Value = max(sld_yw.Limits(1), min(sld_yw.Limits(2), ywp(i)));  edt_yw.Value = sld_yw.Value;
                
                % Cập nhật labels của các chân
                for k=1:6
                    lbl_L(k).Text = sprintf('Chân %d: %.1f mm | Góc: %.1f°', k, L_norm_i(k), phi_thuc_i(k));
                    if phi_thuc_i(k) < motor_min || phi_thuc_i(k) > motor_max
                        lbl_L(k).FontColor = 'r';
                    else
                        lbl_L(k).FontColor = 'k';
                    end
                end
                
                % Cập nhật labels không gian hoạt động còn lại
                marg = calcRemainingSpace(pose_i, A_mat, B_mat, ed_l1.Value, ed_l2.Value, gamma_ang);
                lbl_marg_x.Text = sprintf('X: +%.1f/ -%.1f', marg(1), marg(2));
                lbl_marg_y.Text = sprintf('Y: +%.1f/ -%.1f', marg(3), marg(4));
                lbl_marg_z.Text = sprintf('Z: +%.1f/ -%.1f', marg(5), marg(6));
                lbl_marg_r.Text = sprintf('R: +%.1f°/ -%.1f°', marg(7), marg(8));
                lbl_marg_p.Text = sprintf('P: +%.1f°/ -%.1f°', marg(9), marg(10));
                lbl_marg_yw.Text = sprintf('Yw: +%.1f°/ -%.1f°', marg(11), marg(12));
            catch
            end
            % -------------------------------------
            
            drawStewart3D(xp(i), yp(i), zp(i), rp(i), pp(i), ywp(i), ...
                          Xv_out(1:i), Yv_out(1:i), Zv_out(1:i), ... 
                          Xh_out(1:i), Yh_out(1:i), Zh_out(1:i), ...
                          v_head_local, v_pivot);
            drawnow limitrate; 
        end
        is_Playing = false;
        
        % Gán dữ liệu ra workspace để dùng cho Simulink (nếu cần)
        assignin('base', 'X_ref', timeseries(xp, t)); 
        assignin('base', 'Y_ref', timeseries(yp, t)); 
        assignin('base', 'Z_ref', timeseries(zp, t));
        assignin('base', 'roll_ref', timeseries(rp, t)); 
        assignin('base', 'pitch_ref', timeseries(pp, t)); 
        assignin('base', 'yaw_ref', timeseries(ywp, t));
        assignin('base', 'T_stop', t(end));
        
        % Phần gọi Simulink đã được comment để tránh lỗi khi không có mô hình

        mdl = 'Final_CKASForSIM30_11_SIM';
         if bdIsLoaded(mdl)
             status = get_param(mdl, 'SimulationStatus');
            if ~strcmp(status, 'stopped'), set_param(mdl, 'SimulationCommand', 'stop'); pause(0.5); end
        end
        try sim(mdl); catch ME, uialert(fig, ['Lỗi Simulink: ', ME.message], 'Lỗi'); end
    end

    % ---------------------------------------------------------------------
    % exportData : Xuất quỹ đạo ra file định dạng Moog (7 hoặc 15 tham số)
    % ---------------------------------------------------------------------
    function exportData()
        if ~is_Validated || isempty(T_out)
            uialert(fig, 'Chưa có dữ liệu an toàn! Hãy bấm KIỂM ĐỊNH & CHẠY trước.', 'Lỗi'); return;
        end
        
        format_type = dd_export.Value;
        
        % Chọn đối tượng xuất
        if contains(format_type, 'Đầu người')
            X_target = Xh_out; Y_target = Yh_out; Z_target = Zh_out; def_name = 'Head_Command.csv';
        elseif contains(format_type, 'Tâm quay Pivot')
            % Xuất T_local cho Pivot
            X_target = zeros(length(T_out), 1);
            Y_target = zeros(length(T_out), 1);
            Z_target = zeros(length(T_out), 1);
            v_pivot = [ed_px.Value; ed_py.Value; ed_pz.Value];
            if strcmp(dd_pivot.Value, 'Đỉnh Đầu Người Lái')
                v_pivot = [ed_headX.Value; ed_headY.Value; ed_headZ.Value];
            elseif strcmp(dd_pivot.Value, 'Tâm Bàn Máy')
                v_pivot = [0;0;0];
            end
            for k=1:length(T_out)
                R_k = calcRotationMatrix(Yw_out(k), P_out(k), R_out(k));
                pos_plat = [Xp_out(k); Yp_out(k); Zp_out(k)];
                T_local = R_k' * (pos_plat - [0; 0; ed_homez.Value] - v_pivot) + v_pivot;
                X_target(k) = T_local(1);
                Y_target(k) = T_local(2);
                Z_target(k) = T_local(3);
            end
            def_name = 'Pivot_Command.csv';
        else
            X_target = Xp_out; Y_target = Yp_out; Z_target = Zp_out; def_name = 'Platform_Command.csv';
        end
        
        [file, path] = uiputfile(def_name, 'Lưu file CSV (~M)');
        if isequal(file, 0), return; end
        fid = fopen(fullfile(path, file), 'w');
        if fid == -1, uialert(fig, 'Lỗi: Không thể ghi file.', 'Lỗi'); return; end
        
        N = length(T_out);
        if contains(format_type, '15 tham số')
            % -----------------------------------------------------------------
            % Bước 1: Gia tốc world frame bằng sai phân bậc 2 vị trí
            % -----------------------------------------------------------------
            dt_mean = mean(diff(T_out)); 
            if dt_mean <= 0 || isnan(dt_mean), dt_mean = 0.01; end
            
            vx_w = gradient(X_target, dt_mean);
            vy_w = gradient(Y_target, dt_mean);
            vz_w = gradient(Z_target, dt_mean);
            ax_w = gradient(vx_w, dt_mean) / 1000;  % mm/s² → m/s²
            ay_w = gradient(vy_w, dt_mean) / 1000;
            az_w = gradient(vz_w, dt_mean) / 1000;

            % -----------------------------------------------------------------
            % Bước 2 & 3: Chiếu lên body frame của đối tượng đang xuất
            % 'Body' ở đây = frame của đối tượng (bàn máy / đầu người / pivot)
            % tùy theo lựa chọn xuất file — không phải cố định là đầu người.
            %   axi,ayi,azi = R(t)' * a_world  (gia tốc quán tính, không có g)
            %   axg,ayg,azg = R(t)' * [0;0;g]  (hình chiếu trọng lực lên body)
            % -----------------------------------------------------------------
            g_val = 9.81;
            ax_i = zeros(N,1); ay_i = zeros(N,1); az_i = zeros(N,1);
            axg  = zeros(N,1); ayg  = zeros(N,1); azg  = zeros(N,1);
            for k = 1:N
                R_k    = calcRotationMatrix(Yw_out(k), P_out(k), R_out(k));
                a_body = R_k' * [ax_w(k); ay_w(k); az_w(k)];
                ax_i(k) = a_body(1); ay_i(k) = a_body(2); az_i(k) = a_body(3);
                g_body = R_k' * [0; 0; g_val];  % Z world hướng xuống → g dương
                axg(k) = g_body(1); ayg(k) = g_body(2); azg(k) = g_body(3);
            end

            % -----------------------------------------------------------------
            % Bước 4: Vận tốc góc body frame qua Jacobian ZYX
            % Sai phân trực tiếp trên góc Euler cho kết quả sai (gimbal lock).
            % Jacobian ZYX (Yaw=Ψ, Pitch=Θ, Roll=Φ):
            %   ωx =  dΦ/dt - dΨ/dt·sin(Θ)
            %   ωy =  dΘ/dt·cos(Φ) + dΨ/dt·cos(Θ)·sin(Φ)
            %   ωz = -dΘ/dt·sin(Φ) + dΨ/dt·cos(Θ)·cos(Φ)
            % Thứ tự output theo spec Moog: [ωz ωy ωx] = [Yaw Pitch Roll body]
            % -----------------------------------------------------------------
            dYaw   = gradient(Yw_out, dt_mean) * (pi/180);
            dPitch = gradient(P_out, dt_mean)  * (pi/180);
            dRoll  = gradient(R_out, dt_mean)  * (pi/180);
            phi_r   = R_out   * pi/180;  % Φ Roll (rad)
            theta_r = P_out   * pi/180;  % Θ Pitch (rad)
            wx_b =  dRoll  - dYaw .* sin(theta_r);
            wy_b =  dPitch .* cos(phi_r) + dYaw .* cos(theta_r) .* sin(phi_r);
            wz_b = -dPitch .* sin(phi_r) + dYaw .* cos(theta_r) .* cos(phi_r);

            for k = 1:N
                fprintf(fid, '%.4f ~M[ %.4f %.4f %.4f %.4f %.4f %.4f [ %.4f %.4f %.4f %.4f %.4f %.4f %.4f %.4f %.4f ]]\n', ...
                    T_out(k), X_target(k), Y_target(k), Z_target(k), Yw_out(k), P_out(k), R_out(k), ...
                    ax_i(k), ay_i(k), az_i(k), axg(k), ayg(k), azg(k), wz_b(k), wy_b(k), wx_b(k));
            end
        else
            % 7 tham số
            for k = 1:N
                fprintf(fid, '%.4f ~M[ %.4f %.4f %.4f %.4f %.4f %.4f ]\n', ...
                    T_out(k), X_target(k), Y_target(k), Z_target(k), Yw_out(k), P_out(k), R_out(k));
            end
        end
        fclose(fid); uialert(fig, 'Đã xuất file thành công!', 'Hoàn tất');
    end

    % ---------------------------------------------------------------------
    % pauseTwin : Tạm dừng / tiếp tục hoạt ảnh 3D
    % ---------------------------------------------------------------------
    function pauseTwin()
        if is_Playing
            is_Paused = ~is_Paused; 
            if is_Paused
                btn_pause.Text = '▶ TIẾP TỤC';
                btn_pause.BackgroundColor = [0.9290 0.6940 0.1250]; 
            else
                btn_pause.Text = '⏸ TẠM DỪNG';
                btn_pause.BackgroundColor = [0.4940 0.1840 0.5560]; 
            end
        end
    end

    % ---------------------------------------------------------------------
    % stopTwin : Dừng hẳn hoạt ảnh 3D
    % ---------------------------------------------------------------------
    function stopTwin()
        is_Playing = false; 
        is_Paused = false;  
        btn_pause.Text = '⏸ TẠM DỪNG';
        btn_pause.BackgroundColor = [0.4940 0.1840 0.5560];
    end

    % ---------------------------------------------------------------------
    % local_check_safety : Kiểm tra động học ngược Stewart cho một pose
    % ---------------------------------------------------------------------
    function [is_safe, error_msg, phi_thuc] = local_check_safety(pose, A, B, L1, L2, gamma)
        % pose = [x, y, z, roll, pitch, yaw] (mm, độ)
        phi_thuc = zeros(1,6); % Trả về góc motor
        if any(isnan(pose)) || any(isinf(pose))
            is_safe = false;
            error_msg = 'NaN/Inf';
            return;
        end
        
        r_ang = pose(4);
        p_ang = pose(5); 
        yw_ang = pose(6);
        % Ma trận quay từ hệ bàn máy (body) sang hệ cố định (world)
        R = calcRotationMatrix(yw_ang, p_ang, r_ang);
             
        T = [pose(1); pose(2); pose(3)];
        L_vec = T + R * B - A;   % Vector chân ảo
        l_sq = sum(L_vec.^2, 1); 
        
        % -----------------------------------------------------------------
        % ĐỘNG HỌC NGƯỢC: Giải góc servo phi cho từng chân
        % -----------------------------------------------------------------
        % Xuất phát từ phương trình vòng kín: vị trí đầu tay đòn trên (C_i)
        % phải khớp với khớp cầu trên bàn máy (B_i').
        % Sau khi khai triển và chiếu lên trục quay của motor (xác định bởi gamma_i):
        %
        %   Q = l_sq - L2² + L1²           (hằng số hình học từ độ dài vector L_vec)
        %   M = 2*L1*L_vec_z               (thành phần theo trục Z)
        %   N = 2*L1*(cos(γ)*L_vec_x + sin(γ)*L_vec_y)  (chiều dài chiếu theo trục motor)
        %
        % Phương trình IK rút gọn: Q = M*sin(phi) + N*cos(phi)
        % → có thể viết lại: Q = sqrt(M²+N²) * sin(phi + arctan2(N,M))
        % Điều kiện nghiệm tồn tại: |Q / sqrt(M²+N²)| ≤ 1
        Q = l_sq - L2^2 + L1^2;
        M_val = (2 * L1 * L_vec(3, :));
        N_val = 2 * L1 * (cosd(gamma) .* L_vec(1, :) + sind(gamma) .* L_vec(2, :));
        arg = Q ./ sqrt(M_val.^2 + N_val.^2);
        
        % Nếu |arg| > 1: arcsin không xác định → chân bị "kịch" (tư thế nằm ngoài
        % không gian làm việc — tay đòn không đủ dài để với tới vị trí yêu cầu)
        if any(abs(arg) > 1), bad_legs = find(abs(arg) > 1); is_safe = false;
            error_msg = sprintf('Chân %d kịch', bad_legs(1)); return;
        end
        
        % phi_raw: góc TƯƠNG ĐỐI (độ) — lượng góc cần quay từ vị trí tham chiếu
        % để tay đòn L1 đạt đúng tư thế yêu cầu. Đây là kết quả thuần túy của IK,
        % chưa phản ánh vị trí tuyệt đối hay chiều quay vật lý của motor.
        phi_raw = (asind(arg) - atan2d(N_val, M_val));
        
        % phi_out: góc TUYỆT ĐỐI trong hệ tọa độ toán học (độ).
        % Ở vị trí home, tay đòn L1 nằm ngang (vuông góc với trục Z), tức là
        % đã lệch sẵn 90° so với trục tham chiếu dọc của IK.
        % → Phải cộng offset ±90° vào phi_raw để ra góc tuyệt đối.
        %
        % Dấu ±90° do chiều lắp tay đòn trong cụm:
        %   Trong mỗi cụm 2 chân, tay đòn của chân lẻ và chẵn được lắp
        %   chỉ về 2 phía ĐỐI NHAU (đối xứng gương qua trục motor).
        %   → Khi motor quay cùng chiều, 2 tay đòn di chuyển NGƯỢC nhau.
        %   Chân lẻ  (1,3,5): tay đòn lắp lệch -90° → phi_out = -(90 + phi_raw)
        %   Chân chẵn (2,4,6): tay đòn lắp lệch +90° → phi_out = +(90 + phi_raw)
        % LƯU Ý: Nếu thay motor hoặc lắp lại tay đòn, kiểm tra lại dấu này trước tiên.
        phi_out = zeros(1, 6);
        phi_out(1:2:5) = -(90 + phi_raw(1:2:5));
        phi_out(2:2:6) = (90 + phi_raw(2:2:6));
        
        % phi_thuc: góc thực gửi xuống driver/Simulink (độ).
        % Trong mỗi cụm, 2 motor quay NGƯỢC chiều nhau về mặt cơ học.
        % Driver quy ước chiều dương theo một hướng cố định → motor nào quay
        % ngược quy ước phải đổi dấu góc trước khi gửi lệnh.
        % Offset [90, -90, 90, -90, 90, -90] thực hiện việc đổi dấu này:
        %   Trừ +90  → giữ nguyên dấu (motor cùng chiều quy ước)
        %   Trừ -90  → đảo dấu      (motor ngược chiều quy ước)
        phi_thuc = (phi_out - [90, -90, 90, -90, 90, -90]);
        phi_thuc(1:2:5) = -phi_thuc(1:2:5); % Đảo dấu động cơ lẻ theo yêu cầu
       
        % Giới hạn vật lý của khớp servo từ config.json
        % Đây là giới hạn cơ khí (do thiết kế thanh đỡ và hành trình khớp cầu),
        % không phải giới hạn phần mềm — vượt quá sẽ gây va chạm cơ học.
        if any(phi_thuc < motor_min) || any(phi_thuc > motor_max)
            bad_idx = find((phi_thuc < motor_min) | (phi_thuc > motor_max), 1);
            is_safe = false; error_msg = sprintf('Góc Servo %d là %.2f°', bad_idx, phi_thuc(bad_idx)); return;
        end
        
        % Kiểm tra kỳ dị (singular configuration): Jacobian suy biến khi det ≈ 0,
        % nghĩa là tại tư thế này platform mất bậc tự do → không điều khiển được.
        % J_inv được xây từ vector đơn vị s_vec (dọc tay đòn trên) và moment r×s.
        r_vec = R * B;
        L_norm = sqrt(sum(L_vec.^2, 1));
        s_vec = L_vec ./ L_norm; 
        cross_prod = cross(r_vec, s_vec); 
        J_inv = [s_vec', cross_prod'];
        if abs(det(J_inv)) < 1e-3
           is_safe = false; error_msg = 'Kỳ dị';
           return; 
        end
        is_safe = true; error_msg = 'OK';
    end

    % ---------------------------------------------------------------------
    % drawStewart3D : Vẽ mô hình 3D Stewart Platform và các quỹ đạo
    % ---------------------------------------------------------------------
    function drawStewart3D(x, y, z, roll, pitch, yaw, x_v_trail, y_v_trail, z_v_trail, ...
                           x_h_trail, y_h_trail, z_h_trail, v_head, v_piv)
        cla(ax); lighting(ax, 'gouraud'); material(ax, 'dull');      
        colorBase = [0.8 0.8 0]; colorPlatform = [0 0.6 0]; 
        colorL1 = [0.4 0.4 0.4]; colorL2 = [0.8 0 0];          
        radiusL1 = 18; radiusL2 = 12; N_pts = 16;
        
        fill3(ax, A_mat(1,:), A_mat(2,:), A_mat(3,:), colorBase, 'FaceAlpha', 0.8, 'EdgeColor', 'k');
        
        % Ma trận quay để chuyển tọa độ bàn máy sang hệ cố định
        R = calcRotationMatrix(yaw, pitch, roll);
        B_global = zeros(3,6); 
        for i = 1:6, B_global(:,i) = [x; y; z] + R * B_mat(:,i); end
        fill3(ax, B_global(1,:), B_global(2,:), B_global(3,:), colorPlatform, ...
              'FaceAlpha', 0.9, 'EdgeColor', 'b');
        
        for i = 1:6
            A_i = A_mat(:,i); P_i = B_global(:,i); 
            Lx = P_i(1) - A_i(1); Ly = P_i(2) - A_i(2); Lz = P_i(3) - A_i(3);
            Q = Lx^2 + Ly^2 + Lz^2 - L2_val^2 + L1_val^2;
            M = (2 * L1_val * Lz);
            N = 2 * L1_val * (cosd(gamma_ang(i))*Lx + sind(gamma_ang(i))*Ly);
            arg = Q / sqrt(M^2 + N^2); 
            if abs(arg) <= 1, phi = asind(arg) - atan2d(N, M); else, phi = 0; end
            
            Cx = A_i(1) + L1_val * cosd(gamma_ang(i)) * cosd(phi); 
            Cy = A_i(2) + L1_val * sind(gamma_ang(i)) * cosd(phi); 
            Cz = A_i(3) + L1_val * sind(phi); 
            C_i = [Cx; Cy; Cz];
            [Xc1, Yc1, Zc1] = cylinder(radiusL1, N_pts); Zc1 = Zc1 * L1_val; 
            vec1 = (C_i - A_i) / L1_val; 
            if abs(vec1(3)) > 0.999
                Ry1 = zeros(3,3); 
                if vec1(3) < 0, Ry1 = eye(3)*-1; Ry1(3,3)=1; else, Ry1=eye(3); end
            else
                u_z=[0;0;1]; v1=cross(u_z,vec1); s1=norm(v1); c1=dot(u_z,vec1); 
                Vx1=[0 -v1(3) v1(2); v1(3) 0 -v1(1); -v1(2) v1(1) 0]; 
                Ry1=eye(3)+Vx1+Vx1^2*((1-c1)/s1^2);
            end
            for j = 1:N_pts+1
                curr1 = A_i + Ry1 * [Xc1(1,j); Yc1(1,j); Zc1(1,j)]; 
                curr2 = A_i + Ry1 * [Xc1(2,j); Yc1(2,j); Zc1(2,j)];
                Xc1(1,j) = curr1(1); Yc1(1,j) = curr1(2); Zc1(1,j) = curr1(3); 
                Xc1(2,j) = curr2(1); Yc1(2,j) = curr2(2); Zc1(2,j) = curr2(3);
            end
            surf(ax, Xc1, Yc1, Zc1, 'FaceColor', colorL1, 'EdgeColor', 'none', 'FaceLighting', 'gouraud');
            text(ax, A_i(1), A_i(2), A_i(3)-35, sprintf('A%d', i), 'Color', 'k', ...
                 'FontSize', 11, 'FontWeight', 'bold', 'HorizontalAlignment', 'center');
            text(ax, P_i(1), P_i(2), P_i(3)+35, sprintf('B%d', i), 'Color', 'b', ...
                 'FontSize', 11, 'FontWeight', 'bold', 'HorizontalAlignment', 'center');
            
            [Xc2, Yc2, Zc2] = cylinder(radiusL2, N_pts); Zc2 = Zc2 * L2_val; 
            vec2 = (P_i - C_i) / L2_val; 
            if abs(vec2(3)) > 0.999
                Ry2 = zeros(3,3); 
                if vec2(3) < 0, Ry2 = eye(3)*-1; Ry2(3,3)=1; else, Ry2=eye(3); end
            else
                u_z=[0;0;1]; v2=cross(u_z,vec2); s2=norm(v2); c2=dot(u_z,vec2); 
                Vx2=[0 -v2(3) v2(2); v2(3) 0 -v2(1); -v2(2) v2(1) 0]; 
                Ry2=eye(3)+Vx2+Vx2^2*((1-c2)/s2^2);
            end
            for j = 1:N_pts+1
                curr1 = C_i + Ry2 * [Xc2(1,j); Yc2(1,j); Zc2(1,j)]; 
                curr2 = C_i + Ry2 * [Xc2(2,j); Yc2(2,j); Zc2(2,j)];
                Xc2(1,j) = curr1(1); Yc2(1,j) = curr1(2); Zc2(1,j) = curr1(3); 
                Xc2(2,j) = curr2(1); Yc2(2,j) = curr2(2); Zc2(2,j) = curr2(3);
            end
            surf(ax, Xc2, Yc2, Zc2, 'FaceColor', colorL2, 'EdgeColor', 'none', 'FaceLighting', 'gouraud');
        end
        
        Head_global = [x; y; z] + R * v_head; 
        plot3(ax, [x, Head_global(1)], [y, Head_global(2)], [z, Head_global(3)], ...
              'Color', [0.4 0.4 0.4], 'LineWidth', 6); 
        [Xs, Ys, Zs] = sphere(15); 
        surf(ax, Xs*80 + Head_global(1), Ys*80 + Head_global(2), Zs*80 + Head_global(3), ...
             'FaceColor', [1 0.8 0.6], 'EdgeColor', 'none');
        
        Pivot_global = [x; y; z] + R * v_piv; 
        [X_piv, Y_piv, Z_piv] = sphere(15); 
        surf(ax, X_piv*15 + Pivot_global(1), Y_piv*15 + Pivot_global(2), ...
             Z_piv*15 + Pivot_global(3), 'FaceColor', 'r', 'EdgeColor', 'none');
        
        if ~isempty(x_v_trail)
            plot3(ax, x_v_trail, y_v_trail, z_v_trail, 'b--', 'LineWidth', 1.5); 
        end
        if ~isempty(x_h_trail)
            plot3(ax, x_h_trail, y_h_trail, z_h_trail, 'm-', 'LineWidth', 2.5); 
        end
        camlight(ax, 'headlight');
    end

    % ---------------------------------------------------------------------
    % plot15Params : Vẽ biểu đồ các tham số quỹ đạo
    % ---------------------------------------------------------------------
    function plot15Params()
        if ~is_Validated || isempty(T_out)
            uialert(fig, 'Chưa có dữ liệu quỹ đạo! Hãy chạy mô phỏng trước.', 'Lỗi'); return;
        end
        format_type = dd_export.Value;
        if contains(format_type, 'Đầu người')
            X_target = Xh_out; Y_target = Yh_out; Z_target = Zh_out; titleStr = 'Đầu người';
        elseif contains(format_type, 'Tâm quay Pivot')
            X_target = Xv_out; Y_target = Yv_out; Z_target = Zv_out; titleStr = 'Tâm quay Pivot';
        else
            X_target = Xp_out; Y_target = Yp_out; Z_target = Zp_out; titleStr = 'Bàn máy';
        end
        t = T_out;
        N_pts = length(t);
        
        % Tính toán Vận tốc dài thế giới
        dt_mean = mean(diff(t)); 
        if dt_mean <= 0 || isnan(dt_mean), dt_mean = 0.01; end
        
        vx_w = gradient(X_target, dt_mean);
        vy_w = gradient(Y_target, dt_mean);
        vz_w = gradient(Z_target, dt_mean);
        
        if ~isempty(Ax_out)
            ax_plot = Ax_out; ay_plot = Ay_out; az_plot = Az_out;
            wx_plot = Wx_out; wy_plot = Wy_out; wz_plot = Wz_out;
        else
            ax_w = gradient(vx_w, dt_mean) / 1000;
            ay_w = gradient(vy_w, dt_mean) / 1000;
            az_w = gradient(vz_w, dt_mean) / 1000;
            
            ax_plot = zeros(N_pts,1); ay_plot = zeros(N_pts,1); az_plot = zeros(N_pts,1);
            for k = 1:N_pts
                R_k    = calcRotationMatrix(Yw_out(k), P_out(k), R_out(k));
                a_body = R_k' * [ax_w(k); ay_w(k); az_w(k)];
                ax_plot(k) = a_body(1); ay_plot(k) = a_body(2); az_plot(k) = a_body(3);
            end
            
            dYaw   = gradient(Yw_out, dt_mean) * (pi/180);
            dPitch = gradient(P_out, dt_mean)  * (pi/180);
            dRoll  = gradient(R_out, dt_mean)  * (pi/180);
            phi_r   = R_out * pi/180;
            theta_r = P_out * pi/180;
            wx_plot =  dRoll  - dYaw .* sin(theta_r);
            wy_plot =  dPitch .* cos(phi_r) + dYaw .* cos(theta_r) .* sin(phi_r);
            wz_plot = -dPitch .* sin(phi_r) + dYaw .* cos(theta_r) .* cos(phi_r);
        end
        
        % Tính Gia tốc góc
        alf_x = gradient(wx_plot, dt_mean);
        alf_y = gradient(wy_plot, dt_mean);
        alf_z = gradient(wz_plot, dt_mean);
        
        % Vận tốc dài trên body
        vx_body = zeros(N_pts,1); vy_body = zeros(N_pts,1); vz_body = zeros(N_pts,1);
        for k = 1:N_pts
            R_k = calcRotationMatrix(Yw_out(k), P_out(k), R_out(k));
            v_b = R_k' * [vx_w(k); vy_w(k); vz_w(k)];
            vx_body(k) = v_b(1); vy_body(k) = v_b(2); vz_body(k) = v_b(3);
        end
        
        % Tính toán góc động cơ
        phi_motor = zeros(N_pts, 6);
        for k = 1:N_pts
            pose_k = [Xp_out(k), Yp_out(k), Zp_out(k), R_out(k), P_out(k), Yw_out(k)];
            R_mat = calcRotationMatrix(pose_k(6), pose_k(5), pose_k(4));
            T_vec = [pose_k(1); pose_k(2); pose_k(3)];
            L_vec = T_vec + R_mat * B_mat - A_mat;
            l_sq = sum(L_vec.^2, 1);
            
            L1 = ed_l1.Value; L2 = ed_l2.Value;
            Q = l_sq - L2^2 + L1^2;
            M_val = (2 * L1 * L_vec(3, :));
            N_val = 2 * L1 * (cosd(gamma_ang) .* L_vec(1, :) + sind(gamma_ang) .* L_vec(2, :));
            arg = Q ./ sqrt(M_val.^2 + N_val.^2);
            arg = max(min(arg, 1), -1); 
            
            phi_raw = asind(arg) - atan2d(N_val, M_val);
            phi_out = zeros(1, 6);
            phi_out(1:2:5) = -(90 + phi_raw(1:2:5));
            phi_out(2:2:6) = (90 + phi_raw(2:2:6));
            phi_thuc = (phi_out - [90, -90, 90, -90, 90, -90]);
            phi_thuc(1:2:5) = -phi_thuc(1:2:5); % Đảo dấu động cơ lẻ
            phi_motor(k, :) = phi_thuc;
        end
        
        figPlot = figure('Name', ['Phân tích quỹ đạo: ' titleStr], 'NumberTitle', 'off', ...
                         'Position', [100 50 1400 860], 'Color', 'w', 'Renderer', 'painters');
        tg = uitabgroup(figPlot);
        
        % -----------------------------------------------------------------
        % Tab 1: Vị trí & Góc xoay
        % -----------------------------------------------------------------
        tab1 = uitab(tg, 'Title', '1. Vị trí & Góc xoay');
        
        cPos = [0.00 0.45 0.74]; cAng = [0.85 0.33 0.10];
        
        subplot(2,3,1, 'Parent', tab1); plot(t, X_target, 'Color', cPos, 'LineWidth', 1.5); grid on; box on; title('Vị trí X (mm)'); xlabel('t (s)');
        subplot(2,3,2, 'Parent', tab1); plot(t, Y_target, 'Color', cPos, 'LineWidth', 1.5); grid on; box on; title('Vị trí Y (mm)'); xlabel('t (s)');
        subplot(2,3,3, 'Parent', tab1); plot(t, Z_target, 'Color', cPos, 'LineWidth', 1.5); grid on; box on; title('Vị trí Z (mm)'); xlabel('t (s)');
        
        subplot(2,3,4, 'Parent', tab1); plot(t, R_out, 'Color', cAng, 'LineWidth', 1.5); grid on; box on; title('Góc Roll (°)'); xlabel('t (s)');
        subplot(2,3,5, 'Parent', tab1); plot(t, P_out, 'Color', cAng, 'LineWidth', 1.5); grid on; box on; title('Góc Pitch (°)'); xlabel('t (s)');
        subplot(2,3,6, 'Parent', tab1); plot(t, Yw_out, 'Color', cAng, 'LineWidth', 1.5); grid on; box on; title('Góc Yaw (°)'); xlabel('t (s)');
        
        % -----------------------------------------------------------------
        % Tab 2: Vận tốc, Vận tốc góc, Gia tốc, Gia tốc góc
        % -----------------------------------------------------------------
        tab2 = uitab(tg, 'Title', '2. Vận tốc & Gia tốc');
        
        cV = [0.0 0.5 0.0]; cW = [0.5 0.0 0.5]; cA = [0.9 0.6 0.0]; cAlf = [1.0 0.0 0.0];
        
        % Vận tốc dài
        subplot(4,3,1, 'Parent', tab2); plot(t, vx_body, 'Color', cV, 'LineWidth', 1.5); grid on; title('Vận tốc X (body) (mm/s)'); xlabel('t (s)');
        subplot(4,3,2, 'Parent', tab2); plot(t, vy_body, 'Color', cV, 'LineWidth', 1.5); grid on; title('Vận tốc Y (body) (mm/s)'); xlabel('t (s)');
        subplot(4,3,3, 'Parent', tab2); plot(t, vz_body, 'Color', cV, 'LineWidth', 1.5); grid on; title('Vận tốc Z (body) (mm/s)'); xlabel('t (s)');
        
        % Vận tốc góc
        subplot(4,3,4, 'Parent', tab2); plot(t, wx_plot, 'Color', cW, 'LineWidth', 1.5); grid on; title('Vận tốc góc X (rad/s)'); xlabel('t (s)');
        subplot(4,3,5, 'Parent', tab2); plot(t, wy_plot, 'Color', cW, 'LineWidth', 1.5); grid on; title('Vận tốc góc Y (rad/s)'); xlabel('t (s)');
        subplot(4,3,6, 'Parent', tab2); plot(t, wz_plot, 'Color', cW, 'LineWidth', 1.5); grid on; title('Vận tốc góc Z (rad/s)'); xlabel('t (s)');
        
        % Gia tốc dài
        subplot(4,3,7, 'Parent', tab2); plot(t, ax_plot, 'Color', cA, 'LineWidth', 1.5); grid on; title('Gia tốc X (body) (m/s²)'); xlabel('t (s)');
        subplot(4,3,8, 'Parent', tab2); plot(t, ay_plot, 'Color', cA, 'LineWidth', 1.5); grid on; title('Gia tốc Y (body) (m/s²)'); xlabel('t (s)');
        subplot(4,3,9, 'Parent', tab2); plot(t, az_plot, 'Color', cA, 'LineWidth', 1.5); grid on; title('Gia tốc Z (body) (m/s²)'); xlabel('t (s)');
        
        % Gia tốc góc
        subplot(4,3,10, 'Parent', tab2); plot(t, alf_x, 'Color', cAlf, 'LineWidth', 1.5); grid on; title('Gia tốc góc X (rad/s²)'); xlabel('t (s)');
        subplot(4,3,11, 'Parent', tab2); plot(t, alf_y, 'Color', cAlf, 'LineWidth', 1.5); grid on; title('Gia tốc góc Y (rad/s²)'); xlabel('t (s)');
        subplot(4,3,12, 'Parent', tab2); plot(t, alf_z, 'Color', cAlf, 'LineWidth', 1.5); grid on; title('Gia tốc góc Z (rad/s²)'); xlabel('t (s)');
        
        % -----------------------------------------------------------------
        % Tab 3: Quỹ đạo 3D & Góc động cơ
        % -----------------------------------------------------------------
        tab3 = uitab(tg, 'Title', '3. Quỹ đạo & Góc động cơ');
        
        % Quỹ đạo 3D chiếm 2 cột đầu
        ax3D = subplot(2,3,[1 4], 'Parent', tab3);
        scatter3(ax3D, X_target, Y_target, Z_target, 6, t, 'filled'); colormap(ax3D, 'jet');
        hold(ax3D, 'on');
        plot3(ax3D, X_target, Y_target, Z_target, 'k-', 'LineWidth', 0.8);
        plot3(ax3D, X_target(1), Y_target(1), Z_target(1), 'go', 'MarkerSize', 8, 'LineWidth', 2);
        plot3(ax3D, X_target(end), Y_target(end), Z_target(end), 'rs', 'MarkerSize', 8, 'LineWidth', 2);
        grid(ax3D, 'on'); box(ax3D, 'on'); xlabel(ax3D, 'X (mm)'); ylabel(ax3D, 'Y (mm)'); zlabel(ax3D, 'Z (mm)');
        title(ax3D, ['Quỹ đạo 3D — ' titleStr]); view(ax3D, 3); axis(ax3D, 'tight');
        
        % Các góc động cơ chia ra các subplot bên phải
        subplot(2,3,2, 'Parent', tab3); 
        plot(t, phi_motor(:,1), 'LineWidth', 1.5); hold on; 
        plot(t, phi_motor(:,2), 'LineWidth', 1.5); grid on;
        title('Góc Động cơ 1 & 2'); xlabel('t (s)'); ylabel('Góc (°)'); legend('Motor 1', 'Motor 2');
        
        subplot(2,3,3, 'Parent', tab3); 
        plot(t, phi_motor(:,3), 'LineWidth', 1.5); hold on; 
        plot(t, phi_motor(:,4), 'LineWidth', 1.5); grid on;
        title('Góc Động cơ 3 & 4'); xlabel('t (s)'); ylabel('Góc (°)'); legend('Motor 3', 'Motor 4');
        
        subplot(2,3,5, 'Parent', tab3); 
        plot(t, phi_motor(:,5), 'LineWidth', 1.5); hold on; 
        plot(t, phi_motor(:,6), 'LineWidth', 1.5); grid on;
        title('Góc Động cơ 5 & 6'); xlabel('t (s)'); ylabel('Góc (°)'); legend('Motor 5', 'Motor 6');
        
        subplot(2,3,6, 'Parent', tab3); 
        plot(t, phi_motor, 'LineWidth', 1); grid on;
        title('Tổng hợp 6 động cơ'); xlabel('t (s)'); ylabel('Góc (°)');
        legend({'M1', 'M2', 'M3', 'M4', 'M5', 'M6'}, 'Location', 'best', 'NumColumns', 2);
    end

    % ---------------------------------------------------------------------
    % parseMoogFile : Đọc file định dạng Moog (~M) và trả về ma trận số
    % ---------------------------------------------------------------------
    function data = parseMoogFile(filename)
        fid = fopen(filename, 'r');
        if fid == -1, error('Không thể mở file: %s', filename); end
        rawText = fread(fid, '*char')'; fclose(fid);
        lines = strsplit(rawText, '\n'); data = [];
        numberPattern = '[-+]?\d*\.?\d+(?:[eE][-+]?\d+)?';
        for i = 1:length(lines)
            line = strtrim(lines{i}); if isempty(line), continue; end
            numbers = regexp(line, numberPattern, 'match');
            if isempty(numbers), continue; end
            row = str2double(numbers); row(isnan(row)) = [];
            if ~isempty(row), data = [data; row]; end
        end
    end

    function showHelpDialog()
        help_fig = uifigure('Name', 'Hướng dẫn sử dụng - Dashboard Stewart', 'Position', [200 200 800 600]);
        html_str = [
            '<style>' ...
            'body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; padding: 20px; }' ...
            'h2 { color: #0056b3; border-bottom: 2px solid #0056b3; padding-bottom: 5px; margin-top: 20px; }' ...
            'h3 { color: #d35400; margin-bottom: 5px; }' ...
            'ul { margin-top: 5px; }' ...
            'li { margin-bottom: 8px; }' ...
            '.highlight { background-color: #f8f9fa; padding: 10px; border-left: 4px solid #28a745; margin-bottom: 15px; }' ...
            '.warning { background-color: #fff3cd; padding: 10px; border-left: 4px solid #ffc107; color: #856404; }' ...
            '</style>' ...
            '<h2>1. Ý Nghĩa Các Thông Số Cơ Khí</h2>' ...
            '<div class="highlight">' ...
            '<h3>Hệ tọa độ & Kích thước (Đơn vị: mm)</h3>' ...
            '<ul>' ...
            '<li><b>r_a (Base Radius):</b> Bán kính đường tròn đi qua tâm các khớp gắn trên bệ đế cố định.</li>' ...
            '<li><b>r_b (Platform Radius):</b> Bán kính đường tròn đi qua tâm các khớp cầu gắn trên mặt bàn di động. <i>(Thường r_a > r_b để đảm bảo độ vững chãi).</i></li>' ...
            '<li><b>L1 (Crank Length):</b> Chiều dài tay quay cơ khí (tính từ trục động cơ Servo đến khớp nối chữ U).</li>' ...
            '<li><b>L2 (Rod Length):</b> Chiều dài tay đòn / thanh đẩy (tính từ khớp nối tay quay đến khớp cầu trên bàn máy).</li>' ...
            '<li><b>Đầu người (X, Y, Z):</b> Tọa độ của điểm nhìn (đầu người lái) so với gốc tọa độ trung tâm của bàn máy. Thông số này quyết định độ văng ly tâm khi hệ thống tính toán thuật toán Tâm quay (Motion Cueing).</li>' ...
            '</ul>' ...
            '<h3>Phân bố góc (Đơn vị: Độ &deg;)</h3>' ...
            '<ul>' ...
            '<li><b>alpha_1 & delta_a:</b> Cấu hình cụm bệ đế. <i>alpha_1</i> là góc định hướng của chân thứ nhất. <i>delta_a</i> là khoảng cách góc giữa hai chân nằm trong cùng một cụm tam giác.</li>' ...
            '<li><b>beta_1 & delta_b:</b> Cấu hình cụm bàn máy. Tương tự bệ đế, dùng để nội suy tọa độ 6 khớp trên bệ mặt di động.</li>' ...
            '</ul>' ...
            '</div>' ...
            '<h2>2. Hướng Dẫn Sử Dụng</h2>' ...
            '<ul>' ...
            '<li><b>Bước 1:</b> Đo đạc thông số thực tế của cơ cấu cơ khí và nhập chính xác vào các ô nhập liệu.</li>' ...
            '<li><b>Bước 2 (Lưu trữ):</b> Bấm nút <b>LƯU FILE</b> để xuất cấu hình ra định dạng file (.mat / .json / .ini) phục vụ cho các lần chạy sau, tránh phải nhập lại thủ công.</li>' ...
            '<li><b>Bước 3 (Khởi tạo):</b> Bấm nút <b>CẬP NHẬT CẤU HÌNH</b>. Phần mềm sẽ tính toán lại toàn bộ ma trận Động học và làm mới bản sao số (Digital Twin) trên màn hình 3D dựa theo dữ liệu mới.</li>' ...
            '</ul>' ...
            '<h2>3. Lưu Ý & Cảnh Báo An Toàn</h2>' ...
            '<div class="warning">' ...
            '<ul>' ...
            '<li><b>Sai số đơn vị:</b> Đảm bảo tuyệt đối đơn vị nhập vào là <b>Milimet (mm)</b> và <b>Độ (&deg;)</b>. Nhầm lẫn sang Mét hoặc Radian sẽ khiến hệ thống tính toán sinh ra nội lực phá vỡ cơ khí.</li>' ...
            '<li><b>Tỷ lệ L1 / L2:</b> Tay đòn (L2) phải luôn dài hơn tay quay (L1) đáng kể. Nếu nhập L1 quá lớn hoặc L2 quá ngắn, hệ thống sẽ liên tục báo lỗi "Kịch giới hạn tầm với" hoặc rơi vào điểm kỳ dị động học (Singularity).</li>' ...
            '<li><b>Chiều trục Z của Đầu người:</b> Tùy thuộc vào quy ước hệ tọa độ bạn đang dùng, hãy cẩn thận với dấu của trục Z. Nếu trục Z hướng xuống mặt đất, điểm đầu người nằm bên trên bàn máy sẽ phải mang giá trị <b>Âm (-)</b>.</li>' ...
            '<li><b>Không thay đổi khi đang chạy:</b> Mọi thao tác "Cập nhật cấu hình" chỉ được thực hiện khi bàn máy đang ở trạng thái dừng an toàn (Home/Park). Tuyệt đối không thay đổi thông số khi hệ thống đang xuất xung chạy mô phỏng.</li>' ...
            '</ul>' ...
            '</div>'
        ];
        uihtml(help_fig, 'HTMLSource', html_str, 'Position', [10 10 780 580]);
    end
end