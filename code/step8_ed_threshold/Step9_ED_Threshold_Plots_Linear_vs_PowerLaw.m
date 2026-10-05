%% ========================================================================
% Step9_ED_Threshold_Plots_Linear_vs_PowerLaw.m
%
% PURPOSE
% -------------------------------------------------------------------------
% Publication-style ED threshold plots for stations having:
%
%       > 15 valid triggering / landslide events
%
%
% FIGURE 1
% -------------------------------------------------------------------------
% Linear quantile-regression ED thresholds
%
%       E_tau(D) = a_tau + b_tau D
%
%
% FIGURE 2
% -------------------------------------------------------------------------
% Log-log power-law ED thresholds
%
%       log(E_tau) = c_tau + beta_tau log(D)
%
% therefore
%
%       E_tau(D) = alpha_tau D^(beta_tau)
%
%       alpha_tau = exp(c_tau)
%
%
% Only two thresholds are plotted:
%
%       tau = 0.20
%       tau = 0.10
%
%
% IMPORTANT
% -------------------------------------------------------------------------
% - Station selection is based on number of valid rows in the
%   "trigging" sheet.
%
% - N_triggering > 15 is required.
%
% - The already-generated summary workbook is used for the exact
%   20th-percentile model coefficients.
%
% - The 10th-percentile relationship is fitted using the same
%   ncquantreg method.
%
% - Quantiles are fitted individually, therefore ncquantreg uses
%   fminsearch and DOES NOT require fmincon.
%
% ========================================================================

clc;
clear;
close all;


%% ========================================================================
% 1. PATHS
%% ========================================================================

STEP8_ROOT = ...
    fullfile(neh_root(),'step8_ed_threshold');


%% ------------------------------------------------------------------------
% Station-wise ED input files
%
% Example:
%
% 42299_triggering_output.xlsx
%% ------------------------------------------------------------------------

INPUT_FOLDER = fullfile( ...
    STEP8_ROOT, ...
    'ed_threshold_updated', ...
    'Output_Triggering_Events');


%% ------------------------------------------------------------------------
% Previously generated linear + power-law workbook
%% ------------------------------------------------------------------------

SUMMARY_XLSX = fullfile( ...
    STEP8_ROOT, ...
    'ED_Linear_vs_PowerLaw_AllStations.xlsx');


%% ------------------------------------------------------------------------
% Figure output
%% ------------------------------------------------------------------------

OUTPUT_FOLDER = fullfile( ...
    STEP8_ROOT, ...
    'ED_Plots_Linear_PowerLaw');


%% ------------------------------------------------------------------------
% ncquantreg.m
%% ------------------------------------------------------------------------

NCQUANTREG_FOLDER = ...
    fullfile(neh_root(),'2_new_stations_neh','9_ideal_lag');


addpath(NCQUANTREG_FOLDER);


%% ========================================================================
% 2. CREATE OUTPUT DIRECTORY
%% ========================================================================

if ~exist(OUTPUT_FOLDER,'dir')

    mkdir(OUTPUT_FOLDER);

end


%% ========================================================================
% 3. CHECK INPUTS
%% ========================================================================

if ~exist(INPUT_FOLDER,'dir')

    error( ...
        'ED input folder not found:\n%s', ...
        INPUT_FOLDER);

end


if ~isfile(SUMMARY_XLSX)

    error( ...
        'Summary workbook not found:\n%s', ...
        SUMMARY_XLSX);

end


if exist('ncquantreg','file') ~= 2

    error( ...
        ['ncquantreg.m was not found.' newline ...
         'Check this folder:' newline ...
         '%s'], ...
        NCQUANTREG_FOLDER);

end


fprintf('\n');
fprintf('=============================================================\n');
fprintf(' ED THRESHOLD PLOTTING\n');
fprintf('=============================================================\n');

fprintf('\nInput ED files:\n%s\n',INPUT_FOLDER);
fprintf('\nSummary workbook:\n%s\n',SUMMARY_XLSX);
fprintf('\nFigure output:\n%s\n',OUTPUT_FOLDER);

fprintf('\n=============================================================\n\n');


%% ========================================================================
% 4. SETTINGS
%% ========================================================================

TAU20 = ...
    0.20;


TAU10 = ...
    0.10;


