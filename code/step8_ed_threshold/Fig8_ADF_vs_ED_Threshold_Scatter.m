%% ========================================================================
% FIGURE (b) -- ADF vs. ED-THRESHOLD SCATTER (updated ADF)
%
% x = corrected ADF (independently-selected N*, see Step2_ADF_Correction.m)
% y = 3-day rainfall threshold (mm) at tau = 0.20, linear quantile
%     regression (E3_P20, read from ED_Linear_vs_PowerLaw_AllStations.xlsx,
%     Linear_quantile sheet -- not re-fit here)
%
% A simple linear fit (polyfit) is drawn through the points and Kendall's
% tau (with its p-value) is annotated, matching the reference figure.
%
% NOTE ON SCOPE: unlike Fig8_ED_Threshold_Spatial_Map.m, this script does
% NOT greyed-out/exclude stations with < MIN_EVENTS matched events -- that
% was only requested for the spatial map. All jointly-available stations
% are plotted here. If you want the same low-sample treatment applied to
% this scatter too, say so and it's a small change (filter Data by
% Low_sample before plotting/fitting).
%
% OUTPUT:
%   Fig8b_ADF_vs_ED_Threshold_Scatter.jpg  (300 dpi)
% ========================================================================

clc;
clear;
close all;


%% ========================================================================
% 1. PATHS
%% ========================================================================

ED_FILE = ...
    fullfile(neh_root(),'step8_ed_threshold','ED_Linear_vs_PowerLaw_AllStations.xlsx');

% Updated (independently-selected-N*) ADF results -- see
% Step2_ADF_Correction.m.
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

OUT_JPG = fullfile( ...
    OUT_DIR, ...
    'Fig8b_ADF_vs_ED_Threshold_Scatter.jpg');


%% ========================================================================
% 3. READ ED THRESHOLD (E3_P20) AND UPDATED ADF, JOIN
%% ========================================================================

TED = readtable( ...
    ED_FILE, ...
    'Sheet','Linear_quantile', ...
    'VariableNamingRule','preserve', ...
    'TextType','string');

TED.IMD_ID = normalizeID(TED.IMD_ID);
TED = TED(string(TED.Status) == "OK", {'IMD_ID','E3_P20'});


TADF = readtable( ...
    ADF_FILE, ...
    'Sheet','ADF_summary', ...
    'VariableNamingRule','preserve', ...
    'TextType','string');

TADF.IMD_ID = normalizeID(TADF.IMD_ID);
TADF = TADF(string(TADF.Status) == "OK", {'IMD_ID','ADF','Matched_events'});


Data = innerjoin(TADF, TED, 'Keys','IMD_ID');

Data = Data(isfinite(Data.ADF) & isfinite(Data.E3_P20), :);

n = height(Data);

fprintf('Stations in scatter: %d\n', n);


%% ========================================================================
% 4. LINEAR FIT + KENDALL'S TAU (no Statistics Toolbox dependency)
%% ========================================================================

x = Data.ADF;
y = Data.E3_P20;

p = polyfit(x, y, 1);
slope = p(1);
intercept = p(2);

[tau, pval] = kendallTauLocal(x, y);

fprintf('Linear fit : E3_P20 = %.3f + %.3f * ADF\n', intercept, slope);
fprintf('Kendall''s tau = %.3f   p = %.3f\n', tau, pval);


%% ========================================================================
% 5. PLOT
%% ========================================================================

fig = figure( ...
    'Color','w', ...
    'Units','inches', ...
    'Position',[1 1 7.2 6.6]);


ax = axes('Parent',fig);
hold(ax,'on');

grid(ax,'on');
set(ax, 'GridLineStyle','--', 'GridColor',[0.85 0.85 0.85], 'GridAlpha',1, 'Layer','bottom');


scatter(ax, x, y, 110, [0.85 0.65 0.80], 'filled', ...
    'MarkerEdgeColor','k', 'LineWidth',0.9, 'MarkerFaceAlpha',0.85);


xFit = linspace(min(x), max(x), 100);
yFit = intercept + slope*xFit;

plot(ax, xFit, yFit, 'Color',[0.85 0.15 0.15], 'LineWidth',1.8);


set(ax, 'FontSize',15, 'Box','on', 'LineWidth',0.9, 'TickDir','out');

xlabel(ax, 'ADF', 'FontSize',18, 'FontWeight','bold');

ylabel(ax, sprintf('%d-day rainfall threshold (mm)\nat \\tau = %.2f', DUR_DAYS, TAU_LEVEL), ...
    'FontSize',16, 'FontWeight','bold', 'Interpreter','tex');

text(ax, 0.01, 1.05, '(b)', 'Units','normalized', 'FontSize',24, 'FontWeight','bold');

text(ax, 0.97, 0.97, sprintf('Kendall''s \\tau = %.2f\np = %.3f', tau, pval), ...
    'Units','normalized', 'HorizontalAlignment','right', 'VerticalAlignment','top', ...
    'FontSize',13, 'Interpreter','tex');


%% ========================================================================
% 6. SAVE (300 dpi JPEG)
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


function [tau_b, pval] = kendallTauLocal(x, y)
% Kendall's tau-b with a normal-approximation two-sided p-value
% (no-tie asymptotic variance). Implemented locally so this script has
% no dependency on the Statistics and Machine Learning Toolbox (corr).
% For small n with no ties this closely matches an exact Kendall test;
% MATLAB's own corr(x,y,'Type','Kendall') can be substituted if that
% toolbox is available and an exact/tie-adjusted p-value is preferred.

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

    pval = 2*(1 - normcdfLocal(abs(z)));

end


function t = tieTerm(v)
    u = unique(v);
    t = 0;
    for k = 1:numel(u)
        c = sum(v == u(k));
        t = t + c*(c-1)/2;
    end
end


function p = normcdfLocal(z)
    p = 0.5*(1+erf(z/sqrt(2)));
end
