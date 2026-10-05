%% ========================================================================
% FIGURE -- ED-THRESHOLD SPATIAL MAP (a) + ADF-vs-THRESHOLD SCATTER (b)
%           COMBINED INTO ONE IMAGE
%
% Same data/logic as the two individual scripts
% (Fig8_ED_Threshold_Spatial_Map.m, Fig8_ADF_vs_ED_Threshold_Scatter.m),
% laid out side by side in a single figure/file instead of two separate
% exports, matching the two-panel reference figure layout.
%
% (a) Rainfall threshold (mm), 3-day duration, linear quantile regression
%     at tau = 0.20 (E3_P20, read from ED_Linear_vs_PowerLaw_AllStations.xlsx
%     -- not re-fit here), with an inset density curve of the classified
%     stations' threshold values. Stations with <= MIN_EVENTS
%     matched landslide events are grey and excluded from the inset
%     density curve and station-level comparison.
% (b) Updated (independently-selected-N*) ADF vs. the same E3_P20 value,
%     with a linear fit and Kendall's tau annotated. Only the same eligible
%     stations used for the colored map markers are included.
%
% OUTPUT:
%   Fig6_ED_Threshold_Combined_GT15.jpg  (300 dpi)
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

OUT_JPG = fullfile(OUT_DIR, 'Fig6_ED_Threshold_Combined_GT15.jpg');


%% ========================================================================
% 3. READ + JOIN DATA (station metadata, ED threshold, updated ADF)
%% ========================================================================

optsMeta = detectImportOptions(station_excel, 'Sheet','Sheet1', ...
    'VariableNamingRule','preserve', 'TextType','string');

TM = readtable(station_excel, optsMeta);

metaVarsKey = lower(strtrim(string(TM.Properties.VariableNames)));

latCol = find(contains(metaVarsKey,"lat"), 1,'first');
lonCol = find(metaVarsKey == "long" | contains(metaVarsKey,"lon"), 1,'first');

TMeta = table( ...
    strip(string(TM{:,1})), ...
    normalizeID(TM{:,2}), ...
    double(TM{:,latCol}), ...
    double(TM{:,lonCol}), ...
    'VariableNames', {'Station','IMD_ID','Lat','Lon'});

[~,idxUnique] = unique(TMeta.IMD_ID,'stable');
TMeta = TMeta(idxUnique,:);


TED = readtable(ED_FILE, 'Sheet','Linear_quantile', ...
    'VariableNamingRule','preserve', 'TextType','string');
TED.IMD_ID = normalizeID(TED.IMD_ID);
TED = TED(string(TED.Status) == "OK", {'IMD_ID','E3_P20'});


TADF = readtable(ADF_FILE, 'Sheet','ADF_summary', ...
    'VariableNamingRule','preserve', 'TextType','string');
TADF.IMD_ID = normalizeID(TADF.IMD_ID);
TADF = TADF(string(TADF.Status) == "OK", {'IMD_ID','ADF','Matched_events'});


Spatial = innerjoin(TMeta, TED, 'Keys','IMD_ID');
Spatial = innerjoin(Spatial, TADF, 'Keys','IMD_ID');

Spatial = Spatial( ...
    isfinite(Spatial.Lat) & isfinite(Spatial.Lon) & ...
    isfinite(Spatial.E3_P20) & isfinite(Spatial.ADF), :);

Spatial.Low_sample = Spatial.Matched_events <= MIN_EVENTS_FOR_CLASSIFICATION;

fprintf('Stations: %d total | %d low-sample (<=%d matched events, excluded from analysis)\n', ...
    height(Spatial), sum(Spatial.Low_sample), MIN_EVENTS_FOR_CLASSIFICATION);


%% ========================================================================
% 4. COLORMAP
%% ========================================================================

anchor = [252 253 191; 251 191 115; 239 104 102; 175 54 160; 66 15 112; 0 0 4]/255;
cmap = interp1(linspace(0,1,size(anchor,1)), anchor, linspace(0,1,256), 'pchip');


%% ========================================================================
% 5. SHAPEFILE (NEH-intersecting polygons only)
%% ========================================================================

Sall = shaperead(shapefile_path, 'UseGeoCoords',true);

nehStationMask = isfinite(TMeta.Lat) & isfinite(TMeta.Lon) & ...
    TMeta.Lat >= 21.5 & TMeta.Lat <= 30.0 & TMeta.Lon >= 87.0 & TMeta.Lon <= 98.0;

allMetaLat = TMeta.Lat(nehStationMask);
allMetaLon = TMeta.Lon(nehStationMask);

keepShape = false(numel(Sall),1);

