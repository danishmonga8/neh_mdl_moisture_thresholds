clear; clc; close all;

basePath = 'C:\lews_2022-2024\3_new_stations_neh_new\figures_neh_soil_moisture\empirical_probability';
inFile   = fullfile(basePath, 'EmpiricalProb_SelectedEvent_Stations_all_updated.xlsx');

Out = readtable(inFile, 'VariableNamingRule', 'preserve');

x      = Out.Slope_deg;
yr     = Out.Year_sel;
bua    = Out.BuiltArea_pct;
veg    = Out.Vegetation_Trees_pct;
stn    = string(Out.Station);

y_tri_prob = Out.JEP_formula;
y_tr_prob  = Out.TR_exceedance;

y_tri = y_tri_prob * 100;
y_tr  = y_tr_prob  * 100;

%% -------------------------------------------------
% 1) Built-up area classes
%% -------------------------------------------------
BuiltClass = strings(size(bua));
BuiltClass(bua >= 0  & bua <= 2) = "≤2%";
BuiltClass(bua > 2   & bua < 4)  = "2–4%";
BuiltClass(bua >= 4  & bua < 6)  = "4–6%";
BuiltClass(bua >= 6  & bua < 10) = "6–10%";
BuiltClass(bua >= 10 & bua < 15) = "10–15%";
BuiltClass(bua >= 15)            = ">15%";

bubbleArea = zeros(size(bua));
bubbleArea(BuiltClass=="≤2%")    = 90;
bubbleArea(BuiltClass=="2–4%")   = 150;
bubbleArea(BuiltClass=="4–6%")   = 230;
bubbleArea(BuiltClass=="6–10%")  = 340;
bubbleArea(BuiltClass=="10–15%") = 480;
bubbleArea(BuiltClass==">15%")   = 950;   % increased size for >15%
%% -------------------------------------------------
% 2) Vegetation classes
%% -------------------------------------------------
VegClass = strings(size(veg));
VegClass(veg < 50)              = "<50%";
VegClass(veg >= 50 & veg < 60)  = "50–60%";
VegClass(veg >= 60 & veg < 70)  = "60–70%";
VegClass(veg >= 70 & veg < 80)  = "70–80%";
VegClass(veg >= 80 & veg < 90)  = "80–90%";
VegClass(veg >= 90)             = "≥90%";

vegBoxArea = zeros(size(veg));
vegBoxArea(VegClass=="<50%")    = 90;
vegBoxArea(VegClass=="50–60%")  = 150;
vegBoxArea(VegClass=="60–70%")  = 230;
vegBoxArea(VegClass=="70–80%")  = 380;
vegBoxArea(VegClass=="80–90%")  = 580;
vegBoxArea(VegClass=="≥90%")    = 950;

vegLab1 = '<50%';
vegLab2 = '50–60%';
vegLab3 = '60–70%';
vegLab4 = '70–80%';
vegLab5 = '80–90%';
vegLab6 = '≥90%';

%% -------------------------------------------------
% 3) Reversed HOT colormap
%% -------------------------------------------------
yearsFull = (min(yr):max(yr))';
nY = numel(yearsFull);
yearMap = flipud(hot(nY));
[~, yearIdx] = ismember(yr, yearsFull);

%% -------------------------------------------------
% 4) Bootstrap regression: Joint exceedance probability
%% -------------------------------------------------
rng(123,'twister');
Nboot = 5000;
n = numel(x);

bootCoef_tri = zeros(Nboot,2);
for b = 1:Nboot
    idx = randsample(n, n, true);
    p = polyfit(x(idx), y_tri_prob(idx), 1);
    bootCoef_tri(b,:) = [p(2), p(1)];
end

coeff_tri = polyfit(x, y_tri_prob, 1);

boot_intercept_tri = median(bootCoef_tri(:,1));
boot_slope_tri     = median(bootCoef_tri(:,2));
Slope_boot_tri     = bootCoef_tri(:,2);

boot_slope_tri_10 = boot_slope_tri * 10;
p_boot_tri = sum(Slope_boot_tri < coeff_tri(1)) / size(Slope_boot_tri,1);

%% -------------------------------------------------
% 5) Bootstrap regression: TR exceedance probability
%% -------------------------------------------------
bootCoef_tr = zeros(Nboot,2);
for b = 1:Nboot
    idx = randsample(n, n, true);
    p = polyfit(x(idx), y_tr_prob(idx), 1);
    bootCoef_tr(b,:) = [p(2), p(1)];
end

coeff_tr = polyfit(x, y_tr_prob, 1);

boot_intercept_tr = median(bootCoef_tr(:,1));
boot_slope_tr     = median(bootCoef_tr(:,2));
Slope_boot_tr     = bootCoef_tr(:,2);

