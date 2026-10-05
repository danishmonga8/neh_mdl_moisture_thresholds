%% ============================================================
%  Bivariate Rainfall-Temperature Climatology Map
%
%  Purpose:
%  This script prepares a bivariate map showing the spatial
%  combination of rainfall and temperature climatology over the
%  NEH study region.
%
%  Input:
%  1. Rainfall climatology NetCDF
%  2. Temperature climatology NetCDF
%  3. Study-area shapefile
%  4. Station file
%
%  Output:
%  1. Bivariate rainfall-temperature map
%  2. Rainfall and temperature regional summary tables
%% ============================================================

clear; clc; close all;

%% ================= USER SETTINGS =================

data_folder = "C:\lews_2022-2024\3_new_stations_neh_new\figures_neh_soil_moisture\study_area_additional_figure_1a&b\era-5_temp";

shape_file = "C:\lews_2022-2024\western_himalayas_landslide\spatial_variation_map\my_study_shape\Himalayan_UP_Bihar.shp";

station_file = "C:\lews_2022-2024\3_new_stations_neh_new\Final_Threshold_Output.xlsx";

output_folder = "C:\lews_2022-2024\3_new_stations_neh_new\figures_neh_soil_moisture\study_area_climatology";

if ~exist(output_folder, "dir")
    mkdir(output_folder);
end

rain_file = fullfile(data_folder, "rain_climatology_2007_2021.nc");
temp_file = fullfile(data_folder, "temp_climatology_2007_2021.nc");

output_figure = fullfile(output_folder, "bivariate_rainfall_temperature_climatology.png");
output_summary = fullfile(output_folder, "rainfall_temperature_climatology_summary.xlsx");

% NetCDF variable names
lon_var  = "lon";
lat_var  = "lat";
rain_var = "RAINFALL";
temp_var = "tmp";

% Number of bivariate classes
n_rain_class = 7;
n_temp_class = 6;

% Map padding
pad_degree = 0.35;


%% ================= READ STATION FILE =================

Station = readtable(station_file);

% Expected:
% Column 3 = Latitude
% Column 4 = Longitude
station_lat = Station{:,3};
station_lon = Station{:,4};


%% ================= READ SHAPEFILE =================

ShapeAll = shaperead(shape_file);

% Keep only polygons intersecting station locations
keep_shape = false(numel(ShapeAll),1);

for i = 1:numel(ShapeAll)

    inside = inpolygon(station_lon, station_lat, ...
        ShapeAll(i).X, ShapeAll(i).Y);

    keep_shape(i) = any(inside);

end

Shape = ShapeAll(keep_shape);

% Study-area bounding box
all_lon_shape = [];
all_lat_shape = [];

for i = 1:numel(Shape)
    all_lon_shape = [all_lon_shape; Shape(i).X(:)];
    all_lat_shape = [all_lat_shape; Shape(i).Y(:)];
end

all_lon_shape = all_lon_shape(isfinite(all_lon_shape));
all_lat_shape = all_lat_shape(isfinite(all_lat_shape));

xmin = min(all_lon_shape);
xmax = max(all_lon_shape);
ymin = min(all_lat_shape);
ymax = max(all_lat_shape);


%% ================= READ RAINFALL CLIMATOLOGY =================

lon_rain = double(ncread(rain_file, lon_var));
lat_rain = double(ncread(rain_file, lat_var));
Rain = double(squeeze(ncread(rain_file, rain_var)));

% Ensure Rain is arranged as [lat x lon]
if isequal(size(Rain), [numel(lon_rain), numel(lat_rain)])
    Rain = Rain';
end

% Ensure latitude and longitude are increasing
if lat_rain(1) > lat_rain(end)
    lat_rain = flipud(lat_rain);
    Rain = flipud(Rain);
end

if lon_rain(1) > lon_rain(end)
    lon_rain = flipud(lon_rain);
    Rain = fliplr(Rain);
end


%% ================= READ TEMPERATURE CLIMATOLOGY =================

lon_temp = double(ncread(temp_file, lon_var));
lat_temp = double(ncread(temp_file, lat_var));
Temp = double(squeeze(ncread(temp_file, temp_var)));

% Ensure Temp is arranged as [lat x lon]
if isequal(size(Temp), [numel(lon_temp), numel(lat_temp)])
    Temp = Temp';
end

% Ensure latitude and longitude are increasing
if lat_temp(1) > lat_temp(end)
    lat_temp = flipud(lat_temp);
    Temp = flipud(Temp);
end

if lon_temp(1) > lon_temp(end)
    lon_temp = flipud(lon_temp);
    Temp = fliplr(Temp);
end


%% ================= CROP TO STUDY REGION =================

lon_mask_rain = lon_rain >= (xmin - pad_degree) & lon_rain <= (xmax + pad_degree);
lat_mask_rain = lat_rain >= (ymin - pad_degree) & lat_rain <= (ymax + pad_degree);

