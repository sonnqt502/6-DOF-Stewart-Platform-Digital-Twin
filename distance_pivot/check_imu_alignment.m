% =========================================================================
% SCRIPT ĐỔI HỆ QUY CHIẾU IMU: World Frame → Body Frame
%
% Bài toán: IMU bị đặt nghiêng so với hệ tọa độ chuẩn.
%           Dữ liệu đo được đang biểu diễn trong World Frame (W).
%           Mục tiêu: chuyển sang Body Frame (B) của IMU.
%
% Nguyên lý:  v_B = R_tilt' * v_W
%             R_tilt = R(yaw0, pitch0, roll0) tính từ tư thế tĩnh ban đầu
%             R_tilt là hằng số suốt toàn bộ 15s đo
%
% Output: file CSV mới với cùng cấu trúc, chỉ thay các cột đã xoay
% =========================================================================
clc; clear; close all;

% =========================================================================
% 1. CẤU HÌNH
% =========================================================================
FILE    = 'IMU2_0_aligned.csv';
FILE_OUT = 'IMU2_0_aligned.csv';   % File output sau khi offset

% Mapping cột — header: <t> ~M[ <x> <y> <z> <yaw> <pitch> <roll> <axi> <ayi> <azi> <axg> <ayg> <azg> <wz> <wy> <wx> ]
cT     = 1;                          % Thời gian
cYaw   = 6;  cPitch = 7;  cRoll = 8; % Góc Euler (°)
cAxi   = 10;  cAyi   = 11; cAzi  = 12;% Gia tốc quán tính - đã trừ trọng lực (m/s²)
cAxg   = 13; cAyg   = 14; cAzg  = 15;% Gia tốc thô - bao gồm trọng lực (m/s²)
cWz    = 16; cWy    = 17; cWx   = 18;% Vận tốc góc (rad/s)

N_STATIC = 1000;   % Số mẫu đầu dùng ước lượng góc gá đặt

% =========================================================================
% 2. ĐỌC DỮ LIỆU
% =========================================================================
fprintf('Đang đọc: %s ...\n', FILE);
raw = readmatrix(FILE);
[N, num_cols] = size(raw);
fprintf('   -> %d mẫu,  %d cột\n', N, num_cols);

t  = raw(:, cT) - raw(1, cT);
dt = mean(diff(t));
fprintf('   -> Thời gian đo: %.2f s,  dt trung bình: %.4f s\n', t(end), dt);

% =========================================================================
% 3. ƯỚC LƯỢNG GÓC GÁ ĐẶT
% =========================================================================
valid_yaw   = raw(~isnan(raw(:,cYaw)),   cYaw);
valid_pitch = raw(~isnan(raw(:,cPitch)), cPitch);
valid_roll  = raw(~isnan(raw(:,cRoll)),  cRoll);

if isempty(valid_yaw) || isempty(valid_pitch) || isempty(valid_roll)
    error('LỖI: Cột Yaw/Pitch/Roll toàn NaN — kiểm tra lại số cột!');
end

n_use  = min(N_STATIC, min([length(valid_yaw), length(valid_pitch), length(valid_roll)]));
yaw0   = deg2rad(mean(valid_yaw(1:n_use)));
pitch0 = deg2rad(mean(valid_pitch(1:n_use)));
roll0  = deg2rad(mean(valid_roll(1:n_use)));

fprintf('\n--- GÓC GÁ ĐẶT (Mounting Offset) ---\n');
fprintf('   Yaw0   = %+.4f deg\n', rad2deg(yaw0));
fprintf('   Pitch0 = %+.4f deg\n', rad2deg(pitch0));
fprintf('   Roll0  = %+.4f deg\n', rad2deg(roll0));

% =========================================================================
% 4. MA TRẬN XOAY R_tilt (ZYX convention)
%    R_tilt  : Body → World
%    R_tilt' : World → Body   =>  v_B = R_tilt' * v_W
%    Vectorized: V_B = V_W * R_tilt   (V là [N x 3])
% =========================================================================
cy = cos(yaw0);   sy = sin(yaw0);
cp = cos(pitch0); sp = sin(pitch0);
cr = cos(roll0);  sr = sin(roll0);

R_tilt = [cy*cp,  cy*sp*sr - sy*cr,  cy*sp*cr + sy*sr;
          sy*cp,  sy*sp*sr + cy*cr,  sy*sp*cr - cy*sr;
          -sp,    cp*sr,             cp*cr            ];

