function check_acc(filename)
% Hàm kiểm tra nhanh biểu đồ dữ liệu của file CSV
% Không thuộc luồng chính của chương trình, chỉ dùng để debug/kiểm tra.
% Cách dùng: 
%   check_acc('Pivot_Command.csv') 
%   Hoặc gọi check_acc() (sẽ hiện hộp thoại chọn file)

    if nargin < 1
        [fname, fpath] = uigetfile('*.csv', 'Select CSV file');
        if isequal(fname,0), return; end
        filename = fullfile(fpath, fname);
    end
    
    % Dùng parseMoogFile đã có sẵn để lấy chuẩn 16 cột dữ liệu
    try
        data = parseMoogFile(filename);
    catch ME
        error('Lỗi khi đọc file. Đảm bảo parseMoogFile.m nằm cùng thư mục. Chi tiết: %s', ME.message);
    end
    
    t   = data(:, 1);
    
    % Gia tốc quán tính (Axi, Ayi, Azi) - Cột 8, 9, 10
    Axi = data(:, 8);
    Ayi = data(:, 9);
    Azi = data(:, 10);
    
    % Vận tốc góc (Wz, Wy, Wx) - Cột 14, 15, 16
    Wz  = data(:, 14);
    Wy  = data(:, 15);
    Wx  = data(:, 16);
    
    % Đạo hàm gia tốc góc 
    % Lọc nhẹ vận tốc góc, sau đó đạo hàm dựa theo đúng thời gian t
    Wx_filt = smoothdata(Wx, 1, 'sgolay', 11);
    Wy_filt = smoothdata(Wy, 1, 'sgolay', 11);
    Wz_filt = smoothdata(Wz, 1, 'sgolay', 11);
    
    Alpha_x = gradient(Wx_filt, t);
    Alpha_y = gradient(Wy_filt, t);
    Alpha_z = gradient(Wz_filt, t);
    
    % Khởi tạo giao diện plot
    [~, name, ext] = fileparts(filename);
    figName = sprintf('Kiểm tra nhanh dữ liệu - %s', [name ext]);
    figure('Name', figName, 'NumberTitle', 'off', 'Position', [150 100 1000 800]);
    
    % Subplot 1: Biểu đồ Delta T để xem thời gian có đều không
    dt = diff(t);
    subplot(4, 1, 1);
    plot(t(1:end-1), dt, 'k.-');
    title(sprintf('Bước thời gian \\Delta t (Lớn nhất: %.4f s, Nhỏ nhất: %.4f s)', max(dt), min(dt)));
    ylabel('\Delta t (s)');
    grid on;
    
    % Subplot 2: Vận tốc góc
    subplot(4, 1, 2);
    plot(t, Wx, 'r', t, Wy, 'g', t, Wz, 'b');
    title('Vận tốc góc (w_x, w_y, w_z)');
    legend('w_x', 'w_y', 'w_z', 'Location', 'best');
    ylabel('rad/s');
    grid on;
    
    % Subplot 3: Gia tốc góc
    subplot(4, 1, 3);
    plot(t, Alpha_x, 'r', t, Alpha_y, 'g', t, Alpha_z, 'b');
    title('Gia tốc góc (\alpha_x, \alpha_y, \alpha_z)');
    legend('\alpha_x', '\alpha_y', '\alpha_z', 'Location', 'best');
    ylabel('rad/s^2');
    grid on;
    
    % Subplot 4: Gia tốc dài quán tính
    subplot(4, 1, 4);
    plot(t, Axi, 'r', t, Ayi, 'g', t, Azi, 'b');
    title('Gia tốc dài quán tính (Axi, Ayi, Azi)');
    legend('Axi', 'Ayi', 'Azi', 'Location', 'best');
    ylabel('m/s^2');
    xlabel('Thời gian t (s)');
    grid on;
end
