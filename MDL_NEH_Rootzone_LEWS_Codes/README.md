# Moisture-Driven Landslide Analysis Codes for the Northeastern Himalayas

## Repository Overview

This repository contains the analysis codes used for the revised manuscript on moisture-driven landslides (MDLs) in the Northeastern Himalayas (NEH). The workflow supports MDL inventory processing, rainfall preprocessing, AMC/API calculation, root-zone wetness analysis, event-duration rainfall threshold derivation, joint exceedance probability estimation, and wetness-conditioned landslide likelihood assessment.

The codes were developed to support an at-site, wetness-conditioned framework for understanding how triggering rainfall (TR), antecedent moisture condition represented by antecedent precipitation index (AMC/API), and root-zone effective saturation (`S_eff`) jointly influence MDL likelihood and landslide early warning system (LEWS)-oriented diagnostics.

## Repository Structure

```text
01_data_processing/
02_rainfall_ed_threshold_calculation/
03_api_rootzone_correlation/
04_adf_&_gini_calculation/
05_emp_prob_jep_calculation/
06_rootzone_wetness_conditioned_likelihood/
07_rootzone_wetness_amplification_ratio/
```

## Folder Descriptions

### `01_data_processing`

Contains scripts for MDL inventory extraction, station-wise rainfall preprocessing, RegEM-based rainfall imputation, rainfall threshold application, and study-area diagnostics.

### `02_rainfall_ed_threshold_calculation`

Contains scripts for AMC/API calculation, Crozier antecedent rainfall formulation, at-site E-D rainfall threshold estimation using non-crossing quantile regression, and rainfall threshold mapping.

### `03_api_rootzone_correlation`

Contains scripts for evaluating the rank-based association between rainfall-derived API and GLEAM-derived root-zone effective saturation (`S_eff`) on MDL days.

### `04_adf_&_gini_calculation`

Contains scripts for calculating Antecedent Dominance Fraction (ADF), Lorenz curves, Gini coefficients, and the Gini ratio (`G_AMC/G_TR`) to compare event-wise and annual TR–AMC dominance patterns.

### `05_emp_prob_jep_calculation`

Contains scripts for estimating empirical joint exceedance probability (JEP) using TR, AMC/API, and lagged `S_eff`, and comparing trivariate JEP with TR-only exceedance probability.

### `06_rootzone_wetness_conditioned_likelihood`

Contains scripts for estimating MDL likelihood conditioned on rainfall severity and lagged root-zone effective saturation, along with rainfall-only likelihood diagnostics.

### `07_rootzone_wetness_amplification_ratio`

Contains scripts for calculating and mapping the root-zone wetness amplification ratio (AR), which compares wetness-conditioned MDL likelihood against rainfall-only likelihood.

## General Workflow

The recommended workflow is:

1. Prepare MDL inventory and rainfall datasets.
2. Fill missing station rainfall using RegEM.
3. Apply rainfall-day threshold and prepare rainfall event data.
4. Calculate AMC/API for multiple antecedent lag windows.
5. Derive at-site E-D rainfall thresholds using non-crossing quantile regression.
6. Compare API with root-zone effective saturation (`S_eff`).
7. Calculate ADF and `G_AMC/G_TR`.
8. Estimate empirical trivariate JEP.
9. Compute wetness-conditioned MDL likelihood.
10. Estimate root-zone wetness amplification ratio.

## Required Software

The repository uses both MATLAB and R.

### MATLAB

Main MATLAB requirements include:

* Base MATLAB
* Statistics and Machine Learning Toolbox
* Optimization-related functions
* Excel and text file reading/writing functions
* NetCDF and shapefile handling functions where required

### R

Main R packages include:

* `sf`
* `ggplot2`
* `readxl`
* `openxlsx`
* `dplyr`
* `data.table`
* `geosphere`
* `viridis`
* `RColorBrewer`
* `scales`
* `grid`

## Important Notes

* File paths are defined inside individual scripts and should be updated by the user before running.
* Station IDs, metadata column names, and folder paths should be checked before execution.
* Some scripts depend on outputs from previous folders.
* Each folder contains its own `README.md` with detailed folder-specific instructions.
* The rainfall-day threshold, analysis period, and station-wise lag settings should be kept consistent with the manuscript methodology.
* Outputs should be verified before being used for manuscript figures, supplementary tables, or LEWS-related interpretation.

## Citation / Credit Statement

Codes were developed by Danish Monga under the guidance of Dr. Poulomi Ganguli, Indian Institute of Technology Kharagpur.
