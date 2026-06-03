clc; clear; close all;

%% ============================================================
%  Figure 9b: Pooled Rainfall-Severity MDL Likelihood
%
%  Purpose:
%  This script calculates pooled rain-only MDL likelihood across
%  station-specific E3 rainfall-severity classes.
%
%  Rainfall severity classes:
%  P05-P10, P10-P15, ..., P85-P90, and >=P90
%
%  Formula:
%  P(MDL | rainfall severity class)
%      = N(MDL days in class) / N(rainfall days in class)
%
%  Notes:
%  1. E3 is the 3-day rainfall accumulation ending on the current day.
%  2. Rainfall classes are based on station-specific E3 thresholds.
%  3. S_eff is used only to keep the same date support as the
%     wetness-conditioned analysis. It is not used in the rain-only
%     likelihood calculation.
%% ============================================================


%% ================= USER SETTINGS =================

base_folder = "C:\lews_2022-2024\3_new_stations_neh_new\";

metadata_file = fullfile(base_folder, ...
    "all_stations_neh.xlsx");

threshold_file = fullfile(base_folder, ...
    "Final_Threshold_Output.xlsx");

rainfall_folder = fullfile(base_folder, ...
    "3_rainfall_events_thresholds", ...
    "rainfall_data_threshold_applied");

seff_folder = fullfile(base_folder, ...
    "10_soil_moisture_extraction", ...
    "effective_saturation_time_series_all_stations", ...
    "effective_saturation_time_series_all_stations");

mdl_folder = fullfile(base_folder, ...
    "10_soil_moisture_extraction", ...
    "saturation_by_station");

output_folder = fullfile(base_folder, ...
    "6_rootzone_wetness_conditioned_likelihood", ...
    "outputs");

if ~exist(output_folder, "dir")
    mkdir(output_folder);
end

output_excel = fullfile(output_folder, ...
    "fig9b_pooled_rainfall_severity_likelihood.xlsx");

% Analysis period
start_date = datetime(2007,1,1);
end_date   = datetime(2019,12,31);   % Change if final manuscript uses 2021

% Rainfall-day threshold
rain_day_threshold_mm = 2.5;

% Rainfall severity thresholds used for Figure 9b
percentile_edges = 5:5:90;


%% ================= READ METADATA AND THRESHOLDS =================

Metadata = readtable(metadata_file, ...
    "VariableNamingRule", "preserve");

Metadata.Properties.VariableNames = ...
    matlab.lang.makeValidName(Metadata.Properties.VariableNames);

if ismember("IMD", string(Metadata.Properties.VariableNames))
    station_ids = Metadata.IMD;
elseif ismember("IMD_ID", string(Metadata.Properties.VariableNames))
    station_ids = Metadata.IMD_ID;
else
    error("Station ID column not found. Expected IMD or IMD_ID.");
end


Thresholds = readtable(threshold_file, ...
    "VariableNamingRule", "preserve");

Thresholds.Properties.VariableNames = ...
    matlab.lang.makeValidName(Thresholds.Properties.VariableNames);

if ~ismember("IMD_ID", string(Thresholds.Properties.VariableNames))
    error("Final_Threshold_Output.xlsx must contain IMD_ID column.");
end


%% ================= DEFINE RAINFALL-SEVERITY CLASSES =================

% Required threshold columns: E3_P05, E3_P10, ..., E3_P90
threshold_columns = strings(numel(percentile_edges),1);

for i = 1:numel(percentile_edges)
    threshold_columns(i) = sprintf("E3_P%02d", percentile_edges(i));
end

missing_columns = setdiff(threshold_columns, ...
    string(Thresholds.Properties.VariableNames));

if ~isempty(missing_columns)
    error("Missing threshold columns: %s", strjoin(missing_columns, ", "));
end

% Class labels: P05-P10, ..., P85-P90, >=P90
lowP  = percentile_edges(1:end-1);
highP = percentile_edges(2:end);

Class = strcat("P", string(lowP(:)), "-P", string(highP(:)));
Class = [Class; ">=P90"];

n_classes = numel(Class);


%% ================= INITIALIZE POOLED COUNTS =================

N_rain_days_class = zeros(n_classes,1);
N_MDL_days_class  = zeros(n_classes,1);

UsedStations = strings(0,1);
SkippedStations = strings(0,1);

StationDiagnostics = table();


%% ================= MAIN LOOP OVER STATIONS =================

