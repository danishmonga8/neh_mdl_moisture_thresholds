%% ========================================================================
% STEP 9
% UPDATED KENDALL'S TAU:
%
% API vs root-zone effective saturation
%
% Compares ONLY:
%
%   1) API(N*) vs S_eff[1]
%      S_eff one day before landslide/event date
%
%   2) API(N*) vs S_eff[0]
%      S_eff on landslide/event date
%
%
% UPDATED WORKFLOW
% -------------------------------------------------------------------------
%
% Study period:
%       2007-2021
%
% N*:
%       Taken from updated Step 7 independent lag-selection analysis
%
%       Step7_Optimal_Lag_Summary.xlsx
%
% API:
%       Fixed K = 0.90
%
%       API corresponds to independently selected station-specific N*
%
% Soil wetness:
%       Updated root-zone effective saturation S_eff
%
%
% REMOVED:
%
%       median S_eff[Topt]
%
%
% FINAL COMPARISONS:
%
%       Kendall tau [ API(N*), S_eff(t-1) ]
%
%       Kendall tau [ API(N*), S_eff(t) ]
%
%
% ERROR BARS:
%
%       Stations = +/- 0.5 SE (jackknife)
%
%       All      = +/- 1 SE (jackknife)
%
%
% ALL OUTPUTS ARE SAVED IN:
%
% C:\lews_2022-2024\3_new_stations_neh_new\
% revision_round1\
% step9_api_seff_lf_correlation_updated
%
% ========================================================================

clear;
clc;
close all;


%% ========================================================================
% 1. ROOT PATHS
%% ========================================================================

baseDir = ...
    fullfile(neh_root());


revDir = fullfile( ...
    baseDir, ...
    'revision_round1');


%% ========================================================================
% 2. STEP 9 OUTPUT FOLDER
%
% ALL FILES FROM THIS ANALYSIS WILL BE SAVED HERE
%% ========================================================================

outDir = fullfile( ...
    revDir, ...
    'step9_api_seff_lf_correlation_updated');


if ~exist(outDir,'dir')

    mkdir(outDir);

end


%% ========================================================================
% 3. UPDATED STEP 7 OPTIMAL N*
%% ========================================================================

lagXlsx = fullfile( ...
    revDir, ...
    'step7_lag_selection_updated', ...
    'Step7_Optimal_Lag_Summary.xlsx');


%% ========================================================================
% 4. UPDATED ROOT-ZONE EFFECTIVE SATURATION
%
% Expected filename:
%
%       42308_SMrz_Seff.txt
%
% Expected columns:
%
%       col 1 = Year
%       col 2 = Month
%       col 3 = Day
%       col 5 = S_eff
%
%% ========================================================================

satDir = fullfile( ...
    baseDir, ...
    '10_soil_moisture_extraction', ...
    'effective_saturation_time_series_all_stations', ...
    'effective_saturation_time_series_all_stations');


%% ========================================================================
% 5. UPDATED CROZIER / API ROOT
%
% Automatically checks both possible folder names:
%
%       step5_crozier_outputs
%
%       step_5_crozier_outputs
%
%% ========================================================================

criRoot1 = fullfile( ...
    revDir, ...
    'step5_crozier_outputs');


criRoot2 = fullfile( ...
    revDir, ...
    'step_5_crozier_outputs');


if exist(criRoot1,'dir')


    criRoot = ...
        criRoot1;


elseif exist(criRoot2,'dir')


    criRoot = ...
        criRoot2;


else


    error( ...
        ['Updated Crozier/API root folder was not found.' newline ...
         newline ...
         'Checked:' newline ...
         '%s' newline ...
         newline ...
         'and:' newline ...
         '%s'], ...
        criRoot1, ...
        criRoot2);


end


%% ========================================================================
% 6. EXCEL OUTPUT
%% ========================================================================

xlsOut = fullfile( ...
    outDir, ...
    'Step9_KendallTau_API_vs_Seff1_Seff0.xlsx');


%% ========================================================================
% 7. SETTINGS
%% ========================================================================

yr0 = ...
    2007;


