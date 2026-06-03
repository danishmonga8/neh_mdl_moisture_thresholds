clc; clear; close all;

%% ============================================================
%  Example Lorenz Curve and Gini Ratio for Darjeeling
%
%  Purpose:
%  This script computes annual triggering rainfall (TR) and antecedent
%  moisture condition (AMC) totals for MDL events at Darjeeling and then
%  derives Lorenz curves, Gini coefficients, and the Gini ratio.
%
%  Gini ratio:
%  G_AMC_over_G_TR = G_AMC / G_TR
%
%  Interpretation:
%  G_AMC_over_G_TR > 1  -> AMC is more annually concentrated than TR
%  G_AMC_over_G_TR < 1  -> TR is more annually concentrated than AMC
%
%  Note:
%  Multiple MDL records on the same date are retained as separate events.
%% ============================================================


%% ================= USER SETTINGS =================

base_folder = "C:\lews_2022-2024\3_new_stations_neh_new\";

% Darjeeling WMO / station ID
wmo_target = "42295";

metadata_file = fullfile(base_folder, "all_stations_neh.xlsx");

mdl_folder = fullfile(base_folder, ...
    "4__nasa_coolr", "nearest_landlsides");

amc_folder = fullfile(base_folder, ...
    "6_crozier_outputs");

tr_folder = fullfile(base_folder, ...
    "7_trigging_events");

output_folder = fullfile(base_folder, ...
    "amc_contribution", "lorenz_gini_darjeeling");

if ~exist(output_folder, "dir")
    mkdir(output_folder);
end

annual_output_file = fullfile(output_folder, ...
    "darjeeling_annual_tr_amc.xlsx");

summary_output_file = fullfile(output_folder, ...
    "darjeeling_lorenz_gini_summary.xlsx");

figure_output_file = fullfile(output_folder, ...
    "darjeeling_lorenz_gini_tr_amc.png");

% Analysis period
year_start = 2007;
year_end   = 2018;
years = (year_start:year_end)';


%% ================= READ STATION METADATA =================

Metadata = readtable(metadata_file, ...
    "TextType", "string", ...
    "VariableNamingRule", "preserve");

% Column positions in metadata file
station_col = 1;   % Station name
wmo_col     = 2;   % WMO / station ID
lag_col     = 5;   % Ideal antecedent lag

% Find Darjeeling row
WMO_list = strings(height(Metadata),1);

for i = 1:height(Metadata)
    WMO_list(i) = string(cleanWMO(Metadata{i, wmo_col}));
end

row_id = find(WMO_list == wmo_target, 1, "first");

station_name = strtrim(string(Metadata{row_id, station_col}));
ideal_lag = round(double(Metadata{row_id, lag_col}));

fprintf("Station: %s\n", station_name);
fprintf("WMO: %s\n", wmo_target);
fprintf("Ideal antecedent lag: %d days\n", ideal_lag);


%% ================= INPUT FILES =================

mdl_file = resolveWmoFile(mdl_folder, wmo_target, ".txt", "landslide_");

amc_lag_folder = fullfile(amc_folder, sprintf("%d_day", ideal_lag));
amc_file = resolveWmoFile(amc_lag_folder, wmo_target, ".txt", "", ideal_lag);

tr_file = resolveWmoFile(tr_folder, wmo_target, ".txt", "_trigging");


%% ================= READ MDL, AMC, AND TR DATA =================

MDL_raw = readmatrix(mdl_file, "FileType", "text");
AMC_raw = readmatrix(amc_file, "FileType", "text");
TR_raw  = readmatrix(tr_file, "FileType", "text");

% MDL file: columns 4–6 contain year, month, and day
MDL_date = datetime(MDL_raw(:,4), MDL_raw(:,5), MDL_raw(:,6));
MDL_Event_ID = (1:numel(MDL_date))';

T_mdl = table(MDL_Event_ID, MDL_date, ...
    "VariableNames", {'MDL_Event_ID','Date'});

% AMC file: columns 1–3 contain date and column 4 contains AMC
AMC_date = datetime(AMC_raw(:,1), AMC_raw(:,2), AMC_raw(:,3));
T_amc_raw = table(AMC_date, AMC_raw(:,4), ...
    "VariableNames", {'Date','AMC'});

% TR file: columns 1–3 contain date and column 4 contains TR
TR_date = datetime(TR_raw(:,1), TR_raw(:,2), TR_raw(:,3));
T_tr_raw = table(TR_date, TR_raw(:,4), ...
    "VariableNames", {'Date','TR'});


%% ================= PREPARE DAILY AMC AND TR VALUES =================

% If AMC or TR files contain repeated dates, collapse them to one daily value.
% The median is used as a stable representative value for that date.

T_amc = groupsummary(T_amc_raw, "Date", "median", "AMC");
T_amc = T_amc(:, {'Date','median_AMC'});
T_amc.Properties.VariableNames = {'Date','AMC'};

