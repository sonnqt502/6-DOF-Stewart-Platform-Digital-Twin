%% verify_ik_match.m
% So sánh góc động cơ tại dòng 1 của test.csv giữa donghocnguoc_final1.m
% và local_check_safety của Dashboard_Stewart5 (đã tái hiện inline).

cd('c:\Users\Admin\Desktop\lab\ckas\simcape\sime4');

% Tham số hình học — khớp với Dashboard_Stewart5.m mặc định
ra = 589.66; rb = 429.566; alpha1 = 19.45; beta1 = 53.32; da = 38.9; db = 13.37;
[A_mat, B_mat, gamma_ang] = calc_Geometry(ra, rb, alpha1, beta1, da, db);
L1 = 150; L2 = 747;
Home_Z = -75;  % mặc định Dashboard_Stewart5

% Đọc dòng đầu tiên của test.csv
fid = fopen('test.csv', 'r');
rawText = fread(fid, '*char')';
fclose(fid);
lines = strsplit(rawText, newline);
numberPat = '[-+]?\d*\.?\d+(?:[eE][-+]?\d+)?';

row1 = [];
for i = 1:length(lines)
    line = strtrim(lines{i});
    if isempty(line), continue; end
    nums = regexp(line, numberPat, 'match');
    if isempty(nums), continue; end
    r = str2double(nums);
    r(isnan(r)) = [];
    if length(r) >= 7
        row1 = r;
        break;
    end
end

fprintf('Hang dau CSV: t=%.4f  X=%.4f Y=%.4f Z=%.4f Yaw=%.4f Pitch=%.4f Roll=%.4f\n', ...
    row1(1), row1(2), row1(3), row1(4), row1(5), row1(6), row1(7));

X = row1(2); Y = row1(3); Z = row1(4);
Yaw = row1(5); Pitch = row1(6); Roll = row1(7);

% Ma trận quay theo đúng thứ tự Dashboard_Stewart5 (ZYX: yaw, pitch, roll)
cy=cosd(Yaw);sy=sind(Yaw);cp=cosd(Pitch);sp=sind(Pitch);cr=cosd(Roll);sr=sind(Roll);
R=[cy*cp, cy*sp*sr-sy*cr, cy*sp*cr+sy*sr;
   sy*cp, sy*sp*sr+cy*cr, sy*sp*cr-cy*sr;
   -sp,   cp*sr,          cp*cr];

% Biến đổi tọa độ bàn máy theo chuẩn Dashboard_Stewart5 ("Bàn máy (Platform)")
P_0 = [0; 0; Home_Z];
P_file = [X; Y; Z];
pos_plat = P_0 + R * P_file;

fprintf('pos_plat = [%.4f, %.4f, %.4f] mm\n', pos_plat(1), pos_plat(2), pos_plat(3));

pose = [pos_plat(1), pos_plat(2), pos_plat(3), Roll, Pitch, Yaw];

% Tính góc bằng donghocnguoc_final1
phi_final1 = donghocnguoc_final1(pose, A_mat, B_mat, L1, L2, gamma_ang);
fprintf('\nphi_thuc (donghocnguoc_final1):\n');
fprintf('  M1=%.4f  M2=%.4f  M3=%.4f  M4=%.4f  M5=%.4f  M6=%.4f deg\n', phi_final1);

% Tính góc inline theo local_check_safety của Dashboard_Stewart5
T = pos_plat;
L_vec = T + R * B_mat - A_mat;
l_sq  = sum(L_vec.^2, 1);
Q_val = l_sq - L2^2 + L1^2;
M_val = 2 * L1 * L_vec(3, :);
N_val = 2 * L1 * (cosd(gamma_ang) .* L_vec(1,:) + sind(gamma_ang) .* L_vec(2,:));
arg   = Q_val ./ sqrt(M_val.^2 + N_val.^2);
phi_raw = asind(arg) - atan2d(N_val, M_val);
phi_out = zeros(1,6);
phi_out(1:2:5) = -(90 + phi_raw(1:2:5));
phi_out(2:2:6) =  (90 + phi_raw(2:2:6));
phi_thuc = phi_out - [90, -90, 90, -90, 90, -90];
phi_thuc(1:2:5) = -phi_thuc(1:2:5);

fprintf('\nphi_thuc (inline Dashboard_Stewart5 local_check_safety):\n');
fprintf('  M1=%.4f  M2=%.4f  M3=%.4f  M4=%.4f  M5=%.4f  M6=%.4f deg\n', phi_thuc);

fprintf('\nSai so tuyet doi (final1 - dashboard): [%.6f %.6f %.6f %.6f %.6f %.6f]\n', ...
    phi_final1 - phi_thuc);
