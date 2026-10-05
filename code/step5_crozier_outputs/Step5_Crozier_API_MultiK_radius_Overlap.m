%% ========================================================================
% Step5_Crozier_API_MultiK_radius_Overlap.m
%
% PURPOSE
% -------------------------------------------------------------------------
% Calculate Crozier/API values for the UPDATED landslide dataset:
%
%   - station-radius station radius
%   - catalogue duplicates removed
%   - cross-station overlap retained
%   - updated last day of triggering rainfall
%   - all 21 NEH stations
%
% K SENSITIVITY:
%
%   K = 0.80 : 0.02 : 0.98
%
% i.e.
%
%   0.80
%   0.82
%   0.84
%   0.86
%   0.88
%   0.90
%   0.92
%   0.94
%   0.96
%   0.98
%
%
% LAGS:
%
%   3, 5, 7, 11, 15, 21, 25, 30 days
%
%
% IMPORTANT
% -------------------------------------------------------------------------
% This script preserves the convention used in the previous Crozier code:
%
%       n = lag + 1
%
% Thus, for a nominal 3-day lag, precipitation values are supplied from
% trigger_day - 3 through trigger_day, inclusive.
%
%
% OUTPUT STRUCTURE:
%
% step_5_crozier_outputs\
%
%     K_0p80\
%         03_day\
%         05_day\
%         ...
%         30_day\
%
%     K_0p82\
%     ...
%     K_0p98\
%
%
% Each TXT:
%
% year   month   day   Crozier_API
%
%
% An Excel audit file is also written:
%
% Step5_Crozier_API_Audit.xlsx
%
%
% NO LOCAL/USER-DEFINED FUNCTIONS ARE USED IN THIS SCRIPT.
%
% ========================================================================

clc;
clear;
close all;


%% ========================================================================
% 1. PATHS
%% ========================================================================

% -------------------------------------------------------------------------
% CROZIER FUNCTION LOCATION
%
% Keep the location used previously.
% -------------------------------------------------------------------------

addpath( ...
    fullfile(neh_root(),'1_new_stations_nwh','6_crozier_outputs'));


% -------------------------------------------------------------------------
% UPDATED LAST DAY OF TRIGGERING RAINFALL
% -------------------------------------------------------------------------

last_day_trigger = ...
    fullfile(neh_root(),'step_4_last_day_of_trigging','radius_triggering_rainfall_ALLOW_OVERLAP');


% -------------------------------------------------------------------------
% UPDATED station-radius LANDSLIDE FILES
% Overlap retained
% -------------------------------------------------------------------------

land_path = ...
    fullfile(neh_root(),'step_0_landslide_filtering','radius_station_txt_ALLOW_OVERLAP');


% -------------------------------------------------------------------------
% DAILY RAINFALL
% -------------------------------------------------------------------------

Rain_STN_path = ...
    fullfile(neh_root(),'3_rainfall_events_thresholds','rainfall_data_threshold_applied');


% -------------------------------------------------------------------------
% OUTPUT
% -------------------------------------------------------------------------

OUTPUT_ROOT = ...
    fullfile(neh_root(),'step_5_crozier_outputs');


if ~exist(OUTPUT_ROOT,'dir')

    mkdir(OUTPUT_ROOT);

end


%% ========================================================================
% 2. CONFIGURATION
%% ========================================================================

YR_START = 2007;

YR_END = 2021;


% -------------------------------------------------------------------------
% Current revised lag candidates
% -------------------------------------------------------------------------

lag_days = [ ...
    3 ...
    5 ...
    7 ...
    11 ...
    15 ...
    21 ...
    25 ...
    30];


% -------------------------------------------------------------------------
% K values
% -------------------------------------------------------------------------

K_VALUES = ...
    0.80 : 0.02 : 0.98;


% Prevent floating-point labels such as 0.90000000001
K_VALUES = ...
    round(K_VALUES,2);


