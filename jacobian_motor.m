function [J_q, q_dot, q_ddot] = jacobian_motor(pose, pose_dot, pose_ddot, A_mat, B_mat, L1, L2, gamma_ang)
% JACOBIAN_MOTOR  Ma tran Jacobian goc dong co cho 6-RUS CKAS.
%
% Quy tac chuyen doi goc:
%   phi_raw = asind(arg) - atan2d(N_val, M_val);
%   phi_out(1:2:5) = -(90 + phi_raw(1:2:5));
%   phi_out(2:2:6) = (90 + phi_raw(2:2:6));
%   phi_thuc = (phi_out - [90, -90, 90, -90, 90, -90]);
%   phi_thuc(1:2:5) = -phi_thuc(1:2:5);
%
% => Rut gon toan hoc: phi_thuc(i) = 180 + phi_raw(i) (voi ca 6 chan)
% => Dao ham: d(phi_thuc)/dt = d(phi_raw)/dt (he so +1 cho tat ca cac chan)
%
% -----------------------------------------------------------------------
% INPUTS
%   pose      : [x, y, z, roll, pitch, yaw]              mm va do (ZYX Euler)
%   pose_dot  : [vx, vy, vz, roll_d, pitch_d, yaw_d]    mm/s va do/s
%   pose_ddot : [ax, ay, az, roll_dd, pitch_dd, yaw_dd]  mm/s2 va do/s2
%   A_mat     : 3x6 toa do khop R tai de (mm)
%   B_mat     : 3x6 toa do khop S tai platform, trong frame ban may (mm)
%   L1        : chieu dai servo arm (mm)
%   L2        : chieu dai thanh noi rod (mm)
%   gamma_ang : 1x6 goc ga motor (do)
%
% OUTPUTS
%   J_q    : 6x6 Jacobian cua phi_motor theo [v_p [mm/s]; w_world [rad/s]]
%   q_dot  : 6x1 van toc goc dong co [rad/s]
%   q_ddot : 6x1 gia toc goc dong co [rad/s2]
% -----------------------------------------------------------------------

    if nargin < 3 || isempty(pose_ddot)
        pose_ddot  = [];
        need_accel = false;
    else
        need_accel = true;
    end

    roll  = pose(4);  pitch = pose(5);  yaw = pose(6);
    T     = pose(1:3)';
    R     = rot_zyx(roll, pitch, yaw);

    % Chuyen Euler rates sang w trong World Frame
    pitch_r = pitch * pi/180;
    roll_r  = roll  * pi/180;

    E_body = [1,        0,             -sin(pitch_r)          ;
              0,  cos(roll_r),   sin(roll_r)*cos(pitch_r)    ;
              0, -sin(roll_r),   cos(roll_r)*cos(pitch_r)    ];

    euler_dot_rad = pose_dot(4:6)' * (pi/180);
    v_p     = pose_dot(1:3)';
    w_body  = E_body * euler_dot_rad;
    w_world = R * w_body;
    X_dot   = [v_p; w_world];

    % Dong hoc nguoc
    L_vec  = T + R * B_mat - A_mat;
    l_sq   = sum(L_vec.^2, 1);

    Q_ik   = l_sq - L2^2 + L1^2;
    M_ik   = 2 * L1 * L_vec(3, :);
    N_ik   = 2 * L1 * (cosd(gamma_ang) .* L_vec(1,:) + sind(gamma_ang) .* L_vec(2,:));
    mau_so = sqrt(M_ik.^2 + N_ik.^2);
    arg    = Q_ik ./ mau_so;

    if any(abs(arg) > 1)
        error('jacobian_motor: Pose vuot gioi han dong hoc.');
    end

    phi_raw_deg = asind(arg) - atan2d(N_ik, M_ik);

    % Xay dung Jacobian (J_raw = J_q vi d(phi_thuc)/dt = d(phi_raw)/dt)
    J_q = zeros(6, 6);

    for i = 1:6
        g_i = gamma_ang(i)   * pi/180;
        q_i = phi_raw_deg(i) * pi/180;

        B_i = T + R * B_mat(:, i);
        P_i = A_mat(:,i) + L1 * [ cos(g_i)*cos(q_i);
                                   sin(g_i)*cos(q_i);
                                   sin(q_i)          ];

        rod = B_i - P_i;
        s_i = rod / norm(rod);

        dPdq = L1 * [-cos(g_i)*sin(q_i);
                     -sin(g_i)*sin(q_i);
                      cos(q_i)          ];

        r_Bi = R * B_mat(:, i);
        a_i  = s_i' * dPdq;
        if abs(a_i) < 1e-10
            a_i = sign(a_i + eps) * 1e-10;
        end

        J_q(i, 1:3) = s_i'             / a_i;
        J_q(i, 4:6) = cross(r_Bi,s_i)' / a_i;
    end

    % Tinh van toc goc
    q_dot = J_q * X_dot;

    % Tinh gia toc goc
    if ~need_accel
        q_ddot = zeros(6, 1);
        return;
    end

    a_p = pose_ddot(1:3)';
    euler_ddot_rad = pose_ddot(4:6)' * (pi/180);
    roll_d  = euler_dot_rad(1);
    pitch_d = euler_dot_rad(2);

    dEbody_dt = [0,  0,                              -cos(pitch_r)*pitch_d               ;
                 0, -sin(roll_r)*roll_d,   cos(roll_r)*cos(pitch_r)*roll_d - sin(roll_r)*sin(pitch_r)*pitch_d ;
                 0, -cos(roll_r)*roll_d,  -sin(roll_r)*cos(pitch_r)*roll_d - cos(roll_r)*sin(pitch_r)*pitch_d ];

    w_dot_body  = E_body * euler_ddot_rad + dEbody_dt * euler_dot_rad;
    w_dot_world = R * w_dot_body;
    X_ddot      = [a_p; w_dot_world];

    h_t    = 1e-5;
    pose_p = pose + pose_dot * h_t;
    pose_m = pose - pose_dot * h_t;

    J_p = build_J(pose_p, A_mat, B_mat, L1, L2, gamma_ang);
    J_m = build_J(pose_m, A_mat, B_mat, L1, L2, gamma_ang);

    J_q_dot = (J_p - J_m) / (2 * h_t);

    q_ddot = J_q * X_ddot + J_q_dot * X_dot;