yr1 = ...
    2021;


%% ------------------------------------------------------------------------
% Fixed API decay factor
%% ------------------------------------------------------------------------

Kvalue = ...
    0.90;


Ktag = ...
    '0p90';


%% ========================================================================
% 8. PLOT SETTINGS
%
% Formatting retained from previous figure
%% ========================================================================

ylimBars = ...
    [-1 1];


fontTick = ...
    16;


fontLabel = ...
    20;


xLabelRotate = ...
    32;


%% ------------------------------------------------------------------------
% Colours retained
%
% BLUE   = API vs S_eff[1]
%
% PURPLE = API vs S_eff[0]
%% ------------------------------------------------------------------------

colS1 = ...
    [0.15 0.45 0.85];


colS0 = ...
    [0.55 0.34 0.69];


edgeCol = ...
    0.2 * [1 1 1];


%% ========================================================================
% 9. VERIFY REQUIRED INPUTS
%% ========================================================================

if ~isfile(lagXlsx)


    error( ...
        'Updated Step 7 lag file not found:\n%s', ...
        lagXlsx);


end


if ~exist(satDir,'dir')


    error( ...
        'Updated S_eff directory not found:\n%s', ...
        satDir);


end


%% ========================================================================
% 10. DISPLAY CONFIGURATION
%% ========================================================================

fprintf('\n');
fprintf('=============================================================\n');
fprintf(' STEP 9: API vs ROOT-ZONE S_eff KENDALL TAU\n');
fprintf('=============================================================\n');


fprintf( ...
    'Study period : %d-%d\n', ...
    yr0, ...
    yr1);


fprintf( ...
    'API K        : %.2f\n', ...
    Kvalue);


fprintf('\nUpdated N* source:\n%s\n', ...
    lagXlsx);


fprintf('\nUpdated API root:\n%s\n', ...
    criRoot);


fprintf('\nUpdated S_eff root:\n%s\n', ...
    satDir);


fprintf('\nAll outputs will be saved in:\n%s\n', ...
    outDir);


fprintf('=============================================================\n\n');


%% ========================================================================
% 11. READ UPDATED STEP 7 N*
%% ========================================================================

T = readtable( ...
    lagXlsx, ...
    'Sheet','Optimal_N', ...
    'VariableNamingRule','preserve');


%% ========================================================================
% 12. CHECK REQUIRED COLUMNS
%% ========================================================================

requiredVariables = [ ...
    "Station", ...
    "IMD_ID", ...
    "Optimal_N_days"];


tableVariables = ...
    string(T.Properties.VariableNames);


for v = 1:numel(requiredVariables)


    if ~ismember( ...
            requiredVariables(v), ...
            tableVariables)


        error( ...
            'Required column missing from Step 7 file: %s', ...
            requiredVariables(v));


    end


end


%% ========================================================================
% 13. STANDARDIZE STATION NAMES
%% ========================================================================

stationName = ...
    strip(string(T.Station));


%% ========================================================================
% 14. STANDARDIZE IMD IDs
%% ========================================================================

if isnumeric(T.IMD_ID)


    IMD_ID = ...
        string( ...
        compose( ...
        '%.0f', ...
        T.IMD_ID));


else


    IMD_ID = ...
        strip( ...
        string(T.IMD_ID));


    IMD_ID = ...
        regexprep( ...
        IMD_ID, ...
        '\.0$', ...
        '');


end


%% ========================================================================
% 15. UPDATED INDEPENDENTLY SELECTED N*
%% ========================================================================

Ideal_lag = ...
    double(T.Optimal_N_days);


%% ------------------------------------------------------------------------
% Remove stations without valid N*
%% ------------------------------------------------------------------------

validLag = ...
    isfinite(Ideal_lag);


stationName = ...
    stationName(validLag);


IMD_ID = ...
    IMD_ID(validLag);


Ideal_lag = ...
    Ideal_lag(validLag);


nStations = ...
    numel(IMD_ID);


%% ========================================================================
% 16. STORAGE
%% ========================================================================

