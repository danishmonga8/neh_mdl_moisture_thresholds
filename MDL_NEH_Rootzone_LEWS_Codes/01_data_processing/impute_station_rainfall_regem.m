clc; clear; close all;

%% ============================================================
%  Rainfall Gap Filling using RegEM
%
%  Purpose:
%  This script fills missing daily at-site rainfall records using
%  nearby gridded rainfall predictors and the RegEM algorithm.
%
%  Input:
%  1. Station rainfall data:
%     Year Month Day Rainfall
%
%  2. Nearby gridded rainfall predictors:
%     Year Month Day Rainfall
%
%  Method:
%  For each station, missing rainfall is filled season-wise.
%  The first column of the RegEM input matrix is the at-site rainfall,
%  and the remaining columns are nearby gridded rainfall predictors.
%
%  Seasons:
%  Winter  : January–March
%  Summer  : April–May
%  Monsoon : June–September
%  Fall    : October–December
%
%  Output:
%  1. Filled rainfall time series
%  2. Original unfilled rainfall time series
%
%  Output format:
%  Year Month Day Rainfall
%% ============================================================


%% ================= USER SETTINGS =================

base_folder = "C:\lews_2022-2024\3_new_stations_neh_new\";

% RegEM package folder
regem_folder = fullfile(base_folder, ...
    "2_data_preprocessing", ...
    "filled_data_imd", ...
    "RegEM-master");

addpath(regem_folder);

station_metadata_file = fullfile(base_folder, ...
    "meta_data_new_neh.csv");

station_rainfall_folder = fullfile(base_folder, ...
    "datafiles", ...
    "org_data");

nearest_grid_folder = fullfile(base_folder, ...
    "2_data_preprocessing", ...
    "data_prep_for_regEM", ...
    "nearest_grids");

gridded_rainfall_folder = fullfile(base_folder, ...
    "2_data_preprocessing", ...
    "data_prep_for_regEM", ...
    "gridded_data_lat_long_gridded");

output_root = fullfile(base_folder, ...
    "2_data_preprocessing", ...
    "filled_data_imd");

filled_output_folder = fullfile(output_root, ...
    "filled_missing");

unfilled_output_folder = fullfile(output_root, ...
    "unfilled_station");

if ~exist(filled_output_folder, "dir")
    mkdir(filled_output_folder);
end

if ~exist(unfilled_output_folder, "dir")
    mkdir(unfilled_output_folder);
end

% Analysis period
start_date = datetime(1980,1,1);
end_date   = datetime(2019,12,31);   % Change to 2021 if final data are available

% RegEM options
OPTIONS = struct( ...
    "regress", "mridge", ...
    "maxit", 100);

% Very small rainfall values after filling are treated as zero
rain_min_threshold = 0.1;


%% ================= READ STATION METADATA =================

StationMeta = readtable(station_metadata_file);

% Expected: first numeric column contains WMO/IMD station ID
station_ids = StationMeta{:,1};

n_stations = numel(station_ids);

fprintf("Number of stations found: %d\n", n_stations);


%% ================= MAIN LOOP OVER STATIONS =================