for i = 1:numel(station_ids)

    station_id = station_ids(i);
    station_name = string(station_id);

    fprintf("\nProcessing station %s (%d of %d)\n", ...
        station_name, i, numel(station_ids));


    %% ---------- Input files ----------

    rainfall_file = fullfile(rainfall_folder, ...
        station_name + ".txt");

    seff_file = fullfile(seff_folder, ...
        station_name + "_SMrz_Seff.txt");

    mdl_file = fullfile(mdl_folder, ...
        station_name + "_saturation.txt");


    %% ---------- Skip if required files are missing ----------

    if ~isfile(rainfall_file) || ~isfile(seff_file)
        SkippedStations(end+1,1) = station_name;
        continue;
    end


    %% ---------- Read rainfall and calculate E3 ----------

    Rain = readtable(rainfall_file, "FileType", "text");
    Rain.Properties.VariableNames = {'Year','Month','Day','Rain_mm'};

    Rain.Date = datetime(Rain.Year, Rain.Month, Rain.Day);

    Rain = Rain(isfinite(Rain.Rain_mm) & Rain.Rain_mm >= 0, :);

    % E3 = rainfall accumulated over current day and previous two days.
    Rain.E3_mm = movsum(Rain.Rain_mm, [2 0]);
    Rain.E3_mm(1:2) = NaN;

    Rain = Rain(Rain.Date >= start_date & Rain.Date <= end_date, :);


    %% ---------- Read S_eff time series for date alignment ----------

    Seff = readtable(seff_file, "FileType", "text");
    Seff.Properties.VariableNames(1:3) = {'Year','Month','Day'};

    Seff.Date = datetime(Seff.Year, Seff.Month, Seff.Day);

    % Last column is assumed to contain root-zone effective saturation.
    Seff.S_eff = Seff{:, width(Seff)};

    Seff = Seff(Seff.Date >= start_date & Seff.Date <= end_date, :);


    %% ---------- Read MDL dates ----------

    if isfile(mdl_file)

        MDL = readtable(mdl_file, "FileType", "text");
        MDL.Properties.VariableNames(1:3) = {'Year','Month','Day'};

        MDL_dates = unique(datetime(MDL.Year, MDL.Month, MDL.Day));

    else

        MDL_dates = datetime.empty(0,1);

    end


    %% ---------- Merge rainfall and S_eff dates ----------

    T = innerjoin( ...
        Rain(:, {'Date','Rain_mm','E3_mm'}), ...
        Seff(:, {'Date','S_eff'}), ...
        "Keys", "Date");

    T = T(isfinite(T.Rain_mm) & isfinite(T.E3_mm), :);

    % Keep only rainfall days.
    T = T(T.Rain_mm >= rain_day_threshold_mm, :);

    if isempty(T)
        SkippedStations(end+1,1) = station_name;
        continue;
    end

    % Observed MDL flag.
    T.MDL = ismember(T.Date, MDL_dates);


    %% ---------- Read station-specific E3 thresholds ----------

    row_id = Thresholds.IMD_ID == station_id;

    if ~any(row_id)
        SkippedStations(end+1,1) = station_name;
        continue;
    end

    E3_thresholds = double(Thresholds{row_id, threshold_columns});

    % If thresholds are invalid, use station-wise empirical E3 percentiles.
    if any(~isfinite(E3_thresholds)) || any(diff(E3_thresholds) <= 0)
        E3_thresholds = prctile(T.E3_mm, percentile_edges);
    end

    if any(~isfinite(E3_thresholds)) || any(diff(E3_thresholds) <= 0)
        warning("Station %s skipped due to invalid thresholds.", station_name);
        SkippedStations(end+1,1) = station_name;
        continue;
    end


    %% ---------- Assign rainfall-severity class ----------

    % Edges:
    % [P05 P10 ... P90 inf]
    %
    % Class 1  = P05-P10
    % Class 17 = P85-P90
    % Class 18 = >=P90
    %
    % Days with E3 < P05 are excluded from Figure 9b calculation.

    bin_edges = [E3_thresholds, inf];

    class_id = discretize(T.E3_mm, bin_edges);

    valid_class = isfinite(class_id) & ...
                  class_id >= 1 & ...
                  class_id <= n_classes;

    if ~any(valid_class)
        SkippedStations(end+1,1) = station_name;
        continue;
    end

    class_id = class_id(valid_class);
    MDL_flag = T.MDL(valid_class);


    %% ---------- Update pooled counts ----------

    N_rain_days_class = N_rain_days_class + ...
        accumarray(class_id, 1, [n_classes 1], @sum, 0);

    N_MDL_days_class = N_MDL_days_class + ...
        accumarray(class_id, double(MDL_flag), [n_classes 1], @sum, 0);


    %% ---------- Store station diagnostics ----------

    n_binned = numel(class_id);
    n_geP90  = sum(class_id == n_classes);

    new_diag = table( ...
        station_name, ...
        height(T), ...
        n_binned, ...
        n_geP90, ...
        n_geP90 / max(n_binned,1), ...
        E3_thresholds(end), ...
        'VariableNames', { ...
        'StationID', ...
        'N_RainDays', ...
        'N_BinnedDays', ...
        'N_geP90', ...
        'Share_geP90', ...
        'E3_P90_mm'});

    StationDiagnostics = [StationDiagnostics; new_diag];

    UsedStations(end+1,1) = station_name;

end


%% ================= CALCULATE FIGURE 9b LIKELIHOOD =================

P_MDL_given_rainfall_class = nan(n_classes,1);

valid = N_rain_days_class > 0;

P_MDL_given_rainfall_class(valid) = ...
    N_MDL_days_class(valid) ./ N_rain_days_class(valid);


%% ================= CREATE OUTPUT TABLE =================

Figure9bTable = table( ...
    Class, ...
    N_rain_days_class, ...
    N_MDL_days_class, ...
    P_MDL_given_rainfall_class, ...
    'VariableNames', { ...
    'Rainfall_Severity_Class', ...
    'N_Rainfall_Days', ...
    'N_MDL_Days', ...
    'P_MDL_given_Rainfall_Class'});


%% ================= SAVE OUTPUT =================

writetable(Figure9bTable, output_excel, ...
    "Sheet", "Figure9b_Pooled");

writetable(StationDiagnostics, output_excel, ...
    "Sheet", "StationDiagnostics");

writetable(table(UsedStations), output_excel, ...
    "Sheet", "UsedStations");

writetable(table(SkippedStations), output_excel, ...
    "Sheet", "SkippedStations");


%% ================= DISPLAY SUMMARY =================

total_binned = sum(N_rain_days_class);
share_geP90 = N_rain_days_class(end) / max(total_binned,1);

fprintf("\nFigure 9b pooled rainfall-severity likelihood completed.\n");
fprintf("Stations used: %d\n", numel(UsedStations));
fprintf("Total binned rainfall days: %d\n", total_binned);
fprintf(">=P90 rainfall-class share: %.2f%%\n", 100 * share_geP90);
fprintf("Output saved:\n%s\n", output_excel);