% -----------------------------------------------------------------------
% Thesis
%
% Contact: Behnam Sherafat @ < behnam.sherafat@utah.edu>
% -----------------------------------------------------------------------
%% Initializing
tic
clear;
close all;
clc;

%% Defining STFT Parameters
overlap = 256;
window_size = 2*overlap;
FFTSIZE = 48;
PCA_f = 0.9;
cross_fold = 10;
delay = 0.4748; % how much audio is prior to vibration
train_test_ratio = 0.9;

%% Reading Sensor Data

load test2.mat

fsAccel = length(timestampAccel)/timestampAccel(length(timestampAccel));
fsAng = length(timestampAng)/timestampAng(length(timestampAng));

%% Removing Sensor Data outliers

% Removing G from Accelerometer Data
% Read Only Acceleration Sensor Data
X = Ax;
Y = Ay;
Z = Az;

t = timestampAccel;

kFilteringFactor = 0.1;
g1 = 0;
g2 = 0;
g3 = 0;
Bx = zeros(size(X, 1), 1);
By = zeros(size(Y, 1), 1);
Bz = zeros(size(Z, 1), 1);

for i = 1:size(X, 1)
    
    g1 = (X(i, 1) * kFilteringFactor) + (g1 * (1.0 - kFilteringFactor));
    g2 = (Y(i, 1) * kFilteringFactor) + (g2 * (1.0 - kFilteringFactor));
    g3 = (Z(i, 1) * kFilteringFactor) + (g3 * (1.0 - kFilteringFactor));

    Bx(i, 1) = X(i, 1) - g1;
    By(i, 1) = Y(i, 1) - g2;
    Bz(i, 1) = Z(i, 1) - g3;
end

[Refined_Ax,~,~,~,~] = filloutliers(Bx,'clip','movmedian', 3,'SamplePoints',t);
[Refined_Ay,~,~,~,~] = filloutliers(By,'clip','movmedian', 3,'SamplePoints',t);
[Refined_Az,~,~,~,~] = filloutliers(Bz,'clip','movmedian', 3,'SamplePoints',t);

Refilled_Ax = fillmissing(Refined_Ax,'movmedian',24); 
Refilled_Ay = fillmissing(Refined_Ay,'movmedian',24); 
Refilled_Az = fillmissing(Refined_Az,'movmedian',24); 

MagAccel = sqrt(sum(Refilled_Ax.^2 + Refilled_Ay.^2 + Refilled_Az.^2, 2));
MagAccel = MagAccel - mean(MagAccel);
Mag_A = MagAccel/max(MagAccel);

S_Ax = Refilled_Ax;
S_Ay = Refilled_Ay;
S_Az = Refilled_Az;

% Read other Sensor Data
S_Vx = Vx;
S_Vy = Vy;
S_Vz = Vz;

%% Reading Audio Data

[A_ori, fsA] = audioread('ZOOM0033.wav');

%% Audio Denoising: method = 'mcra2'; 

A_ori(A_ori==0)=10^-4;
A_ori = A_ori(:, 1);
audiowrite('ZOOM0033_ori.wav', A_ori, fsA);

% Audio Denoising: method = 'mcra2'; 
% specsub_ns('ZOOM0033_ori.wav', 'mcra2', 'ZOOM0033_den.wav')

% Read Modified Audio
[S_Audio, fsA] = audioread('ZOOM0033_den.wav');

%% Mutual Time Stamp and Sycnhronization
start_Audio = round(delay*fsA);
S_Audio = S_Audio(start_Audio:end);
start_Audio = 0;
T_A = size(S_Audio, 1)/fsA;
% 
T_Accel = size(S_Ax, 1)/fsAccel;
T_Ang = size(S_Vx, 1)/fsAng;

%% Resampling Vibration Signals

T1 = [T_Accel T_Ang T_A, 120];
T = floor(min(T1)); % in seconds

S_Ax = S_Ax(1:floor(T*fsAccel)+1);
S_Ay = S_Ay(1:floor(T*fsAccel)+1);
S_Az = S_Az(1:floor(T*fsAccel)+1);

