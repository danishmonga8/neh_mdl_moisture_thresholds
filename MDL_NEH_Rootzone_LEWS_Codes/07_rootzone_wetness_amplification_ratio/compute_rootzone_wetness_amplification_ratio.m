clc; clear; close all;

%% ============================================================
%  Root-zone Wetness Amplification Ratio for MDL Likelihood
%
%  Purpose:
%  This script estimates how much MDL likelihood increases when
%  elevated lag-1 root-zone effective saturation is considered
%  together with high rainfall.
%
%  Formula:
%
%  AR = P(MDL | R_high, S_eff,lag1 >= S_eff,80) ...
%       / P(MDL | R_high)
%
%  where:
%  R_high   = 3-day rainfall exceeds the at-site E3 threshold
%  S_eff,80 = station-wise 80th percentile of lag-1 S_eff
%  AR > 1   = elevated root-zone wetness increases MDL likelihood
%
%  Direct probability calculation:
%
%  P(MDL | condition) = number of MDL days satisfying the condition
%                       / total number of days satisfying the condition
%
%  Output:
%  Station-wise rainfall-only likelihood, wetness-conditioned likelihood,
%  and amplification ratio.
%% ============================================================


%% ================= USER SETTINGS =================

base_folder = "C:\lews_2022-2024\3_new_stations_neh_new\";

meta_file = fullfile(base_folder, "all_stations_neh.xlsx");
threshold_file = fullfile(base_folder, "Final_Threshold_Output.xlsx");

output_file = fullfile(base_folder, ...
    "rootzone_wetness_amplification_ratio_q80_all_stations.xlsx");

% Analysis period
start_date = datetime(2007,1,1);
end_date   = datetime(2019,12,31);   % Change to 2021 if final data are available

% Rainfall-day definition
% Use 2.5 mm for IMD rainy-day definition used in the manuscript.
rain_day_threshold = 2.5;

% Minimum number of joint rainfall + wetness cases required to report AR
min_joint_cases = 5;


%% ================= READ STATION AND THRESHOLD DATA =================

Meta = readtable(meta_file);
station_ids = Meta.IMD;

Thresholds = readtable(threshold_file);

% At-site 3-day rainfall threshold from the E-D threshold workflow
rain_threshold_column = "E3_P20";

if ~ismember(rain_threshold_column, Thresholds.Properties.VariableNames)
    error("Column %s not found in Final_Threshold_Output.xlsx.", rain_threshold_column);
end


%% ================= CREATE EMPTY SUMMARY TABLE =================

Summary = table();

