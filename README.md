# HybridKinematicAcousticActivityRecognition
## Keywords
1. Supervised machine learning algorithm
2. Classification
3. Multi-label classification
4. Machine learning
5. Support Vector Machine (SVM)
6. Audio and kinematic signals
7. Sensor fusion
8. Dimension reduction (Principal Component Analysis)
10. Pre-processing (Removing outliers, removing gravity from accelerometer, filling missing values, de-noising)
11. Down-sampling and up-sampling
12. Audio features (Fourier Transform (STFT) Coefficients, Zero Crossing Rate (ZCR), Root Mean Square (RMS), Short Time Energy (STE), Spectral Flux (SF), Spectral, Entropy (SE), Spectral Centroid (SC), Spectral Roll-Off (SRO))
13. Confusion Matrix (Accuracy)

## Introduction
A hybrid system for recognizing multiple activities of construction equipment. The system integrates two major sources of data—audio and kinematic—through implementing a robust data fusion procedure. The presented system includes recording audio and kinematic signals, preprocessing data, extracting several features, as well as dimension reduction, feature fusion, equipment activity classification using Support Vector Machines (SVM), and smoothing labels. The proposed system was implemented in several case studies (i.e., ten different types and equipment models operating at various construction job sites) and the results indicate that a hybrid system is capable of providing up to 20% more accurate results, compared to cases using individual sources of data.

## Programming Language Used
MATLAB

## Guide to folders and files
There are 10 folders available in this repo, that provides the required codes for each type of heavy construction equipment (each equipment has different movements and actions; hence different labels/targets.
Each folder consists of several files, which are explained as follows:
1. **Main file** (Fusion_Training.m): This is the main file to execute.
2. **Denoising algorithms and functions** (algorithm developed by Rangachari, S.; Loizou, P.C. A noise-estimation algorithm for highly non-stationary environments. Speech Commun. 2006, 48, 220–231):
  initialise_parameters.m
  mcra2_estimation.m
  noise_estimation.m
  specsub_ns.m
3. **Inputs:**
  **Kinematic Data** (Accelerometer and gyroscope):
    test2.mat
  **Sound Data**
    Two .WAV files (equipment sound collected on the job site using a microphone)
      _ori: means original sound
      _den: means denoised sound
