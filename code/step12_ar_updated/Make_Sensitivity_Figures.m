%% Make_Sensitivity_Figures.m
% Produces 4 publication-ready figures from Sensitivity_10_20_30km_and_NearDuplicate_Audit.xlsx:
%
%   Fig_Sensitivity_PooledCounts_by_Radius.tif   - grouped bar: Unique / Shared / Total
%                                                   station-event assignments vs buffer radius
%   Fig_Sensitivity_PerStation_Heatmap.tif       - station x radius heatmap of event counts
%   Fig_Sensitivity_OverlapPercent_by_Radius.tif - line plot: % of events shared between
%                                                   stations vs buffer radius
%   Fig_NearDuplicate_Distance_vs_Days.tif       - scatter: candidate near-duplicate pairs,
%                                                   distance (km) vs days apart
%
% All read from the workbook you already have; no recomputation from the master CSV.

clear; clc; close all;

%% ===================== CONFIG =====================
IN_DIR  = fullfile(neh_root(),'step_0_landslide_filtering','sensitivity_analysis_10_20_30');
IN_XLSX = fullfile(IN_DIR, 'Sensitivity_10_20_30km_and_NearDuplicate_Audit.xlsx');
OUT_DIR = IN_DIR;
CURRENT_RADIUS_KM = 20;

if ~exist(OUT_DIR,'dir'), mkdir(OUT_DIR); end

sheetNames = sheetnames(IN_XLSX);
pooledSheet   = sheetNames(contains(sheetNames,'Pooled','IgnoreCase',true));
perStnSheet   = sheetNames(contains(sheetNames,'PerStation','IgnoreCase',true));
dupSheet      = sheetNames(contains(sheetNames,'NearDup','IgnoreCase',true));

Pooled = readtable(IN_XLSX, 'Sheet', pooledSheet{1}, 'VariableNamingRule','preserve');
PerStn = readtable(IN_XLSX, 'Sheet', perStnSheet{1}, 'VariableNamingRule','preserve');
Dup    = readtable(IN_XLSX, 'Sheet', dupSheet{1},    'VariableNamingRule','preserve');

%% ===================== COLORS (Okabe-Ito colorblind-safe) =====================
col_blue   = [0.0000 0.4471 0.6980];   % Unique
col_orange = [0.9020 0.6235 0.0000];   % Shared
col_gray   = [0.6000 0.6000 0.6000];   % Total assignments
col_line   = [0.0000 0.2000 0.4000];

FONT = 'Arial';

%% ===================== FIGURE 1: Pooled counts vs radius (grouped bar) =====================
radiusLabels = compose('%g', Pooled.Radius_km);
isCurrent = Pooled.Radius_km == CURRENT_RADIUS_KM;
radiusLabels(isCurrent) = strcat(radiusLabels(isCurrent), " (current)");

Y = [Pooled.Unique_physical_landslides, Pooled.Shared_between_stations, Pooled.Total_station_event_assignments];

fig1 = figure('Units','inches','Position',[1 1 8 6],'Color','w');
ax1 = axes(fig1);
b = bar(ax1, categorical(radiusLabels, radiusLabels), Y, 'EdgeColor','k', 'LineWidth',0.75);
b(1).FaceColor = col_blue;
b(2).FaceColor = col_orange;
b(3).FaceColor = col_gray;

% direct value labels on top of bars
for k = 1:numel(b)
    xtips = b(k).XEndPoints;
    ytips = b(k).YEndPoints;
    text(ax1, xtips, ytips, string(Y(:,k)), 'HorizontalAlignment','center', ...
        'VerticalAlignment','bottom', 'FontSize',10, 'FontName',FONT);
end

ylabel(ax1, 'Number of landslide events', 'FontSize',16, 'FontWeight','bold', 'FontName',FONT);
xlabel(ax1, 'Station buffer radius (km)', 'FontSize',16, 'FontWeight','bold', 'FontName',FONT);
ax1.FontSize = 13; ax1.FontName = FONT;
ax1.Box = 'on';
ax1.YGrid = 'on'; ax1.GridColor = [0.85 0.85 0.85]; ax1.GridLineStyle = '--';
legend(ax1, {'Unique landslides','Shared between stations','Total station-event assignments'}, ...
    'Location','northwest', 'FontSize',11, 'Box','off');
title(ax1, 'Sensitivity of landslide counts to buffer radius', 'FontSize',15, 'FontName',FONT);

exportgraphics(fig1, fullfile(OUT_DIR,'Fig_Sensitivity_PooledCounts_by_Radius.tif'), 'Resolution',300);

%% ===================== FIGURE 2: Per-station heatmap =====================
radiusCols = PerStn.Properties.VariableNames(startsWith(PerStn.Properties.VariableNames,'Events_within_'));
radiusVals = erase(radiusCols, {'Events_within_','km'});
M = PerStn{:, radiusCols};

% sort stations by their 20km count (descending) for readability
col20idx = find(contains(radiusCols,'_20km') & ~contains(radiusCols,'22'));
[~, sortIdx] = sort(M(:,col20idx), 'descend');
M = M(sortIdx,:);
stationLabels = PerStn.Station(sortIdx);

