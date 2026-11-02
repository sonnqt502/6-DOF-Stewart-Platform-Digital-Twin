function g=tinhgamma(alpha1,d_a)
alpha=zeros(1,6);
for k = 0:2
            alpha(2*k + 1) = alpha1 + k * 120; alpha(2*k + 2) = alpha1 + d_a + k * 120;
end
g=zeros(1,6);
for i=1:6
 g(i)=alpha(i)+((-1)^(i-1))*90;
end