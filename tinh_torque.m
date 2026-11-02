function [tau_motor, tau_platform, tau_inertia, F_joint_Ci, F_joint_Bi, f_rod] = ...
    tinh_torque(pose, pose_dot, pose_ddot, A_mat, B_mat, L1, L2, gamma_ang, ...
                m_platform, I_platform, I_rotor, m_arm, m_rod)
% TINH_TORQUE  Tính moment động cơ và lực khớp cho cơ cấu 6-RUS CKAS Stewart
%
% -----------------------------------------------------------------------
% INPUTS:
%   pose        : [x, y, z, roll, pitch, yaw]             (mm và độ)
%   pose_dot    : [vx, vy, vz, roll_d, pitch_d, yaw_d]   (mm/s và độ/s)
%   pose_ddot   : [ax, ay, az, roll_dd, pitch_dd, yaw_dd](mm/s² và độ/s²)
%   A_mat       : Ma trận 3×6 tọa độ khớp quay ở đế (mm)
%   B_mat       : Ma trận 3×6 tọa độ khớp cầu ở bàn máy body-frame (mm)
%   L1, L2      : Chiều dài tay quay (mm) và thanh truyền (mm)
%   gamma_ang   : Vector 1×6 góc gá động cơ (độ)
%   m_platform  : Khối lượng bệ động (kg)
%   I_platform  : Momen quán tính bệ động [Ixx, Iyy, Izz] (kg·m²)
%   I_rotor     : Momen quán tính chỉ rotor động cơ (kg·m²)
%                 (không gồm tay quay – tay quay sẽ tính từ m_arm)
%   m_arm       : Khối lượng tay quay L1 (kg)  [mặc định: 1.5 kg]
%   m_rod       : Khối lượng thanh truyền L2 (kg) [mặc định: 0 kg]
%
% OUTPUTS:
%   tau_motor    : 6×1  moment tổng tại trục động cơ (N·m)
%   tau_platform : 6×1  thành phần do lực/moment bệ (PVW) (N·m)
%   tau_inertia  : 6×1  thành phần quán tính (rotor+arm+rod) (N·m)
%   F_joint_Ci   : 3×6  lực tại khớp U (Ci), world frame (N)
%   F_joint_Bi   : 3×6  lực tại khớp S (Bi'), world frame (N)
%   f_rod        : 6×1  lực dọc trục trong mỗi thanh truyền (N)
%                       dương = kéo (tension), âm = nén (compression)
% -----------------------------------------------------------------------

    g_vec  = [0; 0; -9.81];   % m/s²
    L1_m   = L1 / 1000.0;     % mm → m
    L2_m   = L2 / 1000.0;

    %% 1. Giá trị mặc định
    persistent cached_m_p cached_I_p cached_I_rotor cached_m_arm
    if isempty(cached_m_p)
        try
            [cached_m_p, cached_I_p, cached_m_arm_sc, cached_I_arm_sc] = load_simscape_params();
            % I_rotor mặc định = I_arm_Simscape - I_arm_lý_thuyết(m_arm_sc)
            % để tránh đếm đôi khi người dùng nhập m_arm
            I_arm_theory = cached_m_arm_sc * L1_m^2 / 3.0;
            cached_I_rotor = max(0, cached_I_arm_sc - I_arm_theory);
            cached_m_arm   = cached_m_arm_sc;
        catch
            cached_m_p     = 30.0653;
            cached_I_p     = [9.8506, 19.6451, 9.8506];
            cached_I_rotor = 0.005;   % rotor thuần (~1/4 tổng)
            cached_m_arm   = 1.5848;
        end
    end

    if nargin < 9  || isempty(m_platform), m_platform = cached_m_p;     end
    if nargin < 10 || isempty(I_platform), I_platform = cached_I_p;     end
    if nargin < 11 || isempty(I_rotor),    I_rotor    = cached_I_rotor; end
    if nargin < 12 || isempty(m_arm),      m_arm      = cached_m_arm;   end
    if nargin < 13 || isempty(m_rod),      m_rod      = 0.0;            end
    if nargin < 3  || isempty(pose_ddot),  pose_ddot  = zeros(1, 6);    end

    %% 2. Jacobian và gia tốc góc động cơ
    [J_q, q_dot, q_ddot] = jacobian_motor(pose, pose_dot, pose_ddot, ...
                                           A_mat, B_mat, L1, L2, gamma_ang);

    %% 3. Động lực học bệ động (Newton-Euler)
    roll  = pose(4); pitch = pose(5); yaw = pose(6);
    R     = rot_zyx_local(roll, pitch, yaw);
    T     = pose(1:3)';                       % mm

    a_p_m = pose_ddot(1:3)' / 1000.0;        % mm/s² → m/s²

    % Vận tốc / gia tốc góc bệ
    pitch_r = pitch * pi/180;  roll_r = roll * pi/180;
    E_body  = [1,           0,                  -sin(pitch_r);
               0,    cos(roll_r),   sin(roll_r)*cos(pitch_r);
               0,   -sin(roll_r),   cos(roll_r)*cos(pitch_r)];

    euler_dot_rad  = pose_dot(4:6)'  * (pi/180);
    euler_ddot_rad = pose_ddot(4:6)' * (pi/180);
    roll_d  = euler_dot_rad(1);  pitch_d = euler_dot_rad(2);

    w_body  = E_body * euler_dot_rad;
    w_world = R * w_body;

    dEbody  = [0,  0,                                     -cos(pitch_r)*pitch_d;
               0, -sin(roll_r)*roll_d,   cos(roll_r)*cos(pitch_r)*roll_d - sin(roll_r)*sin(pitch_r)*pitch_d;
               0, -cos(roll_r)*roll_d,  -sin(roll_r)*cos(pitch_r)*roll_d - cos(roll_r)*sin(pitch_r)*pitch_d];

    w_dot_body  = E_body * euler_ddot_rad + dEbody * euler_dot_rad;
    w_dot_world = R * w_dot_body;

    % Tensor quán tính bệ
    if isvector(I_platform), I_p_body = diag(I_platform);
    else,                     I_p_body = I_platform; end
    I_p_world = R * I_p_body * R';

    % Lực và moment bệ động
    F_plat = m_platform * (a_p_m - g_vec);                              % N
    M_plat = I_p_world * w_dot_world + cross(w_world, I_p_world * w_world); % N·m

    %% 4. Đóng góp khối lượng thanh truyền L2 vào Wrench
    %   Mỗi rod có CG tại (Ci + Bi')/2.
    %   Lực quán tính + trọng lực của rod → hiệu chỉnh Wrench bệ.
    %   Phần tác dụng tại Bi': 1/2 rod dyn force.
    L_vec   = T + R * B_mat - A_mat;   % 3×6, mm
    l_sq    = sum(L_vec.^2, 1);
    Q_ik    = l_sq - L2^2 + L1^2;
    M_ik    = 2 * L1 * L_vec(3,:);
    N_ik    = 2 * L1 * (cosd(gamma_ang) .* L_vec(1,:) + sind(gamma_ang) .* L_vec(2,:));
    mau_so  = sqrt(M_ik.^2 + N_ik.^2);
    arg_ik  = Q_ik ./ mau_so;
    arg_ik  = max(-1, min(1, arg_ik));
    q_raw_deg = asind(arg_ik) - atan2d(N_ik, M_ik);   % 1×6
    q_raw_rad = q_raw_deg' * (pi/180);                 % 6×1

    % Vị trí Ci (mm) cho từng chân
    C_mat = A_mat + L1 * [cosd(gamma_ang) .* cosd(q_raw_deg);
                           sind(gamma_ang) .* cosd(q_raw_deg);
                                             sind(q_raw_deg)];   % 3×6

    % Vận tốc Ci (mm/s): dC_i/dt = L1 * [-cos_g*sin_q; -sin_g*sin_q; cos_q]*q_dot_i
    dCi_dq = L1 * [-cosd(gamma_ang) .* sind(q_raw_deg);
                    -sind(gamma_ang) .* sind(q_raw_deg);
                                        cosd(q_raw_deg)];        % 3×6 (mm/rad)
    vel_Ci = dCi_dq .* q_dot';                                   % 3×6 (mm/s)

    % Gia tốc Ci (mm/s²): phần tuyến tính + tâm
    d2Ci_dq2 = L1 * [-cosd(gamma_ang) .* cosd(q_raw_deg);
                      -sind(gamma_ang) .* cosd(q_raw_deg);
                                         -sind(q_raw_deg)];      % 3×6
    acc_Ci   = d2Ci_dq2 .* (q_dot').^2 + dCi_dq .* q_ddot';    % 3×6 (mm/s²)

    % Vận tốc và gia tốc Bi' trong world frame
    B_world  = T + R * B_mat;                                    % 3×6 (mm)
    b_vec    = B_world - T;                                      % 3×6 (mm)
    v_p_col  = pose_dot(1:3)';
    vel_Bi   = v_p_col + [cross(w_world, b_vec(:,1)), cross(w_world, b_vec(:,2)), ...
                           cross(w_world, b_vec(:,3)), cross(w_world, b_vec(:,4)), ...
                           cross(w_world, b_vec(:,5)), cross(w_world, b_vec(:,6))]; % 3×6

    a_p_mm   = pose_ddot(1:3)';
    alpha_w  = w_dot_world;
    acc_Bi   = a_p_mm + [cross(alpha_w, b_vec(:,1)) + cross(w_world, cross(w_world, b_vec(:,1))), ...
                          cross(alpha_w, b_vec(:,2)) + cross(w_world, cross(w_world, b_vec(:,2))), ...
                          cross(alpha_w, b_vec(:,3)) + cross(w_world, cross(w_world, b_vec(:,3))), ...
                          cross(alpha_w, b_vec(:,4)) + cross(w_world, cross(w_world, b_vec(:,4))), ...
                          cross(alpha_w, b_vec(:,5)) + cross(w_world, cross(w_world, b_vec(:,5))), ...
                          cross(alpha_w, b_vec(:,6)) + cross(w_world, cross(w_world, b_vec(:,6)))]; % 3×6 mm/s²

    % Gia tốc CG rod = (Ci + Bi')/2, đổi mm/s² → m/s²
    acc_Gi_rod = (acc_Ci + acc_Bi) / 2.0 / 1000.0;   % 3×6 (m/s²)

    % Lực động lực học rod (= m_rod * (a_G - g))
    F_rod_dyn = m_rod * (acc_Gi_rod - g_vec);          % 3×6 (N) — tổng 2 đầu rod

    % Hiệu chỉnh Wrench bệ: mỗi rod đóng góp 1/2 lực tại Bi'
    dF_plat = sum(F_rod_dyn / 2.0, 2);                 % 3×1 (N)
    dM_plat = zeros(3,1);
    for i = 1:6
        r_i     = b_vec(:,i) / 1000.0;                 % m
        dM_plat = dM_plat + cross(r_i, F_rod_dyn(:,i)/2.0);
    end
    F_eff = F_plat + dF_plat;
    M_eff = M_plat + dM_plat;

    %% 5. PVW: tau_platform
    % Wrench đã quy đổi đơn vị (F chia 1000 vì J_q(1:3) có đơn vị rad/mm)
    W_scaled    = [F_eff / 1000.0; M_eff];
    tau_platform = (J_q') \ W_scaled;               % 6×1

    %% 6. Lực dọc trục trong thanh truyền f_i
    %   Từ J_q(i,:) = [s_hat_i/a_i, (b_i × s_hat_i)/a_i]
    %   tau_platform_i = a_i * f_i  =>  f_i = tau_platform_i / a_i
    %   Tính a_i từ Jacobian và s_hat_i
    s_hat = (B_world - C_mat) / L2;                 % 3×6 (đơn vị mm/mm = -)
    a_coeff = zeros(6,1);
    for i = 1:6
        dCi_col  = dCi_dq(:,i);  % mm (= L1 * [...])
        a_coeff(i) = dot(s_hat(:,i), dCi_col);      % mm
    end
    f_rod = tau_platform ./ a_coeff * 1000.0;       % N (vì a_coeff mm, tau N·m → *1000)

    %% 7. Lực tại khớp Bi' và Ci
    %  Newton cho rod: F_Ci_on_rod + F_Bi_on_rod + m_rod*g = m_rod*a_G
    %  F_Bi_on_rod ≈ -f_i * s_hat_i  (axial) + rod_correction
    %  F_Ci_on_rod = m_rod*(a_G - g) - F_Bi_on_rod

    F_joint_Bi = zeros(3,6);
    F_joint_Ci = zeros(3,6);
    for i = 1:6
        % Lực dọc trục tại Bi' (rod đẩy/kéo platform)
        F_axial_i  = f_rod(i) * s_hat(:,i);         % N

        % Hiệu chỉnh do quán tính + trọng lực rod tại Bi' (1/2 rod)
        F_rod_half = F_rod_dyn(:,i) / 2.0;          % N
        F_joint_Bi(:,i) = F_axial_i - F_rod_half;

        % Lực tại Ci (phản lực rod đẩy lên tay quay)
        % Newton rod: F_Ci→rod + F_Bi→rod = m_rod*(a_G - g)
        % F_Bi→rod = -F_joint_Bi(:,i) (phản lực của Bi' lên rod)
        F_Ci_on_rod = F_rod_dyn(:,i) - (-F_joint_Bi(:,i));
        F_joint_Ci(:,i) = -F_Ci_on_rod;             % lực rod tác dụng vào cánh tay quay
    end

    %% 8. Moment quán tính (Cách B)
    %  I_total = I_rotor  (chỉ rotor, nhập từ GUI)
    %           + I_arm_eff = m_arm * L1^2/3    (tay quay, thanh đồng chất quanh đầu)
    %           + I_rod_eff = m_rod * (L1/2)^2  (đóng góp của rod do q_dot_i)
    I_arm_eff  = m_arm * L1_m^2 / 3.0;
    I_rod_eff  = m_rod * (L1_m / 2.0)^2;
    I_total    = I_rotor + I_arm_eff + I_rod_eff;

    tau_inertia = I_total * q_ddot;                  % 6×1

    %% 9. Trọng lực tay quay + thanh truyền tại trục Ai
    %  Dùng Lagrangian:
    %    ∂z_arm_CG/∂q_i = (L1/2)*cos(q_i)
    %    ∂z_rod_CG/∂q_i = (L1/2)*cos(q_i)  [Bi' không phụ thuộc q_i]
    %  tau_grav_i = -(m_arm + m_rod)*g*(L1/2)*cos(q_i)
    tau_arm_grav = -(m_arm + m_rod) * 9.81 * (L1_m / 2.0) * cos(q_raw_rad); % 6×1

    %% 10. Ma sát nhớt
    b_m          = 0.02;  % N·m·s/rad
    tau_friction = b_m * q_dot;

    %% 11. Moment tổng tại trục động cơ
    tau_motor = tau_platform + tau_inertia + tau_arm_grav + tau_friction;

end

% -----------------------------------------------------------------------
function R = rot_zyx_local(roll_deg, pitch_deg, yaw_deg)
    cr = cosd(roll_deg);  sr = sind(roll_deg);
    cp = cosd(pitch_deg); sp = sind(pitch_deg);
    cy = cosd(yaw_deg);   sy = sind(yaw_deg);
    R = [cy*cp,  cy*sp*sr - sy*cr,  cy*sp*cr + sy*sr;
         sy*cp,  sy*sp*sr + cy*cr,  sy*sp*cr - cy*sr;
         -sp,    cp*sr,             cp*cr            ];
end
