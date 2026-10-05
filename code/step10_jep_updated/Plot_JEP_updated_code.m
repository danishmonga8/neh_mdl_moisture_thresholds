clear; clc; close all;

%% -------------------------------------------------
% 0) Load updated JEP data (rank/(N+1) corrected)
%% -------------------------------------------------
inFile = fullfile(neh_root(),'step10_jep_updated','EmpiricalProb_All_Large_Events_Corrected_rankNplus1.xlsx');
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

n = numel(x);

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
bubbleArea(BuiltClass=="≤2%")    = 150;
bubbleArea(BuiltClass=="2–4%")   = 230;
bubbleArea(BuiltClass=="4–6%")   = 330;
bubbleArea(BuiltClass=="6–10%")  = 500;
bubbleArea(BuiltClass=="10–15%") = 720;
bubbleArea(BuiltClass==">15%")   = 1250;

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
vegBoxArea(VegClass=="<50%")    = 150;
vegBoxArea(VegClass=="50–60%")  = 230;
vegBoxArea(VegClass=="60–70%")  = 340;
vegBoxArea(VegClass=="70–80%")  = 520;
vegBoxArea(VegClass=="80–90%")  = 780;
vegBoxArea(VegClass=="≥90%")    = 1250;

vegLabels = {'<50%','50–60%','60–70%','70–80%','80–90%','≥90%'};

%% -------------------------------------------------
% 3) Landslide-year colors (generalized to actual year range in data)
%% -------------------------------------------------
yearsFull = (min(yr):max(yr))';
nY = numel(yearsFull);

% Original 11-stop pale-yellow -> dark-red anchor palette, interpolated
% to however many years are actually present in the corrected data.
anchorMap = [ ...
    1.00 1.00 0.80;
    1.00 0.96 0.52;
    1.00 0.90 0.26;
    1.00 0.82 0.00;
    1.00 0.70 0.00;
    1.00 0.56 0.00;
    1.00 0.38 0.00;
    0.96 0.15 0.00;
    0.78 0.00 0.00;
    0.50 0.00 0.00;
    0.22 0.00 0.00];
nAnchor = size(anchorMap,1);
if nY == 1
    yearMap = anchorMap(1,:);
else
    tAnchor = linspace(0,1,nAnchor);
    tQuery  = linspace(0,1,nY);
    yearMap = zeros(nY,3);
    for c = 1:3
        yearMap(:,c) = interp1(tAnchor, anchorMap(:,c), tQuery, 'pchip');
    end
    yearMap = min(max(yearMap,0),1);
end

[~, yearIdx] = ismember(yr, yearsFull);
if any(yearIdx == 0)
    warning('Some landslide years are outside the detected range and will not be color-plotted.');
end

%% -------------------------------------------------
% 3A) Event numbering within each station (resets per station)
%% -------------------------------------------------
eventNumber = zeros(size(stn));
uStn = unique(stn,'stable');
nStn = numel(uStn);
for ss = 1:nStn
    idS = find(stn == uStn(ss));
    [~, ord] = sortrows([yr(idS), y_tri(idS)], [1 2]);
    idS_sorted = idS(ord);
    eventNumber(idS_sorted) = (1:numel(idS_sorted))';
end

%% -------------------------------------------------
% 4) Bootstrap regression: Joint exceedance probability
%% -------------------------------------------------
stream = RandStream('mt19937ar','Seed',123);
RandStream.setGlobalStream(stream);
Nboot = 5000;

bootCoef_tri = zeros(Nboot,2);
for b = 1:Nboot
    idx = randi(n,n,1);
    p = polyfit(x(idx), y_tri_prob(idx), 1);
    bootCoef_tri(b,:) = [p(2), p(1)];
end
boot_intercept_tri = median(bootCoef_tri(:,1));
boot_slope_tri     = median(bootCoef_tri(:,2));
Slope_boot_tri     = bootCoef_tri(:,2);
boot_slope_tri_10  = boot_slope_tri * 10;
p_left_tri  = mean(Slope_boot_tri <= 0);
p_right_tri = mean(Slope_boot_tri >= 0);
p_boot_tri  = min(2 * min(p_left_tri,p_right_tri), 1);

%% -------------------------------------------------
% 5) Bootstrap regression: TR exceedance probability
%% -------------------------------------------------
bootCoef_tr = zeros(Nboot,2);
for b = 1:Nboot
    idx = randi(n,n,1);
    p = polyfit(x(idx), y_tr_prob(idx), 1);
    bootCoef_tr(b,:) = [p(2), p(1)];
