%% ========================================================================
% Step0B_radius_Overlap_Triggering_Rainfall_Extraction_NO_FUNCTIONS.m
%
% UPDATED TRIGGERING-RAINFALL EXTRACTION
%
% Landslide dataset:
%   - station-radius station radius
%   - catalogue duplicates already removed
%   - cross-station overlap intentionally RETAINED
%   - study period 2007-2021
%
% For each landslide:
%
%   1. Search rainfall during previous 20 days including landslide day.
%   2. Identify consecutive rainy-day sequences.
%   3. Calculate:
%        - rainfall-event start
%        - rainfall-event end
%        - cumulative rainfall
%        - rainfall-event duration
%        - lag between rainfall-event END and landslide
%   4. Select rainfall event closest to landslide.
%   5. Accept only when lag < 10 days.
%
%
% OUTPUT TXT FORMAT
% -------------------------------------------------------------------------
% year   month   day   triggering_rainfall   lag_days
%
% If no qualifying rainfall event:
%
% landslide_year   landslide_month   landslide_day   0   0
%
%
% IMPORTANT
% -------------------------------------------------------------------------
% NO USER-DEFINED FUNCTIONS ARE USED IN THIS SCRIPT.
%
% ========================================================================

clc;
clear;
close all;


%% ========================================================================
% 1. PATHS
%% ========================================================================

% Updated station-radius landslide files
land_path = ...
    fullfile(neh_root(),'step_0_landslide_filtering','radius_station_txt_ALLOW_OVERLAP');


% Daily rainfall
Rain_STN_path = ...
    fullfile(neh_root(),'3_rainfall_events_thresholds','rainfall_data_threshold_applied');


% Output
output_base_path = ...
    fullfile(neh_root(),'step_0_landslide_filtering','radius_triggering_rainfall_ALLOW_OVERLAP');


if ~exist(output_base_path,'dir')
    mkdir(output_base_path);
end


%% ========================================================================
% 2. CONFIGURATION
%% ========================================================================

YR_START = 2007;
YR_END   = 2021;


% Search rainfall in preceding 20 days
RAIN_LOOKBACK_DAYS = 20;


% Rainfall event must finish less than 10 days before landslide
MAX_TRIGGER_GAP_DAYS = 10;


fprintf('\n');
fprintf('=============================================================\n');
fprintf(' UPDATED TRIGGERING-RAINFALL EXTRACTION\n');
fprintf('=============================================================\n');
fprintf('Landslide radius      : station radius\n');
fprintf('Station overlap       : RETAINED\n');
fprintf('Catalogue duplicates  : previously removed\n');
fprintf('Study period          : %d-%d\n',YR_START,YR_END);
fprintf('Rain lookback         : %d days\n',RAIN_LOOKBACK_DAYS);
fprintf('Maximum trigger gap   : <%d days\n',MAX_TRIGGER_GAP_DAYS);
fprintf('=============================================================\n\n');


%% ========================================================================
% 3. READ LANDSLIDE FILE LIST
%% ========================================================================

LandFiles = dir( ...
    fullfile(land_path,'*_landslides.txt'));


LandFiles = LandFiles( ...
    ~[LandFiles.isdir]);


nStations = numel(LandFiles);


fprintf( ...
    'Landslide station files found: %d\n\n', ...
    nStations);


if nStations == 0

    error( ...
        'No landslide files found in:\n%s', ...
        land_path);

end


%% ========================================================================
% 4. READ RAINFALL FILE LIST ONCE
%% ========================================================================

RainFiles = dir( ...
    fullfile(Rain_STN_path,'*.txt'));


RainFiles = RainFiles( ...
    ~[RainFiles.isdir]);


RainFileNames = string( ...
    {RainFiles.name})';


if isempty(RainFileNames)

    error( ...
        'No rainfall TXT files found in:\n%s', ...
        Rain_STN_path);

end


%% ========================================================================
% 5. PREALLOCATE SUMMARY
%% ========================================================================

SummaryStation = strings(nStations,1);

SummaryID = strings(nStations,1);

N_Landslides = zeros(nStations,1);

