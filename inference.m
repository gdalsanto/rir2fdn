% Differentiable FDN for Colorless Reverberation 
% demo code 

clear; clc; close all;
disp('Adding toolboxes to the path ...')
addpath(genpath('./informed/diff-fdn-colorless/fdnToolbox'))
addpath(genpath('./informed/diff-fdn-colorless/DecayFitNet'))
addpath(genpath('./informed/diff-fdn-colorless/Two_stage_filter'))
disp('ok!')

results_dir = "./informed/diff-fdn-colorless/output/20240301-170355-ok";    % directory containing the solver's output 
output_dir = fullfile(results_dir, 'matlab');
rng(109378) 

RIRfilename = [
    "h229_Office_Lobby_1txts_48000",...
    "h025_Diningroom_8txts_48000",...
    "h042_Hallway_ElementarySchool_4txts_48000",...
    "h110_Office_MeetingRoom_1txts_48000",...
    "h027_Classroom_8txts_48000",...
    "h163_Bathroom_1txts_48000",...
    "h001_Bedroom_65txts_48000"];

iRIR = 4;  % TODO: 
%% Get attenuation and tone control filters 
computeAdl = 0;

Adl = 0;    % delay line lenghts in the feedback matrix 
if isfile(fullfile(results_dir, 'scat_parameters.mat'))
    types = {'SCAT','VANILLA'};
    if ~isfile(fullfile(results_dir, 'synthesis_filters.mat'))
        % in case you need to compute the filter coefficents save the
        % feedback matrix size  
        load(fullfile(results_dir, 'scat_parameters.mat'), 'feedbackMatrix')
        Adl = size(feedbackMatrix, 3);       
    end
else
    types = {'DFDN','RO'};
end

delays = [593.0, 743.0, 929.0, 1153.0, 1399.0, 1699.0];
N = length(delays);
fs = 48000; 
rir =  audioread("/Users/dalsag1/Dropbox (Aalto)/aalto/projects/analysis-synthesis-of-RIR/git/rir-analysis-synthesis/rirs/MIT_IR_Survey_resample/" + RIRfilename(iRIR)+".wav");

irLen = length(rir);

filterMethods = {'matlabGEQ', 'pythonGEQ', 'TwoStage'};
edc_est_path = "/Users/dalsag1/Dropbox (Aalto)/aalto/projects/analysis-synthesis-of-RIR/git/rir-analysis-synthesis/rirs/MIT_IR_Survey_resample/" + RIRfilename(iRIR) + "_est.mat";
% filters_path = "/Users/dalsag1/Dropbox (Aalto)/aalto/projects/analysis-synthesis-of-RIR/git/rir-analysis-synthesis/informed/output/20240221-111550/synthesis_filters.mat"
octaveBand = 3; 
[attenuationSOS, equalizationSOS] = get_filters(filterMethods{3}, delays+Adl, octaveBand, fs, irLen, edc_est_path=edc_est_path );%  filters_path = filters_path);
zAbsorption = zSOS(attenuationSOS,'isDiagonal',true);

%% construct FDN

if ~exist(output_dir, 'dir')
    mkdir(output_dir)
