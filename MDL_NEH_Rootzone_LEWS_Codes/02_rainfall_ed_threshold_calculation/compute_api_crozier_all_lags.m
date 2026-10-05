clc; clear; close all;

%% ============================================================
%  API / AMC Calculation using Crozier Antecedent Rainfall Index
%
%  Purpose:
%  This script calculates antecedent moisture condition (AMC),
%  represented here using the Crozier/API formulation, for each
%  moisture-driven landslide (MDL) event and for multiple antecedent
%  lag windows.
%
%  Formula:
%  API_n = sum( k^(i-1) * P_i )
%
%  where:
%  API_n = antecedent precipitation index over n days
%  P_i   = rainfall on the i-th antecedent day
%  k     = decay factor
%  n     = antecedent window length
%
%  In this script:
%  n = lag + 1
%  k = 0.9
%
%  The antecedent window ends on the last day of the triggering
%  rainfall event associated with each MDL.
%
%  Output:
%  For each lag window, one folder is created:
%  <lag>_day/
%
%  Each output file contains:
%  Year Month Day API
%
%  The date columns correspond to the MDL event date.
%% ============================================================


%% ================= USER SETTINGS =================

base_folder = "C:\lews_2022-2024\3_new_stations_neh_new\";

rainfall_folder = fullfile(base_folder, ...
    "3_rainfall_events_thresholds", ...
    "rainfall_data_threshold_applied");

mdl_folder = fullfile(base_folder, ...
    "4__nasa_coolr", ...
    "nearest_landlsides");

last_trigger_day_folder = fullfile(base_folder, ...
    "5_last_day_of_trigging");

output_root = fullfile(base_folder, ...
    "6_crozier_outputs");

if ~exist(output_root, "dir")
    mkdir(output_root);
end

% Antecedent lag windows used in the study
lag_days = [3, 5, 7, 11, 15, 21, 25, 30, 35, 40, 45, 50, 55, 60];

% Crozier/API decay factor
decay_factor = 0.9;


%% ================= LIST STATION RAINFALL FILES =================

rainfall_files = dir(fullfile(rainfall_folder, "*.txt"));

fprintf("Number of rainfall station files found: %d\n", numel(rainfall_files));


%% ================= MAIN CALCULATION =================

for lag = lag_days

    % n is the number of days included in the antecedent window.
    n_days = lag + 1;

    output_folder = fullfile(output_root, sprintf("%d_day", lag));

    if ~exist(output_folder, "dir")
        mkdir(output_folder);
    end

    fprintf("\n============================================\n");
    fprintf("Calculating API/AMC for %d-day lag\n", lag);
    fprintf("Output folder: %s\n", output_folder);
    fprintf("============================================\n");


    for i = 1:numel(rainfall_files)

        %% ---------- Station ID ----------

        rainfall_file_name = rainfall_files(i).name;
        [station_id, ~, ~] = fileparts(rainfall_file_name);

        fprintf("Processing station %s\n", station_id);


        %% ---------- Input files ----------

        rainfall_file = fullfile(rainfall_folder, ...
            station_id + ".txt");

        mdl_file = fullfile(mdl_folder, ...
            "landslide_" + station_id + ".txt");

        last_trigger_file = fullfile(last_trigger_day_folder, ...
            station_id + "trigging_duration.txt");


        %% ---------- Read input data ----------

        Rain = readmatrix(rainfall_file);
        MDL = readmatrix(mdl_file);
        LastTrigger = readmatrix(last_trigger_file);

        % Rainfall file:
        % Column 1 = year
        % Column 2 = month
        % Column 3 = day
        % Column 4 = rainfall
        RainDate = datetime(Rain(:,1), Rain(:,2), Rain(:,3));
        RainAmount = Rain(:,4);

        T_rain = table(RainDate, RainAmount, ...
            "VariableNames", {'Date','Rain'});

        % Last triggering rainfall day file:
        % Columns 1–3 = year, month, day
        LastTriggerDate = datetime( ...
            LastTrigger(:,1), ...
            LastTrigger(:,2), ...
            LastTrigger(:,3));

        % MDL file:
        % Columns 4–6 = MDL year, month, day
        MDL_DatePart = MDL(:,4:6);


        %% ---------- Calculate API/AMC for each MDL event ----------

        n_events = numel(LastTriggerDate);

        Output = nan(n_events, 4);

        for j = 1:n_events

            % The antecedent window ends on the last triggering rainfall day.
            end_date = LastTriggerDate(j);
            start_date = end_date - days(n_days - 1);

            window_dates = (start_date:caldays(1):end_date)';

            T_window = T_rain(ismember(T_rain.Date, window_dates), :);

            Precip = [ ...
                year(T_window.Date), ...
                month(T_window.Date), ...
                day(T_window.Date), ...
                T_window.Rain];

            % If rainfall data are missing within the window, pad zeros
            % at the beginning so that the window length remains n_days.
            if size(Precip, 1) < n_days
                n_missing = n_days - size(Precip, 1);
                Precip = [zeros(n_missing, 4); Precip];
            end

            % Crozier/API value for the selected antecedent window.
            API_value = crozier(Precip, n_days, decay_factor);

            % Store MDL event date and API value.
            Output(j, :) = [MDL_DatePart(j, :), API_value];

        end


        %% ---------- Save station output ----------

        output_file = fullfile(output_folder, ...
            sprintf("%s_%d_crozier_5.txt", station_id, lag));

        writematrix(Output, output_file, "Delimiter", "tab");

    end
end


fprintf("\nAPI/AMC calculation completed for all stations and lag windows.\n");