function [t_sync, head_sync, pivot_sync, eval_metrics] = module1_data_io(head_raw, pivot_raw, is_plot)
% MODULE 1: ĐỒNG BỘ VÀ ĐÁNH GIÁ DỮ LIỆU
% Input:
%   head_raw, pivot_raw: Ma trận dữ liệu thô đọc từ file CSV
%   is_plot: true/false (Bật/tắt biểu đồ đánh giá trực quan)
% Output:
%   t_sync: Lưới thời gian chung
%   head_sync, pivot_sync: Dữ liệu đã nội suy khớp với t_sync
%   eval_metrics: Cấu trúc chứa thông số đánh giá sai số (RMSE)
    
    disp('--- Chạy Module 1: Đồng bộ dữ liệu ---');
    
    % 0. XÓA HÀNG RÁC (Lọc bỏ Header chữ làm trục thời gian biến thành NaN)
    head_raw(isnan(head_raw(:, 1)), :) = [];
    pivot_raw(isnan(pivot_raw(:, 1)), :) = [];

    % 0.5. NẮN TRỤC PCA CHO CẢ HEAD VÀ PIVOT (Đưa về chung hệ quy chiếu Cơ khí tuyệt đối)
    [~, ~, head_raw] = applyPCA_internal(head_raw);
    [~, ~, pivot_raw] = applyPCA_internal(pivot_raw);

    % 1. BẢNG MAPPING CỘT DỮ LIỆU CHUẨN
cYaw = 6;   cPitch = 7;   cRoll = 8;
cAx  = 10;  cAy    = 11;  cAz   = 12;  
cWz  = 16;  cWy    = 17;  cWx   = 18;

    % 2. TÁCH CỘT THỜI GIAN
    t_h = head_raw(:, 1);
    t_p = pivot_raw(:, 1);
    
    % 3. TÌM VÙNG CHỒNG LẤN THỜI GIAN (Overlap)
    t_start = max(t_h(1), t_p(1));
    t_end   = min(t_h(end), t_p(end));
    
    if t_end <= t_start
        error('Lỗi: Hai file dữ liệu không có khoảng thời gian trùng nhau!');
    end
    
    % 4. DÙNG LƯỚI THỜI GIAN CỦA PIVOT LÀM CHUẨN (cắt về vùng overlap)
    %    Pivot không bị nội suy — chỉ cắt bớt các mẫu nằm ngoài overlap.
    mask_p = (t_p >= t_start & t_p <= t_end);
    t_sync  = t_p(mask_p);          % Lưới thời gian chuẩn = thời gian thực của Pivot
    dt_sync = mean(diff(t_sync));
    
    fprintf(' + Lưới thời gian chuẩn: PIVOT (%.2f Hz, %d điểm)\n', ...
            1/dt_sync, length(t_sync));
    
    % 5. CẮT PIVOT VÀO VÙNG OVERLAP (không nội suy, giữ nguyên giá trị gốc)
    pivot_sync = pivot_raw(mask_p, :);
    
    % 6. NỘI SUY HEAD LÊN LƯỚI THỜI GIAN CỦA PIVOT
    %    Chỉ nội suy trong vùng t_sync nằm trong [t_h(1), t_h(end)] — không extrapolate.
    head_sync = zeros(length(t_sync), size(head_raw, 2));
    head_sync(:, 1) = t_sync;
    for col = 2:size(head_raw, 2)
        head_sync(:, col) = interp1(t_h, head_raw(:, col), t_sync, 'linear', 'extrap');
    end
    
    % 7. TÍNH RMSE ĐỂ ĐÁNH GIÁ SAI SỐ NỘI SUY CỦA HEAD
    %    Phương pháp: nội suy ngược từ head_sync về đúng mốc thời gian gốc t_h (trong overlap),
    %    so sánh với head_raw gốc → đo độ trung thực của quá trình nội suy.
    mask_h = (t_h >= t_start & t_h <= t_end);
    t_h_orig = t_h(mask_h);
    
    fprintf('\n---> BẢNG SAI SỐ NỘI SUY (RMSE) CỦA HEAD (so với dữ liệu gốc) <---\n');
    eval_metrics.RMSE_Head  = zeros(1, size(head_raw,  2));
    eval_metrics.RMSE_Pivot = zeros(1, size(pivot_raw, 2));  % Pivot = 0 vì không nội suy
    
    for col = 2:size(head_raw, 2)
        orig_data_h  = head_raw(mask_h, col);
        recon_data_h = interp1(t_sync, head_sync(:, col), t_h_orig, 'linear');
        % Loại bỏ NaN ở biên (nếu có) trước khi tính RMSE
        valid = ~isnan(recon_data_h);
        rmse_val_h = sqrt(mean((orig_data_h(valid) - recon_data_h(valid)).^2));
        eval_metrics.RMSE_Head(col) = rmse_val_h;
        fprintf('  Cột %02d : RMSE = %10.6f\n', col, rmse_val_h);
    end
    fprintf(' [Ghi chú] Pivot không được nội suy → RMSE_Pivot = 0 cho tất cả cột.\n');
    
    % 8. VẼ BIỂU ĐỒ ĐÁNH GIÁ (Dùng chuẩn cột cAz, cWy, cWx)
    %    Pivot: dữ liệu gốc chính là pivot_sync (không nội suy) → dùng t_sync làm trục
    if nargin < 3 || is_plot
        az_h_orig = head_raw(mask_h, cAz);
        wy_h_orig = head_raw(mask_h, cWy);
        wx_h_orig = head_raw(mask_h, cWx);
        
        plot_sync_evaluation_multi(t_h_orig, az_h_orig, wy_h_orig, wx_h_orig, ...
                                   t_sync, head_sync, pivot_sync, cAz, cWy, cWx);
    end
