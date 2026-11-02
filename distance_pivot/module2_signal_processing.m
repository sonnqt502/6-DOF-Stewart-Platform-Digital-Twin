
function [proc_data, filter_metrics] = module2_signal_processing(t, head_sync, pivot_sync, test_axis, fc, is_plot)
% MODULE 2: XỬ LÝ TÍN HIỆU — FFT → LỌC → BÙ PHA/BIÊN ĐỘ → ĐÁNH GIÁ (CHO CẢ PIVOT VÀ HEAD)
%
% Input:
%   t            : Vector thời gian chung (từ Module 1)
%   head_sync    : Ma trận HEAD đã đồng bộ
%   pivot_sync   : Ma trận PIVOT đã đồng bộ (chuẩn thời gian)
%   test_axis    : 'Pitch' hoặc 'Roll' — chọn trục chính để phát hiện f_ex
%   fc           : Tần số cắt LPF (Hz)
%   is_plot      : true/false
%
% Output:
%   proc_data      : Struct chứa tất cả tín hiệu đã xử lý (HEAD đã bù)
%   filter_metrics : Struct RMSE trước/sau lọc, trước/sau bù cho cả Pivot & Head

    disp('--- Chạy Module 2: FFT → Lọc → Bù Pha/Biên độ → Đánh giá ---');

    % =====================================================================
    % BƯỚC 1: TRÍCH XUẤT DỮ LIỆU THÔ
    % =====================================================================
    % Cột theo chuẩn Module 1 (index 1-based)
    ax_h_raw    = head_sync(:, 10);
    ay_h_raw    = head_sync(:, 11);
    az_h_raw    = head_sync(:, 12);
    wx_h_raw    = head_sync(:, 18);
    wy_h_raw    = head_sync(:, 17);
    wz_h_raw    = head_sync(:, 16);
    yaw_h_raw   = head_sync(:, 5);
    pitch_h_raw = head_sync(:, 6);
    roll_h_raw  = head_sync(:, 7);

    % Pivot: chỉ cần gia tốc tuyến tính và vận tốc góc
    ax_p_raw = pivot_sync(:, 10);
    ay_p_raw = pivot_sync(:, 11);
    az_p_raw = pivot_sync(:, 12);
    wx_p_raw = pivot_sync(:, 18);
    wy_p_raw = pivot_sync(:, 17);
    wz_p_raw = pivot_sync(:, 16);

    % Gia tốc góc HEAD từ đạo hàm (gradient) có dùng Savitzky-Golay
    alphax_h_raw = gradient(sgolayfilt(wx_h_raw, 3, 11), t);
    alphay_h_raw = gradient(sgolayfilt(wy_h_raw, 3, 11), t);
    alphaz_h_raw = gradient(sgolayfilt(wz_h_raw, 3, 11), t);

    % =====================================================================
    % BƯỚC 2: TÍNH FFT — PHÁT HIỆN TẦN SỐ KÍCH THÍCH f_ex
    % =====================================================================
    if strcmpi(test_axis, 'Pitch')
        main_signal = wy_p_raw;   % Pitch: dùng wy của Pivot
    else
        main_signal = wx_p_raw;   % Roll:  dùng wx của Pivot
    end

    [f_ex_auto, fft_f, fft_amp] = auto_detect_f_ex(main_signal, t);
    fprintf(' + Tần số kích thích (FFT tự động): %.3f Hz\n', f_ex_auto);
    fprintf(' + Tần số cắt LPF (fc): %.2f Hz\n', fc);

    % Tính thông số bộ lọc để log ra màn hình
    phi_deg    = atand(f_ex_auto / fc);
    K_gain     = sqrt(1 + (f_ex_auto / fc)^2);
    dt         = mean(diff(t));
    delay_sec  = atan(f_ex_auto / fc) / (2 * pi * f_ex_auto);
    shift_idx  = round(delay_sec / dt);
    fprintf(' + Trễ pha tại f_ex: %.2f° (%.4f s = %d mẫu)\n', phi_deg, delay_sec, shift_idx);
    fprintf(' + Suy giảm biên độ tại f_ex: 1/%.4f (bù x%.4f)\n', 1/K_gain, K_gain);

    % =====================================================================
    % BƯỚC 3: LỌC BẰNG LPF BẬC 1 (CHO CẢ PIVOT VÀ HEAD)
    % =====================================================================
    fprintf(' + Lọc LPF bậc 1 cho PIVOT...\n');
    ax_p_filt = apply_lpf_only(ax_p_raw, t, fc);
    ay_p_filt = apply_lpf_only(ay_p_raw, t, fc);
    az_p_filt = apply_lpf_only(az_p_raw, t, fc);
    wx_p_filt = apply_lpf_only(wx_p_raw, t, fc);
    wy_p_filt = apply_lpf_only(wy_p_raw, t, fc);
    wz_p_filt = apply_lpf_only(wz_p_raw, t, fc);

    fprintf(' + Lọc LPF bậc 1 cho HEAD (Phần bổ sung)...\n');
    ax_h_filt = apply_lpf_only(ax_h_raw, t, fc);
    ay_h_filt = apply_lpf_only(ay_h_raw, t, fc);
    az_h_filt = apply_lpf_only(az_h_raw, t, fc);
    wx_h_filt = apply_lpf_only(wx_h_raw, t, fc);
    wy_h_filt = apply_lpf_only(wy_h_raw, t, fc);
    wz_h_filt = apply_lpf_only(wz_h_raw, t, fc);

    % Lọc cho gia tốc góc HEAD
    alphax_h_filt = apply_lpf_only(alphax_h_raw, t, fc);
    alphay_h_filt = apply_lpf_only(alphay_h_raw, t, fc);
    alphaz_h_filt = apply_lpf_only(alphaz_h_raw, t, fc);

    % =====================================================================
    % BƯỚC 4: BÙ TRỄ PHA VÀ BIÊN ĐỘ (CHO CẢ PIVOT VÀ HEAD)
    % =====================================================================
    fprintf(' + Bù trễ pha và biên độ cho PIVOT...\n');
    ax_p_comp = apply_compensation(ax_p_filt, t, fc, f_ex_auto);
    ay_p_comp = apply_compensation(ay_p_filt, t, fc, f_ex_auto);
    az_p_comp = apply_compensation(az_p_filt, t, fc, f_ex_auto);
    wx_p_comp = apply_compensation(wx_p_filt, t, fc, f_ex_auto);
    wy_p_comp = apply_compensation(wy_p_filt, t, fc, f_ex_auto);
    wz_p_comp = apply_compensation(wz_p_filt, t, fc, f_ex_auto);

    fprintf(' + Bù trễ pha và biên độ cho HEAD (Phần bổ sung)...\n');
    ax_h_comp = apply_compensation(ax_h_filt, t, fc, f_ex_auto);
    ay_h_comp = apply_compensation(ay_h_filt, t, fc, f_ex_auto);
    az_h_comp = apply_compensation(az_h_filt, t, fc, f_ex_auto);
    wx_h_comp = apply_compensation(wx_h_filt, t, fc, f_ex_auto);
    wy_h_comp = apply_compensation(wy_h_filt, t, fc, f_ex_auto);
    wz_h_comp = apply_compensation(wz_h_filt, t, fc, f_ex_auto);

    % Bù cho gia tốc góc HEAD
    alphax_h_comp = apply_compensation(alphax_h_filt, t, fc, f_ex_auto);
    alphay_h_comp = apply_compensation(alphay_h_filt, t, fc, f_ex_auto);
    alphaz_h_comp = apply_compensation(alphaz_h_filt, t, fc, f_ex_auto);

    % =====================================================================
    % BƯỚC 5: ĐÁNH GIÁ RMSE
    % =====================================================================
    fprintf('\n---> BẢNG RMSE PIVOT <---\n');
    fprintf('  %-10s  %12s  %12s\n', 'Tham số', 'RMSE (Filt)', 'RMSE (Comp)');
    fprintf('  %s\n', repmat('-', 1, 38));
    params_p = {ax_p_raw, ay_p_raw, az_p_raw, wx_p_raw, wy_p_raw, wz_p_raw};
    filts_p  = {ax_p_filt, ay_p_filt, az_p_filt, wx_p_filt, wy_p_filt, wz_p_filt};
    comps_p  = {ax_p_comp, ay_p_comp, az_p_comp, wx_p_comp, wy_p_comp, wz_p_comp};
    names_p  = {'ax_p', 'ay_p', 'az_p', 'wx_p', 'wy_p', 'wz_p'};
    for i = 1:length(params_p)
        r_f = calc_rmse(params_p{i}, filts_p{i});
        r_c = calc_rmse(params_p{i}, comps_p{i});
        filter_metrics.Pivot.(names_p{i}).RMSE_filt = r_f;
        filter_metrics.Pivot.(names_p{i}).RMSE_comp = r_c;
        fprintf('  %-10s  %12.6f  %12.6f\n', names_p{i}, r_f, r_c);
    end

    fprintf('\n---> BẢNG RMSE ALPHA HEAD <---\n');
    fprintf('  %-10s  %12s  %12s\n', 'Tham số', 'RMSE (Filt)', 'RMSE (Comp)');
    fprintf('  %s\n', repmat('-', 1, 38));
    params_ah = {alphax_h_raw, alphay_h_raw, alphaz_h_raw};
    filts_ah  = {alphax_h_filt, alphay_h_filt, alphaz_h_filt};
    comps_ah  = {alphax_h_comp, alphay_h_comp, alphaz_h_comp};
    names_ah  = {'alpha_x', 'alpha_y', 'alpha_z'};
    for i = 1:length(params_ah)
        r_f = calc_rmse(params_ah{i}, filts_ah{i});
        r_c = calc_rmse(params_ah{i}, comps_ah{i});
        filter_metrics.Head.(names_ah{i}).RMSE_filt = r_f;
        filter_metrics.Head.(names_ah{i}).RMSE_comp = r_c;
        fprintf('  %-10s  %12.6f  %12.6f\n', names_ah{i}, r_f, r_c);
    end

    fprintf('\n---> BẢNG RMSE CÁC THÔNG SỐ HEAD (BỔ SUNG) <---\n');
    fprintf('  %-10s  %12s  %12s\n', 'Tham số', 'RMSE (Filt)', 'RMSE (Comp)');
    fprintf('  %s\n', repmat('-', 1, 38));
    params_h = {ax_h_raw, ay_h_raw, az_h_raw, wx_h_raw, wy_h_raw, wz_h_raw};
    filts_h  = {ax_h_filt, ay_h_filt, az_h_filt, wx_h_filt, wy_h_filt, wz_h_filt};
    comps_h  = {ax_h_comp, ay_h_comp, az_h_comp, wx_h_comp, wy_h_comp, wz_h_comp};
    names_h  = {'ax', 'ay', 'az', 'wx', 'wy', 'wz'};
    for i = 1:length(params_h)
        r_f = calc_rmse(params_h{i}, filts_h{i});
        r_c = calc_rmse(params_h{i}, comps_h{i});
        filter_metrics.Head.(names_h{i}).RMSE_filt = r_f;
        filter_metrics.Head.(names_h{i}).RMSE_comp = r_c;
        fprintf('  %-10s  %12.6f  %12.6f\n', names_h{i}, r_f, r_c);
    end

    % =====================================================================
    % BƯỚC 6: ĐÓNG GÓI proc_data (CHUYỂN DỮ LIỆU ĐÃ BÙ CỦA HEAD CHO MODULE SAU)
    % =====================================================================
    proc_data.t = t;
    proc_data.isPitch = strcmpi(test_axis, 'Pitch');
    
    % HEAD: Dùng bản đã BÙ theo đúng yêu cầu
    proc_data.ax_h    = ax_h_comp;
    proc_data.ay_h    = ay_h_comp;
    proc_data.az_h    = az_h_comp;
    proc_data.gyro_x  = wx_h_comp;
    proc_data.gyro_y  = wy_h_comp;
    proc_data.gyro_z  = wz_h_comp;
    proc_data.alpha_x = alphax_h_comp;
    proc_data.alpha_y = alphay_h_comp;
    proc_data.alpha_z = alphaz_h_comp;
    
    % PIVOT: dùng bản đã bù
    proc_data.ax_p = ax_p_comp;
    proc_data.ay_p = ay_p_comp;
    proc_data.az_p = az_p_comp;
    proc_data.wx_p = wx_p_comp;
    proc_data.wy_p = wy_p_comp;
    proc_data.wz_p = wz_p_comp;
    
    proc_data.roll    = roll_h_raw;
    proc_data.pitch   = pitch_h_raw;
    proc_data.yaw     = yaw_h_raw;

    if proc_data.isPitch
        proc_data.gyro_h  = proc_data.gyro_y;
        proc_data.alpha_h = proc_data.alpha_y;
    else
        proc_data.gyro_h  = proc_data.gyro_x;
        proc_data.alpha_h = proc_data.alpha_x;
    end

    % =====================================================================
    % BƯỚC 7: VẼ BIỂU ĐỒ 
    % =====================================================================
    if nargin < 6 || is_plot
        % Gom mảng Head để truyền vào hàm vẽ không bị rối
        head_raws  = {ax_h_raw, ay_h_raw, az_h_raw, wx_h_raw, wy_h_raw, wz_h_raw};
        head_filts = {ax_h_filt, ay_h_filt, az_h_filt, wx_h_filt, wy_h_filt, wz_h_filt};
        head_comps = {ax_h_comp, ay_h_comp, az_h_comp, wx_h_comp, wy_h_comp, wz_h_comp};

        plot_all_results(t, fft_f, fft_amp, f_ex_auto, fc, ...
            ax_p_raw, ax_p_filt, ax_p_comp, ...
            ay_p_raw, ay_p_filt, ay_p_comp, ...
            az_p_raw, az_p_filt, az_p_comp, ...
            wx_p_raw, wx_p_filt, wx_p_comp, ...
            wy_p_raw, wy_p_filt, wy_p_comp, ...
            wz_p_raw, wz_p_filt, wz_p_comp, ...
            alphay_h_raw, alphay_h_filt, alphay_h_comp, ...
            filter_metrics, head_raws, head_filts, head_comps);
    end