for i = 1:numel(Sall)
    Xall = Sall(i).Lon(:); Yall = Sall(i).Lat(:);
    if isempty(Xall) || isempty(Yall), continue, end

    nanBreaks = find(isnan(Xall) | isnan(Yall));
    segStart = [1; nanBreaks+1];
    segEnd = [nanBreaks-1; numel(Xall)];
    insideThisShape = false;

    for s = 1:numel(segStart)
        i1 = segStart(s); i2 = segEnd(s);
        if i2 <= i1, continue, end
        xs = Xall(i1:i2); ys = Yall(i1:i2);
        good = isfinite(xs) & isfinite(ys);
        xs = xs(good); ys = ys(good);
        if numel(xs) < 3, continue, end
        if any(inpolygon(allMetaLon, allMetaLat, xs, ys))
            insideThisShape = true; break
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
padX = 0.03*(bbXmax-bbXmin); padY = 0.03*(bbYmax-bbYmin);
xlimMap = [bbXmin-padX, bbXmax+padX];
ylimMap = [bbYmin-padY, bbYmax+padY];
lonMajor = floor(xlimMap(1)):1:ceil(xlimMap(2));
latMajor = floor(ylimMap(1)):1:ceil(ylimMap(2));


%% ========================================================================
% 6. FIGURE -- TWO PANELS SIDE BY SIDE
%% ========================================================================

fig = figure('Color','w', 'Units','inches', 'Position',[1 1 16 7.4]);

markerSize = 170; markerAlpha = 0.85;
lowSampleColor = [0.65 0.65 0.65];


%% ---- Panel (a): map -----------------------------------------------------

axPos = [0.045 0.22 0.42 0.66];

ax = axes('Parent',fig, 'Position',axPos);
hold(ax,'on');

for i = 1:numel(S)
    patch(ax, S(i).Lon, S(i).Lat, [0.96 0.96 0.96], ...
        'EdgeColor',[0.25 0.25 0.25], 'LineWidth',0.9);
end

for xg = lonMajor
    plot(ax, [xg xg], ylimMap, '--', 'Color',[0.82 0.82 0.82], 'LineWidth',0.4);
end
for yg = latMajor
    plot(ax, xlimMap, [yg yg], '--', 'Color',[0.82 0.82 0.82], 'LineWidth',0.4);
end

isLow = Spatial.Low_sample;

scatter(ax, Spatial.Lon(isLow), Spatial.Lat(isLow), markerSize, lowSampleColor, ...
    'filled', 'MarkerFaceAlpha',markerAlpha, 'MarkerEdgeColor','k', 'LineWidth',0.9);

sc = scatter(ax, Spatial.Lon(~isLow), Spatial.Lat(~isLow), markerSize, Spatial.E3_P20(~isLow), ...
    'filled', 'MarkerFaceAlpha',markerAlpha, 'MarkerEdgeColor','k', 'LineWidth',0.9);

colormap(ax,cmap);
axis(ax,'equal');
xlim(ax,xlimMap); ylim(ax,ylimMap);

set(ax, 'FontSize',13, 'XColor','k', 'YColor','k', 'LineWidth',0.9, ...
    'Layer','top', 'Box','off', 'TickDir','out');

xlabel(ax, 'Longitude', 'FontSize',15, 'FontWeight','bold');
ylabel(ax, 'Latitude', 'FontSize',15, 'FontWeight','bold');

xTicksMap = ceil(xlimMap(1)):2:floor(xlimMap(2));
yTicksMap = ceil(ylimMap(1)):1:floor(ylimMap(2));
xticks(ax,xTicksMap); xticklabels(ax, compose('%d°E',xTicksMap));
yticks(ax,yTicksMap); yticklabels(ax, compose('%d°N',yTicksMap));

annotation(fig, 'textbox', [axPos(1)-0.025, axPos(2)+axPos(4)+0.05, 0.05, 0.05], ...
    'String','(a)', 'EdgeColor','none', 'FontSize',22, 'FontWeight','bold');

hLowSample = scatter(ax, NaN, NaN, markerSize, lowSampleColor, 'filled', ...
    'MarkerEdgeColor','k', 'LineWidth',0.9);
legend(ax, hLowSample, ...
    sprintf('n <= %d matched events (not classified)',MIN_EVENTS_FOR_CLASSIFICATION), ...
    'Location','northwest', 'Box','off', 'FontSize',10);

cb = colorbar(ax,'southoutside');
cb.Position = [axPos(1)+0.03 0.09 axPos(3)-0.06 0.028];
cb.FontSize = 11;
cb.Label.String = sprintf('Rainfall threshold (mm) at \\tau = %.2f', TAU_LEVEL);
cb.Label.FontSize = 14;
cb.Label.FontWeight = 'bold';
cb.Label.Interpreter = 'tex';