T_tr = groupsummary(T_tr_raw, "Date", "median", "TR");
T_tr = T_tr(:, {'Date','median_TR'});
T_tr.Properties.VariableNames = {'Date','TR'};


%% ================= JOIN MDL EVENTS WITH AMC AND TR =================

T = innerjoin(T_mdl, T_amc, "Keys", "Date");
T = innerjoin(T, T_tr, "Keys", "Date");

% Keep analysis period
T = T(year(T.Date) >= year_start & year(T.Date) <= year_end, :);


%% ================= CALCULATE ANNUAL TR AND AMC TOTALS =================

Annual = table();

Annual.Year = years;
Annual.MDL_Events = zeros(numel(years),1);
Annual.TR_Total = zeros(numel(years),1);
Annual.AMC_Total = zeros(numel(years),1);

event_year = year(T.Date);

for i = 1:numel(years)

    this_year = years(i);
    idx_year = event_year == this_year;

    Annual.MDL_Events(i) = sum(idx_year);
    Annual.TR_Total(i) = sum(T.TR(idx_year), "omitnan");
    Annual.AMC_Total(i) = sum(T.AMC(idx_year), "omitnan");

end


%% ================= LORENZ CURVES AND GINI COEFFICIENTS =================

[p_TR, L_TR, G_TR] = lorenzGini(Annual.TR_Total);
[p_AMC, L_AMC, G_AMC] = lorenzGini(Annual.AMC_Total);

G_AMC_over_G_TR = G_AMC / G_TR;


%% ================= CREATE SUMMARY TABLE =================

Summary = table( ...
    station_name, ...
    wmo_target, ...
    ideal_lag, ...
    height(T_mdl), ...
    numel(unique(T_mdl.Date)), ...
    height(T), ...
    G_TR, ...
    G_AMC, ...
    G_AMC_over_G_TR, ...
    'VariableNames', { ...
    'Station', ...
    'WMO', ...
    'IdealLag_days', ...
    'MDL_TotalEvents', ...
    'MDL_UniqueDays', ...
    'MDL_JoinedEvents', ...
    'G_TR', ...
    'G_AMC', ...
    'G_AMC_over_G_TR'});

disp("Annual TR and AMC totals:");
disp(Annual);

disp("Lorenz-Gini summary:");
disp(Summary);


%% ================= SAVE TABLES =================

writetable(Annual, annual_output_file);
writetable(Summary, summary_output_file);

fprintf("\nAnnual table saved:\n%s\n", annual_output_file);
fprintf("Summary table saved:\n%s\n", summary_output_file);


%% ================= PLOT LORENZ CURVES =================

figure("Color", "w", "Position", [100 100 900 700]);
hold on; box on;

plot([0 1], [0 1], "k--", "LineWidth", 1.2);

plot(p_TR, L_TR, "-", ...
    "LineWidth", 2.5);

plot(p_AMC, L_AMC, "-", ...
    "LineWidth", 2.5);

xlim([0 1]);
ylim([0 1]);

xlabel("Cumulative fraction of years", ...
    "FontSize", 16, ...
    "FontWeight", "bold");

ylabel("Cumulative fraction of annual total", ...
    "FontSize", 16, ...
    "FontWeight", "bold");

title(sprintf("%s: Lorenz curves for annual TR and AMC", station_name), ...
    "FontSize", 16, ...
    "FontWeight", "bold", ...
    "Interpreter", "none");

legend( ...
    "Equality line", ...
    sprintf("TR (G = %.3f)", G_TR), ...
    sprintf("AMC (G = %.3f)", G_AMC), ...
    "Location", "southeast", ...
    "Box", "off");

text(0.05, 0.90, ...
    sprintf("G_{AMC}/G_{TR} = %.3f", G_AMC_over_G_TR), ...
    "Units", "normalized", ...
    "FontSize", 14, ...
    "FontWeight", "bold");

set(gca, ...
    "FontSize", 13, ...
    "FontWeight", "bold", ...
    "LineWidth", 1.1, ...
    "TickDir", "out");

grid on;

exportgraphics(gcf, figure_output_file, "Resolution", 600);

fprintf("Figure saved:\n%s\n", figure_output_file);


%% ============================================================
%  Local function: Lorenz curve and Gini coefficient
%% ============================================================

function [p, L, G] = lorenzGini(x)

    x = x(:);
    x(isnan(x)) = 0;
    x(x < 0) = 0;

    x = sort(x, "ascend");
    n = numel(x);

    p = (0:n)' / n;

    if sum(x) == 0
        L = zeros(n+1,1);
        G = NaN;
        return;
    end

    L = [0; cumsum(x) / sum(x)];

    % Gini coefficient based on the area between equality line
    % and Lorenz curve.
    G = 1 - 2 * trapz(p, L);

end