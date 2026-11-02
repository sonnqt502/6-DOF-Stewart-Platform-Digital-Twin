function [J, theta_dot] = jacobian_RUS(pose, pose_dot, A_mat, B_mat, L1, L2, gamma_ang)
% JACOBIAN VẬN TỐC CHO CƠ CẤU RUS
% Dùng phi_raw (góc vật lý thực, trước offset servo) để tính Jacobian
%
% Inputs:
%   pose      : [x, y, z, roll, pitch, yaw] — mm và độ (ZYX Euler)
%   pose_dot  : [vx, vy, vz, roll_dot, pitch_dot, yaw_dot] — mm/s và deg/s
%   A_mat     : 3x6 tọa độ khớp R tại base (mm)
%   B_mat     : 3x6 tọa độ khớp S tại platform (mm, trong PF)
%   L1, L2    : Chiều dài servo arm và rod (mm)
%   gamma_ang : 1x6 góc gá motor (độ)
%
% Outputs:
%   J         : 6x6 Jacobian — phi_raw_dot(rad/s) = J * [v_p(mm/s); w_p(rad/s)]
%   theta_dot : 6x1 vận tốc góc servo arm vật lý (deg/s), tương ứng phi_raw

% =========================================================
% BƯỚC 1: Rotation Matrix R = Rz(yaw)*Ry(pitch)*Rx(roll)
% =========================================================
roll  = pose(4); pitch = pose(5); yaw = pose(6);
cr = cosd(roll);  sr = sind(roll);
cp = cosd(pitch); sp = sind(pitch);
cy = cosd(yaw);   sy = sind(yaw);

R = [cy*cp,  cy*sp*sr - sy*cr,  cy*sp*cr + sy*sr;
     sy*cp,  sy*sp*sr + cy*cr,  sy*sp*cr - cy*sr;
     -sp,    cp*sr,             cp*cr];

T = pose(1:3)';   % 3x1, mm

% =========================================================
% BƯỚC 2: Euler rates → Angular velocity (ZYX convention)
%   ω_IF = E * [roll_dot; pitch_dot; yaw_dot]
% =========================================================
r_dot = pose_dot(4) * pi/180;
p_dot = pose_dot(5) * pi/180;
y_dot = pose_dot(6) * pi/180;

pitch_r = pitch * pi/180;
roll_r  = roll  * pi/180;

E = [1,          0,              -sin(pitch_r);
     0,   cos(roll_r),   sin(roll_r)*cos(pitch_r);
     0,  -sin(roll_r),   cos(roll_r)*cos(pitch_r)];

v_p = pose_dot(1:3)';
w_p = E * [r_dot; p_dot; y_dot];   % 3x1, rad/s

% =========================================================
% BƯỚC 3: Lấy phi_raw từ IK (góc vật lý, chưa offset)
% =========================================================
[phi_raw_deg, ~] = donghocnguoc_raw(pose, A_mat, B_mat, L1, L2, gamma_ang);

if any(isnan(phi_raw_deg))
    error('jacobian_RUS: Pose không khả thi (IK = NaN)');
end

% =========================================================
% BƯỚC 4: Xây dựng Jacobian — Loop closure velocity
%
%   Ràng buộc: |B_i - P_i(phi_i)|^2 = L2^2
%   Đạo hàm:  s_i' * (B_dot_i - P_dot_i) = 0
%
%   s_i      = (B_i - P_i) / L2          unit vector dọc rod
%   B_dot_i  = v_p + w x r_Bi            vận tốc khớp S
%   P_dot_i  = dP_i/dphi_i * phi_dot_i   vận tốc đầu servo arm
%
%   => phi_dot_i = [s_i' , (r_Bi x s_i)'] * [v_p; w_p]
%                  ─────────────────────────────────────
%                           s_i' * dP_i/dphi_i
% =========================================================
J = zeros(6, 6);

for i = 1:6
    % Vị trí khớp S trong IF
    B_i = T + R * B_mat(:, i);             % 3x1

    % Góc servo arm vật lý (phi_raw)
    g_i   = gamma_ang(i)    * pi/180;      % rad
    phi_i = phi_raw_deg(i)  * pi/180;      % rad ← dùng phi_RAW

    % Vị trí đầu servo arm
    % P_i = A_i + L1*[cos(g)*cos(phi); sin(g)*cos(phi); sin(phi)]
    P_i = A_mat(:,i) + L1 * [cos(g_i)*cos(phi_i);
                               sin(g_i)*cos(phi_i);
                               sin(phi_i)];         % 3x1

    % Unit vector dọc rod
    rod_vec = B_i - P_i;                           % 3x1
    s_i = rod_vec / norm(rod_vec);                  % 3x1

    % dP_i/dphi_i (đạo hàm theo góc vật lý phi_raw)
    dP_dphi = L1 * [-cos(g_i)*sin(phi_i);
                    -sin(g_i)*sin(phi_i);
                     cos(phi_i)];                   % 3x1, mm/rad

    % Vector từ tâm platform đến khớp S
    r_Bi = B_i - T;                                % 3x1

    % Mẫu số
    denom = s_i' * dP_dphi;                        % scalar, mm/rad

    if abs(denom) < 1e-10
        warning('jacobian_RUS: Leg %d singular (denom=%.2e)', i, denom);
    end

    J(i, 1:3) = s_i'            / denom;           % [rad/mm]
    J(i, 4:6) = cross(r_Bi,s_i)' / denom;          % [rad/rad]
end

% =========================================================
% BƯỚC 5: Tính theta_dot (vận tốc phi_raw)
% =========================================================
theta_dot_rad = J * [v_p; w_p];        % 6x1, rad/s
theta_dot     = theta_dot_rad * 180/pi; % 6x1, deg/s

end