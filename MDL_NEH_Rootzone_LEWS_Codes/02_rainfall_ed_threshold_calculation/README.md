# 02_rainfall_ed_threshold_calculation

## Folder Title

AMC/API Calculation and At-Site E-D Rainfall Threshold Estimation

## Purpose of the Folder

This folder contains MATLAB and R scripts used to calculate antecedent moisture condition using the antecedent precipitation index (AMC/API), derive at-site event-duration (E-D) rainfall thresholds, and visualize the spatial variability of rainfall thresholds across the Northeastern Himalayas (NEH).

## Scientific Relevance to the Manuscript

The scripts in this folder support the rainfall-threshold component of the moisture-driven landslide (MDL) analysis. AMC/API represents rainfall-derived antecedent wetness preceding MDL occurrence, while triggering rainfall (TR) represents the rainfall episode directly associated with slope failure.

The derived at-site E-D thresholds provide rainfall-based reference conditions for MDL occurrence. These thresholds are later used for comparison with root-zone effective saturation (`S_eff`), wetness-conditioned likelihood, joint exceedance probability (JEP), amplification ratio (AR), and landslide early warning system (LEWS)-oriented diagnostics.

## Scripts Included

1. `compute_api_crozier_all_lags.m`
2. `crozier.m`
3. `compute_at_site_ed_thresholds_ncquantreg.m`
4. `ncquantreg.m`
5. `plot_threshold_spatial_map_kde.R`

## Brief Description of Scripts

### `compute_api_crozier_all_lags.m`

Calculates AMC/API values for each MDL event using the Crozier antecedent rainfall formulation. The script evaluates multiple antecedent lag windows and generates station-wise API values for each lag.

### `crozier.m`

Helper function used to compute the Crozier/API value for a specified antecedent rainfall window and decay factor.

### `compute_at_site_ed_thresholds_ncquantreg.m`

Derives station-wise E-D rainfall thresholds using non-crossing quantile regression. The script combines AMC/API and TR samples and estimates rainfall thresholds across multiple quantiles. The manuscript-focused rainfall threshold is extracted at `tau = 0.20`.

### `ncquantreg.m`

Helper function used for non-crossing polynomial quantile regression. This function supports physically consistent quantile estimation by avoiding crossing among fitted quantile curves.

### `plot_threshold_spatial_map_kde.R`

Generates spatial and distributional diagnostics of station-wise rainfall thresholds, including threshold maps and kernel density estimates of the 3-day rainfall threshold.

## Required Input Files

The scripts require the following inputs:

* Threshold-applied station-wise rainfall files.
* Station-wise MDL event files.
* Last triggering rainfall day files for MDL events.
* Station-wise AMC/API files for different antecedent lags.
* Station-wise TR files.
* NEH station metadata file.
* Final station-wise threshold output table.
* Study-area shapefile.

File paths are defined inside the scripts and should be updated by the user before running.

## Expected Output Files

The scripts generate the following outputs:

* Station-wise AMC/API files for multiple antecedent lag windows.
* Station-wise E-D rainfall threshold table.
* Quantile-specific 3-day rainfall threshold estimates.
* Rainfall threshold equation at `tau = 0.20`.
* Spatial maps of station-wise rainfall thresholds.
* Kernel density plots of station-wise rainfall threshold distribution.

## Recommended Run Order

1. Run `compute_api_crozier_all_lags.m` to calculate AMC/API values for all stations and antecedent lag windows.
2. Keep `crozier.m` in the same folder or add it to the MATLAB path before running the API calculation script.
3. Run `compute_at_site_ed_thresholds_ncquantreg.m` to derive station-wise E-D rainfall thresholds.
4. Keep `ncquantreg.m` in the same folder or add it to the MATLAB path before running the threshold calculation script.
5. Run `plot_threshold_spatial_map_kde.R` to visualize spatial and distributional variability in the rainfall thresholds.

## Required Software and Packages

### MATLAB

Required for:

* `compute_api_crozier_all_lags.m`
* `crozier.m`
* `compute_at_site_ed_thresholds_ncquantreg.m`
* `ncquantreg.m`

Main MATLAB requirements:

* Base MATLAB
* Optimization functions
* Excel and text file reading/writing functions

### R

Required for:

* `plot_threshold_spatial_map_kde.R`

Required R packages:

* `sf`
* `ggplot2`
* `readxl`
* `dplyr`
* `viridis`
* `grid`

## Notes on Reproducibility

* AMC/API is calculated using the Crozier antecedent rainfall formulation.
* The decay factor is defined inside the API calculation script and should be kept consistent with the manuscript methodology.
* Multiple antecedent lag windows are evaluated to support lag-sensitive AMC/API analysis.
* The at-site optimal lag is used in subsequent manuscript analyses.
* E-D thresholds are estimated using non-crossing quantile regression.
* The manuscript-focused threshold is estimated at `tau = 0.20`.
* The 3-day rainfall threshold represents the 72 h rainfall accumulation scale used for short-term MDL threshold diagnostics.
* Users should verify station IDs, folder paths, file names, metadata columns, and analysis periods before running.

## Assumptions and Methodological Notes

* AMC/API represents rainfall-derived antecedent wetness prior to the MDL-associated triggering rainfall endpoint.
* The antecedent window ends on the last day of the triggering rainfall event.
* Missing early-window rainfall values are padded with zero rainfall where required.
* TR represents the rainfall episode directly associated with the MDL event.
* E-D thresholds are rainfall-derived and do not directly include root-zone effective saturation (`S_eff`).
* Non-crossing quantile regression is used to avoid physically inconsistent crossing among quantile threshold curves.
* The threshold outputs from this folder provide the rainfall-based reference conditions for comparison with `S_eff`, ADF, `G_AMC/G_TR`, JEP, AR, wetness-conditioned likelihood, and LEWS-related analyses.

## Citation / Credit Statement

Codes were developed by Danish Monga under the guidance of Dr. Poulomi Ganguli.