%% ------------------------------------------------------------------------
% Advisor screening:
%
% MORE THAN 15 triggering / landslide observations
%% ------------------------------------------------------------------------

MIN_TRIGGERING_EVENTS = ...
    15;


%% ========================================================================
% 5. READ LINEAR AND POWER-LAW SUMMARY SHEETS
%% ========================================================================

Tlinear = readtable( ...
    SUMMARY_XLSX, ...
    'Sheet','Linear_quantile', ...
    'VariableNamingRule','preserve');


Tpower = readtable( ...
    SUMMARY_XLSX, ...
    'Sheet','PowerLaw_loglog', ...
    'VariableNamingRule','preserve');


%% ========================================================================
% 6. STANDARDIZE IDS IN BOTH TABLES
%% ========================================================================

if isnumeric(Tlinear.IMD_ID)

    linear_ID = ...
        string(compose('%.0f',Tlinear.IMD_ID));

else

    linear_ID = ...
        strip(string(Tlinear.IMD_ID));

    linear_ID = ...
        regexprep(linear_ID,'\.0$','');

end


if isnumeric(Tpower.IMD_ID)

    power_ID = ...
        string(compose('%.0f',Tpower.IMD_ID));

else

    power_ID = ...
        strip(string(Tpower.IMD_ID));

    power_ID = ...
        regexprep(power_ID,'\.0$','');

end


%% ========================================================================
% 7. SCREEN STATIONS USING TRIGGERING / LANDSLIDE SAMPLE COUNT
%
% Important:
%
% We DO NOT use Tlinear.N_samples for screening because that includes:
%
%       antecedent events + triggering events
%
% Here we specifically count valid observations in the "trigging" sheet.
%% ========================================================================

nAll = ...
    height(Tlinear);


N_AP = ...
    nan(nAll,1);


N_TRIGGERING = ...
    nan(nAll,1);


Include = ...
    false(nAll,1);


InputStatus = ...
    strings(nAll,1);


for i = 1:nAll


    id = ...
        linear_ID(i);


    file_path = fullfile( ...
        INPUT_FOLDER, ...
        sprintf( ...
        '%s_triggering_output.xlsx', ...
        char(id)));


    %% --------------------------------------------------------------------
    % File check
    %% --------------------------------------------------------------------

    if ~isfile(file_path)


        InputStatus(i) = ...
            "Input file missing";


        continue

    end


    try


        %% ----------------------------------------------------------------
        % Read antecedent rainfall events
        %% ----------------------------------------------------------------

        AP = readmatrix( ...
            file_path, ...
            'Sheet','ap');


        %% ----------------------------------------------------------------
        % Read triggering rainfall / landslide-associated events
        %% ----------------------------------------------------------------

        TRIG = readmatrix( ...
            file_path, ...
            'Sheet','trigging');


        %% ----------------------------------------------------------------
        % Protect against empty sheets
        %% ----------------------------------------------------------------

        if isempty(AP)

            AP = ...
                zeros(0,2);

        end


        if isempty(TRIG)

            TRIG = ...
                zeros(0,2);

        end


        %% ----------------------------------------------------------------
        % Valid antecedent rows
        %% ----------------------------------------------------------------

        if size(AP,2) >= 2


            goodAP = ...
                isfinite(AP(:,1)) & ...
                isfinite(AP(:,2)) & ...
                AP(:,1) > 0 & ...
                AP(:,2) > 0;


            AP = ...
                AP(goodAP,1:2);


        else


            AP = ...
                zeros(0,2);

        end


        %% ----------------------------------------------------------------
        % Valid triggering rows
        %% ----------------------------------------------------------------

        if size(TRIG,2) >= 2


            goodTRIG = ...
                isfinite(TRIG(:,1)) & ...
                isfinite(TRIG(:,2)) & ...
                TRIG(:,1) > 0 & ...
                TRIG(:,2) > 0;


            TRIG = ...
                TRIG(goodTRIG,1:2);


        else


            TRIG = ...
                zeros(0,2);

        end


        %% ----------------------------------------------------------------
        % Counts
        %% ----------------------------------------------------------------

        N_AP(i) = ...
            size(AP,1);


        N_TRIGGERING(i) = ...
            size(TRIG,1);


        %% ----------------------------------------------------------------
        % Advisor rule:
        %
        % > 15 triggering / landslide observations
        %% ----------------------------------------------------------------

        if N_TRIGGERING(i) > MIN_TRIGGERING_EVENTS


            Include(i) = ...
                true;


            InputStatus(i) = ...
                "Included";


        else


            Include(i) = ...
                false;


            InputStatus(i) = ...
                "Excluded: triggering n <= 15";

        end


    catch ME


        InputStatus(i) = ...
            "Read error: " + string(ME.message);


    end

