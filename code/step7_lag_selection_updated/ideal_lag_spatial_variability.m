clear; clc; close all;

%% ============================================================
% Updated fixed N* spatial map with KDE inset
% Grey stations: Imphal, Kiphira, Nangpoh, Tuensang
% Requires Mapping Toolbox for shaperead.
%% ============================================================

%% File paths
shapeFile = ...
    fullfile(neh_root(),'western_himalayas_landslide','spatial_variation_map','my_study_shape','Himalayan_UP_Bihar.shp');

stationFile = ...
    fullfile(neh_root(),'all_stations_neh.xlsx');

nStarFile = ...
    fullfile(neh_root(),'step7_lag_selection_updated','K_sensitivity_fixed_Nstar','Step8_K_Sensitivity_Fixed_Nstar_ADF.xlsx');

outFolder = ...
    fullfile(neh_root(),'figures_neh_soil_moisture','ideal_lag_4');

if ~exist(outFolder, 'dir')
    mkdir(outFolder);
end

outPNG = fullfile(outFolder, 'Fixed_Nstar_Map_Grey_Excluded_600dpi.png');
outTIFF = fullfile(outFolder, 'Fixed_Nstar_Map_Grey_Excluded_600dpi.tif');

%% Read station locations
% all_stations_neh.xlsx:
% Column A = Station, Column C = Latitude, Column D = Longitude
Tloc = readtable(stationFile, 'Sheet', 'Sheet1', ...
    'VariableNamingRule', 'preserve');

locName = string(Tloc{:, 1});
locLat  = double(Tloc{:, 3});
locLon  = double(Tloc{:, 4});

%% Read updated fixed N* values
% Step8 workbook, Station_summary:
% Column A = Station, Column C = Fixed_Nstar_days
Tn = readtable(nStarFile, 'Sheet', 'Station_summary', ...
    'VariableNamingRule', 'preserve');

nName  = string(Tn.Station);
fixedN = double(Tn.Fixed_Nstar_days);

%% Match updated N* to station coordinates
locKey = normaliseStationName(locName);
nKey   = normaliseStationName(nName);

[isMatched, locIndex] = ismember(nKey, locKey);

if any(~isMatched)
    missingNames = strjoin(cellstr(nName(~isMatched)), ', ');
    error('Coordinates are missing for: %s', missingNames);
end

stationName = nName;
Lat = locLat(locIndex);
Lon = locLon(locIndex);

valid = isfinite(Lat) & isfinite(Lon) & isfinite(fixedN);

stationName = stationName(valid);
Lat         = Lat(valid);
Lon         = Lon(valid);
fixedN      = fixedN(valid);

%% Stations to display in grey
excludedStations = ["Imphal", "Kiphira", "Nangpoh", "Tuensang"];

isExcluded = ismember(normaliseStationName(stationName), ...
    normaliseStationName(excludedStations));

if sum(isExcluded) ~= numel(excludedStations)
    error('One or more excluded station names were not found.');
end

%% Read shapefile
try
    S = shaperead(shapeFile, 'UseGeoCoords', true);
catch
    S = shaperead(shapeFile);
end

%% Keep shapefile polygons that contain at least one station
mainLon = {};
mainLat = {};

for i = 1:numel(S)

    [x, y] = getShapeXY(S(i));
    parts = splitNanParts(x, y);

    if isempty(parts)
        continue
    end

    containsStation = false;

    for p = 1:numel(parts)
        [in, on] = inpolygon(Lon, Lat, parts(p).x, parts(p).y);

        if any(in | on)
            containsStation = true;
            break
        end
    end

    if containsStation
        polygonArea = zeros(numel(parts), 1);

        for p = 1:numel(parts)
            polygonArea(p) = abs(polyarea(parts(p).x, parts(p).y));
        end

        [~, largestPart] = max(polygonArea);

        mainLon{end+1} = parts(largestPart).x;
        mainLat{end+1} = parts(largestPart).y;
    end
end

if isempty(mainLon)
    error('No shapefile polygons intersected the station locations.');
end

%% Figure settings
mapXLim = [85.5 97.0];
mapYLim = [21.5 29.5];

pointSize = 85;
greyColor = [0.50 0.50 0.50];       % #808080
landColor = [0.97 0.97 0.97];
edgeColor = [0.28 0.28 0.28];

includedN = fixedN(~isExcluded);

%% Create figure
fig = figure( ...
    'Color', 'w', ...
    'Units', 'inches', ...
    'Position', [1 1 12 8], ...
    'Renderer', 'painters');

ax = axes(fig, 'Position', [0.08 0.22 0.80 0.69]);
hold(ax, 'on');

