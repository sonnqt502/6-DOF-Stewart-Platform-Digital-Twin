function B = tinhvitriB(rb,beta1,d_b)
    B = zeros(3,6);
    beta = zeros(1,6);
   for k = 0:2
        % Cặp khớp ở Bàn máy (B) - Chú ý (k+1)*120 để đảm bảo đúng thiết kế
        beta(2*k + 1) = -(beta1 + k * 120); 
        beta(2*k + 2) = -(beta1 + d_b + k * 120); 
   end
   for i = 1:6
        B(1,i)=rb*cosd(beta(i));
        B(2,i) = rb * sind(beta(i));
        B(3,i) = 0;
    end
end