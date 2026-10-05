clc; clear; close all;

%% ============================================================
%  ADF versus 3-day Rainfall Threshold at tau = 0.20
%
%  Purpose:
%  This script plots the relationship between Antecedent Dominance
%  Fraction (ADF) and the station-wise 3-day rainfall threshold
%  derived at tau = 0.20.
%
%  Statistical measure:
%  Kendall's tau is used to assess the rank-based association
%  between ADF and the 3-day rainfall threshold.
%
%  Output:
%  Scatter plot with a linear guide line and Kendall's tau statistic.
%% ============================================================


%% ================= USER SETTINGS =================

input_file = ...
    "C:\lews_2022-2024\3_new_stations_neh_new\all_stations_neh.xlsx";

output_folder = ...
    "C:\lews_2022-2024\3_new_stations_neh_new\figures_neh_soil_moisture\adf_threshold_relationship";

if ~exist(output_folder, "dir")
    mkdir(output_folder);
end

output_figure = fullfile(output_folder, ...
    "adf_vs_3day_threshold_tau20.png");


%% ================= READ INPUT TABLE =================

T = readtable(input_file, ...
    "VariableNamingRule", "preserve");

% Current column positions in your Excel file:
% Column 1  = Station name
% Column 9  = ADF
% Column 11 = 3-day rainfall threshold at tau = 0.20
Station = string(T{:,1});
ADF = T{:,9};
Threshold_3day_tau20 = T{:,11};


%% ================= REMOVE INVALID VALUES =================

valid = isfinite(ADF) & isfinite(Threshold_3day_tau20);

Station = Station(valid);
ADF = double(ADF(valid));
Threshold_3day_tau20 = double(Threshold_3day_tau20(valid));


%% ================= KENDALL CORRELATION =================

[tau_value, p_value] = corr( ...
    ADF, ...
    Threshold_3day_tau20, ...
    "Type", "Kendall", ...
    "Rows", "complete");


%% ================= LINEAR GUIDE LINE =================

pfit = polyfit(ADF, Threshold_3day_tau20, 1);

xfit = linspace(min(ADF), max(ADF), 200);
yfit = polyval(pfit, xfit);


%% ================= PLOT FIGURE =================

fig = figure( ...
    "Color", "w", ...
    "Units", "inches", ...
    "Position", [1 1 7.4 6.8]);

ax = axes(fig);
hold(ax, "on");

% Scatter plot
s = scatter( ...
    ADF, ...
    Threshold_3day_tau20, ...
    105, ...
    "o", ...
    "MarkerFaceColor", [0.78 0.50 0.68], ...
    "MarkerEdgeColor", [0.30 0.30 0.30], ...
    "LineWidth", 0.8);

s.MarkerFaceAlpha = 0.78;
s.MarkerEdgeAlpha = 0.95;

% Linear guide line
plot( ...
    xfit, ...
    yfit, ...
    "-", ...
    "Color", [0.88 0.10 0.10], ...
    "LineWidth", 2.2);


%% ================= AXIS LABELS =================

xlabel( ...
    "Antecedent Dominance Fraction (ADF)", ...
    "FontSize", 18, ...
    "FontWeight", "bold");

ylabel( ...
    {"3-day rainfall threshold (mm)", "at \tau = 0.20"}, ...
    "FontSize", 15, ...
    "FontWeight", "bold", ...
    "Interpreter", "tex");


%% ================= AXIS STYLE =================

set(ax, ...
    "FontSize", 17, ...
    "LineWidth", 1.1, ...
    "Box", "off", ...
    "Layer", "top", ...
    "TickDir", "out", ...
    "XColor", [0.22 0.22 0.22], ...
    "YColor", [0.22 0.22 0.22]);

grid(ax, "on");
ax.GridLineStyle = "--";
ax.GridColor = [0.78 0.78 0.78];
ax.GridAlpha = 0.80;

xpad = 0.05 * range(ADF);
ypad = 0.08 * range(Threshold_3day_tau20);

xlim([min(ADF), max(ADF) + xpad]);
ylim([min(Threshold_3day_tau20), max(Threshold_3day_tau20) + ypad]);


%% ================= STATISTICS BOX =================

stat_text = { ...
    sprintf("Kendall''s \\tau = %.2f", tau_value), ...
    sprintf("p = %.3f", p_value)};

text( ...
    0.96, ...
    0.92, ...
    stat_text, ...
    "Units", "normalized", ...
    "HorizontalAlignment", "right", ...
    "VerticalAlignment", "top", ...
    "FontSize", 13.5, ...
    "BackgroundColor", "white", ...
    "EdgeColor", [0.70 0.70 0.70], ...
    "Margin", 7, ...
    "Interpreter", "tex");

hold(ax, "off");


%% ================= SAVE FIGURE =================

exportgraphics(fig, output_figure, "Resolution", 600);

fprintf("\nADF-threshold figure saved:\n%s\n", output_figure);
fprintf("Kendall tau = %.3f, p = %.4f\n", tau_value, p_value);