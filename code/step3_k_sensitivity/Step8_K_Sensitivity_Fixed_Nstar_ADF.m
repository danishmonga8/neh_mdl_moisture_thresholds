%% ========================================================================
% Step8_K_Sensitivity_Fixed_Nstar_ADF.m
%
% REVIEWER 2 - COMMENT 11
%
% "Report ADF at a fixed lag, and test K."
%
% PURPOSE
% -------------------------------------------------------------------------
% For every station:
%
%   1. Read the independently selected optimal lag N* from Step 7.
%
%   2. HOLD N* FIXED for that station.
%
%   3. Vary only the Crozier/API decay factor K:
%
%          K = 0.80, 0.82, 0.84, ..., 0.98
%
%   4. For each K, read API calculated at that SAME fixed N*.
%
%   5. Match API with updated triggering rainfall (TR).
%
%   6. Normalize API and TR using the SAME empirical normalization
%      previously used:
%
%          tiedrank(X)/(n+1)
%
%   7. Calculate:
%
%          ADF = fraction of events where
%                normalized API > normalized TR
%
%   8. Quantify K sensitivity:
%
%          Delta ADF = max(ADF across K) - min(ADF across K)
%
%
% IMPORTANT
% -------------------------------------------------------------------------
% N* IS NOT re-selected for each K.
%
% K changes.
% N* remains fixed.
%
% ADF is interpreted as a DEPENDENCE / relative antecedent-rainfall
% contribution indicator and NOT as causal attribution.
%
%
% INPUTS
% -------------------------------------------------------------------------
% Updated optimal N*:
%
%   step7_lag_selection_updated\
%       Step7_Optimal_Lag_Summary.xlsx
%
% Updated API:
%
%   step5_crozier_outputs\K_0p80\...
%              OR
%   step_5_crozier_outputs\K_0p80\...
%
% Updated triggering rainfall:
%
%   step6_trigging_events\
%       step_6_triggering_event_characteristics_20km_ALLOW_OVERLAP\
%
%
% OUTPUTS
% -------------------------------------------------------------------------
% Step8_K_Sensitivity_Fixed_Nstar_ADF.xlsx
%
%   Sheets:
%       Station_summary
%       ADF_matrix
%       Event_count
%       API_GT_TR_count
%       TR_GT_API_count
%       Equal_count
%       Status
%       Event_level
%
% Figures:
%
%       Step8_ADF_K_Sensitivity_Heatmap.png
%       Step8_ADF_K_Sensitivity_Heatmap.tiff
%       Step8_ADF_K_Sensitivity_Heatmap.fig
%
%       Step8_DeltaADF_by_Station.png
%
% ========================================================================

clc;
clear;
close all;


%% ========================================================================
% 1. ROOT
%% ========================================================================

ROOT = ...
    fullfile(neh_root());


%% ========================================================================
% 2. UPDATED N* FILE
%% ========================================================================

LAG_FILE = fullfile( ...
    ROOT, ...
    'step7_lag_selection_updated', ...
    'Step7_Optimal_Lag_Summary.xlsx');


%% ========================================================================
% 3. UPDATED TRIGGERING EVENT DIRECTORY
%% ========================================================================

TRIGGER_DIR = fullfile( ...
    ROOT, ...
    'step6_trigging_events', ...
    'step_6_triggering_event_characteristics_20km_ALLOW_OVERLAP');


%% ========================================================================
% 4. API ROOT
%
% Automatically checks both folder naming conventions because both have
% appeared during the revision workflow.
%% ========================================================================

API_ROOT_1 = fullfile( ...
    ROOT, ...
    'step5_crozier_outputs');


API_ROOT_2 = fullfile( ...
    ROOT, ...
    'step_5_crozier_outputs');


if exist(API_ROOT_1,'dir')

    API_ROOT = API_ROOT_1;

elseif exist(API_ROOT_2,'dir')

    API_ROOT = API_ROOT_2;

else

    error( ...
        ['Crozier/API root folder not found.' newline ...
         newline ...
         'Checked:' newline ...
         '%s' newline ...
         newline ...
         'and:' newline ...
         '%s'], ...
        API_ROOT_1, ...
        API_ROOT_2);

end


%% ========================================================================
% 5. OUTPUT
%% ========================================================================

OUT_DIR = fullfile( ...
    ROOT, ...
    'step7_lag_selection_updated', ...
    'K_sensitivity_fixed_Nstar');


if ~exist(OUT_DIR,'dir')

    mkdir(OUT_DIR);

end


%% ========================================================================
% 6. CONFIGURATION
%% ========================================================================

