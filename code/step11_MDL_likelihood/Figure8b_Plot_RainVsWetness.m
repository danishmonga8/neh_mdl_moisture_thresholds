clear; clc; close all;

%% ---------- USER PATHS ----------
infile  = fullfile(neh_root(),'step11_MDL_likelihood','Figure8b_CALC_TABLE.xlsx');
out_dir = fullfile(neh_root(),'step11_MDL_likelihood');
if ~exist(out_dir, 'dir'), mkdir(out_dir); end
out_tif = fullfile(out_dir, 'Figure8b_FINAL_1PLOT_2Y_80th.tif');

%% ---------- STYLE ----------
axis_title_size  = 29;
axis_text_size   = 26;
legend_text_size = 28;

lab_x  = 'Rainfall threshold (percentiles)';
lab_yL = 'Number of rainy days in each threshold category';
lab_yR = 'MDL likelihood (%)';

%% ---------- READ ----------
T = readtable(infile, 'Sheet', 1, 'VariableNamingRule','preserve');
Class      = strtrim(string(T.Class));
N_bin      = T.N_bin;
P_rainonly = T.P_rainonly;
P_joint    = T.P_joint_plot;

keep = isfinite(N_bin) & N_bin > 0;
Class = Class(keep); N_bin = N_bin(keep);
P_rainonly = P_rainonly(keep); P_joint = P_joint(keep);

%% ---------- FORCE CHRONOLOGICAL ORDER ----------
classStart = nan(size(Class));
for i = 1:numel(Class)
    if Class(i) == ">90"
        classStart(i) = 999;
    else
        tok = regexp(Class(i), '^(\d+)', 'tokens');
        classStart(i) = str2double(tok{1}{1});
    end
end
[~, ord] = sort(classStart);
Class = Class(ord); N_bin = N_bin(ord);
P_rainonly = P_rainonly(ord); P_joint = P_joint(ord);
Class_original = Class;

%% ---------- CLASS RANGE -> MIDPOINT LABELS ----------
Class_label = strings(size(Class));
for i = 1:numel(Class)
    if Class(i) == ">90"
        Class_label(i) = ">90";
    else
        nums = regexp(Class(i), '\d+', 'match');
        mid = mean(str2double(nums));
        Class_label(i) = string(mid);
    end
end
Class_cat = categorical(Class_label, Class_label, 'Ordinal', true);

%% ---------- CONVERT PROBABILITIES TO PERCENT ----------
P_rain_pct  = 100 * P_rainonly;
P_wet80_pct = 100 * P_joint;

%% ---------- RIGHT-AXIS LIMIT ----------
p_all = [P_rain_pct; P_wet80_pct];
p_all = p_all(isfinite(p_all));
if isempty(p_all)
    pmax_val = 5;
else
    pmax_val = max(p_all);
end
prob_top = ceil((pmax_val + 0.2) / 0.5) * 0.5;

%% ---------- LEFT-AXIS LIMIT ----------
Nmax = max(N_bin);
ymax_left = Nmax * 1.10;

%% ---------- HIGHLIGHT BINS ----------
highlight_bins = ["5-10","10-15","15-20"];
isHighlight = ismember(Class_original, highlight_bins);
barColors = repmat([0.85 0.85 0.85], numel(Class_original), 1);   % grey85
lightgreen = [0.565 0.933 0.565];                                  % 'lightgreen'
alphaHL = 0.35;
highlightColor = alphaHL*lightgreen + (1-alphaHL)*[1 1 1];         % single 1x3 blended color
barColors(isHighlight,:) = repmat(highlightColor, sum(isHighlight), 1);   % <-- fixed: replicate per row

%% ---------- PLOT ----------
fig = figure('Color','w','Position',[80 60 1850 1080]);
ax = axes(fig); hold(ax,'on');
x = 1:numel(Class_cat);

% ----- bars on left axis -----
yyaxis(ax,'left');
hBar = bar(ax, x, N_bin, 0.75, 'FaceColor','flat', 'EdgeColor','none');
hBar.CData = barColors;
ax.YLim = [0 ymax_left];
ax.YColor = 'k';
ylabel(ax, lab_yL, 'FontWeight','bold', 'FontSize', axis_title_size);

% ----- connector lines + points on right axis -----
yyaxis(ax,'right');
ax.YLim = [0 prob_top];
ax.YColor = 'k';
ylabel(ax, lab_yR, 'FontWeight','bold', 'FontSize', axis_title_size);

y_top = max(P_rain_pct, P_wet80_pct);
for i = 1:numel(x)
    if isfinite(y_top(i))
        hLine = plot(ax, [x(i) x(i)], [0 y_top(i)], '--', 'Color','k', 'LineWidth', 0.9);
        hLine.Color(4) = 0.35;
    end
end

okR = isfinite(P_rain_pct);
okW = isfinite(P_wet80_pct);
hRain = plot(ax, x(okR), P_rain_pct(okR), 'o', ...
    'MarkerSize', 9, 'LineWidth', 2.0, 'Color', 'blue', 'MarkerFaceColor', 'none');
hWet  = plot(ax, x(okW), P_wet80_pct(okW), 'o', ...
    'MarkerSize', 9, 'LineWidth', 1.6, 'Color', 'red', 'MarkerFaceColor', 'red');

%% ---------- X AXIS ----------
ax.XTick = x;
ax.XTickLabel = cellstr(Class_cat);
ax.XLim = [0.4, numel(x)+0.6];
xlabel(ax, lab_x, 'FontWeight','bold', 'FontSize', axis_title_size);

%% ---------- GENERAL STYLE ----------
ax.FontSize = axis_text_size;
ax.FontWeight = 'bold';
ax.Box = 'on';
ax.GridLineStyle = '-';
ax.GridAlpha = 0.25;
grid(ax,'on');
ax.Layer = 'top';

%% ---------- LEGEND ----------
lgd = legend(ax, [hWet, hRain], ...
    {'Rain + Wetness (80th percentile)', 'Rain only'}, ...
    'Orientation','horizontal', 'Box','on');
lgd.FontSize = legend_text_size;
lgd.FontWeight = 'bold';
lgd.Location = 'north';
lgd.Color = [1 1 1];

%% ---------- EXPORT ----------
exportgraphics(fig, out_tif, 'Resolution', 300);
fprintf('Saved: %s\n', out_tif);