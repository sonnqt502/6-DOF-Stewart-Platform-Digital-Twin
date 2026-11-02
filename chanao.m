function [l, L] = chanao(x, y, z, A, B, R)
    l = zeros(1,6);
    L = zeros(3,6);
    P = [x; y; z];
    for i = 1:6
        L(:,i) = P + R * B(:,i) - A(:,i);  
        l(i) = norm(L(:,i));  
    end
end