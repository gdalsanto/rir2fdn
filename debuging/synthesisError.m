clear all; close all; 
set(groot, 'defaulttextinterpreter','latex');  
set(groot, 'defaultAxesTickLabelInterpreter','latex');  
set(groot, 'defaultLegendInterpreter','latex');

RIRfilename = "h042_Hallway_ElementarySchool_4txts_48000";
predName = "_FDN";
refRirPath = fullfile("rirs", RIRfilename + ".wav");
predRirPath = fullfile("rirs", RIRfilename + predName + ".wav");

fBands = [63, 80, 100, 125, 160, 200, 250, 315, 400, 500, 630, 800, 1000, 1250, 1600, 2000, 2500, 3150, 4000, 5000, 6300, 8000, 10000, 12500, 16000];
fs = 48000; 
maxT60=[];
cT60 = [];
cL = [];
tErrDAR = zeros(7, 25);
tErrDiffFDN = zeros(7, 25);


% read RIR
rirRef = audioread(refRirPath);
rirPred = audioread(predRirPath);
L= min([length(rirRef), length(rirPred)]);

estsRef = load(fullfile("edc-estimations", RIRfilename + "_est.mat"));
estsPred = load(fullfile("edc-estimations", RIRfilename + predName + "_est.mat"));
estsPredSCAT = load(fullfile("edc-estimations", RIRfilename + '_SCAT' + "_est.mat"));

estsRef = getEst(estsRef, fs, length(rirRef), fBands);
estsPred = getEst(estsPred, fs, length(rirPred), fBands);
estsPredSCAT = getEst(estsPredSCAT, fs, length(rirPred), fBands);

figure(1)
plot(fBands, estsRef.T, 'LineWidth',2); hold on; grid on;  
x2 = [fBands, fliplr(fBands)];
inBetween = [estsRef.T.*0.95, fliplr(estsRef.T.*1.05)];
f = fill(x2, inBetween, [200, 200, 200]./255, 'LineStyle', 'none', 'HandleVisibility','off');
set(f,'facealpha',.5)
plot(fBands, estsPred.T, 'LineWidth',2);
plot(fBands, estsPredSCAT.T, 'LineWidth',2);
legend('Reference', 'FDN', 'FDN w Scattering');

tErr = abs(estsRef.T - estsPred.T)./estsRef.T;
xticks([63, 125, 250, 500, 1000, 2000, 4000, 8000, 16000])
ax=gca;
ax.FontSize = 20;
xlabel("Frequency (Hz)");
ylabel("$T_\textrm{60}$ (s)");
% sgtitle('Reverberation Time (s)')
set(ax, 'box', 'on', 'Visible', 'on')
set(gca, 'XScale', 'log');

figure(2)
plot(fBands, db(estsRef.L), 'LineWidth',2); hold on; grid on; 
plot(fBands, db(estsPred.L), 'LineWidth',2);
plot(fBands, db(estsPredSCAT.L), 'LineWidth',2);
legend('Reference', 'FDN', 'FDN w Scattering');
xticks([63, 125, 250, 500, 1000, 2000, 4000, 8000, 16000])
ax=gca;
ax.FontSize = 20;
xlabel("Frequency (Hz)");
ylabel("Initial level (dB)");
set(ax, 'box', 'on', 'Visible', 'on')
set(gca, 'XScale', 'log');
% sgtitle('Initial Enegy (dB)')

disp(predRirPath + " tErr: " + string(sum(abs(estsRef.T - estsPred.T))) + " lErr: " + string(sum(abs(db(estsRef.L) - db(estsPred.L)))))
%% functions 

function estRefined = getEst(est,  fs, len, fBands)
    est.T = double(est.T);  
    est.A = double(est.A); 
    est.N = double(est.N); 
    est.norm = double(est.norm_vals)'; 
    est = transposeAllFields(est);
    [estRefined.L, estRefined.A, estRefined.N] = decayFitNet2InitialLevel(est.T, est.A, est.N, est.norm, fs, len, fBands);
     estRefined.T = est.T;
end
