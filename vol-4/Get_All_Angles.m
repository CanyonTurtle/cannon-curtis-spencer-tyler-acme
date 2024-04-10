clear; clc;
%% Read in data <These will need to be updated on each computer>
% [label,data,timestamp,fs,micPositions,channel_ID_string]=readMCDR("C:\Users\curti\OneDrive\CAT\CatRepo\Data\CAT_Data\spring2024\testRecording_45_deg_left_of_fwd_2.mcdr");
% [label,data,timestamp,fs,micPositions,channel_ID_string]=readMCDR("C:\Users\curti\OneDrive\CAT\CatRepo\Data\CAT_Data\23_lowIdle_5m.mcdr");
% [label,data1,timestamp,fs,micPositions,channel_ID_string]=readMCDR("C:\Users\curti\OneDrive\CAT\CatRepo\Data\CAT_Data\spring2024\test_01_white_noise_0_fwd.mcdr");
% [label,data2,timestamp,fs,micPositions,channel_ID_string]=readMCDR("C:\Users\curti\OneDrive\CAT\CatRepo\Data\CAT_Data\spring2024\test_03_white_noise_90_left.mcdr");
% [label,data3,timestamp,fs,micPositions,channel_ID_string]=readMCDR("C:\Users\curti\OneDrive\CAT\CatRepo\Data\CAT_Data\spring2024\test_02_white_noise_45_left.mcdr");
% [label,data,timestamp,fs,micPositions,channel_ID_string]=readMCDR("C:\Users\curti\OneDrive\CAT\CatRepo\Demo2024\testRecording.mcdr");
data_path = 'C:\Repositories\cannon-curtis-spencer-tyler-acme\vol-3\Data\';
file = 'test_01_white_noise_0_fwd.mcdr';
file_to_read = [data_path, file];
[label,data,timestamp,fs,micPositions,channel_ID_string]=readMCDR(file_to_read);

% data=[data1; data2; data3]; % Concatenate data (if you want to see multiple results at once)

micPositions=micPositions(1:7,:); % Remove channel 8 (some datasets have mic 8 in the wrong location)
nMics=7;



Signals=data(:,1:nMics); % Trim data to match mic number
clearvars -except Signals fs micPositions nMics data file data_path

% Signals(:,2)=circshift(Signals(:,2),20);

%% Parameters
frameSize=512; % How many samples are processed at a time
% SmoothingFactor=0;
SmoothingFactor=0.93; % This is used by the leaky filter
win = true;
hann_window = repmat(hann(frameSize),1,nMics);
amplitudes = [];

%% Precalcs
A_ind=getAngularIndex_GPHAT(micPositions,fs,frameSize); % A_ind handles the conversion from time domain to spatial domain
A_ind_xc=getAngularIndex_XC(micPositions,fs,frameSize);
% Preallocation
GphatSmooth=zeros(frameSize,nMics*(nMics+1)/2);
xcSmooth=zeros(frameSize*2-1,nMics*(nMics+1)/2);

%% Looper
nBlocks=floor(size(Signals,1)/frameSize);

%C(nMics,2) total pairs, 2 angles for each pair
all_angs_time = zeros([2*nchoosek(nMics,2),nBlocks]);

for b=1:nBlocks
    block=Signals((b-1)*frameSize+1:b*frameSize,:); % Get a block of data
    if win
        block = block.*hann_window;
    end
    dblock=[zeros(1,nMics); diff(block)]; % Differentiate (d/dt)
    DOA_inst=zeros(360,1); % Zero instantaneous DOA estimate each cycle
    DOA_inst_XC=DOA_inst;
    np=0; % micpair index
    
    
    block_angles = [];
    for i=1:size(block,2)-1
        for j=i+1:size(block,2,1)
            np=np+1;
            % GCC PHAT (Alg orithm 2 Step 1)
            G1=fft(block(:,i));
            G2=fft(block(:,j));
            % amplitude = max(abs((G1.*conj(G2))));
            % amplitudes = [amplitudes,amplitude];
            GPHAT=(G1.*conj(G2))./abs((G1.*conj(G2))); % This is the coherence metric being calculated via dark magic, then normalized
            GPHAT(isnan(GPHAT))=0; % Just in case
            GphatSmooth(:,np)=GphatSmooth(:,np)*SmoothingFactor+GPHAT;
            %GphatSmooth(:,np)=GphatSmooth(:,np)*SmoothingFactor+GPHAT*amplitude; % This is a leaky filter, 
            R=ifft(GphatSmooth(:,np));
            R=[R(length(R)/2+1:end); R(1:length(R)/2)]; % This is a re-indexing to arrange R from -x to x, rather than 0 to x, then -x to -1
            
            % Compile DOA GCC (Algorithm 2 Step 2)
            DOA_inst=DOA_inst+R(A_ind(:,np)); % Domain change and add micpair np to total estimate
            %Extract the 2 angle measurements, compile them
            [pks,locs] = findpeaks(R(A_ind(:,np)),"SortStr","descend");
            this_angs = locs(1:2);
            block_angles = [block_angles this_angs(1) this_angs(2)];


            % Differential XC (Algorithm 1 Step 1)
            xc=xcorr(dblock(:,i),dblock(:,j));
            xcSmooth(:,np)=xcSmooth(:,np)*SmoothingFactor+xc;
            this_xcs=xcSmooth(:,np);
            
            % Compile DOA XC (Algorithm 1 Step 2)
            DOA_inst_XC=DOA_inst_XC+this_xcs(A_ind_xc(:,np)); % Domain change and add micpair np to total estimate
        end
    end
    % Compile data over time
    [~,est(b)]=max(DOA_inst);
    DOA_Surf(b,:)=DOA_inst;
    DOA_Surf_xc(b,:)=DOA_inst_XC;

    %Compile ALL angle measurements
    all_angs_time(1:end,b) = block_angles;

