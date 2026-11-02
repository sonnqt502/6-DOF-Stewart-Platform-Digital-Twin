% =========================================================
% SCRIPT KIỂM TRA JACOBIAN — dùng phi_raw cho FD
% =========================================================
clear; clc;

% --- Thông số cơ khí (THAY BẰNG GIÁ TRỊ THỰC CỦA CKAS W2) ---
ra = 589.66; rb = 429.566; L1 = 150; L2 = 747;
a1 = 19.45; da = 38.9; b1 = 53.32; db = 13.37;
Z_A = 795.4 - 202.0; % 593.4

A_mat = zeros(3,6); B_mat = zeros(3,6); gamma_ang = zeros(1,6);
alpha = zeros(1,6); beta = zeros(1,6);

for k = 0:2
    alpha(2*k + 1) = -(a1 + k * 120); 
    alpha(2*k + 2) = -(a1 - da + (k+1) * 120);
    beta(2*k + 1)  = -(b1 + k * 120); 
    beta(2*k + 2)  = -(b1 + db + k * 120); 
end
for i = 1:6
    A_mat(1, i) = ra * cosd(alpha(i)); A_mat(2, i) = ra * sind(alpha(i)); A_mat(3, i) = Z_A;
    B_mat(1, i) = rb * cosd(beta(i));  B_mat(2, i) = rb * sind(beta(i));  B_mat(3, i) = 0;
    gamma_ang(i) = alpha(i) + ((-1)^(i)) * 90;
end

% --- Pose kiểm tra ---
pose0 = [0, 0, 0, 0, 0, 0];

[phi_raw0, phi_out0] = donghocnguoc_raw(pose0, A_mat, B_mat, L1, L2, gamma_ang);
if any(isnan(phi_raw0))
    error('Pose không khả thi!');
end
fprintf('phi_raw tại pose0: %.4f %.4f %.4f %.4f %.4f %.4f (deg)\n', phi_raw0);
fprintf('phi_out tại pose0: %.4f %.4f %.4f %.4f %.4f %.4f (deg)\n\n', phi_out0);

% =========================================================
% FINITE DIFFERENCE dùng phi_raw (không có offset servo)
%   J_FD(:,k) = d(phi_raw)/d(q_k)
% =========================================================
h_trans = 1e-4;   % mm
h_rot   = 1e-4;   % deg

J_FD = zeros(6,6);
for k = 1:6
    h = h_trans * (k<=3) + h_rot * (k>3);
    pose_p = pose0; pose_p(k) = pose0(k) + h;
    pose_m = pose0; pose_m(k) = pose0(k) - h;

    [phi_p, ~] = donghocnguoc_raw(pose_p, A_mat, B_mat, L1, L2, gamma_ang);
    [phi_m, ~] = donghocnguoc_raw(pose_m, A_mat, B_mat, L1, L2, gamma_ang);

    J_FD(:,k) = (phi_p - phi_m)' / (2*h);   % deg/mm hoặc deg/deg
end

% =========================================================
% Chuyển J_analytical sang cùng đơn vị J_FD
%   J_anal: rad/mm (cột 1-3), rad/rad (cột 4-6)
%   J_FD:   deg/mm (cột 1-3), deg/deg (cột 4-6)
%   => J_anal_conv = J_anal * (180/pi)   cho cả 6 cột
%      Cột 4-6 thêm *(pi/180) vì FD dùng deg còn J nhận rad
%      => cột 4-6: J_anal*(180/pi)*(pi/180) = J_anal
% =========================================================
[J_anal, ~] = jacobian_RUS(pose0, [1,0,0,0,0,0], A_mat, B_mat, L1, L2, gamma_ang);

J_conv = zeros(6,6);
J_conv(:,1:3) = J_anal(:,1:3) * (180/pi);  % rad/mm → deg/mm
J_conv(:,4:6) = J_anal(:,4:6);             % rad/rad = deg/deg (dimensionless)

fprintf('J_FD:\n');          disp(J_FD);
fprintf('J_analytical:\n'); disp(J_conv);
fprintf('Diff (J_FD - J_anal):\n'); disp(J_FD - J_conv);

err = abs(J_FD - J_conv);
fprintf('Max error mỗi cột:\n');
fprintf('  x:%.2e  y:%.2e  z:%.2e  roll:%.2e  pitch:%.2e  yaw:%.2e\n\n', ...
    max(err(:,1)), max(err(:,2)), max(err(:,3)), ...
    max(err(:,4)), max(err(:,5)), max(err(:,6)));

% =========================================================
% Kiểm tra theta_dot trực tiếp
% =========================================================
test_cases = [10,0,0,0,0,0; 0,10,0,0,0,0; 0,0,10,0,0,0;
               0,0,0,5,0,0;  0,0,0,0,5,0;  0,0,0,0,0,5];
labels = {'vx=10mm/s','vy=10mm/s','vz=10mm/s','roll=5°/s','pitch=5°/s','yaw=5°/s'};

fprintf('%-14s | %-42s | %-42s | MaxErr\n','Case','Analytical(deg/s)','FD(deg/s)');
fprintf('%s\n', repmat('-',1,110));

dt = 1e-6;
for tc = 1:6
    pd = test_cases(tc,:);
    [~, td_anal] = jacobian_RUS(pose0, pd, A_mat, B_mat, L1, L2, gamma_ang);

    pose1 = pose0 + pd*dt;
    [phi1, ~] = donghocnguoc_raw(pose1, A_mat, B_mat, L1, L2, gamma_ang);
    td_fd = (phi1 - phi_raw0)' / dt;   % deg/s, từ phi_raw

    err = max(abs(td_anal - td_fd));
    fprintf('%-14s | [%s] | [%s] | %.2e  %s\n', labels{tc}, ...
        sprintf('%6.2f ',td_anal), sprintf('%6.2f ',td_fd), err, ...
        ternary(err<0.01,'✓','✗'));
end

function s = ternary(c,a,b); if c; s=a; else; s=b; end; end