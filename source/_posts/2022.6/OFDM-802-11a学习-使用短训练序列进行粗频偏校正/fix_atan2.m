function [angle] = fix_atan2(y,x)
% angle = atan2(y,x);
%https://blog.csdn.net/weixin_43404836/article/details/117996385
%http://nghiaho.com/?p=997
pi4 =  fix(2^16*pi/4);
pi1 =  fix(pi*2^16);
fx=((y/x)*2^16);

% M_PI_4*x - x*(fabs(x) - 1)*(0.2447 + 0.0663*fabs(x))
if x==0 && y==0
    angle =0;
else
    if x >0
       angle= pi4*fx - fx*(abs(fx) - 2^16)*(fix(0.2447*2^16) + fix(0.0663*abs(fx)))/2^16;
    elseif x<0 && y>=0
        angle= pi1*2^16 + pi4*fx - fx*(abs(fx) - 2^16)*(fix(0.2447*2^16) + fix(0.0663*abs(fx)))/2^16;
    elseif x<0 && y<0
        angle= -pi1*2^16 + pi4*fx - fx*(abs(fx) - 2^16)*(fix(0.2447*2^16) + fix(0.0663*abs(fx)))/2^16;
    elseif x ==0 && y>0
        angle = pi1*2^16*0.5;
    elseif x ==0 && y<0
        angle = -pi1*2^16*0.5;
    end
end
angle = angle/2^32;
end