K_VALUES = ...
    0.80 : 0.02 : 0.98;


K_VALUES = ...
    round(K_VALUES,2);


nK = ...
    numel(K_VALUES);


YR_START = ...
    2007;


YR_END = ...
    2021;


% Same numerical tolerance as previous API-TR analysis
EQ_TOL = ...
    1e-12;


% Reference K used for original/primary analysis
REFERENCE_K = ...
    0.90;


fprintf('\n');
fprintf('=============================================================\n');
fprintf(' FIXED-N* K-SENSITIVITY ANALYSIS\n');
fprintf('=============================================================\n');

fprintf('Landslide radius       : 20 km\n');
fprintf('Station overlap        : retained\n');
fprintf('Catalogue duplicates   : previously removed\n');

fprintf( ...
    'Study period           : %d-%d\n', ...
    YR_START,YR_END);


fprintf('K values               : ');

fprintf('%.2f ',K_VALUES);

fprintf('\n');


fprintf( ...
    'Reference K            : %.2f\n', ...
    REFERENCE_K);


fprintf('\nAPI root:\n%s\n', ...
    API_ROOT);


fprintf('\nTrigger directory:\n%s\n', ...
    TRIGGER_DIR);


fprintf('\nOutput directory:\n%s\n', ...
    OUT_DIR);


fprintf('=============================================================\n\n');


%% ========================================================================
% 7. CHECK INPUTS
%% ========================================================================

if ~isfile(LAG_FILE)

    error( ...
        'Updated optimal-lag file not found:\n%s', ...
        LAG_FILE);

end


if ~exist(TRIGGER_DIR,'dir')

    error( ...
        'Updated triggering-event folder not found:\n%s', ...
        TRIGGER_DIR);

end


%% ========================================================================
% 8. READ UPDATED OPTIMAL N*
%% ========================================================================

Lag = readtable( ...
    LAG_FILE, ...
    'Sheet','Optimal_N', ...
    'VariableNamingRule','preserve');


lagVars = ...
    string(Lag.Properties.VariableNames);


requiredVars = [ ...
    "Station", ...
    "IMD_ID", ...
    "Optimal_N_days"];


for v = 1:numel(requiredVars)

    if ~ismember(requiredVars(v),lagVars)

        error( ...
            'Missing variable in Step 7 lag file: %s', ...
            requiredVars(v));

    end

end


%% ------------------------------------------------------------------------
% Station name
%% ------------------------------------------------------------------------

Lag.Station = ...
    strip(string(Lag.Station));


%% ------------------------------------------------------------------------
% IMD ID
%% ------------------------------------------------------------------------

if isnumeric(Lag.IMD_ID)

    Lag.IMD_ID = ...
        string(compose('%.0f',Lag.IMD_ID));

else

    Lag.IMD_ID = ...
        strip(string(Lag.IMD_ID));


    Lag.IMD_ID = ...
        regexprep( ...
        Lag.IMD_ID, ...
        '\.0$', ...
        '');

end


%% ------------------------------------------------------------------------
% N*
%% ------------------------------------------------------------------------

Lag.Optimal_N_days = ...
    double(Lag.Optimal_N_days);


%% ------------------------------------------------------------------------
% Only valid N*
%% ------------------------------------------------------------------------

Lag = ...
    Lag(isfinite(Lag.Optimal_N_days),:);


%% ========================================================================
% 9. SORT STATIONS BY FIXED N*
%
% Same presentation principle as the lag-selection heatmap:
%
%     ascending selected lag
%     then station name
%% ========================================================================

Lag = sortrows( ...
    Lag, ...
    {'Optimal_N_days','Station'}, ...
    {'ascend','ascend'});


nStations = ...
    height(Lag);


fprintf( ...
    'Stations with valid fixed N*: %d\n\n', ...
    nStations);


%% ========================================================================
% 10. PREALLOCATE K-SENSITIVITY MATRICES
%% ========================================================================

ADF = ...
    nan(nStations,nK);


NEVENT = ...
    nan(nStations,nK);


API_GT_TR_COUNT = ...
    nan(nStations,nK);


TR_GT_API_COUNT = ...
    nan(nStations,nK);


EQUAL_COUNT = ...
    nan(nStations,nK);


STATUS = ...
    strings(nStations,nK);


%% ------------------------------------------------------------------------
% Event-level audit
%% ------------------------------------------------------------------------

EventTable = ...
    table();


%% ========================================================================
% 11. STATION LOOP
%% ========================================================================