fprintf('\n--- MA TRẬN XOAY R_tilt ---\n');
disp(R_tilt);
fprintf('det(R_tilt) = %.6f  (phai = 1.0)\n', det(R_tilt));

% =========================================================================
% 5. CHUYỂN ĐỔI HỆ QUY CHIẾU
% =========================================================================
fprintf('\nĐang chuyển đổi %d mẫu sang Body Frame...\n', N);

% helper: V [Nx3] world -> body
xform = @(V) V * R_tilt;

% Trích dữ liệu gốc (World Frame)
Axi_W  = raw(:, [cAxi, cAyi, cAzi]);
Axg_W  = raw(:, [cAxg, cAyg, cAzg]);
W_W    = raw(:, [cWx,  cWy,  cWz ]);   % chú ý: cWx trước dù trong file là wz,wy,wx
angle_W = raw(:, [cYaw, cPitch, cRoll]);

% Chuyển sang Body Frame
Axi_B  = xform(Axi_W);
Axg_B  = xform(Axg_W);
W_B    = xform(W_W);
angle_B = angle_W - [rad2deg(yaw0), rad2deg(pitch0), rad2deg(roll0)];

% Gia tốc góc (dùng ω đã xoay)
alpha_W = [gradient(W_W(:,1),dt), gradient(W_W(:,2),dt), gradient(W_W(:,3),dt)];
alpha_B = [gradient(W_B(:,1),dt), gradient(W_B(:,2),dt), gradient(W_B(:,3),dt)];

fprintf('   -> Xong.\n');

% =========================================================================
% 6. TẠO FILE DỮ LIỆU MỚI SAU KHI OFFSET
%
%    Giữ nguyên toàn bộ cấu trúc file gốc,
%    chỉ GHI ĐÈ các cột đã được xoay sang Body Frame
% =========================================================================
fprintf('\nĐang tạo file output: %s ...\n', FILE_OUT);

out = raw;   % Bắt đầu từ bản sao nguyên vẹn của file gốc

% Ghi đè các cột đã xoay
out(:, cYaw)   = angle_B(:, 1);
out(:, cPitch) = angle_B(:, 2);
out(:, cRoll)  = angle_B(:, 3);

out(:, cAxi)   = Axi_B(:, 1);
out(:, cAyi)   = Axi_B(:, 2);
out(:, cAzi)   = Axi_B(:, 3);

out(:, cAxg)   = Axg_B(:, 1);
out(:, cAyg)   = Axg_B(:, 2);
out(:, cAzg)   = Axg_B(:, 3);

% Chú ý: file gốc lưu thứ tự wz, wy, wx — ghi lại đúng thứ tự đó
out(:, cWz)    = W_B(:, 3);   % wz
out(:, cWy)    = W_B(:, 2);   % wy
out(:, cWx)    = W_B(:, 1);   % wx

% Ghi ra file CSV (không có header — giữ đúng format gốc)
writematrix(out, FILE_OUT);
fprintf('   -> Da luu: %s  (%d dong x %d cot)\n', FILE_OUT, size(out,1), size(out,2));

% Kiểm tra nhanh: đọc lại và so sánh cột đầu
check = readmatrix(FILE_OUT);
fprintf('   -> Kiem tra: so cot file moi = %d  (goc = %d)\n', size(check,2), num_cols);

% =========================================================================
% 7. VẼ BIỂU ĐỒ SO SÁNH (4 nhóm)
% =========================================================================
clr_gray = [0.75 0.75 0.75];
clr_blue = [0.12 0.47 0.71];
clr_red  = [0.84 0.15 0.16];
clr_oran = [0.89 0.47 0.13];
clr_gree = [0.17 0.63 0.17];

%% --- NHOM 1: GOC EULER ---
figure('Name', 'Nhom1 Goc Euler', 'NumberTitle', 'off', 'Position', [75 570 1200 560]);
sgtitle('NHOM 1 - Goc Euler (deg)', 'FontSize', 13, 'FontWeight', 'bold');
ylabels1 = {'Yaw (deg)', 'Pitch (deg)', 'Roll (deg)'};
ax1 = gobjects(3,1);
for k = 1:3
    ax1(k) = subplot(3,1,k);
    plot(t, angle_W(:,k), 'Color', clr_gray, 'LineWidth', 1.4, 'DisplayName', 'World Frame (goc)'); hold on;
    plot(t, angle_B(:,k), 'Color', clr_blue, 'LineWidth', 1.8, 'DisplayName', 'Body Frame (da offset)');
    ylabel(ylabels1{k}); grid on; box off;
    if k == 1; legend('Location','best','FontSize',8); end
    if k == 3; xlabel('Thoi gian (s)'); end