end


%% ========================================================================
% 8. SCREENING TABLE
%% ========================================================================

ScreeningTable = table( ...
    string(Tlinear.Station), ...
    linear_ID, ...
    N_AP, ...
    N_TRIGGERING, ...
    Include, ...
    InputStatus, ...
    'VariableNames',{ ...
    'Station', ...
    'IMD_ID', ...
    'N_antecedent_events', ...
    'N_triggering_landslide_events', ...
    'Included_GT15', ...
    'Status'});


screeningFile = fullfile( ...
    OUTPUT_FOLDER, ...
    'ED_Plot_Station_Screening.xlsx');


writetable( ...
    ScreeningTable, ...
    screeningFile);


%% ========================================================================
% 9. SELECT ELIGIBLE STATIONS
%% ========================================================================

plotRows = ...
    find(Include);


nPlot = ...
    numel(plotRows);


fprintf('\n');
fprintf('=============================================================\n');
fprintf(' STATION SCREENING\n');
fprintf('=============================================================\n');

fprintf( ...
    'Total stations              : %d\n', ...
    nAll);


fprintf( ...
    'Required triggering events  : > %d\n', ...
    MIN_TRIGGERING_EVENTS);


fprintf( ...
    'Stations retained           : %d\n', ...
    nPlot);


fprintf('=============================================================\n\n');


if nPlot == 0

    error( ...
        'No stations have more than %d valid triggering events.', ...
        MIN_TRIGGERING_EVENTS);

end


disp( ...
    ScreeningTable(Include, ...
    {'Station','IMD_ID','N_triggering_landslide_events'}));


%% ========================================================================
% 10. FIGURE LAYOUT
%% ========================================================================

if nPlot <= 9

    nCols = ...
        3;

elseif nPlot <= 12

    nCols = ...
        4;

else

    nCols = ...
        5;

end


nRows = ...
    ceil(nPlot/nCols);


%% ========================================================================
% 11. COMMON FIGURE STYLE
%% ========================================================================

antecedentColor = ...
    [0.05 0.30 0.90];


triggerColor = ...
    [0.90 0.15 0.15];


line20Color = ...
    [0.85 0.10 0.10];


line10Color = ...
    [0.25 0.25 0.25];


markerSize = ...
    34;


lineWidth20 = ...
    2.2;


lineWidth10 = ...
    1.8;


axisFont = ...
    10;


titleFont = ...
    12;


equationFont = ...
    9.5;


globalLabelFont = ...
    18;


%% ########################################################################
% ########################################################################
%
% FIGURE 1
%
% LINEAR QUANTILE-REGRESSION ED THRESHOLDS
%
%       E_tau(D) = a_tau + b_tau D
%
% ########################################################################
% ########################################################################

fig1 = figure( ...
    'Color','w', ...
    'Units','centimeters', ...
    'Position',[1 1 38 22], ...
    'Renderer','painters');


tl1 = tiledlayout( ...
    fig1, ...
    nRows, ...
    nCols, ...
    'TileSpacing','compact', ...
    'Padding','compact');


legendHandles1 = ...
    gobjects(4,1);


