# RIR2FDN
This is the companion code to the **RIR2FDN: An improved room impulse response analysis and synthesis** paper submitted to the 27th International Conference on Audio Effcts (DAFx24), Guilford, UK, 3-7 September 2024.  



**RIR2FDN**: a mapping from RIR to Feedback Delay Network (FDN) parameters such that the impulse response of the FDN is perceptually similar to the target RIR. 
To do so, we use an informed method incorporating improved energy decay estimation and synthesis within an optimized feedback delay network.

This repository relies on 4 submodules:
- [diff-fdn-colorless](https://github.com/gdalsanto/diff-fdn-colorless): optimization code to tune a set of FDN parameters (feedback matrix, input gains, and output gains) to achieve a smoother and less colored reverberation [1, 2]. 
In the submitted paper we use the scattering feedback matrix (arg `--scattering`), 6 delay lines with lengths [593, 743, 929, 1153, 1399, 1699]. 
    - [DecayFitNet](https://github.com/georg-goetz/DecayFitNet/tree/01daf3e7bbfd637aa1269bbca0cab7f445db0d5d): neural-network-based approach to estimate RIR decay parameters from energy decay curves (EDCs), which are modeled as a combination of multiple exponential decays, each characterized by an amplitude, decay time, and a noise term. We use these values to design the prototype attenuation and tone corrector filters.
    - [fdnToolbox](https://github.com/SebastianJiroSchlecht/fdnToolbox): Matlab toolbox for FDN, used to generate the impulse response at inference (by the `inference.m` script) from the estimated FDN parameters.
- [diff-delay-net](https://github.com/gdalsanto/diff-delay-net): implementation of the differentiable delay network presented by S. Lee et al. in [3]. **Please note that this is not the official implementation.** 


## Getting started 
When cloning this repository, make sure to clone all the submodules, by running
```
git clone --recurse-submodules https://github.com/gdalsanto/rir2fdn
```



## References
Audio demos are published in: [RIR2FDN](http://research.spa.aalto.fi/publications/papers/dafx24-rir2fdn/).  
The paper is not yet available, but you can check related work:
```
[1] Dal Santo G., Prawda K., Schlecht S. J., and Välimäki V., "Feedback Delay Network Optimization." in EURASIP Journal on Audio, Speech, and Music Processing - sumbitted for reviews on 31.01.2024
[2] Dal Santo G., Prawda K., Schlecht S. J., and Välimäki V., "Differentiable Feedback Delay Network for colorless reverberation." in the 26th International Conference on Digital Audio Effects (DAFx23), Copenhagen, Denmark, Sept. 4-7 2023 
[3] Lee, S., Choi, H. S., & Lee, K., "Differentiable artificial reverberation." in IEEE/ACM Transactions on Audio, Speech, and Language Processing, 30, 2541-2556, 2022.
```