cmap_viridis = local_viridis(256);

fig2 = figure('Units','inches','Position',[1 1 8 10],'Color','w');
h = heatmap(fig2, radiusVals, stationLabels, M, ...
    'Colormap', cmap_viridis, ...
    'ColorbarVisible','on', ...
    'CellLabelColor','auto', ...
    'FontName', FONT, ...
    'FontSize', 11);
h.Title = 'Landslide events within buffer, by station and radius';
h.XLabel = 'Buffer radius (km)';
h.YLabel = 'Station';

exportgraphics(fig2, fullfile(OUT_DIR,'Fig_Sensitivity_PerStation_Heatmap.tif'), 'Resolution',300);

%% ===================== FIGURE 3: Overlap % vs radius (single-axis line) =====================
overlapPct = 100 .* Pooled.Shared_between_stations ./ Pooled.Unique_physical_landslides;

fig3 = figure('Units','inches','Position',[1 1 7 5.5],'Color','w');
ax3 = axes(fig3); hold(ax3,'on');
plot(ax3, Pooled.Radius_km, overlapPct, '-o', 'Color', col_line, 'LineWidth',2, ...
    'MarkerFaceColor', col_line, 'MarkerSize',8);

for i = 1:height(Pooled)
    text(ax3, Pooled.Radius_km(i), overlapPct(i)+1.5, sprintf('%.0f%%',overlapPct(i)), ...
        'HorizontalAlignment','center', 'FontSize',11, 'FontName',FONT);
end

xline(ax3, CURRENT_RADIUS_KM, '--', ...
    sprintf('Current pipeline (%g km)', CURRENT_RADIUS_KM), 'Color',[0.5 0.5 0.5], ...
    'LabelVerticalAlignment','bottom', 'FontSize',10, 'FontName',FONT);

xlabel(ax3, 'Station buffer radius (km)', 'FontSize',16, 'FontWeight','bold', 'FontName',FONT);
ylabel(ax3, 'Events shared between \geq 2 station buffers (%)', 'FontSize',14, 'FontWeight','bold', 'FontName',FONT);
ax3.FontSize = 13; ax3.FontName = FONT;
ax3.Box = 'on';
ax3.XGrid = 'on'; ax3.YGrid = 'on';
ax3.GridColor = [0.85 0.85 0.85]; ax3.GridLineStyle = '--';
xlim(ax3, [5 35]);
ylim(ax3, [0 max(overlapPct)*1.25]);
title(ax3, 'Cross-station buffer overlap increases with radius', 'FontSize',15, 'FontName',FONT);

exportgraphics(fig3, fullfile(OUT_DIR,'Fig_Sensitivity_OverlapPercent_by_Radius.tif'), 'Resolution',300);

%% ===================== FIGURE 4: Near-duplicate audit scatter =====================
sameDay = Dup.Days_apart == 0;

fig4 = figure('Units','inches','Position',[1 1 7 6],'Color','w');
ax4 = axes(fig4); hold(ax4,'on');

rectangle(ax4, 'Position',[0 0 2 3], 'EdgeColor',[0.4 0.4 0.4], 'LineStyle','--', 'LineWidth',1.2);
text(ax4, 2.02, 3.05, 'audit criterion: \leq2 km, \leq3 days', 'FontSize',10, 'FontName',FONT, 'Color',[0.4 0.4 0.4]);

scatter(ax4, Dup.Distance_km(sameDay), Dup.Days_apart(sameDay), 55, col_blue, 'filled', ...
    'MarkerEdgeColor','k', 'LineWidth',0.5);
scatter(ax4, Dup.Distance_km(~sameDay), Dup.Days_apart(~sameDay), 55, col_orange, 'o', ...
    'LineWidth',1.5);

xlabel(ax4, 'Great-circle distance between records (km)', 'FontSize',15, 'FontWeight','bold', 'FontName',FONT);
ylabel(ax4, 'Days between reported dates', 'FontSize',15, 'FontWeight','bold', 'FontName',FONT);
ax4.FontSize = 13; ax4.FontName = FONT;
ax4.Box = 'on';
ax4.XGrid = 'on'; ax4.YGrid = 'on';
ax4.GridColor = [0.9 0.9 0.9]; ax4.GridLineStyle = '--';
xlim(ax4, [0 2.3]); ylim(ax4, [-0.3 3.3]);
legend(ax4, {'audit threshold','same-day pair','different-day pair'}, ...
    'Location','southoutside', 'Orientation','horizontal', 'FontSize',11, 'Box','off');
title(ax4, sprintf('Candidate near-duplicate pairs (n = %d)', height(Dup)), 'FontSize',15, 'FontName',FONT);

exportgraphics(fig4, fullfile(OUT_DIR,'Fig_NearDuplicate_Distance_vs_Days.tif'), 'Resolution',300);

fprintf('Saved 4 figures to: %s\n', OUT_DIR);
