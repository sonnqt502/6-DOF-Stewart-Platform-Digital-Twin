% test_math_engine_import.m
% Kịch bản nạp file CSV lý thuyết trực tiếp vào khối Math Engine
clear; clc; close all;

disp('==================================================');
disp('   KIỂM TRA MATH ENGINE TỪ FILE CSV LÝ THUYẾT');
disp('==================================================');

% 1. Đọc file Pivot và Head
[pFile, pPath] = uigetfile({'*.csv;*.txt', 'Data Files'}, 'Chọn file CSV/TXT của PIVOT');
if isequal(pFile, 0), disp('Đã hủy chọn file Pivot.'); return; end
pivot_data = parse_simscape_csv(fullfile(pPath, pFile));

[hFile, hPath] = uigetfile({'*.csv;*.txt', 'Data Files'}, 'Chọn file CSV/TXT của HEAD');
if isequal(hFile, 0), disp('Đã hủy chọn file Head.'); return; end
head_data = parse_simscape_csv(fullfile(hPath, hFile));

% 2. Lấy các cột (theo đúng định dạng motion_calibration2.m)
% Nếu dữ liệu sau khi lọc có đủ 16 cột số, ta lấy: 1=Time, 8,9,10=a, 14,15,16=w
% Cột: 1=Time, 8=ax, 9=ay, 10=az, 14=wz, 15=wy, 16=wx
t = head_data(:, 1);
N = length(t);

disp(['Số lượng mẫu dữ liệu (N) = ', num2str(N)]);

% Lấy Data của Head
w_h  = head_data(:, [16, 15, 14]); % [wx, wy, wz]
a_h  = head_data(:, [8, 9, 10]);   % [ax, ay, az]

% Lấy Data của Pivot (Giả sử số lượng mẫu khớp nhau hoàn toàn)
a_p  = pivot_data(:, [8, 9, 10]);  % [ax, ay, az]