lon_mask_temp = lon_temp >= (xmin - pad_degree) & lon_temp <= (xmax + pad_degree);
lat_mask_temp = lat_temp >= (ymin - pad_degree) & lat_temp <= (ymax + pad_degree);

lon = lon_rain(lon_mask_rain);
lat = lat_rain(lat_mask_rain);

Rain = Rain(lat_mask_rain, lon_mask_rain);
Temp = Temp(lat_mask_temp, lon_mask_temp);

% Simple check: rainfall and temperature must be on the same grid
if ~isequal(size(Rain), size(Temp))
    error("Rainfall and temperature grids are not the same size after cropping. Please regrid one dataset before plotting.");
end

[LON, LAT] = meshgrid(lon, lat);


%% ================= APPLY STUDY-AREA MASK =================

study_mask = false(size(LON));

for i = 1:numel(Shape)

    this_mask = inpolygon(LON, LAT, Shape(i).X, Shape(i).Y);

    study_mask = study_mask | this_mask;

end

Rain(~study_mask) = NaN;
Temp(~study_mask) = NaN;


%% ================= CREATE RAINFALL AND TEMPERATURE CLASSES =================

rain_values = Rain(study_mask & isfinite(Rain));
temp_values = Temp(study_mask & isfinite(Temp));

rain_edges = quantile(rain_values, linspace(0,1,n_rain_class+1));
temp_edges = quantile(temp_values, linspace(0,1,n_temp_class+1));

% Avoid duplicate class edges
for i = 2:numel(rain_edges)
    if rain_edges(i) <= rain_edges(i-1)
        rain_edges(i) = rain_edges(i-1) + eps;
    end
end

for i = 2:numel(temp_edges)
    if temp_edges(i) <= temp_edges(i-1)
        temp_edges(i) = temp_edges(i-1) + eps;
    end
end

rain_class = NaN(size(Rain));
temp_class = NaN(size(Temp));

for i = 1:n_rain_class

    if i < n_rain_class
        idx = Rain >= rain_edges(i) & Rain < rain_edges(i+1);
    else
        idx = Rain >= rain_edges(i) & Rain <= rain_edges(i+1);
    end

    rain_class(idx) = i;

end

for j = 1:n_temp_class

    if j < n_temp_class
        idx = Temp >= temp_edges(j) & Temp < temp_edges(j+1);
    else
        idx = Temp >= temp_edges(j) & Temp <= temp_edges(j+1);
    end

    temp_class(idx) = j;

end


%% ================= CREATE BIVARIATE COLOR MATRIX =================

% Corner colors:
% c00 = low rainfall, low temperature
% c10 = low rainfall, high temperature
% c01 = high rainfall, low temperature
% c11 = high rainfall, high temperature

c00 = [0.72 0.78 0.84];
c10 = [0.90 0.43 0.16];
c01 = [0.20 0.55 0.88];
c11 = [0.12 0.50 0.20];

biv_color = zeros(n_rain_class, n_temp_class, 3);

for i = 1:n_rain_class

    for j = 1:n_temp_class

        u = (j - 1) / (n_temp_class - 1);
        v = (i - 1) / (n_rain_class - 1);

        this_color = ...
            (1-u) * (1-v) * c00 + ...
             u    * (1-v) * c10 + ...
            (1-u) *  v    * c01 + ...
             u    *  v    * c11;

        biv_color(i,j,:) = this_color;

    end

end

% Initialize map as grey
rgb_map = zeros([size(Rain), 3]);
rgb_map(:,:,1) = 0.78;
rgb_map(:,:,2) = 0.78;
rgb_map(:,:,3) = 0.78;

% Assign bivariate colors
for i = 1:n_rain_class

    for j = 1:n_temp_class

        idx = rain_class == i & temp_class == j;

        tmp_r = rgb_map(:,:,1);
        tmp_g = rgb_map(:,:,2);
        tmp_b = rgb_map(:,:,3);

        tmp_r(idx) = biv_color(i,j,1);
        tmp_g(idx) = biv_color(i,j,2);
        tmp_b(idx) = biv_color(i,j,3);

        rgb_map(:,:,1) = tmp_r;
        rgb_map(:,:,2) = tmp_g;
        rgb_map(:,:,3) = tmp_b;

    end

end


%% ================= LEGEND LABELS =================

