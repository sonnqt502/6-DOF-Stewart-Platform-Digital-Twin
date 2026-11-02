function [phi_thuc_history, t_out] = traj_to_motor_angle(traj, A, B, L1, L2, gamma, options)
% TRAJ_TO_MOTOR_ANGLE  Chuyển quỹ đạo bệ động → quỹ đạo góc 6 động cơ (ĐỒNG BỘ 100% DASHBOARD_STEWART5)
%
% INPUTS:
%   traj   - Ma trận Nx7: [t, x, y, z, yaw, pitch, roll]
%              t                : thời gian (s)
%              x, y, z          : vị trí tịnh tiến (mm)
%              yaw, pitch, roll : góc Euler (độ)
%
% OUTPUT:
%   phi_thuc_history - Ma trận N×6 góc thực tế 6 động cơ (độ)
%   t_out            - Vector Nx1 thời gian (s)

    % -----------------------------------------------------------------
    % Thông số cơ khí mặc định — Máy CKAS thực tế
    % -----------------------------------------------------------------
    if nargin < 2 || isempty(A)
        A = [ 556.009538774124, -107.962917791227, -448.046620982896, ...
             -448.046620982896, -107.962917791227,  556.009538774124;
             -196.347417584715, -579.692094117217, -383.344676532502, ...
              383.344676532502,  579.692094117217,  196.347417584715;
              668.400000000000,  668.400000000000,  668.400000000000, ...
              668.400000000000,  668.400000000000,  668.400000000000 ];
    end
    if nargin < 3 || isempty(B)
        B = [ 256.599204538802,  169.981755823305, -426.649811653508, ...
             -426.641083944694,  170.050607114706,  256.659328121389;
             -344.505147401391, -394.503676843735,  -49.968856020786, ...
               50.043319699002,  394.474003422177,  344.460357144733;
              0, 0, 0, 0, 0, 0 ];
    end
    if nargin < 4 || isempty(L1),    L1    = 150;  end
    if nargin < 5 || isempty(L2),    L2    = 747;  end
    if nargin < 6 || isempty(gamma)
        gamma = [-109.45, -10.55, -229.45, -130.55, -349.45, -250.55];
    end
    if nargin < 7, options = struct(); end

    % -----------------------------------------------------------------
    % Xử lý options mặc định (Home Z mặc định -75 mm theo Dashboard_Stewart5)
    % -----------------------------------------------------------------
    if ~isfield(options, 'plot_result'),  options.plot_result  = true;  end
    if ~isfield(options, 'export_csv'),   options.export_csv   = false; end
    if ~isfield(options, 'csv_path'),     options.csv_path     = 'test.csv'; end
    if ~isfield(options, 'home_z'),       options.home_z       = 0.0; end

    % -----------------------------------------------------------------
    % Trích xuất dữ liệu quỹ đạo
    % -----------------------------------------------------------------
    if size(traj, 2) == 7
        t_out   = traj(:, 1);
        poses   = traj(:, 2:7);   % [x, y, z, yaw, pitch, roll]
    elseif size(traj, 2) == 6
        poses   = traj;
        t_out   = (0 : size(traj,1)-1)' * 0.02;
    else
        error('traj phải có 6 cột [x,y,z,yaw,pitch,roll] hoặc 7 cột [t,x,y,z,yaw,pitch,roll].');
    end

    N = size(poses, 1);
    phi_thuc_history = zeros(N, 6);
    is_safe_flag     = true(N, 1);
    P_0 = [0; 0; options.home_z];

    % -----------------------------------------------------------------
    % Vòng lặp IK cho từng bước thời gian bằng donghocnguoc_final1
    % -----------------------------------------------------------------
    for k = 1:N
        P_file = [poses(k, 1); poses(k, 2); poses(k, 3)];
        yw = poses(k, 4); p = poses(k, 5); r = poses(k, 6);

        % Ma trận quay ZYX
        cr = cosd(r); sr = sind(r);
        cp = cosd(p); sp = sind(p);
        cy = cosd(yw); sy = sind(yw);
        R_k = [cy*cp, cy*sp*sr - sy*cr, cy*sp*cr + sy*sr;
               sy*cp, sy*sp*sr + cy*cr, sy*sp*cr - cy*sr;
               -sp,   cp*sr,            cp*cr];

        pos_plat = P_0 + R_k * P_file;
        pose_k = [pos_plat(1), pos_plat(2), pos_plat(3), r, p, yw];

        phi_k = donghocnguoc_final1(pose_k, A, B, L1, L2, gamma);
        phi_thuc_history(k, :) = phi_k;

        if any(isnan(phi_k))
            is_safe_flag(k) = false;
        end
    end

    % -----------------------------------------------------------------
    % Vẽ đồ thị
    % -----------------------------------------------------------------
    if options.plot_result
        figure('Name', 'Quỹ đạo góc Động cơ CKAS', 'Position', [80 80 1200 700]);

        subplot(2, 2, 1);
        plot(t_out, poses(:,1), 'b', t_out, poses(:,2), 'g', t_out, poses(:,3), 'r', 'LineWidth', 1.5);
        xlabel('Thời gian (s)'); ylabel('Vị trí (mm)');
        title('Quỹ đạo Tịnh tiến bệ động');
        legend('X','Y','Z'); grid on;

        subplot(2, 2, 2);
        plot(t_out, poses(:,4), 'b', t_out, poses(:,5), 'g', t_out, poses(:,6), 'r', 'LineWidth', 1.5);
        xlabel('Thời gian (s)'); ylabel('Góc (độ)');
        title('Quỹ đạo Góc bệ động');
        legend('Yaw','Pitch','Roll'); grid on;

        subplot(2, 2, [3 4]);
        colors = lines(6);
        hold on;
        for i = 1:6
            plot(t_out, phi_thuc_history(:, i), 'Color', colors(i,:), 'LineWidth', 1.8, ...
                'DisplayName', sprintf('Motor %d', i));
        end
        if any(~is_safe_flag)
            scatter(t_out(~is_safe_flag), zeros(sum(~is_safe_flag),1), ...
                80, 'rx', 'LineWidth', 2, 'DisplayName', 'Kịch cơ khí');
        end
        xlabel('Thời gian (s)'); ylabel('Góc động cơ (độ)');
        title('Quỹ đạo Góc Thực tế của 6 Động cơ (phi\_thuc)');
        legend('Location','Best'); grid on;
    end

    % -----------------------------------------------------------------
    % Xuất file CSV
    % -----------------------------------------------------------------
    if options.export_csv
        fid = fopen(options.csv_path, 'w');
        if fid ~= -1
            fprintf(fid, 't,x,y,z,yaw,pitch,roll,phi1,phi2,phi3,phi4,phi5,phi6\n');
            for k = 1:N
                fprintf(fid, '%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f\n', ...
                    t_out(k), poses(k,1), poses(k,2), poses(k,3), ...
                    poses(k,4), poses(k,5), poses(k,6), ...
                    phi_thuc_history(k,1), phi_thuc_history(k,2), phi_thuc_history(k,3), ...
                    phi_thuc_history(k,4), phi_thuc_history(k,5), phi_thuc_history(k,6));
            end
            fclose(fid);
        end
    end
end
