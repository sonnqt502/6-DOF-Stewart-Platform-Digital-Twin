function [A, alpha] = tinhvitriA(ra, alpha1, d_a) % Thay đổi ở đây
    A = zeros(3,6);
    alpha = zeros(1,6);
    
    for k = 0:2
        alpha(2*k + 1) = -(alpha1 + k * 120); 
        alpha(2*k + 2) = -(alpha1 - d_a + (k+1) * 120);
    end
    
    disp('Giá trị của alpha là:');
    disp(alpha); % Vẫn giữ nguyên lệnh in ra màn hình
    
    for i = 1:6
        A(1,i) = ra * cosd(alpha(i));
        A(2,i) = ra * sind(alpha(i));
        A(3,i) = -593.4;
    end
end