N_TriggerFound = zeros(nStations,1);

N_NoTrigger = zeros(nStations,1);

MeanTriggerLag_days = nan(nStations,1);

ProcessingStatus = strings(nStations,1);


% Combined event-level audit
AuditAll = table();


%% ========================================================================
% 6. LOOP THROUGH LANDSLIDE STATIONS
%% ========================================================================

for idx = 1:nStations


    %% --------------------------------------------------------------------
    % 6A. LANDSLIDE FILE
    %% --------------------------------------------------------------------

    landFileName = ...
        LandFiles(idx).name;


    landFile = fullfile( ...
        land_path, ...
        landFileName);


    [~,landBase,~] = ...
        fileparts(landFileName);


    %% --------------------------------------------------------------------
    % Extract station ID
    %
    % Expected filename:
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
            'Unable to identify station ID from %s', ...
            landFileName);


        ProcessingStatus(idx) = ...
            "Station ID not identified";


        continue

    end


    stationID = ...
        string(idToken{1});


    %% --------------------------------------------------------------------
    % Extract station name
    %% --------------------------------------------------------------------

    stationNameChar = regexprep( ...
        landBase, ...
        ['_' char(stationID) '_landslides$'], ...
        '');


    stationName = replace( ...
        string(stationNameChar), ...
        '_',' ');


    SummaryStation(idx) = ...
        stationName;


    SummaryID(idx) = ...
        stationID;


    fprintf('\n');
    fprintf('-------------------------------------------------------------\n');

    fprintf( ...
        '%s | ID = %s\n', ...
        stationName, ...
        stationID);

    fprintf('-------------------------------------------------------------\n');


    %% ====================================================================
    % 6B. FIND CORRESPONDING RAINFALL FILE
    %
    % No assumption about directory order.
    %% ====================================================================

    rainFile = "";


    %% --------------------------------------------------------------------
    % Method 1:
    % exact station ID filename
    %
    % Example:
    % 326239204.txt
    %% --------------------------------------------------------------------

    exactMatch = ...
        lower(RainFileNames) == ...
        lower(stationID + ".txt");


    if sum(exactMatch) == 1

        rainFile = ...
            RainFileNames(exactMatch);

    end


    %% --------------------------------------------------------------------
    % Method 2:
    % station ID appearing as complete numeric token
    %% --------------------------------------------------------------------

    if strlength(rainFile) == 0


        escapedID = regexptranslate( ...
            'escape', ...
            char(stationID));


        IDpattern = ...
            ['(^|[^0-9])' ...
             escapedID ...
             '([^0-9]|$)'];


        IDmatch = ...
            false(numel(RainFileNames),1);


        for rf = 1:numel(RainFileNames)


            IDmatch(rf) = ...
                ~isempty( ...
                regexp( ...
                char(RainFileNames(rf)), ...
                IDpattern, ...
                'once'));

        end


        if sum(IDmatch) == 1

            rainFile = ...
                RainFileNames(IDmatch);

        end

    end


    %% --------------------------------------------------------------------
    % Method 3:
    % cleaned station-name match
    %% --------------------------------------------------------------------

    if strlength(rainFile) == 0


        cleanStation = lower( ...
            regexprep( ...
            char(stationName), ...
            '[^a-zA-Z0-9]', ...
            ''));


        stationNameMatch = ...
            false(numel(RainFileNames),1);


        for rf = 1:numel(RainFileNames)


            cleanRainFile = lower( ...
                regexprep( ...
                char(RainFileNames(rf)), ...
                '[^a-zA-Z0-9]', ...
                ''));


            stationNameMatch(rf) = ...
                contains( ...
                cleanRainFile, ...
                cleanStation);

        end


        if sum(stationNameMatch) == 1

            rainFile = ...
                RainFileNames(stationNameMatch);

        end

    end


    %% --------------------------------------------------------------------
    % Method 4:
    % broad station-ID match
    %% --------------------------------------------------------------------

    if strlength(rainFile) == 0


        broadMatch = contains( ...
            lower(RainFileNames), ...
            lower(stationID));


        if sum(broadMatch) == 1

            rainFile = ...
                RainFileNames(broadMatch);

        end

    end


    %% --------------------------------------------------------------------
    % Still no unique rainfall file
    %% --------------------------------------------------------------------

    if strlength(rainFile) == 0


        warning( ...
            'No unique rainfall file found for %s (%s).', ...
            stationName, ...
            stationID);


        ProcessingStatus(idx) = ...
            "Rainfall file not found";


        continue

    end


    fprintf( ...
        'Rain file: %s\n', ...
        rainFile);


    rainFullPath = fullfile( ...
        Rain_STN_path, ...
        char(rainFile));


    [~,rainBase,~] = ...
        fileparts(char(rainFile));


    %% ====================================================================
    % 6C. READ LANDSLIDE DATA
    %% ====================================================================

    slide_data = readmatrix( ...
        landFile);


    if isempty(slide_data) || ...
            size(slide_data,2) < 6


        warning( ...
            'Invalid landslide file: %s', ...
            landFileName);


        ProcessingStatus(idx) = ...
            "Invalid landslide file";


        continue

    end


    %% --------------------------------------------------------------------
    % Landslide file:
    %
    % col 1 = longitude
    % col 2 = latitude
    % col 3 = great-circle distance
    % col 4 = year
    % col 5 = month
    % col 6 = day
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


        ProcessingStatus(idx) = ...
            "No valid landslides";


        continue

    end


    T_slides = datetime( ...
        slide_data(:,4), ...
        slide_data(:,5), ...
        slide_data(:,6));


    %% --------------------------------------------------------------------
    % Restrict to 2007-2021
    %% --------------------------------------------------------------------

    keepSlide = ...
        year(T_slides) >= YR_START & ...
        year(T_slides) <= YR_END;


    slide_data = ...
        slide_data(keepSlide,:);


    T_slides = ...
        T_slides(keepSlide);


    %% --------------------------------------------------------------------
    % Sort landslides chronologically
    %% --------------------------------------------------------------------

    [T_slides,slideOrder] = ...
        sort(T_slides);


    slide_data = ...
        slide_data(slideOrder,:);


    nSlides = ...
        numel(T_slides);


    N_Landslides(idx) = ...
        nSlides;


    fprintf( ...
        'Landslides processed: %d\n', ...
        nSlides);


    if nSlides == 0


        ProcessingStatus(idx) = ...
            "No landslides in study period";


        continue

    end


    %% ====================================================================
    % 6D. READ DAILY RAINFALL
    %% ====================================================================

    Rain_STN = readmatrix( ...
        rainFullPath);


    if isempty(Rain_STN) || ...
            size(Rain_STN,2) < 4


        warning( ...
            'Invalid rainfall file: %s', ...
            rainFile);


        ProcessingStatus(idx) = ...
            "Invalid rainfall file";


        continue

    end


    %% --------------------------------------------------------------------
    % Rainfall:
    %
    % col 1 = year
    % col 2 = month
    % col 3 = day
    % col 4 = daily rainfall
    %% --------------------------------------------------------------------

    validRain = ...
        isfinite(Rain_STN(:,1)) & ...
        isfinite(Rain_STN(:,2)) & ...
        isfinite(Rain_STN(:,3)) & ...
        isfinite(Rain_STN(:,4));


    Rain_STN = ...
        Rain_STN(validRain,:);


    if isempty(Rain_STN)


        ProcessingStatus(idx) = ...
            "No valid rainfall";


        continue

    end


    T_rain = datetime( ...
        Rain_STN(:,1), ...
        Rain_STN(:,2), ...
        Rain_STN(:,3));


    RainValue = ...
        Rain_STN(:,4);


    %% --------------------------------------------------------------------
    % Sort rainfall chronologically
    %% --------------------------------------------------------------------

    [T_rain,rainOrder] = ...
        sort(T_rain);


    RainValue = ...
        RainValue(rainOrder);


    %% --------------------------------------------------------------------
    % Remove repeated rainfall dates
    %
    % Keep first occurrence
    %% --------------------------------------------------------------------

    if numel(unique(T_rain)) ~= numel(T_rain)


        warning( ...
            ['Repeated rainfall dates found for %s. ' ...
             'Keeping first occurrence.'], ...
            stationName);


        [T_rain,uniqueRainIdx] = ...
            unique( ...
            T_rain, ...
            'stable');


        RainValue = ...
            RainValue(uniqueRainIdx);

    end


    %% ====================================================================
    % 6E. OUTPUT ARRAYS
    %% ====================================================================

    % Main output:
    %
    % year month day TR lag

    triggerOutput = ...
        zeros(nSlides,5);


    % Detailed audit

    RainStart = ...
        NaT(nSlides,1);


    RainEnd = ...
        NaT(nSlides,1);


    RainTotal = ...
        zeros(nSlides,1);


    RainDuration_days = ...
        zeros(nSlides,1);


    TriggerLag_days = ...
        nan(nSlides,1);


    TriggerFound = ...
        false(nSlides,1);


    NumberRainEventsInWindow = ...
        zeros(nSlides,1);


    %% ====================================================================
    % 6F. PROCESS EACH LANDSLIDE
    %% ====================================================================

    for jdx = 1:nSlides


        landslideDate = ...
            T_slides(jdx);


        %% ----------------------------------------------------------------
        % Default:
        %
        % if no rainfall trigger found,
        % write landslide date + zeros
        %% ----------------------------------------------------------------

        triggerOutput(jdx,:) = [ ...
            year(landslideDate), ...
            month(landslideDate), ...
            day(landslideDate), ...
            0, ...
            0];


        %% ----------------------------------------------------------------
        % Search rainfall window
        %% ----------------------------------------------------------------

        windowStart = ...
            landslideDate - ...
            days(RAIN_LOOKBACK_DAYS);


        windowEnd = ...
            landslideDate;


        inWindow = ...
            T_rain >= windowStart & ...
            T_rain <= windowEnd;


        Pdate = ...
            T_rain(inWindow);


        P = ...
            RainValue(inWindow);


        %% ----------------------------------------------------------------
        % No rainfall observations
        %% ----------------------------------------------------------------

        if isempty(P)

            continue

        end


        %% ----------------------------------------------------------------
        % Rainy days
        %% ----------------------------------------------------------------

        rainy = ...
            isfinite(P) & ...
            P > 0;


        if ~any(rainy)

            continue

        end


        rainDates = ...
            Pdate(rainy);


        rainAmount = ...
            P(rainy);


        %% ----------------------------------------------------------------
        % Sort rainy days
        %% ----------------------------------------------------------------

        [rainDates,rainEventOrder] = ...
            sort(rainDates);


        rainAmount = ...
            rainAmount(rainEventOrder);


        %% ----------------------------------------------------------------
        % Identify consecutive rainy-day events
        %
        % New event begins when gap > 1 day
        %% ----------------------------------------------------------------

        if numel(rainDates) == 1


            newRainEvent = true;


        else


            dayGap = ...
                days(diff(rainDates));


            newRainEvent = [ ...
                true; ...
                dayGap > 1];

        end


        rainEventGroup = ...
            cumsum(newRainEvent);


        nRainEvents = ...
            max(rainEventGroup);


        NumberRainEventsInWindow(jdx) = ...
            nRainEvents;


        %% ----------------------------------------------------------------
        % Preallocate rain-event properties
        %% ----------------------------------------------------------------

        eventStart = ...
            NaT(nRainEvents,1);


        eventEnd = ...
            NaT(nRainEvents,1);


        eventTotal = ...
            nan(nRainEvents,1);


        eventDuration = ...
            nan(nRainEvents,1);


        eventLag = ...
            nan(nRainEvents,1);


        %% ================================================================
        % Compute each rainfall-event property
        %% ================================================================

        for g = 1:nRainEvents


            thisEvent = ...
                rainEventGroup == g;


            firstIdx = ...
                find(thisEvent,1,'first');


            lastIdx = ...
                find(thisEvent,1,'last');


            eventStart(g) = ...
                rainDates(firstIdx);


            eventEnd(g) = ...
                rainDates(lastIdx);


            eventTotal(g) = ...
                sum( ...
                rainAmount(thisEvent), ...
                'omitnan');


            eventDuration(g) = ...
                sum(thisEvent);


            eventLag(g) = ...
                days( ...
                landslideDate - ...
                eventEnd(g));

        end


        %% ----------------------------------------------------------------
        % Valid triggering rainfall candidates
        %% ----------------------------------------------------------------

        validCandidate = ...
            eventLag >= 0 & ...
            eventLag < MAX_TRIGGER_GAP_DAYS;


        if ~any(validCandidate)

            continue

        end


        candidateIdx = ...
            find(validCandidate);


        candidateLag = ...
            eventLag(candidateIdx);


        %% ----------------------------------------------------------------
        % Select smallest gap
        %% ----------------------------------------------------------------

        minLag = ...
            min(candidateLag);


        closestEvents = ...
            candidateIdx( ...
            candidateLag == minLag);


        %% ----------------------------------------------------------------
        % Tie-break:
        % if same lag, select larger rainfall total
        %% ----------------------------------------------------------------

        if numel(closestEvents) > 1


            [~,maxRainPos] = ...
                max( ...
                eventTotal(closestEvents));


            selectedEvent = ...
                closestEvents(maxRainPos);


        else


            selectedEvent = ...
                closestEvents(1);

        end


        %% ================================================================
        % SAVE SELECTED EVENT
        %% ================================================================

        RainStart(jdx) = ...
            eventStart(selectedEvent);


        RainEnd(jdx) = ...
            eventEnd(selectedEvent);


        RainTotal(jdx) = ...
            eventTotal(selectedEvent);


        RainDuration_days(jdx) = ...
            eventDuration(selectedEvent);


        TriggerLag_days(jdx) = ...
            eventLag(selectedEvent);


        TriggerFound(jdx) = ...
            true;


        %% ----------------------------------------------------------------
        % MAIN TXT output
        %
        % rainfall event START date
        % cumulative TR
        % lag between rainfall END and landslide
        %% ----------------------------------------------------------------

        triggerOutput(jdx,:) = [ ...
            year(RainStart(jdx)), ...
            month(RainStart(jdx)), ...
            day(RainStart(jdx)), ...
            RainTotal(jdx), ...
            TriggerLag_days(jdx)];

    end


    %% ====================================================================
    % 6G. WRITE STATION TRIGGERING TXT
    %
    % FIXED VERSION:
    % filename is guaranteed to be ONE character vector.
    %% ====================================================================

    outputFileName = sprintf( ...
        '%strigging_duration.txt', ...
        rainBase);


    outputTXT = fullfile( ...
        output_base_path, ...
        outputFileName);


    fprintf('\nWriting output:\n%s\n', ...
        outputTXT);


    writematrix( ...
        triggerOutput, ...
        outputTXT, ...
        'Delimiter','tab');


    fprintf( ...
        'Trigger TXT successfully written.\n');


    %% ====================================================================
    % 6H. STATION SUMMARY
    %% ====================================================================

    N_TriggerFound(idx) = ...
        sum(TriggerFound);


    N_NoTrigger(idx) = ...
        nSlides - ...
        N_TriggerFound(idx);


    if any(TriggerFound)


        MeanTriggerLag_days(idx) = ...
            mean( ...
            TriggerLag_days(TriggerFound), ...
            'omitnan');

    end


    ProcessingStatus(idx) = ...
        "OK";


    fprintf( ...
        'Triggering rainfall identified: %d/%d\n', ...
        N_TriggerFound(idx), ...
        nSlides);


    fprintf( ...
        'No qualifying trigger         : %d/%d\n', ...
        N_NoTrigger(idx), ...
        nSlides);


    %% ====================================================================
    % 6I. EVENT-LEVEL AUDIT
    %% ====================================================================

    Station = ...
        repmat(stationName,nSlides,1);


    IMD_ID = ...
        repmat(stationID,nSlides,1);


    LandslideLongitude = ...
        slide_data(:,1);


    LandslideLatitude = ...
        slide_data(:,2);


    DistanceFromStation_km = ...
        slide_data(:,3);


    LandslideDate = ...
        T_slides;


    SearchWindowStart = ...
        T_slides - ...
        days(RAIN_LOOKBACK_DAYS);


    SearchWindowEnd = ...
        T_slides;


    AuditStation = table( ...
        Station, ...
        IMD_ID, ...
        LandslideLongitude, ...
        LandslideLatitude, ...
        DistanceFromStation_km, ...
        LandslideDate, ...
        SearchWindowStart, ...
        SearchWindowEnd, ...
        NumberRainEventsInWindow, ...
        RainStart, ...
        RainEnd, ...
        RainDuration_days, ...
        RainTotal, ...
        TriggerLag_days, ...
        TriggerFound);


    AuditAll = [ ...
        AuditAll; ...
        AuditStation]; %#ok<AGROW>


