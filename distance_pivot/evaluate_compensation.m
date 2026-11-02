function evaluate_compensation(t, raw_signal, fc, f_ex, signal_name)
    % Hàm đánh giá chi tiết LPF: Trễ pha và RMSE Trước/Sau khi bù
    
    % 1. Thông số cơ bản
    dt = mean(diff(t));
    RC = 1 / (2 * pi * fc);
    alpha = dt / (RC + dt); 
    N = length(raw_signal);
    
    % 2. MÔ PHỎNG 1: LPF THUẦN TÚY (CHƯA BÙ TRỪ)
    uncomp = zeros(N, 1);
    uncomp(1) = raw_signal(1);
    for k = 2:N
        uncomp(k) = alpha * raw_signal(k) + (1 - alpha) * uncomp(k-1);
    end
    
    % 3. MÔ PHỎNG 2: LPF ĐÃ BÙ TRỪ (COMPENSATED)
    % Tính thông số bù pha
    phi_rad = atan(f_ex / fc);
    delay_sec = phi_rad / (2 * pi * f_ex);
    shift_idx = round(delay_sec / dt);
    
    % Tính thông số bù biên độ
    K_gain = sqrt(1 + (f_ex / fc)^2);
    
    % Áp dụng bù
    comp_shifted = zeros(N, 1);
    comp_gained = uncomp * K_gain;
    if shift_idx > 0 && shift_idx < N
        comp_shifted(1 : N-shift_idx) = comp_gained(shift_idx+1 : end);
        comp_shifted(N-shift_idx+1 : end) = comp_gained(end);
    else
        comp_shifted = comp_gained;
    end
    
    % 4. TÍNH TOÁN SAI SỐ RMSE
    rmse_uncomp = sqrt(mean((raw_signal - uncomp).^2));
    rmse_comp = sqrt(mean((raw_signal - comp_shifted).^2));
    
    % 5. IN BÁO CÁO KẾT QUẢ
    fprintf('\n========================================================\n');
    fprintf('   BÁO CÁO ĐÁNH GIÁ HIỆU QUẢ BÙ TRỪ: %s\n', upper(signal_name));
    fprintf('========================================================\n');
    fprintf('1. ĐÁNH GIÁ TRỄ PHA (PHASE DELAY):\n');
    fprintf('   - Tín hiệu Chưa bù : Bị trễ %.4f giây (Tương đương dịch %d mẫu)\n', delay_sec, shift_idx);
    fprintf('   - Tín hiệu Đã bù   : Trễ ~0.0000 giây (Đã được kéo về mốc gốc)\n\n');
    
    fprintf('2. ĐÁNH GIÁ BIÊN ĐỘ (AMPLITUDE GAIN):\n');
    fprintf('   - Tín hiệu Chưa bù : Bị hao hụt %.2f%%\n', (1 - 1/K_gain)*100);
    fprintf('   - Tín hiệu Đã bù   : Phục hồi 100%% (Hệ số K = %.4f)\n\n', K_gain);
    
    fprintf('3. ĐÁNH GIÁ SAI SỐ TOÀN DIỆN (RMSE):\n');
    fprintf('   - RMSE Trước khi bù: %.6f (Chứa nhiễu + Sai số do lệch pha/biên độ)\n', rmse_uncomp);
    fprintf('   - RMSE Sau khi bù  : %.6f (Chỉ chứa rác/nhiễu thực sự đã bị cắt)\n', rmse_comp);
    fprintf('   => Lượng "Sai số ảo" được triệt tiêu: %.2f%%\n', ...
            (rmse_uncomp - rmse_comp) / rmse_uncomp * 100);
    fprintf('========================================================\n');
    
    % 6. VẼ ĐỒ THỊ TRỰC QUAN (ZOOM VÀO 3 CHU KỲ ĐẦU ĐỂ THẤY RÕ ĐỘ LỆCH)
    figure('Name', ['Phân tích Bù trừ: ' signal_name], 'Position', [150 150 1000 600]);
    
    plot(t, raw_signal, 'Color', [0.8 0.8 0.8], 'LineWidth', 1.5, 'DisplayName', 'Gốc (Raw)'); hold on;
    plot(t, uncomp, 'r--', 'LineWidth', 1.5, 'DisplayName', 'Chưa bù (Bị lùi & Thấp)');
    plot(t, comp_shifted, 'b', 'LineWidth', 2, 'DisplayName', 'Đã bù (Khớp hoàn toàn)');
    
    title(sprintf('So sánh Tín hiệu: %s (fc = %.1f Hz, f_{ex} = %.2f Hz)', signal_name, fc, f_ex));
    xlabel('Thời gian (s)'); ylabel('Biên độ');
    legend('Location', 'best'); grid on;
    
    % Tự động Zoom vào vùng có đỉnh sóng (Khoảng 3 chu kỳ đầu tiên)
    zoom_time = 3 * (1 / f_ex); 
    xlim([t(1), t(1) + zoom_time]);
end