for idx = 1:n_stations

    WMO_ID = station_ids(idx);

    fprintf("\n============================================\n");
    fprintf("Processing station %d of %d | WMO = %d\n", ...
        idx, n_stations, WMO_ID);
    fprintf("============================================\n");


    %% ---------- Input files ----------

    station_rainfall_file = fullfile(station_rainfall_folder, ...
        sprintf("%05d.txt", WMO_ID));

    nearest_grid_file = fullfile(nearest_grid_folder, ...
        sprintf("coolr%d.txt", WMO_ID));


    %% ---------- Read station rainfall ----------

    StationRain = readmatrix(station_rainfall_file);

    station_date = datetime( ...
        StationRain(:,1), ...
        StationRain(:,2), ...
        StationRain(:,3));

    station_rain = StationRain(:,4);

    T_station_raw = table(station_date, station_rain, ...
        "VariableNames", {'Date','Rain'});


    %% ---------- Create complete daily time series ----------

    full_dates = (start_date:caldays(1):end_date)';

    T_full = table(full_dates, ...
        "VariableNames", {'Date'});

    T_station = outerjoin(T_full, T_station_raw, ...
        "Keys", "Date", ...
        "MergeKeys", true);

    T_station = sortrows(T_station, "Date");

    Station_Unfilled = [ ...
        year(T_station.Date), ...
        month(T_station.Date), ...
        day(T_station.Date), ...
        T_station.Rain];


    %% ---------- Read nearby gridded rainfall predictors ----------

    NearGrid = readmatrix(nearest_grid_file);

    GriddedRain_All = [];
    grid_counter = 0;

    for g = 1:size(NearGrid,1)

        Lon = NearGrid(g,1);
        Lat = NearGrid(g,2);

        grid_file = fullfile(gridded_rainfall_folder, ...
            sprintf("dly_precip_%2.2f_&_%2.2f.txt", Lon, Lat));

        if ~isfile(grid_file)
            warning("Grid file not found: %s", grid_file);
            continue;
        end

        GridRain = readmatrix(grid_file);

        grid_date = datetime( ...
            GridRain(:,1), ...
            GridRain(:,2), ...
            GridRain(:,3));

        grid_rain = GridRain(:,end);

        T_grid_raw = table(grid_date, grid_rain, ...
            "VariableNames", {'Date','Rain'});

        T_grid = outerjoin(T_full, T_grid_raw, ...
            "Keys", "Date", ...
            "MergeKeys", true);

        T_grid = sortrows(T_grid, "Date");

        grid_counter = grid_counter + 1;
        GriddedRain_All(:,grid_counter) = T_grid.Rain;

    end

    if isempty(GriddedRain_All)
        warning("No valid gridded predictors found for station %d. Skipping.", WMO_ID);
        continue;
    end


    %% ---------- Combine station and gridded rainfall ----------

    % First column = at-site station rainfall
    % Remaining columns = gridded rainfall predictors
    RainMatrix_All = [T_station.Rain, GriddedRain_All];

    Date_All = T_station.Date;
    Month_All = month(Date_All);


    %% ---------- Split data by season ----------

    idx_winter  = Month_All >= 1  & Month_All <= 3;
    idx_summer  = Month_All >= 4  & Month_All <= 5;
    idx_monsoon = Month_All >= 6  & Month_All <= 9;
    idx_fall    = Month_All >= 10 & Month_All <= 12;


    %% ---------- Fill missing rainfall using old RegEM function ----------

    FilledRain_All = nan(size(RainMatrix_All,1),1);

    % Winter
    Winter_MAT = RainMatrix_All(idx_winter,:);
    [Winter_Filled, ~] = regem(Winter_MAT, OPTIONS);
    Winter_Filled(Winter_Filled(:,1) < rain_min_threshold, 1) = 0;
    FilledRain_All(idx_winter) = Winter_Filled(:,1);

    % Summer
    Summer_MAT = RainMatrix_All(idx_summer,:);
    [Summer_Filled, ~] = regem(Summer_MAT, OPTIONS);
    Summer_Filled(Summer_Filled(:,1) < rain_min_threshold, 1) = 0;
    FilledRain_All(idx_summer) = Summer_Filled(:,1);

    % Monsoon
    Monsoon_MAT = RainMatrix_All(idx_monsoon,:);
    [Monsoon_Filled, ~] = regem(Monsoon_MAT, OPTIONS);
    Monsoon_Filled(Monsoon_Filled(:,1) < rain_min_threshold, 1) = 0;
    FilledRain_All(idx_monsoon) = Monsoon_Filled(:,1);

    % Fall
    Fall_MAT = RainMatrix_All(idx_fall,:);
    [Fall_Filled, ~] = regem(Fall_MAT, OPTIONS);
    Fall_Filled(Fall_Filled(:,1) < rain_min_threshold, 1) = 0;
    FilledRain_All(idx_fall) = Fall_Filled(:,1);


    %% ---------- Final filled rainfall output ----------

    Filled_Output = [ ...
        year(Date_All), ...
        month(Date_All), ...
        day(Date_All), ...
        FilledRain_All];


    %% ---------- Save outputs ----------

    filled_file = fullfile(filled_output_folder, ...
        sprintf("%05d_Prcp_filled.txt", WMO_ID));

    unfilled_file = fullfile(unfilled_output_folder, ...
        sprintf("%05d_Prcp_unfilled.txt", WMO_ID));

    writematrix(Filled_Output, filled_file, ...
        "Delimiter", "tab");

    writematrix(Station_Unfilled, unfilled_file, ...
        "Delimiter", "tab");

    fprintf("Saved filled rainfall file:\n%s\n", filled_file);
    fprintf("Saved unfilled rainfall file:\n%s\n", unfilled_file);

end

fprintf("\nRegEM rainfall imputation completed for all stations.\n");