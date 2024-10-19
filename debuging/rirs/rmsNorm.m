clear all; close all; clc;

indx = 1;

fileslist = dir(fullfile(pwd, '*.wav'));
fs = 48000; 

targetRMS = 10^(-45/20);

% normalize all stimuli on maxPeak
for i = 1:length(fileslist)
    filename = fullfile(fileslist(i).folder, fileslist(i).name);
    [x, fs] = audioread(filename);
    y = normalizeRMS(x, targetRMS);
    if max(abs(y),[],'all') >= 1 
        warning('clipping');
    end 
    audiowrite(filename, y, fs)
end