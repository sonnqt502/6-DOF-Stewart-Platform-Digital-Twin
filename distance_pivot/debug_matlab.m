% debug_matlab.m
clc;
head_dir = 'data_before_convert/roll_second';
z0_file = fullfile(head_dir, 'z0 10do 0.25hz.csv');

raw_h_ref = readmatrix(z0_file, 'NumHeaderLines', 1);
Axi_raw_h_ref = raw_h_ref(:, 2:4) * 9.81; % m/s^2
W_raw_h_ref   = raw_h_ref(:, 5:7) * (pi / 180); % rad/s
t_h_raw_ref   = raw_h_ref(:, 1);

t_static = 2.0; % s
n_static_h = sum(t_h_raw_ref - t_h_raw_ref(1) <= t_static);
if n_static_h < 10, n_static_h = 10; end

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

% Tinh A_aligned_h
Axi_aligned_h = Axi_raw_h_ref * R_PCA_h_GLOBAL;
g_body_raw = mean(Axi_raw_h_ref(1:n_static_h, :));
g_body_aligned = g_body_raw * R_PCA_h_GLOBAL;
Axi_aligned_h = Axi_aligned_h - g_body_aligned;

fprintf('First 5 lines of Axi_aligned_h:\n');
disp(Axi_aligned_h(1:5, :));
