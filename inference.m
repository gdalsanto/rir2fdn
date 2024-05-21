% Differentiable FDN for Colorless Reverberation 
%
% Gloria Dal Santo, last modified on 17.05.2024, Espoo (FI)

clear; clc; close all;

%% PREPARE FILEPATHS 

disp('Adding toolboxes to the path ...')
addpath(genpath('./informed/diff-fdn-colorless/fdnToolbox'))
addpath(genpath('./informed/diff-fdn-colorless/DecayFitNet'))
addpath(genpath('./informed/Two_stage_filter'))
disp('ok!')

% initializing filepaths
results_dir = "./output/20240521-092940";    % directory containing the solver's output 
output_dir = fullfile(results_dir, 'inference-matlab');   % output directory 
if ~exist(output_dir, 'dir')
    % create output directory
    mkdir(output_dir)
end 
rirs_dir = './rirs';    % directory containing rirs to synthesize 
edc_est_dir = './rirs/edc-params';   % directory containing EDC analysis results for the rirs to synthesize 
[RIRfilepaths, RIRfilenames]  = getFilepaths(rirs_dir, 'wav');   % filepaths of rirs to synthesize


%% VARIABLES INIT

% detect whether it uses a scattering feedback matrix 
if isfile(fullfile(results_dir, 'scat_parameters.mat'))
    type = 'SCAT';
else
    type = 'DFDN';
end

fs = 48000;     % sampling frequnecy
octaveBand = 3; % frequnecy resolution of the filters 
isTranspose = 1;     % relative position of the feedback matrix and delays (0/1)
%% BUILD FDNs AND SAVE RIRS

for iRIR = 1:length(RIRfilepaths)
    RIRfilename = char(RIRfilenames(iRIR));
    % read EDC estimations (ideally I would compute them here, but
    % DecayFitNet dependencies don't support M2 chip
    edc_est_path = fullfile(edc_est_dir, RIRfilename(1:end-4) + "_est.mat");
    % read RIR
    rir = audioread(RIRfilepaths(iRIR));
    irLen = length(rir);    

    switch type
        case 'DFDN' 
            % load parameters
            load(fullfile(results_dir,'parameters.mat'))
            B = B(:);           % input gains as column
            D = zeros(1:1);     % direct gains
            % make matrix A orthogonal 
            A = double(expm(skew(A)));

            % get filters
            [attenuationSOS, equalizationSOS] = get_filters('TwoStage', m, octaveBand, fs, irLen, edc_est_path=edc_est_path );
            zAbsorption = zSOS(attenuationSOS,'isDiagonal',true);

            % apply tone corrector filter
            C = zSOS(permute(equalizationSOS,[3 4 1 2]) .*  C);
            if isTranspose
               ir = dss2impzTransposed(...
                irLen, m, A, B, C, D, 'absorptionFilters', zAbsorption);             
            else 
               ir = dss2impz(...
                irLen, m, A, B, C, D, 'absorptionFilters', zAbsorption);
            end
        case 'SCAT'
            load(fullfile(results_dir, 'scat_parameters.mat'))
            Adl = size(feedbackMatrix, 3);  % delays introduced by the scattering feedback matrix
            B = inputGain(:);   % input gains
            C = outputGain(:)'; % output gains
            D = zeros(1:1);     % direct gains

            % get filters
            [attenuationSOS, equalizationSOS] = get_filters('TwoStage', double(delays+Adl/2), octaveBand, fs, irLen, edc_est_path=edc_est_path);
             zAbsorption = zSOS(attenuationSOS,'isDiagonal',true);

            % apply tone corrector filter
            C = zSOS(permute(equalizationSOS,[3 4 1 2]) .*  C);
            % build scattering matrix 
            A = shiftMatrix(double(feedbackMatrix), double(delayLeft), 'left');
            A = shiftMatrix(A, double(delayRight), 'right');
            m = double(delays - double(delayLeft) - double(delayRight));
            A = zFIR(double(A));
            if isTranspose
                ir = dss2impzTransposed(...
                    irLen, m, A, B, C, D, 'absorptionFilters', zAbsorption);
            else
                ir = dss2impz(...
                    irLen, m, A, B, C, D, 'absorptionFilters', zAbsorption);
            end
    end
    % save impulse response
    name =  RIRfilenames(iRIR) + "_" + type + "_est.wav";
    filename = fullfile(output_dir,name);
    audiowrite(filename, ir, fs);
end

%% AUXILIARY FUNCTIONS 

function Y = skew(X)
    % orthogonal mapping
    X = triu(X,1);
    Y = X - transpose(X);
end

function [filePaths, baseFilename] = getFilepaths(folder, extension)
    % retrieves the full file paths of all files with a specified
    % extension in a given folder.

    % get a list of all .extension files in the folder
    waveFiles = dir(fullfile(folder, "*."+ extension));

    % initialize a cell array to store the full file paths
    filePaths = cell(length(waveFiles), 1);
    baseFilename = cell(length(waveFiles), 1);
    % loop through the list of files to construct full file paths
    for k = 1:length(waveFiles)
        filePaths{k} = fullfile(folder, waveFiles(k).name);
        baseFilename{k} =  waveFiles(k).name;
    end

    % convert cell array to a string array if needed
    filePaths = string(filePaths);
    baseFilename = string(baseFilename);
end
