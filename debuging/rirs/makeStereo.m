clear all; close all; clc;

fs = 48000; 

irLen = floor(fs*1.75); 
indx = 1;

fileslist = dir(fullfile(pwd, '*.wav'));
for i = 1:length(fileslist)
    filename = fullfile(fileslist(i).folder, fileslist(i).name);
    [x, fs] = audioread(filename);
    if size(x, 2) < 2
        x = x(1:irLen,1);
        y = repmat(x(:), 1, 2);
        audiowrite(filename, y, fs)
    else
        y = x(1:irLen,:);
        audiowrite(filename, y, fs)
    end
    
end