S_Vx = S_Vx(1:floor(T*fsAng)+1);
S_Vy = S_Vy(1:floor(T*fsAng)+1);
S_Vz = S_Vz(1:floor(T*fsAng)+1);

S_Audio = S_Audio(1:floor(T*fsA)+1);

xA = linspace(0, T, size(S_Ax,1));
xV = linspace(0, T, size(S_Vx,1));
xq = 0:1/fsA:T;

S_Ax = (interp1(xA, S_Ax, xq, 'linear'))';
S_Ay = (interp1(xA, S_Ay, xq, 'linear'))';
S_Az = (interp1(xA, S_Az, xq, 'linear'))';

S_Vx = (interp1(xV, S_Vx, xq, 'linear'))';
S_Vy = (interp1(xV, S_Vy, xq, 'linear'))';
S_Vz = (interp1(xV, S_Vz, xq, 'linear'))';

fs = fsA;

%% Normalization of Signals

% S_Audio = bsxfun(@rdivide,bsxfun(@minus,S_Audio,mean(S_Audio)),std(S_Audio));
% 
% S_Ax = bsxfun(@rdivide,bsxfun(@minus,S_Ax,mean(S_Ax)),std(S_Ax));
% 
% S_Ay = bsxfun(@rdivide,bsxfun(@minus,S_Ay,mean(S_Ay)),std(S_Ay));
% 
% S_Az = bsxfun(@rdivide,bsxfun(@minus,S_Az,mean(S_Az)),std(S_Az));
% 
% S_Vx = bsxfun(@rdivide,bsxfun(@minus,S_Vx,mean(S_Vx)),std(S_Vx));
% 
% S_Vy = bsxfun(@rdivide,bsxfun(@minus,S_Vy,mean(S_Vy)),std(S_Vy));
% 
% S_Vz = bsxfun(@rdivide,bsxfun(@minus,S_Vz,mean(S_Vz)),std(S_Vz));

%% Building Vibration and Audio Data Set

% ============================== Training Ax ============================== %
[V_Spec1, V_SpecM, V_RMS, V_E, V_ZCR, V_SF, V_SpecEntropy, V_SC, V_SRO] = FunctionExtractionV(S_Ax, 0, T, fs, FFTSIZE, overlap, window_size);
F_Ax = [V_Spec1, V_RMS, V_E, V_ZCR, V_SF, V_SpecEntropy, V_SC, V_SRO];

% ============================== Training Ay ============================== %
[V_Spec2, V_SpecM, V_RMS, V_E, V_ZCR, V_SF, V_SpecEntropy, V_SC, V_SRO] = FunctionExtractionV(S_Ay, 0, T, fs, FFTSIZE, overlap, window_size);
F_Ay = [V_Spec2, V_RMS, V_E, V_ZCR, V_SF, V_SpecEntropy, V_SC, V_SRO];

% ============================== Training Az ============================== %
[V_Spec3, V_SpecM, V_RMS, V_E, V_ZCR, V_SF, V_SpecEntropy, V_SC, V_SRO] = FunctionExtractionV(S_Az, 0, T, fs, FFTSIZE, overlap, window_size);
F_Az = [V_Spec3, V_RMS, V_E, V_ZCR, V_SF, V_SpecEntropy, V_SC, V_SRO];

% ============================== Training Vx ============================== %
[V_Spec4, V_SpecM, V_RMS, V_E, V_ZCR, V_SF, V_SpecEntropy, V_SC, V_SRO] = FunctionExtractionV(S_Vx, 0, T, fs, FFTSIZE, overlap, window_size);
F_Vx = [V_Spec4, V_RMS, V_E, V_ZCR, V_SF, V_SpecEntropy, V_SC, V_SRO];

% ============================== Training Vy ============================== %
[V_Spec5, V_SpecM, V_RMS, V_E, V_ZCR, V_SF, V_SpecEntropy, V_SC, V_SRO] = FunctionExtractionV(S_Vy, 0, T, fs, FFTSIZE, overlap, window_size);
F_Vy = [V_Spec5, V_RMS, V_E, V_ZCR, V_SF, V_SpecEntropy, V_SC, V_SRO];