%% ------------------------------------------------------------------------
% API vs S_eff[0]
%% ------------------------------------------------------------------------

tauS0 = ...
    nan(nStations,1);


pS0 = ...
    nan(nStations,1);


ciS0 = ...
    nan(nStations,2);


nPairsS0 = ...
    zeros(nStations,1);


%% ------------------------------------------------------------------------
% API vs S_eff[1]
%% ------------------------------------------------------------------------

tauS1 = ...
    nan(nStations,1);


pS1 = ...
    nan(nStations,1);


ciS1 = ...
    nan(nStations,2);


nPairsS1 = ...
    zeros(nStations,1);


%% ------------------------------------------------------------------------
% Event pairs for pooled "All NEH"
%% ------------------------------------------------------------------------

pairsS0_X = ...
    cell(nStations,1);


pairsS0_Y = ...
    cell(nStations,1);


pairsS1_X = ...
    cell(nStations,1);


pairsS1_Y = ...
    cell(nStations,1);


%% ------------------------------------------------------------------------
% Processing status
%% ------------------------------------------------------------------------

Status = ...
    strings(nStations,1);


%% ========================================================================
% 17. MAIN STATION LOOP
%% ========================================================================

for s = 1:nStations


    station = ...
        stationName(s);


    stnStr = ...
        char(IMD_ID(s));


    lagYY = ...
        round(Ideal_lag(s));


    fprintf('\n');
    fprintf('-------------------------------------------------------------\n');


    fprintf( ...
        'Station: %s (%s) | N* = %d days\n', ...
        station, ...
        stnStr, ...
        lagYY);


    fprintf('-------------------------------------------------------------\n');


    %% ====================================================================
    % 17A. UPDATED DAILY S_eff FILE
    %% ====================================================================

    satFile = fullfile( ...
        satDir, ...
        sprintf( ...
        '%s_SMrz_Seff.txt', ...
        stnStr));


    if ~isfile(satFile)


        fprintf( ...
            '[WARN] S_eff file missing:\n%s\n', ...
            satFile);


        Status(s) = ...
            "S_eff file missing";


        continue


    end


    %% --------------------------------------------------------------------
    % Read S_eff
    %% --------------------------------------------------------------------

    S = readmatrix( ...
        satFile, ...
        'FileType','text');


    %% --------------------------------------------------------------------
    % Required:
    %
    % col 1 = year
    % col 2 = month
    % col 3 = day
    % col 5 = S_eff
    %% --------------------------------------------------------------------

    if isempty(S) || ...
            size(S,2) < 5


        fprintf( ...
            '[WARN] Invalid S_eff file.\n');


        Status(s) = ...
            "Invalid S_eff file";


        continue


    end


    %% --------------------------------------------------------------------
    % Remove invalid rows
    %% --------------------------------------------------------------------

    goodS = ...
        isfinite(S(:,1)) & ...
        isfinite(S(:,2)) & ...
        isfinite(S(:,3)) & ...
        isfinite(S(:,5));


    S = ...
        S(goodS,:);


    if isempty(S)


        fprintf( ...
            '[WARN] No valid S_eff data.\n');


        Status(s) = ...
            "No valid S_eff data";


        continue


    end


    %% ====================================================================
    % CREATE DAILY S_eff DATE SERIES
    %% ====================================================================

    SeffDate = datetime( ...
        S(:,1), ...
        S(:,2), ...
        S(:,3));


    Seff = ...
        double(S(:,5));


    %% ====================================================================
    % 17B. UPDATED API FILE
    %
    % Expected structure:
    %
    % revision_round1
    %   step5_crozier_outputs
    %       K_0p90
    %           03_day
    %               42308_03d_crozier_K0p90.txt
    %
    %
    % API file:
    %
    %       col 1 = year
    %       col 2 = month
    %       col 3 = day
    %       col 4 = API
    %
    %% ====================================================================

    lagFolder = fullfile( ...
        criRoot, ...
        ['K_' Ktag], ...
        sprintf( ...
        '%02d_day', ...
        lagYY));


    criFile = fullfile( ...
        lagFolder, ...
        sprintf( ...
        '%s_%02dd_crozier_K%s.txt', ...
        stnStr, ...
        lagYY, ...
        Ktag));


    %% ====================================================================
    % FALLBACK:
    %
    % Check lag folder without leading zero
    %
    % Example:
    %
    %       3_day
    %
    % instead of:
    %
    %       03_day
    %% ====================================================================

    if ~isfile(criFile)


        lagFolder2 = fullfile( ...
            criRoot, ...
            ['K_' Ktag], ...
            sprintf( ...
            '%d_day', ...
            lagYY));


        criFile2 = fullfile( ...
            lagFolder2, ...
            sprintf( ...
            '%s_%02dd_crozier_K%s.txt', ...
            stnStr, ...
            lagYY, ...
            Ktag));


        if isfile(criFile2)


            criFile = ...
                criFile2;


        end


    end


    %% ====================================================================
    % API FILE CHECK
    %% ====================================================================

    if ~isfile(criFile)


        fprintf( ...
            '[WARN] API file missing.\n');


        fprintf( ...
            'Checked:\n%s\n', ...
            criFile);


        Status(s) = ...
            "API file missing";


        continue


    end


    %% ====================================================================
    % READ UPDATED API
    %% ====================================================================

    C = readmatrix( ...
        criFile, ...
        'FileType','text');


    if isempty(C) || ...
            size(C,2) < 4


        fprintf( ...
            '[WARN] Invalid API file.\n');


        Status(s) = ...
            "Invalid API file";


        continue


    end


    %% --------------------------------------------------------------------
    % Remove invalid API rows
    %% --------------------------------------------------------------------

    goodC = ...
        isfinite(C(:,1)) & ...
        isfinite(C(:,2)) & ...
        isfinite(C(:,3)) & ...
        isfinite(C(:,4));


    C = ...
        C(goodC,:);


    if isempty(C)


        fprintf( ...
            '[WARN] No valid API data.\n');


        Status(s) = ...
            "No valid API data";


        continue


    end


    %% ====================================================================
    % API EVENT DATES
    %% ====================================================================

    APIDate = datetime( ...
        C(:,1), ...
        C(:,2), ...
        C(:,3));


    API = ...
        double(C(:,4));


    %% ====================================================================
    % RESTRICT TO UPDATED STUDY PERIOD
    %% ====================================================================

    keepAPI = ...
        year(APIDate) >= yr0 & ...
        year(APIDate) <= yr1;


    APIDate = ...
        APIDate(keepAPI);


    API = ...
        API(keepAPI);


    if isempty(API)


        fprintf( ...
            '[WARN] No API events during %d-%d.\n', ...
            yr0, ...
            yr1);


        Status(s) = ...
            "No events in study period";


        continue


    end


    %% ====================================================================
    % COLLAPSE DUPLICATE DATES WITHIN STATION
    %
    % If multiple API records correspond to the same event date:
    %
    %       use median API
    %
    %% ====================================================================

    [uniqueDates,~,dateGroup] = ...
        unique(APIDate);


    APIunique = ...
        nan(numel(uniqueDates),1);


    for uu = 1:numel(uniqueDates)


        APIunique(uu) = median( ...
            API(dateGroup == uu), ...
            'omitnan');


    end


    APIDate = ...
        uniqueDates;


    API = ...
        APIunique;


    %% ====================================================================
    % 17C. EVENT-WISE PAIRS
    %
    % For event / landslide date t:
    %
    %       S_eff[0] = S_eff(t)
    %
    %       S_eff[1] = S_eff(t-1)
    %
    %% ====================================================================

    API_evt_S0 = ...
        [];


    API_evt_S1 = ...
        [];


    S0_evt = ...
        [];


    S1_evt = ...
        [];


    %% ====================================================================
    % MATCH API EVENT DATE WITH S_eff
    %% ====================================================================

    for r = 1:numel(APIDate)


        eventDate = ...
            APIDate(r);


        aUse = ...
            API(r);


        %% ----------------------------------------------------------------
        % S_eff[0]:
        %
        % effective saturation on event / landslide day
        %% ----------------------------------------------------------------

        idxS0 = ...
            SeffDate == eventDate;


        %% ----------------------------------------------------------------
        % S_eff[1]:
        %
        % effective saturation one day before event / landslide
        %% ----------------------------------------------------------------

        idxS1 = ...
            SeffDate == ...
            (eventDate - days(1));


        %% ================================================================
        % API vs S_eff[0]
        %% ================================================================

        if any(idxS0)


            s0Use = median( ...
                Seff(idxS0), ...
                'omitnan');


            if isfinite(aUse) && ...
                    isfinite(s0Use)


                API_evt_S0(end+1,1) = ...
                    aUse; %#ok<AGROW>


                S0_evt(end+1,1) = ...
                    s0Use; %#ok<AGROW>


            end


        end


        %% ================================================================
        % API vs S_eff[1]
        %% ================================================================

        if any(idxS1)


            s1Use = median( ...
                Seff(idxS1), ...
                'omitnan');


            if isfinite(aUse) && ...
                    isfinite(s1Use)


                API_evt_S1(end+1,1) = ...
                    aUse; %#ok<AGROW>


                S1_evt(end+1,1) = ...
                    s1Use; %#ok<AGROW>


            end


        end


    end


    %% ====================================================================
    % 17D. KENDALL TAU:
    %
    % API vs S_eff[0]
    %% ====================================================================

    if numel(API_evt_S0) >= 2


        [tauS0(s),pS0(s)] = corr( ...
            API_evt_S0, ...
            S0_evt, ...
            'Type','Kendall', ...
            'Rows','complete');


        nPairsS0(s) = ...
            numel(API_evt_S0);


        pairsS0_X{s} = ...
            API_evt_S0;


        pairsS0_Y{s} = ...
            S0_evt;


        %% ----------------------------------------------------------------
        % Jackknife standard error
        %% ----------------------------------------------------------------

        if nPairsS0(s) >= 3


            se = ...
                jackknife_se_kendall( ...
                API_evt_S0, ...
                S0_evt);


            %% -------------------------------------------------------------
            % Station error bar:
            %
            % +/- 0.5 SE
            %% -------------------------------------------------------------

            half = ...
                0.5 * se;


            ciS0(s,:) = ...
                clamp_to_unit( ...
                [ ...
                tauS0(s)-half, ...
                tauS0(s)+half ...
                ]);


        end


    end


    %% ====================================================================
    % 17E. KENDALL TAU:
    %
    % API vs S_eff[1]
    %% ====================================================================

    if numel(API_evt_S1) >= 2


        [tauS1(s),pS1(s)] = corr( ...
            API_evt_S1, ...
            S1_evt, ...
            'Type','Kendall', ...
            'Rows','complete');


        nPairsS1(s) = ...
            numel(API_evt_S1);


        pairsS1_X{s} = ...
            API_evt_S1;


        pairsS1_Y{s} = ...
            S1_evt;


        %% ----------------------------------------------------------------
        % Jackknife standard error
        %% ----------------------------------------------------------------

        if nPairsS1(s) >= 3


            se = ...
                jackknife_se_kendall( ...
                API_evt_S1, ...
                S1_evt);


            %% -------------------------------------------------------------
            % Station error bar:
            %
            % +/- 0.5 SE
            %% -------------------------------------------------------------

            half = ...
                0.5 * se;


            ciS1(s,:) = ...
                clamp_to_unit( ...
                [ ...
                tauS1(s)-half, ...
                tauS1(s)+half ...
                ]);


        end


    end


    %% ====================================================================
    % STATUS
    %% ====================================================================

    Status(s) = ...
        "OK";


    fprintf( ...
        'API vs S_eff[1]: n = %d | tau = %+.3f | p = %.4f\n', ...
        nPairsS1(s), ...
        tauS1(s), ...
        pS1(s));


    fprintf( ...
        'API vs S_eff[0]: n = %d | tau = %+.3f | p = %.4f\n', ...
        nPairsS0(s), ...
        tauS0(s), ...
        pS0(s));