%% ========================================================================
% 3. CHECK CROZIER FUNCTION
%% ========================================================================

crozierLocation = ...
    which('crozier');


if isempty(crozierLocation)

    error( ...
        ['crozier.m could not be found.' newline ...
         'Check the addpath directory at the start of the script.']);

end


fprintf('\n');
fprintf('=============================================================\n');
fprintf(' CROZIER/API MULTI-K ANALYSIS\n');
fprintf('=============================================================\n');

fprintf( ...
    'Crozier function:\n%s\n\n', ...
    crozierLocation);


fprintf('Landslide radius      : station radius\n');

fprintf('Station overlap       : RETAINED\n');

fprintf('Catalogue duplicates  : previously removed\n');

fprintf( ...
    'Study period         : %d-%d\n', ...
    YR_START,YR_END);


fprintf('Lag windows           : ');

fprintf('%d ',lag_days);

fprintf('days\n');


fprintf('K values              : ');

fprintf('%.2f ',K_VALUES);

fprintf('\n');


fprintf('Output:\n%s\n', ...
    OUTPUT_ROOT);

fprintf('=============================================================\n\n');


%% ========================================================================
% 4. GET UPDATED LANDSLIDE FILES
%% ========================================================================

LandFiles = dir( ...
    fullfile( ...
    land_path, ...
    '*_landslides.txt'));


LandFiles = ...
    LandFiles(~[LandFiles.isdir]);


nStations = ...
    numel(LandFiles);


fprintf( ...
    'Landslide station files found: %d\n\n', ...
    nStations);


if nStations == 0

    error( ...
        'No landslide TXT files were found.');

end


if nStations ~= 21

    warning( ...
        'Expected 21 stations but found %d.', ...
        nStations);

end


%% ========================================================================
% 5. GET RAINFALL FILE LIST
%% ========================================================================

RainFiles = dir( ...
    fullfile( ...
    Rain_STN_path, ...
    '*.txt'));


RainFiles = ...
    RainFiles(~[RainFiles.isdir]);


RainFileNames = ...
    string({RainFiles.name})';


%% ========================================================================
% 6. GET LAST-TRIGGER FILE LIST
%% ========================================================================

TriggerFiles = dir( ...
    fullfile( ...
    last_day_trigger, ...
    '*.txt'));


TriggerFiles = ...
    TriggerFiles(~[TriggerFiles.isdir]);


TriggerFileNames = ...
    string({TriggerFiles.name})';


fprintf( ...
    'Last-trigger files found      : %d\n', ...
    numel(TriggerFiles));


fprintf( ...
    'Rainfall files available      : %d\n\n', ...
    numel(RainFiles));


%% ========================================================================
% 7. PREPARE AUDIT ARRAYS
%% ========================================================================

totalExpectedRows = ...
    nStations * ...
    numel(K_VALUES) * ...
    numel(lag_days);


AuditStation = ...
    strings(totalExpectedRows,1);


AuditID = ...
    strings(totalExpectedRows,1);


AuditK = ...
    nan(totalExpectedRows,1);


AuditLag = ...
    nan(totalExpectedRows,1);


AuditNEvents = ...
    nan(totalExpectedRows,1);


AuditMissingRainDays = ...
    nan(totalExpectedRows,1);


AuditMeanAPI = ...
    nan(totalExpectedRows,1);


AuditMedianAPI = ...
    nan(totalExpectedRows,1);


AuditMinAPI = ...
    nan(totalExpectedRows,1);


AuditMaxAPI = ...
    nan(totalExpectedRows,1);


AuditOutputFile = ...
    strings(totalExpectedRows,1);


auditRow = 0;


%% ========================================================================
% 8. LOOP THROUGH UPDATED station-radius LANDSLIDE STATIONS
%% ========================================================================

