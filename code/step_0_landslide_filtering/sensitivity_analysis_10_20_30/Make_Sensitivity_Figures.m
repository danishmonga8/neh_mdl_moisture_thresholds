%% Make_Sensitivity_Figures.m
% Produces 4 publication-ready figures from Sensitivity_10_20_30km_and_NearDuplicate_Audit.xlsx

clear; clc; close all;

%% ===================== CONFIG =====================
IN_DIR  = fullfile(neh_root(),'step_0_landslide_filtering','sensitivity_analysis_10_20_30');
IN_XLSX = fullfile(IN_DIR, 'Sensitivity_10_20_30km_and_NearDuplicate_Audit.xlsx');
OUT_DIR = IN_DIR;

if ~exist(OUT_DIR,'dir'), mkdir(OUT_DIR); end

sheetNames = cellstr(sheetnames(IN_XLSX));   % force cellstr up front -- avoids string/cell ambiguity everywhere downstream
pooledSheet = sheetNames{find(contains(sheetNames,'Pooled','IgnoreCase',true),1)};
perStnSheet = sheetNames{find(contains(sheetNames,'PerStation','IgnoreCase',true),1)};
dupSheet    = sheetNames{find(contains(sheetNames,'NearDup','IgnoreCase',true),1)};

Pooled = readtable(IN_XLSX, 'Sheet', pooledSheet, 'VariableNamingRule','preserve', 'TextType','string');
PerStn = readtable(IN_XLSX, 'Sheet', perStnSheet, 'VariableNamingRule','preserve', 'TextType','string');
Dup    = readtable(IN_XLSX, 'Sheet', dupSheet,    'VariableNamingRule','preserve', 'TextType','string');

%% ===================== COLORS (Okabe-Ito colorblind-safe) =====================
col_blue   = [0.0000 0.4471 0.6980];
col_orange = [0.9020 0.6235 0.0000];
col_gray   = [0.6000 0.6000 0.6000];
col_line   = [0.0000 0.2000 0.4000];

FONT = 'Arial';

%% ===================== FIGURE 1: Pooled counts vs radius (grouped bar) =====================
radiusNum = double(Pooled.Radius_km);                       % force numeric explicitly
radiusLabels = strings(numel(radiusNum),1);                 % pre-allocate as string array
for i = 1:numel(radiusNum)
    if radiusNum(i) == 22.5
        radiusLabels(i) = sprintf('%g (current)', radiusNum(i));
    else
        radiusLabels(i) = sprintf('%g', radiusNum(i));
    end
end
radiusLabels = cellstr(radiusLabels);   % categorical() below wants cellstr/string consistently -- cellstr is the safest common denominator

Y = [double(Pooled.Unique_physical_landslides), double(Pooled.Shared_between_stations), double(Pooled.Total_station_event_assignments)];

fig1 = figure('Units','inches','Position',[1 1 8 6],'Color','w');
ax1 = axes(fig1);
b = bar(ax1, categorical(radiusLabels, radiusLabels), Y, 'EdgeColor','k', 'LineWidth',0.75);
b(1).FaceColor = col_blue;
b(2).FaceColor = col_orange;
b(3).FaceColor = col_gray;

for k = 1:numel(b)
    xtips = b(k).XEndPoints;
    ytips = b(k).YEndPoints;
    labelStrs = cellstr(num2str(Y(:,k)));
    text(ax1, xtips, ytips, labelStrs, 'HorizontalAlignment','center', ...
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
allVarNames = PerStn.Properties.VariableNames;               % guaranteed cellstr by MATLAB
radiusCols = allVarNames(startsWith(allVarNames,'Events_within_'));
radiusVals = cellstr(erase(string(radiusCols),{'Events_within_','km'}));
M = PerStn{:, radiusCols};

col20idx = find(contains(radiusCols,'_20km') & ~contains(radiusCols,'22'));
[~, sortIdx] = sort(M(:,col20idx), 'descend');
M = M(sortIdx,:);
stationLabels = cellstr(string(PerStn.Station(sortIdx)));    % force cellstr regardless of how readtable imported it

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
overlapPct = 100 .* double(Pooled.Shared_between_stations) ./ double(Pooled.Unique_physical_landslides);

fig3 = figure('Units','inches','Position',[1 1 7 5.5],'Color','w');
ax3 = axes(fig3); hold(ax3,'on');
plot(ax3, radiusNum, overlapPct, '-o', 'Color', col_line, 'LineWidth',2, ...
    'MarkerFaceColor', col_line, 'MarkerSize',8);

for i = 1:numel(radiusNum)
    text(ax3, radiusNum(i), overlapPct(i)+1.5, sprintf('%.0f%%',overlapPct(i)), ...
        'HorizontalAlignment','center', 'FontSize',11, 'FontName',FONT);
end

xline(ax3, 22.5, '--', 'Current pipeline (22.5 km)', 'Color',[0.5 0.5 0.5], ...
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
daysApart = double(Dup.Days_apart);
distKm    = double(Dup.Distance_km);
sameDay = daysApart == 0;

fig4 = figure('Units','inches','Position',[1 1 7 6],'Color','w');
ax4 = axes(fig4); hold(ax4,'on');

rectangle(ax4, 'Position',[0 0 2 3], 'EdgeColor',[0.4 0.4 0.4], 'LineStyle','--', 'LineWidth',1.2);
text(ax4, 2.02, 3.05, 'audit criterion: \leq2 km, \leq3 days', 'FontSize',10, 'FontName',FONT, 'Color',[0.4 0.4 0.4]);

scatter(ax4, distKm(sameDay), daysApart(sameDay), 55, col_blue, 'filled', ...
    'MarkerEdgeColor','k', 'LineWidth',0.5);
scatter(ax4, distKm(~sameDay), daysApart(~sameDay), 55, col_orange, 'o', ...
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

%% ===================================================================
function cmap = local_viridis(n)
    stops = [ ...
        0.2667 0.0039 0.3294;
        0.2824 0.1569 0.4706;
        0.2431 0.2863 0.5373;
        0.1922 0.4078 0.5569;
        0.1490 0.5098 0.5569;
        0.1216 0.6196 0.5373;
        0.2078 0.7176 0.4745;
        0.4314 0.8078 0.3451;
        0.7098 0.8706 0.1686;
        0.9922 0.9059 0.1451];
    x  = linspace(0,1,size(stops,1));
    xi = linspace(0,1,n);
    cmap = interp1(x, stops, xi, 'pchip');
end