end


%% ========================================================================
% 18. "ALL NEH" POOLED ANALYSIS
%% ========================================================================

useMask = ...
    true(nStations,1);


%% ------------------------------------------------------------------------
% Pool API vs S_eff[1]
%% ------------------------------------------------------------------------

[xAllS1,yAllS1] = pool_pairs( ...
    pairsS1_X, ...
    pairsS1_Y, ...
    useMask);


%% ------------------------------------------------------------------------
% Pool API vs S_eff[0]
%% ------------------------------------------------------------------------

[xAllS0,yAllS0] = pool_pairs( ...
    pairsS0_X, ...
    pairsS0_Y, ...
    useMask);


%% ========================================================================
% POOLED KENDALL TAU
%
% All NEH error bar:
%
%       +/- 1 SE
%% ========================================================================

[tauS1_all,ciS1_all,pS1_all] = ...
    tau_and_SE( ...
    xAllS1, ...
    yAllS1, ...
    1);


[tauS0_all,ciS0_all,pS0_all] = ...
    tau_and_SE( ...
    xAllS0, ...
    yAllS0, ...
    1);


%% ========================================================================
% 19. PREPARE PLOT DATA
%% ========================================================================

labelsUse = ...
    stationName(useMask);


labelsPlot = [ ...
    "All"; ...
    labelsUse];


