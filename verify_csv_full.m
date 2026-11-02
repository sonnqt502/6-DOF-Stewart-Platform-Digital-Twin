%% verify_csv_full.m
% Đọc toàn bộ test.csv và so sánh phi_motor tại mọi điểm.

cd('c:\Users\Admin\Desktop\lab\ckas\simcape\sime4');

ra = 589.66; rb = 429.566; alpha1 = 19.45; beta1 = 53.32; da = 38.9; db = 13.37;
[A_mat, B_mat, gamma_ang] = calc_Geometry(ra, rb, alpha1, beta1, da, db);
L1 = 150; L2 = 747;
Home_Z = -75;

% Đọc CSV
fid = fopen('test.csv', 'r');
rawText = fread(fid, '*char')';
fclose(fid);
lines = strsplit(rawText, newline);
numberPat = '[-+]?\d*\.?\d+(?:[eE][-+]?\d+)?';

data = [];
for i = 1:length(lines)
    line = strtrim(lines{i});
    if isempty(line), continue; end
    nums = regexp(line, numberPat, 'match');
    if isempty(nums), continue; end
    r = str2double(nums);
    r(isnan(r)) = [];
    if length(r) >= 7
        data(end+1, :) = r(1:7);
    end
end

N = size(data, 1);
fprintf('So diem: %d\n', N);

% Kiểm tra 5 điểm đầu và 5 điểm cuối
check_idx = [1:5, N-4:N];
for i = check_idx
    X=data(i,2); Y=data(i,3); Z=data(i,4);
    Yaw=data(i,5); Pitch=data(i,6); Roll=data(i,7);
    cy=cosd(Yaw);sy=sind(Yaw);cp=cosd(Pitch);sp=sind(Pitch);cr=cosd(Roll);sr=sind(Roll);
    R=[cy*cp,cy*sp*sr-sy*cr,cy*sp*cr+sy*sr;
       sy*cp,sy*sp*sr+cy*cr,sy*sp*cr-cy*sr;
       -sp,  cp*sr,         cp*cr];
    pos_plat = [0;0;Home_Z] + R * [X;Y;Z];
    pose = [pos_plat', Roll, Pitch, Yaw];
    phi = donghocnguoc_final1(pose, A_mat, B_mat, L1, L2, gamma_ang);
    fprintf('t=%.2f  phi=[%6.2f %6.2f %6.2f %6.2f %6.2f %6.2f]\n', data(i,1), phi);
end