for q = 1:nPlot


    i = ...
        plotRows(q);


    station = ...
        string(Tlinear.Station(i));


    id = ...
        linear_ID(i);


    file_path = fullfile( ...
        INPUT_FOLDER, ...
        sprintf( ...
        '%s_triggering_output.xlsx', ...
        char(id)));


    %% ====================================================================
    % READ AP + TRIGGERING
    %% ====================================================================

    AP = readmatrix( ...
        file_path, ...
        'Sheet','ap');


    TRIG = readmatrix( ...
        file_path, ...
        'Sheet','trigging');


    if isempty(AP)

        AP = ...
            zeros(0,2);

    end


    if isempty(TRIG)

        TRIG = ...
            zeros(0,2);

    end


    AP = ...
        AP(:,1:2);


    TRIG = ...
        TRIG(:,1:2);


    goodAP = ...
        isfinite(AP(:,1)) & ...
        isfinite(AP(:,2)) & ...
        AP(:,1) > 0 & ...
        AP(:,2) > 0;


    goodTRIG = ...
        isfinite(TRIG(:,1)) & ...
        isfinite(TRIG(:,2)) & ...
        TRIG(:,1) > 0 & ...
        TRIG(:,2) > 0;


    AP = ...
        AP(goodAP,:);


    TRIG = ...
        TRIG(goodTRIG,:);


    COMBINED = [ ...
        AP; ...
        TRIG];


    %% ====================================================================
    % VARIABLES
    %% ====================================================================

    D = ...
        COMBINED(:,2);


    E = ...
        COMBINED(:,1);


    %% ====================================================================
    % 20TH PERCENTILE
    %
    % Use EXACT coefficients from previously generated workbook.
    %% ====================================================================

    a20 = ...
        Tlinear.Intercept_P20(i);


    b20 = ...
        Tlinear.Slope_P20(i);


    %% ====================================================================
    % 10TH PERCENTILE
    %
    % Single tau -> ncquantreg uses fminsearch, not fmincon.
    %% ====================================================================

    coeff10 = ncquantreg( ...
        D, ...
        E, ...
        1, ...
        TAU10);


    a10 = ...
        coeff10(1);


    b10 = ...
        coeff10(2);


    %% ====================================================================
    % SMOOTH DURATION VECTOR
    %% ====================================================================

    Dmin = ...
        min(D);


    Dmax = ...
        max(D);


    Dfit = ...
        linspace(Dmin,Dmax,300)';


    %% ====================================================================
    % THRESHOLD LINES
    %% ====================================================================

    E20 = ...
        a20 + ...
        b20 .* Dfit;


    E10 = ...
        a10 + ...
        b10 .* Dfit;


    %% ====================================================================
    % TILE
    %% ====================================================================

    ax = ...
        nexttile(tl1,q);


    hold(ax,'on');


    %% --------------------------------------------------------------------
    % Antecedent rainfall
    %% --------------------------------------------------------------------

    hAP = scatter( ...
        ax, ...
        AP(:,2), ...
        AP(:,1), ...
        markerSize, ...
        'o', ...
        'MarkerFaceColor','none', ...
        'MarkerEdgeColor',antecedentColor, ...
        'LineWidth',1.3);


    %% --------------------------------------------------------------------
    % Triggering rainfall
    %% --------------------------------------------------------------------

    hTRIG = scatter( ...
        ax, ...
        TRIG(:,2), ...
        TRIG(:,1), ...
        markerSize, ...
        'o', ...
        'MarkerFaceColor','none', ...
        'MarkerEdgeColor',triggerColor, ...
        'LineWidth',1.5);


    %% --------------------------------------------------------------------
    % 20th percentile
    %% --------------------------------------------------------------------

    h20 = plot( ...
        ax, ...
        Dfit, ...
        E20, ...
        '-', ...
        'Color',line20Color, ...
        'LineWidth',lineWidth20);


    %% --------------------------------------------------------------------
    % 10th percentile
    %% --------------------------------------------------------------------

    h10 = plot( ...
        ax, ...
        Dfit, ...
        E10, ...
        '--', ...
        'Color',line10Color, ...
        'LineWidth',lineWidth10);


    %% ====================================================================
    % EQUATION
    %% ====================================================================

    if b20 >= 0

        equationText = sprintf( ...
            'E = %.2f + %.2fD', ...
            a20,b20);

    else

        equationText = sprintf( ...
            'E = %.2f - %.2fD', ...
            a20,abs(b20));

    end


    text( ...
        ax, ...
        0.04, ...
        0.94, ...
        equationText, ...
        'Units','normalized', ...
        'HorizontalAlignment','left', ...
        'VerticalAlignment','top', ...
        'FontSize',equationFont, ...
        'FontWeight','bold', ...
        'Color','k');


    %% ====================================================================
    % TITLE
    %% ====================================================================

    title( ...
        ax, ...
        station, ...
        'FontSize',titleFont, ...
        'FontWeight','bold', ...
        'Color','k');


    %% ====================================================================
    % AXIS FORMAT
    %% ====================================================================

    grid(ax,'on');


    set( ...
        ax, ...
        'FontSize',axisFont, ...
        'FontWeight','bold', ...
        'LineWidth',1.0, ...
        'TickDir','out', ...
        'TickLength',[0.018 0.018], ...
        'Box','on', ...
        'Layer','top', ...
        'XColor','k', ...
        'YColor','k');


    ax.GridAlpha = ...
        0.20;


    %% --------------------------------------------------------------------
    % Individual limits, same principle as original figure
    %% --------------------------------------------------------------------

    xmax = ...
        max(D);


    ymax = ...
        max([ ...
        E; ...
        E20(isfinite(E20) & E20 > 0); ...
        E10(isfinite(E10) & E10 > 0)]);


    if isempty(ymax) || ...
            ~isfinite(ymax)

        ymax = ...
            max(E);

    end


    xlim( ...
        ax, ...
        [0 max(1,1.05*xmax)]);


    ylim( ...
        ax, ...
        [0 max(1,1.10*ymax)]);


    %% --------------------------------------------------------------------
    % Store legend handles once
    %% --------------------------------------------------------------------

    if q == 1

        legendHandles1 = [ ...
            hAP; ...
            hTRIG; ...
            h20; ...
            h10];

    end


    hold(ax,'off');

