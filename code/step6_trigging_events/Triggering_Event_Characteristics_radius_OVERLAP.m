%% ========================================================================
% Step6_Triggering_Event_Characteristics_radius_OVERLAP.m
%
% PURPOSE
% -------------------------------------------------------------------------
% Recalculate triggering-rainfall characteristics for the UPDATED
% landslide catalogue:
%
%   - station-radius station radius
%   - catalogue duplicates previously removed
%   - cross-station overlap RETAINED
%   - all 21 NEH stations
%   - study period 2007-2021
%
%
% FOR EACH LANDSLIDE:
% -------------------------------------------------------------------------
% 1. Search rainfall during the 20 days preceding the landslide,
%    including the landslide day.
%
% 2. Identify consecutive rainy-day sequences (rainfall > 0).
%
% 3. For every rainfall sequence calculate:
%
%       rainfall-event start date
%       rainfall-event end date
%       cumulative triggering rainfall
%       rainfall-event duration
%       lag = landslide date - rainfall-event end date
%
% 4. Select the rainfall event having the SMALLEST lag.
%
% 5. Accept the rainfall event only when:
%
%       0 <= lag < 10 days
%
%
% OUTPUT TXT FORMAT
% -------------------------------------------------------------------------
%
% Col 1 = Landslide year
% Col 2 = Landslide month
% Col 3 = Landslide day
% Col 4 = Triggering rainfall total
% Col 5 = Lag from rainfall-event END to landslide (days)
% Col 6 = Duration of selected rainfall event (days)
%
%
% Example:
%
% 2015    7    18    126.4    1    4
%
%
% IMPORTANT
% -------------------------------------------------------------------------
% Catalogue duplicates were removed previously.
%
% Station-buffer overlap is RETAINED.
%
% Therefore, the same unique physical landslide may intentionally occur
% in two station files if it lies within station radius of both stations.
%
% NO USER-DEFINED FUNCTIONS.
%
% ========================================================================

clc;
clear;
close all;


%% ========================================================================
% 1. PATHS
%% ========================================================================

% -------------------------------------------------------------------------
% UPDATED station-radius landslide files
% -------------------------------------------------------------------------

land_path = ...
    fullfile(neh_root(),'step_0_landslide_filtering','radius_station_txt_ALLOW_OVERLAP');


% -------------------------------------------------------------------------
% DAILY RAINFALL
% -------------------------------------------------------------------------

Rain_STN_path = ...
    fullfile(neh_root(),'3_rainfall_events_thresholds','rainfall_data_threshold_applied');


% -------------------------------------------------------------------------
% REVISION ROOT
% -------------------------------------------------------------------------

REVISION_ROOT = ...
    fullfile(neh_root());


% -------------------------------------------------------------------------
% OUTPUT
% -------------------------------------------------------------------------

OUTPUT_DIR = fullfile( ...
    REVISION_ROOT, ...
    'step_6_triggering_event_characteristics_radius_ALLOW_OVERLAP');


if ~exist(OUTPUT_DIR,'dir')

    mkdir(OUTPUT_DIR);

end


%% ========================================================================
% 2. CONFIGURATION
%% ========================================================================

YR_START = 2007;

YR_END = 2021;


% Rainfall search window
RAIN_LOOKBACK_DAYS = 20;


% Rainfall-event end must occur <10 days before landslide
MAX_TRIGGER_GAP_DAYS = 10;


fprintf('\n');
fprintf('=============================================================\n');
fprintf(' UPDATED TRIGGERING-RAINFALL CHARACTERISTICS\n');
fprintf('=============================================================\n');

fprintf('Landslide radius      : station radius\n');

fprintf('Station overlap       : RETAINED\n');

fprintf('Catalogue duplicates  : previously removed\n');

fprintf( ...
    'Study period         : %d-%d\n', ...
    YR_START,YR_END);

fprintf( ...
    'Rainfall lookback    : %d days\n', ...
    RAIN_LOOKBACK_DAYS);

fprintf( ...
    'Maximum trigger gap  : <%d days\n', ...
    MAX_TRIGGER_GAP_DAYS);

fprintf( ...
    'Output directory:\n%s\n', ...
    OUTPUT_DIR);

fprintf('=============================================================\n\n');


%% ========================================================================
% 3. READ UPDATED LANDSLIDE FILE LIST
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
        'No updated station-radius landslide files found.');

end


if nStations ~= 21

    warning( ...
        'Expected 21 stations but found %d.', ...
        nStations);

end


%% ========================================================================
% 4. READ RAINFALL FILE LIST
%% ========================================================================

