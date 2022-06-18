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

corr = zeros(1,1000);
est_angle = zeros(1,1000);
for i=1:1000
    if(sum(abs(rx_sample(i:i+15).^2)) == 0)
        corr(i) = 0;
        est_angle(i)=0;
    else
        est_angle(i) = sum(conj(rx_sample(i:i+15)).*rx_sample(i+16:i+16+15));     % for the purpose of using angle
        % est_angle(i) = sum(conj(rx_sample(i:i+15)).*rx_sample(i+16:i+16+15));       % for the purpose of using fix_actan
        corr(i) = (abs(sum(rx_sample(i:i+15).*conj(rx_sample(i+16:i+16+15))))/abs(sum(rx_sample(i:i+15).*conj(rx_sample(i:i+15)))));
    end
end

short_sync_index = find((corr>0.75) & (corr <1.25)==1);
freq_est=(angle(est_angle(short_sync_index(100)))/(2*pi*16))*Fs;
display(freq_est);
est_freq_data = exp(-1i*(time_squence*(2*pi*freq_est/Fs)));

% freq_est=(fix_atan2(imag(est_angle(short_sync_index(100))),real(est_angle(short_sync_index(100))))/(2*pi*16))*Fs;
% Q = imag(est_angle(short_sync_index(100)));
% I = real(est_angle(short_sync_index(100)));
% fix_angle = fix_atan2(Q,I);
% display(Q);
% display(I);
% display(fix_angle);

% n=0:2047;
% s_rom = sin(2*pi*n/2048);
% c_rom = cos(2*pi*n/2048);
% freq_ctrl_word = fix(((freq_est/Fs)*2^32));
% display(freq_ctrl_word);

% phase_acc = 0;
% for i=1:length(rx_sample)
%     phase_acc = phase_acc - freq_ctrl_word;
%     if phase_acc > 2^32
%         phase_acc = phase_acc - 2^32;
%     elseif phase_acc < 0
%         phase_acc = phase_acc + 2^32;
%     end
%     rom_addr = bitshift(uint32(phase_acc),-21)+1;
%     est_freq_data(i,1) = complex(c_rom(rom_addr), s_rom(rom_addr));
% end

rx_correct_sample = rx_sample .* est_freq_data;

figure(1)
plot(corr);
hold on;
plot(real(rx_sample(1:1000))/(max(real(rx_sample(1:1000)))*0.5));
figure(2)
plot(real(rx_sample(1:1000)));
hold on;
plot(real(rx_correct_sample(1:1000)),'r','linewidth',0.8);
hold on;
plot(real(RxSave(1:1000)),'--g','linewidth',0.6);
title("blue: data with freq offset, red: data with coarse cfo, green original data without freq offset")