Summary.StationID = [];
Summary.E3_Threshold_mm = [];
Summary.N_EvaluationDays = [];
Summary.N_MDL_Days = [];
Summary.S_eff_q80 = [];
Summary.N_Rhigh = [];
Summary.L_Rhigh = [];
Summary.P_MDL_given_Rhigh = [];
Summary.N_Rhigh_SeffHigh = [];
Summary.L_Rhigh_SeffHigh = [];
Summary.P_MDL_given_Rhigh_SeffHigh = [];
Summary.AmplificationRatio = [];


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


    %% ---------- Read rainfall data ----------

    Rain = readtable(rainfall_file, "FileType", "text");
    Rain.Properties.VariableNames = {'Year','Month','Day','Rain_mm'};

    Rain.Date = datetime(Rain.Year, Rain.Month, Rain.Day);

    % 3-day rainfall accumulation including current day, previous day,
    % and two days before.
    Rain.E3_mm = movsum(Rain.Rain_mm, [2 0]);
    Rain.E3_mm(1:2) = NaN;

    Rain = Rain(Rain.Date >= start_date & Rain.Date <= end_date, :);


    %% ---------- Read continuous root-zone effective saturation ----------

    Seff = readtable(seff_file, "FileType", "text");
    Seff.Properties.VariableNames(1:3) = {'Year','Month','Day'};

    Seff.Date = datetime(Seff.Year, Seff.Month, Seff.Day);

    % The last column is assumed to contain root-zone effective saturation.
    Seff.S_eff = Seff{:, width(Seff)};

    % Lag-1 effective saturation: wetness condition one day before.
    Seff.S_eff_lag1 = [NaN; Seff.S_eff(1:end-1)];

    Seff = Seff(Seff.Date >= start_date & Seff.Date <= end_date, :);


    %% ---------- Read MDL dates ----------

    LS = readtable(landslide_file, "FileType", "text");
    LS.Properties.VariableNames(1:3) = {'Year','Month','Day'};

    MDL_dates = unique(datetime(LS.Year, LS.Month, LS.Day));


    %% ---------- Merge rainfall and S_eff data ----------

    T = innerjoin( ...
        Rain(:, {'Date','Rain_mm','E3_mm'}), ...
        Seff(:, {'Date','S_eff_lag1'}), ...
        "Keys", "Date");

    % Keep only days with valid 3-day rainfall and lag-1 S_eff.
    T = T(~isnan(T.E3_mm) & ~isnan(T.S_eff_lag1), :);

    % Mark whether each day is an MDL day.
    T.MDL = ismember(T.Date, MDL_dates);

    % Evaluation days are rainfall days.
    T = T(T.Rain_mm > rain_day_threshold, :);

    if isempty(T)
        warning("No valid rainfall evaluation days for station %s.", station_name);
        continue;
    end


    %% ---------- Define rainfall and wetness conditions ----------

    row_id = Thresholds.IMD_ID == station_id;
    E3_threshold = Thresholds{row_id, rain_threshold_column};

    % Elevated root-zone wetness condition:
    % station-wise 80th percentile of lag-1 S_eff.
    S_eff_q80 = prctile(T.S_eff_lag1, 80);

    % High rainfall condition
    R_high = T.E3_mm > E3_threshold;

    % High root-zone wetness condition
    Seff_high = T.S_eff_lag1 >= S_eff_q80;

    % Joint condition: high rainfall and high root-zone wetness
    Rhigh_SeffHigh = R_high & Seff_high;


    %% ---------- Calculate rainfall-only MDL likelihood ----------

    % P(MDL | R_high)
    N_Rhigh = sum(R_high);
    L_Rhigh = sum(T.MDL(R_high));

    if N_Rhigh > 0
        P_MDL_given_Rhigh = L_Rhigh / N_Rhigh;
    else
        P_MDL_given_Rhigh = NaN;
    end


    %% ---------- Calculate wetness-conditioned MDL likelihood ----------

    % P(MDL | R_high, S_eff,lag1 >= S_eff,80)
    N_Rhigh_SeffHigh = sum(Rhigh_SeffHigh);
    L_Rhigh_SeffHigh = sum(T.MDL(Rhigh_SeffHigh));

    if N_Rhigh_SeffHigh >= min_joint_cases
        P_MDL_given_Rhigh_SeffHigh = ...
            L_Rhigh_SeffHigh / N_Rhigh_SeffHigh;
    else
        P_MDL_given_Rhigh_SeffHigh = NaN;
    end


    %% ---------- Calculate amplification ratio ----------

    % AR = P(MDL | R_high, S_eff,lag1 >= S_eff,80)
    %      / P(MDL | R_high)

    if ~isnan(P_MDL_given_Rhigh) && ...
       ~isnan(P_MDL_given_Rhigh_SeffHigh) && ...
       P_MDL_given_Rhigh > 0

        AmplificationRatio = ...
            P_MDL_given_Rhigh_SeffHigh / P_MDL_given_Rhigh;
    else
        AmplificationRatio = NaN;
    end


    %% ---------- Store station-wise result ----------

    new_row = table( ...
        station_id, ...
        E3_threshold, ...
        height(T), ...
        sum(T.MDL), ...
        S_eff_q80, ...
        N_Rhigh, ...
        L_Rhigh, ...
        P_MDL_given_Rhigh, ...
        N_Rhigh_SeffHigh, ...
        L_Rhigh_SeffHigh, ...
        P_MDL_given_Rhigh_SeffHigh, ...
        AmplificationRatio, ...
        'VariableNames', Summary.Properties.VariableNames);

    Summary = [Summary; new_row];


    %% ---------- Display result ----------

    fprintf("E3 threshold = %.2f mm\n", E3_threshold);
    fprintf("S_eff,80 = %.3f\n", S_eff_q80);
    fprintf("P(MDL | R_high) = %.4f\n", P_MDL_given_Rhigh);
    fprintf("P(MDL | R_high, S_eff >= S_eff,80) = %.4f\n", ...
        P_MDL_given_Rhigh_SeffHigh);
    fprintf("Amplification Ratio = %.3f\n", AmplificationRatio);

end


%% ================= SAVE OUTPUT =================

writetable(Summary, output_file, "Sheet", "Amplification_Ratio");

fprintf("\nAmplification ratio summary saved:\n%s\n", output_file);