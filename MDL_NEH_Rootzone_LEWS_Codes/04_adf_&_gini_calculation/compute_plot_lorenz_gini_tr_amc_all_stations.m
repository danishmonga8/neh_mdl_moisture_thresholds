clc; clear; close all;

%% ============================================================
%  Lorenz Curve and Gini Ratio for TR and AMC
%
%  Purpose:
%  This script computes station-wise Lorenz curves and Gini coefficients
%  for annual triggering rainfall (TR) and antecedent moisture condition
%  (AMC) associated with moisture-driven landslide (MDL) events.
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

metadata_file = fullfile(base_folder, "all_stations_neh.xlsx");

mdl_folder = fullfile(base_folder, ...
    "4__nasa_coolr", "nearest_landlsides");

amc_folder = fullfile(base_folder, ...
    "6_crozier_outputs");

tr_folder = fullfile(base_folder, ...
    "7_trigging_events");

output_folder = fullfile(base_folder, ...
    "amc_contribution", "lorenz_gini_tr_amc");

if ~exist(output_folder, "dir")
    mkdir(output_folder);
end

summary_file = fullfile(output_folder, ...
    "lorenz_gini_tr_amc_summary_all_stations.xlsx");

figure_file = fullfile(output_folder, ...
    "lorenz_curves_tr_amc_all_stations.png");

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

n_stations = height(Metadata);


%% ================= OUTPUT STORAGE =================

Summary = table();

Summary.Station = strings(n_stations,1);
Summary.WMO = strings(n_stations,1);
Summary.IdealLag_days = nan(n_stations,1);
Summary.MDL_TotalEvents = nan(n_stations,1);
Summary.MDL_UniqueDays = nan(n_stations,1);
Summary.MDL_JoinedEvents = nan(n_stations,1);
Summary.G_TR = nan(n_stations,1);
Summary.G_AMC = nan(n_stations,1);
Summary.G_AMC_over_G_TR = nan(n_stations,1);

LorenzData = struct();


%% ================= MAIN CALCULATION =================