%% Draw NEH polygons
for i = 1:numel(mainLon)
    patch(ax, ...
        mainLon{i}, mainLat{i}, landColor, ...
        'EdgeColor', edgeColor, ...
        'LineWidth', 0.75);
end

%% Map gridlines
for xg = 86:1:96
    plot(ax, [xg xg], mapYLim, '-', ...
        'Color', [0.90 0.90 0.90], ...
        'LineWidth', 0.6);
end

for yg = 22:1:29
    plot(ax, mapXLim, [yg yg], '-', ...
        'Color', [0.90 0.90 0.90], ...
        'LineWidth', 0.6);
end

%% Plot included stations, coloured by updated fixed N*
scatter(ax, Lon(~isExcluded), Lat(~isExcluded), pointSize, ...
    fixedN(~isExcluded), ...
    'filled', ...
    'Marker', 'o', ...
    'MarkerEdgeColor', 'k', ...
    'LineWidth', 0.8);

%% Plot excluded stations in grey
scatter(ax, Lon(isExcluded), Lat(isExcluded), pointSize, ...
    'filled', ...
    'Marker', 'o', ...
    'MarkerFaceColor', greyColor, ...
    'MarkerEdgeColor', 'k', ...
    'LineWidth', 0.8);

%% Colormap and colour scale
colormap(ax, plasmaReverse(256));
clim(ax, [min(includedN) max(includedN)]);

cb = colorbar(ax, 'southoutside');
cb.Position = [0.16 0.075 0.64 0.028];
cb.Ticks = sort(unique(includedN));
cb.TickDirection = 'out';
cb.LineWidth = 0.8;
cb.FontName = 'Arial';
cb.FontSize = 12;
cb.Label.String = 'Fixed N* (days)';
cb.Label.FontName = 'Arial';
cb.Label.FontSize = 14;
cb.Label.FontWeight = 'bold';

%% Axis formatting
axis(ax, 'equal');
xlim(ax, mapXLim);
ylim(ax, mapYLim);

xticks(ax, 86:2:96);
yticks(ax, 22:1:29);

xticklabels(ax, degreeLabels(xticks(ax), 'E'));
yticklabels(ax, degreeLabels(yticks(ax), 'N'));

xlabel(ax, 'Longitude', ...
    'FontName', 'Arial', ...
    'FontSize', 15, ...
    'FontWeight', 'bold');

ylabel(ax, 'Latitude', ...
    'FontName', 'Arial', ...
    'FontSize', 15, ...
    'FontWeight', 'bold');

set(ax, ...
    'FontName', 'Arial', ...
    'FontSize', 12, ...
    'LineWidth', 0.9, ...
    'TickDir', 'out', ...
    'Box', 'on', ...
    'Layer', 'top');

text(ax, 0.01, 0.98, '(a)', ...
    'Units', 'normalized', ...
    'FontName', 'Arial', ...
    'FontSize', 15, ...
    'FontWeight', 'bold', ...
    'VerticalAlignment', 'top');

%% KDE inset: all 21 updated N* values
insetAx = axes(fig, 'Position', [0.68 0.32 0.20 0.20]);
hold(insetAx, 'on');

xKDE = linspace(min(fixedN) - 1, max(fixedN) + 1, 500);

if exist('ksdensity', 'file') == 2
    [density, xKDE] = ksdensity(fixedN, xKDE);
else
    density = simpleKDE(fixedN, xKDE);
end

plot(insetAx, xKDE, density, ...
    'Color', [0.85 0.10 0.10], ...
    'LineWidth', 1.5);

medianN = median(fixedN, 'omitnan');

xline(insetAx, medianN, '--', ...
    'Color', [0.85 0.10 0.10], ...
    'LineWidth', 1.1);

xlabel(insetAx, 'Fixed N* (days)', ...
    'FontName', 'Arial', ...
    'FontSize', 8, ...
    'FontWeight', 'bold');

ylabel(insetAx, 'Density', ...
    'FontName', 'Arial', ...
    'FontSize', 8, ...
    'FontWeight', 'bold');

set(insetAx, ...
    'FontName', 'Arial', ...
    'FontSize', 7, ...
    'LineWidth', 0.7, ...
    'Box', 'on', ...
    'TickDir', 'out');

grid(insetAx, 'on');
insetAx.GridColor = [0.86 0.86 0.86];
insetAx.GridAlpha = 0.55;

%% Export
exportgraphics(fig, outPNG, 'Resolution', 600);
exportgraphics(fig, outTIFF, 'Resolution', 600);

fprintf('Figure saved:\n%s\n%s\n', outPNG, outTIFF);

%% ============================================================
% Local functions
%% ============================================================





