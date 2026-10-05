clc; clear; close all;

%% ============================================================
%  Kendall's Tau between API and Root-zone Wetness Metrics
%
%  Purpose:
%  This script evaluates the association between antecedent
%  precipitation index (API) and root-zone effective saturation
%  on moisture-driven landslide (MDL) days.
%
%  Three root-zone wetness metrics are compared:
%
%  1. median S_eff[T_opt] : median effective saturation over the
%                           station-specific optimal antecedent window
%  2. S_eff[1]            : lag-1 root-zone effective saturation
%  3. S_eff[0]            : event-day root-zone effective saturation
%
%  Statistical measure:
%
%  Kendall's tau is used to quantify rank-based association between
%  API and each root-zone wetness metric.
%
%  Output:
%  1. Station-wise Kendall's tau and p-values
%  2. Pooled "All NEH" Kendall's tau
%  3. Grouped bar plot comparing the three wetness metrics
%% ============================================================


%% ================= USER SETTINGS =================

base_folder = "C:\lews_2022-2024\3_new_stations_neh_new\";

metadata_file = fullfile(base_folder, "all_stations_neh.xlsx");

mdl_folder = fullfile(base_folder, ...
    "4__nasa_coolr", "nearest_landlsides");

seff_folder = fullfile(base_folder, ...
    "10_soil_moisture_extraction", "saturation_by_station");

api_folder = fullfile(base_folder, ...
    "6_crozier_outputs");

output_folder = fullfile(base_folder, ...
    "api_rootzone_correlation");

if ~exist(output_folder, "dir")
    mkdir(output_folder);
end

output_excel = fullfile(output_folder, ...
    "kendall_tau_api_rootzone_metrics.xlsx");

output_figure = fullfile(output_folder, ...
    "kendall_tau_api_rootzone_metrics.png");

% Analysis period
year_start = 2007;
year_end   = 2018;   % Change if final manuscript figure uses a longer period


%% ================= READ STATION METADATA =================

Metadata = readtable(metadata_file, ...
    "ReadVariableNames", true);

StationName = string(Metadata.Station);
StationID = Metadata.IMD;
OptimalLag = Metadata.Ideal_lag;

n_stations = numel(StationID);


%% ================= OUTPUT STORAGE =================

Tau_API_Seff_Topt = nan(n_stations,1);
P_API_Seff_Topt   = nan(n_stations,1);

Tau_API_Seff_1 = nan(n_stations,1);
P_API_Seff_1   = nan(n_stations,1);

Tau_API_Seff_0 = nan(n_stations,1);
P_API_Seff_0   = nan(n_stations,1);

N_Topt = zeros(n_stations,1);
N_Seff1 = zeros(n_stations,1);
N_Seff0 = zeros(n_stations,1);

% Store event-wise pairs for pooled "All NEH" calculation.
API_Topt_all = [];
Seff_Topt_all = [];

API_Seff1_all = [];
Seff1_all = [];

API_Seff0_all = [];
Seff0_all = [];


%% ================= MAIN CALCULATION =================

for i = 1:n_stations

    station_id = StationID(i);
    station_name = StationName(i);
    optimal_lag = OptimalLag(i);

    station_id_str = sprintf("%05d", station_id);

    fprintf("\nProcessing %s | Station ID = %s | optimal lag = %d days\n", ...
        station_name, station_id_str, optimal_lag);


    %% ---------- Input files ----------

    mdl_file = fullfile(mdl_folder, ...
        sprintf("landslide_%s.txt", station_id_str));

    seff_file = fullfile(seff_folder, ...
        sprintf("%s_saturation.txt", station_id_str));

    api_file = fullfile(api_folder, ...
        sprintf("%d_day", optimal_lag), ...
        sprintf("%s_%d_crozier_5.txt", station_id_str, optimal_lag));


    %% ---------- Read MDL dates ----------

    MDL_raw = readmatrix(mdl_file);

    % MDL file: columns 4–6 contain year, month, and day.
    MDL_date = datetime(MDL_raw(:,4), MDL_raw(:,5), MDL_raw(:,6));

    % Keep MDLs within the analysis period.
    MDL_date = MDL_date(year(MDL_date) >= year_start & ...
                        year(MDL_date) <= year_end);

    if isempty(MDL_date)
        continue;
    end


    %% ---------- Read root-zone effective saturation ----------

    Seff_raw = readmatrix(seff_file);

    % Expected columns:
    % 1 = year
    % 2 = month
    % 3 = day
    % 4 = median S_eff[T_opt]
    % 5 = S_eff[1]
    % 6 = S_eff[0]
    Seff_date = datetime(Seff_raw(:,1), Seff_raw(:,2), Seff_raw(:,3));

    Seff_Topt = Seff_raw(:,4);
    Seff_1    = Seff_raw(:,5);
    Seff_0    = Seff_raw(:,6);

    T_seff = table(Seff_date, Seff_Topt, Seff_1, Seff_0, ...
        "VariableNames", {'Date','Seff_Topt','Seff_1','Seff_0'});


    %% ---------- Read API at optimal antecedent lag ----------

    API_raw = readmatrix(api_file);

    % API file: columns 1–3 contain date and column 4 contains API.
    API_date = datetime(API_raw(:,1), API_raw(:,2), API_raw(:,3));
    API_value = API_raw(:,4);

    T_api = table(API_date, API_value, ...
        "VariableNames", {'Date','API'});


    %% ---------- Join MDL dates with API and S_eff ----------

    T_mdl = table(MDL_date, "VariableNames", {'Date'});

    T = innerjoin(T_mdl, T_api, "Keys", "Date");
    T = innerjoin(T, T_seff, "Keys", "Date");


    %% ---------- API vs median S_eff[T_opt] ----------

    x = T.API;
    y = T.Seff_Topt;

    valid = isfinite(x) & isfinite(y);

    if sum(valid) >= 2
        [Tau_API_Seff_Topt(i), P_API_Seff_Topt(i)] = ...
            corr(x(valid), y(valid), ...
            "Type", "Kendall", ...
            "Rows", "complete");

        N_Topt(i) = sum(valid);

        API_Topt_all = [API_Topt_all; x(valid)];
        Seff_Topt_all = [Seff_Topt_all; y(valid)];
    end


    %% ---------- API vs S_eff[1] ----------

    x = T.API;
    y = T.Seff_1;

    valid = isfinite(x) & isfinite(y);

    if sum(valid) >= 2
        [Tau_API_Seff_1(i), P_API_Seff_1(i)] = ...
            corr(x(valid), y(valid), ...
            "Type", "Kendall", ...
            "Rows", "complete");

        N_Seff1(i) = sum(valid);

        API_Seff1_all = [API_Seff1_all; x(valid)];
        Seff1_all = [Seff1_all; y(valid)];
    end


    %% ---------- API vs S_eff[0] ----------

    x = T.API;
    y = T.Seff_0;

    valid = isfinite(x) & isfinite(y);

    if sum(valid) >= 2
        [Tau_API_Seff_0(i), P_API_Seff_0(i)] = ...
            corr(x(valid), y(valid), ...
            "Type", "Kendall", ...
            "Rows", "complete");

        N_Seff0(i) = sum(valid);

        API_Seff0_all = [API_Seff0_all; x(valid)];
        Seff0_all = [Seff0_all; y(valid)];
    end