for i = 1:nStations


    station = ...
        Lag.Station(i);


    id = ...
        Lag.IMD_ID(i);


    Nstar = ...
        round(Lag.Optimal_N_days(i));


    fprintf('\n');
    fprintf('=============================================================\n');

    fprintf( ...
        '%s (%s) | FIXED N* = %d d\n', ...
        station,id,Nstar);

    fprintf('=============================================================\n');


    %% ====================================================================
    % 11A. UPDATED TRIGGERING RAINFALL
    %% ====================================================================

    triggerFile = fullfile( ...
        TRIGGER_DIR, ...
        sprintf( ...
        '%s_trigging.txt', ...
        char(id)));


    if ~isfile(triggerFile)


        warning( ...
            'Trigger file missing: %s', ...
            triggerFile);


        STATUS(i,:) = ...
            "Trigger file missing";


        continue

    end


    TRdata = readmatrix( ...
        triggerFile, ...
        'FileType','text');


    if isempty(TRdata) || ...
            size(TRdata,2) < 4


        warning( ...
            'Invalid trigger file for %s.', ...
            station);


        STATUS(i,:) = ...
            "Invalid trigger file";


        continue

    end


    %% --------------------------------------------------------------------
    % Valid rows
    %% --------------------------------------------------------------------

    goodTR = ...
        isfinite(TRdata(:,1)) & ...
        isfinite(TRdata(:,2)) & ...
        isfinite(TRdata(:,3)) & ...
        isfinite(TRdata(:,4));


    TRdata = ...
        TRdata(goodTR,:);


    if isempty(TRdata)


        STATUS(i,:) = ...
            "No valid triggering events";


        continue

    end


    %% --------------------------------------------------------------------
    % Event date and triggering rainfall
    %% --------------------------------------------------------------------

    TRdate = datetime( ...
        TRdata(:,1), ...
        TRdata(:,2), ...
        TRdata(:,3));


    TR = ...
        TRdata(:,4);


    %% --------------------------------------------------------------------
    % Study period
    %% --------------------------------------------------------------------

    keepTR = ...
        year(TRdate) >= YR_START & ...
        year(TRdate) <= YR_END;


    TRdate = ...
        TRdate(keepTR);


    TR = ...
        TR(keepTR);


    if isempty(TRdate)


        STATUS(i,:) = ...
            "No TR events in period";


        continue

    end


    %% ====================================================================
    % 12. K LOOP
    %
    % IMPORTANT:
    % Nstar does NOT change here.
    %% ====================================================================

    for kk = 1:nK


        K = ...
            K_VALUES(kk);


        %% ----------------------------------------------------------------
        % K folder text
        %
        % 0.80 -> 0p80
        %% ----------------------------------------------------------------

        Ktxt = sprintf( ...
            '%.2f', ...
            K);


        Ktag = strrep( ...
            Ktxt, ...
            '.', ...
            'p');


        %% ----------------------------------------------------------------
        % Fixed N* folder
        %% ----------------------------------------------------------------

        lagFolder = sprintf( ...
            '%02d_day', ...
            Nstar);


        %% ----------------------------------------------------------------
        % API filename
        %
        % Example:
        %
        % 42516_03d_crozier_K0p90.txt
        %% ----------------------------------------------------------------

        apiFilename = sprintf( ...
            '%s_%02dd_crozier_K%s.txt', ...
            char(id), ...
            Nstar, ...
            Ktag);


        apiFile = fullfile( ...
            API_ROOT, ...
            ['K_' Ktag], ...
            lagFolder, ...
            apiFilename);


        %% ----------------------------------------------------------------
        % Check API
        %% ----------------------------------------------------------------

        if ~isfile(apiFile)


            STATUS(i,kk) = ...
                "API missing";


            warning( ...
                'API missing: %s | N*=%d | K=%.2f', ...
                id,Nstar,K);


            continue

        end


        %% =================================================================
        % 12A. READ API
        %% =================================================================

        APIdata = readmatrix( ...
            apiFile, ...
            'FileType','text');


        if isempty(APIdata) || ...
                size(APIdata,2) < 4


            STATUS(i,kk) = ...
                "Invalid API file";


            continue

        end


        goodAPI = ...
            isfinite(APIdata(:,1)) & ...
            isfinite(APIdata(:,2)) & ...
            isfinite(APIdata(:,3)) & ...
            isfinite(APIdata(:,4));


        APIdata = ...
            APIdata(goodAPI,:);


        APIdate = datetime( ...
            APIdata(:,1), ...
            APIdata(:,2), ...
            APIdata(:,3));


        API = ...
            APIdata(:,4);


        %% ----------------------------------------------------------------
        % Period
        %% ----------------------------------------------------------------

        keepAPI = ...
            year(APIdate) >= YR_START & ...
            year(APIdate) <= YR_END;


        APIdate = ...
            APIdate(keepAPI);


        API = ...
            API(keepAPI);


        %% =================================================================
        % 12B. MATCH API AND TR
        %
        % Preferred:
        % direct row alignment because API and TR were derived from the
        % same updated station-event catalogue.
        %
        % Fallback:
        % occurrence-preserving date matching.
        %% =================================================================

        directAlignment = ...
            numel(APIdate) == numel(TRdate);


        if directAlignment

            directAlignment = ...
                all(APIdate == TRdate);

        end


        %% ----------------------------------------------------------------
        % DIRECT ALIGNMENT
        %% ----------------------------------------------------------------

        if directAlignment


            matchedDate = ...
                TRdate;


            API_match = ...
                API;


            TR_match = ...
                TR;


            MatchMethod = ...
                repmat( ...
                "Direct row alignment", ...
                numel(TR_match), ...
                1);


        else


            %% =============================================================
            % OCCURRENCE-PRESERVING DATE MATCH
            %
            % This is safer than simple ismember when multiple landslides
            % occur on the same calendar date.
            %% =============================================================

            nTR = ...
                numel(TRdate);


            API_match_temp = ...
                nan(nTR,1);


            matchedFlag = ...
                false(nTR,1);


            usedAPI = ...
                false(numel(APIdate),1);


            for ee = 1:nTR


                candidate = find( ...
                    APIdate == TRdate(ee) & ...
                    ~usedAPI, ...
                    1, ...
                    'first');


                if ~isempty(candidate)


                    API_match_temp(ee) = ...
                        API(candidate);


                    matchedFlag(ee) = ...
                        true;


                    usedAPI(candidate) = ...
                        true;

                end

            end


            validMatch = ...
                matchedFlag & ...
                isfinite(API_match_temp) & ...
                isfinite(TR);


            matchedDate = ...
                TRdate(validMatch);


            API_match = ...
                API_match_temp(validMatch);


            TR_match = ...
                TR(validMatch);


            MatchMethod = ...
                repmat( ...
                "Occurrence-preserving date match", ...
                numel(API_match), ...
                1);


            warning( ...
                ['%s | K=%.2f | N*=%d: direct row alignment failed. ' ...
                 'Occurrence-preserving date matching used.'], ...
                station,K,Nstar);

        end


        %% ----------------------------------------------------------------
        % Final finite values
        %% ----------------------------------------------------------------

        finalOK = ...
            isfinite(API_match) & ...
            isfinite(TR_match);


        API_match = ...
            API_match(finalOK);


        TR_match = ...
            TR_match(finalOK);


        matchedDate = ...
            matchedDate(finalOK);


        MatchMethod = ...
            MatchMethod(finalOK);


        n = ...
            numel(API_match);


        NEVENT(i,kk) = ...
            n;


        if n < 3


            STATUS(i,kk) = ...
                "Too few matched events";


            continue

        end


        %% =================================================================
        % 12C. EMPIRICAL NORMALIZATION
        %
        % EXACTLY SAME METHOD AS PREVIOUS API-vs-TR ANALYSIS
        %% =================================================================

        API_norm = ...
            tiedrank(API_match) ./ ...
            (n + 1);


        TR_norm = ...
            tiedrank(TR_match) ./ ...
            (n + 1);


        %% =================================================================
        % 12D. ADF
        %
        % API > TR corresponds to points below the 1:1 line
        %% =================================================================

        d = ...
            TR_norm - API_norm;


        API_GT_TR = ...
            d < -EQ_TOL;


        TR_GT_API = ...
            d > EQ_TOL;


        Equal = ...
            abs(d) <= EQ_TOL;


        %% ----------------------------------------------------------------
        % Counts
        %% ----------------------------------------------------------------

        API_GT_TR_COUNT(i,kk) = ...
            sum(API_GT_TR);


        TR_GT_API_COUNT(i,kk) = ...
            sum(TR_GT_API);


        EQUAL_COUNT(i,kk) = ...
            sum(Equal);


        %% ----------------------------------------------------------------
        % ADF
        %% ----------------------------------------------------------------

        ADF(i,kk) = ...
            API_GT_TR_COUNT(i,kk) / n;


        STATUS(i,kk) = ...
            "OK";


        fprintf( ...
            'K=%.2f | n=%3d | ADF=%.3f\n', ...
            K,n,ADF(i,kk));


        %% =================================================================
        % 12E. EVENT-LEVEL AUDIT
        %% =================================================================

        TEvent = table( ...
            repmat(station,n,1), ...
            repmat(id,n,1), ...
            repmat(Nstar,n,1), ...
            repmat(K,n,1), ...
            matchedDate, ...
            API_match, ...
            TR_match, ...
            API_norm, ...
            TR_norm, ...
            API_GT_TR, ...
            TR_GT_API, ...
            Equal, ...
            MatchMethod, ...
            'VariableNames',{ ...
            'Station', ...
            'IMD_ID', ...
            'Fixed_Nstar_days', ...
            'K', ...
            'Event_date', ...
            'API_raw', ...
            'TR_raw', ...
            'API_normalized', ...
            'TR_normalized', ...
            'API_GT_TR', ...
            'TR_GT_API', ...
            'Equal', ...
            'Matching_method'});


        EventTable = [ ...
            EventTable; ...
            TEvent]; %#ok<AGROW>


    end

