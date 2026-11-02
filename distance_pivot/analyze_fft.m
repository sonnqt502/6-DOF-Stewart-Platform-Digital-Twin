function analyze_fft(t_sync, data_vector, signal_name)
    % Hàm phân tích phổ tần số bằng FFT để tìm tần số cắt fc
    % t_sync: Vector thời gian (giúp tự động tính tần số lấy mẫu Fs)
    % data_vector: Cột tín hiệu cần phân tích (VD: gia tốc trục Z)
    % signal_name: Tên tín hiệu để đặt tiêu đề đồ thị (VD: 'Gia tốc Z Pivot')
    
    % 1. Tính tần số lấy mẫu (Sampling Frequency)
    dt = mean(diff(t_sync));
    Fs = 1 / dt;
    L = length(data_vector);
    
    % 2. Tiền xử lý: Khử thành phần một chiều (DC offset)
    % RẤT QUAN TRỌNG: Nếu không trừ đi giá trị trung bình, 
    % đỉnh tại 0Hz sẽ khổng lồ và đè bẹp các tín hiệu khác.
    data_zero_mean = data_vector - mean(data_vector, 'omitnan');
    
    % 3. Chạy thuật toán FFT
    Y = fft(data_zero_mean);
    
    % 4. Tính toán biên độ phổ (Single-Sided Amplitude Spectrum)
    P2 = abs(Y / L);               % Phổ 2 phía
    P1 = P2(1:floor(L/2)+1);       % Lấy nửa phổ dương
    P1(2:end-1) = 2 * P1(2:end-1); % Bù biên độ cho nửa đã bỏ đi
    
    % Trục tần số
    f = Fs * (0:(floor(L/2))) / L;
    
    % 5. Vẽ biểu đồ "Chụp X-Quang"
    figure('Name', ['Phân tích FFT: ' signal_name], 'Position', [200 200 900 500]);
    
    % Đồ thị 1: Toàn cảnh (0 đến Fs/2)
    subplot(1, 2, 1);
    plot(f, P1, 'b', 'LineWidth', 1.2);
    title('Phổ tần số toàn cảnh (Nyquist)');
    xlabel('Tần số f (Hz)'); ylabel('Biên độ |P1(f)|');
    grid on;
    
    % Đồ thị 2: Phóng to vào vùng tần số thấp (Cơ khí thường < 10Hz)
    subplot(1, 2, 2);
    plot(f, P1, 'r', 'LineWidth', 1.5);
    title('Vùng quan tâm (Tìm fc)');
    xlabel('Tần số f (Hz)'); ylabel('Biên độ');
    xlim([0 10]); % Chỉ soi từ 0 đến 10 Hz
    grid on;
    
    % Đánh dấu đỉnh cao nhất
    [max_amp, max_idx] = max(P1);
    hold on;
    plot(f(max_idx), max_amp, 'k*', 'MarkerSize', 8);
    text(f(max_idx) + 0.2, max_amp, sprintf('Đỉnh: %.2f Hz', f(max_idx)), 'FontWeight', 'bold');
    
    fprintf('--- BÁO CÁO FFT: %s ---\n', signal_name);
    fprintf(' + Tần số lấy mẫu hệ thống (Fs) : %.2f Hz\n', Fs);
    fprintf(' + Tần số dao động chủ đạo      : %.2f Hz\n', f(max_idx));
    fprintf(' => GỢI Ý: Hãy chọn fc lớn hơn %.2f Hz một chút (VD: %.1f Hz hoặc %.1f Hz).\n\n', ...
            f(max_idx), f(max_idx)*3, f(max_idx)*5);
end