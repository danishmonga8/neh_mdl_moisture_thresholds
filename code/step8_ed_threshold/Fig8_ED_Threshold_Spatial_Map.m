%% ========================================================================
% FIGURE (a) -- ED-THRESHOLD SPATIAL VARIABILITY MAP
%
% Rainfall threshold (mm), 3-day duration, linear quantile regression at
% tau = 0.20 (E3_P20), one value per station, read directly from the
% already-computed ED_Linear_vs_PowerLaw_AllStations.xlsx workbook
% (Linear_quantile sheet -- no quantile regression is re-fit here).
%
% Stations with fewer than MIN_EVENTS matched landslide events (same
% Matched_events count used in the corrected-ADF pipeline) are plotted in
% grey instead of being colour-mapped, and are excluded from the inset
% density curve, for the same reason as in Step2_ADF_Correction.m: the
% underlying statistic is not considered reliable at very small n.
%
% OUTPUT:
%   Fig8a_ED_Threshold_Spatial_Map_P20_D3.jpg  (300 dpi)
% ========================================================================

clc;
clear;
close all;


%% ========================================================================
% 1. PATHS
%% ========================================================================

shapefile_path = ...
    fullfile(neh_root(),'western_himalayas_landslide','spatial_variation_map','my_study_shape','Himalayan_UP_Bihar.shp');

station_excel = ...
    fullfile(neh_root(),'all_stations_neh.xlsx');

ED_FILE = ...
    fullfile(neh_root(),'step8_ed_threshold','ED_Linear_vs_PowerLaw_AllStations.xlsx');

% Updated (independently-selected-N*) ADF results -- see
% Step2_ADF_Correction.m. Matched_events is reused here purely as the
% "how many landslide points does this station have" count for the grey
% threshold; ADF itself is not plotted in this figure.
ADF_FILE = ...
    fullfile(neh_root(),'step2_adf_correction','Step2_ADF_Corrected_Results.xlsx');

OUT_DIR = ...
    fullfile(neh_root(),'step8_ed_threshold');


if ~exist(OUT_DIR,'dir')
    mkdir(OUT_DIR);
end


%% ========================================================================
% 2. CONFIGURATION
%% ========================================================================

TAU_LEVEL = 0.20;
DUR_DAYS  = 3;

MIN_EVENTS_FOR_CLASSIFICATION = 15;

OUT_JPG = fullfile( ...
    OUT_DIR, ...
    'Fig8a_ED_Threshold_Spatial_Map_P20_D3.jpg');


%% ========================================================================
% 3. READ STATION METADATA (Lat/Lon)
%% ========================================================================

optsMeta = detectImportOptions( ...
    station_excel, ...
    'Sheet','Sheet1', ...
    'VariableNamingRule','preserve', ...
    'TextType','string');


TM = readtable( ...
    station_excel, ...
    optsMeta);


metaVarsKey = lower( ...
    strtrim(string(TM.Properties.VariableNames)));


latCol = find( ...
    contains(metaVarsKey,"lat"), ...
    1,'first');


lonCol = find( ...
    metaVarsKey == "long" | contains(metaVarsKey,"lon"), ...
    1,'first');


TMeta = table( ...
    strip(string(TM{:,1})), ...
    normalizeID(TM{:,2}), ...
    double(TM{:,latCol}), ...
    double(TM{:,lonCol}), ...
    'VariableNames', ...
    {'Station','IMD_ID','Lat','Lon'});


[~,idxUnique] = unique(TMeta.IMD_ID,'stable');

TMeta = TMeta(idxUnique,:);


%% ========================================================================
% 4. READ ED THRESHOLD (E3_P20, LINEAR QUANTILE REGRESSION)
%% ========================================================================

TED = readtable( ...
    ED_FILE, ...
    'Sheet','Linear_quantile', ...
    'VariableNamingRule','preserve', ...
    'TextType','string');


TED.IMD_ID = normalizeID(TED.IMD_ID);

TED = TED(string(TED.Status) == "OK", :);

TED = TED(:, {'IMD_ID','E3_P20'});


%% ========================================================================
% 5. READ UPDATED ADF RESULTS (for the Matched_events / <15 flag only)
%% ========================================================================

TADF = readtable( ...
    ADF_FILE, ...
    'Sheet','ADF_summary', ...
    'VariableNamingRule','preserve', ...
    'TextType','string');


TADF.IMD_ID = normalizeID(TADF.IMD_ID);

TADF = TADF(string(TADF.Status) == "OK", :);

TADF = TADF(:, {'IMD_ID','Matched_events'});


%% ========================================================================
% 6. JOIN + FLAG LOW-SAMPLE STATIONS
%% ========================================================================

Spatial = innerjoin(TMeta, TED, 'Keys','IMD_ID');

Spatial = innerjoin(Spatial, TADF, 'Keys','IMD_ID');

