%% ========================================================================
% UPDATED ED-THRESHOLD INPUT PREPARATION
%
% PURPOSE
% -------------------------------------------------------------------------
% For each station:
%
%   1. Read updated independently selected N* from Step 7.
%   2. Read updated last day of triggering rainfall.
%   3. Read updated daily rainfall series.
%   4. Extract antecedent rainfall events within the selected N* window.
%   5. Read updated triggering-event characteristics.
%   6. Save:
%
%       Sheet "ap"        -> antecedent precipitation events
%                            [event precipitation, duration]
%
%       Sheet "trigging"  -> triggering events
%                            [triggering rainfall, duration]
%
%
% UPDATED STUDY PERIOD
%       2007-2021
%
%
% UPDATED LANDSLIDE WORKFLOW
%       station-radius station assignment
%       catalogue duplicates removed upstream
%       cross-station overlapping events retained upstream
%
% ========================================================================

clc;
clear;
close all;


%% ========================================================================
% 1. ROOT PATHS
%% ========================================================================

ROOT = ...
    fullfile(neh_root());


REV_ROOT = fullfile( ...
    ROOT, ...
    'revision_round1');


%% ========================================================================
% 2. UPDATED LAST-DAY-OF-TRIGGERING PATH
%% ========================================================================

%% ========================================================================
% UPDATED LAST-DAY-OF-TRIGGERING PATH
%% ========================================================================

land_path_1 = fullfile( ...
    REV_ROOT, ...
    'step4_last_day_of_trigging', ...
    'radius_triggering_rainfall_ALLOW_OVERLAP');

land_path_2 = fullfile( ...
    REV_ROOT, ...
    'step_4_last_day_of_trigging', ...
    'radius_triggering_rainfall_ALLOW_OVERLAP');


if exist(land_path_1,'dir')

    land_path = land_path_1;

elseif exist(land_path_2,'dir')

    land_path = land_path_2;

else

    error( ...
        ['Last-trigger-day folder not found.' newline ...
         'Checked:' newline ...
         '%s' newline ...
         'and:' newline ...
         '%s'], ...
        land_path_1, ...
        land_path_2);

end


fprintf('Last-trigger-day folder found:\n%s\n\n',land_path);

%% ========================================================================
% 3. UPDATED DAILY RAINFALL PATH
%% ========================================================================

Rain_STN_path = fullfile( ...
    ROOT, ...
    '3_rainfall_events_thresholds', ...
    'rainfall_data_threshold_applied');


%% ========================================================================
% 4. UPDATED TRIGGERING-EVENT PATH
%
% Example:
%       42308_trigging.txt
%
% Expected columns:
%
%   1 = Landslide year
%   2 = Landslide month
%   3 = Landslide day
%   4 = Triggering rainfall total
%   5 = Lag between rainfall-event END and landslide
%   6 = Triggering rainfall-event duration
%% ========================================================================

trigger_event_path = fullfile( ...
    REV_ROOT, ...
    'step6_trigging_events', ...
    'step_6_triggering_event_characteristics_radius_ALLOW_OVERLAP');


%% ========================================================================
% 5. UPDATED OPTIMAL-LAG FILE
%
% Generated from:
%
%       max Kendall tau [API(N), S_eff(t-1)]
%
% Sheet:
%       Optimal_N
%
% Important columns:
%
%       Station
%       IMD_ID
%       Optimal_N_days
%% ========================================================================

ideal_lag_path = fullfile( ...
    REV_ROOT, ...
    'step7_lag_selection_updated', ...
    'Step7_Optimal_Lag_Summary.xlsx');


%% ========================================================================
% 6. UPDATED ED OUTPUT FOLDER
%% ========================================================================

output_folder = fullfile( ...
    REV_ROOT, ...
    'ed_threshold_updated', ...
    'Output_Triggering_Events');


if ~exist(output_folder,'dir')
    mkdir(output_folder);
end


%% ========================================================================
% 7. STUDY PERIOD
%% ========================================================================

YR_START = 2007;
YR_END   = 2021;


%% ========================================================================
% 8. VERIFY REQUIRED INPUT DIRECTORIES
%% ========================================================================