end 
for typeCell = types
    type = typeCell{1};
    switch type
        case 'DFDN' 
            % load parameters
            load(fullfile(results_dir,'parameters.mat'))
            temp = B; clear B
            B.(type) = temp(:);        % input gains as column
            temp = C; clear C
            C.(type) = temp;
            D.(type) = zeros(1:1);     % direct gains
            % make matrix A orthogonal 
            temp = A; clear A
            A.(type) = double(expm(skew(temp)));
            C.(type) = zSOS(permute(equalizationSOS,[3 4 1 2]) .*  C.(type));
            ir.(type) = dss2impz(...
                irLen, delays, A.(type), B.(type), C.(type), D.(type), 'absorptionFilters', zAbsorption);
        case 'RO'
            % ugly quick fix
            tempB = B; tempC = C; tempD = D; tempA = A; 
            load(fullfile(results_dir,'parameters_init.mat'))
            % make matrix A orthogonal 
            temp = A; clear A
            Ainit = double(expm(skew(temp)));  
            temp = B; clear B 
            B = tempB; 
            B.(type) = temp';
            temp = C; clear C
            C = tempC; 
            C.(type) = temp;
            D = tempD; 
            D.(type) = zeros(1,1);
            A = tempA;
            A.(type) = Ainit; 
            C.(type) = zSOS(permute(equalizationSOS,[3 4 1 2]) .*  C.(type));
            ir.(type) = dss2impz(...
                irLen, delays, A.(type), B.(type), C.(type), D.(type), 'absorptionFilters', zAbsorption);
        case 'SCAT'
            tempDelays = delays;
            load(fullfile(results_dir, 'scat_parameters.mat'))
            Adl = size(feedbackMatrix, 3);
            delayLeft = double(delayLeft);
            delayRight = double(delayRight);
            inputGain = inputGain(:);
            outputGain = outputGain(:)';
            outputGain = zSOS(permute(equalizationSOS,[3 4 1 2]) .*  outputGain);
%             if computeAdl
%                 zAbsorptionSCAT = zSOS(absorptionGEQ(double(targetT60), double(delays+Adl/2), fs),'isDiagonal',true);
%             else
%                 zAbsorptionSCAT = zAbsorption;
%             end
            zAbsorptionSCAT = zAbsorption;
            feedbackMatrix = shiftMatrix(double(feedbackMatrix), delayLeft, 'left');
            feedbackMatrix = shiftMatrix(feedbackMatrix, delayRight, 'right');
            mainDelay = double(delays - delayLeft - delayRight);
            matrixFilter = zFIR(double(feedbackMatrix));
            ir.(type) = dss2impzTransposed(irLen, mainDelay, matrixFilter, inputGain, outputGain, zeros(1,1), 'absorptionFilters', zAbsorptionSCAT);
            delays = tempDelays;
        case 'VANILLA' 
            K = 4;
            pulseSize = 1;
            load(fullfile(results_dir, 'scat_parameters.mat'))
            sparsityVector = [3, ones(1,K-1)];
            matrixS = 1/3*ones(N,N,K) - repmat(eye(N), [1, 1, K]);
            feedbackMatrix = matrixS(:,:,1);
            for it = 2:K
                
                [shiftLeft] = shiftMatrixDistribute(feedbackMatrix, sparsityVector(it-1), 'pulseSize', pulseSize);
                
                G1 = diag(1.^shiftLeft);
                R1 = matrixS(:,:,it) * G1;
            
                feedbackMatrix = shiftMatrix(feedbackMatrix, shiftLeft, 'left');
                feedbackMatrix = matrixConvolution(R1, feedbackMatrix);
               
                pulseSize = pulseSize * N*sparsityVector(it-1);
            end
            Adl = size(feedbackMatrix, 3);
            delayLeft = double(delayLeft);
            delayRight = double(delayRight);
            inputGain = randn(size(inputGain(:)));
            outputGain = randn(size(outputGain(:)'));
            outputGain = zSOS(permute(equalizationSOS,[3 4 1 2]) .*  outputGain);
            zAbsorptionSCAT = zAbsorption;
            feedbackMatrix = shiftMatrix(double(feedbackMatrix), delayLeft, 'left');
            feedbackMatrix = shiftMatrix(feedbackMatrix, delayRight, 'right');
            mainDelay = double(delays - delayLeft - delayRight);
            matrixFilter = zFIR(double(feedbackMatrix));
            ir.(type) = dss2impzTransposed(irLen, mainDelay, matrixFilter, inputGain, outputGain, zeros(1,1), 'absorptionFilters', zAbsorptionSCAT);
    end

    % generate impulse response

    % save impulse response
    name =  RIRfilename(iRIR) + "_" + type + "_est.wav";
    filename = fullfile(output_dir,name);
    % audiowrite(filename, ir.(type)/max(abs(ir.(type))),fs);
end

%% functions 
function Y = skew(X)
    X = triu(X,1);
    Y = X - transpose(X);
end