end
boot_intercept_tr = median(bootCoef_tr(:,1));
boot_slope_tr     = median(bootCoef_tr(:,2));
Slope_boot_tr     = bootCoef_tr(:,2);
boot_slope_tr_10  = boot_slope_tr * 10;
p_left_tr  = mean(Slope_boot_tr <= 0);
p_right_tr = mean(Slope_boot_tr >= 0);
p_boot_tr  = min(2 * min(p_left_tr,p_right_tr), 1);

%% -------------------------------------------------
% 5A) 95% bootstrap CIs and SE
%% -------------------------------------------------
Slope_boot_tri_10_pct = Slope_boot_tri * 10;
Slope_boot_tr_10_pct  = Slope_boot_tr  * 10;
CI_tri_95 = prctile(Slope_boot_tri_10_pct,[2.5 97.5]);
CI_tr_95  = prctile(Slope_boot_tr_10_pct,[2.5 97.5]);
SE_tri_10_pct = std(Slope_boot_tri_10_pct,0,'omitnan');
SE_tr_10_pct  = std(Slope_boot_tr_10_pct,0,'omitnan');

%% -------------------------------------------------
% 5B) Display bootstrap results
%% -------------------------------------------------
fprintf('\n================ Bootstrap regression results ================\n');
fprintf('\nJoint exceedance probability: TR–AMC–S_eff\n');
fprintf('beta = %.4f +/- %.4f per 10 degrees\n', boot_slope_tri_10, SE_tri_10_pct);
fprintf('95%% CI = [%.4f, %.4f]\n', CI_tri_95(1), CI_tri_95(2));
fprintf('Two-sided bootstrap p-value = %.4f\n', p_boot_tri);
fprintf('\nTR-only exceedance probability\n');
fprintf('beta = %.4f +/- %.4f per 10 degrees\n', boot_slope_tr_10, SE_tr_10_pct);
fprintf('95%% CI = [%.4f, %.4f]\n', CI_tr_95(1), CI_tr_95(2));
fprintf('Two-sided bootstrap p-value = %.4f\n', p_boot_tr);
fprintf('\nFor manuscript reporting:\n');
fprintf('beta_(TR,AMC,S_eff) = %.2f +/- %.2f per 10 deg (p = %.2f)\n', ...
    boot_slope_tri_10, SE_tri_10_pct, p_boot_tri);
fprintf('beta_TR = %.2f +/- %.2f per 10 deg (p = %.2f)\n', ...
    boot_slope_tr_10, SE_tr_10_pct, p_boot_tr);
fprintf('\n===============================================================\n');

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
set(fig,'Renderer','opengl');
ax1 = axes(fig);
hold(ax1,'on');
ax1.Position      = [0.16 0.18 0.62 0.72];
ax1.Box           = 'off';
ax1.LineWidth     = 1.2;
ax1.FontSize      = 18;
ax1.TickDir       = 'out';
ax1.Layer         = 'top';
ax1.GridLineStyle = ':';
ax1.GridAlpha     = 0.28;
grid(ax1,'on');

%% -------------------------------------------------
% 8) Bootstrap fit lines and reference lines
%% -------------------------------------------------
plot(ax1, xx, yy_tri, ':k', 'LineWidth', 1.8);
plot(ax1, xx, yy_tr, '--', 'Color', [0.40 0.40 0.40], 'LineWidth', 1.5);
xline(ax1, 10, '--', 'Color', 'k', 'LineWidth', 2);
xline(ax1, 20, '--', 'Color', 'k', 'LineWidth', 2);
yline(ax1, 10, '--', 'Color', [1 0 0], 'LineWidth', 2);

%% -------------------------------------------------
% 9) Green TR squares (higher vegetation classes), plotted first
%% -------------------------------------------------
for k = 4:6
    idVeg = VegClass == string(vegLabels{k});
    if ~any(idVeg), continue; end
    scatter(ax1, x(idVeg), y_tr(idVeg), vegBoxArea(idVeg)*1.15, ...
        's', 'MarkerFaceColor',[0.72 0.90 0.72], 'MarkerEdgeColor',[0.00 0.38 0.00], ...
        'LineWidth',2.2, 'MarkerFaceAlpha',0.16, 'MarkerEdgeAlpha',1.00);
end