if ~exist(land_path,'dir')

    error( ...
        'Last-trigger-day folder not found:\n%s', ...
        land_path);

end


if ~exist(Rain_STN_path,'dir')

    error( ...
        'Rainfall folder not found:\n%s', ...
        Rain_STN_path);

end


if ~exist(trigger_event_path,'dir')

    error( ...
        'Triggering-event folder not found:\n%s', ...
        trigger_event_path);

end


if ~isfile(ideal_lag_path)

    error( ...
        'Updated optimal-lag file not found:\n%s', ...
        ideal_lag_path);

end


%% ========================================================================
% 9. READ UPDATED OPTIMAL N*
%% ========================================================================

T = readtable( ...
    ideal_lag_path, ...
    'Sheet','Optimal_N', ...
    'VariableNamingRule','preserve');


%% ------------------------------------------------------------------------
% Check required columns
%% ------------------------------------------------------------------------

requiredVariables = [ ...
    "Station", ...
    "IMD_ID", ...
    "Optimal_N_days"];


tableVariables = ...
    string(T.Properties.VariableNames);


for v = 1:numel(requiredVariables)

    if ~ismember(requiredVariables(v),tableVariables)

        error( ...
            'Required column missing from Step 7 file: %s', ...
            requiredVariables(v));

    end

end


%% ========================================================================
% 10. STANDARDIZE STATION NAMES
%% ========================================================================

T.Station = ...
    strip(string(T.Station));


%% ========================================================================
% 11. STANDARDIZE IMD IDs
%% ========================================================================

if isnumeric(T.IMD_ID)

    IMD_IDs = ...
        string(compose('%.0f',T.IMD_ID));

else

    IMD_IDs = ...
        strip(string(T.IMD_ID));


    IMD_IDs = ...
        regexprep( ...
        IMD_IDs, ...
        '\.0$', ...
        '');

end


%% ========================================================================
% 12. UPDATED INDEPENDENTLY SELECTED LAGS
%% ========================================================================

ideal_lags = ...
    double(T.Optimal_N_days);


%% ------------------------------------------------------------------------
% Keep only valid selected lags
%% ------------------------------------------------------------------------

validStation = ...
    isfinite(ideal_lags);


T = ...
    T(validStation,:);


IMD_IDs = ...
    IMD_IDs(validStation);


ideal_lags = ...
    ideal_lags(validStation);


%% ========================================================================
% 13. SORT BY UPDATED SELECTED N*
%% ========================================================================

sortTable = table( ...
    (1:numel(IMD_IDs))', ...
    ideal_lags, ...
    string(T.Station), ...
    'VariableNames', ...
    {'OriginalIndex','Nstar','Station'});


sortTable = sortrows( ...
    sortTable, ...
    {'Nstar','Station'}, ...
    {'ascend','ascend'});


order = ...
    sortTable.OriginalIndex;


T = ...
    T(order,:);


IMD_IDs = ...
    IMD_IDs(order);


ideal_lags = ...
    ideal_lags(order);


%% ========================================================================
% 14. DISPLAY CONFIGURATION
%% ========================================================================

fprintf('\n');
fprintf('=============================================================\n');
fprintf(' UPDATED ED-THRESHOLD INPUT PREPARATION\n');
fprintf('=============================================================\n');

fprintf( ...
    'Study period       : %d-%d\n', ...
    YR_START,YR_END);

fprintf( ...
    'Stations           : %d\n', ...
    height(T));

fprintf('\nUpdated N* source:\n%s\n', ...
    ideal_lag_path);

fprintf('\nRainfall source:\n%s\n', ...
    Rain_STN_path);

fprintf('\nTrigger source:\n%s\n', ...
    trigger_event_path);

fprintf('\nOutput:\n%s\n', ...
    output_folder);

fprintf('=============================================================\n\n');


%% ========================================================================
% 15. LOOP THROUGH EACH STATION
%% ========================================================================

