# RIR2FDN
This is the companion code to the **RIR2FDN: An improved room impulse response analysis and synthesis** paper submitted to the 27th International Conference on Audio Effects (DAFx24), Guilford, UK, 3-7 September 2024.  



**RIR2FDN**: a mapping from RIR to Feedback Delay Network (FDN) parameters such that the impulse response of the FDN is perceptually similar to the target RIR. 
To do so, we use an informed method incorporating improved energy decay estimation and synthesis within an optimized feedback delay network.

This repository relies on 4 submodules:
- [diff-fdn-colorless](https://github.com/gdalsanto/diff-fdn-colorless): optimization code to tune a set of FDN parameters (feedback matrix, input gains, and output gains) to achieve a smoother and less colored reverberation [1, 2]. 
In the submitted paper we use the scattering feedback matrix (arg `--scattering`), 6 delay lines with lengths [593, 743, 929, 1153, 1399, 1699]. 
    - [Two_stage_filter](https://github.com/gdalsanto/Two_stage_filter): two stage attenuation filter design by Vesa Välimäki et al. [3]
    - [DecayFitNet](https://github.com/georg-goetz/DecayFitNet/tree/01daf3e7bbfd637aa1269bbca0cab7f445db0d5d): neural-network-based approach to estimate RIR decay parameters from energy decay curves (EDCs), which are modeled as a combination of multiple exponential decays, each characterized by an amplitude, decay time, and a noise term. We use these values to design the prototype attenuation and tone corrector filters.
    - [fdnToolbox](https://github.com/SebastianJiroSchlecht/fdnToolbox): Matlab toolbox for FDN, used to generate the impulse response at inference (by the `inference.m` script) from the estimated FDN parameters.
- [diff-delay-net](https://github.com/gdalsanto/diff-delay-net): implementation of the differentiable delay network presented by S. Lee et al. in [4]. **Please note that this is not the official implementation.** 


## Getting started 
When cloning this repository, make sure to clone all the submodules, by running
```
git clone --recurse-submodules https://github.com/gdalsanto/rir2fdn
```
<ins>FDN colorless optimization</ins>: to run colorless optimization run `./diff-fdn-colorless/solver.py`. The output parameters will be saved in .mat format. 

<ins>Decay parameters estimation</ins>: run `./diff-fdn-colorless/rir_analysis.py` to run the energy decay analysis and the EDC parameters estimation of the RIR you want to synthesize. The solver can do this already by setting the argument `--reference_ir`.

<ins>RIR2FDN</ins>: run the `.inference.m` script to build an FDN with the optimized FDN parameters. The script uses the two-stage attenuation filter and a graphic equalizer for the tone correction filter. The prototype filters are derived from the pre-estimated EDC parameters. 


In `./rir` you can already find a set of 7 rirs and their EDC parameters. These RIR were used for the paper to evaluate the presented model. 

**Note**: as it is, this code doesn't take into account the early reflections and, as such, should be used to synthesize only the late reverberation part. 

## References
Audio demos are published in [RIR2FDN](http://research.spa.aalto.fi/publications/papers/dafx24-rir2fdn/).  
The paper is not yet available, but you can check related work:
```
[1] Dal Santo G., Prawda K., Schlecht S. J., and Välimäki V., "Feedback Delay Network Optimization." in EURASIP Journal on Audio, Speech, and Music Processing - sumbitted for reviews on 31.01.2024
[2] Dal Santo G., Prawda K., Schlecht S. J., and Välimäki V., "Differentiable Feedback Delay Network for colorless reverberation." in the 26th International Conference on Digital Audio Effects (DAFx23), Copenhagen, Denmark, Sept. 4-7 2023
[3] Välimäki, V., Prawda, K., & Schlecht, S. J., "Two-stage attenuation filter for artificial reverberation." IEEE Signal Processing Letters, 2024
[4] Lee, S., Choi, H. S., & Lee, K., "Differentiable artificial reverberation." in IEEE/ACM Transactions on Audio, Speech, and Language Processing, 30, 2541-2556, 2022.
```
