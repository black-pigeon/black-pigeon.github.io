clc;
clear all;
close all;

load("RxIQ.mat");

rx_sample = double(RxSave);

% ofdm channel data
mod_ofdm_syms = [1 1 -1 -1 1 1 -1 1 -1 1 1 1 1 1 1 -1 -1 1 1 -1 1 -1 1 1 1 1 ...
      1 -1 -1 1 1 -1 1 -1 1 -1 -1 -1 -1 -1 1 1 -1 -1 1 -1 1 -1 1 1 1 1];

ofdm_chn_data = zeros(64, 1);
% mapping data into ifft, the negative channel maps into 33:64 (64)
% the positive channel maps into 1~32(1:27)
ofdm_chn_data([7:32 34:59], :) = reshape(mod_ofdm_syms, 52, 1);
ofdm_chn_data([33:64 1:32], :) = ofdm_chn_data;

% ifft generate real world data
ifft_dout = ifft(ofdm_chn_data);

ifft_sample = ifft_dout(:).';
ifft_sample = ifft_sample.';
lts_lut = [ifft_sample(33:64); ifft_sample(1:32)]; 

re1 = real(lts_lut);
im1 = imag(lts_lut);
re1 = round(re1 .* 2^12);
im1 = round(im1 .* 2^12);
sign_re1 = (re1<0);
sign_im1 = (im1<0);
re1 = re1 + sign_re1.*2^16;
im1 = im1 + sign_im1.*2^16;

fid = fopen('p1_real.txt','w');
fprintf(fid,'%d, ',re1);%GI2
fclose(fid);

fid = fopen('p1_imag.txt','w');
fprintf(fid,'%d, ',im1);%GI2
fclose(fid);

for i=1:1500;
    lts_corr(i) = abs(sum((rx_sample(i:i+63)).*conj(lts_lut)));
end

plot(lts_corr);
hold on;
plot(real(rx_sample(1:1500)));

figure(2)
plot(real(ifft_sample))