for idx = 1:nStations


    %% --------------------------------------------------------------------
    % LANDSLIDE FILE
    %% --------------------------------------------------------------------

    landFileName = ...
        LandFiles(idx).name;


    landFileFull = fullfile( ...
        land_path, ...
        landFileName);


    [~,landBase,~] = ...
        fileparts(landFileName);


    %% --------------------------------------------------------------------
    % Extract station ID
    %
    % Expected:
    %
    % Aizwal_326239204_landslides.txt
    %% --------------------------------------------------------------------

    token = regexp( ...
        landFileName, ...
        '_(\d+)_landslides\.txt$', ...
        'tokens', ...
        'once');


    if isempty(token)

        warning( ...
            'Could not identify station ID: %s', ...
            landFileName);

        continue

    end


    stationID = ...
        string(token{1});


    %% --------------------------------------------------------------------
    % Station name
    %% --------------------------------------------------------------------

    stationNameRaw = regexprep( ...
        landBase, ...
        ['_' char(stationID) '_landslides$'], ...
        '');


    stationName = replace( ...
        string(stationNameRaw), ...
        '_', ...
        ' ');


    fprintf('\n');
    fprintf('=============================================================\n');

    fprintf( ...
        'STATION: %s | ID: %s\n', ...
        stationName, ...
        stationID);

    fprintf('=============================================================\n');


    %% ====================================================================
    % 8A. FIND RAINFALL FILE
    %% ====================================================================

    expectedRainName = ...
        stationID + ".txt";


    rainMatch = ...
        lower(RainFileNames) == ...
        lower(expectedRainName);


    if sum(rainMatch) == 1


        rainFileName = ...
            RainFileNames(rainMatch);


    else


        % ---------------------------------------------------------------
        % Fallback: search station ID inside filename
        % ---------------------------------------------------------------

        rainMatch = contains( ...
            lower(RainFileNames), ...
            lower(stationID));


        if sum(rainMatch) == 1

            rainFileName = ...
                RainFileNames(rainMatch);

        else

            warning( ...
                'No unique rainfall file found for ID %s.', ...
                stationID);

            continue

        end

    end


    rainFileFull = fullfile( ...
        Rain_STN_path, ...
        char(rainFileName));


    fprintf( ...
        'Rainfall file       : %s\n', ...
        rainFileName);


    %% ====================================================================
    % 8B. FIND LAST-DAY-OF-TRIGGER FILE
    %% ====================================================================

    % Previous output naming was generally:
    %
    % 326239204trigging_duration.txt

    triggerMatch = contains( ...
        lower(TriggerFileNames), ...
        lower(stationID));


    if sum(triggerMatch) == 1


        triggerFileName = ...
            TriggerFileNames(triggerMatch);


    elseif sum(triggerMatch) > 1


        % ---------------------------------------------------------------
        % Prefer filename containing "trigging_duration"
        % ---------------------------------------------------------------

        candidates = ...
            TriggerFileNames(triggerMatch);


        candidatePreferred = contains( ...
            lower(candidates), ...
            'trigging_duration');


        if sum(candidatePreferred) == 1

            triggerFileName = ...
                candidates(candidatePreferred);

        else

            warning( ...
                ['Multiple trigger files found for station ' ...
                 '%s. Skipping to prevent incorrect matching.'], ...
                stationID);

            continue

        end


    else


        warning( ...
            'No last-trigger file found for ID %s.', ...
            stationID);

        continue

    end


    triggerFileFull = fullfile( ...
        last_day_trigger, ...
        char(triggerFileName));


    fprintf( ...
        'Last-trigger file   : %s\n', ...
        triggerFileName);


    %% ====================================================================
    % 8C. LOAD UPDATED LANDSLIDES
    %% ====================================================================

    slide_data = readmatrix( ...
        landFileFull);


    if isempty(slide_data) || ...
            size(slide_data,2) < 6


        warning( ...
            'Invalid landslide file: %s', ...
            landFileName);

        continue

    end


    %% --------------------------------------------------------------------
    % Remove non-finite rows
    %% --------------------------------------------------------------------

    validSlide = ...
        isfinite(slide_data(:,1)) & ...
        isfinite(slide_data(:,2)) & ...
        isfinite(slide_data(:,3)) & ...
        isfinite(slide_data(:,4)) & ...
        isfinite(slide_data(:,5)) & ...
        isfinite(slide_data(:,6));


    slide_data = ...
        slide_data(validSlide,:);


    slideDate = datetime( ...
        slide_data(:,4), ...
        slide_data(:,5), ...
        slide_data(:,6));


    %% ====================================================================
    % 8D. LOAD LAST DAY OF TRIGGERING
    %% ====================================================================

    last_trigger_data = readmatrix( ...
        triggerFileFull);


    if isempty(last_trigger_data) || ...
            size(last_trigger_data,2) < 3


        warning( ...
            'Invalid last-trigger file: %s', ...
            triggerFileName);

        continue

    end


    %% ====================================================================
    % 8E. ROW ALIGNMENT CHECK
    %% ====================================================================

    if size(slide_data,1) ~= ...
            size(last_trigger_data,1)


        error( ...
            ['ROW MISMATCH for %s.' newline ...
             'Landslide rows = %d' newline ...
             'Trigger rows   = %d' newline ...
             'Do NOT continue until these files are aligned.'], ...
            stationName, ...
            size(slide_data,1), ...
            size(last_trigger_data,1));

    end


    %% ====================================================================
    % 8F. SORT BOTH USING LANDSLIDE DATE
    %
    % Keeps row correspondence intact.
    %% ====================================================================

    [slideDate,sortOrder] = ...
        sort(slideDate);


    slide_data = ...
        slide_data(sortOrder,:);


    last_trigger_data = ...
        last_trigger_data(sortOrder,:);


    %% ====================================================================
    % 8G. STUDY PERIOD
    %% ====================================================================

    keepPeriod = ...
        year(slideDate) >= YR_START & ...
        year(slideDate) <= YR_END;


    slideDate = ...
        slideDate(keepPeriod);


    slide_data = ...
        slide_data(keepPeriod,:);


    last_trigger_data = ...
        last_trigger_data(keepPeriod,:);


    %% ====================================================================
    % 8H. LAST DAY OF TRIGGERING AS DATETIME
    %% ====================================================================

    validTriggerDate = ...
        isfinite(last_trigger_data(:,1)) & ...
        isfinite(last_trigger_data(:,2)) & ...
        isfinite(last_trigger_data(:,3));


    if ~all(validTriggerDate)


        warning( ...
            '%s contains invalid trigger dates.', ...
            stationName);


        slideDate = ...
            slideDate(validTriggerDate);


        slide_data = ...
            slide_data(validTriggerDate,:);


        last_trigger_data = ...
            last_trigger_data(validTriggerDate,:);

    end


    lastTriggerDate = datetime( ...
        last_trigger_data(:,1), ...
        last_trigger_data(:,2), ...
        last_trigger_data(:,3));


    nEvents = ...
        numel(lastTriggerDate);


    fprintf( ...
        'Landslide events     : %d\n', ...
        nEvents);


    if nEvents == 0

        continue

    end


    %% ====================================================================
    % 8I. LOAD DAILY RAINFALL
    %% ====================================================================

    Rain_STN = readmatrix( ...
        rainFileFull);


    if isempty(Rain_STN) || ...
            size(Rain_STN,2) < 4


        warning( ...
            'Invalid rainfall file for %s.', ...
            stationName);

        continue

    end


    validRain = ...
        isfinite(Rain_STN(:,1)) & ...
        isfinite(Rain_STN(:,2)) & ...
        isfinite(Rain_STN(:,3)) & ...
        isfinite(Rain_STN(:,4));


    Rain_STN = ...
        Rain_STN(validRain,:);


    rainDate = datetime( ...
        Rain_STN(:,1), ...
        Rain_STN(:,2), ...
        Rain_STN(:,3));


    rainValue = ...
        Rain_STN(:,4);


    %% --------------------------------------------------------------------
    % Sort rainfall
    %% --------------------------------------------------------------------

    [rainDate,rainOrder] = ...
        sort(rainDate);


    rainValue = ...
        rainValue(rainOrder);


    %% --------------------------------------------------------------------
    % Remove repeated rainfall dates
    %% --------------------------------------------------------------------

    if numel(unique(rainDate)) ~= ...
            numel(rainDate)


        warning( ...
            ['Repeated rainfall dates found for %s. ' ...
             'Keeping first occurrence.'], ...
            stationName);


        [rainDate,ia] = unique( ...
            rainDate, ...
            'stable');


        rainValue = ...
            rainValue(ia);

    end


    %% ====================================================================
    % 9. LOOP THROUGH K VALUES
    %% ====================================================================

    for kk = 1:numel(K_VALUES)


        kDecay = ...
            K_VALUES(kk);


        %% ----------------------------------------------------------------
        % Folder-safe K text
        %
        % 0.80 -> 0p80
        %% ----------------------------------------------------------------

        kText = sprintf( ...
            '%.2f', ...
            kDecay);


        kFolderText = strrep( ...
            kText, ...
            '.', ...
            'p');


        K_DIR = fullfile( ...
            OUTPUT_ROOT, ...
            ['K_' kFolderText]);


        if ~exist(K_DIR,'dir')

            mkdir(K_DIR);

        end


        fprintf('\n');

        fprintf( ...
            '  K = %.2f\n', ...
            kDecay);


        %% ================================================================
        % 10. LOOP THROUGH LAG WINDOWS
        %% ================================================================

        for ll = 1:numel(lag_days)


            lag = ...
                lag_days(ll);


            % -------------------------------------------------------------
            % Preserve convention from original code
            % -------------------------------------------------------------

            n = ...
                lag + 1;


            %% -------------------------------------------------------------
            % Lag folder
            %% -------------------------------------------------------------

            lagFolder = sprintf( ...
                '%02d_day', ...
                lag);


            LAG_DIR = fullfile( ...
                K_DIR, ...
                lagFolder);


            if ~exist(LAG_DIR,'dir')

                mkdir(LAG_DIR);

            end


            %% -------------------------------------------------------------
            % Output matrix
            %
            % Y M D API
            %% -------------------------------------------------------------

            result_matrix = ...
                nan(nEvents,4);


            %% -------------------------------------------------------------
            % Missing-rain counter
            %% -------------------------------------------------------------

            totalMissingRainDays = ...
                0;


            %% ============================================================
            % 11. EVENT LOOP
            %% ============================================================

            for jdx = 1:nEvents


                %% --------------------------------------------------------
                % Last day of triggering rainfall
                %% --------------------------------------------------------

                endDate = ...
                    lastTriggerDate(jdx);


                %% --------------------------------------------------------
                % Antecedent window
                %
                % For lag=3:
                %
                % trigger-3, trigger-2, trigger-1, trigger
                %
                % = 4 records, reproducing original n=lag+1 convention
                %% --------------------------------------------------------

                startDate = ...
                    endDate - ...
                    days(lag);


                windowDates = ...
                    (startDate : caldays(1) : endDate)';


                %% --------------------------------------------------------
                % Safety
                %% --------------------------------------------------------

                if numel(windowDates) ~= n

                    error( ...
                        ['Unexpected window length at %s, ' ...
                         'K=%.2f, lag=%d.'], ...
                        stationName, ...
                        kDecay, ...
                        lag);

                end


                %% --------------------------------------------------------
                % Align daily rainfall exactly to window dates
                %% --------------------------------------------------------

                [dateFound,dateLocation] = ...
                    ismember( ...
                    windowDates, ...
                    rainDate);


                precipValues = ...
                    zeros(n,1);


                %% --------------------------------------------------------
                % Dates present in rainfall file
                %% --------------------------------------------------------

                precipValues(dateFound) = ...
                    rainValue( ...
                    dateLocation(dateFound));


                %% --------------------------------------------------------
                % Missing dates
                %
                % Reproduces the previous zero-padding approach.
                %% --------------------------------------------------------

                nMissing = ...
                    sum(~dateFound);


                totalMissingRainDays = ...
                    totalMissingRainDays + ...
                    nMissing;


                %% --------------------------------------------------------
                % Crozier input:
                %
                % year month day rainfall
                %% --------------------------------------------------------

                Precip = [ ...
                    year(windowDates), ...
                    month(windowDates), ...
                    day(windowDates), ...
                    precipValues];


                %% --------------------------------------------------------
                % CROZIER CALCULATION
                %% --------------------------------------------------------

                Precip_Crozier = ...
                    crozier( ...
                    Precip, ...
                    n, ...
                    kDecay);


                %% --------------------------------------------------------
                % Expected scalar output
                %% --------------------------------------------------------

                if numel(Precip_Crozier) ~= 1

                    error( ...
                        ['crozier returned %d values instead of one ' ...
                         'for %s, K=%.2f, lag=%d.'], ...
                        numel(Precip_Crozier), ...
                        stationName, ...
                        kDecay, ...
                        lag);

                end


                %% --------------------------------------------------------
                % Save using LANDSLIDE date, as in old workflow
                %% --------------------------------------------------------

                result_matrix(jdx,:) = [ ...
                    year(slideDate(jdx)), ...
                    month(slideDate(jdx)), ...
                    day(slideDate(jdx)), ...
                    Precip_Crozier];

            end


            %% ============================================================
            % 12. OUTPUT FILE
            %% ============================================================

            outputFileName = sprintf( ...
                '%s_%02dd_crozier_K%s.txt', ...
                char(stationID), ...
                lag, ...
                kFolderText);


            outputFile = fullfile( ...
                LAG_DIR, ...
                outputFileName);


            writematrix( ...
                result_matrix, ...
                outputFile, ...
                'Delimiter','tab');


            fprintf( ...
                '    Lag %2d d : %4d events -> %s\n', ...
                lag, ...
                nEvents, ...
                outputFileName);


            %% ============================================================
            % 13. AUDIT
            %% ============================================================

            auditRow = ...
                auditRow + 1;


            AuditStation(auditRow) = ...
                stationName;


            AuditID(auditRow) = ...
                stationID;


            AuditK(auditRow) = ...
                kDecay;


            AuditLag(auditRow) = ...
                lag;


            AuditNEvents(auditRow) = ...
                nEvents;


            AuditMissingRainDays(auditRow) = ...
                totalMissingRainDays;


            AuditMeanAPI(auditRow) = ...
                mean( ...
                result_matrix(:,4), ...
                'omitnan');


            AuditMedianAPI(auditRow) = ...
                median( ...
                result_matrix(:,4), ...
                'omitnan');


            AuditMinAPI(auditRow) = ...
                min( ...
                result_matrix(:,4), ...
                [], ...
                'omitnan');


            AuditMaxAPI(auditRow) = ...
                max( ...
                result_matrix(:,4), ...
                [], ...
                'omitnan');


            AuditOutputFile(auditRow) = ...
                string(outputFile);


        end

    end