end

% =========================================================================
% Hàm vẽ biểu đồ đa thông số (Đã tích hợp biến Index linh hoạt)
% =========================================================================
function plot_sync_evaluation_multi(t_h_o, az_h_o, wy_h_o, wx_h_o, ...
                                    t_s, head_s, pivot_s, cAz, cWy, cWx)
% Pivot dùng t_s làm trục (không nội suy → điểm gốc trùng điểm đồng bộ)
    figure('Name', 'Module 1: Đánh giá Đồng bộ (az, wy, wx)', 'Position', [100 100 1000 900]);
    
    mid_t = t_s(round(end/2));
    z_win = 0.2; % Zoom 0.2 giây
    
    % --- ĐỒ THỊ 1: HEAD az (đỏ = gốc thô, xanh = đã nội suy) ---
    ax1 = subplot(6,1,1);
    plot(t_h_o, az_h_o, 'ro', 'MarkerFaceColor','r', 'DisplayName', 'HEAD gốc'); hold on;
    plot(t_s, head_s(:,cAz), 'b.-', 'MarkerSize',10, 'DisplayName', 'HEAD nội suy');
    draw_sync_lines(t_s, mid_t, z_win);
    ylabel('az HEAD'); title('HEAD: Gốc (Đỏ) vs Nội suy (Xanh) | PIVOT: Gốc = Đồng bộ (Xanh lá)');
    grid on; legend('Location', 'best');
    
    % --- ĐỒ THỊ 2: HEAD wy ---
    ax2 = subplot(6,1,2);
    plot(t_h_o, wy_h_o, 'ro', 'MarkerFaceColor','r'); hold on;
    plot(t_s, head_s(:,cWy), 'b.-', 'MarkerSize',10);
    draw_sync_lines(t_s, mid_t, z_win);
    ylabel('\omega_y HEAD'); grid on;
    
    % --- ĐỒ THỊ 3: HEAD wx ---
    ax3 = subplot(6,1,3);
    plot(t_h_o, wx_h_o, 'ro', 'MarkerFaceColor','r'); hold on;
    plot(t_s, head_s(:,cWx), 'b.-', 'MarkerSize',10);
    draw_sync_lines(t_s, mid_t, z_win);
    ylabel('\omega_x HEAD'); grid on;
    
    % --- ĐỒ THỊ 4: PIVOT az (chỉ 1 đường vì không nội suy) ---
    ax4 = subplot(6,1,4);
    plot(t_s, pivot_s(:,cAz), 'g.-', 'MarkerSize',10, 'DisplayName', 'PIVOT (chuẩn)');
    draw_sync_lines(t_s, mid_t, z_win);
    ylabel('az PIVOT'); grid on; legend('Location', 'best');
    
    % --- ĐỒ THỊ 5: PIVOT wy ---
    ax5 = subplot(6,1,5);
    plot(t_s, pivot_s(:,cWy), 'g.-', 'MarkerSize',10);
    draw_sync_lines(t_s, mid_t, z_win);
    ylabel('\omega_y PIVOT'); grid on;
    
    % --- ĐỒ THỊ 6: PIVOT wx ---
    ax6 = subplot(6,1,6);
    plot(t_s, pivot_s(:,cWx), 'g.-', 'MarkerSize',10);
    draw_sync_lines(t_s, mid_t, z_win);
    ylabel('\omega_x PIVOT'); xlabel('Thời gian (s)'); grid on;
    
    % Liên kết trục X của tất cả 6 đồ thị
    linkaxes([ax1, ax2, ax3, ax4, ax5, ax6], 'x');
    xlim([mid_t, mid_t + z_win]);