% ============================== Training Vz ============================== %
[V_Spec6, V_SpecM, V_RMS, V_E, V_ZCR, V_SF, V_SpecEntropy, V_SC, V_SRO] = FunctionExtractionV(S_Vz, 0, T, fs, FFTSIZE, overlap, window_size);
F_Vz = [V_Spec6, V_RMS, V_E, V_ZCR, V_SF, V_SpecEntropy, V_SC, V_SRO];

% ============================== Training Audio ============================== %
[A_Spec, A_SpecM, A_RMS, A_E, A_SF, A_SpecEntropy, A_SC, A_SRO] = FunctionExtractionA(S_Audio, 0, T, fs, FFTSIZE, overlap, window_size);
F_A = [A_Spec, A_RMS, A_E, A_SF, A_SpecEntropy, A_SC, A_SRO];

% ==================================================================== %

Data = [abs(F_Ax) abs(F_Ay) abs(F_Az) abs(F_Vx) abs(F_Vy) abs(F_Vz) abs(F_A)]; % concatenate all STFT matrix
Data = bsxfun(@rdivide,bsxfun(@minus,Data,mean(Data)),std(Data));

%% Defining Classes

short_stop = 1;
rotating_arm = 1;
lowering_scraper = 1;
extending_arm = 1;
raising_arm = 1;
moving_drill = 1;
moving_backward = 1;
drilling = 2;

% Adding Labels to Training Data Set

% Add Actual Labels

label_act = zeros(size(Data, 1), 1);
lps = length(label_act)/T; % length per second 

s1 = ceil((0)*lps+1); 
f1 = ceil((1-delay)*lps);
s2 = ceil((1-delay)*lps+1);
f2 = ceil((8-delay)*lps);
s3 = ceil((8-delay)*lps+1);
f3 = ceil((12-delay)*lps);
s4 = ceil((12-delay)*lps+1);
f4 = ceil((17-delay)*lps);
s5 = ceil((17-delay)*lps+1);
f5 = ceil((20-delay)*lps);
s6 = ceil((20-delay)*lps+1);
f6 = ceil((27-delay)*lps);
s7 = ceil((27-delay)*lps+1);
f7 = ceil((30-delay)*lps);
s8 = ceil((30-delay)*lps+1);
f8 = ceil((36-delay)*lps);
s9 = ceil((36-delay)*lps+1);
f9 = ceil((37-delay)*lps);
s10 = ceil((37-delay)*lps+1);
f10 = ceil((38-delay)*lps);
s11 = ceil((38-delay)*lps+1);
f11 = ceil((44-delay)*lps);
s12 = ceil((44-delay)*lps+1);
f12 = ceil((49-delay)*lps);
s13 = ceil((49-delay)*lps+1);
f13 = ceil((50-delay)*lps);
s14 = ceil((50-delay)*lps+1);
f14 = ceil((52-delay)*lps);
s15 = ceil((52-delay)*lps+1);
f15 = ceil((59-delay)*lps);
s16 = ceil((59-delay)*lps+1);
f16 = ceil((62-delay)*lps);
s17 = ceil((62-delay)*lps+1);
f17 = ceil((67-delay)*lps);
s18 = ceil((67-delay)*lps+1);
f18 = ceil((69-delay)*lps);
s19 = ceil((69-delay)*lps+1);
f19 = ceil((77-delay)*lps);
s20 = ceil((77-delay)*lps+1);
f20 = ceil((80-delay)*lps);
s21 = ceil((80-delay)*lps+1);
f21 = ceil((87-delay)*lps);
s22 = ceil((87-delay)*lps+1);
f22 = ceil((90-delay)*lps);
s23 = ceil((90-delay)*lps+1);
f23 = ceil((97-delay)*lps);
s24 = ceil((97-delay)*lps+1);
f24 = ceil((99-delay)*lps);
s25 = ceil((99-delay)*lps+1);
f25 = ceil((107-delay)*lps);
s26 = ceil((107-delay)*lps+1);
f26 = ceil((109-delay)*lps);
s27 = ceil((109-delay)*lps+1);
f27 = ceil((114-delay)*lps);
s28 = ceil((114-delay)*lps+1);
f28 = ceil((116-delay)*lps);
s29 = ceil((116-delay)*lps+1);
f29 = ceil((T)*lps);

