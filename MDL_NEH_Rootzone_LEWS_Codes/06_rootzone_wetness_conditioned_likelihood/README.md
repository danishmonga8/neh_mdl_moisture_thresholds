# 06_rootzone_wetness_conditioned_likelihood

## Folder Title

Root-Zone Wetness-Conditioned MDL Likelihood

## Purpose of the Folder

This folder contains MATLAB scripts used to estimate moisture-driven landslide (MDL) likelihood conditioned on rainfall magnitude and root-zone effective saturation (`S_eff`) across the Northeastern Himalayas (NEH).

The scripts evaluate how 3-day rainfall accumulation (`E3`) and lag-1 root-zone wetness jointly condition MDL occurrence, and also compute rainfall-only likelihood across station-specific rainfall-severity classes.

## Scientific Relevance to the Manuscript

The scripts support the manuscript’s wetness-conditioned likelihood analysis by quantifying how elevated root-zone wetness modifies MDL likelihood beyond rainfall-only conditioning.

The outputs are used to compare MDL likelihood under rainfall-only conditions with likelihood conditioned jointly on rainfall threshold exceedance and lagged root-zone effective saturation. This supports the manuscript’s LEWS-oriented argument that root-zone wetness can refine rainfall-threshold-based MDL prediction.

## Scripts Included

1. `compute_binned_mdl_likelihood_rainfall_seff.m`
2. `compute_fig9b_pooled_rainfall_severity_likelihood.m`

## Brief Description of Scripts

### `compute_binned_mdl_likelihood_rainfall_seff.m`

Computes station-wise conditional MDL likelihood using 3-day rainfall threshold exceedance and lag-1 root-zone effective saturation class.

The script estimates:

`P(MDL | X, Y) = N_MDL(X, Y) / N(X, Y)`

where `X` represents 3-day rainfall (`E3`) exceeding an at-site rainfall threshold, and `Y` represents lag-1 `S_eff` falling within a defined root-zone wetness class.

### `compute_fig9b_pooled_rainfall_severity_likelihood.m`

Computes pooled rainfall-only MDL likelihood across station-specific `E3` rainfall-severity classes.

The script estimates:

`P(MDL | rainfall severity class) = N(MDL days in class) / N(rainfall days in class)`

This output provides the rainfall-only reference likelihood used for comparison with root-zone wetness-conditioned likelihood.

## Required Input Files

The scripts require the following input files:

* NEH station metadata file.
* Station-wise threshold table from the E-D rainfall threshold workflow.
* Threshold-applied station-wise rainfall files.
* Station-wise GLEAM-derived root-zone effective saturation (`S_eff`) time series.
* Station-wise MDL date files.
* Station-specific `E3` threshold columns such as `E3_P05`, `E3_P10`, ..., `E3_P90`.

File paths are defined inside the scripts and should be updated by the user before running.

## Expected Output Files

The scripts generate the following outputs:

* Station-wise binned MDL likelihood tables.
* Conditional likelihood estimates for rainfall threshold exceedance and lag-1 `S_eff` classes.
* Counts of all rainfall–`S_eff` class combinations.
* Counts of MDL days within each rainfall–`S_eff` class.
* Pooled rainfall-only MDL likelihood table.
* Rainfall-severity class diagnostics.
* Lists of used and skipped stations.
* Excel outputs suitable for manuscript figures and supplementary diagnostics.

## Recommended Run Order

1. Ensure that rainfall E-D threshold outputs are available.
2. Ensure that threshold-applied daily rainfall files are available.
3. Ensure that station-wise `S_eff` time series are available and date-aligned with rainfall data.
4. Ensure that station-wise MDL date files are available.
5. Run `compute_binned_mdl_likelihood_rainfall_seff.m` to calculate station-wise wetness-conditioned MDL likelihood.
6. Run `compute_fig9b_pooled_rainfall_severity_likelihood.m` to calculate pooled rainfall-only MDL likelihood across rainfall-severity classes.

## Required Software and Packages

### MATLAB

Required for both scripts.

Main MATLAB requirements:

* Base MATLAB
* `readtable`
* `writetable`
* `datetime`
* `innerjoin`
* `movsum`
* `discretize`
* `accumarray`
* `prctile`

No additional external MATLAB package is required for this folder.

## Notes on Reproducibility

* The analysis period is defined inside each script and should be kept consistent with the manuscript.
* The rainfall-day threshold is set to 2.5 mm day⁻¹, consistent with the IMD rainy-day definition used in the manuscript.
* `E3` is calculated as the 3-day accumulated rainfall ending on the current day.
* Lag-1 `S_eff` is calculated as the root-zone effective saturation one day before the evaluation day.
* Rainfall-severity classes are based on station-specific `E3` threshold values.
* Users should verify file paths, station IDs, threshold column names, and date alignment before running.

## Assumptions and Methodological Notes

* `E3` represents sub-weekly rainfall accumulation relevant for short-term MDL triggering.
* `S_eff_lag1` represents near-failure root-zone wetness one day before the evaluation day.
* The wetness-conditioned likelihood is computed using joint rainfall-threshold and `S_eff` class combinations.
* Root-zone wetness classes follow the manuscript-defined `S_eff` bins:

  * 0.65–0.75
  * 0.75–0.85
  * 0.85–0.95
  * ≥0.95
* Rainfall-only likelihood is computed separately to provide a reference condition.
* The comparison between rainfall-only and wetness-conditioned likelihood supports interpretation of how root-zone saturation modifies MDL probability.
* These outputs are intended for manuscript figures and LEWS-oriented threshold refinement.

## Citation / Credit Statement

Codes were developed by Danish Monga under the guidance of Dr. Poulomi Ganguli.
