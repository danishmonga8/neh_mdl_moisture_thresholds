% Developed by Danish Monga under the guidance of Dr. Poulomi Ganguli

clc; clear; close all;

%% ============================================================
%  Apply Rainfall Threshold to Filled Daily Rainfall Series
%
%  Purpose:
%  This script applies a daily rainfall threshold to the filled
%  station-wise rainfall time series.
%
%  Rainfall values below the threshold are set to zero.
%
%  Input:
%  Filled daily rainfall files:
%  Year Month Day Rainfall
%
%  Output:
%  Threshold-applied rainfall files:
%  Year Month Day Rainfall
%
%  These output files are used for rainfall-event extraction,
%  triggering rainfall, AMC/API, and threshold analyses.
%% ============================================================


%% ================= USER SETTINGS =================

base_folder = "C:\lews_2022-2024\3_new_stations_neh_new\";

input_folder = fullfile(base_folder, ...
    "2_data_preprocessing", ...
    "filled_data_imd", ...
    "filled_missing");

output_folder = fullfile(base_folder, ...
    "3_rainfall_events_thresholds", ...
    "rainfall_data_threshold_applied");

if ~exist(output_folder, "dir")
    mkdir(output_folder);
end

% Analysis period
start_date = datetime(1980,1,1);
end_date   = datetime(2019,12,31);   % Change to 2021 if final data are available

% Daily rainfall threshold used to define rainfall days
rainfall_threshold_mm = 2.5;


%% ================= LIST FILLED RAINFALL FILES =================

station_files = dir(fullfile(input_folder, "*_Prcp_filled.txt"));

fprintf("Number of station files found: %d\n", numel(station_files));


%% ================= MAIN LOOP =================

for i = 1:numel(station_files)

    file_name = station_files(i).name;
    file_path = fullfile(station_files(i).folder, file_name);

    fprintf("\nProcessing %s\n", file_name);

    %% ---------- Extract station ID ----------

    name_parts = split(string(file_name), "_");
    station_id = name_parts(1);


    %% ---------- Read filled rainfall data ----------

    Rain = readmatrix(file_path);

    % Expected columns:
    % 1 = Year
    % 2 = Month
    % 3 = Day
    % 4 = Rainfall
    Date = datetime(Rain(:,1), Rain(:,2), Rain(:,3));
    Rainfall = Rain(:,4);

    T = table(Date, Rainfall, ...
        "VariableNames", {'Date','Rainfall'});


    %% ---------- Standardize to complete daily period ----------

    full_dates = (start_date:caldays(1):end_date)';

    T_full = table(full_dates, ...
        "VariableNames", {'Date'});

    T = outerjoin(T_full, T, ...
        "Keys", "Date", ...
        "MergeKeys", true);

    T = sortrows(T, "Date");

    % If any date is missing from the input file, keep it as zero rainfall.
    T.Rainfall(isnan(T.Rainfall)) = 0;


    %% ---------- Apply rainfall threshold ----------

    % Values below 2.5 mm are treated as non-rainfall days.
    T.Rainfall(T.Rainfall < rainfall_threshold_mm) = 0;


    %% ---------- Save threshold-applied rainfall ----------

    Output = [ ...
        year(T.Date), ...
        month(T.Date), ...
        day(T.Date), ...
        T.Rainfall];

    output_file = fullfile(output_folder, ...
        sprintf("%s.txt", station_id));

    writematrix(Output, output_file, ...
        "Delimiter", "tab");

    fprintf("Saved threshold-applied rainfall file: %s\n", output_file);

end

fprintf("\nRainfall threshold application completed for all stations.\n");