RainFiles = dir( ...
    fullfile( ...
    Rain_STN_path, ...
    '*.txt'));


RainFiles = ...
    RainFiles(~[RainFiles.isdir]);


RainFileNames = ...
    string({RainFiles.name})';


if isempty(RainFileNames)

    error( ...
        'No rainfall files found in rainfall directory.');

end


%% ========================================================================
% 5. SUMMARY STORAGE
%% ========================================================================

SummaryStation = ...
    strings(nStations,1);


SummaryID = ...
    strings(nStations,1);


SummaryLandslides = ...
    zeros(nStations,1);


SummaryTriggerFound = ...
    zeros(nStations,1);


SummaryNoTrigger = ...
    zeros(nStations,1);


SummaryMeanRainfall = ...
    nan(nStations,1);


SummaryMeanDuration = ...
    nan(nStations,1);


SummaryMeanLag = ...
    nan(nStations,1);


SummaryMissingRainDays = ...
    zeros(nStations,1);


SummaryStatus = ...
    strings(nStations,1);


% Combined detailed audit
AuditAll = table();


%% ========================================================================
% 6. LOOP THROUGH ALL STATIONS
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
    % Extract IMD ID
    %
    % Example:
    %
    % Aizwal_326239204_landslides.txt
    %% --------------------------------------------------------------------

    idToken = regexp( ...
        landFileName, ...
        '_(\d+)_landslides\.txt$', ...
        'tokens', ...
        'once');


    if isempty(idToken)


        warning( ...
            'Cannot identify station ID from %s.', ...
            landFileName);


        SummaryStatus(idx) = ...
            "Station ID not identified";


        continue

    end


    stationID = ...
        string(idToken{1});


    %% --------------------------------------------------------------------
    % Station name
    %% --------------------------------------------------------------------

    stationRaw = regexprep( ...
        landBase, ...
        ['_' char(stationID) '_landslides$'], ...
        '');


    stationName = replace( ...
        string(stationRaw), ...
        '_', ...
        ' ');


    SummaryStation(idx) = ...
        stationName;


    SummaryID(idx) = ...
        stationID;


    fprintf('\n');
    fprintf('=============================================================\n');

    fprintf( ...
        '%s | IMD ID = %s\n', ...
        stationName, ...
        stationID);

    fprintf('=============================================================\n');


    %% ====================================================================
    % 7. FIND CORRECT RAINFALL FILE USING STATION ID
    %% ====================================================================

    expectedRainFile = ...
        stationID + ".txt";


    exactMatch = ...
        lower(RainFileNames) == ...
        lower(expectedRainFile);


    if sum(exactMatch) == 1


        rainFileName = ...
            RainFileNames(exactMatch);


    else


        % ---------------------------------------------------------------
        % Fallback:
        % station ID anywhere in filename
        % ---------------------------------------------------------------

        idMatch = contains( ...
            lower(RainFileNames), ...
            lower(stationID));


        if sum(idMatch) == 1


            rainFileName = ...
                RainFileNames(idMatch);


        else


            warning( ...
                'No unique rainfall file found for station %s.', ...
                stationID);


            SummaryStatus(idx) = ...
                "Rainfall file not found";


            continue

        end

    end


    rainFileFull = fullfile( ...
        Rain_STN_path, ...
        char(rainFileName));


    fprintf( ...
        'Rainfall file: %s\n', ...
        rainFileName);


    %% ====================================================================
    % 8. READ LANDSLIDE DATA
    %% ====================================================================

    slide_data = readmatrix( ...
        landFileFull);


    if isempty(slide_data) || ...
            size(slide_data,2) < 6


        warning( ...
            'Invalid landslide file: %s.', ...
            landFileName);


        SummaryStatus(idx) = ...
            "Invalid landslide file";


        continue

    end


    %% --------------------------------------------------------------------
    % Updated landslide TXT:
    %
    % col 1 longitude
    % col 2 latitude
    % col 3 distance_km
    % col 4 year
    % col 5 month
    % col 6 day
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


    if isempty(slide_data)


        warning( ...
            'No valid landslide rows for %s.', ...
            stationName);


        SummaryStatus(idx) = ...
            "No valid landslides";


        continue

    end


    slideDate = datetime( ...
        slide_data(:,4), ...
        slide_data(:,5), ...
        slide_data(:,6));


    %% --------------------------------------------------------------------
    % Study period
    %% --------------------------------------------------------------------

    keepPeriod = ...
        year(slideDate) >= YR_START & ...
        year(slideDate) <= YR_END;


    slide_data = ...
        slide_data(keepPeriod,:);


    slideDate = ...
        slideDate(keepPeriod);


    %% --------------------------------------------------------------------
    % Sort landslide events chronologically
    %% --------------------------------------------------------------------

    [slideDate,slideOrder] = ...
        sort(slideDate);


    slide_data = ...
        slide_data(slideOrder,:);


    nSlides = ...
        numel(slideDate);


    SummaryLandslides(idx) = ...
        nSlides;


    fprintf( ...
        'Landslides processed: %d\n', ...
        nSlides);


    if nSlides == 0


        SummaryStatus(idx) = ...
            "No landslides in period";


        continue

    end


    %% ====================================================================
    % 9. READ RAINFALL
    %% ====================================================================

    Rain_STN = readmatrix( ...
        rainFileFull);


    if isempty(Rain_STN) || ...
            size(Rain_STN,2) < 4


        warning( ...
            'Invalid rainfall file for %s.', ...
            stationName);


        SummaryStatus(idx) = ...
            "Invalid rainfall file";


        continue

    end


    %% --------------------------------------------------------------------
    % Rainfall format:
    %
    % col 1 year
    % col 2 month
    % col 3 day
    % col 4 rainfall
    %% --------------------------------------------------------------------

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
    % Duplicate rainfall dates
    %% --------------------------------------------------------------------

    if numel(unique(rainDate)) ~= numel(rainDate)


        warning( ...
            ['Repeated rainfall dates found for %s. ' ...
             'First occurrence retained.'], ...
            stationName);


        [rainDate,uniqueRainIdx] = ...
            unique( ...
            rainDate, ...
            'stable');


        rainValue = ...
            rainValue(uniqueRainIdx);

    end


    %% ====================================================================
    % 10. PREALLOCATE OUTPUT
    %% ====================================================================

    % Same six-column format as old sx:
    %
    % LS_Y LS_M LS_D TR lag duration

    sx = ...
        zeros(nSlides,6);


    TriggerStart = ...
        NaT(nSlides,1);


    TriggerEnd = ...
        NaT(nSlides,1);


    TriggerRainfall = ...
        zeros(nSlides,1);


    TriggerLag = ...
        nan(nSlides,1);


    TriggerDuration = ...
        zeros(nSlides,1);


    TriggerFound = ...
        false(nSlides,1);


    N_RainEvents = ...
        zeros(nSlides,1);


    MissingRainDays = ...
        zeros(nSlides,1);


    %% ====================================================================
    % 11. LOOP THROUGH LANDSLIDES
    %% ====================================================================

    for jdx = 1:nSlides


        landslideDate = ...
            slideDate(jdx);


        %% ----------------------------------------------------------------
        % Default output when no trigger is identified
        %% ----------------------------------------------------------------

        sx(jdx,:) = [ ...
            year(landslideDate), ...
            month(landslideDate), ...
            day(landslideDate), ...
            0, ...
            0, ...
            0];


        %% ----------------------------------------------------------------
        % 20-day lookback
        %
        % Consistent with old code:
        %
        % landslide-20 through landslide date
        %% ----------------------------------------------------------------

        windowStart = ...
            landslideDate - ...
            days(RAIN_LOOKBACK_DAYS);


        windowEnd = ...
            landslideDate;


        expectedDates = ...
            (windowStart:caldays(1):windowEnd)';


        %% ----------------------------------------------------------------
        % Determine whether rainfall dates exist
        %% ----------------------------------------------------------------

        [datePresent,dateLocation] = ...
            ismember( ...
            expectedDates, ...
            rainDate);


        MissingRainDays(jdx) = ...
            sum(~datePresent);


        %% ----------------------------------------------------------------
        % Build complete rainfall window
        %
        % Missing observations = NaN
        %% ----------------------------------------------------------------

        windowRain = ...
            nan(numel(expectedDates),1);


        windowRain(datePresent) = ...
            rainValue( ...
            dateLocation(datePresent));


        %% ----------------------------------------------------------------
        % Rainy days only
        %% ----------------------------------------------------------------

        rainy = ...
            isfinite(windowRain) & ...
            windowRain > 0;


        if ~any(rainy)

            continue

        end


        rainyDates = ...
            expectedDates(rainy);


        rainyAmounts = ...
            windowRain(rainy);


        %% ----------------------------------------------------------------
        % Identify consecutive rainy-day sequences
        %% ----------------------------------------------------------------

        if numel(rainyDates) == 1


            newEvent = true;


        else


            dayDifference = ...
                days(diff(rainyDates));


            newEvent = [ ...
                true; ...
                dayDifference > 1];

        end


        eventGroup = ...
            cumsum(newEvent);


        nEvents = ...
            max(eventGroup);


        N_RainEvents(jdx) = ...
            nEvents;


        %% ----------------------------------------------------------------
        % Rain-event properties
        %% ----------------------------------------------------------------

        eventStart = ...
            NaT(nEvents,1);


        eventEnd = ...
            NaT(nEvents,1);


        eventRain = ...
            zeros(nEvents,1);


        eventDuration = ...
            zeros(nEvents,1);


        eventLag = ...
            nan(nEvents,1);


        %% ================================================================
        % 12. CALCULATE EACH RAIN-EVENT PROPERTY
        %% ================================================================

        for ee = 1:nEvents


            thisEvent = ...
                eventGroup == ee;


            firstEventRow = ...
                find( ...
                thisEvent, ...
                1, ...
                'first');


            lastEventRow = ...
                find( ...
                thisEvent, ...
                1, ...
                'last');


            %% ------------------------------------------------------------
            % Start
            %% ------------------------------------------------------------

            eventStart(ee) = ...
                rainyDates(firstEventRow);


            %% ------------------------------------------------------------
            % End
            %% ------------------------------------------------------------

            eventEnd(ee) = ...
                rainyDates(lastEventRow);


            %% ------------------------------------------------------------
            % Total rainfall
            %% ------------------------------------------------------------

            eventRain(ee) = ...
                sum( ...
                rainyAmounts(thisEvent), ...
                'omitnan');


            %% ------------------------------------------------------------
            % Number of consecutive rainy days
            %% ------------------------------------------------------------

            eventDuration(ee) = ...
                sum(thisEvent);


            %% ------------------------------------------------------------
            % Gap between rain-event END and landslide
            %% ------------------------------------------------------------

            eventLag(ee) = ...
                days( ...
                landslideDate - ...
                eventEnd(ee));

        end


        %% =================================================================
        % 13. IDENTIFY VALID CANDIDATE EVENTS
        %% =================================================================

        validCandidate = ...
            eventLag >= 0 & ...
            eventLag < MAX_TRIGGER_GAP_DAYS;


        if ~any(validCandidate)

            continue

        end


        candidateRows = ...
            find(validCandidate);


        candidateLag = ...
            eventLag(candidateRows);


        %% ----------------------------------------------------------------
        % Select event closest to landslide
        %% ----------------------------------------------------------------

        minimumLag = ...
            min(candidateLag);


        closestRows = ...
            candidateRows( ...
            candidateLag == minimumLag);


        %% ----------------------------------------------------------------
        % Tie-break:
        %
        % if equal ending lag, choose event having greater rainfall
        %% ----------------------------------------------------------------

        if numel(closestRows) > 1


            [~,tiePosition] = ...
                max( ...
                eventRain(closestRows));


            selected = ...
                closestRows(tiePosition);


        else


            selected = ...
                closestRows(1);

        end


        %% =================================================================
        % 14. SAVE SELECTED TRIGGER EVENT
        %% =================================================================

        TriggerStart(jdx) = ...
            eventStart(selected);


        TriggerEnd(jdx) = ...
            eventEnd(selected);


        TriggerRainfall(jdx) = ...
            eventRain(selected);


        TriggerLag(jdx) = ...
            eventLag(selected);


        TriggerDuration(jdx) = ...
            eventDuration(selected);


        TriggerFound(jdx) = ...
            true;


        %% ----------------------------------------------------------------
        % SIX-COLUMN OUTPUT
        %% ----------------------------------------------------------------

        sx(jdx,:) = [ ...
            year(landslideDate), ...
            month(landslideDate), ...
            day(landslideDate), ...
            TriggerRainfall(jdx), ...
            TriggerLag(jdx), ...
            TriggerDuration(jdx)];

    end


    %% ====================================================================
    % 15. WRITE STATION TXT
    %% ====================================================================

    outputFileName = sprintf( ...
        '%s_trigging.txt', ...
        char(stationID));


    outputFile = fullfile( ...
        OUTPUT_DIR, ...
        outputFileName);


    writematrix( ...
        sx, ...
        outputFile, ...
        'Delimiter','tab');


    fprintf( ...
        'Output: %s\n', ...
        outputFileName);


    %% ====================================================================
    % 16. STATION STATISTICS
    %% ====================================================================

    SummaryTriggerFound(idx) = ...
        sum(TriggerFound);


    SummaryNoTrigger(idx) = ...
        nSlides - ...
        SummaryTriggerFound(idx);


    SummaryMissingRainDays(idx) = ...
        sum(MissingRainDays);


    if any(TriggerFound)


        SummaryMeanRainfall(idx) = ...
            mean( ...
            TriggerRainfall(TriggerFound), ...
            'omitnan');


        SummaryMeanDuration(idx) = ...
            mean( ...
            TriggerDuration(TriggerFound), ...
            'omitnan');


        SummaryMeanLag(idx) = ...
            mean( ...
            TriggerLag(TriggerFound), ...
            'omitnan');

    end


    SummaryStatus(idx) = ...
        "OK";


    fprintf( ...
        'Trigger identified : %d/%d\n', ...
        SummaryTriggerFound(idx), ...
        nSlides);


    fprintf( ...
        'No trigger         : %d/%d\n', ...
        SummaryNoTrigger(idx), ...
        nSlides);


    %% ====================================================================
    % 17. EVENT-LEVEL AUDIT
    %% ====================================================================

    Station = ...
        repmat( ...
        stationName, ...
        nSlides, ...
        1);


    IMD_ID = ...
        repmat( ...
        stationID, ...
        nSlides, ...
        1);


    Longitude = ...
        slide_data(:,1);


    Latitude = ...
        slide_data(:,2);


    Distance_km = ...
        slide_data(:,3);


    LandslideDate = ...
        slideDate;


    SearchWindowStart = ...
        slideDate - ...
        days(RAIN_LOOKBACK_DAYS);


    SearchWindowEnd = ...
        slideDate;


    AuditStation = table( ...
        Station, ...
        IMD_ID, ...
        Longitude, ...
        Latitude, ...
        Distance_km, ...
        LandslideDate, ...
        SearchWindowStart, ...
        SearchWindowEnd, ...
        N_RainEvents, ...
        TriggerStart, ...
        TriggerEnd, ...
        TriggerRainfall, ...
        TriggerLag, ...
        TriggerDuration, ...
        TriggerFound, ...
        MissingRainDays);


    AuditAll = [ ...
        AuditAll; ...
        AuditStation]; %#ok<AGROW>


