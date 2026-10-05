clc; clear; close all;

%% ============================================================
%  Antecedent Dominance Fraction (ADF) for MDL Events
%
%  Purpose:
%  This script computes the Antecedent Dominance Fraction (ADF)
%  for each NEH station using moisture-driven landslide (MDL)
%  event dates, triggering rainfall (TR), and antecedent moisture
%  condition (AMC/API) at the station-specific optimal lag.
%
%  Formula:
%
%  ADF = N(AMC > TR) / N(total eligible MDL events)
%
%  where:
%  N(AMC > TR) = number of MDL events for which antecedent
%                moisture exceeds triggering rainfall
%
%  N(total eligible MDL events) = number of MDL events for which
%                                 both AMC and TR are available
%
%  Interpretation:
%  ADF > 0.50  -> antecedent moisture dominance is more frequent
%  ADF < 0.50  -> triggering rainfall dominance is more frequent
%
%  Note:
%  Multiple MDL records on the same date are retained as separate
%  MDL events, consistent with the event-record-based analysis.
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

output_folder = fullfile(base_folder, "amc_contribution");

if ~exist(output_folder, "dir")
    mkdir(output_folder);
end

output_file = fullfile(output_folder, ...
    "adf_station_summary.xlsx");

% Analysis period
start_date = datetime(2007,1,1);
end_date   = datetime(2019,12,31);   % Change to 2021 if final dataset is complete


%% ================= READ STATION METADATA =================

Metadata = readtable(metadata_file, ...
    "TextType", "string", ...
    "VariableNamingRule", "preserve");

% Column positions in metadata file
station_col = 1;   % Station name
wmo_col     = 2;   % WMO / station ID
lag_col     = 5;   % Optimal antecedent lag
lat_col     = "Lat";
lon_col     = "Lon";

n_stations = height(Metadata);


%% ================= CREATE OUTPUT TABLE =================

Summary = table();

Summary.Station = strings(n_stations,1);
Summary.WMO = strings(n_stations,1);
Summary.Lat = nan(n_stations,1);
Summary.Lon = nan(n_stations,1);
Summary.OptimalLag_days = nan(n_stations,1);

Summary.MDL_TotalEvents = nan(n_stations,1);
Summary.MDL_EligibleEvents = nan(n_stations,1);
Summary.AMC_Dominant_Events = nan(n_stations,1);
Summary.TR_Dominant_Events = nan(n_stations,1);

Summary.ADF = nan(n_stations,1);
Summary.Dominant_Control = strings(n_stations,1);


%% ================= MAIN CALCULATION =================

for i = 1:n_stations

    station_name = strtrim(string(Metadata{i, station_col}));
    wmo = cleanWMO(Metadata{i, wmo_col});
    optimal_lag = round(double(Metadata{i, lag_col}));

    lat = double(Metadata{i, lat_col});
    lon = double(Metadata{i, lon_col});

    fprintf("\nProcessing %s | WMO = %s | optimal lag = %d days\n", ...
        station_name, string(wmo), optimal_lag);


    %% ---------- Input files ----------

    mdl_file = resolveWmoFile(mdl_folder, wmo, ".txt", "landslide_");

    amc_lag_folder = fullfile(amc_folder, sprintf("%d_day", optimal_lag));
    amc_file = resolveWmoFile(amc_lag_folder, wmo, ".txt", "", optimal_lag);

    tr_file = resolveWmoFile(tr_folder, wmo, ".txt", "_trigging");


    %% ---------- Read MDL, AMC, and TR data ----------

    MDL_raw = readmatrix(mdl_file, "FileType", "text");
    AMC_raw = readmatrix(amc_file, "FileType", "text");
    TR_raw  = readmatrix(tr_file, "FileType", "text");

    % MDL file: columns 4–6 contain year, month, and day.
    MDL_date = datetime(MDL_raw(:,4), MDL_raw(:,5), MDL_raw(:,6));
    MDL_Event_ID = (1:numel(MDL_date))';

    T_mdl = table(MDL_Event_ID, MDL_date, ...
        "VariableNames", {'MDL_Event_ID','Date'});

    % AMC/API file: columns 1–3 contain date and column 4 contains AMC/API.
    AMC_date = datetime(AMC_raw(:,1), AMC_raw(:,2), AMC_raw(:,3));
    T_amc_raw = table(AMC_date, AMC_raw(:,4), ...
        "VariableNames", {'Date','AMC'});

    % TR file: columns 1–3 contain date and column 4 contains TR.
    TR_date = datetime(TR_raw(:,1), TR_raw(:,2), TR_raw(:,3));
    T_tr_raw = table(TR_date, TR_raw(:,4), ...
        "VariableNames", {'Date','TR'});


    %% ---------- Prepare daily AMC and TR values ----------

    % If AMC or TR files contain repeated dates, collapse them to one
    % representative daily value. Median is used to avoid duplicate-date bias.

    T_amc = groupsummary(T_amc_raw, "Date", "median", "AMC");
    T_amc = T_amc(:, {'Date','median_AMC'});
    T_amc.Properties.VariableNames = {'Date','AMC'};

    T_tr = groupsummary(T_tr_raw, "Date", "median", "TR");
    T_tr = T_tr(:, {'Date','median_TR'});
    T_tr.Properties.VariableNames = {'Date','TR'};


    %% ---------- Join MDL events with AMC and TR ----------

    T = innerjoin(T_mdl, T_amc, "Keys", "Date");
    T = innerjoin(T, T_tr, "Keys", "Date");

    % Keep only the analysis period.
    T = T(T.Date >= start_date & T.Date <= end_date, :);


    %% ---------- Calculate ADF ----------

    MDL_TotalEvents = height(T_mdl);
    MDL_EligibleEvents = height(T);

    AMC_Dominant = T.AMC > T.TR;
    TR_Dominant  = T.TR >= T.AMC;

    AMC_Dominant_Events = sum(AMC_Dominant);
    TR_Dominant_Events  = sum(TR_Dominant);

    if MDL_EligibleEvents > 0
        ADF = AMC_Dominant_Events / MDL_EligibleEvents;
    else
        ADF = NaN;
    end

    if ADF > 0.50
        Dominant_Control = "AMC-dominant";
    elseif ADF < 0.50
        Dominant_Control = "TR-dominant";
    elseif ADF == 0.50
        Dominant_Control = "Balanced";
    else
        Dominant_Control = "Not available";
    end


    %% ---------- Store station-wise results ----------

    Summary.Station(i) = station_name;
    Summary.WMO(i) = string(wmo);
    Summary.Lat(i) = lat;
    Summary.Lon(i) = lon;
    Summary.OptimalLag_days(i) = optimal_lag;

    Summary.MDL_TotalEvents(i) = MDL_TotalEvents;
    Summary.MDL_EligibleEvents(i) = MDL_EligibleEvents;
    Summary.AMC_Dominant_Events(i) = AMC_Dominant_Events;
    Summary.TR_Dominant_Events(i) = TR_Dominant_Events;

    Summary.ADF(i) = ADF;
    Summary.Dominant_Control(i) = Dominant_Control;

    fprintf("Eligible MDL events = %d | AMC-dominant = %d | TR-dominant = %d | ADF = %.3f\n", ...
        MDL_EligibleEvents, AMC_Dominant_Events, TR_Dominant_Events, ADF);

end


%% ================= SAVE OUTPUT =================

writetable(Summary, output_file);

fprintf("\nADF station summary saved:\n%s\n", output_file);



