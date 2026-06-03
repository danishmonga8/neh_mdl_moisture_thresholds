# 07_rootzone_wetness_amplification_ratio

## Folder Title

Root-Zone Wetness Amplification Ratio Analysis

## Purpose of the Folder

This folder contains MATLAB and R scripts used to quantify and map how elevated root-zone effective saturation (`S_eff`) amplifies moisture-driven landslide (MDL) likelihood under high rainfall conditions across the Northeastern Himalayas (NEH).

The folder estimates rainfall-only MDL likelihood, wetness-conditioned MDL likelihood, and the root-zone wetness amplification ratio (AR).

## Scientific Relevance to the Manuscript

The scripts support the manuscript’s wetness-conditioned threshold refinement by quantifying whether elevated root-zone wetness increases MDL likelihood beyond rainfall-only conditioning.

The amplification ratio provides a site-wise measure of how much MDL likelihood changes when high 3-day rainfall accumulation is combined with elevated lag-1 root-zone effective saturation. This directly supports the manuscript’s LEWS-oriented interpretation of root-zone wetness as a preconditioning control on MDL occurrence.

## Scripts Included

1. `compute_rootzone_wetness_amplification_ratio.m`
2. `plot_rootzone_wetness_amplification_maps.R`

## Brief Description of Scripts

### `compute_rootzone_wetness_amplification_ratio.m`

Computes station-wise rainfall-only MDL likelihood, wetness-conditioned MDL likelihood, and the root-zone wetness amplification ratio.

The amplification ratio is calculated as:

`AR = P(MDL | R_high, S_eff[1] >= S_eff,80) / P(MDL | R_high)`

where `R_high` represents 3-day rainfall (`E3`) exceeding the at-site threshold, and `S_eff,80` represents the station-wise 80th percentile of lag-1 root-zone effective saturation.

### `plot_rootzone_wetness_amplification_maps.R`

Generates spatial maps of:

* rainfall-only MDL likelihood: `P(MDL | R_high)`
* wetness-conditioned MDL likelihood: `P(MDL | R_high, S_eff[1] >= S_eff,80)`
* root-zone wetness amplification ratio: `AR`

The maps show spatial variability in rainfall-only likelihood, wetness-conditioned likelihood, and amplification effects across NEH stations.

## Required Input Files

The scripts require the following input files:

* NEH station metadata file containing station ID, latitude, longitude, and station information.
* Station-wise E-D rainfall threshold table.
* Threshold-applied station-wise rainfall files.
* Station-wise GLEAM-derived root-zone effective saturation (`S_eff`) time series.
* Station-wise MDL date files.
* Root-zone wetness amplification summary table.
* Himalayan study-area shapefile.

File paths are defined inside the scripts and should be updated by the user before running.

## Expected Output Files

The scripts generate the following outputs:

* Station-wise rainfall-only MDL likelihood.
* Station-wise wetness-conditioned MDL likelihood.
* Station-wise 80th percentile of lag-1 `S_eff`.
* Number of high-rainfall cases.
* Number of joint high-rainfall and high-wetness cases.
* Root-zone wetness amplification ratio table.
* Spatial map of rainfall-only MDL likelihood.
* Spatial map of wetness-conditioned MDL likelihood.
* Spatial map of root-zone wetness amplification ratio.

## Recommended Run Order

1. Ensure that threshold-applied rainfall files are available.
2. Ensure that station-wise `S_eff` time series are available and date-aligned with rainfall data.
3. Ensure that station-wise MDL date files are available.
4. Ensure that the station-wise 3-day E-D rainfall threshold table is available.
5. Run `compute_rootzone_wetness_amplification_ratio.m` to calculate rainfall-only likelihood, wetness-conditioned likelihood, and AR.
6. Run `plot_rootzone_wetness_amplification_maps.R` to generate spatial maps of likelihood and amplification ratio.

## Required Software and Packages

### MATLAB

Required for:

* `compute_rootzone_wetness_amplification_ratio.m`

Main MATLAB requirements:

* Base MATLAB
* `readtable`
* `writetable`
* `datetime`
* `innerjoin`
* `movsum`
* `prctile`

### R

Required for:

* `plot_rootzone_wetness_amplification_maps.R`

Required R packages:

* `sf`
* `ggplot2`
* `readxl`
* `dplyr`
* `viridis`
* `scales`
* `grid`

## Notes on Reproducibility

* The analysis period is defined inside the scripts and should be kept consistent with the manuscript.
* The rainfall-day threshold is set to 2.5 mm day⁻¹, consistent with the IMD rainy-day definition used in the manuscript.
* `E3` is calculated as the 3-day accumulated rainfall ending on the current day.
* `S_eff[1]` represents lag-1 root-zone effective saturation.
* `S_eff,80` is calculated separately for each station using the 80th percentile of lag-1 `S_eff`.
* A minimum number of joint high-rainfall and high-wetness cases is required before reporting AR.
* Users should verify file paths, station IDs, threshold columns, shapefile paths, and date alignment before running.

## Assumptions and Methodological Notes

* `R_high` is defined as `E3` exceeding the at-site 3-day rainfall threshold.
* Elevated root-zone wetness is defined as `S_eff[1] >= S_eff,80`.
* Rainfall-only likelihood is calculated as `P(MDL | R_high)`.
* Wetness-conditioned likelihood is calculated as `P(MDL | R_high, S_eff[1] >= S_eff,80)`.
* `AR > 1` indicates that elevated root-zone wetness increases MDL likelihood relative to rainfall-only conditioning.
* `AR < 1` indicates lower MDL likelihood under the joint high-rainfall and high-wetness condition relative to rainfall-only conditioning.
* The amplification ratio should be interpreted together with the number of available joint cases.
* The outputs support manuscript figures and LEWS-oriented diagnostics of root-zone wetness amplification.

## Citation / Credit Statement

Codes were developed by Danish Monga under the guidance of Dr. Poulomi Ganguli.