end


%% ========================================================================
% SHARED AXIS LABELS
%% ========================================================================

xlabel( ...
    tl1, ...
    'Duration, D (days)', ...
    'FontSize',globalLabelFont, ...
    'FontWeight','bold', ...
    'Color','k');


ylabel( ...
    tl1, ...
    'Rainfall, E (mm)', ...
    'FontSize',globalLabelFont, ...
    'FontWeight','bold', ...
    'Color','k');


%% ========================================================================
% COMMON LEGEND
%% ========================================================================

lgd1 = legend( ...
    legendHandles1, ...
    {'Antecedent rainfall events', ...
     'Triggering rainfall events', ...
     '20th percentile', ...
     '10th percentile'}, ...
    'Orientation','horizontal', ...
    'FontSize',10.5, ...
    'Box','off');


lgd1.Layout.Tile = ...
    'south';


%% ========================================================================
% EXPORT LINEAR FIGURE
%% ========================================================================

linearPNG = fullfile( ...
    OUTPUT_FOLDER, ...
    'ED_Linear_Quantile_Thresholds_GT15.png');


linearTIF = fullfile( ...
    OUTPUT_FOLDER, ...
    'ED_Linear_Quantile_Thresholds_GT15.tiff');


linearFIG = fullfile( ...
    OUTPUT_FOLDER, ...
    'ED_Linear_Quantile_Thresholds_GT15.fig');


exportgraphics( ...
    fig1, ...
    linearPNG, ...
    'Resolution',600);


exportgraphics( ...
    fig1, ...
    linearTIF, ...
    'Resolution',600);


savefig( ...
    fig1, ...
    linearFIG);


%% ########################################################################
% ########################################################################
%
% FIGURE 2
%
% LOG-LOG POWER-LAW ED THRESHOLDS
%
%       log(E) = c + beta log(D)
%
% therefore
%
%       E = alpha D^beta
%
% ########################################################################
% ########################################################################

fig2 = figure( ...
    'Color','w', ...
    'Units','centimeters', ...
    'Position',[1 1 38 22], ...
    'Renderer','painters');


tl2 = tiledlayout( ...
    fig2, ...
    nRows, ...
    nCols, ...
    'TileSpacing','compact', ...
    'Padding','compact');


legendHandles2 = ...
    gobjects(4,1);


