function find_nominal_L_limits()
    cfg = jsondecode(fileread('config.json'));
    
    % Sweep pure Z movement
    Z_sweep = linspace(200, 1000, 10000);
    x = zeros(size(Z_sweep));
    y = zeros(size(Z_sweep));
    roll = zeros(size(Z_sweep));
    pitch = zeros(size(Z_sweep));
    yaw = zeros(size(Z_sweep));
    
    [L_lengths, is_valid, ~] = kinematic_chan_ao(x, y, Z_sweep', roll, pitch, yaw, cfg);
    
    valid_L = L_lengths(1, is_valid);
    if ~isempty(valid_L)
        L_nom_min = min(valid_L);
        L_nom_max = max(valid_L);
        fprintf('Nominal Pure Z Min L: %f\n', L_nom_min);
        fprintf('Nominal Pure Z Max L: %f\n', L_nom_max);
    end
    
    % We can also just calculate the L limits based on the motor limits directly
    % for the pure Z movement.
end
