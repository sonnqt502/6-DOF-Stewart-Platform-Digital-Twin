function [phi_raw, phi_out] = donghocnguoc_raw(pose, A_mat, B_mat, L1, L2, gamma_ang)
% Tách phi_raw (trước offset) và phi_out (sau offset) từ IK
% phi_raw dùng cho Jacobian, phi_out dùng để điều khiển servo

    roll = pose(4); pitch = pose(5); yaw = pose(6);
    cr = cosd(roll); sr = sind(roll);
    cp = cosd(pitch); sp = sind(pitch);
    cy = cosd(yaw);   sy = sind(yaw);

    R = [cy*cp, cy*sp*sr - sy*cr, cy*sp*cr + sy*sr;
         sy*cp, sy*sp*sr + cy*cr, sy*sp*cr - cy*sr;
         -sp,   cp*sr,            cp*cr];

    T = [pose(1); pose(2); pose(3)];
    L_vec = T + R * B_mat - A_mat;
    l_sq  = sum(L_vec.^2, 1);

    Q = l_sq - L2^2 + L1^2;
    M = 2 * L1 * L_vec(3, :);
    N = 2 * L1 * (cosd(gamma_ang) .* L_vec(1,:) + sind(gamma_ang) .* L_vec(2,:));

    mau_so = sqrt(M.^2 + N.^2);
    arg    = Q ./ mau_so;

    invalid_idx = abs(arg) > 1;

    % phi_raw — GÓC VẬT LÝ THỰC, chưa có offset servo
    phi_raw = -(asind(arg) - atan2d(N, M));   % 1x6, deg

    % phi_out — có offset để gửi cho servo
    phi_out = zeros(1,6);
    phi_out(1:2:5) = 180 - phi_raw(1:2:5);
    phi_out(2:2:6) = -180 + phi_raw(2:2:6);

    if any(invalid_idx)
        phi_raw(:) = NaN;
        phi_out(:) = NaN;
    end
end