end


%% ========================================================================
% 14. TRIM UNUSED AUDIT ROWS
%% ========================================================================

AuditStation = ...
    AuditStation(1:auditRow);


AuditID = ...
    AuditID(1:auditRow);


AuditK = ...
    AuditK(1:auditRow);


AuditLag = ...
    AuditLag(1:auditRow);


AuditNEvents = ...
    AuditNEvents(1:auditRow);


AuditMissingRainDays = ...
    AuditMissingRainDays(1:auditRow);


AuditMeanAPI = ...
    AuditMeanAPI(1:auditRow);


AuditMedianAPI = ...
    AuditMedianAPI(1:auditRow);


AuditMinAPI = ...
    AuditMinAPI(1:auditRow);


AuditMaxAPI = ...
    AuditMaxAPI(1:auditRow);


AuditOutputFile = ...
    AuditOutputFile(1:auditRow);


%% ========================================================================
% 15. CREATE AUDIT TABLE
%% ========================================================================

Audit = table( ...
    AuditStation, ...
    AuditID, ...
    AuditK, ...
    AuditLag, ...
    AuditNEvents, ...
    AuditMissingRainDays, ...
    AuditMeanAPI, ...
    AuditMedianAPI, ...
    AuditMinAPI, ...
    AuditMaxAPI, ...
    AuditOutputFile, ...
    'VariableNames',{ ...
    'Station', ...
    'IMD_ID', ...
    'K', ...
    'Lag_days', ...
    'N_landslide_events', ...
    'Missing_daily_rainfall_values_filled_zero', ...
    'Mean_API', ...
    'Median_API', ...
    'Minimum_API', ...
    'Maximum_API', ...
    'Output_file'});


