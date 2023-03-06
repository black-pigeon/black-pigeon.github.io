%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% coarse frequency correction
% α_st = sum(s[m].*conj(s[m+16]))
% α_st = 2*pi*16*fc/Fs
% fc = α_st*Fs/(2*pi*16)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
clc;
clear all;
close all;

load('RxIQ.mat');
rx_sample = double(RxSave);
Fs = 20e6;
freq_offset = -16e3;    % freq offset of rx 120K

% the length of the input sequence
time_squence = [0:length(rx_sample)-1].';

% radian per samples
radian_per_sample = (2*pi*freq_offset/Fs); % 2*pi*f*T

% freq offset data
freq_offset_data = exp(1i*(time_squence*radian_per_sample)); %exp(jwt)

% data with freq offset
rx_sample = rx_sample.*freq_offset_data; % add freq offset to original data

% long training sequence
mod_ofdm_syms = [1 1 -1 -1 1 1 -1 1 -1 1 1 1 1 1 1 -1 -1 1 1 -1 1 -1 1 1 1 1 ...
      1 -1 -1 1 1 -1 1 -1 1 -1 -1 -1 -1 -1 1 1 -1 -1 1 -1 1 -1 1 1 1 1];

syms_into_ifft = zeros(64,1);

% mapping the LTS into the ifft channel, channel 33 is DC, channle 7:32 is -26~-1, channel 34:59 is channel 1~26
syms_into_ifft([7:32 34:59],:)=reshape(mod_ofdm_syms,52,1);

% the negative freq will put into the tail when ifft
syms_into_ifft([33:64 1:32],:) = syms_into_ifft;

% ifft modulation
ifft_out = ifft(syms_into_ifft);
time_syms = zeros(1,64);
time_syms = ifft_out(:).';
% get the long training sequence
long_training_sequence=(time_syms.*2048).';
% change the long training sequence for packet detect, the GI+1/2LTS for detect packet
long_training_sequence=[long_training_sequence(end/2+1:end);long_training_sequence(1:end/2)];

corr = zeros(1,1000);
est_angle = zeros(1,1000);
for i=1:1000
    if(sum(abs(rx_sample(i:i+15).^2)) == 0)
        corr(i) = 0;
        est_angle(i)=0;
    else
        % est_angle(i) = sum(conj(rx_sample(i:i+15)).*rx_sample(i+16:i+16+15));     % for the purpose of using angle
        est_angle(i) = sum(conj(rx_sample(i:i+15)).*rx_sample(i+16:i+16+15))/16;    % for the purpose of using fix_actan
        corr(i) = (abs(sum(rx_sample(i:i+15).*conj(rx_sample(i+16:i+16+15))))/abs(sum(rx_sample(i:i+15).*conj(rx_sample(i:i+15)))));
    end
end

short_sync_index = find((corr>0.75) & (corr <1.25)==1);
% freq_est=(angle(est_angle(short_sync_index(100)))/(2*pi*16))*Fs;
% display(freq_est);
% est_freq_data = exp(-1i*(time_squence*(2*pi*freq_est/Fs)));

freq_est=(fix_atan2(imag(est_angle(short_sync_index(100))),real(est_angle(short_sync_index(100))))/(2*pi*16))*Fs;
Q = imag(est_angle(short_sync_index(100)));
I = real(est_angle(short_sync_index(100)));
fix_angle = fix_atan2(Q,I);
display(Q);
display(I);
display(fix_angle);

n=0:2047;
s_rom = sin(2*pi*n/2048);
c_rom = cos(2*pi*n/2048);
freq_ctrl_word = fix(((freq_est/Fs)*2^32));
display(freq_ctrl_word);

phase_acc = 0;
for i=1:length(rx_sample)
    phase_acc = phase_acc - freq_ctrl_word;
    if phase_acc > 2^32
        phase_acc = phase_acc - 2^32;
    elseif phase_acc < 0
        phase_acc = phase_acc + 2^32;
    end
    rom_addr = bitshift(uint32(phase_acc),-21)+1;
    est_freq_data(i,1) = complex(c_rom(rom_addr), s_rom(rom_addr));
end

rx_correct_sample = rx_sample .* est_freq_data;

% get the sign of the input samples, sign bit 0 maps to 1, sign bit 1 maps to -1
no_r= (real(rx_correct_sample)<0)*(-2)+1;
no_i= (imag(rx_correct_sample)<0)*(-2)+1;
rx_norms=complex(no_r,no_i);

for i=1:1000
    rx_cross_sum = sum(rx_norms(i:i+64-1).*conj(long_training_sequence));
    rx_cross_corr(i)= abs(rx_cross_sum)
end

index=find(rx_cross_corr>1.1e4);
if length(index)>=2
    if length(index)==2 && (index(2)-index(1))>=62 && (index(2)-index(1))<=65
        thres_index=index(2)+64+32;
    end
end
figure(1)
plot(rx_cross_corr(1:thres_index),'r');
hold on;
plot(real(rx_correct_sample(1:thres_index))*10,'b');


figure(2)
plot(corr);
hold on;
plot(real(rx_sample(1:1000))/(max(real(rx_sample(1:1000)))*0.5));
figure(3)
plot(real(rx_sample(1:1000)));
hold on;
plot(real(rx_correct_sample(1:1000)),'r','linewidth',0.8);
hold on;
plot(real(RxSave(1:1000)),'--g','linewidth',0.6);
