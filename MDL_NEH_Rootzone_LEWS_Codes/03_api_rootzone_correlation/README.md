# 03_api_rootzone_correlation

## Folder Title

API–Root-Zone Wetness Correlation Analysis

## Purpose of the Folder

This folder contains MATLAB scripts used to evaluate the association between rainfall-derived antecedent moisture condition, represented by the antecedent precipitation index (API), and GLEAM-based root-zone effective saturation (`S_eff`) on moisture-driven landslide (MDL) days across the Northeastern Himalayas (NEH).

## Scientific Relevance to the Manuscript

The scripts support the manuscript’s assessment of whether API, used as a rainfall-derived proxy for antecedent moisture condition (AMC), is consistent with root-zone wetness represented by `S_eff`.

This analysis helps determine whether rainfall-based AMC/API and root-zone soil saturation provide overlapping or complementary information for wetness-conditioned MDL likelihood estimation and landslide early warning system (LEWS) development.

## Scripts Included

1. `compute_kendall_tau_api_rootzone_metrics.m`
2. `compute_kendall_tau_api_seff0_seff1.m`

## Brief Description of Scripts

### `compute_kendall_tau_api_rootzone_metrics.m`

Computes Kendall’s tau between API and three root-zone wetness metrics on MDL days:

* median `S_eff[T_opt]`
* lag-1 `S_eff[1]`
* event-day `S_eff[0]`

The script generates station-wise Kendall’s tau values, p-values, pooled “All NEH” statistics, sample sizes, and a grouped bar plot comparing API–`S_eff` associations across the three root-zone wetness metrics.

### `compute_kendall_tau_api_seff0_seff1.m`

Computes Kendall’s tau between API and two near-event root-zone wetness metrics:

* lag-1 `S_eff[1]`
* event-day `S_eff[0]`

This script provides a focused comparison of API with near-failure root-zone saturation conditions.

## Required Input Files

The scripts require the following input files:

* NEH station metadata file containing station name, station ID, and optimal antecedent lag.
* Station-wise MDL event files.
* Station-wise API files calculated at the optimal antecedent lag.
* Station-wise GLEAM-derived root-zone effective saturation files.
* Daily `S_eff` files containing median `S_eff[T_opt]`, `S_eff[1]`, and `S_eff[0]`.

File paths are defined inside the scripts and should be updated by the user before running.

## Expected Output Files

The scripts generate the following outputs:

* Station-wise Kendall’s tau and p-value tables.
* Pooled “All NEH” Kendall’s tau and p-value estimates.
* Sample size information for each API–`S_eff` comparison.
* Grouped bar plots showing API–root-zone wetness association across stations.
* Summary Excel files for manuscript or supplementary-table use.

## Recommended Run Order

1. Ensure that station-wise MDL event files are available.
2. Ensure that API files have been generated at the station-specific optimal antecedent lag.
3. Ensure that station-wise GLEAM-derived `S_eff` files are available and aligned with MDL event dates.
4. Run `compute_kendall_tau_api_rootzone_metrics.m` for the full API–root-zone wetness comparison using median `S_eff[T_opt]`, `S_eff[1]`, and `S_eff[0]`.
5. Run `compute_kendall_tau_api_seff0_seff1.m` for the focused near-event comparison using `S_eff[1]` and `S_eff[0]`.

## Required Software and Packages

### MATLAB

Required for both scripts.

Main MATLAB requirements:

* Base MATLAB
* `readtable`
* `readmatrix`
* `datetime`
* `innerjoin`
* `corr`
* `writetable`
* `exportgraphics`

No additional external MATLAB package is required for these scripts.

## Notes on Reproducibility

* The analysis period is defined inside the scripts and should be kept consistent with the manuscript period.
* Station IDs and optimal antecedent lags are read from the NEH station metadata file.
* API files must correspond to the station-specific optimal antecedent lag (`T_opt`).
* Root-zone effective saturation files must be aligned with daily MDL dates.
* The pooled “All NEH” statistics are calculated by combining event-wise values across all stations.
* Users should verify file paths, station ID formatting, metadata column names, and date alignment before running.

## Assumptions and Methodological Notes

* API is treated as a rainfall-derived proxy for antecedent moisture condition (AMC).
* `S_eff` represents GLEAM-derived root-zone effective saturation.
* `S_eff[0]` represents event-day root-zone effective saturation.
* `S_eff[1]` represents lag-1 root-zone effective saturation.
* median `S_eff[T_opt]` represents root-zone wetness over the station-specific optimal antecedent window.
* Kendall’s tau is used as a non-parametric rank-based measure of monotonic association.
* The analysis is restricted to MDL days within the selected study period.
* These outputs are used to interpret whether API and root-zone wetness provide complementary information for wetness-conditioned MDL likelihood, JEP, and LEWS-related diagnostics.

## Citation / Credit Statement

Codes were developed by Danish Monga under the guidance of Dr. Poulomi Ganguli.