Spatial = Spatial( ...
    isfinite(Spatial.Lat) & ...
    isfinite(Spatial.Lon) & ...
    isfinite(Spatial.E3_P20), :);


Spatial.Low_sample = ...
    Spatial.Matched_events < MIN_EVENTS_FOR_CLASSIFICATION;


fprintf('Stations plotted: %d  |  Low-sample (<%d matched events, greyed): %d\n', ...
    height(Spatial), MIN_EVENTS_FOR_CLASSIFICATION, sum(Spatial.Low_sample));


%% ========================================================================
% 7. COLORMAP (same anchors as ADF / Gini figures)
%% ========================================================================

anchor = [ ...
    252 253 191
    251 191 115
    239 104 102
    175  54 160
     66  15 112
      0   0   4] / 255;


cmap = interp1( ...
    linspace(0,1,size(anchor,1)), ...
    anchor, ...
    linspace(0,1,256), ...
    'pchip');


%% ========================================================================
% 8. READ SHAPEFILE, KEEP ONLY POLYGONS INTERSECTING NEH STATIONS
%% ========================================================================

Sall = shaperead( ...
    shapefile_path, ...
    'UseGeoCoords',true);


nehStationMask = ...
    isfinite(TMeta.Lat) & isfinite(TMeta.Lon) & ...
    TMeta.Lat >= 21.5 & TMeta.Lat <= 30.0 & ...
    TMeta.Lon >= 87.0 & TMeta.Lon <= 98.0;


allMetaLat = TMeta.Lat(nehStationMask);
allMetaLon = TMeta.Lon(nehStationMask);


keepShape = false(numel(Sall),1);


for i = 1:numel(Sall)

    Xall = Sall(i).Lon(:);
    Yall = Sall(i).Lat(:);

    if isempty(Xall) || isempty(Yall)
        continue
    end

    nanBreaks = find(isnan(Xall) | isnan(Yall));
    segStart = [1; nanBreaks+1];
    segEnd = [nanBreaks-1; numel(Xall)];

    insideThisShape = false;

    for s = 1:numel(segStart)

        i1 = segStart(s); i2 = segEnd(s);

        if i2 <= i1
            continue
        end

        xs = Xall(i1:i2); ys = Yall(i1:i2);
        good = isfinite(xs) & isfinite(ys);
        xs = xs(good); ys = ys(good);

        if numel(xs) < 3
            continue
        end

        if any(inpolygon(allMetaLon, allMetaLat, xs, ys))
            insideThisShape = true;
            break
        end

    end

    keepShape(i) = insideThisShape;

end


S = Sall(keepShape);

if isempty(S)
    error('No NEH polygons were retained. Check shapefile and coordinates.');
end


allLonShape = []; allLatShape = [];

for i = 1:numel(S)
    allLonShape = [allLonShape; S(i).Lon(:)]; %#ok<AGROW>
    allLatShape = [allLatShape; S(i).Lat(:)]; %#ok<AGROW>
end

allLonShape = allLonShape(isfinite(allLonShape));
allLatShape = allLatShape(isfinite(allLatShape));

bbXmin = min(allLonShape); bbXmax = max(allLonShape);
bbYmin = min(allLatShape); bbYmax = max(allLatShape);

padX = 0.03*(bbXmax-bbXmin);
padY = 0.03*(bbYmax-bbYmin);

xlimMap = [bbXmin-padX, bbXmax+padX];
ylimMap = [bbYmin-padY, bbYmax+padY];

lonMajor = floor(xlimMap(1)):1:ceil(xlimMap(2));
latMajor = floor(ylimMap(1)):1:ceil(ylimMap(2));


%% ========================================================================
% 9. STYLE
%% ========================================================================

axisTitleSize = 22;
axisTextSize  = 16;
cbarTitleSize = 18;
cbarTextSize  = 14;

markerSize  = 200;
markerAlpha = 0.80;

shapeEdgeLW  = 1.00;
shapeEdgeCol = [0.22 0.22 0.22];

gridColor = [0.80 0.80 0.80];
gridLW    = 0.40;

lowSampleColor = [0.65 0.65 0.65];


%% ========================================================================
% 10. MAP
%% ========================================================================

fig = figure( ...
    'Color','w', ...
    'Units','inches', ...
    'Position',[1 1 11 8.5]);


ax = axes( ...
    'Parent',fig, ...
    'Position',[0.09 0.26 0.85 0.66]);


hold(ax,'on');


for i = 1:numel(S)
    patch(ax, S(i).Lon, S(i).Lat, [0.96 0.96 0.96], ...
        'EdgeColor',shapeEdgeCol, 'LineWidth',shapeEdgeLW);
end


for xg = lonMajor
    plot(ax, [xg xg], [ylimMap(1) ylimMap(2)], '--', 'Color',gridColor, 'LineWidth',gridLW);