end


%% ========================================================================
% 13. STATION-WISE K-SENSITIVITY METRICS
%% ========================================================================

ADF_mean = ...
    mean(ADF,2,'omitnan');


ADF_median = ...
    median(ADF,2,'omitnan');


ADF_min = ...
    min(ADF,[],2,'omitnan');


ADF_max = ...
    max(ADF,[],2,'omitnan');


ADF_SD = ...
    std(ADF,0,2,'omitnan');


Delta_ADF = ...
    ADF_max - ADF_min;


%% ========================================================================
% 14. ADF AT REFERENCE K = 0.90
%% ========================================================================

idxK90 = find( ...
    abs(K_VALUES - REFERENCE_K) < 1e-10, ...
    1);


if isempty(idxK90)

    error('Reference K = %.2f was not found.',REFERENCE_K);

end


ADF_K090 = ...
    ADF(:,idxK90);


%% ========================================================================
% 15. CHECK WHETHER K CHANGES THE >=0.5 INTERPRETATION
%% ========================================================================

Crosses_0p5 = ...
    ADF_min < 0.50 & ...
    ADF_max >= 0.50;


All_ADF_GE_0p5 = ...
    ADF_min >= 0.50;


All_ADF_LT_0p5 = ...
    ADF_max < 0.50;


