clc; clear; close all;

%% ============================================================
%  Prepare Daily Gridded Rainfall Predictors for RegEM
%
%  Purpose:
%  This script converts year-wise IMD gridded rainfall CSV files into
%  daily lon-lat grid rainfall time series for 1980–2019.
%
%  These gridded rainfall files are later used as predictor variables
%  for RegEM-based missing rainfall imputation at IMD stations.
%
%  Input:
%  Year-wise gridded rainfall CSV files.
%  Each file should contain:
%  Column 1 = Longitude
%  Column 2 = Latitude
%  Columns 3 onward = daily rainfall values
%
%  Output:
%  One daily rainfall text file per grid:
%  dly_precip_<Lon>_&_<Lat>.txt
%
%  Output format:
%  Year Month Day Rainfall
%% ============================================================


%% ================= USER SETTINGS =================

base_folder = "C:\lews_2022-2024\3_new_stations_neh_new\";

input_folder = fullfile(base_folder, ...
    "2_data_preprocessing", ...
    "data_prep_for _regEM", ...
    "imd_gridded_western");

output_folder = fullfile(base_folder, ...
    "2_data_preprocessing", ...
    "data_prep_for _regEM", ...
    "gridded_data_lat_long_gridded");

if ~exist(output_folder, "dir")
    mkdir(output_folder);
end

% Analysis period
start_date = datetime(1980,1,1);
end_date   = datetime(2019,12,31);

full_dates = (start_date:caldays(1):end_date)';

% Spatial domain used for NEH extraction
lon_min = 89;
lon_max = 100;
lat_min = 20;
lat_max = 30;

% Missing value flag in gridded data
missing_flag = -9999;


%% ================= LIST YEAR-WISE CSV FILES =================

year_files = dir(fullfile(input_folder, "*.csv"));

% Remove temporary files
year_files = year_files(arrayfun(@(x) ~startsWith(x.name, "~"), year_files));

if isempty(year_files)
    error("No CSV files found in: %s", input_folder);
end

% Extract year from file name
years = nan(numel(year_files),1);

for i = 1:numel(year_files)

    [~, file_base] = fileparts(year_files(i).name);
    parts = strsplit(file_base, "_");

    years(i) = str2double(parts{1});

end

% Sort files by year
[years, order_id] = sort(years);
year_files = year_files(order_id);


%% ================= READ AND STORE YEAR-WISE DATA =================

YearLonLat = cell(numel(year_files),1);
YearData   = cell(numel(year_files),1);
YearDays   = zeros(numel(year_files),1);

for i = 1:numel(year_files)

    this_year = years(i);
    file_name = year_files(i).name;
    file_path = fullfile(input_folder, file_name);

    fprintf("Reading %s | Year = %d\n", file_name, this_year);

    M = readmatrix(file_path);

    if isempty(M) || size(M,2) < 3
        warning("Skipping %s: file has insufficient columns.", file_name);
        continue;
    end

    %% ---------- Select NEH domain ----------

    M = M(M(:,1) >= lon_min & M(:,1) <= lon_max, :);
    M = M(M(:,2) >= lat_min & M(:,2) <= lat_max, :);

    if isempty(M)
        warning("No grid cells within NEH domain for year %d.", this_year);
        continue;
    end


    %% ---------- Clean missing values ----------

    M(M(:,3:end) == missing_flag) = NaN;

    % Keep only grid cells with complete daily rainfall for this year.
    M(any(isnan(M), 2), :) = [];

    if isempty(M)
        warning("All grid cells removed due to missing values for year %d.", this_year);
        continue;
    end


    %% ---------- Read available daily columns ----------

    expected_days = days(datetime(this_year,12,31) - datetime(this_year,1,1)) + 1;
    available_days = size(M,2) - 2;

    days_to_use = min(expected_days, available_days);

    if days_to_use < expected_days
        warning("Year %d has only %d daily columns; expected %d.", ...
            this_year, days_to_use, expected_days);
    end

    rainfall_block = M(:, 3:(2 + days_to_use));

    % Store:
    % Lon-lat: [nGrid x 2]
    % Rainfall: [nDays x nGrid]
    YearLonLat{i} = round(M(:,1:2), 2);
    YearData{i} = rainfall_block';
    YearDays(i) = days_to_use;