end
linkaxes(ax1, 'x');

%% --- NHOM 2: VAN TOC GOC ---
figure('Name', 'Nhom2 Van toc goc', 'NumberTitle', 'off', 'Position', [100 510 1200 560]);
sgtitle('NHOM 2 - Van toc goc omega (rad/s)', 'FontSize', 13, 'FontWeight', 'bold');
ylabels2 = {'wx (rad/s)', 'wy (rad/s)', 'wz (rad/s)'};
ax2 = gobjects(3,1);
for k = 1:3
    ax2(k) = subplot(3,1,k);
    plot(t, W_W(:,k), 'Color', clr_gray, 'LineWidth', 1.4, 'DisplayName', 'World Frame (goc)'); hold on;
    plot(t, W_B(:,k), 'Color', clr_red,  'LineWidth', 1.8, 'DisplayName', 'Body Frame (da xoay)');
    ylabel(ylabels2{k}); grid on; box off;
    if k == 1; legend('Location','best','FontSize',8); end
    if k == 3; xlabel('Thoi gian (s)'); end
end
linkaxes(ax2, 'x');

%% --- NHOM 3: GIA TOC GOC ---
figure('Name', 'Nhom3 Gia toc goc', 'NumberTitle', 'off', 'Position', [125 450 1200 560]);
sgtitle('NHOM 3 - Gia toc goc alpha = domega/dt (rad/s2)', 'FontSize', 13, 'FontWeight', 'bold');
ylabels3 = {'ax (rad/s2)', 'ay (rad/s2)', 'az (rad/s2)'};
ax3 = gobjects(3,1);
for k = 1:3
    ax3(k) = subplot(3,1,k);
    plot(t, alpha_W(:,k), 'Color', clr_gray, 'LineWidth', 1.4, 'DisplayName', 'World Frame (goc)'); hold on;
    plot(t, alpha_B(:,k), 'Color', clr_oran, 'LineWidth', 1.8, 'DisplayName', 'Body Frame (da xoay)');
    ylabel(ylabels3{k}); grid on; box off;
    if k == 1; legend('Location','best','FontSize',8); end
    if k == 3; xlabel('Thoi gian (s)'); end
end
linkaxes(ax3, 'x');

%% --- NHOM 4: GIA TOC QUAN TINH ---
figure('Name', 'Nhom4 Gia toc quan tinh', 'NumberTitle', 'off', 'Position', [150 390 1200 560]);
sgtitle('NHOM 4 - Gia toc quan tinh axi (m/s2)  [da tru g]', 'FontSize', 13, 'FontWeight', 'bold');
ylabels4 = {'axi (m/s2)', 'ayi (m/s2)', 'azi (m/s2)'};
ax4 = gobjects(3,1);
for k = 1:3
    ax4(k) = subplot(3,1,k);
    plot(t, Axi_W(:,k), 'Color', clr_gray, 'LineWidth', 1.4, 'DisplayName', 'World Frame (goc)'); hold on;
    plot(t, Axi_B(:,k), 'Color', clr_gree, 'LineWidth', 1.8, 'DisplayName', 'Body Frame (da xoay)');
    ylabel(ylabels4{k}); grid on; box off;
    if k == 1; legend('Location','best','FontSize',8); end
    if k == 3; xlabel('Thoi gian (s)'); end
end
linkaxes(ax4, 'x');

% =========================================================================
% 8. THONG KE KIEM TRA
% =========================================================================
fprintf('\n========== KIEM TRA SAU ALIGNMENT ==========\n');
fprintf('Gia toc Z trung binh - Body Frame:\n');
fprintf('   axg_z = %.4f m/s2  (ky vong ~9.81 neu dung yen)\n', mean(Axg_B(:,3)));
fprintf('Van toc goc trung binh - Body Frame:\n');
fprintf('   wx = %.4f   wy = %.4f   wz = %.4f  (ky vong ~0)\n', ...
        mean(W_B(:,1)), mean(W_B(:,2)), mean(W_B(:,3)));
fprintf('=============================================\n');
fprintf('\n=> File da luu: %s\n', FILE_OUT);
fprintf('=> Da ve xong 4 bieu do!\n');