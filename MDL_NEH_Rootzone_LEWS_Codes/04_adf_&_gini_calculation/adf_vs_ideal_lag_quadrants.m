clc; clear; close all;

%% ============================================================
%  Panel 3: Relationship between ADF and Ideal Antecedent Lag
%
%  Purpose:
%  This script plots the relationship between Antecedent Dominance
%  Fraction (ADF) and station-wise ideal antecedent lag.
%
%  Statistical measure:
%  Spearman's rho is used to quantify the rank-based association
%  between ideal lag and ADF.
%
%  Quadrants:
%  1. n < 15 days,  ADF < 0.50
%  2. n >= 15 days, ADF < 0.50
%  3. n < 15 days,  ADF >= 0.50
%  4. n >= 15 days, ADF >= 0.50
%
%  Interpretation:
%  ADF >= 0.50 indicates more frequent AMC-dominant MDL events.
%  ADF <  0.50 indicates more frequent TR-dominant MDL events.
%% ============================================================


%% ================= USER SETTINGS =================

base_folder = "C:\lews_2022-2024\3_new_stations_neh_new\";

adf_file = fullfile(base_folder, ...
    "amc_contribution", ...
    "amc_contribution_map_metrics.xlsx");

station_file = fullfile(base_folder, ...
    "all_stations_neh.xlsx");

output_folder = fullfile(base_folder, ...
    "amc_contribution", ...
    "panel3_adf_ideal_lag");

if ~exist(output_folder, "dir")
    mkdir(output_folder);
end

output_png = fullfile(output_folder, ...
    "panel3_adf_vs_ideal_lag_quadrants.png");

output_tiff = fullfile(output_folder, ...
    "panel3_adf_vs_ideal_lag_quadrants.tiff");

output_excel = fullfile(output_folder, ...
    "panel3_adf_vs_ideal_lag_data.xlsx");


%% ================= FIGURE SETTINGS =================

lag_cut = 15;
adf_cut = 0.50;

x_min = 0;
y_min = 0;

trend_start_x = 3;

blood_red = [139 0 0] / 255;

font_axis_text  = 22;
font_axis_title = 26;
font_station    = 15;
font_corr_text  = 22;
font_quad_text  = 20;


%% ================= READ ADF DATA =================

ADFTable = readtable(adf_file, ...
    "VariableNamingRule", "preserve");

ADFTable.Properties.VariableNames = ...
    matlab.lang.makeValidName(ADFTable.Properties.VariableNames);

% Required columns in ADF file:
% WMO or StationID
% ADF

if ismember("WMO", string(ADFTable.Properties.VariableNames))
    ADFTable.StationID = string(ADFTable.WMO);
elseif ismember("StationID", string(ADFTable.Properties.VariableNames))
    ADFTable.StationID = string(ADFTable.StationID);
elseif ismember("IMD", string(ADFTable.Properties.VariableNames))
    ADFTable.StationID = string(ADFTable.IMD);
else
    error("Station ID column not found in ADF file.");
end

if ~ismember("ADF", string(ADFTable.Properties.VariableNames))
    error("ADF column not found in ADF file.");
end

ADFTable.StationID = strip(ADFTable.StationID);
ADFTable.StationID = regexprep(ADFTable.StationID, "\.0$", "");
ADFTable.ADF = double(ADFTable.ADF);

ADFTable = ADFTable(isfinite(ADFTable.ADF), :);


%% ================= READ STATION METADATA =================

StationTable = readtable(station_file, ...
    "VariableNamingRule", "preserve");

StationTable.Properties.VariableNames = ...
    matlab.lang.makeValidName(StationTable.Properties.VariableNames);

% Detect station ID
if ismember("IMD", string(StationTable.Properties.VariableNames))
    StationTable.StationID = string(StationTable.IMD);
elseif ismember("IMD_ID", string(StationTable.Properties.VariableNames))
    StationTable.StationID = string(StationTable.IMD_ID);