disp('--- DEBUG DỮ LIỆU ĐỌC VÀO ---');
disp(['Kích thước ma trận Head: ', num2str(size(head_data, 1)), ' hàng, ', num2str(size(head_data, 2)), ' cột']);
disp('5 giá trị đầu tiên của cột Thời gian (Cột 1):');
disp(head_data(1:min(5, N), 1)');
disp('5 giá trị đầu tiên của cột Vận tốc góc w_x (Cột 16):');
if size(head_data, 2) >= 16
    disp(head_data(1:min(5, N), 16)');
else
    disp('Không có Cột 16!');
end
disp('-----------------------------');

% Kiểm tra lỗi NaN trong file CSV
if any(isnan(t)) || any(isnan(w_h(:))) || any(isnan(a_h(:))) || any(isnan(a_p(:)))
    disp('CẢNH BÁO: Dữ liệu CSV chứa giá trị NaN (Not a Number)! Có thể do chứa chữ, dòng trống hoặc dấu phẩy thập phân sai.');
    % Xóa bỏ các hàng chứa NaN
    valid_mask = ~isnan(t) & ~any(isnan(w_h),2) & ~any(isnan(a_h),2) & ~any(isnan(a_p),2);
    t = t(valid_mask);
    w_h = w_h(valid_mask, :);
    a_h = a_h(valid_mask, :);
    a_p = a_p(valid_mask, :);
    N = length(t);
    disp(['Đã lọc bỏ NaN. Số lượng mẫu còn lại: ', num2str(N)]);
end

% 3. Tính Gia tốc góc (Alpha) bằng đạo hàm vận tốc góc (giống Bước 2)
dt = mean(diff(t));
disp(['Bước thời gian trung bình (dt) = ', num2str(dt), ' s']);
if dt == 0 || isnan(dt)
    disp('LỖI: dt = 0 hoặc NaN. Cột thời gian (Cột 1) không hợp lệ!');
    return;
end

alpha_h = zeros(N, 3);
alpha_h(:, 1) = gradient(w_h(:, 1)) / dt;
alpha_h(:, 2) = gradient(w_h(:, 2)) / dt;
alpha_h(:, 3) = gradient(w_h(:, 3)) / dt;

% Lựa chọn trục quay để giải
mode_str = questdlg('Trục quay của dữ liệu lý thuyết là trục nào?', 'Chọn trục', 'Pitch (Trục Y)', 'Roll (Trục X)', 'Pitch (Trục Y)');
if strcmp(mode_str, 'Pitch (Trục Y)')
    test_mode = 'Pitch';
else
    test_mode = 'Roll';
end

%% 4. GIẢI BẰNG KHỐI TOÁN HỌC MATH ENGINE (Y HỆT BƯỚC 4 CỦA PHẦN MỀM)
M_stack = zeros(2*N, 2);
B_stack = zeros(2*N, 1);

for k = 1:N
    w = w_h(k, :)';
    al = alpha_h(k, :)';
    
    % Tín hiệu đo đạc: da = a_head - a_pivot
    da = a_h(k, :)' - a_p(k, :)';
    
    % Ma trận Skew-Symmetric
    Om = [0 -w(3) w(2); w(3) 0 -w(1); -w(2) w(1) 0];
    Al = [0 -al(3) al(2); al(3) 0 -al(1); -al(2) al(1) 0];
    
    % M = [Alpha]x + [Omega]x^2
    M_k = Al + Om^2;
    
    if strcmp(test_mode, 'Pitch')
        % Pitch: Giữ rx, rz -> Lấy hàng 1, 3
        M_reduced = M_k([1, 3], [1, 3]);
        B_reduced = [da(1); da(3)];
    else
        % Roll: Giữ ry, rz -> Lấy hàng 2, 3
        M_reduced = M_k([2, 3], [2, 3]);
        B_reduced = [da(2); da(3)];
    end
    
    idx = (2*k - 1) : 2*k;
    M_stack(idx, :) = M_reduced;
    B_stack(idx)    = B_reduced;
end

% --- TẠM TẮT BỘ LỌC ĐỂ KIỂM CHỨNG THEO YÊU CẦU ---
% Loại bỏ các giá trị dị thường / nhiễu nội suy ban đầu nếu có
% Cắt bỏ 5% dữ liệu đầu và cuối để tránh nhiễu do vi phân (gradient)
% valid_idx = round(0.05*N) : round(0.95*N);
% valid_rows = [];
% for v = valid_idx
%     valid_rows = [valid_rows, 2*v-1, 2*v];
% end
% M_stack = M_stack(valid_rows, :);
% B_stack = B_stack(valid_rows);
% ------------------------------------------------

% Giải phương trình
if rank(M_stack) < 2
    disp('LỖI: Dữ liệu bị suy biến, không đủ thông tin để giải.');
    return;
end

r_sol_m = M_stack \ B_stack;
r_sol_mm = r_sol_m * 1000;

%% 5. BÁO CÁO KẾT QUẢ
disp('--------------------------------------------------');
disp(['MATH ENGINE SOLVER OUTPUT (Chế độ: ', test_mode, '):']);
if strcmp(test_mode, 'Pitch')
    disp(['[TÍNH ĐƯỢC] rx = ', num2str(r_sol_mm(1), '%.2f'), ' mm']);
    disp(['[TÍNH ĐƯỢC] rz = ', num2str(r_sol_mm(2), '%.2f'), ' mm']);
else
    disp(['[TÍNH ĐƯỢC] ry = ', num2str(r_sol_mm(1), '%.2f'), ' mm']);
    disp(['[TÍNH ĐƯỢC] rz = ', num2str(r_sol_mm(2), '%.2f'), ' mm']);
end

acc_calc = M_stack * r_sol_m;
RMSE = sqrt(mean((B_stack - acc_calc).^2));
disp(['RMSE tổng hợp: ', num2str(RMSE, '%.4f')]);
disp('==================================================');

% Hàm đọc file hỗ trợ bóc tách dấu ngoặc dị thường
function data = parse_simscape_csv(filepath)
    lines = readlines(filepath);
    % Xóa bỏ các ký tự rác từ command window / Simscape
    lines = replace(lines, {'~M[', '[', ']'}, ' ');
    % Ghép lại và chuyển thành số
    data_str = strjoin(lines, newline);
    data = str2num(data_str); %#ok<ST2NM>
end