for i = 1:n_stations

    station_name = strtrim(string(Metadata{i, station_col}));
    wmo = cleanWMO(Metadata{i, wmo_col});
    ideal_lag = round(double(Metadata{i, lag_col}));

    fprintf("\nProcessing %s | WMO = %s | lag = %d days\n", ...
        station_name, string(wmo), ideal_lag);

    %% ---------- Input files ----------

    mdl_file = resolveWmoFile(mdl_folder, wmo, ".txt", "landslide_");

    amc_lag_folder = fullfile(amc_folder, sprintf("%d_day", ideal_lag));
    amc_file = resolveWmoFile(amc_lag_folder, wmo, ".txt", "", ideal_lag);

    tr_file = resolveWmoFile(tr_folder, wmo, ".txt", "_trigging");


    %% ---------- Read MDL, AMC, and TR files ----------

    MDL_raw = readmatrix(mdl_file, "FileType", "text");
    AMC_raw = readmatrix(amc_file, "FileType", "text");
    TR_raw  = readmatrix(tr_file, "FileType", "text");

    % MDL file: columns 4–6 contain year, month, day
    MDL_date = datetime(MDL_raw(:,4), MDL_raw(:,5), MDL_raw(:,6));
    MDL_Event_ID = (1:numel(MDL_date))';

    T_mdl = table(MDL_Event_ID, MDL_date, ...
        "VariableNames", {'MDL_Event_ID','Date'});

    % AMC file: columns 1–3 date, column 4 AMC
    AMC_date = datetime(AMC_raw(:,1), AMC_raw(:,2), AMC_raw(:,3));
    T_amc_raw = table(AMC_date, AMC_raw(:,4), ...
        "VariableNames", {'Date','AMC'});

    % TR file: columns 1–3 date, column 4 TR
    TR_date = datetime(TR_raw(:,1), TR_raw(:,2), TR_raw(:,3));
    T_tr_raw = table(TR_date, TR_raw(:,4), ...
        "VariableNames", {'Date','TR'});


    %% ---------- Make AMC and TR unique by date ----------

    T_amc = groupsummary(T_amc_raw, "Date", "median", "AMC");
    T_amc = T_amc(:, {'Date','median_AMC'});
    T_amc.Properties.VariableNames = {'Date','AMC'};

    T_tr = groupsummary(T_tr_raw, "Date", "median", "TR");
    T_tr = T_tr(:, {'Date','median_TR'});
    T_tr.Properties.VariableNames = {'Date','TR'};


    %% ---------- Join MDL events with AMC and TR ----------

    T = innerjoin(T_mdl, T_amc, "Keys", "Date");
    T = innerjoin(T, T_tr, "Keys", "Date");

    T = T(year(T.Date) >= year_start & year(T.Date) <= year_end, :);


    %% ---------- Annual TR and AMC totals ----------

    Annual = table();

    Annual.Year = years;
    Annual.MDL_Events = zeros(numel(years),1);
    Annual.TR_Total = zeros(numel(years),1);
    Annual.AMC_Total = zeros(numel(years),1);

    event_year = year(T.Date);

    for y = 1:numel(years)

        this_year = years(y);
        idx_year = event_year == this_year;

        Annual.MDL_Events(y) = sum(idx_year);
        Annual.TR_Total(y) = sum(T.TR(idx_year), "omitnan");
        Annual.AMC_Total(y) = sum(T.AMC(idx_year), "omitnan");

    end


    %% ---------- Lorenz curves and Gini coefficients ----------

    [p_TR, L_TR, G_TR] = lorenzGini(Annual.TR_Total);
    [p_AMC, L_AMC, G_AMC] = lorenzGini(Annual.AMC_Total);

    G_AMC_over_G_TR = G_AMC / G_TR;


    %% ---------- Store results ----------

    Summary.Station(i) = station_name;
    Summary.WMO(i) = string(wmo);
    Summary.IdealLag_days(i) = ideal_lag;
    Summary.MDL_TotalEvents(i) = height(T_mdl);
    Summary.MDL_UniqueDays(i) = numel(unique(T_mdl.Date));
    Summary.MDL_JoinedEvents(i) = height(T);
    Summary.G_TR(i) = G_TR;
    Summary.G_AMC(i) = G_AMC;
    Summary.G_AMC_over_G_TR(i) = G_AMC_over_G_TR;

    LorenzData(i).Station = station_name;
    LorenzData(i).p_TR = p_TR;
    LorenzData(i).L_TR = L_TR;
    LorenzData(i).p_AMC = p_AMC;
    LorenzData(i).L_AMC = L_AMC;

end


%% ================= SAVE SUMMARY TABLE =================

writetable(Summary, summary_file);

fprintf("\nSummary saved:\n%s\n", summary_file);


%% ================= PLOT LORENZ CURVES =================

n_cols = 4;
n_rows = ceil(n_stations / n_cols);

figure("Color", "w", "Position", [50 50 1800 2200]);

tiledlayout(n_rows, n_cols, ...
    "TileSpacing", "compact", ...
    "Padding", "compact");

for i = 1:n_stations

    nexttile;
    hold on; box on;

    plot([0 1], [0 1], "-", ...
        "Color", [0.65 0.65 0.65], ...
        "LineWidth", 1.0);

    plot(LorenzData(i).p_TR, LorenzData(i).L_TR, "-", ...
        "LineWidth", 2.0);

    plot(LorenzData(i).p_AMC, LorenzData(i).L_AMC, "-", ...
        "LineWidth", 2.0);

    xlim([0 1]);
    ylim([0 1]);

    xticks([0 0.5 1]);
    yticks([0 0.5 1]);

    title(LorenzData(i).Station, ...
        "Interpreter", "none", ...
        "FontWeight", "bold");

    set(gca, ...
        "FontSize", 10, ...
        "FontWeight", "bold", ...
        "LineWidth", 1.0, ...
        "TickDir", "out");

    if i == 1
        legend({"Equality line", "TR", "AMC"}, ...
            "Location", "southeast", ...
            "Box", "off");
    end

end

sgtitle("Lorenz Curves for Annual TR and AMC across NEH Sites", ...
    "FontWeight", "bold");

exportgraphics(gcf, figure_file, "Resolution", 300);

fprintf("Figure saved:\n%s\n", figure_file);