label_act(s1:f1) = 1;
label_act(s2:f2) = 2;
label_act(s3:f3) = 3;
label_act(s4:f4) = 2;
label_act(s5:f5) = 3;
label_act(s6:f6) = 2;
label_act(s7:f7) = 3;
label_act(s8:f8) = 4;
label_act(s9:f9) = 3;
label_act(s10:f10) = 1;
label_act(s11:f11) = 3;
label_act(s12:f12) = 2;
label_act(s13:f13) = 1;
label_act(s14:f14) = 3;
label_act(s15:f15) = 2;
label_act(s16:f16) = 3;
label_act(s17:f17) = 2;
label_act(s18:f18) = 3;
label_act(s19:f19) = 2;
label_act(s20:f20) = 3;
label_act(s21:f21) = 2;
label_act(s22:f22) = 3;
label_act(s23:f23) = 2;
label_act(s24:f24) = 3;
label_act(s25:f25) = 2;
label_act(s26:f26) = 3;
label_act(s27:f27) = 2;
label_act(s28:f28) = 3;
label_act(s29:f29) = 2;

% Categorizing Data
Activity_1 = [Data(s1:f1,:);Data(s10:f10,:);Data(s13:f13,:)];
Activity_2 = [Data(s2:f2,:);Data(s4:f4,:);Data(s6:f6,:);Data(s12:f12,:);Data(s15:f15,:);Data(s17:f17,:);Data(s19:f19,:);Data(s21:f21,:);Data(s23:f23,:);Data(s25:f25,:);Data(s27:f27,:);Data(s29:f29,:)];
Activity_3 = [Data(s3:f3,:);Data(s5:f5,:);Data(s7:f7,:);Data(s9:f9,:);Data(s11:f11,:);Data(s14:f14,:);Data(s16:f16,:);Data(s18:f18,:);Data(s20:f20,:);Data(s22:f22,:);Data(s24:f24,:);Data(s26:f26,:);Data(s28:f28,:)];
Activity_4 = Data(s8:f8,:);

Activity_1 = [ones(size(Activity_1,1), 1), Activity_1];
Activity_2 = [2*ones(size(Activity_2,1), 1), Activity_2];
Activity_3 = [3*ones(size(Activity_3,1), 1), Activity_3];
Activity_4 = [4*ones(size(Activity_4,1), 1), Activity_4];

Activity_1 = Activity_1(randperm(size(Activity_1,1)),:);
Activity_2 = Activity_2(randperm(size(Activity_2,1)),:);
Activity_3 = Activity_3(randperm(size(Activity_3,1)),:);
Activity_4 = Activity_4(randperm(size(Activity_4,1)),:);

training_data_1 = Activity_1(1:ceil(size(Activity_1,1)*train_test_ratio),:);
training_data_2 = Activity_2(1:ceil(size(Activity_2,1)*train_test_ratio),:);
training_data_3 = Activity_3(1:ceil(size(Activity_3,1)*train_test_ratio),:);
training_data_4 = Activity_4(1:ceil(size(Activity_4,1)*train_test_ratio),:);

training_data = [training_data_1;training_data_2;training_data_3;training_data_4];

testing_data_1 = Activity_1(ceil(size(Activity_1,1)*train_test_ratio)+1:end,:);
testing_data_2 = Activity_2(ceil(size(Activity_2,1)*train_test_ratio)+1:end,:);
testing_data_3 = Activity_3(ceil(size(Activity_3,1)*train_test_ratio)+1:end,:);
testing_data_4 = Activity_4(ceil(size(Activity_4,1)*train_test_ratio)+1:end,:);