Robustness_class = ...
    strings(nStations,1);


for i = 1:nStations


    if Crosses_0p5(i)

        Robustness_class(i) = ...
            "Crosses 0.5 across K";


    elseif All_ADF_GE_0p5(i)

        Robustness_class(i) = ...
            "ADF >= 0.5 for all K";


    elseif All_ADF_LT_0p5(i)

        Robustness_class(i) = ...
            "ADF < 0.5 for all K";


    else

        Robustness_class(i) = ...
            "Insufficient data";

    end

end


%% ========================================================================
% 16. SUMMARY TABLE
%% ========================================================================

StationSummary = table( ...
    Lag.Station, ...
    Lag.IMD_ID, ...
    Lag.Optimal_N_days, ...
    ADF_K090, ...
    ADF_mean, ...
    ADF_median, ...
    ADF_min, ...
    ADF_max, ...
    ADF_SD, ...
    Delta_ADF, ...
    Crosses_0p5, ...
    Robustness_class, ...
    'VariableNames',{ ...
    'Station', ...
    'IMD_ID', ...
    'Fixed_Nstar_days', ...
    'ADF_at_K_0p90', ...
    'Mean_ADF_across_K', ...
    'Median_ADF_across_K', ...
    'Minimum_ADF', ...
    'Maximum_ADF', ...
    'SD_ADF', ...
    'Delta_ADF', ...
    'Crosses_ADF_0p5', ...
    'Robustness_class'});


%% ========================================================================
% 17. MATRIX TABLE VARIABLE NAMES
%% ========================================================================

K_HEADERS = ...
    strings(1,nK);


for kk = 1:nK


    txt = sprintf( ...
        '%.2f', ...
        K_VALUES(kk));


    txt = strrep( ...
        txt, ...
        '.', ...
        'p');


    K_HEADERS(kk) = ...
        "K_" + txt;

end


K_HEADERS = ...
    matlab.lang.makeValidName(K_HEADERS);


%% ========================================================================
% 18. CREATE MATRIX TABLES
%% ========================================================================

ADF_Table = table( ...
    Lag.Station, ...
    Lag.IMD_ID, ...
    Lag.Optimal_N_days, ...
    'VariableNames',{ ...
    'Station','IMD_ID','Fixed_Nstar_days'});


