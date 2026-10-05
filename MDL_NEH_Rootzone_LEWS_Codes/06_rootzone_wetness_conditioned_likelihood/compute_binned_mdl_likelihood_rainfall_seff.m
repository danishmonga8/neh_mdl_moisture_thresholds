clc; clear; close all;

%% ============================================================
%  Binned MDL Likelihood Using Rainfall Thresholds and Root-zone Wetness
%
%  Purpose:
%  This script estimates the conditional likelihood of moisture-driven
%  landslides (MDLs) for each station using:
%
%  1. 3-day rainfall threshold exceedance
%  2. Lag-1 root-zone effective saturation class
%
%  Formula:
%
%  P(MDL | X,Y) = N_MDL(X,Y) / N(X,Y)
%
%  where:
%  X = E3 > selected at-site 3-day rainfall threshold
%  Y = S_eff,lag1 falls within a root-zone wetness class
%
%  E3:
%  3-day accumulated rainfall ending on the current day.
%
%  S_eff,lag1:
%  Root-zone effective saturation one day before the evaluation day.
%
%  Output:
%  One Excel file with one sheet per station.
%% ============================================================


%% ================= USER SETTINGS =================

base_folder = "C:\lews_2022-2024\3_new_stations_neh_new\";

meta_file = fullfile(base_folder, "all_stations_neh.xlsx");
threshold_file = fullfile(base_folder, "Final_Threshold_Output.xlsx");

output_file = fullfile(base_folder, ...
    "binned_mdl_likelihood_rainfall_seff_all_stations.xlsx");

% Analysis period
start_date = datetime(2007,1,1);
end_date   = datetime(2019,12,31);   % Change to 2021 if final data are available

% Rainfall-day definition
% Use 2.5 mm/day to match the IMD rainy-day definition used in the manuscript.
rain_day_threshold = 2.5;

% Root-zone effective saturation classes used in the manuscript:
% S1: 0.65–0.75
% S2: 0.75–0.85
% S3: 0.85–0.95
% S4: >= 0.95
S_edges = [0.65 0.75 0.85 0.95 inf];


%% ================= READ METADATA AND THRESHOLDS =================

Meta = readtable(meta_file);
station_ids = Meta.IMD;

Thresholds = readtable(threshold_file);

% Select all 3-day E-D rainfall threshold columns.
all_columns = Thresholds.Properties.VariableNames;
is_E3_column = startsWith(all_columns, "E3_P");

E3_column_names = all_columns(is_E3_column);

fprintf("Processing %d stations...\n", numel(station_ids));


%% ================= DELETE OLD OUTPUT FILE =================

if exist(output_file, "file") == 2
    delete(output_file);
end


%% ================= LOOP THROUGH STATIONS =================

