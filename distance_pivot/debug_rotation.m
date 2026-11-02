data = parseMoogFile('after_convert_10_0.25_0.csv');
n_use = 1000;
yaw0 = mean(data(1:n_use, 5));
pitch0 = mean(data(1:n_use, 6));
roll0 = mean(data(1:n_use, 7));
fprintf('Init YPR (deg): Yaw=%.2f, Pitch=%.2f, Roll=%.2f\n', yaw0, pitch0, roll0);

W_raw = data(:, 14:16); % wz, wy, wx
W_raw = [W_raw(:,3), W_raw(:,2), W_raw(:,1)]; % wx, wy, wz

% Function to evaluate a rotation sequence
function cost = eval_rot(W, angles, seq)
    % angles in degrees: [z, y, x]
    % W is Nx3: [wx, wy, wz]
    % We want to minimize W(:,2) and W(:,3)
    R = eul2rotm(deg2rad(angles), seq);
    W_aligned = W * R';
    cost = sum(W_aligned(:,2).^2 + W_aligned(:,3).^2);
end

% Try all 12 Euler sequences
seqs = {'ZYX', 'ZYZ', 'ZXY', 'ZXZ', 'YXZ', 'YXY', 'YZX', 'YZY', 'XYZ', 'XYX', 'XZY', 'XZX'};
best_seq = '';
best_angles = [0 0 0];
min_cost = inf;

options = optimset('Display', 'off');
for i = 1:length(seqs)
    seq = seqs{i};
    % Start with the IMU angles, but which one is which? 
    % Let's just use fminsearch to find the absolute best angles
    x0 = [yaw0, pitch0, roll0];
    [x_opt, cost] = fminsearch(@(x) eval_rot(W_raw, x, seq), x0, options);
    
    if cost < min_cost
        min_cost = cost;
        best_seq = seq;
        best_angles = x_opt;
    end
end

fprintf('\nOPTIMAL ALIGNMENT FOUND:\n');
fprintf('Best Sequence: %s\n', best_seq);
fprintf('Best Angles (deg): %.2f, %.2f, %.2f\n', best_angles(1), best_angles(2), best_angles(3));

% Let's test the ZYX sequence with negative angles
cost_inv = eval_rot(W_raw, -[yaw0, pitch0, roll0], 'ZYX');
fprintf('Cost with -[Yaw0, Pitch0, Roll0] in ZYX: %f\n', cost_inv);

cost_normal = eval_rot(W_raw, [yaw0, pitch0, roll0], 'ZYX');
fprintf('Cost with +[Yaw0, Pitch0, Roll0] in ZYX: %f\n', cost_normal);

% Let's test ZYX with [yaw0, pitch0, roll0] but R instead of R'
R_normal = eul2rotm(deg2rad([yaw0, pitch0, roll0]), 'ZYX');
W_a_R = W_raw * R_normal;
cost_R = sum(W_a_R(:,2).^2 + W_a_R(:,3).^2);
fprintf('Cost with W * R_tilt (Old Buggy Code): %f\n', cost_R);

W_a_R_inv = W_raw * R_normal';
cost_R_inv = sum(W_a_R_inv(:,2).^2 + W_a_R_inv(:,3).^2);
fprintf('Cost with W * R_tilt'' (Current Code): %f\n', cost_R_inv);