end

% =========================================================================
% HÀM CON 1: LPF BẬC 1 (CHỈ LỌC)
% =========================================================================
function data_filt = apply_lpf_only(data, t, fc)
    dt    = mean(diff(t));
    RC    = 1 / (2 * pi * fc);
    alpha = dt / (RC + dt);
    N     = length(data);
    data_filt    = zeros(N, 1);
    data_filt(1) = data(1);
    for k = 2:N
        data_filt(k) = alpha * data(k) + (1 - alpha) * data_filt(k-1);
    end
end

% =========================================================================
% HÀM CON 2: BÙ TRỄ PHA VÀ SUY GIẢM BIÊN ĐỘ
% =========================================================================
function data_comp = apply_compensation(data_filt, t, fc, f_ex)
    if f_ex <= 0
        data_comp = data_filt;
        return;
    end
    K_gain     = sqrt(1 + (f_ex / fc)^2);
    data_gained = data_filt * K_gain;
    dt        = mean(diff(t));
    phi_rad   = atan(f_ex / fc);           
    delay_sec = phi_rad / (2 * pi * f_ex); 
    shift_idx = round(delay_sec / dt);     
    N         = length(data_gained);
    data_comp = zeros(N, 1);
    if shift_idx > 0 && shift_idx < N
        data_comp(1 : N - shift_idx) = data_gained(shift_idx + 1 : end);
        data_comp(N - shift_idx + 1 : end) = data_gained(end : -1 : end - shift_idx + 1);
    else
        data_comp = data_gained;
    end
