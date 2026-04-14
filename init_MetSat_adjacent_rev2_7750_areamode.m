clear;
clc;
close all force;
close all;
app=NaN(1);  %%%%%%%%%This is to allow for Matlab Application integration.
format shortG
top_start_clock=clock;
folder1='C:\Users\nlasorte\OneDrive - National Telecommunications and Information Administration\MATLAB2024\7GHz FSS Neighborhoods';
cd(folder1)
addpath(folder1)
addpath('C:\Users\nlasorte\OneDrive - National Telecommunications and Information Administration\MATLAB2024\Basic_Functions')
addpath('C:\Local Matlab Data\Local MAT Data') %%%%%%%One Drive Error with mat files
pause(0.1)


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
'Adjacent band Met Sat generic'
%%%%%%%%%%%%%%%%%%%%%%%%%%


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%FSS System: PLACEHOLDER Inputs
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
rx_ant_heigt_m=10; %%%%%%meters
rx_nf=2;  %%%%%%%NF in dB
rx_ant_gain=-10; %%%%%%Main Beam gain in dBi
in_ratio=-10.5; %%%%%I/N Ratio
tx_bw_mhz=275; %%megahertz: 
rx_bw_mhz=100; %%%%%Megahertz
rx_temp_k=176.20;%%%%%Noise Temperature K
x_pol_dB=2
radar_threshold=-138.7+10*log10(rx_bw_mhz)+10*log10(rx_temp_k)+in_ratio+x_pol_dB+-rx_ant_gain
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


%%%%%%%%%%%%%%%%%%%Other Inputs
rev=1
tx_height_m=30; %%%%%%2 meters
max_itm_dist_km=100;
reliability=50%
FreqMHz=7250; %%%%%%%%MHS
tf_clutter=0
tx_eirp=71+10*log10(tx_bw_mhz/1) %%%%%%%71dBm/1Mhz +Convert to 275Mhz 10*log10(tx_bw_mhz/1)
required_pathloss_fdr=ceil(tx_eirp-radar_threshold)
%%%%%%%%%%%%%%%%%%%%%%%%%%%



%%%%%%%%%%Find the ITM Area Pathloss for the distance array
tic;
max_rx_height=rx_ant_heigt_m
[array_pathloss]=itm_area_dist_array_sea_rev2(app,reliability,tx_height_m,max_rx_height,max_itm_dist_km,FreqMHz);
toc;
tic;
save(strcat('Rev',num2str(rev),'_array_pathloss.mat'),'array_pathloss')
toc;



% figure;
% hold on;
% plot(array_pathloss(:,1),array_pathloss(:,2),'-g','LineWidth',3)
% xline(array_pathloss(cross_idx,1))
% yline(required_pathloss)
% xlabel('Distance [km]')
% ylabel('Pathloss [dB]')
% grid on;
% filename1=strcat('Pathloss_AdjacentFSS_Scenario1.png');
% saveas(gcf,char(filename1))
% pause(0.1);




%%%%%%%%%%%%%%%%%%%FDR


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%Calculate FDR
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
tf_calc_fdr=1%0
rx_freq_mhz=7800
guardband=350
tx_freq_mhz=7262.5
zero_freq=7400


filename_fdr=strcat('metsat_','array_fdr_',num2str(tx_freq_mhz),'_',num2str(rx_freq_mhz),'.mat');
[var_exist_fdr]=persistent_var_exist_with_corruption(app,filename_fdr);

if tf_calc_fdr==1
    var_exist_fdr=0
end

if var_exist_fdr==2
    tic;
    load(filename_fdr,'array_fdr')
    toc;