%% ========================================================================
% 16. WRITE AUDIT WORKBOOK
%% ========================================================================

AUDIT_XLSX = fullfile( ...
    OUTPUT_ROOT, ...
    'Step5_Crozier_API_Audit.xlsx');


if isfile(AUDIT_XLSX)

    delete(AUDIT_XLSX);

end


writetable( ...
    Audit, ...
    AUDIT_XLSX, ...
    'Sheet','All_outputs');


%% ========================================================================
% 17. K SUMMARY
%% ========================================================================

nK = ...
    numel(K_VALUES);


KsummaryK = ...
    K_VALUES';


KsummaryFiles = ...
    zeros(nK,1);


KsummaryMeanAPI = ...
    nan(nK,1);


for kk = 1:nK


    thisK = ...
        abs(Audit.K - K_VALUES(kk)) < 1e-10;


    KsummaryFiles(kk) = ...
        sum(thisK);


    KsummaryMeanAPI(kk) = ...
        mean( ...
        Audit.Mean_API(thisK), ...
        'omitnan');

end


K_Summary = table( ...
    KsummaryK, ...
    KsummaryFiles, ...
    KsummaryMeanAPI, ...
    'VariableNames',{ ...
    'K', ...
    'Number_of_output_files', ...
    'Mean_of_station_lag_mean_API'});