for i = 1:numel(station_ids)

    station_id = station_ids(i);
    station_name = string(station_id);

    fprintf("\nProcessing station %s (%d of %d)\n", ...
        station_name, i, numel(station_ids));


    %% ---------- Input file paths ----------

    rainfall_file = fullfile(base_folder, ...
        "3_rainfall_events_thresholds", ...
        "rainfall_data_threshold_applied", ...
        station_name + ".txt");

    seff_file = fullfile(base_folder, ...
        "10_soil_moisture_extraction", ...
        "effective_saturation_time_series_all_stations", ...
        "effective_saturation_time_series_all_stations", ...
        station_name + "_SMrz_Seff.txt");

    landslide_file = fullfile(base_folder, ...
        "10_soil_moisture_extraction", ...
        "saturation_by_station", ...
        station_name + "_saturation.txt");


    %% ---------- Read station-specific E3 thresholds ----------

    row_id = Thresholds.IMD_ID == station_id;

    if ~any(row_id)
        warning("Threshold values missing for station %s. Skipping.", station_name);
        continue;
    end

    E3_threshold_values = Thresholds{row_id, is_E3_column};
    E3_threshold_values = E3_threshold_values(:)';

    n_thresholds = numel(E3_threshold_values);


    %% ---------- Read rainfall data ----------

    Rain = readtable(rainfall_file, "FileType", "text");
    Rain.Properties.VariableNames = {'Year','Month','Day','Rain_mm'};

    Rain.Date = datetime(Rain.Year, Rain.Month, Rain.Day);

    % E3 is the 3-day accumulated rainfall ending on the current day.
    Rain.E3_mm = movsum(Rain.Rain_mm, [2 0]);
    Rain.E3_mm(1:2) = NaN;

    Rain = Rain(Rain.Date >= start_date & Rain.Date <= end_date, :);


    %% ---------- Read root-zone effective saturation ----------

    Seff = readtable(seff_file, "FileType", "text");
    Seff.Properties.VariableNames(1:3) = {'Year','Month','Day'};

    Seff.Date = datetime(Seff.Year, Seff.Month, Seff.Day);

    % The last column is assumed to contain root-zone effective saturation.
    Seff.S_eff = Seff{:, width(Seff)};

    % Lag-1 root-zone wetness condition.
    Seff.S_eff_lag1 = [NaN; Seff.S_eff(1:end-1)];

    Seff = Seff(Seff.Date >= start_date & Seff.Date <= end_date, :);


    %% ---------- Read MDL dates ----------

    Landslide = readtable(landslide_file, "FileType", "text");
    Landslide.Properties.VariableNames(1:3) = {'Year','Month','Day'};

    MDL_dates = unique(datetime( ...
        Landslide.Year, Landslide.Month, Landslide.Day));


    %% ---------- Merge rainfall and S_eff data ----------

    T = innerjoin( ...
        Rain(:, {'Date','Rain_mm','E3_mm'}), ...
        Seff(:, {'Date','S_eff_lag1'}), ...
        "Keys", "Date");

    % Keep only valid 3-day rainfall and lag-1 S_eff values.
    T = T(~isnan(T.E3_mm) & ~isnan(T.S_eff_lag1), :);

    % Mark MDL days.
    T.MDL = ismember(T.Date, MDL_dates);

    % Evaluation dataset: rainy days only.
    T_eval = T(T.Rain_mm > rain_day_threshold & isfinite(T.Rain_mm), :);

    if isempty(T_eval)
        warning("No valid rainy evaluation days for station %s. Skipping.", station_name);
        continue;
    end

    N_eval_days = height(T_eval);
    N_MDL_days = sum(T_eval.MDL);

    fprintf("Evaluation days = %d, MDL days = %d\n", ...
        N_eval_days, N_MDL_days);


    %% ---------- Initialize output matrices ----------

    n_seff_bins = numel(S_edges) - 1;

    N_XY = zeros(n_seff_bins, n_thresholds);
    N_XY_MDL = zeros(n_seff_bins, n_thresholds);

    P_XY = nan(n_seff_bins, n_thresholds);
    P_MDL_given_XY = nan(n_seff_bins, n_thresholds);


    %% ---------- Compute binned conditional MDL likelihood ----------

    for j = 1:n_thresholds

        E3_threshold = E3_threshold_values(j);

        % X: high rainfall condition.
        X_high_rainfall = T_eval.E3_mm > E3_threshold;

        T_threshold = T_eval(X_high_rainfall, :);

        if isempty(T_threshold)
            continue;
        end

        % Y: lag-1 S_eff bin.
        S_bin_index = discretize(T_threshold.S_eff_lag1, S_edges);

        for b = 1:n_seff_bins

            Y_seff_bin = S_bin_index == b;

            N_XY(b,j) = sum(Y_seff_bin);

            if N_XY(b,j) == 0
                continue;
            end

            N_XY_MDL(b,j) = sum(T_threshold.MDL(Y_seff_bin));

            % P(X,Y): relative occurrence of rainfall-threshold exceedance
            % and S_eff bin among all rainy evaluation days.
            P_XY(b,j) = N_XY(b,j) / N_eval_days;

            % Direct conditional MDL likelihood:
            % P(MDL | X,Y) = N_MDL(X,Y) / N(X,Y)
            P_MDL_given_XY(b,j) = N_XY_MDL(b,j) / N_XY(b,j);

        end
    end


    %% ---------- Convert matrices to station-wise output table ----------

    [s_bin, e_idx] = ndgrid(1:n_seff_bins, 1:n_thresholds);

    OutTable = table( ...
        repmat(station_id, numel(s_bin), 1), ...
        s_bin(:), ...
        e_idx(:), ...
        S_edges(s_bin(:))', ...
        S_edges(s_bin(:)+1)', ...
        string(E3_column_names(e_idx(:)))', ...
        E3_threshold_values(e_idx(:))', ...
        N_XY(:), ...
        N_XY_MDL(:), ...
        P_XY(:), ...
        P_MDL_given_XY(:), ...
        'VariableNames', { ...
        'StationID', ...
        'S_eff_bin', ...
        'E3_threshold_index', ...
        'S_eff_low', ...
        'S_eff_high', ...
        'E3_threshold_name', ...
        'E3_threshold_mm', ...
        'N_XY', ...
        'N_XY_MDL', ...
        'P_XY', ...
        'P_MDL_given_XY'});

    % Remove empty combinations.
    OutTable = OutTable(OutTable.N_XY > 0, :);


    %% ---------- Save one sheet per station ----------

    writetable(OutTable, output_file, ...
        "Sheet", station_name, ...
        "WriteMode", "overwritesheet");

    fprintf("Saved sheet for station %s\n", station_name);

end


fprintf("\nAll stations processed successfully.\nOutput file:\n%s\n", output_file);