N_Table = ...
    ADF_Table;


APIcount_Table = ...
    ADF_Table;


TRcount_Table = ...
    ADF_Table;


Equal_Table = ...
    ADF_Table;


Status_Table = ...
    ADF_Table;


for kk = 1:nK


    ADF_Table.(K_HEADERS{kk}) = ...
        ADF(:,kk);


    N_Table.(K_HEADERS{kk}) = ...
        NEVENT(:,kk);


    APIcount_Table.(K_HEADERS{kk}) = ...
        API_GT_TR_COUNT(:,kk);


    TRcount_Table.(K_HEADERS{kk}) = ...
        TR_GT_API_COUNT(:,kk);


    Equal_Table.(K_HEADERS{kk}) = ...
        EQUAL_COUNT(:,kk);


    Status_Table.(K_HEADERS{kk}) = ...
        STATUS(:,kk);

end


%% ========================================================================
% 19. WRITE EXCEL
%% ========================================================================

OUT_XLSX = fullfile( ...
    OUT_DIR, ...
    'Step8_K_Sensitivity_Fixed_Nstar_ADF.xlsx');


if isfile(OUT_XLSX)

    delete(OUT_XLSX);

end


writetable( ...
    StationSummary, ...
    OUT_XLSX, ...
    'Sheet','Station_summary');


writetable( ...
    ADF_Table, ...
    OUT_XLSX, ...
    'Sheet','ADF_matrix');


writetable( ...
    N_Table, ...
    OUT_XLSX, ...
    'Sheet','Event_count');


writetable( ...
    APIcount_Table, ...
    OUT_XLSX, ...
    'Sheet','API_GT_TR_count');


writetable( ...
    TRcount_Table, ...
    OUT_XLSX, ...
    'Sheet','TR_GT_API_count');


writetable( ...
    Equal_Table, ...
    OUT_XLSX, ...
    'Sheet','Equal_count');


writetable( ...
    Status_Table, ...
    OUT_XLSX, ...
    'Sheet','Status');


if ~isempty(EventTable)


    writetable( ...
        EventTable, ...
        OUT_XLSX, ...
        'Sheet','Event_level');

end


%% ========================================================================
% 20. SAVE MAT
%% ========================================================================

OUT_MAT = fullfile( ...
    OUT_DIR, ...
    'Step8_K_Sensitivity_Fixed_Nstar_ADF.mat');


save( ...
    OUT_MAT, ...
    'ADF', ...
    'NEVENT', ...
    'API_GT_TR_COUNT', ...
    'TR_GT_API_COUNT', ...
    'EQUAL_COUNT', ...
    'STATUS', ...
    'Delta_ADF', ...
    'ADF_mean', ...
    'ADF_median', ...
    'ADF_min', ...
    'ADF_max', ...
    'ADF_SD', ...
    'ADF_K090', ...
    'Crosses_0p5', ...
    'Robustness_class', ...
    'K_VALUES', ...
    'Lag', ...
    'StationSummary', ...
    'EventTable');


%% ========================================================================
% 21. CONSOLE SUMMARY
%% ========================================================================

fprintf('\n');
fprintf('=============================================================\n');
fprintf(' K-SENSITIVITY SUMMARY\n');
fprintf('=============================================================\n');


fprintf( ...
    '%-19s %5s %8s %8s %8s %8s\n', ...
    'Station', ...
    'N*', ...
    'ADF.90', ...
    'Min', ...
    'Max', ...
    'Delta');


fprintf('%s\n', ...
    repmat('-',1,66));


for i = 1:nStations


    fprintf( ...
        '%-19s %5.0f %8.3f %8.3f %8.3f %8.3f\n', ...
        Lag.Station(i), ...
        Lag.Optimal_N_days(i), ...
        ADF_K090(i), ...
        ADF_min(i), ...
        ADF_max(i), ...
        Delta_ADF(i));

end


fprintf('%s\n', ...
    repmat('-',1,66));


fprintf( ...
    'Median Delta ADF       : %.3f\n', ...
    median(Delta_ADF,'omitnan'));


fprintf( ...
    'Maximum Delta ADF      : %.3f\n', ...
    max(Delta_ADF,[],'omitnan'));


fprintf( ...
    'Sites crossing ADF=0.5 : %d/%d\n', ...
    sum(Crosses_0p5), ...
    nStations);


fprintf('=============================================================\n');