end

% =========================================================================
% HÀM CON 3: PHÁT HIỆN TẦN SỐ KÍCH THÍCH QUA FFT
% =========================================================================
function [f_ex, f_axis, amp_spectrum] = auto_detect_f_ex(data, t)
    dt   = mean(diff(t));
    Fs   = 1 / dt;
    L    = length(data);
    data_zm = data - mean(data, 'omitnan');
    Y  = fft(data_zm);
    P1 = abs(Y / L);
    P1 = P1(1 : floor(L/2) + 1);
    P1(2:end-1) = 2 * P1(2:end-1);
    f_axis = Fs * (0 : floor(L/2)) / L;
    valid      = f_axis > 0.05 & f_axis < 15;
    P1_valid   = P1(valid);
    f_valid    = f_axis(valid);
    [~, idx]   = max(P1_valid);
    if isempty(idx)
        f_ex = 0;
    else
        f_ex = f_valid(idx);
    end
    amp_spectrum = P1;
end

% =========================================================================
% HÀM CON 4: TÍNH RMSE
% =========================================================================
function rmse = calc_rmse(raw, processed)
    diff_vec = raw(:) - processed(:);
    rmse = sqrt(mean(diff_vec(~isnan(diff_vec)).^2));
end

% =========================================================================
% HÀM CON 5: VẼ TOÀN BỘ KẾT QUẢ (TÁCH LÀM 3 FIGURE ĐỂ CÓ CẢ PIVOT VÀ HEAD)
% =========================================================================
function plot_all_results(t, fft_f, fft_amp, f_ex, fc, ...
        ax_r, ax_f, ax_c, ay_r, ay_f, ay_c, az_r, az_f, az_c, ...
        wx_r, wx_f, wx_c, wy_r, wy_f, wy_c, wz_r, wz_f, wz_c, ...
        alp_r, alp_f, alp_c, metrics, head_raws, head_filts, head_comps)

    c_raw  = [0.60 0.60 0.60];   % Xám
    c_filt = [0.85 0.33 0.10];   % Cam
    c_comp = [0.00 0.45 0.74];   % Xanh dương
    lw_raw  = 1.0;  
    lw_filt = 1.5;  
    lw_comp = 2.0;  

    %% =================================================================
    % FIGURE 1: PHÂN TÍCH TẦN SỐ & BỘ LỌC (Như nguyên bản của bạn)
    % =================================================================
    fig1 = figure('Name', 'Module 2: Phân tích Tần số & Đặc tuyến LPF', ...
                  'Position', [50 100 1000 700], 'Color', 'white');
    
    subplot(2, 2, 1);
    plot(fft_f, fft_amp, 'Color', [0.2 0.6 0.2], 'LineWidth', 1.5); hold on;
    xline(f_ex, '--r', sprintf('f_{ex}=%.3fHz', f_ex), 'LabelVerticalAlignment','bottom', 'LineWidth', 1.5, 'FontSize', 10);
    xline(fc,   '--b', sprintf('f_c=%.1fHz', fc), 'LabelVerticalAlignment','bottom', 'LineWidth', 1.5, 'FontSize', 10);
    xlim([0, min(max(fft_f), 20)]);
    xlabel('Tần số (Hz)', 'FontSize', 11, 'FontWeight', 'bold'); 
    ylabel('Biên độ', 'FontSize', 11, 'FontWeight', 'bold');
    title('FFT Tín hiệu PIVOT', 'FontSize', 12);
    grid on;
    
    subplot(2, 2, 2);
    f_bode = logspace(-2, log10(max(fft_f)*1.5 + 1), 400);
    H_mag  = 1 ./ sqrt(1 + (f_bode/fc).^2);
    semilogx(f_bode, 20*log10(H_mag), 'b', 'LineWidth', 1.8); hold on;
    K_at_fex = 1 / sqrt(1 + (f_ex/fc)^2);
    semilogx(f_ex, 20*log10(K_at_fex), 'rv', 'MarkerFaceColor','r', 'MarkerSize', 8);
    xline(fc, '--k', sprintf('f_c=%.1f Hz', fc), 'LineWidth', 1, 'FontSize', 10);
    text(f_ex*1.2, 20*log10(K_at_fex), sprintf('  %.1f dB', 20*log10(K_at_fex)), 'Color','r', 'FontSize', 10, 'FontWeight', 'bold');
    xlabel('Tần số (Hz)', 'FontSize', 11, 'FontWeight', 'bold'); 
    ylabel('|H| (dB)', 'FontSize', 11, 'FontWeight', 'bold');
    title('Đặc tuyến biên độ LPF', 'FontSize', 12);
    grid on;
    
    subplot(2, 2, 3);
    H_phase = -atand(f_bode / fc);
    semilogx(f_bode, H_phase, 'r', 'LineWidth', 1.8); hold on;
    ph_at_fex = -atand(f_ex / fc);
    semilogx(f_ex, ph_at_fex, 'bv', 'MarkerFaceColor','b', 'MarkerSize', 8);
    xline(fc, '--k', sprintf('f_c=%.1f Hz', fc), 'LineWidth', 1, 'FontSize', 10);
    text(f_ex*1.2, ph_at_fex, sprintf('  %.1f°', ph_at_fex), 'Color','b', 'FontSize', 10, 'FontWeight', 'bold');
    xlabel('Tần số (Hz)', 'FontSize', 11, 'FontWeight', 'bold'); 
    ylabel('Pha (°)', 'FontSize', 11, 'FontWeight', 'bold');
    title('Đặc tuyến pha LPF', 'FontSize', 12);
    grid on;
    
    subplot(2, 2, 4);
    axis off;
    dt_mean = mean(diff(t));
    delay_s = atan(f_ex/fc)/(2*pi*f_ex);
    info_str = sprintf([...
        '\\bfTHÔNG SỐ BỘ LỌC\\rm\n\n'...
        'Tần số kích thích (f_{ex}) : %.4f Hz\n'...
        'Tần số cắt LPF (f_c)     : %.2f Hz\n\n'...
        'Hệ số bù biên độ (K)     : ×%.4f\n'...
        'Trễ pha tại f_{ex}        : %.2f°\n'...
        'Trễ thời gian tương đương: %.4f giây\n'...
        'Dịch mẫu bù trễ         : %d mẫu'], ...
        f_ex, fc, sqrt(1 + (f_ex/fc)^2), atand(f_ex/fc), delay_s, round(delay_s/dt_mean));
    text(0.1, 0.8, info_str, 'Units','normalized', 'VerticalAlignment','top', 'FontSize', 13, 'Interpreter','tex');

    %% =================================================================
    % FIGURE 2: TÍN HIỆU THỜI GIAN PIVOT (Như nguyên bản của bạn)
    % =================================================================
    fig2 = figure('Name', 'Module 2: Tín hiệu Thời gian PIVOT', ...
                  'Position', [100 50 1400 900], 'Color', 'white');
    all_time_ax = gobjects(7, 1);
    pivot_raws  = {ax_r, ay_r, az_r, wx_r, wy_r, wz_r};
    pivot_filts = {ax_f, ay_f, az_f, wx_f, wy_f, wz_f};
    pivot_comps = {ax_c, ay_c, az_c, wx_c, wy_c, wz_c};
    pivot_names = {'ax_{PIVOT} (m/s^2)', 'ay_{PIVOT} (m/s^2)', 'az_{PIVOT} (m/s^2)', ...
                   '\omega_x_{PIVOT} (rad/s)', '\omega_y_{PIVOT} (rad/s)', '\omega_z_{PIVOT} (rad/s)'};
    rmse_fields = {'ax_p', 'ay_p', 'az_p', 'wx_p', 'wy_p', 'wz_p'};
    
    plot_slots = [1, 3, 5, 2, 4, 6]; 
    for i = 1:6
        sp = subplot(4, 2, plot_slots(i));
        all_time_ax(i) = sp;
        r_f = metrics.Pivot.(rmse_fields{i}).RMSE_filt;
        r_c = metrics.Pivot.(rmse_fields{i}).RMSE_comp;
        plot_three_lines(sp, t, pivot_raws{i}, pivot_filts{i}, pivot_comps{i}, ...
            c_raw, c_filt, c_comp, lw_raw, lw_filt, lw_comp, pivot_names{i}, r_f, r_c);
    end
    sp_alp = subplot(4, 2, 7);
    all_time_ax(7) = sp_alp;
    plot_three_lines(sp_alp, t, alp_r, alp_f, alp_c, ...
        c_raw, c_filt, c_comp, lw_raw, lw_filt, lw_comp, '\alpha_y HEAD (rad/s^2)', ...
        metrics.Head.alpha_y.RMSE_filt, metrics.Head.alpha_y.RMSE_comp);
    
    linkaxes(all_time_ax, 'x');
    
    subplot(4, 2, 8);
    axis off; hold on;
    plot(NaN, NaN, 'Color', c_raw,  'LineWidth', 2.5, 'DisplayName', 'Raw (Tín hiệu thô PIVOT)');
    plot(NaN, NaN, 'Color', c_filt, 'LineWidth', 2.5, 'DisplayName', 'Filtered (Chỉ Lọc)');
    plot(NaN, NaN, 'Color', c_comp, 'LineWidth', 2.5, 'DisplayName', 'Compensated (Lọc + Bù)');
    legend('Location', 'best', 'FontSize', 12, 'Box', 'off', 'FontWeight', 'bold');

    %% =================================================================
    % FIGURE 3: TÍN HIỆU THỜI GIAN HEAD (ĐƯỢC BỔ SUNG THÊM ĐỂ ĐÁNH GIÁ)
    % =================================================================
    fig3 = figure('Name', 'Module 2: Tín hiệu Thời gian HEAD', ...
                  'Position', [150 70 1400 900], 'Color', 'white');
    all_head_ax = gobjects(6, 1);
    head_names = {'ax_{HEAD} (m/s^2)', 'ay_{HEAD} (m/s^2)', 'az_{HEAD} (m/s^2)', ...
                  '\omega_x_{HEAD} (rad/s)', '\omega_y_{HEAD} (rad/s)', '\omega_z_{HEAD} (rad/s)'};
    rmse_fields_h = {'ax', 'ay', 'az', 'wx', 'wy', 'wz'};
    
    for i = 1:6
        sp = subplot(4, 2, plot_slots(i));
        all_head_ax(i) = sp;
        r_f = metrics.Head.(rmse_fields_h{i}).RMSE_filt;
        r_c = metrics.Head.(rmse_fields_h{i}).RMSE_comp;
        plot_three_lines(sp, t, head_raws{i}, head_filts{i}, head_comps{i}, ...
            c_raw, c_filt, c_comp, lw_raw, lw_filt, lw_comp, head_names{i}, r_f, r_c);
    end
    
    linkaxes(all_head_ax, 'x');


    subplot(4, 2, [7 8]); % Chiếm trọn bề ngang để hiển thị Legend cho đẹp
    axis off; hold on;
    plot(NaN, NaN, 'Color', c_raw,  'LineWidth', 2.5, 'DisplayName', 'Raw (Tín hiệu thô HEAD)');
    plot(NaN, NaN, 'Color', c_filt, 'LineWidth', 2.5, 'DisplayName', 'Filtered (Chỉ Lọc LPF)');
    plot(NaN, NaN, 'Color', c_comp, 'LineWidth', 2.5, 'DisplayName', 'Compensated (Lọc + Đã bù)');
    legend('Location', 'best', 'Orientation', 'horizontal', 'FontSize', 12, 'Box', 'off', 'FontWeight', 'bold');
end

% =========================================================================
% HÀM CON 6: HÀM VẼ 3 ĐƯỜNG TIÊU CHUẨN
% =========================================================================
function plot_three_lines(sp, t, raw, filt, comp, c_raw, c_filt, c_comp, lw_r, lw_f, lw_c, ylab, rmse_filt, rmse_comp)
    axes(sp); 
    plot(t, raw,  '-', 'Color', c_raw,  'LineWidth', lw_r); hold on;
    plot(t, filt, '-', 'Color', c_filt, 'LineWidth', lw_f);
    plot(t, comp, '-', 'Color', c_comp, 'LineWidth', lw_c);
    
    ylabel(ylab, 'FontSize', 11, 'FontWeight', 'bold');
    title(sprintf('RMSE: Lọc = %.4f  |  Bù = %.4f', rmse_filt, rmse_comp), 'FontSize', 11, 'Color', [0.2 0.2 0.2]);
    grid on; box on;
end