else

    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%FDR Curves
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%FDR Inputs
    array_tx_rf=fliplr(horzcat(0, 135, 137.5,140, 150, 400)); %%%%Frequency MHz (Base Station) [Half Bandwidth]
    array_tx_mask=fliplr(horzcat(0,0.1, 6, 20, 90, 96)); %%%%%%%dB Loss
    tx_extrap_loss=-60; %%%%%%%%%TX Extrapolation Slope dB/Decade -60dB (This is generous)

    array_rx_if=fliplr(horzcat(0,50,51,54,60,70)); %%%%Frequency MHz Half Bandwidth [Need to check these numbers]
    array_rx_loss=fliplr(horzcat(0,0.1,3,6,40,60)); %%%%%%%dB Loss
    rx_extrap_loss=-60; %%%%%%%%%RX Extrapolation Slope dB/Decade 60dB (This is generous)

    
    fdr_freq_separation=abs(tx_freq_mhz-rx_freq_mhz)
    fdr_calc_mhz=ceil(fdr_freq_separation*1.5)
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%Calculate FDR
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    tic;
    [FDR_dB,ED,VD,OTR,DeltaFreq,~,trans_mask_lte]=FDR_ModelII_app(app,fdr_calc_mhz,array_tx_rf,array_rx_if,array_tx_mask,array_rx_loss,tx_extrap_loss,rx_extrap_loss);
    toc;

    table_em=array2table(ED)
    table_em.Properties.VariableNames = {'Freq_Offset_MHz', 'dB'}
    writetable(table_em,strcat('Tx_Em.xlsx'))

    table_VD=array2table(VD)
    table_VD.Properties.VariableNames = {'Freq_Offset_MHz', 'dB'}
    writetable(table_VD,strcat('Rx_IF.xlsx'))


    zero_idx=nearestpoint_app(app,0,DeltaFreq);
    array_fdr=horzcat(DeltaFreq(zero_idx:end)',FDR_dB(zero_idx:end));

    fdr_idx=nearestpoint_app(app,fdr_freq_separation,array_fdr(:,1));
    fdr_dB=array_fdr(fdr_idx,:)  %%%%%%Frequency, FDR Loss
    save(filename_fdr,'array_fdr')

    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%FDR Plot
    close all;
    figure;
    hold on;
    plot(array_fdr(:,1),array_fdr(:,2),'-b','LineWidth',2,'DisplayName','FDR Loss')
    legend('Location','northwest')
    title({strcat('FDR: Example FSS Rx and Base Station')})
    grid on;
    xlabel('Frequency Offset [MHz]')
    ylabel('FDR [dB]')
    filename1=strcat('FDR1_NewTx_metsat_',num2str(rx_freq_mhz),'.png');
    saveas(gcf,char(filename1))



    figure;
    hold on;
    plot(ED(:,1)+tx_freq_mhz,-1*ED(:,2),'-r')
    grid on;
    xlabel('Frequency [MHz]')
    ylabel('Normalized Emission Mask [dB]')
    axis([7100 7750 -100 0])
    filename1=strcat('7GHz_Tx_metsat_',num2str(rx_freq_mhz),'.png');
    saveas(gcf,char(filename1))


    figure;
    hold on;
    plot(VD(:,1)+rx_freq_mhz,VD(:,2),'-r')
    grid on;
    xlabel('Frequency [MHz]')
    ylabel('Normalized IF Mask [dB]')
    filename1=strcat('7GHz_Rx_metsat_',num2str(rx_freq_mhz),'.png');
    saveas(gcf,char(filename1))

end



offset_freq=rx_freq_mhz-tx_freq_mhz
loss_vs_freq=array_fdr;
loss_vs_freq(:,2)=required_pathloss_fdr-array_fdr(:,2);

figure;
hold on;
plot(loss_vs_freq(:,1),loss_vs_freq(:,2),'-b')
grid on;



%%%%%%%%%%Find the Distance for each loss(:,2)
array_cross_idx=nearestpoint_app(app,loss_vs_freq(:,2),array_pathloss(:,2));
dist_vs_freq=array_pathloss(array_cross_idx,1);
dist_vs_freq(:,2)=loss_vs_freq(:,1);
adjust_dist_vs_freq=dist_vs_freq;
adjust_dist_vs_freq(:,2)=dist_vs_freq(:,2)-offset_freq+guardband;

cross_idx=nearestpoint_app(app,guardband,adjust_dist_vs_freq(:,2))
adjust_dist_vs_freq(cross_idx,:)


figure;
hold on;
plot(dist_vs_freq(:,2)-offset_freq+guardband,dist_vs_freq(:,1),'-b','LineWidth',2)
xline(0,'-r','LineWidth',2)
xline(guardband,'-g','LineWidth',2)
xlabel('Frequency Separation (Guard Band) [MHz]')
ylabel('Distance [km]')
grid on;
filename1=strcat('Dist_vs_Freq_metsat_',num2str(rx_freq_mhz),'.png');
saveas(gcf,char(filename1))



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%



end_clock=clock;
total_clock=end_clock-top_start_clock;
total_seconds=total_clock(6)+total_clock(5)*60+total_clock(4)*3600+total_clock(3)*86400;
total_mins=total_seconds/60;
total_hours=total_mins/60;
if total_hours>1
    strcat('Total Hours:',num2str(total_hours))
elseif total_mins>1
    strcat('Total Minutes:',num2str(total_mins))
else
    strcat('Total Seconds:',num2str(total_seconds))
end
%close all force;
cd(folder1)
'Done'