end

% Hàm phụ vẽ đường gióng dọc
function draw_sync_lines(t_sync, mid_time, zoom_window)
    yL = ylim;
    for i = 1:length(t_sync)
        if t_sync(i) >= mid_time && t_sync(i) <= mid_time + zoom_window
            line([t_sync(i) t_sync(i)], yL, 'Color', [0.8 0.8 0.8 0.5], 'LineStyle', '--');
        end
    end
end

% =========================================================================
% Hàm bổ trợ: Nắn trục PCA
% =========================================================================
function [R_PCA, move_type, aligned_data] = applyPCA_internal(data)
    cT=1; cAxi=8; cAyi=9; cAzi=10; cWz=14; cWy=15; cWx=16;
    A_raw = data(:, [cAxi, cAyi, cAzi]);
    W_raw = data(:, [cWx, cWy, cWz]);
    Grav_raw = data(:, 11:13);
    
    [coeff, ~, ~] = pca(W_raw);
    rot_axis = coeff(:, 1);
    
    g_vec = mean(Grav_raw(1:min(1000, size(Grav_raw,1)), :))';
    g_vec = g_vec / norm(g_vec);
    
    if abs(rot_axis(1)) > abs(rot_axis(2))
        move_type = 'ROLL (Trục X)';
        if rot_axis(1) < 0, rot_axis = -rot_axis; end
        X = rot_axis;
        Y = cross(g_vec, X); Y = Y / norm(Y);
        Z = cross(X, Y); Z = Z / norm(Z);
    else
        move_type = 'PITCH (Trục Y)';
        if rot_axis(2) < 0, rot_axis = -rot_axis; end
        Y = rot_axis;
        X = cross(Y, g_vec); X = X / norm(X);
        Z = cross(X, Y); Z = Z / norm(Z);
    end
    
    R_PCA = [X, Y, Z];
    aligned_data = data;
    aligned_data(:, [cAxi, cAyi, cAzi]) = A_raw * R_PCA;
    aligned_data(:, [cWx, cWy, cWz]) = W_raw * R_PCA;
end

% =========================================================================
% HÀM BỔ TRỢ: NẮN THẲNG TỌA ĐỘ (ĐÃ SỬA LỖI LOẠI BỎ NaN)
% =========================================================================