% run_simulink.m
clear; clc;

[script_path, ~, ~] = fileparts(mfilename('fullpath'));
mat_file = fullfile(script_path, 'simulink_data.mat');

if ~isfile(mat_file)
    error('Không tìm thấy file simulink_data.mat');
end

% Load dữ liệu quỹ đạo + tham số hình học
load(mat_file, ...
     't', 'xp', 'yp', 'zp', 'rp', 'pp', 'ywp', 'T_stop', ...
     'A_mat', 'B_mat', 'gamma_ang', 'L1', 'L2');

% Gán vào base workspace
assignin('base', 'X_ref',    timeseries(xp, t));
assignin('base', 'Y_ref',    timeseries(yp, t));
assignin('base', 'Z_ref',    timeseries(zp, t));
assignin('base', 'roll_ref',  timeseries(rp, t));
assignin('base', 'pitch_ref', timeseries(pp, t));
assignin('base', 'yaw_ref',   timeseries(ywp, t));
assignin('base', 'T_stop',   T_stop);

assignin('base', 'A_mat',     A_mat);
assignin('base', 'B_mat',     B_mat);
assignin('base', 'gamma_ang', gamma_ang);
assignin('base', 'L1',        L1);
assignin('base', 'L2',        L2);

% Mở và chạy mô hình
mdl = 'Final_CKASForSIM30_11_SIM';
if ~bdIsLoaded(mdl)
    open_system(mdl);
end
set_param(mdl, 'StopTime', num2str(T_stop));
sim(mdl);

%quit force;