for q = 1:nPlot


    i = ...
        plotRows(q);


    station = ...
        string(Tlinear.Station(i));


    id = ...
        linear_ID(i);


    file_path = fullfile( ...
        INPUT_FOLDER, ...
        sprintf( ...
        '%s_triggering_output.xlsx', ...
        char(id)));


    %% ====================================================================
    % READ DATA
    %% ====================================================================

    AP = readmatrix( ...
        file_path, ...
        'Sheet','ap');


    TRIG = readmatrix( ...
        file_path, ...
        'Sheet','trigging');


    if isempty(AP)

        AP = ...
            zeros(0,2);

    end


    if isempty(TRIG)

        TRIG = ...
            zeros(0,2);

    end


    AP = ...
        AP(:,1:2);


    TRIG = ...
        TRIG(:,1:2);


    goodAP = ...
        isfinite(AP(:,1)) & ...
        isfinite(AP(:,2)) & ...
        AP(:,1) > 0 & ...
        AP(:,2) > 0;


    goodTRIG = ...
        isfinite(TRIG(:,1)) & ...
        isfinite(TRIG(:,2)) & ...
        TRIG(:,1) > 0 & ...
        TRIG(:,2) > 0;


    AP = ...
        AP(goodAP,:);


    TRIG = ...
        TRIG(goodTRIG,:);


    COMBINED = [ ...
        AP; ...
        TRIG];


    D = ...
        COMBINED(:,2);


    E = ...
        COMBINED(:,1);


    %% ====================================================================
    % FIND SAME STATION IN POWER-LAW WORKBOOK
    %% ====================================================================

    powerRow = find( ...
        power_ID == id, ...
        1);


    if isempty(powerRow)

        error( ...
            'Station %s not found in PowerLaw_loglog sheet.', ...
            id);

    end


    %% ====================================================================
    % EXACT 20TH-PERCENTILE COEFFICIENTS FROM WORKBOOK
    %% ====================================================================

    alpha20 = ...
        Tpower.Alpha_P20(powerRow);


    beta20 = ...
        Tpower.Beta_P20(powerRow);


    %% ====================================================================
    % 10TH-PERCENTILE POWER-LAW
    %
    % Quantile regression performed in log-log space:
    %
    % log(E) = c + beta log(D)
    %% ====================================================================

    logD = ...
        log(D);


    logE = ...
        log(E);


    coeff10power = ncquantreg( ...
        logD, ...
        logE, ...
        1, ...
        TAU10);


    c10 = ...
        coeff10power(1);


    beta10 = ...
        coeff10power(2);


    alpha10 = ...
        exp(c10);


    %% ====================================================================
    % DURATION VECTOR
    %
    % geomspace is appropriate for log axis
    %% ====================================================================

    Dmin = ...
        min(D);


    Dmax = ...
        max(D);


    if Dmin <= 0

        Dmin = ...
            min(D(D > 0));

    end


    Dfit = ...
        logspace( ...
        log10(Dmin), ...
        log10(Dmax), ...
        300)';


    %% ====================================================================
    % POWER-LAW THRESHOLDS
    %% ====================================================================

    E20 = ...
        alpha20 .* ...
        (Dfit .^ beta20);


    E10 = ...
        alpha10 .* ...
        (Dfit .^ beta10);


    %% ====================================================================
    % TILE
    %% ====================================================================

    ax = ...
        nexttile(tl2,q);


    hold(ax,'on');


    %% --------------------------------------------------------------------
    % Scatter points
    %% --------------------------------------------------------------------

    hAP = scatter( ...
        ax, ...
        AP(:,2), ...
        AP(:,1), ...
        markerSize, ...
        'o', ...
        'MarkerFaceColor','none', ...
        'MarkerEdgeColor',antecedentColor, ...
        'LineWidth',1.3);


    hTRIG = scatter( ...
        ax, ...
        TRIG(:,2), ...
        TRIG(:,1), ...
        markerSize, ...
        'o', ...
        'MarkerFaceColor','none', ...
        'MarkerEdgeColor',triggerColor, ...
        'LineWidth',1.5);


    %% --------------------------------------------------------------------
    % 20th percentile power law
    %% --------------------------------------------------------------------

    h20 = plot( ...
        ax, ...
        Dfit, ...
        E20, ...
        '-', ...
        'Color',line20Color, ...
        'LineWidth',lineWidth20);


    %% --------------------------------------------------------------------
    % 10th percentile power law
    %% --------------------------------------------------------------------

    h10 = plot( ...
        ax, ...
        Dfit, ...
        E10, ...
        '--', ...
        'Color',line10Color, ...
        'LineWidth',lineWidth10);


    %% ====================================================================
    % LOG-LOG AXES
    %% ====================================================================

    set( ...
        ax, ...
        'XScale','log', ...
        'YScale','log');


    %% ====================================================================
    % 20TH-PERCENTILE EQUATION
    %% ====================================================================

    equationText = sprintf( ...
        'E = %.2fD^{%.2f}', ...
        alpha20, ...
        beta20);


    text( ...
        ax, ...
        0.04, ...
        0.94, ...
        equationText, ...
        'Units','normalized', ...
        'HorizontalAlignment','left', ...
        'VerticalAlignment','top', ...
        'FontSize',equationFont, ...
        'FontWeight','bold', ...
        'Color','k');


    %% ====================================================================
    % TITLE
    %% ====================================================================

    title( ...
        ax, ...
        station, ...
        'FontSize',titleFont, ...
        'FontWeight','bold', ...
        'Color','k');


    %% ====================================================================
    % AXIS STYLE
    %% ====================================================================

    grid(ax,'on');


    set( ...
        ax, ...
        'FontSize',axisFont, ...
        'FontWeight','bold', ...
        'LineWidth',1.0, ...
        'TickDir','out', ...
        'TickLength',[0.018 0.018], ...
        'Box','on', ...
        'Layer','top', ...
        'XColor','k', ...
        'YColor','k');


    ax.GridAlpha = ...
        0.20;


    %% --------------------------------------------------------------------
    % Limits with multiplicative margin, appropriate for logarithmic axes
    %% --------------------------------------------------------------------

    xmin = ...
        min(D);


    xmax = ...
        max(D);


    ymin = ...
        min(E);


    ymax = ...
        max([ ...
        E; ...
        E20; ...
        E10]);


    xlim( ...
        ax, ...
        [max(xmin*0.85,0.1), ...
         xmax*1.15]);


    ylim( ...
        ax, ...
        [max(ymin*0.75,0.1), ...
         ymax*1.20]);


    %% --------------------------------------------------------------------
    % Legend handles once
    %% --------------------------------------------------------------------

    if q == 1

        legendHandles2 = [ ...
            hAP; ...
            hTRIG; ...
            h20; ...
            h10];

    end


    hold(ax,'off');