for i = 1:height(T)


    station_id = ...
        IMD_IDs(i);


    station_name = ...
        string(T.Station(i));


    l_lag = ...
        round(ideal_lags(i));


    %% --------------------------------------------------------------------
    % Preserve original lag-window convention
    %
    % Original code:
    %
    %       n = ideal_lag + 1
    %
    % This convention is retained here so the revised ED preparation
    % remains comparable with the previous workflow.
    %% --------------------------------------------------------------------

    n = ...
        l_lag + 1;


    STN_str = ...
        char(station_id);


    fprintf('\n');
    fprintf('-------------------------------------------------------------\n');

    fprintf( ...
        'Processing: %s (%s) | N* = %d days\n', ...
        station_name, ...
        STN_str, ...
        l_lag);

    fprintf('-------------------------------------------------------------\n');


    %% ====================================================================
    % 15A. READ UPDATED LAST TRIGGERING DAY FILE
    %
    % Original filename convention:
    %
    %       42308trigging_duration.txt
    %
    % The code also checks:
    %
    %       42308_trigging_duration.txt
    %
    % and then automatically searches the folder if necessary.
    %% ====================================================================

    lastTriggerFile1 = fullfile( ...
        land_path, ...
        [STN_str 'trigging_duration.txt']);


    lastTriggerFile2 = fullfile( ...
        land_path, ...
        [STN_str '_trigging_duration.txt']);


    lastTriggerFile = "";


    if isfile(lastTriggerFile1)

        lastTriggerFile = ...
            string(lastTriggerFile1);


    elseif isfile(lastTriggerFile2)

        lastTriggerFile = ...
            string(lastTriggerFile2);


    else

        candidates = dir( ...
            fullfile( ...
            land_path, ...
            [STN_str '*trigging*.txt']));


        if numel(candidates) == 1

            lastTriggerFile = fullfile( ...
                candidates(1).folder, ...
                candidates(1).name);

        elseif numel(candidates) > 1

            % Prefer file containing "duration"
            namesLower = ...
                lower(string({candidates.name}));


            idxDuration = find( ...
                contains(namesLower,'duration'), ...
                1, ...
                'first');


            if ~isempty(idxDuration)

                lastTriggerFile = fullfile( ...
                    candidates(idxDuration).folder, ...
                    candidates(idxDuration).name);

            end

        end

    end


    if strlength(lastTriggerFile) == 0

        fprintf( ...
            'WARNING: No last-trigger-day file for station %s\n', ...
            STN_str);

        continue

    end


    %% --------------------------------------------------------------------
    % Read last triggering day
    %% --------------------------------------------------------------------

    last_trigging_day = readmatrix( ...
        lastTriggerFile, ...
        'FileType','text');


    if isempty(last_trigging_day) || ...
            size(last_trigging_day,2) < 3

        fprintf( ...
            'WARNING: Invalid last-trigger-day file for station %s\n', ...
            STN_str);

        continue

    end


    %% --------------------------------------------------------------------
    % Remove invalid date rows
    %% --------------------------------------------------------------------

    validLast = ...
        isfinite(last_trigging_day(:,1)) & ...
        isfinite(last_trigging_day(:,2)) & ...
        isfinite(last_trigging_day(:,3));


    last_trigging_day = ...
        last_trigging_day(validLast,:);


    if isempty(last_trigging_day)

        fprintf( ...
            'WARNING: No valid trigger dates for station %s\n', ...
            STN_str);

        continue

    end


    %% ====================================================================
    % 15B. READ UPDATED RAINFALL DATA
    %
    % Expected filename:
    %
    %       42308.txt
    %
    % Expected columns:
    %
    %       Year Month Day Rainfall
    %% ====================================================================

    rainfall_file = fullfile( ...
        Rain_STN_path, ...
        [STN_str '.txt']);


    if ~isfile(rainfall_file)

        fprintf( ...
            'WARNING: No rainfall file for station %s\n', ...
            STN_str);

        continue

    end


    Rain_STN = readmatrix( ...
        rainfall_file, ...
        'FileType','text');


    if isempty(Rain_STN) || ...
            size(Rain_STN,2) < 4

        fprintf( ...
            'WARNING: Invalid rainfall file for station %s\n', ...
            STN_str);

        continue

    end


    %% --------------------------------------------------------------------
    % Remove invalid rainfall rows
    %% --------------------------------------------------------------------

    validRain = ...
        isfinite(Rain_STN(:,1)) & ...
        isfinite(Rain_STN(:,2)) & ...
        isfinite(Rain_STN(:,3)) & ...
        isfinite(Rain_STN(:,4));


    Rain_STN = ...
        Rain_STN(validRain,:);


    %% ====================================================================
    % 15C. CREATE DATETIME SERIES
    %% ====================================================================

    l_trigger = datetime( ...
        last_trigging_day(:,1), ...
        last_trigging_day(:,2), ...
        last_trigging_day(:,3));


    RainDate = datetime( ...
        Rain_STN(:,1), ...
        Rain_STN(:,2), ...
        Rain_STN(:,3));


    RainAmount = ...
        Rain_STN(:,4);


    %% --------------------------------------------------------------------
    % Restrict trigger dates to revised study period
    %% --------------------------------------------------------------------

    keepTrigger = ...
        year(l_trigger) >= YR_START & ...
        year(l_trigger) <= YR_END;


    l_trigger = ...
        l_trigger(keepTrigger);


    %% --------------------------------------------------------------------
    % Rainfall table
    %% --------------------------------------------------------------------

    T_rain = table( ...
        RainDate, ...
        RainAmount, ...
        'VariableNames',{ ...
        'Date', ...
        'Rainfall'});


    if isempty(l_trigger)

        fprintf( ...
            'WARNING: No triggering dates during %d-%d for %s\n', ...
            YR_START,YR_END,STN_str);

        continue

    end


    %% ====================================================================
    % 15D. EXTRACT ANTECEDENT-PRECIPITATION EVENTS
    %
    % Same logic as original code:
    %
    %   - use updated station-specific N*
    %   - inspect rainfall preceding last triggering day
    %   - consecutive non-zero rainfall days form one rainfall event
    %   - calculate:
    %
    %           total precipitation
    %           duration
    %% ====================================================================

    sx = [];


    for jdx = 1:numel(l_trigger)


        starttime = ...
            l_trigger(jdx);


        tlower = ...
            starttime;


        tupper = ...
            starttime - days(n);


        %% ----------------------------------------------------------------
        % Daily time window
        %% ----------------------------------------------------------------

        Timestamp = ...
            (tupper:caldays(1):tlower)';


        %% ----------------------------------------------------------------
        % Extract rainfall in window
        %% ----------------------------------------------------------------

        inWindow = ismember( ...
            T_rain.Date, ...
            Timestamp);


        C = ...
            T_rain(inWindow,:);


        if isempty(C)

            continue

        end


        %% ----------------------------------------------------------------
        % Rainfall vector
        %% ----------------------------------------------------------------

        rainWindow = ...
            C.Rainfall;


        %% ----------------------------------------------------------------
        % At least one rainy day
        %% ----------------------------------------------------------------

        if any(rainWindow > 0)


            %% -------------------------------------------------------------
            % Identify rainy days
            %% -------------------------------------------------------------

            isRain = ...
                rainWindow > 0;


            event_durations = ...
                [];


            event_precipitations = ...
                [];


            current_duration = ...
                0;


            current_precipitation = ...
                0;


            %% =============================================================
            % GROUP CONSECUTIVE RAINY DAYS
            %% =============================================================

            for rr = 1:numel(rainWindow)


                if isRain(rr)


                    current_duration = ...
                        current_duration + 1;


                    current_precipitation = ...
                        current_precipitation + ...
                        rainWindow(rr);


                else


                    if current_duration > 0


                        event_durations = [ ...
                            event_durations; ...
                            current_duration]; %#ok<AGROW>


                        event_precipitations = [ ...
                            event_precipitations; ...
                            current_precipitation]; %#ok<AGROW>


                        current_duration = ...
                            0;


                        current_precipitation = ...
                            0;

                    end

                end

            end


            %% -------------------------------------------------------------
            % Save final event if rainfall continues to window end
            %% -------------------------------------------------------------

            if current_duration > 0


                event_durations = [ ...
                    event_durations; ...
                    current_duration];


                event_precipitations = [ ...
                    event_precipitations; ...
                    current_precipitation];

            end


            %% -------------------------------------------------------------
            % Store:
            %
            % col 1 = event precipitation
            % col 2 = event duration
            %% -------------------------------------------------------------

            new_events = [ ...
                event_precipitations, ...
                event_durations];


            sx = [ ...
                sx; ...
                new_events]; %#ok<AGROW>

        end

    end


    %% ====================================================================
    % 15E. OUTPUT EXCEL FILE
    %% ====================================================================

    out_file = fullfile( ...
        output_folder, ...
        [STN_str '_triggering_output.xlsx']);


    if isfile(out_file)

        delete(out_file);

    end


    %% ====================================================================
    % 15F. SHEET 1: ANTECEDENT-PRECIPITATION EVENTS
    %
    % col 1 = cumulative event precipitation
    % col 2 = duration
    %% ====================================================================

    if ~isempty(sx)


        writematrix( ...
            sx, ...
            out_file, ...
            'Sheet','ap');


        fprintf( ...
            'AP events extracted: %d\n', ...
            size(sx,1));


    else


        fprintf( ...
            'No AP events for station %s\n', ...
            STN_str);

    end


    %% ====================================================================
    % 15G. SHEET 2: UPDATED TRIGGERING EVENTS
    %
    % Updated Step 6 file:
    %
    %       col 1 = landslide year
    %       col 2 = landslide month
    %       col 3 = landslide day
    %       col 4 = triggering rainfall
    %       col 5 = trigger-to-landslide lag
    %       col 6 = event duration
    %
    % For ED analysis we retain:
    %
    %       col 4 = triggering rainfall
    %       col 6 = duration
    %% ====================================================================

    trig_file = fullfile( ...
        trigger_event_path, ...
        [STN_str '_trigging.txt']);


    if isfile(trig_file)


        trig_data = readmatrix( ...
            trig_file, ...
            'FileType','text');


        if ~isempty(trig_data) && ...
                size(trig_data,2) >= 6


            %% -------------------------------------------------------------
            % Remove invalid rows
            %% -------------------------------------------------------------

            validTrig = ...
                isfinite(trig_data(:,1)) & ...
                isfinite(trig_data(:,2)) & ...
                isfinite(trig_data(:,3)) & ...
                isfinite(trig_data(:,4)) & ...
                isfinite(trig_data(:,6));


            trig_data = ...
                trig_data(validTrig,:);


            %% -------------------------------------------------------------
            % Study-period filtering
            %% -------------------------------------------------------------

            trigDate = datetime( ...
                trig_data(:,1), ...
                trig_data(:,2), ...
                trig_data(:,3));


            keep = ...
                year(trigDate) >= YR_START & ...
                year(trigDate) <= YR_END;


            trig_data = ...
                trig_data(keep,:);


            %% -------------------------------------------------------------
            % ED variables:
            %
            % rainfall amount + rainfall duration
            %% -------------------------------------------------------------

            trig_selected = ...
                trig_data(:,[4 6]);


            if ~isempty(trig_selected)


                writematrix( ...
                    trig_selected, ...
                    out_file, ...
                    'Sheet','trigging');


                fprintf( ...
                    'Triggering events written: %d\n', ...
                    size(trig_selected,1));


            else


                fprintf( ...
                    'No triggering events in %d-%d for %s\n', ...
                    YR_START,YR_END,STN_str);

            end


        else


            fprintf( ...
                ['Triggering data file for %s does not contain ' ...
                 'the required six columns.\n'], ...
                STN_str);

        end


    else


        fprintf( ...
            'Missing triggering-event file for station %s\n', ...
            STN_str);

    end


    fprintf( ...
        'Output saved: %s\n', ...
        out_file);


end


%% ========================================================================
% 16. COMPLETE
%% ========================================================================

fprintf('\n');
fprintf('=============================================================\n');
fprintf(' ED INPUT PREPARATION COMPLETE\n');
fprintf('=============================================================\n');

fprintf( ...
    'Outputs saved to:\n%s\n', ...
    output_folder);

fprintf('=============================================================\n');