rain_mid = 5 * round(((rain_edges(1:end-1) + rain_edges(2:end)) / 2) / 5);
temp_mid = 5 * round(((temp_edges(1:end-1) + temp_edges(2:end)) / 5);


%% ================= PLOT MAP =================

fig = figure("Color", "w", "Position", [70 35 1320 920]);

% Main map
ax1 = axes("Position", [0.08 0.10 0.84 0.80]);
hold(ax1, "on");

h_map = image(ax1, [lon(1) lon(end)], [lat(1) lat(end)], rgb_map);

set(ax1, "YDir", "normal");

% Show only study-area cells
set(h_map, "AlphaData", double(study_mask));

% Shape outline
for i = 1:numel(Shape)

    plot(ax1, Shape(i).X, Shape(i).Y, ...
        "Color", [0.30 0.30 0.30], ...
        "LineWidth", 0.9);

end

% Station markers
plot(ax1, station_lon, station_lat, "^", ...
    "MarkerSize", 8.2, ...
    "MarkerFaceColor", "k", ...
    "MarkerEdgeColor", "w", ...
    "LineWidth", 1.0);

xlim(ax1, [xmin - pad_degree, xmax + pad_degree]);
ylim(ax1, [ymin - pad_degree, ymax + pad_degree]);

axis(ax1, "equal");

xt = 86:2:96;
yt = 22:2:28;

set(ax1, "XTick", xt, "YTick", yt);
set(ax1, "XTickLabel", compose("%d°E", xt));
set(ax1, "YTickLabel", compose("%d°N", yt));

grid(ax1, "on");
ax1.GridLineStyle = "--";
ax1.GridColor = [0.84 0.84 0.84];
ax1.GridAlpha = 1;
ax1.LineWidth = 0.8;
ax1.FontSize = 19;
ax1.FontName = "Arial";
ax1.Box = "off";
ax1.Layer = "top";
ax1.TickDir = "out";

xlabel(ax1, "Longitude", ...
    "FontSize", 20, ...
    "FontWeight", "bold", ...
    "FontName", "Arial");

ylabel(ax1, "Latitude", ...
    "FontSize", 20, ...
    "FontWeight", "bold", ...
    "FontName", "Arial");


%% ================= BIVARIATE LEGEND =================

ax2 = axes("Position", [0.77 0.16 0.13 0.20]);

image(ax2, [1 n_temp_class], [1 n_rain_class], biv_color);

set(ax2, "YDir", "normal");

ax2.XTick = 1:n_temp_class;
ax2.YTick = 1:n_rain_class;
ax2.XTickLabel = string(temp_mid);
ax2.YTickLabel = string(rain_mid);

ax2.FontSize = 8.5;
ax2.FontName = "Arial";
ax2.LineWidth = 0.8;
ax2.Box = "on";
ax2.Layer = "top";

pbaspect(ax2, [n_temp_class n_rain_class 1]);

xlabel(ax2, "Temperature (°C) →", ...
    "FontSize", 11, ...
    "FontWeight", "bold", ...
    "FontName", "Arial");

ylabel(ax2, "Rainfall (mm yr^{-1})", ...
    "FontSize", 11, ...
    "FontWeight", "bold", ...
    "FontName", "Arial");

grid(ax2, "on");
ax2.GridColor = [0.86 0.86 0.86];
ax2.GridLineStyle = "-";


%% ================= REGIONAL SUMMARY =================

valid_rain = study_mask & isfinite(Rain);
valid_temp = study_mask & isfinite(Temp);

rain_data = Rain(valid_rain);
temp_data = Temp(valid_temp);

lat_rain = LAT(valid_rain);
lat_temp = LAT(valid_temp);

% Cosine-latitude weights
w_rain = cosd(lat_rain);
w_temp = cosd(lat_temp);

w_rain = w_rain ./ sum(w_rain);
w_temp = w_temp ./ sum(w_temp);

RainfallSummary = table();

RainfallSummary.ValidCells = nnz(valid_rain);
RainfallSummary.MissingPct = 100 * (nnz(study_mask) - nnz(valid_rain)) / nnz(study_mask);
RainfallSummary.AreaWeightedMean_mm_yr = sum(rain_data .* w_rain);
RainfallSummary.Mean_mm_yr = mean(rain_data);
RainfallSummary.Median_mm_yr = median(rain_data);
RainfallSummary.Std_mm_yr = std(rain_data);
RainfallSummary.Min_mm_yr = min(rain_data);
RainfallSummary.Max_mm_yr = max(rain_data);
RainfallSummary.Q1_mm_yr = quantile(rain_data, 0.25);
RainfallSummary.Q3_mm_yr = quantile(rain_data, 0.75);
RainfallSummary.IQR_mm_yr = iqr(rain_data);
RainfallSummary.CV_pct = 100 * RainfallSummary.Std_mm_yr / RainfallSummary.Mean_mm_yr;

TemperatureSummary = table();

TemperatureSummary.ValidCells = nnz(valid_temp);
TemperatureSummary.MissingPct = 100 * (nnz(study_mask) - nnz(valid_temp)) / nnz(study_mask);
TemperatureSummary.AreaWeightedMean_degC = sum(temp_data .* w_temp);
TemperatureSummary.Mean_degC = mean(temp_data);
TemperatureSummary.Median_degC = median(temp_data);
TemperatureSummary.Std_degC = std(temp_data);
TemperatureSummary.Min_degC = min(temp_data);
TemperatureSummary.Max_degC = max(temp_data);
TemperatureSummary.Q1_degC = quantile(temp_data, 0.25);
TemperatureSummary.Q3_degC = quantile(temp_data, 0.75);
TemperatureSummary.IQR_degC = iqr(temp_data);

