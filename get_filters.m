function [attenuationSOS, equalizationSOS] = get_filters(method, delays, octaveBand, fs, rirLen, varargin)
% GET_FILTERS - Obtain attenuation and tone correction filters for RIR synthesis using FDN.
%
% Syntax:
%   [attenuationSOS, equalizationSOS] = get_filters(method, delays, octaveBand, fs, rirLen, varargin)
%
% Input Arguments:
%   method        - Method for obtaining filters. Choices are:
%                     * 'matlabGEQ': Use pre-estimated Energy Decay Curve (EDC) parameters values to design a Graphic Equalizer (GEQ) [1].
%                     * 'TwoStage': Use pre-estimated EDC parameters values to design a two-stage attenuation filter [2].
%                       note that the cutoff frequency of the prefilter wc be tuned manually
%                     * 'pythonGEQ': Use pre-computed Second Order Sections (SOS) filter parameters computed in Python. The
%                       filters can be generated using the FilterDesigner in diff-fdn-colorless/eq_design.py and are automatically generated when
%                       running solver.py with --reference_ir argument
%   delays        - Vector of FDN delay line lengths.
%   octaveBand    - Octave band division. Specify 1 for 1 octave bands or 3 for 1/3 octave bands.
%   fs            - Sampling frequency in Hz.
%   rirLen        - Length of the room impulse response in samples.
%   varargin      - Optional arguments depending on the chosen method:
%                     * For 'matlabGEQ' and 'TwoStage': Provide the path to the .mat file containing EDC parameter estimations.
%                     * For 'pythonGEQ': Provide the path to the .mat file containing pre-computed SOS filter parameters.
%
% Output Arguments:
%   attenuationSOS   - Attenuation filters represented as SOS in a 4D array.
%   equalizationSOS  - Equalization filters represented as SOS in a 2D array.
%
% References:
%   [1] J. Liski and V. Välimäki, “The quest for the best graphic equalizer,” 
%       in Proc. DAFx, Edinburgh, UK, Sep. 2017, pp. 95–102.
%   [2] V. Välimäki, K. Prawda, and S. J. Schlecht, “Two-stage attenuation 
%       filter for artificial reverberation,” IEEE Signal Process. Lett., Jan. 2024.
%
% Gloria Dal Santo, last modified on 17.05.2024, Espoo (FI)


p = inputParser;
addRequired(p, 'method', @(x) any(validatestring(x, {'matlabGEQ', 'pythonGEQ', 'TwoStage'})));
addRequired(p, 'delays', @(x) isvector(x) ) % FDN delay lines lengths
addRequired(p, 'octaveBand', @(x) x == 1 || x == 3 ) % octave band division
addRequired(p, 'fs' , @(x) isnumeric(x)) % sampling frequency
addRequired(p, 'rirLen' , @(x) isnumeric(x)) % sampling frequency

addOptional(p, 'edc_est_path', @(x) endsWith(x,".mat") )    % path to the EDC parameters estimations 
addOptional(p, 'filters_path', @(x) endsWith(x,".mat") )    % path to the SOS filters parameters computed in python 

parse(p,method, delays, octaveBand, fs, rirLen, varargin{:});

% get center frequencies 
if octaveBand == 1
    % hardcoded 1/1 octave bands
    fBands = [63, 125, 250, 500, 1000, 2000, 4000, 8000, 16000];
    correction_T = [0.9, 0.9, 1, 1, 1, 1, 1, 0.9, 0.5];
    correction_L = [5, 0, 0, 0, 0, 0, 0, 5, 5];
    nBands = 10; % total number of bands expected by the fitler desgin functions 
elseif octaveBand == 3
    % hardcoded 1/3 octave bands
    fBands = [63, 80, 100, 125, 160, 200, 250, 315, 400, 500, 630, 800, 1000, 1250, 1600, 2000, 2500, 3150, 4000, 5000, 6300, 8000, 10000, 12500, 16000];
    correction_T = [0.9, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0.9];
    correction_L = [15, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 15];
    nBands = 31; % total number of bands expected by the fitler desgin functions 
end

if strcmp(method, 'matlabGEQ') || strcmp(method, 'TwoStage')
    % Unless you have the >=M2 chip, you should be able to get the EDC
    % parameters from the DecayFitNet Toolbox directly in Matlab. 
    % This code uploads the values pre-estimated in Python
    load(varargin{2});
    est.T = double(T);  % decay time
    est.A = double(A);  % amplitude
    est.N = double(N);  % noise level
    est.norm = double(norm_vals)';  % level normalization term 
    est = transposeAllFields(est);
    [est.L, est.A, est.N] = decayFitNet2InitialLevel(est.T, est.A, est.N, est.norm, fs, rirLen, fBands);
    est.T = est.T.*correction_T;
    targetLevel = mag2db(est.L) - correction_L;

    if strcmp(method, 'matlabGEQ') 
        % 1/1 octave band is expected 
        targetT60 = est.T([1 1:end end]);  % seconds        
        attenuationSOS = absorptionGEQ(targetT60, delays, fs);
    elseif strcmp(method, 'TwoStage') 
        % uses shelving prefilter and GEQ 
        targetT60 = est.T;
        % pad RT values 
        if octaveBand == 1
            targetT60 = [targetT60(1)*ones(1), targetT60, targetT60(end)*ones(1)];
        elseif octaveBand == 3
            targetT60 = [targetT60(1)*ones(1, 5), targetT60, targetT60(end)*ones(1)];
        end
        wc = 8000; % cut off frequency for the prefilter TODO: make wc detection automatic 
        % get the frequency response of the attenuation filter
        attenuationSOS = zeros(length(delays), 1, nBands+1, 6);
        for i = 1:length(delays)
            [~, ~, ~, ~, iSOS] = twoFilters(targetT60, delays(i), fs, 'shelf', wc);
            attenuationSOS(i, 1, :, :) = iSOS;
        end
    end
    % Tone correction filter 
    if octaveBand == 1
        targetLevel = [targetLevel(1)*ones(1), targetLevel, targetLevel(end)*ones(1)];
        [nums,dens, ~] = aceq(targetLevel, 0, fs);
    elseif octaveBand == 3
        targetLevel = [targetLevel(1)*ones(1, 5), targetLevel, targetLevel(end)*ones(1)];
        [nums,dens, ~] = acge3(targetLevel, 0, fs);
    end
    % get the frequency response of the tone correction filter
    equalizationSOS = horzcat(nums', dens');
    
elseif strcmp(method, 'pythonGEQ') 
    % load filters computed in python during training (solver.py)
    load(varargin{2})
    attenuationSOS = G_SOS;
    equalizationSOS = TC_SOS;
end
end