end


%% ========================================================================
% 7. REMOVE EMPTY SUMMARY ROWS
%% ========================================================================

validSummary = ...
    strlength(SummaryStation) > 0;


SummaryStation = ...
    SummaryStation(validSummary);


SummaryID = ...
    SummaryID(validSummary);


N_Landslides = ...
    N_Landslides(validSummary);


N_TriggerFound = ...
    N_TriggerFound(validSummary);


N_NoTrigger = ...
    N_NoTrigger(validSummary);


MeanTriggerLag_days = ...
    MeanTriggerLag_days(validSummary);


ProcessingStatus = ...
    ProcessingStatus(validSummary);


%% ========================================================================
% 8. STATION SUMMARY TABLE
%% ========================================================================

Summary = table( ...
    SummaryStation, ...
    SummaryID, ...
    N_Landslides, ...
    N_TriggerFound, ...
    N_NoTrigger, ...
    MeanTriggerLag_days, ...
    ProcessingStatus, ...
    'VariableNames',{ ...
    'Station', ...
    'IMD_ID', ...
    'N_landslide_points_radius', ...
    'N_triggering_rainfall_identified', ...
    'N_without_qualifying_trigger', ...
    'Mean_trigger_lag_days', ...
    'Processing_status'});


%% ========================================================================
% 9. WRITE AUDIT EXCEL
%% ========================================================================