end


%% ================= POOLED ALL-NEH CORRELATION =================

[Tau_Topt_All, P_Topt_All] = corr( ...
    API_Topt_all, Seff_Topt_all, ...
    "Type", "Kendall", ...
    "Rows", "complete");

[Tau_Seff1_All, P_Seff1_All] = corr( ...
    API_Seff1_all, Seff1_all, ...
    "Type", "Kendall", ...
    "Rows", "complete");

[Tau_Seff0_All, P_Seff0_All] = corr( ...
    API_Seff0_all, Seff0_all, ...
    "Type", "Kendall", ...
    "Rows", "complete");


%% ================= CREATE OUTPUT TABLE =================

TauTable = table();

TauTable.Station = ["All NEH"; StationName(:)];

TauTable.Tau_API_median_Seff_Topt = [Tau_Topt_All; Tau_API_Seff_Topt];
TauTable.p_API_median_Seff_Topt   = [P_Topt_All; P_API_Seff_Topt];

TauTable.Tau_API_Seff_1 = [Tau_Seff1_All; Tau_API_Seff_1];
TauTable.p_API_Seff_1   = [P_Seff1_All; P_API_Seff_1];

TauTable.Tau_API_Seff_0 = [Tau_Seff0_All; Tau_API_Seff_0];
TauTable.p_API_Seff_0   = [P_Seff0_All; P_API_Seff_0];

TauTable.N_median_Seff_Topt = [numel(API_Topt_all); N_Topt];
TauTable.N_Seff_1 = [numel(API_Seff1_all); N_Seff1];
TauTable.N_Seff_0 = [numel(API_Seff0_all); N_Seff0];

disp(TauTable);

writetable(TauTable, output_excel);

fprintf("\nKendall tau table saved:\n%s\n", output_excel);


%% ================= PLOT GROUPED BAR FIGURE =================

Labels = TauTable.Station;

Y = [ ...
    TauTable.Tau_API_median_Seff_Topt, ...
    TauTable.Tau_API_Seff_1, ...
    TauTable.Tau_API_Seff_0];

figure("Color", "w", "Position", [100 100 1600 700]);

bar(Y, "grouped");
hold on;

yline(0, "k-", "LineWidth", 1.0);

ylim([-1 1]);

set(gca, ...
    "XTick", 1:numel(Labels), ...
    "XTickLabel", Labels, ...
    "FontSize", 12, ...
    "FontWeight", "bold", ...
    "TickDir", "out");

xtickangle(35);

ylabel("Kendall's \tau (API vs S_{eff})", ...
    "FontSize", 16, ...
    "FontWeight", "bold", ...
    "Interpreter", "tex");

legend({ ...
    "API vs median S_{eff}[T_{opt}]", ...
    "API vs S_{eff}[1]", ...
    "API vs S_{eff}[0]"}, ...
    "Location", "southoutside", ...
    "Orientation", "horizontal", ...
    "Box", "on", ...
    "Interpreter", "tex");

title("Association between API and root-zone wetness metrics on MDL days", ...
    "FontSize", 16, ...
    "FontWeight", "bold");

box on;

exportgraphics(gcf, output_figure, "Resolution", 300);

fprintf("Figure saved:\n%s\n", output_figure);