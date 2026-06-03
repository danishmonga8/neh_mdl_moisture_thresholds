# 04_adf_&_gini_calculation

## Folder Title

Antecedent Dominance Fraction and Gini Ratio Calculation

## Purpose of the Folder

This folder contains MATLAB scripts used to quantify the relative dominance of antecedent moisture condition (AMC/API) and triggering rainfall (TR) in moisture-driven landslide (MDL) occurrence across the Northeastern Himalayas (NEH).

The folder calculates the Antecedent Dominance Fraction (ADF), evaluates the annual temporal concentration of TR and AMC using Lorenz curves and Gini coefficients, and generates diagnostic plots linking ADF with ideal antecedent lag and rainfall thresholds.

## Scientific Relevance to the Manuscript

The scripts support the manuscript’s analysis of antecedent wetness control on MDLs. ADF is used to identify sites where antecedent wetness dominates over TR, while the Gini ratio (`G_AMC/G_TR`) is used to compare the annual temporal concentration of AMC relative to TR.

Together, ADF and `G_AMC/G_TR` provide complementary diagnostics: ADF captures event-wise dominance of AMC over TR, whereas the Gini ratio captures interannual unevenness in AMC and TR contributions.

## Scripts Included

1. `compute_adf_from_tr_amc_events.m`
2. `compute_plot_lorenz_gini_tr_amc_all_stations.m`
3. `example_lorenz_gini_darjeeling.m`
4. `lorenzGini.m`
5. `adf_vs_ideal_lag_quadrants.m`
6. `plot_adf_vs_3day_threshold_tau20.m`
7. `cleanWMO.m`
8. `resolveWmoFile.m`

## Brief Description of Scripts

### `compute_adf_from_tr_amc_events.m`

Computes the Antecedent Dominance Fraction (ADF) for each NEH station using MDL event dates, TR, and AMC/API at the station-specific optimal antecedent lag.

ADF is calculated as:

`ADF = N(AMC > TR) / N(total eligible MDL events)`

where eligible MDL events are those for which both AMC and TR values are available.

### `compute_plot_lorenz_gini_tr_amc_all_stations.m`

Computes station-wise Lorenz curves and Gini coefficients for annual TR and AMC totals associated with MDL events. The script calculates the Gini ratio:

`G_AMC/G_TR = G_AMC / G_TR`

Values greater than 1 indicate that AMC is more annually concentrated than TR, whereas values less than 1 indicate that TR is more annually concentrated than AMC.

### `example_lorenz_gini_darjeeling.m`

Provides a station-specific example of Lorenz curve and Gini ratio calculation for Darjeeling. This script is useful for checking the annual TR–AMC aggregation, Lorenz curve construction, and interpretation of `G_AMC/G_TR`.

### `lorenzGini.m`

Helper function used to calculate Lorenz curve coordinates and the Gini coefficient from annual TR or AMC totals.

### `adf_vs_ideal_lag_quadrants.m`

Generates a quadrant-based diagnostic plot between ADF and ideal antecedent lag. The plot classifies stations based on whether ADF is above or below 0.50 and whether the ideal antecedent lag is shorter or longer than 15 days.

### `plot_adf_vs_3day_threshold_tau20.m`

Plots the relationship between ADF and the station-wise 3-day rainfall threshold derived at `tau = 0.20`. Kendall’s tau is used to assess the rank-based association between antecedent dominance and rainfall threshold magnitude.

### `cleanWMO.m`

Helper function used to clean WMO/station IDs by removing unnecessary spaces, decimal endings, and non-alphanumeric characters.

### `resolveWmoFile.m`

Helper function used to construct and resolve station-specific input file paths for MDL, TR, and AMC/API files.

## Required Input Files

The scripts require the following input files:

* NEH station metadata file containing station name, station ID, latitude, longitude, and ideal antecedent lag.
* Station-wise MDL event files.
* Station-wise TR files.
* Station-wise AMC/API files calculated at the station-specific optimal lag.
* Station-wise ADF summary file.
* Station-wise 3-day rainfall threshold file at `tau = 0.20`.
* Output from the rainfall E-D threshold calculation workflow.

File paths are defined inside the scripts and should be updated by the user before running.

## Expected Output Files

The scripts generate the following outputs:

* Station-wise ADF summary table.
* Classification of stations as AMC-dominant, TR-dominant, balanced, or unavailable.
* Annual TR and AMC totals.
* Station-wise Lorenz curve and Gini coefficient summary.
* `G_AMC/G_TR` ratio table.
* Lorenz curve figures for TR and AMC.
* Darjeeling example Lorenz–Gini output.
* ADF versus ideal antecedent lag quadrant plot.
* ADF versus 3-day rainfall threshold diagnostic plot.

## Recommended Run Order

1. Ensure that station-wise MDL, TR, and AMC/API files are available.
2. Ensure that AMC/API files correspond to the station-specific optimal antecedent lag.
3. Run `compute_adf_from_tr_amc_events.m` to calculate station-wise ADF.
4. Run `compute_plot_lorenz_gini_tr_amc_all_stations.m` to calculate Lorenz curves, Gini coefficients, and `G_AMC/G_TR`.
5. Run `example_lorenz_gini_darjeeling.m` if a station-specific example is required for checking or illustration.
6. Run `adf_vs_ideal_lag_quadrants.m` to examine the relationship between ADF and ideal antecedent lag.
7. Run `plot_adf_vs_3day_threshold_tau20.m` to assess the association between ADF and the 3-day rainfall threshold at `tau = 0.20`.

Helper functions `cleanWMO.m`, `resolveWmoFile.m`, and `lorenzGini.m` should remain in the same folder or be added to the MATLAB path.

## Required Software and Packages

### MATLAB

Required for all scripts in this folder.

Main MATLAB requirements:

* Base MATLAB
* `readtable`
* `readmatrix`
* `datetime`
* `innerjoin`
* `groupsummary`
* `corr`
* `polyfit`
* `writetable`
* `exportgraphics`

No additional external MATLAB package is required for this folder.

## Notes on Reproducibility

* The analysis period is defined inside the scripts and should be kept consistent with the manuscript.
* Station IDs are cleaned using `cleanWMO.m` to avoid mismatch caused by formatting differences.
* Station-specific files are resolved using `resolveWmoFile.m`.
* Multiple MDL records occurring on the same date are retained as separate MDL events, consistent with the event-record-based analysis.
* If AMC or TR files contain repeated dates, daily values are summarized using the median to avoid duplicate-date bias.
* Users should verify station IDs, file naming conventions, date ranges, and metadata column positions before running.

## Assumptions and Methodological Notes

* ADF quantifies the fraction of eligible MDL events for which AMC/API exceeds TR.
* `ADF > 0.50` indicates more frequent AMC-dominant MDL events.
* `ADF < 0.50` indicates more frequent TR-dominant MDL events.
* `ADF = 0.50` indicates balanced AMC and TR dominance.
* Lorenz curves are constructed using annual TR and AMC totals associated with MDL events.
* `G_AMC/G_TR > 1` indicates stronger annual concentration of AMC than TR.
* `G_AMC/G_TR < 1` indicates stronger annual concentration of TR than AMC.
* ADF and `G_AMC/G_TR` should be interpreted together because they describe different aspects of antecedent wetness control.
* The outputs from this folder support manuscript figures and diagnostics related to antecedent wetness dominance, temporal concentration, and rainfall-threshold variability.

## Citation / Credit Statement

Codes were developed by Danish Monga under the guidance of Dr. Poulomi Ganguli.