boot_slope_tr_10 = boot_slope_tr * 10;
p_boot_tr = sum(Slope_boot_tr < coeff_tr(1)) / size(Slope_boot_tr,1);

%% -------------------------------------------------
% 5A) 95% bootstrap confidence intervals for fitted slopes
%% -------------------------------------------------

% Convert slopes to change in probability per 10 degrees
% If you want values in probability units, use: slope * 10
% If you want values in percentage points, use: slope * 10 * 100

Slope_boot_tri_10_pct = Slope_boot_tri * 10 * 100;
Slope_boot_tr_10_pct  = Slope_boot_tr  * 10 * 100;

CI_tri_95 = prctile(Slope_boot_tri_10_pct, [2.5 97.5]);
CI_tr_95  = prctile(Slope_boot_tr_10_pct,  [2.5 97.5]);

boot_slope_tri_10_pct = boot_slope_tri * 10 * 100;
boot_slope_tr_10_pct  = boot_slope_tr  * 10 * 100;

fprintf('\n95%% Bootstrap Confidence Interval for fitted slopes:\n');
fprintf('Trivariate probability slope = %.2f percentage points per 10° [95%% CI: %.2f, %.2f]\n', ...
    boot_slope_tri_10_pct, CI_tri_95(1), CI_tri_95(2));

fprintf('TR-only probability slope     = %.2f percentage points per 10° [95%% CI: %.2f, %.2f]\n\n', ...
    boot_slope_tr_10_pct, CI_tr_95(1), CI_tr_95(2));

%% -------------------------------------------------
% 6) Fitted lines
%% -------------------------------------------------
xx = linspace(min(x), max(x), 300);

yy_tri = (boot_intercept_tri + boot_slope_tri * xx) * 100;
yy_tr  = (boot_intercept_tr  + boot_slope_tr  * xx) * 100;

%% -------------------------------------------------
% 7) Figure and main axis
%% -------------------------------------------------
fig = figure('Color','w','Position',[60 40 1720 950]);

ax1 = axes(fig);
hold(ax1,'on');

ax1.Position      = [0.16 0.20 0.60 0.70];   % changed only for outside legends
ax1.Box           = 'off';
ax1.LineWidth     = 1.2;
ax1.FontSize      = 18;
ax1.TickDir       = 'out';
ax1.Layer         = 'top';
ax1.GridLineStyle = ':';
ax1.GridAlpha     = 0.28;
grid(ax1,'on');


%% -------------------------------------------------
% 9) Joint exceedance probability: filled circles
%% -------------------------------------------------
for i = 1:nY
    id = (yearIdx == i);

    id_lowBuilt  = id & BuiltClass ~= ">15%" & bubbleArea > 0;
    id_highBuilt = id & BuiltClass == ">15%" & bubbleArea > 0;

    if any(id_lowBuilt)
        scatter(ax1, x(id_lowBuilt), y_tri(id_lowBuilt), bubbleArea(id_lowBuilt), ...
            'o', ...
            'filled', ...
            'MarkerFaceColor', yearMap(i,:), ...
            'MarkerEdgeColor', 'k', ...
            'LineWidth', 1.25, ...
            'MarkerFaceAlpha', 0.45, ...
            'MarkerEdgeAlpha', 0.85);
    end

    if any(id_highBuilt)
        scatter(ax1, x(id_highBuilt), y_tri(id_highBuilt), bubbleArea(id_highBuilt), ...
            'o', ...
            'filled', ...
            'MarkerFaceColor', yearMap(i,:), ...
            'MarkerEdgeColor', [0.85 0.00 0.00], ...
            'LineWidth', 2.4, ...
            'MarkerFaceAlpha', 0.45, ...
            'MarkerEdgeAlpha', 0.95);
    end
end
%% -------------------------------------------------
% 10) Station labels next to bubbles
%% -------------------------------------------------
dx = 0.18;
dy = 0.60;

for j = 1:n
    text(ax1, x(j) + dx, y_tri(j) + dy, stn(j), ...
        'FontSize', 14, ...
        'Color', 'k', ...
        'FontWeight', 'normal', ...
        'HorizontalAlignment', 'left', ...
        'VerticalAlignment', 'middle');
end

%% -------------------------------------------------
% 11) Bootstrap fit lines
%% -------------------------------------------------
plot(ax1, xx, yy_tri, ':k', 'LineWidth', 1.8);
plot(ax1, xx, yy_tr, '--', 'Color', [0.40 0.40 0.40], 'LineWidth', 1.5);

%% -------------------------------------------------
% 12) Vertical dotted reference lines at 10° and 20°
%% -------------------------------------------------
xline(ax1, 10, '--', 'Color', 'k', 'LineWidth', 2);
xline(ax1, 20, '--', 'Color', 'k', 'LineWidth', 2);
yline(ax1, 10, '--', 'Color', [1 0 0], 'LineWidth', 2);