end

for yg = latMajor
    plot(ax, [xlimMap(1) xlimMap(2)], [yg yg], '--', 'Color',gridColor, 'LineWidth',gridLW);
end


isLow = Spatial.Low_sample;


scatter(ax, Spatial.Lon(isLow), Spatial.Lat(isLow), markerSize, lowSampleColor, ...
    'filled', 'MarkerFaceAlpha',markerAlpha, 'MarkerEdgeColor','k', 'LineWidth',1.0);


sc = scatter(ax, Spatial.Lon(~isLow), Spatial.Lat(~isLow), markerSize, Spatial.E3_P20(~isLow), ...
    'filled', 'MarkerFaceAlpha',markerAlpha, 'MarkerEdgeColor','k', 'LineWidth',1.0);


colormap(ax,cmap);


axis(ax,'equal');
xlim(ax,xlimMap); ylim(ax,ylimMap);

set(ax, 'FontSize',axisTextSize, 'XColor','k', 'YColor','k', ...
    'LineWidth',0.9, 'Layer','top', 'Box','off', 'TickDir','out');

xlabel(ax, 'Longitude', 'FontSize',axisTitleSize, 'FontWeight','bold');
ylabel(ax, 'Latitude', 'FontSize',axisTitleSize, 'FontWeight','bold');

xTicksMap = ceil(xlimMap(1)):2:floor(xlimMap(2));
yTicksMap = ceil(ylimMap(1)):1:floor(ylimMap(2));

xticks(ax,xTicksMap); xticklabels(ax, compose('%d°E',xTicksMap));
yticks(ax,yTicksMap); yticklabels(ax, compose('%d°N',yTicksMap));

text(ax, 0.01, 1.04, '(a)', 'Units','normalized', 'FontSize',26, 'FontWeight','bold');


hLowSample = scatter(ax, NaN, NaN, markerSize, lowSampleColor, 'filled', ...
    'MarkerEdgeColor','k', 'LineWidth',1.0);

legend(ax, hLowSample, ...
    sprintf('n < %d matched events (not classified)',MIN_EVENTS_FOR_CLASSIFICATION), ...
    'Location','northwest', 'Box','off', 'FontSize',12);


cb = colorbar(ax,'southoutside');
cb.Position = [0.16 0.10 0.68 0.030];
cb.FontSize = cbarTextSize;
cb.LineWidth = 0.8;
cb.Color = 'k';
cb.Label.String = sprintf('Rainfall threshold (mm) at \\tau = %.2f', TAU_LEVEL);
cb.Label.FontSize = cbarTitleSize;
cb.Label.FontWeight = 'bold';
cb.Label.Interpreter = 'tex';


%% ========================================================================
% 11. INSET DENSITY (classified stations only), placed in an empty
%     corner of the map (top-right; adjust bounds below if your station
%     layout differs)
%% ========================================================================

axins = axes('Parent',fig, 'Position',[0.60 0.68 0.30 0.16]);

vals = Spatial.E3_P20(~isLow);

xq = linspace(min(vals)*0.8, max(vals)*1.1, 300)';

dens = localKDE(vals, xq);

plot(axins, xq, dens, 'Color',[0.85 0.15 0.15], 'LineWidth',1.4);

hold(axins,'on');

xline(axins, median(vals), '--', 'Color',[0.85 0.15 0.15], 'LineWidth',1.0);

xlabel(axins, 'Rainfall threshold', 'FontSize',9);
ylabel(axins, 'Density', 'FontSize',9);
set(axins, 'FontSize',8, 'Box','on');


%% ========================================================================
% 12. SAVE (300 dpi JPEG)
%% ========================================================================

exportgraphics(fig, OUT_JPG, 'Resolution',300);

fprintf('\nWritten: %s\n', OUT_JPG);


%% ========================================================================
% LOCAL FUNCTIONS
%% ========================================================================

function out = normalizeID(x)

    if isnumeric(x)
        out = string(compose('%.0f',x));
    else
        out = strip(string(x));
        out = regexprep(out, '\.0$', '');
    end

end


function dens = localKDE(vals, xq)
% Gaussian kernel density estimate with Silverman's rule-of-thumb
% bandwidth. Implemented locally so this script has no dependency on the
% Statistics and Machine Learning Toolbox (ksdensity).

    vals = vals(:);
    n = numel(vals);
    sigma = std(vals);

    if sigma <= 0 || n < 2
        bw = 1;
    else
        bw = 1.06 * sigma * n^(-1/5);
    end

    dens = zeros(size(xq));

    for k = 1:n
        dens = dens + normpdfLocal((xq - vals(k))/bw)/bw;
    end

    dens = dens / n;

end


function y = normpdfLocal(z)
    y = exp(-0.5*z.^2) / sqrt(2*pi);
end