%% ========================================================================
% 22. PUBLICATION-STYLE K-SENSITIVITY HEATMAP
%
% Rows:
%       stations sorted by fixed N*
%
% Columns:
%       K
%
% Cells:
%       ADF
%
% Black rectangle:
%       reference K = 0.90
%
% No title.
%% ========================================================================

fig = figure( ...
    'Color','w', ...
    'Units','centimeters', ...
    'Position',[2 2 31 18], ...
    'Renderer','painters');


ax = axes(fig);


imagesc( ...
    ax, ...
    ADF);


hold(ax,'on');


set( ...
    ax, ...
    'YDir','reverse');


%% ========================================================================
% 23. COLOR LIMITS
%
% ADF naturally ranges from 0 to 1.
% White midpoint corresponds approximately to ADF = 0.5.
%% ========================================================================

clim( ...
    ax, ...
    [0 1]);


%% ========================================================================
% 24. MULTICOLOUR ADF COLORMAP
%
% Full theoretical ADF range remains 0-1.
%
% Low ADF     -> dark blue
% ~0.25       -> cyan
% ~0.50       -> yellow
% ~0.75       -> orange
% High ADF    -> dark red
%
% This improves visual discrimination without changing the data.
%% ========================================================================

clim(ax,[0 1]);


% Anchor colours corresponding approximately to:
% ADF = 0, 0.25, 0.50, 0.75, 1.00

anchorValues = [ ...
    0.00 ...
    0.25 ...
    0.50 ...
    0.75 ...
    1.00];


anchorColors = [ ...
    0.10 0.20 0.70;   % dark blue
    0.15 0.75 0.90;   % cyan
    1.00 0.95 0.35;   % yellow
    1.00 0.50 0.10;   % orange
    0.75 0.05 0.05];  % dark red


nColors = 256;

queryValues = linspace(0,1,nColors);


ADF_cmap = zeros(nColors,3);


for cc = 1:3

    ADF_cmap(:,cc) = interp1( ...
        anchorValues, ...
        anchorColors(:,cc), ...
        queryValues, ...
        'linear');

end


colormap(ax,ADF_cmap);


%% ========================================================================
% 25. CELL ANNOTATIONS
%% ========================================================================

for r = 1:nStations


    for c = 1:nK


        value = ...
            ADF(r,c);


        if ~isfinite(value)

            continue

        end


        %% ----------------------------------------------------------------
        % Text colour according to background intensity
        %% ----------------------------------------------------------------

        if value <= 0.22 || ...
                value >= 0.78


            txtColor = ...
                [1 1 1];

        else

            txtColor = ...
                [0 0 0];

        end


        %% ----------------------------------------------------------------
        % K=0.90 reference values slightly bolder
        %% ----------------------------------------------------------------

        if c == idxK90

            fontWeight = ...
                'bold';


            fontSize = ...
                11.5;

        else

            fontWeight = ...
                'bold';


            fontSize = ...
                10.5;

        end


        text( ...
            ax, ...
            c, ...
            r, ...
            sprintf('%.2f',value), ...
            'HorizontalAlignment','center', ...
            'VerticalAlignment','middle', ...
            'FontSize',fontSize, ...
            'FontWeight',fontWeight, ...
            'Color',txtColor);

    end

end


%% ========================================================================
% 26. OUTLINE REFERENCE K = 0.90
%
% Entire reference column outlined instead of repeatedly boxing all cells.
%% ========================================================================

rectangle( ...
    ax, ...
    'Position',[ ...
    idxK90-0.5 ...
    0.5 ...
    1 ...
    nStations], ...
    'EdgeColor','k', ...
    'LineWidth',2.5);


%% ========================================================================
% 27. Y LABELS
%
% Include N* because lag is fixed during K-sensitivity analysis.
%% ========================================================================

yLabels = ...
    strings(nStations,1);


for i = 1:nStations


    yLabels(i) = sprintf( ...
        '%s  (N^*=%d d)', ...
        Lag.Station(i), ...
        round(Lag.Optimal_N_days(i)));

end


%% ========================================================================
% 28. AXES
%% ========================================================================

K_X_LABELS = ...
    strings(1,nK);


for kk = 1:nK

    K_X_LABELS(kk) = sprintf( ...
        '%.2f', ...
        K_VALUES(kk));

end


set( ...
    ax, ...
    'XTick',1:nK, ...
    'XTickLabel',K_X_LABELS, ...
    'YTick',1:nStations, ...
    'YTickLabel',yLabels, ...
    'FontSize',12.5, ...
    'FontWeight','bold', ...
    'TickLength',[0 0], ...
    'LineWidth',1.1, ...
    'Box','on', ...
    'Layer','top', ...
    'XColor','k', ...
    'YColor','k');