elseif ismember("WMO", string(StationTable.Properties.VariableNames))
    StationTable.StationID = string(StationTable.WMO);
else
    error("Station ID column not found in station metadata.");
end

% Detect station name
if ismember("Station", string(StationTable.Properties.VariableNames))
    StationTable.StationName = string(StationTable.Station);
else
    StationTable.StationName = StationTable.StationID;
end

% Detect ideal lag
if ismember("Ideal_lag", string(StationTable.Properties.VariableNames))
    IdealLag = StationTable.Ideal_lag;
elseif ismember("IdealLag", string(StationTable.Properties.VariableNames))
    IdealLag = StationTable.IdealLag;
else
    % If not named, assume column 5 contains ideal lag.
    IdealLag = StationTable{:,5};
end

StationTable.IdealLag_days = double(IdealLag);

StationTable.StationID = strip(StationTable.StationID);
StationTable.StationID = regexprep(StationTable.StationID, "\.0$", "");

StationTable = StationTable( ...
    isfinite(StationTable.IdealLag_days), :);


%% ================= MERGE ADF AND IDEAL LAG =================

Data = innerjoin( ...
    StationTable(:, {'StationID','StationName','IdealLag_days'}), ...
    ADFTable(:, {'StationID','ADF'}), ...
    "Keys", "StationID");

Data = Data(isfinite(Data.IdealLag_days) & isfinite(Data.ADF), :);

% Keep one row per station
[~, unique_id] = unique(Data.StationID, "stable");
Data = Data(unique_id, :);

fprintf("Stations used in Panel 3 = %d\n", height(Data));


%% ================= SPEARMAN CORRELATION =================

[rho, p_value] = corr( ...
    Data.IdealLag_days, ...
    Data.ADF, ...
    "Type", "Spearman", ...
    "Rows", "complete");

if p_value < 0.001
    p_text = "< 0.001";
else
    p_text = sprintf("%.3f", p_value);
end

corr_text = sprintf("Spearman''s \\rho = %.2f   p = %s", rho, p_text);


%% ================= QUADRANT COUNTS =================

n_LL = sum(Data.IdealLag_days <  lag_cut & Data.ADF <  adf_cut);
n_HL = sum(Data.IdealLag_days >= lag_cut & Data.ADF <  adf_cut);
n_LH = sum(Data.IdealLag_days <  lag_cut & Data.ADF >= adf_cut);
n_HH = sum(Data.IdealLag_days >= lag_cut & Data.ADF >= adf_cut);

n_total = height(Data);

pct_LL = round(100 * n_LL / n_total);
pct_HL = round(100 * n_HL / n_total);
pct_LH = round(100 * n_LH / n_total);
pct_HH = round(100 * n_HH / n_total);


%% ================= LINEAR GUIDE LINE =================

x_max = max(Data.IdealLag_days, [], "omitnan");

fit_coeff = polyfit(Data.IdealLag_days, Data.ADF, 1);

x_fit = linspace(trend_start_x, x_max, 300);
y_fit = polyval(fit_coeff, x_fit);


%% ================= CREATE FIGURE =================

fig = figure( ...
    "Color", "w", ...
    "Units", "inches", ...
    "Position", [1 1 14 10]);

ax = axes(fig);
hold(ax, "on");


%% ---------- Quadrant separator lines ----------

xline(lag_cut, ":", ...
    "Color", [0.25 0.25 0.25], ...
    "LineWidth", 1.5);

yline(adf_cut, ":", ...
    "Color", [0.25 0.25 0.25], ...
    "LineWidth", 1.5);


%% ---------- Scatter points ----------

scatter( ...
    Data.IdealLag_days, ...
    Data.ADF, ...
    170, ...
    "o", ...
    "MarkerFaceColor", [0.80 0.80 0.80], ...
    "MarkerEdgeColor", [0.35 0.35 0.35], ...
    "LineWidth", 1.1, ...
    "MarkerFaceAlpha", 0.65, ...
    "MarkerEdgeAlpha", 0.80);


%% ---------- Station labels ----------

