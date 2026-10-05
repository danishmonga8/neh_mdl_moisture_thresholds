# 0_1_data_processing

## Folder Title

Initial Data Processing for MDL Inventory, Rainfall Imputation, and Study-Area Diagnostics

## Purpose of the Folder

This folder contains scripts used to prepare the core input datasets for the moisture-driven landslide (MDL) analysis in the Northeastern Himalayas (NEH). The scripts support MDL inventory extraction, station-wise rainfall preprocessing, RegEM-based rainfall gap filling, rainfall threshold application, and preliminary study-area diagnostics.

## Scientific Relevance to the Manuscript

The outputs from this folder provide the standardized rainfall and MDL datasets required for subsequent analyses of triggering rainfall (TR), antecedent moisture condition represented by antecedent precipitation index (AMC/API), root-zone effective saturation (`S_eff`), event-duration (E-D) rainfall thresholds, wetness-conditioned MDL likelihood, joint exceedance probability (JEP), and landslide early warning system (LEWS)-oriented diagnostics.

This folder forms the first step of the manuscript workflow by preparing spatially and temporally consistent rainfall and landslide-event datasets before downstream threshold and probability-based analyses.

## Scripts Included

1. `extract_uglc_mdl_events_within_station_buffer.R`
2. `prepare_gridded_rainfall_predictors_for_regem.m`
3. `impute_station_rainfall_regem.m`
4. `apply_rainfall_threshold_to_filled_series.m`
5. `plot_bivariate_rainfall_temperature_climatology.m`
6. `plot_peak_mdl_probability_month_map_bar.R`

## Brief Description of Scripts

### `extract_uglc_mdl_events_within_station_buffer.R`

Extracts UGLC landslide records within a 30 km radius of each NEH rain-gauge station. The script retains moisture-driven events using hydrometeorological trigger information and removes records associated with non-hydrometeorological controls.

### `prepare_gridded_rainfall_predictors_for_regem.m`

Processes year-wise IMD gridded rainfall data and converts them into continuous daily lon-lat rainfall time series for the NEH domain. These gridded rainfall series are used as predictor fields for RegEM-based gap filling of station rainfall records.

### `impute_station_rainfall_regem.m`

Fills missing daily at-site IMD rainfall values using nearby gridded rainfall predictors and the Regularized Expectation–Maximization (RegEM) algorithm. The imputation is performed season-wise to preserve seasonal rainfall variability.

### `apply_rainfall_threshold_to_filled_series.m`

Applies the manuscript rainfall-day threshold to the filled station-wise rainfall series. Daily rainfall values below the selected threshold are treated as non-rainfall days and set to zero.

### `plot_bivariate_rainfall_temperature_climatology.m`

Generates a bivariate rainfall-temperature climatology map for the NEH study region and prepares regional summary statistics for hydroclimatic interpretation.

### `plot_peak_mdl_probability_month_map_bar.R`

Generates station-wise diagnostics showing the peak month of MDL probability across the NEH study region.

## Required Input Files

The folder requires the following input datasets, depending on the script:

* NEH station metadata file containing station ID, latitude, longitude, and related station attributes.
* UGLC landslide inventory file.
* Station-wise observed daily IMD rainfall files.
* Year-wise IMD gridded rainfall files.
* Nearest-grid information for each station.
* RegEM package folder.
* Filled station-wise rainfall files.
* Rainfall and temperature climatology NetCDF files.
* Study-area shapefile.
* River shapefile.

File paths are specified inside the scripts and should be updated by the user before running.

## Expected Output Files

The scripts generate the following types of outputs:

* Station-wise MDL event files extracted within the 30 km station buffer.
* Summary file of UGLC-based MDL events within the station buffer.
* Daily gridded rainfall predictor files.
* Gridded rainfall summary files.
* RegEM-filled station rainfall files.
* Original unfilled station rainfall files.
* Threshold-applied daily rainfall files.
* Study-area climatology figure and summary table.
* Station-wise diagnostics of peak MDL probability month.

## Recommended Run Order

1. Run `extract_uglc_mdl_events_within_station_buffer.R` to prepare station-wise MDL inventory files.
2. Run `prepare_gridded_rainfall_predictors_for_regem.m` to prepare gridded rainfall predictor files.
3. Run `impute_station_rainfall_regem.m` to fill missing station rainfall data using RegEM.
4. Run `apply_rainfall_threshold_to_filled_series.m` to prepare threshold-applied daily rainfall series.
5. Run `plot_bivariate_rainfall_temperature_climatology.m` for study-area hydroclimatic diagnostics.
6. Run `plot_peak_mdl_probability_month_map_bar.R` for peak MDL probability month diagnostics.

## Required Software and Packages

### MATLAB

Required for:

* `prepare_gridded_rainfall_predictors_for_regem.m`
* `impute_station_rainfall_regem.m`
* `apply_rainfall_threshold_to_filled_series.m`
* `plot_bivariate_rainfall_temperature_climatology.m`

Main MATLAB requirements:

* Base MATLAB
* Mapping-related functions for shapefile handling
* NetCDF reading functions
* RegEM package

### R

Required for:

* `extract_uglc_mdl_events_within_station_buffer.R`
* `plot_peak_mdl_probability_month_map_bar.R`

Required R packages:

* `data.table`
* `readxl`
* `openxlsx`
* `geosphere`
* `sf`
* `ggplot2`
* `RColorBrewer`
* `dplyr`
* `stringi` optional but recommended

## Notes on Reproducibility

* The scripts use fixed processing rules and user-defined analysis periods.
* Station-wise MDL extraction is based on a 30 km buffer around each NEH station.
* Missing station rainfall values are filled using RegEM with nearby gridded rainfall predictors.
* The rainfall-day threshold should be kept consistent with the manuscript definition.
* Users should verify all input paths, file names, station IDs, and metadata column structures before running the scripts.
* The outputs from this folder should be checked before proceeding to TR, AMC/API, `S_eff`, ADF, `G_AMC/G_TR`, JEP, wetness-conditioned likelihood, and LEWS-related analyses.

## Assumptions and Methodological Notes

* MDLs are identified using hydrometeorological trigger information from the landslide inventory.
* Landslide records associated with seismic, anthropogenic, unknown, or other non-hydrometeorological controls are excluded.
* Station-wise MDL events are extracted within a fixed 30 km radius of rain-gauge stations.
* IMD gridded rainfall data are used as predictor fields for RegEM-based gap filling of at-site rainfall records.
* A rainy day is defined using the manuscript rainfall-day threshold.
* Threshold-applied rainfall series are used for subsequent TR extraction, AMC/API calculation, and E-D rainfall threshold estimation.
* This folder prepares the baseline rainfall and MDL datasets required for the manuscript’s wetness-conditioned, at-site LEWS framework.

## Citation / Credit Statement

Codes were developed by Danish Monga under the guidance of Dr. Poulomi Ganguli.