xlim( ...
    ax, ...
    [0.5 nK+0.5]);


ylim( ...
    ax, ...
    [0.5 nStations+0.5]);


%% ========================================================================
% 29. AXIS LABEL
%% ========================================================================

xlabel( ...
    ax, ...
    'Decay factor, K', ...
    'FontSize',15, ...
    'FontWeight','bold', ...
    'Color','k');


% No title


%% ========================================================================
% 30. COLORBAR
%% ========================================================================

cb = colorbar(ax);


cb.Label.String = ...
    'ADF';


cb.Label.FontSize = ...
    14;


cb.Label.FontWeight = ...
    'bold';


cb.Label.Color = ...
    'k';


cb.FontSize = ...
    12;


cb.FontWeight = ...
    'bold';


cb.Color = ...
    'k';


cb.Ticks = ...
    [0 0.25 0.50 0.75 1.00];


%% ========================================================================
% 31. EXPORT HEATMAP
%% ========================================================================

HEAT_PNG = fullfile( ...
    OUT_DIR, ...
    'Step8_ADF_K_Sensitivity_Heatmap.png');


HEAT_TIF = fullfile( ...
    OUT_DIR, ...
    'Step8_ADF_K_Sensitivity_Heatmap.tiff');


HEAT_FIG = fullfile( ...
    OUT_DIR, ...
    'Step8_ADF_K_Sensitivity_Heatmap.fig');


exportgraphics( ...
    fig, ...
    HEAT_PNG, ...
    'Resolution',600);


exportgraphics( ...
    fig, ...
    HEAT_TIF, ...
    'Resolution',600);


savefig( ...
    fig, ...
    HEAT_FIG);


%% ========================================================================
% 32. DELTA ADF FIGURE
%
% Useful for directly showing which stations are more sensitive to K.
%% ========================================================================

fig2 = figure( ...
    'Color','w', ...
    'Units','centimeters', ...
    'Position',[2 2 21 18], ...
    'Renderer','painters');


ax2 = axes(fig2);


b = barh( ...
    ax2, ...
    Delta_ADF, ...
    0.72);


b.FaceColor = ...
    [0.38 0.60 0.78];


b.EdgeColor = ...
    [0.10 0.10 0.10];


b.LineWidth = ...
    0.7;


set( ...
    ax2, ...
    'YDir','reverse', ...
    'YTick',1:nStations, ...
    'YTickLabel',Lag.Station, ...
    'FontSize',12, ...
    'FontWeight','bold', ...
    'TickDir','out', ...
    'LineWidth',1, ...
    'Box','off', ...
    'XColor','k', ...
    'YColor','k');


xlabel( ...
    ax2, ...
    '\DeltaADF = max(ADF) - min(ADF)', ...
    'FontSize',14, ...
    'FontWeight','bold');


grid( ...
    ax2, ...
    'on');


ax2.XGrid = ...
    'on';


ax2.YGrid = ...
    'off';


ax2.GridLineStyle = ...
    ':';


ax2.GridAlpha = ...
    0.18;


for i = 1:nStations


    if ~isfinite(Delta_ADF(i))

        continue

    end


    text( ...
        ax2, ...
        Delta_ADF(i) + 0.005, ...
        i, ...
        sprintf('%.2f',Delta_ADF(i)), ...
        'HorizontalAlignment','left', ...
        'VerticalAlignment','middle', ...
        'FontSize',10.5, ...
        'FontWeight','bold');

end


DELTA_PNG = fullfile( ...
    OUT_DIR, ...
    'Step8_DeltaADF_by_Station.png');


exportgraphics( ...
    fig2, ...
    DELTA_PNG, ...
    'Resolution',600);


%% ========================================================================
% 33. FINAL MESSAGE
%% ========================================================================

fprintf('\n');
fprintf('=============================================================\n');
fprintf(' STEP 8 COMPLETE\n');
fprintf('=============================================================\n');


fprintf( ...
    'Fixed lag source:\n%s\n\n', ...
    LAG_FILE);


fprintf( ...
    'Excel:\n%s\n\n', ...
    OUT_XLSX);


fprintf( ...
    'ADF heatmap:\n%s\n\n', ...
    HEAT_PNG);


fprintf( ...
    'Delta ADF figure:\n%s\n\n', ...
    DELTA_PNG);


fprintf( ...
    'Sites crossing ADF = 0.5 across K: %d/%d\n', ...
    sum(Crosses_0p5), ...
    nStations);


fprintf('=============================================================\n');