AUDIT_XLSX = fullfile( ...
    output_base_path, ...
    'Triggering_Rainfall_Audit_radius_OVERLAP.xlsx');


if isfile(AUDIT_XLSX)

    delete(AUDIT_XLSX);

end


writetable( ...
    Summary, ...
    AUDIT_XLSX, ...
    'Sheet','Station_summary');


if ~isempty(AuditAll)

    writetable( ...
        AuditAll, ...
        AUDIT_XLSX, ...
        'Sheet','Event_level');

end


%% ========================================================================
% 10. FINAL SUMMARY
%% ========================================================================

fprintf('\n');
fprintf('=============================================================\n');
fprintf(' TRIGGERING-RAINFALL EXTRACTION COMPLETE\n');
fprintf('=============================================================\n');


fprintf( ...
    'Station files found                : %d\n', ...
    nStations);


fprintf( ...
    'Stations successfully processed    : %d\n', ...
    sum(ProcessingStatus == "OK"));


fprintf( ...
    'Total station-landslide records    : %d\n', ...
    sum(N_Landslides));


fprintf( ...
    'Triggering rainfall identified     : %d\n', ...
    sum(N_TriggerFound));


fprintf( ...
    'Without qualifying rainfall trigger: %d\n', ...
    sum(N_NoTrigger));


if sum(N_Landslides) > 0

    triggerPct = ...
        100 * ...
        sum(N_TriggerFound) / ...
        sum(N_Landslides);


    fprintf( ...
        'Trigger identification rate      : %.1f %%\n', ...
        triggerPct);

end


fprintf('\n');


fprintf( ...
    'Output folder:\n%s\n\n', ...
    output_base_path);


fprintf( ...
    'Audit workbook:\n%s\n', ...
    AUDIT_XLSX);


fprintf('=============================================================\n');