rng(7);

dx = 0.25 + 0.15 * randn(height(Data), 1);
dy = 0.018 + 0.012 * randn(height(Data), 1);

for i = 1:height(Data)

    text( ...
        Data.IdealLag_days(i) + dx(i), ...
        Data.ADF(i) + dy(i), ...
        Data.StationName(i), ...
        "FontSize", font_station, ...
        "Color", [0.10 0.10 0.10], ...
        "HorizontalAlignment", "left", ...
        "VerticalAlignment", "middle", ...
        "Interpreter", "none");

end


%% ---------- Linear guide line ----------

plot( ...
    x_fit, ...
    y_fit, ...
    "Color", blood_red, ...
    "LineWidth", 2.4);


%% ---------- Spearman annotation ----------

text( ...
    x_max, ...
    0.985, ...
    corr_text, ...
    "FontSize", font_corr_text, ...
    "Color", [0.10 0.10 0.10], ...
    "HorizontalAlignment", "right", ...
    "VerticalAlignment", "top", ...
    "Interpreter", "tex");


%% ---------- Quadrant percentage labels ----------

x_left  = x_min + 0.8;
x_right = x_max - 0.8;
y_top   = 0.78;
y_bottom = 0.20;

text(x_left, y_top, ...
    sprintf("\\bf p(n < %d, ADF \\geq %.1f) = %d%%", lag_cut, adf_cut, pct_LH), ...
    "FontSize", font_quad_text, ...
    "Color", blood_red, ...
    "HorizontalAlignment", "left", ...
    "Interpreter", "tex");

text(x_right, y_top, ...
    sprintf("\\bf p(n \\geq %d, ADF \\geq %.1f) = %d%%", lag_cut, adf_cut, pct_HH), ...
    "FontSize", font_quad_text, ...
    "Color", blood_red, ...
    "HorizontalAlignment", "right", ...
    "Interpreter", "tex");

text(x_left, y_bottom, ...
    sprintf("\\bf p(n < %d, ADF < %.1f) = %d%%", lag_cut, adf_cut, pct_LL), ...
    "FontSize", font_quad_text, ...
    "Color", blood_red, ...
    "HorizontalAlignment", "left", ...
    "Interpreter", "tex");

text(x_right, y_bottom, ...
    sprintf("\\bf p(n \\geq %d, ADF < %.1f) = %d%%", lag_cut, adf_cut, pct_HL), ...
    "FontSize", font_quad_text, ...
    "Color", blood_red, ...
    "HorizontalAlignment", "right", ...
    "Interpreter", "tex");


%% ================= AXIS SETTINGS =================

xlim([x_min x_max]);
ylim([y_min 1]);

xticks(3:3:ceil(x_max/3)*3);
yticks(0:0.2:1);

xlabel( ...
    "Ideal lag (days)", ...
    "FontSize", font_axis_title, ...
    "FontWeight", "bold", ...
    "Color", [0.10 0.10 0.10]);

ylabel( ...
    "Antecedent Dominance Fraction (ADF)", ...
    "FontSize", font_axis_title, ...
    "FontWeight", "bold", ...
    "Color", [0.10 0.10 0.10]);

set(ax, ...
    "FontSize", font_axis_text, ...
    "LineWidth", 1.3, ...
    "Box", "on", ...
    "TickDir", "out", ...
    "XColor", [0.10 0.10 0.10], ...
    "YColor", [0.10 0.10 0.10]);

grid(ax, "off");

hold(ax, "off");


%% ================= SAVE OUTPUTS =================

writetable(Data, output_excel);

exportgraphics(fig, output_png, ...
    "Resolution", 600);

exportgraphics(fig, fullfile(output_folder, ...
    "panel3_adf_vs_ideal_lag_quadrants.tiff"), ...
    "Resolution", 600);

fprintf("\nPanel 3 ADF-Ideal lag figure saved:\n%s\n", output_png);
fprintf("Spearman rho = %.3f, p = %.4f\n", rho, p_value);