end


%% ========================================================================
% SHARED LOG-LOG FIGURE LABELS
%% ========================================================================

xlabel( ...
    tl2, ...
    'Duration, D (days)', ...
    'FontSize',globalLabelFont, ...
    'FontWeight','bold', ...
    'Color','k');


ylabel( ...
    tl2, ...
    'Rainfall, E (mm)', ...
    'FontSize',globalLabelFont, ...
    'FontWeight','bold', ...
    'Color','k');


%% ========================================================================
% COMMON LEGEND
%% ========================================================================

lgd2 = legend( ...
    legendHandles2, ...
    {'Antecedent rainfall events', ...
     'Triggering rainfall events', ...
     '20th percentile', ...
     '10th percentile'}, ...
    'Orientation','horizontal', ...
    'FontSize',10.5, ...
    'Box','off');


lgd2.Layout.Tile = ...
    'south';


%% ========================================================================
% EXPORT LOG-LOG POWER-LAW FIGURE
%% ========================================================================
% 
% powerPNG = fullfile( ...
%     OUTPUT_FOLDER, ...
%     'ED_PowerLaw_LogLog_Thresholds_GT15.png');
% 
% 
% powerTIF = fullfile( ...
%     OUTPUT_FOLDER, ...
%     'ED_PowerLaw_LogLog_Thresholds_GT15.tiff');
% 
% 
% powerFIG = fullfile( ...
%     OUTPUT_FOLDER, ...
%     'ED_PowerLaw_LogLog_Thresholds_GT15.fig');
% 
% 
% exportgraphics( ...
%     fig2, ...
%     powerPNG, ...
%     'Resolution',600);
% 
% 
% exportgraphics( ...
%     fig2, ...
%     powerTIF, ...
%     'Resolution',600);
% 
% 
% savefig( ...
%     fig2, ...
%     powerFIG);


%% ========================================================================
% FINAL MESSAGE
%% ========================================================================

fprintf('\n');
fprintf('=============================================================\n');
fprintf(' ED PLOTS COMPLETE\n');
fprintf('=============================================================\n');

fprintf( ...
    'Stations plotted (>15 triggering events): %d\n', ...
    nPlot);


fprintf('\nLinear ED figure:\n%s\n', ...
    linearPNG);


fprintf('\nLog-log power-law figure:\n%s\n', ...
    powerPNG);


fprintf('\nStation screening table:\n%s\n', ...
    screeningFile);


fprintf('\n=============================================================\n');