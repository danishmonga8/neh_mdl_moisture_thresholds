clc; clear; close all;

%% ============================================================
%  At-site E-D Rainfall Thresholds using Non-crossing Quantile Regression
%
%  Purpose:
%  This script derives station-wise event-duration (E-D) rainfall
%  thresholds for moisture-driven landslide (MDL) analysis.
%
%  Input:
%  For each station, the input Excel file contains two sheets:
%
%  1. ap        : antecedent moisture condition / API event samples
%  2. trigging  : triggering rainfall event samples
%
%  Each sheet must contain:
%  Column 1 = rainfall amount, E
%  Column 2 = duration, D
%
%  Model:
%  E = a + bD
%
%  Threshold extracted:
%  E3 = threshold rainfall amount at D = 3 days
%
%  Note:
%  This is a rainfall-derived threshold using AMC/API and triggering
%  rainfall samples. Root-zone effective saturation is not used here.
%% ============================================================


%% ================= USER SETTINGS =================

base_folder = "C:\lews_2022-2024\3_new_stations_neh_new\";

input_folder = fullfile(base_folder, ...
    "9_ideal_lag", ...
    "Output_Triggering_Events");

metadata_file = fullfile(base_folder, ...
    "all_stations_neh.xlsx");

output_file = fullfile(base_folder, ...
    "Final_Threshold_Output.xlsx");

% Folder containing ncquantreg.m
addpath("C:\lews_2022-2024\2_new_stations_neh\9_ideal_lag");

% Quantiles for threshold estimation
taus = 0.05:0.01:0.98;

% Main quantile used in the manuscript
tau_main = 0.20;

% Duration for 3-day threshold.
% Keep D_eval = 3 only if duration column is in days.
D_eval = 3;


%% ================= READ STATION METADATA =================

Metadata = readtable(metadata_file);

station_ids = Metadata.IMD;
nTau = numel(taus);

OutputRows = {};


%% ================= LOOP THROUGH STATIONS =================

for i = 1:numel(station_ids)

    station_id = station_ids(i);

    input_file = fullfile(input_folder, ...
        sprintf("%d_triggering_output.xlsx", station_id));

    fprintf("\nProcessing station %d\n", station_id);


    %% ---------- Read AMC/API and triggering rainfall samples ----------

    data_api = readmatrix(input_file, "Sheet", "ap");
    data_tr  = readmatrix(input_file, "Sheet", "trigging");

    % Combine rainfall-derived controls.
    % API/AMC and triggering rainfall are both rainfall-based variables.
    data_all = [data_api; data_tr];

    % Keep valid rainfall amount and duration.
    valid_rows = isfinite(data_all(:,1)) & ...
                 isfinite(data_all(:,2)) & ...
                 data_all(:,1) > 0 & ...
                 data_all(:,2) > 0;

    data_all = data_all(valid_rows, :);


    %% ---------- Define E and D ----------

    E = data_all(:,1);   % rainfall amount
    D = data_all(:,2);   % duration


    %% ---------- Estimate E3 thresholds at all quantiles ----------

    E3_thresholds = nan(1, nTau);

    for q = 1:nTau

        tau = taus(q);

        % Linear E-D model: E = a + bD
        model_order = 1;

        beta = ncquantreg(D, E, model_order, tau);

        a = beta(1);
        b = beta(2);

        % 3-day rainfall threshold
        E3_thresholds(q) = a + b * D_eval;

    end


    %% ---------- Store the tau = 0.20 equation ----------

    beta20 = ncquantreg(D, E, 1, tau_main);

    a20 = beta20(1);
    b20 = beta20(2);

    Eqn_P20 = sprintf("E = %.2f + %.2fD, tau = 0.20", a20, b20);


    %% ---------- Station metadata ----------

    station_name = string(Metadata.Station(i));
    lat = Metadata.Lat(i);

    if ismember("Long", string(Metadata.Properties.VariableNames))
        lon = Metadata.Long(i);
    else
        lon = Metadata.Lon(i);
    end


    %% ---------- Append station result ----------

    new_row = [{station_name, station_id, lat, lon}, ...
               num2cell(E3_thresholds), ...
               {Eqn_P20}];

    OutputRows(end+1, :) = new_row;

end


%% ================= SAVE OUTPUT TABLE =================

tau_labels = arrayfun(@(t) sprintf("E3_P%02d", round(100*t)), ...
    taus, ...
    "UniformOutput", false);

column_names = [{'Station','IMD_ID','Lat','Lon'}, ...
                tau_labels, ...
                {'Eqn_P20'}];

ThresholdTable = cell2table(OutputRows, ...
    "VariableNames", column_names);

writetable(ThresholdTable, output_file);

fprintf("\nAt-site E-D threshold table saved:\n%s\n", output_file);