function data_trimmed = apply_trim(data_raw, trim_start_sec, trim_end_sec)
% Cắt dữ liệu 2 đầu theo giây để loại bỏ nhiễu khởi động/kết thúc
    if isempty(data_raw)
        error('Dữ liệu đầu vào trống!');
    end
    t = data_raw(:, 1);
    t_start_target = t(1) + trim_start_sec;
    t_end_target   = t(end) - trim_end_sec;
    if t_start_target >= t_end_target
        error('Lỗi Trim: Thời gian cắt quá lớn khiến dữ liệu bị xóa sạch!');
    end
    mask = (t >= t_start_target) & (t <= t_end_target);
    data_trimmed = data_raw(mask, :);
end
