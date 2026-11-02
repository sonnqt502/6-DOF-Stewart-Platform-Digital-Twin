% =========================================================================
% TEST_JACOBIAN_MOTOR
%   Kiem tra jacobian_motor voi phi_thuc (phi_motor)
% =========================================================================
clear; clc;

ra = 589.66; rb = 429.566; L1 = 150; L2 = 747;
a1 = 19.45;  da = 38.9;   b1 = 53.32; db = 13.37;
Z_A = 664.4;

A_mat = zeros(3,6); B_mat = zeros(3,6); gamma_ang = zeros(1,6);
for k = 0:2
    av(2*k+1) = -(a1+k*120);      av(2*k+2) = -(a1-da+(k+1)*120);
    bv(2*k+1) = -(b1+k*120);      bv(2*k+2) = -(b1+db+k*120);
end
for i = 1:6
    A_mat(1,i)=ra*cosd(av(i)); A_mat(2,i)=ra*sind(av(i)); A_mat(3,i)=Z_A;
    B_mat(1,i)=rb*cosd(bv(i)); B_mat(2,i)=rb*sind(bv(i)); B_mat(3,i)=0;
    gamma_ang(i) = av(i) + ((-1)^i)*90;
end

pose_dot0  = [10, 5, 8, 2, -3, 1];
pose_ddot0 = [20, -10, 15, 5, -8, 3];

poses = [  0,   0,   0,   0,   0,   0;
          15,  -8,  12,   0,   0,   0;
           0,   0,   0,   5,  -3,   2;
          20,  -5,   8,   3,   4,  -1;
           0,   0,   5,  10,   0,   0];
labels = {'Trung tinh','Tinh tien','Quay','Kep','Tilt Z'};

fprintf('========================================================================================\n');
fprintf('                GOC QUAY DONG CO (PHI_MOTOR) CUA CAC TRUONG HOP KIEM TRA                \n');
fprintf('========================================================================================\n');
fprintf(' %-12s | Pose [x, y, z, roll, pitch, yaw] | Chan 1    Chan 2    Chan 3    Chan 4    Chan 5    Chan 6  (do)\n', 'Truong hop');
fprintf(' %s\n', repmat('-', 1, 105));

for tc = 1:size(poses, 1)
    pt = poses(tc, :);
    [phi_mot, phi_raw, phi_out] = tinh_phi_motor_all(pt, A_mat, B_mat, L1, L2, gamma_ang);
    
    pose_str = sprintf('[%2.0f, %2.0f, %2.0f, %2.0f, %2.0f, %2.0f]', pt(1), pt(2), pt(3), pt(4), pt(5), pt(6));
    fprintf(' %-12s | %-32s | %8.3f  %8.3f  %8.3f  %8.3f  %8.3f  %8.3f\n', ...
        labels{tc}, pose_str, phi_mot(1), phi_mot(2), phi_mot(3), phi_mot(4), phi_mot(5), phi_mot(6));
end
fprintf(' %s\n\n', repmat('-', 1, 105));

fprintf('=======================================================\n');
fprintf(' KIEM TRA CHINH XAC JACOBIAN & VAN TOC / GIA TOC\n');
fprintf('=======================================================\n\n');

%% TEST 1: Pose Jacobian J_xi vs FD
fprintf('[TEST 1] J_xi_analytical vs J_xi_FD\n');
fprintf('  %-12s | max|J_xi-J_FD|   | Ket qua\n','Pose');
fprintf('  %s\n', repmat('-',1,48));
h_t = 1e-4; h_r = 1e-4;
all_pass1 = true;

for tc = 1:size(poses,1)
    pt = poses(tc,:);
    try
        [Jq,~,~] = jacobian_motor(pt, pose_dot0, [], A_mat, B_mat, L1, L2, gamma_ang);

        roll_r = pt(4)*pi/180; pitch_r = pt(5)*pi/180;
        R_pt   = rot_zyx_local(pt(4), pt(5), pt(6));
        E_body = [1, 0, -sin(pitch_r);
                  0, cos(roll_r), sin(roll_r)*cos(pitch_r);
                  0, -sin(roll_r), cos(roll_r)*cos(pitch_r)];

        J_xi_anal = zeros(6,6);
        J_xi_anal(:,1:3) = Jq(:,1:3);
        J_xi_anal(:,4:6) = Jq(:,4:6) * R_pt * E_body * (pi/180);

        J_xi_FD = zeros(6,6);
        for k = 1:6
            h = h_t*(k<=3) + h_r*(k>3);
            pp = pt; pp(k) = pt(k)+h;
            pm = pt; pm(k) = pt(k)-h;
            op = tinh_phi_motor(pp, A_mat, B_mat, L1, L2, gamma_ang);
            om = tinh_phi_motor(pm, A_mat, B_mat, L1, L2, gamma_ang);
            J_xi_FD(:,k) = (op - om)' * (pi/180) / (2*h);
        end

        eJ = max(max(abs(J_xi_anal - J_xi_FD)));
        ok = eJ < 1e-4;
        all_pass1 = all_pass1 && ok;
        fprintf('  %-12s | %14.3e | %s\n', labels{tc}, eJ, ternary(ok,'PASS','FAIL'));
    catch ME
        fprintf('  %-12s | LOI: %s\n', labels{tc}, ME.message);
        all_pass1 = false;
    end