writetable( ...
    K_Summary, ...
    AUDIT_XLSX, ...
    'Sheet','K_summary');


%% ========================================================================
% 18. EXPECTED FILE COUNT
%% ========================================================================

expectedFiles = ...
    nStations * ...
    numel(K_VALUES) * ...
    numel(lag_days);


fprintf('\n');
fprintf('=============================================================\n');
fprintf(' CROZIER/API PROCESSING COMPLETE\n');
fprintf('=============================================================\n');


fprintf( ...
    'Stations detected       : %d\n', ...
    nStations);


fprintf( ...
    'K values                : %d\n', ...
    numel(K_VALUES));


fprintf( ...
    'Lag windows             : %d\n', ...
    numel(lag_days));


fprintf( ...
    'Expected output files   : %d\n', ...
    expectedFiles);


fprintf( ...
    'Outputs actually written: %d\n', ...
    auditRow);


fprintf('\n');


fprintf( ...
    'K range                 : %.2f to %.2f\n', ...
    min(K_VALUES), ...
    max(K_VALUES));


fprintf( ...
    'K increment             : %.2f\n', ...
    K_VALUES(2)-K_VALUES(1));


fprintf('\n');


fprintf( ...
    'Output root:\n%s\n\n', ...
    OUTPUT_ROOT);


fprintf( ...
    'Audit workbook:\n%s\n', ...
    AUDIT_XLSX);


fprintf('=============================================================\n');