%% -------------------------------------------------
% 10) Joint exceedance probability circles, colored by year
%% -------------------------------------------------
for i = 1:nY
    id = (yearIdx == i);
    id_lowBuilt  = id & BuiltClass ~= ">15%" & bubbleArea > 0;
    id_highBuilt = id & BuiltClass == ">15%" & bubbleArea > 0;
    if any(id_lowBuilt)
        scatter(ax1, x(id_lowBuilt), y_tri(id_lowBuilt), bubbleArea(id_lowBuilt)*1.16, ...
            'o', 'filled', 'MarkerFaceColor',yearMap(i,:), 'MarkerEdgeColor','k', ...
            'LineWidth',1.55, 'MarkerFaceAlpha',0.82, 'MarkerEdgeAlpha',0.98);
    end
    if any(id_highBuilt)
        scatter(ax1, x(id_highBuilt), y_tri(id_highBuilt), bubbleArea(id_highBuilt)*1.16, ...
            'o', 'filled', 'MarkerFaceColor',yearMap(i,:), 'MarkerEdgeColor',[0.85 0.00 0.00], ...
            'LineWidth',2.6, 'MarkerFaceAlpha',0.82, 'MarkerEdgeAlpha',0.98);
    end
end

%% -------------------------------------------------
% 10A) Grey TR squares (lower vegetation classes), plotted last
%% -------------------------------------------------
for k = 1:3
    idVeg = VegClass == string(vegLabels{k});
    if ~any(idVeg), continue; end
    scatter(ax1, x(idVeg), y_tr(idVeg), vegBoxArea(idVeg)*1.20, ...
        's', 'MarkerFaceColor',[0.55 0.55 0.55], 'MarkerEdgeColor',[0.05 0.05 0.05], ...
        'LineWidth',2.4, 'MarkerFaceAlpha',0.60, 'MarkerEdgeAlpha',1.00);
end

%% -------------------------------------------------
% 10B) Event numbers on circles and squares (contrast-based text color)
%% -------------------------------------------------
for j = 1:n
    if yearIdx(j) > 0
        c = yearMap(yearIdx(j),:);
        lum = 0.299*c(1) + 0.587*c(2) + 0.114*c(3);
        if lum < 0.55
            numColorTri = 'w';
        else
            numColorTri = 'k';
        end
    else
        numColorTri = 'k';
    end
    text(ax1, x(j), y_tri(j), 1.4e-14, sprintf('%d',eventNumber(j)), ...
        'FontSize',10.2,'FontWeight','bold','Color',numColorTri, ...
        'HorizontalAlignment','center','VerticalAlignment','middle','Clipping','on');
    text(ax1, x(j), y_tr(j), 1.4e-14, sprintf('%d',eventNumber(j)), ...
        'FontSize',10.2,'FontWeight','bold','Color','k', ...
        'HorizontalAlignment','center','VerticalAlignment','middle','Clipping','on');
end

%% -------------------------------------------------
% 10C) Station names inside plot — auto-positioned near each cluster
%      (edit STATION_POS below to hand-place any station like before)
%% -------------------------------------------------
STATION_POS = containers.Map('KeyType','char','ValueType','any');
% Example manual override (uncomment and edit as needed):
% STATION_POS('Aizwal') = [22.5, 56.0];

for ss = 1:nStn
    nm = char(uStn(ss));
    idS = (stn == uStn(ss));
    if isKey(STATION_POS, nm)
        pos = STATION_POS(nm);
        lx = pos(1); ly = pos(2);
    else
        [ly, iMax] = max(y_tri(idS));
        idxList = find(idS);
        lx = x(idxList(iMax));
        ly = ly + 3;
    end
    text(ax1, lx, ly, 1.4e-14, nm, ...
        'FontSize',12.2,'FontWeight','bold','Color','k', ...
        'HorizontalAlignment','left','VerticalAlignment','middle', ...
        'BackgroundColor','none','Clipping','on');
end

%% -------------------------------------------------
% 11) Axes formatting
%% -------------------------------------------------
xlim(ax1,[min(x)-0.8, max(x)+0.8]);
ylim(ax1,[0 100]);
xt = ceil(min(x)):2:floor(max(x));
xticks(ax1,xt);
xticklabels(ax1, arrayfun(@(v)sprintf('%d°',v), xt, 'UniformOutput', false));
yt = 0:10:100;
yticks(ax1,yt);
yticklabels(ax1, arrayfun(@(v)sprintf('%d%%',v), yt, 'UniformOutput', false));
xlabel(ax1,'Slope','FontSize',22,'FontWeight','bold');
ylabel(ax1,'Joint exceedance probability','FontSize',22,'FontWeight','bold');

%% -------------------------------------------------
% 12) Regression annotations (positioned as a fraction of the data range)
%% -------------------------------------------------
xr = xlim(ax1); yr_ax = ylim(ax1);
xAnn_tr = xr(1) + 0.06*range(xr);
yAnn_tr = yr_ax(1) + 0.38*range(yr_ax);
txt_tr = sprintf('$\\beta_{\\mathrm{TR}} = %.2f \\pm %.2f\\ \\mathrm{per}\\ 10^{\\circ}\\ (p = %.2f)$', ...
    boot_slope_tr_10, SE_tr_10_pct, p_boot_tr);
