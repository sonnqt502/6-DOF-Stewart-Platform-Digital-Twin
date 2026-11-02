% debug_signs.m
clc;
head_dir = 'c:\Users\Admin\Desktop\lab\ckas\simcape\sime4\distance_pivot';
pivot_file = 'c:\Users\Admin\Desktop\lab\ckas\simcape\sime4\distance_pivot\Pivot_Command.csv';
fname = 'z0 10do 0.25hz.csv';

% Pivot
raw_p = parseMoogFile(pivot_file);
Axi_aligned_p = raw_p(:, [11, 12, 13]); 
W_aligned_p   = raw_p(:, [16, 15, 14]); 
t_p_raw   = raw_p(:, 1);

% Head
raw_h = readmatrix(fullfile(head_dir, fname), 'NumHeaderLines', 1);
Axi_raw_h = raw_h(:, 2:4) * 9.81;
W_raw_h   = raw_h(:, 5:7) * (pi / 180);
t_h = raw_h(:, 1);

% PCA
z0_file = fullfile(head_dir, 'z0 10do 0.25hz.csv');
raw_h_ref = readmatrix(z0_file, 'NumHeaderLines', 1);
Axi_raw_h_ref = raw_h_ref(:, 2:4) * 9.81;
W_raw_h_ref   = raw_h_ref(:, 5:7) * (pi / 180);
t_h_raw_ref   = raw_h_ref(:, 1);
n_static_h = sum(t_h_raw_ref - t_h_raw_ref(1) <= 2.0);
X_raw_h = W_raw_h_ref;
mu_h = mean(X_raw_h);
X_centered_h = X_raw_h - mu_h;
C_h = (X_centered_h' * X_centered_h) / (size(X_centered_h, 1) - 1);
[EigenVectors_h, EigenValuesDiag_h] = eig(C_h);
[~, sortIdx_h] = sort(diag(EigenValuesDiag_h), 'descend');
rot_axis_h = EigenVectors_h(:, sortIdx_h(1));
Grav_raw_h = Axi_raw_h_ref;
g_vec_h = mean(Grav_raw_h(1:n_static_h, :))';
g_vec_h = g_vec_h / norm(g_vec_h);
if abs(rot_axis_h(1)) > abs(rot_axis_h(2))
    if rot_axis_h(1) < 0, rot_axis_h = -rot_axis_h; end 
    X_h = rot_axis_h; Y_h = cross(g_vec_h, X_h); Y_h = Y_h / norm(Y_h); Z_h = cross(X_h, Y_h); Z_h = Z_h / norm(Z_h);
else
    if rot_axis_h(2) < 0, rot_axis_h = -rot_axis_h; end 
    Y_h = rot_axis_h; X_h = cross(Y_h, g_vec_h); X_h = X_h / norm(X_h); Z_h = cross(X_h, Y_h); Z_h = Z_h / norm(Z_h);
end
R_PCA_h_GLOBAL = [X_h, Y_h, Z_h];

Axi_aligned_h = Axi_raw_h * R_PCA_h_GLOBAL;
W_aligned_h   = W_raw_h * R_PCA_h_GLOBAL;

t_interp = 5.0;
idx_p = find(t_p_raw >= t_interp, 1);
idx_h = find(t_h >= t_interp, 1);

fprintf('At t=%.1f:\n', t_interp);
fprintf('Pivot Acc (Total): %f, %f, %f\n', Axi_aligned_p(idx_p, 1), Axi_aligned_p(idx_p, 2), Axi_aligned_p(idx_p, 3));
fprintf('Head Acc (Total): %f, %f, %f\n', Axi_aligned_h(idx_h, 1), Axi_aligned_h(idx_h, 2), Axi_aligned_h(idx_h, 3));
fprintf('Pivot Gyro: %f, %f, %f\n', W_aligned_p(idx_p, 1), W_aligned_p(idx_p, 2), W_aligned_p(idx_p, 3));
fprintf('Head Gyro: %f, %f, %f\n', W_aligned_h(idx_h, 1), W_aligned_h(idx_h, 2), W_aligned_h(idx_h, 3));

function data = parseMoogFile(filepath)
    fid = fopen(filepath, 'rt');
    lines = {};
    while ~feof(fid)
        l = fgetl(fid);
        if contains(l, '~M[')
            lines{end+1} = l;
        end
    end
    fclose(fid);
    
    data = zeros(length(lines), 16);
    for i = 1:length(lines)
        s = strrep(lines{i}, '~M[', '');
        s = strrep(s, '[', '');
        parts = sscanf(s, '%f');
        data(i, 1:length(parts)) = parts';
    end
end