%% -------------------------------------------------
% 13) Axes formatting
%% -------------------------------------------------
xlim(ax1,[min(x)-0.8, max(x)+0.8]);
ylim(ax1,[0 100]);

xt = ceil(min(x)):2:floor(max(x));
xticks(ax1,xt);
xticklabels(ax1, arrayfun(@(v)sprintf('%d°',v), xt, 'UniformOutput', false));

yt = 0:10:100;
yticks(ax1,yt);
yticklabels(ax1, arrayfun(@(v)sprintf('%d%%',v), yt, 'UniformOutput', false));

xlabel(ax1,'Slope', ...
    'FontSize',20, ...
    'FontWeight','bold');

ylabel(ax1,'Joint exceedance probability', ...
    'FontSize',20, ...
    'FontWeight','bold');

%% -------------------------------------------------
% 14) Regression annotations
%% -------------------------------------------------

% Annotation for joint exceedance probability: TR, AMC, and S_eff
xAnn_tri = min(x) + 0.16*(max(x)-min(x));
yAnn_tri = (boot_intercept_tri + boot_slope_tri*xAnn_tri)*100 + 8;

txt_tri = sprintf('$\\beta_{(\\mathrm{TR},\\mathrm{AMC},S_{\\mathrm{eff}})} = %.2f\\ \\mathrm{per}\\ 10^{\\circ}\\ (p = %.3f)$', ...
    boot_slope_tri_10, p_boot_tri);

text(ax1, xAnn_tri, yAnn_tri, txt_tri, ...
    'Interpreter','latex', ...
    'FontSize',17, ...
    'HorizontalAlignment','left', ...
    'VerticalAlignment','bottom', ...
    'BackgroundColor','w', ...
    'Margin',3, ...
    'Rotation',8);

% Annotation for TR-only exceedance probability
xAnn_tr = min(x) + 0.16*(max(x)-min(x));
yAnn_tr = (boot_intercept_tr + boot_slope_tr*xAnn_tr)*100 + 1.5;

txt_tr = sprintf('$\\beta_{\\mathrm{TR}} = %.2f\\ \\mathrm{per}\\ 10^{\\circ}\\ (p = %.3f)$', ...
    boot_slope_tr_10, p_boot_tr);

text(ax1, xAnn_tr, yAnn_tr, txt_tr, ...
    'Interpreter','latex', ...
    'FontSize',17, ...
    'HorizontalAlignment','left', ...
    'VerticalAlignment','bottom', ...
    'BackgroundColor','w', ...
    'Margin',3, ...
    'Rotation',8);

%% -------------------------------------------------
% 15) Colorbar
%% -------------------------------------------------
colormap(ax1, yearMap);
caxis(ax1,[yearsFull(1)-0.5, yearsFull(end)+0.5]);

cb = colorbar(ax1,'eastoutside');
cb.Ticks = yearsFull;
cb.TickLabels = string(yearsFull);
cb.FontSize = 17;
cb.LineWidth = 0.9;
cb.Position = [0.84 0.20 0.017 0.70];
cb.Label.String = 'Landslide year';
cb.Label.FontSize = 22;
cb.Label.FontWeight = 'bold';

%% -------------------------------------------------
% 16) Vegetation and built-up legend outside plot
%     placed AFTER colorbar
% -------------------------------------------------
legAx1 = axes('Parent',fig, ...
    'Units','normalized', ...
    'Position',[0.90 0.34 0.09 0.43], ...
    'Visible','off');
hold(legAx1,'on');

text(legAx1,0.00,0.96,'Vegetation (%)', ...
    'FontSize',11, ...
    'FontWeight','bold');

text(legAx1,0.58,0.96,'Built-up (%)', ...
    'FontSize',11, ...
    'FontWeight','bold');

legendSizes_v = [55, 90, 130, 190, 280, 390];
legendSizes_b = [35, 70, 120, 190, 280, 520];

vegLabels   = {vegLab1, vegLab2, vegLab3, vegLab4, vegLab5, vegLab6};
builtLabels = {'0–2%', '2–4%', '4–6%', '6–10%', '10–15%', '>15%'};

