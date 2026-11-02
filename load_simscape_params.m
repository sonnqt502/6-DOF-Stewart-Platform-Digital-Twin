function [m_platform, I_platform, m_arm, I_arm] = load_simscape_params(dataFile)
% LOAD_SIMSCAPE_PARAMS  Trích xuất tự động khối lượng M và quán tính I từ Simscape DataFile
%
% Usage:
%   [m_p, I_p, m_arm, I_arm] = load_simscape_params()
%   [m_p, I_p, m_arm, I_arm] = load_simscape_params('Final_CKASForSIM30_11_SIM_DataFile.m')

    if nargin < 1 || isempty(dataFile)
        dataFile = 'Final_CKASForSIM30_11_SIM_DataFile';
    end

    % 1. Xóa phần mở rộng file nếu có
    [~, nameOnly, ~] = fileparts(dataFile);

    % 2. Thực thi script DataFile để nạp struct smiData
    evalin('base', [nameOnly ';']);
    smiData = evalin('base', 'smiData');

    % 3. Tìm các Solid trong smiData dựa theo ID
    m_platform = 30.0;
    I_platform = [9.85, 19.65, 9.85];
    m_arm = 1.585;
    I_arm = 0.05;

    for i = 1:length(smiData.Solid)
        solidID = char(smiData.Solid(i).ID);
        
        % Bệ động P-CKAS-001
        if contains(solidID, 'P-CKAS-001')
            m_platform = smiData.Solid(i).mass;
            % Đổi từ kg.mm^2 sang kg.m^2 (chia 1e6)
            I_platform = smiData.Solid(i).MoI / 1e6;
        end

        % Tay ngắn P-CKAS-002
        if contains(solidID, 'P-CKAS-002')
            m_arm = smiData.Solid(i).mass;
            MoI_arm = smiData.Solid(i).MoI / 1e6;
            I_arm = max(MoI_arm); % Lấy momen quán tính lớn nhất của tay ngắn
        end
    end

    fprintf('======================================================\n');
    fprintf('   TRÍCH XUẤT THÀNH CÔNG THAM SỐ TỪ SIMSCAPE (smiData)\n');
    fprintf('======================================================\n');
    fprintf('  - Khối lượng Bệ động (m_platform): %.4f kg\n', m_platform);
    fprintf('  - Inertia Bệ động (I_platform)  : [%.4f, %.4f, %.4f] kg.m^2\n', ...
        I_platform(1), I_platform(2), I_platform(3));
    fprintf('  - Khối lượng Tay ngắn (m_arm)   : %.4f kg\n', m_arm);
    fprintf('  - Inertia Tay ngắn (I_arm)      : %.4f kg.m^2\n', I_arm);
    fprintf('======================================================\n');
end