testing_data = [testing_data_1;testing_data_2;testing_data_3;testing_data_4];

%% Plotting Data

x = 1:length(label_act);

figure(1);
subplot(2,1,1)
plot(S_Ax)
xt1 = get(gca, 'XTick');                                 % 'XTick' Values
set(gca,'YDir','normal');
set(gca, 'XTick', xt1, 'XTickLabel', round(xt1/fs))
title('CAT 259D Ax Signal','FontSize',20,'FontWeight','bold');
y = ylabel('Amplitude','FontSize',18,'FontWeight','bold');
xlabel('Time (s)','FontSize',10,'FontWeight','bold');
set(y, 'Units', 'Normalized', 'Position', [-0.1, 0.5, 0]);
set(get(gca,'ylabel'),'rotation',0)
axis tight
subplot(2,1,2)
imagesc(db(V_Spec1')); colormap('jet'); set(gca,'YDir','normal'); c = get(gca,'Clim');
set(gca, 'XTickLabelMode', 'manual', 'XTickLabel', []);
set(gca, 'YTickLabelMode', 'manual', 'YTickLabel', []);
title('CAT 259D Ax Signal Spectrogram',...
    'FontSize', 20, 'FontWeight','bold');
y=ylabel({'Normalized', 'Frequency'}, 'FontSize', 18, 'FontWeight','bold');
set(y, 'Units', 'Normalized', 'Position', [-0.1, 0.5, 0]);
set(get(gca,'ylabel'),'rotation',0)
xlabel('Time (s)', 'FontSize', 10, 'FontWeight','bold');
grid off
axis tight
hold on
stem(x, (FFTSIZE/8).*label_act, 'filled', 'Marker', 'none', 'Color', 'black');
axis tight

figure(2);
subplot(2,1,1)
plot(S_Ay)
xt1 = get(gca, 'XTick');                                 % 'XTick' Values
set(gca,'YDir','normal');
set(gca, 'XTick', xt1, 'XTickLabel', round(xt1/fs))
title('CAT 259D Ay Signal','FontSize',20,'FontWeight','bold');
y = ylabel('Amplitude','FontSize',18,'FontWeight','bold');
xlabel('Time (s)','FontSize',10,'FontWeight','bold');
set(y, 'Units', 'Normalized', 'Position', [-0.1, 0.5, 0]);
set(get(gca,'ylabel'),'rotation',0)
axis tight
subplot(2,1,2)
imagesc(db(V_Spec2')); colormap('jet'); set(gca,'YDir','normal'); c = get(gca,'Clim');
set(gca, 'XTickLabelMode', 'manual', 'XTickLabel', []);
set(gca, 'YTickLabelMode', 'manual', 'YTickLabel', []);
title('CAT 259D Ay Signal Spectrogram',...
    'FontSize', 20, 'FontWeight','bold');
y=ylabel({'Normalized', 'Frequency'}, 'FontSize', 18, 'FontWeight','bold');
set(y, 'Units', 'Normalized', 'Position', [-0.1, 0.5, 0]);
set(get(gca,'ylabel'),'rotation',0)
xlabel('Time (s)', 'FontSize', 10, 'FontWeight','bold');
grid off
axis tight
hold on
stem(x, (FFTSIZE/8).*label_act, 'filled', 'Marker', 'none', 'Color', 'black');
axis tight


figure(3);
subplot(2,1,1)
plot(S_Az)
xt1 = get(gca, 'XTick');                                 % 'XTick' Values
set(gca,'YDir','normal');
set(gca, 'XTick', xt1, 'XTickLabel', round(xt1/fs))
title('CAT 259D Az Signal','FontSize',20,'FontWeight','bold');
y = ylabel('Amplitude','FontSize',18,'FontWeight','bold');
xlabel('Time (s)','FontSize',10,'FontWeight','bold');
set(y, 'Units', 'Normalized', 'Position', [-0.1, 0.5, 0]);
set(get(gca,'ylabel'),'rotation',0)
axis tight
subplot(2,1,2)
imagesc(db(V_Spec3')); colormap('jet'); set(gca,'YDir','normal'); c = get(gca,'Clim');
set(gca, 'XTickLabelMode', 'manual', 'XTickLabel', []);
set(gca, 'YTickLabelMode', 'manual', 'YTickLabel', []);
title('CAT 259D Az Signal Spectrogram',...
    'FontSize', 20, 'FontWeight','bold');
y=ylabel({'Normalized', 'Frequency'}, 'FontSize', 18, 'FontWeight','bold');
set(y, 'Units', 'Normalized', 'Position', [-0.1, 0.5, 0]);
set(get(gca,'ylabel'),'rotation',0)
xlabel('Time (s)', 'FontSize', 10, 'FontWeight','bold');
grid off
axis tight
hold on
stem(x, (FFTSIZE/8).*label_act, 'filled', 'Marker', 'none', 'Color', 'black');
axis tight


figure(4);
subplot(2,1,1)
plot(S_Vx)
xt1 = get(gca, 'XTick');                                 % 'XTick' Values
set(gca,'YDir','normal');
set(gca, 'XTick', xt1, 'XTickLabel', round(xt1/fs))
title('CAT 259D Vx Signal','FontSize',20,'FontWeight','bold');
y = ylabel('Amplitude','FontSize',18,'FontWeight','bold');
xlabel('Time (s)','FontSize',10,'FontWeight','bold');
set(y, 'Units', 'Normalized', 'Position', [-0.1, 0.5, 0]);
set(get(gca,'ylabel'),'rotation',0)
axis tight
subplot(2,1,2)
imagesc(db(V_Spec4')); colormap('jet'); set(gca,'YDir','normal'); c = get(gca,'Clim');
set(gca, 'XTickLabelMode', 'manual', 'XTickLabel', []);
set(gca, 'YTickLabelMode', 'manual', 'YTickLabel', []);
title('CAT 259D Vx Signal Spectrogram',...
    'FontSize', 20, 'FontWeight','bold');
y=ylabel({'Normalized', 'Frequency'}, 'FontSize', 18, 'FontWeight','bold');
set(y, 'Units', 'Normalized', 'Position', [-0.1, 0.5, 0]);
set(get(gca,'ylabel'),'rotation',0)
xlabel('Time (s)', 'FontSize', 10, 'FontWeight','bold');
grid off
axis tight
hold on
stem(x, (FFTSIZE/8).*label_act, 'filled', 'Marker', 'none', 'Color', 'black');
axis tight


figure(5);
subplot(2,1,1)
plot(S_Vy)
xt1 = get(gca, 'XTick');                                 % 'XTick' Values
set(gca,'YDir','normal');
set(gca, 'XTick', xt1, 'XTickLabel', round(xt1/fs))
title('CAT 259D Vy Signal','FontSize',20,'FontWeight','bold');
y = ylabel('Amplitude','FontSize',18,'FontWeight','bold');
xlabel('Time (s)','FontSize',10,'FontWeight','bold');
set(y, 'Units', 'Normalized', 'Position', [-0.1, 0.5, 0]);
set(get(gca,'ylabel'),'rotation',0)
axis tight
subplot(2,1,2)
imagesc(db(V_Spec5')); colormap('jet'); set(gca,'YDir','normal'); c = get(gca,'Clim');
set(gca, 'XTickLabelMode', 'manual', 'XTickLabel', []);
set(gca, 'YTickLabelMode', 'manual', 'YTickLabel', []);
title('CAT 259D Vy Signal Spectrogram',...
    'FontSize', 20, 'FontWeight','bold');
y=ylabel({'Normalized', 'Frequency'}, 'FontSize', 18, 'FontWeight','bold');
set(y, 'Units', 'Normalized', 'Position', [-0.1, 0.5, 0]);
set(get(gca,'ylabel'),'rotation',0)
xlabel('Time (s)', 'FontSize', 10, 'FontWeight','bold');
grid off
axis tight
hold on
stem(x, (FFTSIZE/8).*label_act, 'filled', 'Marker', 'none', 'Color', 'black');
axis tight


figure(6);
subplot(2,1,1)
plot(S_Vz)
xt1 = get(gca, 'XTick');                                 % 'XTick' Values
set(gca,'YDir','normal');
set(gca, 'XTick', xt1, 'XTickLabel', round(xt1/fs))
title('CAT 259D Vz Signal','FontSize',20,'FontWeight','bold');
y = ylabel('Amplitude','FontSize',18,'FontWeight','bold');
xlabel('Time (s)','FontSize',10,'FontWeight','bold');
set(y, 'Units', 'Normalized', 'Position', [-0.1, 0.5, 0]);
set(get(gca,'ylabel'),'rotation',0)
axis tight
subplot(2,1,2)
imagesc(db(V_Spec6')); colormap('jet'); set(gca,'YDir','normal'); c = get(gca,'Clim');
set(gca, 'XTickLabelMode', 'manual', 'XTickLabel', []);
set(gca, 'YTickLabelMode', 'manual', 'YTickLabel', []);
title('CAT 259D Vz Signal Spectrogram',...
    'FontSize', 20, 'FontWeight','bold');
y=ylabel({'Normalized', 'Frequency'}, 'FontSize', 18, 'FontWeight','bold');
set(y, 'Units', 'Normalized', 'Position', [-0.1, 0.5, 0]);
set(get(gca,'ylabel'),'rotation',0)
xlabel('Time (s)', 'FontSize', 10, 'FontWeight','bold');
grid off
axis tight
hold on
stem(x, (FFTSIZE/8).*label_act, 'filled', 'Marker', 'none', 'Color', 'black');
axis tight


figure(7);
subplot(2,1,1)
plot(S_Audio)
xt2 = get(gca, 'XTick');                                 % 'XTick' Values
set(gca,'YDir','normal');
set(gca, 'XTick', xt2, 'XTickLabel', round(xt2/fs))
title('CAT 259D Audio Signal','FontSize',20,'FontWeight','bold');
y = ylabel('Amplitude','FontSize',18,'FontWeight','bold');
xlabel('Time (s)','FontSize',10,'FontWeight','bold');
set(y, 'Units', 'Normalized', 'Position', [-0.1, 0.5, 0]);
set(get(gca,'ylabel'),'rotation',0)
axis tight
subplot(2,1,2)
imagesc(db(A_Spec')); colormap('jet'); set(gca,'YDir','normal'); c = get(gca,'Clim');
set(gca, 'XTickLabelMode', 'manual', 'XTickLabel', []);
set(gca, 'YTickLabelMode', 'manual', 'YTickLabel', []);
title('CAT 259D Audio Signal Spectrogram',...
    'FontSize', 20, 'FontWeight','bold');
y=ylabel({'Normalized', 'Frequency'}, 'FontSize', 18, 'FontWeight','bold');
set(y, 'Units', 'Normalized', 'Position', [-0.1, 0.5, 0]);
set(get(gca,'ylabel'),'rotation',0)
xlabel('Time (s)', 'FontSize', 10, 'FontWeight','bold');
grid off
axis tight
hold on
stem(x, (FFTSIZE/8).*label_act, 'filled', 'Marker', 'none', 'Color', 'black');
axis tight


%% Building Vibration Data Fusion Test

vibration_training_data = training_data(:,1:((((FFTSIZE/2)+1)+7)*6)+1);
vibration_testing_data = testing_data(:,1:((((FFTSIZE/2)+1)+7)*6)+1);

% Implementing PCA
[COEFF, ~, ~] = pca(vibration_training_data(:, 2:end)); % Obtaining coefficients matrix
p = round(PCA_f*size(vibration_training_data, 2)-1);
Ap = COEFF(:, 1:p);

training_data_N_1 = [vibration_training_data(:, 1), bsxfun(@minus, vibration_training_data(:, 2:end), mean(vibration_training_data(:, 2:end)))*Ap];
testing_data_N_1 = [vibration_testing_data(:, 1), bsxfun(@minus, vibration_testing_data(:, 2:end), mean(vibration_training_data(:, 2:end)))*Ap];
% Creating cross-folds
% r = randi(cross_fold,size(training_data_N, 1),1);
% U = [r, training_data_N];
% firstColumn = U(:, 1);
% for i = 1:cross_fold
%      
%     A = U(firstColumn == i, :);
%     B = U(firstColumn ~= i, :);
%     test = A(:, 2:end);
%     train = B(:, 2:end);
    
% SVM Multiclass

Model = fitcecoc(training_data_N_1(:,2:end),training_data_N_1(:,1));
label = predict(Model,testing_data_N_1(:,2:end));
comparison_vibration = table(testing_data_N_1(:,1),label);
C_vibration = confusionmat(testing_data_N_1(:,1),label)
accuracy_vibration = trace(C_vibration)/sum(C_vibration(:))

%% Building Audio Data Test

audio_training_data = [training_data(:,1), training_data(:,((((FFTSIZE/2)+1)+7)*6)+2:end)];
audio_testing_data = [testing_data(:,1), testing_data(:,((((FFTSIZE/2)+1)+7)*6)+2:end)];

% Implementing PCA
[COEFF, ~, ~] = pca(audio_training_data(:, 2:end)); % Obtaining coefficients matrix
p = round(PCA_f*size(audio_training_data, 2)-1);
Ap = COEFF(:, 1:p);

training_data_N_2 = [audio_training_data(:, 1), bsxfun(@minus, audio_training_data(:, 2:end), mean(audio_training_data(:, 2:end)))*Ap];
testing_data_N_2 = [audio_testing_data(:, 1), bsxfun(@minus, audio_testing_data(:, 2:end), mean(audio_training_data(:, 2:end)))*Ap];
% Creating cross-folds
% r = randi(cross_fold,size(training_data_N, 1),1);
% U = [r, training_data_N];
% firstColumn = U(:, 1);
% for i = 1:cross_fold
%      
%     A = U(firstColumn == i, :);
%     B = U(firstColumn ~= i, :);
%     test = A(:, 2:end);
%     train = B(:, 2:end);
    
% SVM Multiclass

Model = fitcecoc(training_data_N_2(:,2:end),training_data_N_2(:,1));
label = predict(Model,testing_data_N_2(:,2:end));
comparison_audio = table(testing_data_N_2(:,1),label);
C_audio = confusionmat(testing_data_N_2(:,1),label)
accuracy_audio = trace(C_audio)/sum(C_audio(:))

%% Building Fusion Data Test

fused_training_data = training_data;
fused_testing_data = testing_data;

% Implementing PCA
[COEFF, ~, ~] = pca(fused_training_data(:, 2:end)); % Obtaining coefficients matrix
p = round(PCA_f*size(fused_training_data, 2)-1);
Ap = COEFF(:, 1:p);

training_data_N = [fused_training_data(:, 1), bsxfun(@minus, fused_training_data(:, 2:end), mean(fused_training_data(:, 2:end)))*Ap];
testing_data_N = [fused_testing_data(:, 1), bsxfun(@minus, fused_testing_data(:, 2:end), mean(fused_training_data(:, 2:end)))*Ap];
% Creating cross-folds
% r = randi(cross_fold,size(training_data_N, 1),1);
% U = [r, training_data_N];
% firstColumn = U(:, 1);
% for i = 1:cross_fold
%      
%     A = U(firstColumn == i, :);
%     B = U(firstColumn ~= i, :);
%     test = A(:, 2:end);
%     train = B(:, 2:end);
    
% SVM Multiclass

Model = fitcecoc(training_data_N(:,2:end),training_data_N(:,1));
label = predict(Model,testing_data_N(:,2:end));
comparison_fused = table(testing_data_N(:,1),label);
C_fused = confusionmat(testing_data_N(:,1),label)
accuracy_fused = trace(C_fused)/sum(C_fused(:))

toc