%% ---- Inset density curve in the empty southeast part of the map -------

insetPos = [0.345, 0.285, 0.115, 0.135];

axins = axes('Parent',fig, 'Position',insetPos);

vals = Spatial.E3_P20(~isLow);
xq = linspace(min(vals)*0.8, max(vals)*1.1, 300)';
dens = localKDE(vals, xq);

plot(axins, xq, dens, 'Color',[0.85 0.15 0.15], 'LineWidth',1.3);
hold(axins,'on');
xline(axins, median(vals), '--', 'Color',[0.85 0.15 0.15], 'LineWidth',0.9);

xlabel(axins, 'Rainfall threshold', 'FontSize',8);
ylabel(axins, 'Density', 'FontSize',8);
set(axins, 'FontSize',7, 'Box','on');


%% ---- Panel (b): scatter --------------------------------------------------

axb = axes('Parent',fig, 'Position',[0.58 0.14 0.39 0.78]);
hold(axb,'on');
grid(axb,'on');
set(axb, 'GridLineStyle','--', 'GridColor',[0.85 0.85 0.85], 'GridAlpha',1, 'Layer','bottom');

x = Spatial.ADF(~isLow);
y = Spatial.E3_P20(~isLow);

p = polyfit(x, y, 1);
slope = p(1); intercept = p(2);
[tau, pval] = kendallTauLocal(x, y);

scatter(axb, x, y, 100, [0.85 0.65 0.80], 'filled', ...
    'MarkerEdgeColor','k', 'LineWidth',0.9, 'MarkerFaceAlpha',0.85);

xFit = linspace(min(x), max(x), 100);
plot(axb, xFit, intercept + slope*xFit, 'Color',[0.85 0.15 0.15], 'LineWidth',1.7);

set(axb, 'FontSize',14, 'Box','on', 'LineWidth',0.9, 'TickDir','out');
xlabel(axb, 'ADF', 'FontSize',16, 'FontWeight','bold');
ylabel(axb, sprintf('%d-day rainfall threshold (mm)\nat \\tau = %.2f', DUR_DAYS, TAU_LEVEL), ...
    'FontSize',14, 'FontWeight','bold', 'Interpreter','tex');

annotation(fig, 'textbox', [0.555, 0.95, 0.05, 0.05], ...
    'String','(b)', 'EdgeColor','none', 'FontSize',22, 'FontWeight','bold');

text(axb, 0.97, 0.97, sprintf('Kendall''s \\tau = %.2f\np = %.3f', tau, pval), ...
    'Units','normalized', 'HorizontalAlignment','right', 'VerticalAlignment','top', ...
    'FontSize',12, 'Interpreter','tex');


%% ========================================================================
% 7. SAVE (300 dpi JPEG, single combined image)
%% ========================================================================

exportgraphics(fig, OUT_JPG, 'Resolution',300);

fprintf('\nWritten: %s\n', OUT_JPG);
fprintf('Linear fit: E3_P20 = %.3f + %.3f * ADF\n', intercept, slope);
fprintf('Kendall''s tau = %.3f   p = %.3f\n', tau, pval);


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
% Gaussian KDE, Silverman bandwidth -- no Statistics Toolbox dependency.
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
        dens = dens + exp(-0.5*((xq - vals(k))/bw).^2)/(bw*sqrt(2*pi));
    end
    dens = dens / n;
end


function [tau_b, pval] = kendallTauLocal(x, y)
% Kendall's tau-b with a normal-approximation two-sided p-value
% (no-tie asymptotic variance). No Statistics Toolbox dependency.
    x = x(:); y = y(:);
    n = numel(x);
    P = 0; Q = 0;
    for i = 1:n-1
        dx = x(i+1:end) - x(i);
        dy = y(i+1:end) - y(i);
        sgn = sign(dx) .* sign(dy);
        P = P + sum(sgn > 0);
        Q = Q + sum(sgn < 0);
    end
    n0 = n*(n-1)/2;
    n1 = tieTerm(x);
    n2 = tieTerm(y);
    denom = sqrt((n0-n1)*(n0-n2));
    if denom > 0
        tau_b = (P-Q)/denom;
    else
        tau_b = NaN;
    end
    S = P - Q;
    varS = n*(n-1)*(2*n+5)/18;
    if varS > 0
        z = S/sqrt(varS);
    else
        z = 0;
    end
    pval = 2*(1 - 0.5*(1+erf(abs(z)/sqrt(2))));
end


function t = tieTerm(v)
    u = unique(v);
    t = 0;
    for k = 1:numel(u)
        c = sum(v == u(k));
        t = t + c*(c-1)/2;
    end
end