for k = 1:6
    yy = 0.96 - k*0.13;

    % Vegetation legend color rule
    if k <= 3
        vegFaceCol = [0.72 0.72 0.72];      % grey for <50, 50–60, 60–70
        vegEdgeCol = 'k';
    else
        vegFaceCol = [0.72 0.90 0.72];      % light green for 70–80, 80–90, ≥90
        vegEdgeCol = [0.00 0.38 0.00];      % deep green boundary
    end

    scatter(legAx1,0.04,yy,legendSizes_v(k),'s', ...
        'MarkerFaceColor',vegFaceCol, ...
        'MarkerEdgeColor',vegEdgeCol, ...
        'MarkerFaceAlpha',0.45, ...
        'MarkerEdgeAlpha',0.95, ...
        'LineWidth',1.7);

    text(legAx1,0.15,yy,vegLabels{k}, ...
        'FontSize',10, ...
        'VerticalAlignment','middle');

    % Built-up legend color rule
    if k == 6
        builtEdgeCol = [0.85 0.00 0.00];    % red boundary for >15%
        builtLW = 2.2;
    else
        builtEdgeCol = 'k';
        builtLW = 1.25;
    end

    scatter(legAx1,0.62,yy,legendSizes_b(k),'o', ...
        'MarkerFaceColor','w', ...
        'MarkerEdgeColor',builtEdgeCol, ...
        'LineWidth',builtLW);

    text(legAx1,0.73,yy,builtLabels{k}, ...
        'FontSize',10, ...
        'VerticalAlignment','middle');
end

xlim(legAx1,[0 1]);
ylim(legAx1,[0.05 1]);
%% -------------------------------------------------
% 17) Response legend below x-axis outside plot
%% -------------------------------------------------
legAx2 = axes('Parent',fig, ...
    'Units','normalized', ...
    'Position',[0.25 0.015 0.55 0.095], ...   % moved lower and wider
    'Visible','off');
hold(legAx2,'on');

fsLeg = 14;   % increased font size

scatter(legAx2,0.04,0.72,65,'o', ...
    'MarkerFaceColor','w', ...
    'MarkerEdgeColor','k', ...
    'LineWidth',1.35);

text(legAx2,0.09,0.72,'Joint exceedance probability', ...
    'FontSize',fsLeg, ...
    'VerticalAlignment','middle');

scatter(legAx2,0.04,0.28,75,'s', ...
    'MarkerFaceColor',[0.72 0.72 0.72], ...
    'MarkerEdgeColor','k', ...
    'MarkerFaceAlpha',0.35, ...
    'MarkerEdgeAlpha',0.90, ...
    'LineWidth',1.7);

text(legAx2,0.09,0.28,'Exceedance probability of TR', ...
    'FontSize',fsLeg, ...
    'VerticalAlignment','middle');

plot(legAx2,[0.57 0.69],[0.72 0.72],':k','LineWidth',1.8);

text(legAx2,0.72,0.72,'Bootstrap fit: joint exceedance', ...
    'FontSize',fsLeg, ...
    'VerticalAlignment','middle');

plot(legAx2,[0.57 0.69],[0.28 0.28],'--', ...
    'Color',[0.40 0.40 0.40], ...
    'LineWidth',1.6);

text(legAx2,0.72,0.28,'Bootstrap fit: TR exceedance', ...
    'FontSize',fsLeg, ...
    'VerticalAlignment','middle');

xlim(legAx2,[0 1]);
ylim(legAx2,[0 1]);

%% -------------------------------------------------
% 8) TR exceedance probability: vegetation-class squares
%% -------------------------------------------------
for k = 1:6

    idVeg = VegClass == string(vegLabels{k});

    if k <= 3
        faceCol = [0.72 0.72 0.72];      % grey for <50, 50–60, 60–70
        edgeCol = 'k';
        edgeAlpha = 0.45;
    else
        faceCol = [0.72 0.90 0.72];      % light green for 70–80, 80–90, ≥90
        edgeCol = [0.00 0.38 0.00];      % deep green boundary
        edgeAlpha = 0.95;
    end

    scatter(ax1, x(idVeg), y_tr(idVeg), vegBoxArea(idVeg)*1.35, ...
        's', ...
        'MarkerFaceColor', faceCol, ...
        'MarkerEdgeColor', edgeCol, ...
        'LineWidth', 1.7, ...
        'MarkerFaceAlpha', 0.45, ...
        'MarkerEdgeAlpha', edgeAlpha);
end

%% -------------------------------------------------
% Secondary left y-axis for TR exceedance probability
%% -------------------------------------------------
ax2 = axes('Position',[0.09 0.20 0.60 0.70], ...
           'Color','none', ...
           'Box','off', ...
           'XAxisLocation','bottom', ...
           'YAxisLocation','left', ...
           'XColor','none', ...
           'YColor','k', ...
           'LineWidth',1.2, ...
           'FontSize',18, ...
           'TickDir','out', ...
           'YLim',[0 100], ...
           'YTick',yt, ...
           'YTickLabel',arrayfun(@(v)sprintf('%d%%',v), yt, 'UniformOutput', false), ...
           'XTick',[], ...
           'XLim',xlim(ax1));

ylabel(ax2,'Exceedance probability of TR', ...
    'FontSize',20, ...
    'FontWeight','bold');