end


%% ================= KEEP ONLY VALID YEARS =================

valid_years = ~cellfun(@isempty, YearData);

YearLonLat = YearLonLat(valid_years);
YearData   = YearData(valid_years);
YearDays   = YearDays(valid_years);
years      = years(valid_years);

if isempty(YearData)
    error("No usable gridded rainfall data after filtering.");
end


%% ================= FIND COMMON GRID CELLS ACROSS YEARS =================

CommonLonLat = YearLonLat{1};

for i = 2:numel(YearLonLat)

    CommonLonLat = intersect(CommonLonLat, YearLonLat{i}, ...
        "rows", "stable");

    if isempty(CommonLonLat)
        error("No common lon-lat grid cells across all valid years.");
    end

end

fprintf("Common grid cells retained: %d\n", size(CommonLonLat,1));


%% ================= ALIGN YEAR-WISE DATA TO COMMON GRID ORDER =================

AlignedData = cell(numel(YearData),1);

for i = 1:numel(YearData)

    [~, grid_position] = ismember(CommonLonLat, YearLonLat{i}, "rows");

    if any(grid_position == 0)
        error("Grid alignment failed for year %d.", years(i));
    end

    AlignedData{i} = YearData{i}(:, grid_position);

end

AllRainfall = vertcat(AlignedData{:});
LonLat = CommonLonLat;


%% ================= BUILD DATE VECTOR FOR AVAILABLE DATA =================

actual_dates = datetime([],[],[]);

for i = 1:numel(years)

    this_year = years(i);
    n_days = YearDays(i);

    if n_days > 0
        year_dates = (datetime(this_year,1,1) + caldays(0:n_days-1))';
        actual_dates = [actual_dates; year_dates]; %#ok<AGROW>
    end

end

if size(AllRainfall,1) ~= numel(actual_dates)
    error("Date and rainfall row count mismatch.");
end


%% ================= STANDARDIZE EACH GRID TO 1980–2019 =================

AAR_Table = nan(size(LonLat,1), 3);

for j = 1:size(LonLat,1)

    lon = LonLat(j,1);
    lat = LonLat(j,2);

    rainfall = AllRainfall(:,j);

    T = timetable(actual_dates, rainfall, ...
        "VariableNames", {'Rain'});

    T = sortrows(T);

    % Remove duplicate dates, if any
    [~, unique_id] = unique(T.Properties.RowTimes, "stable");
    T = T(unique_id,:);

    % Standardize to complete 1980–2019 daily series
    T_full = retime(T, full_dates, "fillwithmissing");

    out_dates = T_full.Properties.RowTimes;
    out_rain = T_full.Rain;

    %% ---------- Annual average rainfall ----------

    year_id = year(out_dates);
    unique_years = unique(year_id, "stable");

    annual_total = nan(numel(unique_years),1);

    for y = 1:numel(unique_years)

        idx_year = year_id == unique_years(y);
        annual_total(y) = sum(out_rain(idx_year), "omitnan");

    end

    AAR = mean(annual_total, "omitnan");

    AAR_Table(j,:) = [lon, lat, AAR];


    %% ---------- Save daily grid rainfall file ----------

    Output = [ ...
        year(out_dates), ...
        month(out_dates), ...
        day(out_dates), ...
        out_rain];

    output_name = sprintf("dly_precip_%2.2f_&_%2.2f.txt", lon, lat);

    writematrix(Output, fullfile(output_folder, output_name), ...
        "Delimiter", "tab");

    fprintf("Saved %s | Rows = %d\n", output_name, size(Output,1));

end


%% ================= SAVE GRID SUMMARY FILES =================

AAR_file = fullfile(output_folder, "Precip_AAR.csv");
writematrix(["Longitude","Latitude","AAR_mm"], AAR_file);
writematrix(AAR_Table, AAR_file, "WriteMode", "append");

LonLat_file = fullfile(output_folder, "LongLat.csv");
writematrix(["Longitude","Latitude"], LonLat_file);
writematrix(LonLat, LonLat_file, "WriteMode", "append");

fprintf("\nGridded rainfall predictor files prepared successfully.\n");
fprintf("Output folder:\n%s\n", output_folder);