%% ------------------------------------------------------------------------
% Kendall tau
%% ------------------------------------------------------------------------

tauS1_plot = [ ...
    tauS1_all; ...
    tauS1(useMask)];


tauS0_plot = [ ...
    tauS0_all; ...
    tauS0(useMask)];


%% ------------------------------------------------------------------------
% Error intervals
%% ------------------------------------------------------------------------

ciS1_plot = [ ...
    ciS1_all; ...
    ciS1(useMask,:)];


ciS0_plot = [ ...
    ciS0_all; ...
    ciS0(useMask,:)];


%% ------------------------------------------------------------------------
% p values
%% ------------------------------------------------------------------------

pS1_plot = [ ...
    pS1_all; ...
    pS1(useMask)];


pS0_plot = [ ...
    pS0_all; ...
    pS0(useMask)];


%% ------------------------------------------------------------------------
% number of event pairs
%% ------------------------------------------------------------------------

nS1_plot = [ ...
    numel(xAllS1); ...
    nPairsS1(useMask)];


nS0_plot = [ ...
    numel(xAllS0); ...
    nPairsS0(useMask)];


%% ------------------------------------------------------------------------
% N* for output table
%
% "All" has no single N*, therefore NaN
%% ------------------------------------------------------------------------

Nstar_plot = [ ...
    NaN; ...
    Ideal_lag(useMask)];