end


%% ========================================================================
% 18. SUMMARY TABLE
%% ========================================================================

Summary = table( ...
    SummaryStation, ...
    SummaryID, ...
    SummaryLandslides, ...
    SummaryTriggerFound, ...
    SummaryNoTrigger, ...
    SummaryMeanRainfall, ...
    SummaryMeanLag, ...
    SummaryMeanDuration, ...
    SummaryMissingRainDays, ...
    SummaryStatus, ...
    'VariableNames',{ ...
    'Station', ...
    'IMD_ID', ...
    'N_landslides_radius', ...
    'N_trigger_identified', ...
    'N_without_trigger', ...
    'Mean_triggering_rainfall', ...
    'Mean_trigger_lag_days', ...
    'Mean_trigger_duration_days', ...
    'Missing_daily_rainfall_records', ...
    'Status'});


%% ========================================================================
% 19. WRITE AUDIT EXCEL
%% ========================================================================

AUDIT_FILE = fullfile( ...
    OUTPUT_DIR, ...
    'Triggering_Event_Characteristics_radius_Audit.xlsx');


if isfile(AUDIT_FILE)

    delete(AUDIT_FILE);

end


writetable( ...
    Summary, ...
    AUDIT_FILE, ...
    'Sheet','Station_summary');


if ~isempty(AuditAll)


    writetable( ...
        AuditAll, ...
        AUDIT_FILE, ...
        'Sheet','Event_level');

end


%% ========================================================================
% 20. FINAL SUMMARY
%% ========================================================================

fprintf('\n');
fprintf('=============================================================\n');
fprintf(' PROCESSING COMPLETE\n');
fprintf('=============================================================\n');


fprintf( ...
    'Stations detected             : %d\n', ...
    nStations);


fprintf( ...
    'Stations processed            : %d\n', ...
    sum(SummaryStatus == "OK"));


fprintf( ...
    'Total station-landslide rows  : %d\n', ...
    sum(SummaryLandslides));


fprintf( ...
    'Triggers identified           : %d\n', ...
    sum(SummaryTriggerFound));


fprintf( ...
    'No qualifying trigger         : %d\n', ...
    sum(SummaryNoTrigger));


if sum(SummaryLandslides) > 0


    fprintf( ...
        'Trigger identification rate : %.1f %%\n', ...
        100 * ...
        sum(SummaryTriggerFound) / ...
        sum(SummaryLandslides));

end


fprintf('\n');


fprintf( ...
    'Output directory:\n%s\n\n', ...
    OUTPUT_DIR);


fprintf( ...
    'Audit workbook:\n%s\n', ...
    AUDIT_FILE);


fprintf('=============================================================\n');