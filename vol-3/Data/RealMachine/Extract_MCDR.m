%fnames = ["test_01_white_noise_0_fwd","test_02_white_noise_45_left","test_03_white_noise_90_left","test_04_engine_noise_no_talking","test_06_engine_noise_talking"];
% Get the current directory
currentDir = pwd;

% List all files in the current directory
files = dir(currentDir);

% Extract filenames
filenames = {files(~[files.isdir]).name};


for i = 1:length(filenames)
    %Loops through all files and saves it as a .mat file
    file = filenames(i);
    file = file{1};
    if file(length(file)-3:length(file)) == 'mcdr'
        MCDR2mat(file);
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

%Reads the MCDR file and saves it as a .mat file with data, micpositions,
%fs, and label
function MCDR2mat(fnameMCDR)
    %Load in the mcdr file
    filename = fnameMCDR(1:length(fnameMCDR)-5);
    %fnameMCDR = strcat(filename,".mcdr");
    [label,data,timestamp,fs,micPositions,channel_ID] = readMCDR(fnameMCDR);
    fname_mat = strcat(filename,".mat");

    %save the data, fs, and micpositions as a .mat file
    save(fname_mat,'data');
    save(fname_mat,'micPositions','-append');
    save(fname_mat,'fs','-append');
    save(fname_mat,'label','-append');
end

%Reads the MCDR file and saves it as a .mat file with just data
function MCDR2CSV(filename)
    %fnameMCDR = strcat(filename,".mcdr");
    [label,data,timestamp,fs,micPositions,channel_ID] = readMCDR(fnameMCDR);

    fname_to_write = strcat(filename,"_", string(fs),".csv");
    writematrix(data,fname_to_write);
end