end
fprintf('  Ket qua chung: %s\n\n', ternary(all_pass1,'[PASS]','[FAIL]'));

%% TEST 2: q_dot vs FD
fprintf('[TEST 2] q_dot vs dao ham so theo thoi gian\n');
fprintf('  %-12s | max|qdot_J - qdot_FD| | Ket qua\n','Pose');
fprintf('  %s\n', repmat('-',1,50));
dt_fd = 1e-6;
all_pass2 = true;

for tc = 1:size(poses,1)
    pt = poses(tc,:);
    try
        [~, qd, ~] = jacobian_motor(pt, pose_dot0, [], A_mat, B_mat, L1, L2, gamma_ang);
        pt1 = pt + pose_dot0 * dt_fd;
        o0  = tinh_phi_motor(pt,  A_mat, B_mat, L1, L2, gamma_ang);
        o1  = tinh_phi_motor(pt1, A_mat, B_mat, L1, L2, gamma_ang);
        qd_fd = ((o1 - o0) * (pi/180) / dt_fd)';
        ev = max(abs(qd - qd_fd));
        ok = ev < 1e-4;
        all_pass2 = all_pass2 && ok;
        fprintf('  %-12s | %22.3e | %s\n', labels{tc}, ev, ternary(ok,'PASS','FAIL'));
    catch ME
        fprintf('  %-12s | LOI: %s\n', labels{tc}, ME.message);
        all_pass2 = false;
    end
end
fprintf('  Ket qua chung: %s\n\n', ternary(all_pass2,'[PASS]','[FAIL]'));

%% TEST 3: q_ddot vs FD
fprintf('[TEST 3] q_ddot vs FD thoi gian\n');
pose0 = [0,0,0,0,0,0];
[~, qd_t0, qdd_t0] = jacobian_motor(pose0, pose_dot0, pose_ddot0, ...
                                     A_mat, B_mat, L1, L2, gamma_ang);
dt3 = 1e-5;
pose_next = pose0     + pose_dot0*dt3 + 0.5*pose_ddot0*dt3^2;
vdot_next = pose_dot0 + pose_ddot0*dt3;
[~, qd_next, ~] = jacobian_motor(pose_next, vdot_next, [], A_mat, B_mat, L1, L2, gamma_ang);
qdd_fd = (qd_next - qd_t0) / dt3;

fprintf('  q_ddot Jacobian (rad/s2): '); fprintf('%9.4f ', qdd_t0'); fprintf('\n');
fprintf('  q_ddot FD       (rad/s2): '); fprintf('%9.4f ', qdd_fd'); fprintf('\n');
err3 = max(abs(qdd_t0 - qdd_fd));
fprintf('  Max err = %.3e  %s\n\n', err3, ternary(err3<5e-2,'[PASS]','[FAIL]'));

fprintf('[HOAN THANH]\n');

function s = ternary(c,a,b); if c; s=a; else; s=b; end; end

function phi_motor = tinh_phi_motor(pose, A_mat, B_mat, L1, L2, gamma_ang)
    [phi_motor, ~, ~] = tinh_phi_motor_all(pose, A_mat, B_mat, L1, L2, gamma_ang);
end

function [phi_motor, phi_raw, phi_out] = tinh_phi_motor_all(pose, A_mat, B_mat, L1, L2, gamma_ang)
    R = rot_zyx_local(pose(4), pose(5), pose(6));
    T = pose(1:3)';
    L_vec = T + R * B_mat - A_mat;
    l_sq = sum(L_vec.^2, 1);
    Q = l_sq - L2^2 + L1^2;
    M_val = 2 * L1 * L_vec(3, :);
    N_val = 2 * L1 * (cosd(gamma_ang) .* L_vec(1, :) + sind(gamma_ang) .* L_vec(2, :));
    arg = Q ./ sqrt(M_val.^2 + N_val.^2);

    phi_raw = asind(arg) - atan2d(N_val, M_val);
    phi_out = zeros(1, 6);
    phi_out(1:2:5) = -(90 + phi_raw(1:2:5));
    phi_out(2:2:6) = (90 + phi_raw(2:2:6));
    phi_thuc = (phi_out - [90, -90, 90, -90, 90, -90]);
    phi_thuc(1:2:5) = -phi_thuc(1:2:5);
    phi_motor = phi_thuc;
end

function R = rot_zyx_local(roll_deg, pitch_deg, yaw_deg)
    cr=cosd(roll_deg); sr=sind(roll_deg);
    cp=cosd(pitch_deg); sp=sind(pitch_deg);
    cy=cosd(yaw_deg); sy=sind(yaw_deg);
    R=[cy*cp,cy*sp*sr-sy*cr,cy*sp*cr+sy*sr;
       sy*cp,sy*sp*sr+cy*cr,sy*sp*cr-cy*sr;
       -sp,cp*sr,cp*cr];
end