%% ========================================================================
% 20. GROUPED BAR PLOT
%
% EXACTLY TWO BARS:
%
%       BLUE   = API vs S_eff[1]
%
%       PURPLE = API vs S_eff[0]
%
%% ========================================================================

errLabel = ...
    '\pm0.5 SE (stations), \pm1 SE (All)';


if ~isempty(labelsPlot)


    nStnPlot = ...
        numel(labelsPlot);


    x = ...
        1:nStnPlot;


    %% --------------------------------------------------------------------
    % TWO-BAR MATRIX
    %% --------------------------------------------------------------------

    Y = [ ...
        tauS1_plot, ...
        tauS0_plot];


    %% ====================================================================
    % FIGURE
    %% ====================================================================

    figure( ...
        'Color','w', ...
        'Position',[100 100 1600 700]);


    hold on;


    %% ====================================================================
    % GROUPED BARS
    %% ====================================================================

    b = bar( ...
        x, ...
        Y, ...
        'grouped');


    %% --------------------------------------------------------------------
    % S_eff[1]
    %% --------------------------------------------------------------------

    b(1).FaceColor = ...
        colS1;


    b(1).EdgeColor = ...
        edgeCol;


    %% --------------------------------------------------------------------
    % S_eff[0]
    %% --------------------------------------------------------------------

    b(2).FaceColor = ...
        colS0;


    b(2).EdgeColor = ...
        edgeCol;


    %% ====================================================================
    % 21. ERROR BARS
    %% ====================================================================

    CI = cat( ...
        3, ...
        ciS1_plot, ...
        ciS0_plot);


    for j = 1:2


        xj = ...
            b(j).XEndPoints;


        yj = ...
            Y(:,j);


        lower = ...
            yj - ...
            CI(:,1,j);


        upper = ...
            CI(:,2,j) - ...
            yj;


        errorbar( ...
            xj, ...
            yj, ...
            lower, ...
            upper, ...
            'k', ...
            'linestyle','none', ...
            'LineWidth',1);


    end


    %% ====================================================================
    % 22. SIGNIFICANCE STARS
    %
    % ** = p <= 0.05
    %
    % *  = 0.05 < p <= 0.10
    %% ====================================================================

    Pmat = [ ...
        pS1_plot, ...
        pS0_plot];


    for j = 1:2


        xj = ...
            b(j).XEndPoints;


        yj = ...
            Y(:,j);


        upper = ...
            CI(:,2,j) - ...
            yj;


        for i = 1:nStnPlot


            pval = ...
                Pmat(i,j);


            if isnan(pval)


                continue


            end


            if pval <= 0.05


                stars = ...
                    '**';


            elseif pval <= 0.10


                stars = ...
                    '*';


            else


                continue


            end


            %% -------------------------------------------------------------
            % Position star
            %% -------------------------------------------------------------

            y_top = ...
                yj(i) + ...
                upper(i);


            if y_top >= 0


                y_star = ...
                    y_top + 0.05;


            else


                y_star = ...
                    y_top - 0.05;


            end


            text( ...
                xj(i), ...
                y_star, ...
                stars, ...
                'HorizontalAlignment','center', ...
                'VerticalAlignment','middle', ...
                'FontSize',10, ...
                'FontWeight','bold');


        end


    end


    %% ====================================================================
    % 23. AXIS FORMATTING
    %% ====================================================================

    xlim( ...
        [ ...
        0.5, ...
        nStnPlot + 0.5 ...
        ]);


    ylim( ...
        ylimBars);


    set( ...
        gca, ...
        'XTick',x, ...
        'XTickLabel',labelsPlot, ...
        'FontName','Arial', ...
        'FontSize',fontTick);


    xtickangle( ...
        xLabelRotate);


    %% ====================================================================
    % Y LABEL
    %% ====================================================================

    ylabel( ...
        'Kendall''s \tau (API vs S_{eff})', ...
        'FontName','Arial', ...
        'FontSize',fontLabel, ...
        'Interpreter','tex');


    %% ====================================================================
    % 24. LEGEND
    %% ====================================================================

    legend( ...
        { ...
        'API vs S_{eff}[1]', ...
        'API vs S_{eff}[0]' ...
        }, ...
        'Location','southoutside', ...
        'Orientation','horizontal', ...
        'Box','on', ...
        'Interpreter','tex');


    %% ====================================================================
    % 25. ERROR-BAR DESCRIPTION
    %% ====================================================================

    text( ...
        0.5, ...
        ylimBars(2)-0.05, ...
        errLabel, ...
        'Units','data', ...
        'FontSize',10, ...
        'Interpreter','tex');


    %% ====================================================================
    % FIGURE SPACING
    %% ====================================================================

    set( ...
        gca, ...
        'LooseInset', ...
        max( ...
        get(gca,'TightInset'), ...
        0.02*[1 1 1 1]));


    %% ====================================================================
    % 26. SAVE FIGURES IN STEP 9 FOLDER
    %% ====================================================================

    outBase = fullfile( ...
        outDir, ...
        'Step9_NEH_API_vs_Seff1_Seff0_KendallTau');


    %% --------------------------------------------------------------------
    % TIFF
    %% --------------------------------------------------------------------

    print( ...
        gcf, ...
        [outBase '.tif'], ...
        '-dtiff', ...
        '-r300');


    %% --------------------------------------------------------------------
    % PNG
    %% --------------------------------------------------------------------

    print( ...
        gcf, ...
        [outBase '.png'], ...
        '-dpng', ...
        '-r300');


    %% --------------------------------------------------------------------
    % MATLAB editable figure
    %% --------------------------------------------------------------------

    savefig( ...
        gcf, ...
        [outBase '.fig']);