end

%Save the angle estimates:
CSV_name_all_angs = [data_path,'All_Angles_', file(1:end-4), 'csv'];
CSV_name_one_angs = [data_path,'One_Angle_', file(1:end-4), 'csv'];
writematrix(all_angs_time,CSV_name_all_angs)
writematrix(est,CSV_name_one_angs)
% writematrix(all_angs_time,"C:\Repositories\cannon-curtis-spencer-tyler-acme\vol-3\Data\ALL_ANGS_TEST.csv")
% writematrix(est,"C:\Repositories\cannon-curtis-spencer-tyler-acme\vol-3\Data\test_01_white_noise_0_fwd.csv")

% %%%%% IGNORE THIS STUFF %%%%%
% lgs=-length(R)/2:length(R)/2-1;
% %% Control
% A_ind_C=getAngularIndex_GPHAT(micPositions,fs,size(Signals,1)*2);
% DOAC=zeros(360,1);
% np=0;
% for i=1:size(block,2)-1
%     for j=i+1:size(block,2,1)
%         np=np+1;
%         [~,R_control,lgs_control]=gccphat(Signals(:,i),Signals(:,j));
%         DOAC=DOAC+R_control(A_ind_C(:,np));
%     end
% end
% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% %% Plot
% close all
% 
% subplot(2,1,1)
% surf(DOA_Surf_xc')
% shading interp
% colormap jet
% view(0,90)
% xlim([1 nBlocks]); ylim([1 360]);
% title('Differential XC')
% ylabel('Degrees');
% 
% subplot(2,1,2)
% surf(DOA_Surf')
% shading interp
% colormap jet
% view(0,90)
% xlim([1 nBlocks]); ylim([1 360]);
% title('GCC PHAT')
% ylabel('Degrees'); xlabel('Block Number')
% 
% sgtitle('Comparison of Continuous Metrics')
% set(gcf, 'Units', 'Normalized', 'OuterPosition', [0.1, 0.1, 0.65, 0.75]);
% 
% plot(lgs_control,R_control/max(abs(R_control)))
% hold on
% plot(lgs,R/max(abs(R)));
% xlim([-50 50])
% grid on

%% Functions
function angularIndex=getAngularIndex_GPHAT(micpos,fs,bufferSize)
n=1;
for i=1:size(micpos,1)-1
    for j=i+1:size(micpos,1)
        [d,a]=distang(micpos(i,:),micpos(j,:)); %Calculate distance and angle between mics
        ra=(1:360)*pi/180-a; %Create angle vector, rotate based on mic position
        ds=d*cos(ra)*fs/343; %Convert to sample delay
        angularIndex(:,n)=round(ds)+bufferSize/2 +1; % Shift to put zero index in the middle

        n=n+1;
    end
end
end

function angularIndex=getAngularIndex_XC(micpos,fs,bufferSize)
n=1;
for i=1:size(micpos,1)-1
    for j=i+1:size(micpos,1)
        [d,a]=distang(micpos(i,:),micpos(j,:)); %Calculate distance and angle between mics
        ra=(1:360)*pi/180-a; %Create angle vector, rotate based on mic position
        ds=d*cos(ra)*fs/343; %Convert to sample delay
        angularIndex(:,n)=round(ds+bufferSize); % Shift to put zero index in the middle

        n=n+1;
    end
end
end

function newXC=maskSource(oldXC,angularIndex,anglesToMask)
newXC=oldXC;
for n=1:size(oldXC,2)
    newXC(unique(angularIndex(anglesToMask,n)),n)=0;
end
end

% Reads an MCDR file and returns all fields. v1.1
function [label,data,timestamp,fs,micPositions,channel_ID_string]=readMCDR(filename)
    fileID = fopen(filename,'r');
    if fileID<0
        error(sprintf("Cannot find file: %s",filename));
    end
    v1=fread(fileID,1,"uint8");
    v2=fread(fileID,1,"uint8");
    L=fread(fileID,1,"uint8");
    T=fread(fileID,1,"uint8");
    label=string(fread(fileID,L,'char=>char')');
    timestamp=string(fread(fileID,T,'char=>char')');
    fs=fread(fileID,1,"uint32");
    N=fread(fileID,1,"uint8");
    micPositions=fread(fileID,[N 2],"float32");
    channel_ID_string=fread(fileID,N,"char=>char")';
    NS=fread(fileID,1,"uint32");
    P=fread(fileID,1,"uint8");
    if P==4
        data=fread(fileID,[NS N],"float32");
    elseif P==8
        data=fread(fileID,[NS N],"double");
    else
        error("invalid precision for v1.1 MCDR file.")
    end
    fclose(fileID);
end

function [d,a]=distang(p1,p2)
d=sqrt((p1(1)-p2(1))^2+(p1(2)-p2(2))^2);
a=atan2(p2(2)-p1(2),p2(1)-p1(1));
end