clear all;
clc;
mod_ofdm_syms =  sqrt(13/6)*[0 0 1+j 0 0 0 -1-j 0 0 0 1+j 0 0 0 -1-j 0 0 0 -1-j 0 0 0 1+j 0 0 0 0 0 0 -1-j 0 0 0 -1-j 0 0 0 ...
      1+j 0 0 0 1+j 0 0 0 1+j 0 0 0 1+j 0 0];
%mod_ofdm_syms=1:52;
NumSubc = 52;
up=2;
int16 re;
int16 im;
int16 re1;
int16 im1;

syms_into_ifft = zeros(64,1);
syms_into_ifft([7:32 34:59],:)=reshape(mod_ofdm_syms,NumSubc,1);
syms_into_ifft([33:64 1:32],:) = syms_into_ifft;
% up sample
syms_into_ifft_up = zeros(64*up,1);
syms_into_ifft_up(1:32,:) = syms_into_ifft(1:32,:);
syms_into_ifft_up(end-31:end,:) = syms_into_ifft(33:64,:);
%freq convert to time domain
ifft_out = ifft(syms_into_ifft_up);
time_syms = zeros(1,64*up);
time_syms = ifft_out(:).';
re = real(time_syms);
im = imag(time_syms);
re = round(re * 2^15);
im = round(im * 2^15);
sign_re = (re<0);
sign_im = (im<0);
re = re + sign_re*2^16;
im = im + sign_im*2^16;

mod_ofdm_syms = [1 1 -1 -1 1 1 -1 1 -1 1 1 1 1 1 1 -1 -1 1 1 -1 1 -1 1 1 1 1 ...
      1 -1 -1 1 1 -1 1 -1 1 -1 -1 -1 -1 -1 1 1 -1 -1 1 -1 1 -1 1 1 1 1];

syms_into_ifft = zeros(64,1);
syms_into_ifft([7:32 34:59],:)=reshape(mod_ofdm_syms,NumSubc,1);
syms_into_ifft([33:64 1:32],:) = syms_into_ifft;
% up sample
syms_into_ifft_up = zeros(64*up,1);
syms_into_ifft_up(1:32,:) = syms_into_ifft(1:32,:);
syms_into_ifft_up(end-31:end,:) = syms_into_ifft(33:64,:);
%freq convert to time domain
ifft_out = ifft(syms_into_ifft_up);
time_syms = zeros(1,64*up);
time_syms = ifft_out(:).';
re1 = real(time_syms);
im1 = imag(time_syms);
re1 = round(re1 * 2^15);
im1 = round(im1 * 2^15);
sign_re1 = (re1<0);
sign_im1 = (im1<0);
re1 = re1 + sign_re1*2^16;
im1 = im1 + sign_im1*2^16;

fid = fopen('preamble_real.coe','w');
fprintf(fid,'memory_initialization_radix = 10;\n');
fprintf(fid,'memory_initialization_vector = \n');
for i=1:10
    fprintf(fid,'%d,\n',re(1:16*up)); %St1~t10
end
fprintf(fid,'%d,\n',re1(65:128));%GI2
fprintf(fid,'%d,\n',re1(1:128)); %L T1
fprintf(fid,'%d,\n',re1(1:127)); %L T2
fprintf(fid,'%d;\n',re1(end));
fclose(fid);

fid = fopen('preamble_imag.coe','w');
fprintf(fid,'memory_initialization_radix = 10;\n');
fprintf(fid,'memory_initialization_vector = \n');
for i=1:10
    fprintf(fid,'%d,\n',im(1:16*up)); %St1~t10
end
fprintf(fid,'%d,\n',im1(65:128));%GI2
fprintf(fid,'%d,\n',im1(1:128)); %L T1
fprintf(fid,'%d,\n',im1(1:127)); %L T2
fprintf(fid,'%d;\n',im1(end));
fclose(fid);