end


%% ========================================================================
% 27. OUTPUT TABLE
%% ========================================================================

TauTable = table( ...
    labelsPlot, ...
    Nstar_plot, ...
    nS1_plot, ...
    tauS1_plot, ...
    pS1_plot, ...
    nS0_plot, ...
    tauS0_plot, ...
    pS0_plot, ...
    'VariableNames',{ ...
    'Station', ...
    'Nstar_days', ...
    'N_API_Seff1', ...
    'Tau_API_Seff1', ...
    'p_API_Seff1', ...
    'N_API_Seff0', ...
    'Tau_API_Seff0', ...
    'p_API_Seff0'});


%% ========================================================================
% DISPLAY RESULTS
%% ========================================================================

disp(' ');


disp( ...
    '=============================================================');


disp( ...
    'Kendall tau: API vs S_eff[1] and S_eff[0]');


disp( ...
    '=============================================================');


disp( ...
    TauTable);


%% ========================================================================
% 28. PROCESSING STATUS TABLE
%% ========================================================================

StatusTable = table( ...
    stationName, ...
    IMD_ID, ...
    Ideal_lag, ...
    nPairsS1, ...
    nPairsS0, ...
    Status, ...
    'VariableNames',{ ...
    'Station', ...
    'IMD_ID', ...
    'Nstar_days', ...
    'N_API_Seff1', ...
    'N_API_Seff0', ...
    'Status'});