end

function R = rot_zyx(roll_deg, pitch_deg, yaw_deg)
    cr = cosd(roll_deg);  sr = sind(roll_deg);
    cp = cosd(pitch_deg); sp = sind(pitch_deg);
    cy = cosd(yaw_deg);   sy = sind(yaw_deg);
    R = [cy*cp,  cy*sp*sr - sy*cr,  cy*sp*cr + sy*sr;
         sy*cp,  sy*sp*sr + cy*cr,  sy*sp*cr - cy*sr;
         -sp,    cp*sr,             cp*cr            ];
end

function J = build_J(pose, A_mat, B_mat, L1, L2, gamma_ang)
    roll  = pose(4); pitch = pose(5); yaw = pose(6);
    T     = pose(1:3)';
    R     = rot_zyx(roll, pitch, yaw);

    L_vec  = T + R * B_mat - A_mat;
    l_sq   = sum(L_vec.^2, 1);
    Q_ik   = l_sq - L2^2 + L1^2;
    M_ik   = 2 * L1 * L_vec(3, :);
    N_ik   = 2 * L1 * (cosd(gamma_ang) .* L_vec(1,:) + sind(gamma_ang) .* L_vec(2,:));
    mau_so = sqrt(M_ik.^2 + N_ik.^2);
    arg    = Q_ik ./ mau_so;

    if any(abs(arg) > 1)
        J = zeros(6, 6);
        return;
    end

    phi_raw_deg = asind(arg) - atan2d(N_ik, M_ik);

    J = zeros(6, 6);
    for i = 1:6
        g_i = gamma_ang(i)   * pi/180;
        q_i = phi_raw_deg(i) * pi/180;

        B_i = T + R * B_mat(:, i);
        P_i = A_mat(:,i) + L1 * [ cos(g_i)*cos(q_i);
                                   sin(g_i)*cos(q_i);
                                   sin(q_i)          ];
        rod = B_i - P_i;
        s_i = rod / norm(rod);

        dPdq = L1 * [-cos(g_i)*sin(q_i);
                     -sin(g_i)*sin(q_i);
                      cos(q_i)          ];

        r_Bi = R * B_mat(:, i);
        a_i  = s_i' * dPdq;
        if abs(a_i) < 1e-10
            a_i = sign(a_i + eps) * 1e-10;
        end

        J(i, 1:3) = s_i'             / a_i;
        J(i, 4:6) = cross(r_Bi,s_i)' / a_i;
    end
end