text(ax1, xAnn_tr, yAnn_tr, 1.4e-14, txt_tr, 'Interpreter','latex','FontSize',18, ...
    'HorizontalAlignment','left','VerticalAlignment','bottom','BackgroundColor','none', ...
    'Margin',3,'Rotation',2);

xAnn_tri = xr(1) + 0.04*range(xr);
yAnn_tri = yr_ax(1) + 0.20*range(yr_ax);
txt_tri = sprintf('$\\beta_{(\\mathrm{TR},\\mathrm{AMC},S_{\\mathrm{eff}})} = %.2f \\pm %.2f\\ \\mathrm{per}\\ 10^{\\circ}\\ (p = %.2f)$', ...
    boot_slope_tri_10, SE_tri_10_pct, p_boot_tri);
text(ax1, xAnn_tri, yAnn_tri, 1.4e-14, txt_tri, 'Interpreter','latex','FontSize',18, ...
    'HorizontalAlignment','left','VerticalAlignment','bottom','BackgroundColor','none', ...
    'Margin',3,'Rotation',2);

%% -------------------------------------------------
% 13) Custom colorbar (generalized to actual year range)
%% -------------------------------------------------
cbAx = axes('Parent',fig,'Units','normalized','Position',[0.82 0.18 0.10 0.72]);
hold(cbAx,'on');
axis(cbAx,'off');

yearEdges = min(yr):max(yr);
if numel(yearEdges) < 2
    yearEdges = [yearEdges, yearEdges+1];
end
nBlocks = numel(yearEdges) - 1;

tAnchorCb = linspace(0,1,nAnchor);
tQueryCb  = linspace(0,1,nBlocks);
cbMap = zeros(nBlocks,3);
for c = 1:3
    cbMap(:,c) = interp1(tAnchorCb, anchorMap(:,c), tQueryCb, 'pchip');
end
cbMap = min(max(cbMap,0),1);

barX0 = 0.00; barX1 = 0.28;
for ii = 1:nBlocks
    y0 = yearEdges(ii); y1 = yearEdges(ii+1);
    patch(cbAx, [barX0 barX1 barX1 barX0], [y0 y0 y1 y1], cbMap(ii,:), 'EdgeColor','none');
end
plot(cbAx,[barX0 barX0],[yearEdges(1) yearEdges(end)],'k','LineWidth',0.9);
plot(cbAx,[barX1 barX1],[yearEdges(1) yearEdges(end)],'k','LineWidth',0.9);
plot(cbAx,[barX0 barX1],[yearEdges(1) yearEdges(1)],'k','LineWidth',0.9);
plot(cbAx,[barX0 barX1],[yearEdges(end) yearEdges(end)],'k','LineWidth',0.9);

tickLen = 0.035;
for yyTick = yearEdges
    plot(cbAx,[barX1 barX1+tickLen],[yyTick yyTick],'k','LineWidth',0.8);
end
for yyTick = yearEdges
    text(cbAx, barX1 + 0.09, yyTick, sprintf('%d',yyTick), ...
        'FontSize',18,'FontWeight','bold','HorizontalAlignment','left', ...
        'VerticalAlignment','middle','Color','k','Clipping','off');
end
text(cbAx, barX1 + 0.48, mean([yearEdges(1) yearEdges(end)]), 'Landslide year', ...
    'FontSize',21,'FontWeight','bold','Rotation',90, ...
    'HorizontalAlignment','center','VerticalAlignment','middle','Color','k','Clipping','off');
xlim(cbAx,[0 0.85]);
ylim(cbAx,[yearEdges(1) yearEdges(end)]);

%% -------------------------------------------------
% 14) Secondary left y-axis for TR exceedance probability
%% -------------------------------------------------
ax2 = axes('Position',[0.09 0.18 0.62 0.72], ...
    'Color','none','Box','off','XAxisLocation','bottom','YAxisLocation','left', ...
    'XColor','none','YColor','k','LineWidth',1.2,'FontSize',18,'TickDir','out', ...
    'YLim',[0 100],'YTick',yt,'YTickLabel',arrayfun(@(v)sprintf('%d%%',v), yt, 'UniformOutput', false), ...
    'XTick',[],'XLim',xlim(ax1));
ylabel(ax2,'Exceedance probability of TR','FontSize',22,'FontWeight','bold');
uistack(ax2,'bottom');
uistack(ax1,'top');