%% ========================================================================
% 29. WRITE EXCEL OUTPUT
%% ========================================================================

if isfile(xlsOut)


    delete(xlsOut);


end


%% ------------------------------------------------------------------------
% Main results
%% ------------------------------------------------------------------------

writetable( ...
    TauTable, ...
    xlsOut, ...
    'Sheet','Tau_p_API_Seff1_Seff0');


%% ------------------------------------------------------------------------
% Processing status
%% ------------------------------------------------------------------------

writetable( ...
    StatusTable, ...
    xlsOut, ...
    'Sheet','Processing_Status');


%% ========================================================================
% 30. SAVE ANALYSIS SETTINGS
%% ========================================================================

SettingsTable = table( ...
    yr0, ...
    yr1, ...
    Kvalue, ...
    string(lagXlsx), ...
    string(criRoot), ...
    string(satDir), ...
    'VariableNames',{ ...
    'Study_Start_Year', ...
    'Study_End_Year', ...
    'API_K', ...
    'Nstar_Source', ...
    'API_Source', ...
    'Seff_Source'});


writetable( ...
    SettingsTable, ...
    xlsOut, ...
    'Sheet','Analysis_Settings');


%% ========================================================================
% 31. COMPLETE
%% ========================================================================

fprintf('\n');
fprintf('=============================================================\n');
fprintf(' STEP 9 ANALYSIS COMPLETE\n');
fprintf('=============================================================\n');


fprintf( ...
    'Study period : %d-%d\n', ...
    yr0, ...
    yr1);


fprintf( ...
    'API K        : %.2f\n', ...
    Kvalue);


fprintf('\nComparisons:\n');


fprintf( ...
    '1. API(N*) vs S_eff[1]\n');


fprintf( ...
    '2. API(N*) vs S_eff[0]\n');


fprintf('\n');


fprintf( ...
    'median S_eff[Topt] was NOT used.\n');


fprintf('\nAll files saved in:\n%s\n', ...
    outDir);


fprintf('\nExcel output:\n%s\n', ...
    xlsOut);


fprintf('\nFigure files:\n');


fprintf( ...
    '%s\n', ...
    [outBase '.png']);


fprintf( ...
    '%s\n', ...
    [outBase '.tif']);


fprintf( ...
    '%s\n', ...
    [outBase '.fig']);


fprintf('=============================================================\n');

