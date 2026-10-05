%% ========================================================================
% STEP 9
% UPDATED KENDALL'S TAU:
%
% LANDSLIDE FREQUENCY (LF) vs ROOT-ZONE EFFECTIVE SATURATION
%
% Compares:
%
%   1) LF vs median S_eff[Topt]
%      Topt = independently selected station-specific N*
%
%   2) LF vs S_eff[1]
%      S_eff one day before landslide
%
%   3) LF vs S_eff[0]
%      S_eff on landslide/event day
%
%
% ANALYSIS UNIT
% -------------------------------------------------------------------------
%
% One observation = one STATION-YEAR having LF >= 1.
%
% For each station-year:
%
%   LF = number of revised station-radius landslide assignments
%
%   S_eff[Topt] =
%       median of event-specific antecedent-window median S_eff values
%
%   S_eff[1] =
%       median S_eff one day before landslides in that year
%
%   S_eff[0] =
%       median S_eff on landslide days in that year
%
%
% UPDATED WORKFLOW
% -------------------------------------------------------------------------
%
% Study period:
%       2007-2021
%
% Landslides:
%       Revised station-radius station-event associations
%       Catalogue duplicates removed upstream
%       Cross-station overlap intentionally retained
%
% Topt:
%       Updated independently selected N* from Step 7
%
% Root-zone wetness:
%       Updated daily effective saturation S_eff
%
%
% ERROR BARS
% -------------------------------------------------------------------------
%
% Stations:
%       +/- 0.5 SE (jackknife)
%
% All:
%       +/- 1 SE (jackknife)
%
%
% OUTPUT FOLDER
% -------------------------------------------------------------------------
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
%% ========================================================================

outDir = fullfile( ...
    revDir, ...
    'step9_api_seff_lf_correlation_updated');


if ~exist(outDir,'dir')

    mkdir(outDir);

end


xlsOut = fullfile( ...
    outDir, ...
    'Step9_KendallTau_LF_vs_SeffTopt_Seff1_Seff0.xlsx');


%% ========================================================================
% 3. UPDATED STEP-7 N*
%% ========================================================================

lagXlsx = fullfile( ...
    revDir, ...
    'step7_lag_selection_updated', ...
    'Step7_Optimal_Lag_Summary.xlsx');


%% ========================================================================
% 4. UPDATED station-radius LANDSLIDE METADATA
%
% IMPORTANT:
%
% Catalogue duplicates were already removed upstream.
%
% The same physical landslide can deliberately occur for more than one
% station when the landslide lies inside overlapping station-radius station buffers.
%
% Sheet:
%
%       Station_event_pairs
%
%% ========================================================================

landslideMeta = fullfile( ...
    revDir, ...
    'step_0_landslide_filtering', ...
    'Station_Landslide_Metadata_radius_ALLOW_OVERLAP.xlsx');


%% ========================================================================
% 5. UPDATED DAILY ROOT-ZONE S_eff
%
% Expected filename:
%
%       42308_SMrz_Seff.txt
%
% Expected columns:
%
%       column 1 = year
%       column 2 = month
%       column 3 = day
%       column 5 = root-zone effective saturation S_eff
%
%% ========================================================================

satDir = fullfile( ...
    baseDir, ...
    '10_soil_moisture_extraction', ...
    'effective_saturation_time_series_all_stations', ...
    'effective_saturation_time_series_all_stations');


%% ========================================================================
% 6. SETTINGS
%% ========================================================================

yr0 = ...
    2007;


yr1 = ...
    2021;


years = ...
    (yr0:yr1).';


nYears = ...
    numel(years);


%% ========================================================================
% 7. PLOT FORMATTING
%
% Preserve original 3-bar formatting
%% ========================================================================

% Orange = median S_eff[Topt]
colMed = ...
    [0.90 0.45 0.10];


% Blue = S_eff[1]
colPrev = ...
    [0.15 0.45 0.85];


% Purple = S_eff[0]
colEvt = ...
    [0.55 0.34 0.69];


edgeCol = ...
    0.2 * [1 1 1];


fontTick = ...
    14;


fontLabel = ...
    18;


xLabelRotate = ...
    32;


ylimBars = ...
    [-1 1];


%% ========================================================================
% 8. VERIFY INPUTS
%% ========================================================================

if ~isfile(lagXlsx)

    error( ...
        'Updated Step-7 optimal-lag file not found:\n%s', ...
        lagXlsx);

end


if ~isfile(landslideMeta)

    error( ...
        'Updated station-radius landslide metadata file not found:\n%s', ...
        landslideMeta);

end


if ~exist(satDir,'dir')

    error( ...
        'Updated daily S_eff folder not found:\n%s', ...
        satDir);

end


%% ========================================================================
% 9. READ UPDATED N*
%% ========================================================================

Lag = readtable( ...
    lagXlsx, ...
    'Sheet','Optimal_N', ...
    'VariableNamingRule','preserve');


requiredLagVariables = [ ...
    "Station", ...
    "IMD_ID", ...
    "Optimal_N_days"];


lagVariables = ...
    string(Lag.Properties.VariableNames);


for v = 1:numel(requiredLagVariables)

    if ~ismember(requiredLagVariables(v),lagVariables)

        error( ...
            'Required Step-7 column missing: %s', ...
            requiredLagVariables(v));

    end

end


%% ========================================================================
% 10. STANDARDIZE STATION INFORMATION
%% ========================================================================

stationName = ...
    strip(string(Lag.Station));


if isnumeric(Lag.IMD_ID)

    IMD_ID = ...
        string( ...
        compose('%.0f',Lag.IMD_ID));

else

    IMD_ID = ...
        strip(string(Lag.IMD_ID));


    IMD_ID = ...
        regexprep( ...
        IMD_ID, ...
        '\.0$', ...
        '');

end


Topt = ...
    double(Lag.Optimal_N_days);


%% ------------------------------------------------------------------------
% Keep valid N*
%% ------------------------------------------------------------------------

validLag = ...
    isfinite(Topt);


stationName = ...
    stationName(validLag);


IMD_ID = ...
    IMD_ID(validLag);


Topt = ...
    Topt(validLag);


nStations = ...
    numel(IMD_ID);


%% ========================================================================
% 11. READ UPDATED station-radius LANDSLIDE STATION-EVENT PAIRS
%% ========================================================================

Pairs = readtable( ...
    landslideMeta, ...
    'Sheet','Station_event_pairs', ...
    'VariableNamingRule','preserve');


pairVariables = ...
    string(Pairs.Properties.VariableNames);


if ~ismember("Station",pairVariables)

    error( ...
        'Station column not found in Station_event_pairs sheet.');

end


if ~ismember("EventDate",pairVariables)

    error( ...
        'EventDate column not found in Station_event_pairs sheet.');

end


Pairs.Station = ...
    strip(string(Pairs.Station));


%% ------------------------------------------------------------------------
% Event dates
%% ------------------------------------------------------------------------

eventDateAll = ...
    Pairs.EventDate;


if ~isdatetime(eventDateAll)

    eventDateAll = ...
        datetime(string(eventDateAll));

end


Pairs.EventDate = ...
    eventDateAll;


%% ------------------------------------------------------------------------
% Restrict to revised study period
%% ------------------------------------------------------------------------

keepPeriod = ...
    year(Pairs.EventDate) >= yr0 & ...
    year(Pairs.EventDate) <= yr1;


Pairs = ...
    Pairs(keepPeriod,:);


%% ========================================================================
% 12. DISPLAY CONFIGURATION
%% ========================================================================

fprintf('\n');
fprintf('=============================================================\n');
fprintf(' STEP 9: LF vs ROOT-ZONE S_eff KENDALL TAU\n');
fprintf('=============================================================\n');


fprintf( ...
    'Study period           : %d-%d\n', ...
    yr0, ...
    yr1);


fprintf( ...
    'Stations               : %d\n', ...
    nStations);


fprintf( ...
    'Landslide radius       : station radius\n');


fprintf( ...
    'Cross-station overlap  : RETAINED\n');


fprintf( ...
    'Catalogue duplicates   : removed upstream\n');


fprintf('\nN* source:\n%s\n', ...
    lagXlsx);


fprintf('\nLandslide source:\n%s\n', ...
    landslideMeta);


fprintf('\nDaily S_eff source:\n%s\n', ...
    satDir);


fprintf('\nOutput folder:\n%s\n', ...
    outDir);


fprintf('=============================================================\n\n');


%% ========================================================================
% 13. STORAGE
%% ========================================================================

%% ------------------------------------------------------------------------
% LF vs S_eff[Topt]
%% ------------------------------------------------------------------------

tauTopt = ...
    nan(nStations,1);


pTopt = ...
    nan(nStations,1);


ciTopt = ...
    nan(nStations,2);


nPairsTopt = ...
    zeros(nStations,1);


%% ------------------------------------------------------------------------
% LF vs S_eff[1]
%% ------------------------------------------------------------------------

tauPrev = ...
    nan(nStations,1);


pPrev = ...
    nan(nStations,1);


ciPrev = ...
    nan(nStations,2);


nPairsPrev = ...
    zeros(nStations,1);


%% ------------------------------------------------------------------------
% LF vs S_eff[0]
%% ------------------------------------------------------------------------

tauEvt = ...
    nan(nStations,1);


pEvt = ...
    nan(nStations,1);


ciEvt = ...
    nan(nStations,2);


nPairsEvt = ...
    zeros(nStations,1);


%% ------------------------------------------------------------------------
% Pairs for pooled "All NEH"
%% ------------------------------------------------------------------------

pairsTopt_X = ...
    cell(nStations,1);


pairsTopt_Y = ...
    cell(nStations,1);


pairsPrev_X = ...
    cell(nStations,1);


pairsPrev_Y = ...
    cell(nStations,1);


pairsEvt_X = ...
    cell(nStations,1);


pairsEvt_Y = ...
    cell(nStations,1);


%% ------------------------------------------------------------------------
% Processing status
%% ------------------------------------------------------------------------

Status = ...
    strings(nStations,1);


%% ------------------------------------------------------------------------
% Audit of yearly pairs
%% ------------------------------------------------------------------------

YearlyAudit = ...
    table();


%% ========================================================================
% 14. MAIN STATION LOOP
%% ========================================================================

for s = 1:nStations


    station = ...
        stationName(s);


    stationID = ...
        IMD_ID(s);


    stnStr = ...
        char(stationID);


    Nstar = ...
        round(Topt(s));


    fprintf('\n');
    fprintf('-------------------------------------------------------------\n');


    fprintf( ...
        '%s | ID = %s | Topt/N* = %d days\n', ...
        station, ...
        stnStr, ...
        Nstar);


    fprintf('-------------------------------------------------------------\n');


    %% ====================================================================
    % 14A. GET REVISED LANDSLIDES FOR THIS STATION
    %% ====================================================================

    stationMask = ...
        strcmpi( ...
        strip(string(Pairs.Station)), ...
        strip(station));


    stationEvents = ...
        Pairs.EventDate(stationMask);


    stationEvents = ...
        stationEvents( ...
        ~isnat(stationEvents));


    %% --------------------------------------------------------------------
    % Keep revised analysis period
    %% --------------------------------------------------------------------

    stationEvents = ...
        stationEvents( ...
        year(stationEvents) >= yr0 & ...
        year(stationEvents) <= yr1);


    if isempty(stationEvents)

        fprintf( ...
            '[INFO] No revised station-radius landslides for this station.\n');


        Status(s) = ...
            "No landslides";


        continue

    end


    %% ====================================================================
    % 14B. DAILY S_eff FILE
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


    S = readmatrix( ...
        satFile, ...
        'FileType','text');


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
            '[WARN] No valid S_eff values.\n');


        Status(s) = ...
            "No valid S_eff";


        continue

    end


    %% ====================================================================
    % DAILY S_eff TIME SERIES
    %% ====================================================================

    SeffDate = datetime( ...
        S(:,1), ...
        S(:,2), ...
        S(:,3));


    Seff = ...
        double(S(:,5));


    %% ====================================================================
    % 14C. ANNUAL LANDSLIDE FREQUENCY
    %% ====================================================================

    LF = ...
        zeros(nYears,1);


    for iy = 1:nYears

        LF(iy) = ...
            sum( ...
            year(stationEvents) == years(iy));

    end


    %% ====================================================================
    % BUILD STATION-YEAR PAIRS
    %% ====================================================================

    xLF_forTopt = ...
        [];


    yTopt = ...
        [];


    xLF_forPrev = ...
        [];


    yPrev = ...
        [];


    xLF_forEvt = ...
        [];


    yEvt = ...
        [];


    %% ====================================================================
    % LOOP THROUGH YEARS
    %% ====================================================================

    for iy = 1:nYears


        yNow = ...
            years(iy);


        %% ----------------------------------------------------------------
        % Only years having >= 1 landslide
        %% ----------------------------------------------------------------

        if LF(iy) < 1

            continue

        end


        %% ----------------------------------------------------------------
        % Landslides in this station-year
        %% ----------------------------------------------------------------

        Ydates = ...
            stationEvents( ...
            year(stationEvents) == yNow);


        %% ================================================================
        % Event-level S_eff values
        %% ================================================================

        eventTopt = ...
            [];


        eventPrev = ...
            [];


        eventEvt = ...
            [];


        for r = 1:numel(Ydates)


            eventDate = ...
                Ydates(r);


            %% ============================================================
            % 1. S_eff[Topt]
            %
            % Antecedent N*-day window:
            %
            %       eventDate-N*  through  eventDate-1
            %
            % This preserves S_eff[Topt] as a pre-failure wetness metric.
            %% ============================================================

            startTopt = ...
                eventDate - days(Nstar);


            endTopt = ...
                eventDate - days(1);


            idxTopt = ...
                SeffDate >= startTopt & ...
                SeffDate <= endTopt;


            if any(idxTopt)


                v = median( ...
                    Seff(idxTopt), ...
                    'omitnan');


                if isfinite(v)

                    eventTopt(end+1,1) = ...
                        v; %#ok<AGROW>

                end

            end


            %% ============================================================
            % 2. S_eff[1]
            %
            % Previous day
            %% ============================================================

            idxPrev = ...
                SeffDate == ...
                (eventDate - days(1));


            if any(idxPrev)


                v = median( ...
                    Seff(idxPrev), ...
                    'omitnan');


                if isfinite(v)

                    eventPrev(end+1,1) = ...
                        v; %#ok<AGROW>

                end

            end


            %% ============================================================
            % 3. S_eff[0]
            %
            % Event / landslide day
            %% ============================================================

            idxEvt = ...
                SeffDate == ...
                eventDate;


            if any(idxEvt)


                v = median( ...
                    Seff(idxEvt), ...
                    'omitnan');


                if isfinite(v)

                    eventEvt(end+1,1) = ...
                        v; %#ok<AGROW>

                end

            end


        end


        %% ================================================================
        % YEARLY MEDIAN S_eff[Topt]
        %% ================================================================

        yearlyTopt = ...
            NaN;


        if ~isempty(eventTopt)

            yearlyTopt = median( ...
                eventTopt, ...
                'omitnan');


            xLF_forTopt(end+1,1) = ...
                LF(iy); %#ok<AGROW>


            yTopt(end+1,1) = ...
                yearlyTopt; %#ok<AGROW>

        end


        %% ================================================================
        % YEARLY MEDIAN S_eff[1]
        %% ================================================================

        yearlyPrev = ...
            NaN;


        if ~isempty(eventPrev)

            yearlyPrev = median( ...
                eventPrev, ...
                'omitnan');


            xLF_forPrev(end+1,1) = ...
                LF(iy); %#ok<AGROW>


            yPrev(end+1,1) = ...
                yearlyPrev; %#ok<AGROW>

        end


        %% ================================================================
        % YEARLY MEDIAN S_eff[0]
        %% ================================================================

        yearlyEvt = ...
            NaN;


        if ~isempty(eventEvt)

            yearlyEvt = median( ...
                eventEvt, ...
                'omitnan');


            xLF_forEvt(end+1,1) = ...
                LF(iy); %#ok<AGROW>


            yEvt(end+1,1) = ...
                yearlyEvt; %#ok<AGROW>

        end


        %% ================================================================
        % SAVE YEARLY AUDIT
        %% ================================================================

        newAudit = table( ...
            station, ...
            stationID, ...
            Nstar, ...
            yNow, ...
            LF(iy), ...
            numel(Ydates), ...
            numel(eventTopt), ...
            yearlyTopt, ...
            numel(eventPrev), ...
            yearlyPrev, ...
            numel(eventEvt), ...
            yearlyEvt, ...
            'VariableNames',{ ...
            'Station', ...
            'IMD_ID', ...
            'Topt_Nstar_days', ...
            'Year', ...
            'LF', ...
            'N_Landslide_Records', ...
            'N_SeffTopt_Events', ...
            'Median_SeffTopt', ...
            'N_Seff1_Events', ...
            'Median_Seff1', ...
            'N_Seff0_Events', ...
            'Median_Seff0'});


        YearlyAudit = [ ...
            YearlyAudit; ...
            newAudit]; %#ok<AGROW>


    end


    %% ====================================================================
    % SAVE PAIRS FOR ALL-NEH POOLING
    %% ====================================================================

    pairsTopt_X{s} = ...
        xLF_forTopt;


    pairsTopt_Y{s} = ...
        yTopt;


    pairsPrev_X{s} = ...
        xLF_forPrev;


    pairsPrev_Y{s} = ...
        yPrev;


    pairsEvt_X{s} = ...
        xLF_forEvt;


    pairsEvt_Y{s} = ...
        yEvt;


    %% ====================================================================
    % 14D. LF vs S_eff[Topt]
    %% ====================================================================

    if numel(xLF_forTopt) >= 2


        [tauTopt(s),pTopt(s)] = corr( ...
            xLF_forTopt, ...
            yTopt, ...
            'Type','Kendall', ...
            'Rows','complete');


        nPairsTopt(s) = ...
            numel(xLF_forTopt);


        if nPairsTopt(s) >= 3


            se = jackknife_se_kendall( ...
                xLF_forTopt, ...
                yTopt);


            half = ...
                0.5 * se;


            ciTopt(s,:) = ...
                clamp_to_unit( ...
                [ ...
                tauTopt(s)-half, ...
                tauTopt(s)+half ...
                ]);


        end


    end


    %% ====================================================================
    % 14E. LF vs S_eff[1]
    %% ====================================================================

    if numel(xLF_forPrev) >= 2


        [tauPrev(s),pPrev(s)] = corr( ...
            xLF_forPrev, ...
            yPrev, ...
            'Type','Kendall', ...
            'Rows','complete');


        nPairsPrev(s) = ...
            numel(xLF_forPrev);


        if nPairsPrev(s) >= 3


            se = jackknife_se_kendall( ...
                xLF_forPrev, ...
                yPrev);


            half = ...
                0.5 * se;


            ciPrev(s,:) = ...
                clamp_to_unit( ...
                [ ...
                tauPrev(s)-half, ...
                tauPrev(s)+half ...
                ]);


        end


    end


    %% ====================================================================
    % 14F. LF vs S_eff[0]
    %% ====================================================================

    if numel(xLF_forEvt) >= 2


        [tauEvt(s),pEvt(s)] = corr( ...
            xLF_forEvt, ...
            yEvt, ...
            'Type','Kendall', ...
            'Rows','complete');


        nPairsEvt(s) = ...
            numel(xLF_forEvt);


        if nPairsEvt(s) >= 3


            se = jackknife_se_kendall( ...
                xLF_forEvt, ...
                yEvt);


            half = ...
                0.5 * se;


            ciEvt(s,:) = ...
                clamp_to_unit( ...
                [ ...
                tauEvt(s)-half, ...
                tauEvt(s)+half ...
                ]);


        end


    end


    Status(s) = ...
        "OK";


    fprintf( ...
        'LF vs S_eff[Topt] : n=%d | tau=%+.3f | p=%.4f\n', ...
        nPairsTopt(s), ...
        tauTopt(s), ...
        pTopt(s));


    fprintf( ...
        'LF vs S_eff[1]    : n=%d | tau=%+.3f | p=%.4f\n', ...
        nPairsPrev(s), ...
        tauPrev(s), ...
        pPrev(s));


    fprintf( ...
        'LF vs S_eff[0]    : n=%d | tau=%+.3f | p=%.4f\n', ...
        nPairsEvt(s), ...
        tauEvt(s), ...
        pEvt(s));


end


%% ========================================================================
% 15. ALL NEH -- POOLED STATION-YEAR PAIRS
%% ========================================================================

useMask = ...
    true(nStations,1);


[xAllTopt,yAllTopt] = pool_pairs( ...
    pairsTopt_X, ...
    pairsTopt_Y, ...
    useMask);


[xAllPrev,yAllPrev] = pool_pairs( ...
    pairsPrev_X, ...
    pairsPrev_Y, ...
    useMask);


[xAllEvt,yAllEvt] = pool_pairs( ...
    pairsEvt_X, ...
    pairsEvt_Y, ...
    useMask);


%% ------------------------------------------------------------------------
% All = +/- 1 SE
%% ------------------------------------------------------------------------

[tauTopt_all,ciTopt_all,pTopt_all] = ...
    tau_and_SE( ...
    xAllTopt, ...
    yAllTopt, ...
    1);


[tauPrev_all,ciPrev_all,pPrev_all] = ...
    tau_and_SE( ...
    xAllPrev, ...
    yAllPrev, ...
    1);


[tauEvt_all,ciEvt_all,pEvt_all] = ...
    tau_and_SE( ...
    xAllEvt, ...
    yAllEvt, ...
    1);


%% ========================================================================
% 16. STACK FOR PLOTTING
%% ========================================================================

labelsUse = ...
    stationName(useMask);


labelsPlot = [ ...
    "All"; ...
    labelsUse];


%% ------------------------------------------------------------------------
% Kendall tau
%% ------------------------------------------------------------------------

tauTopt_plot = [ ...
    tauTopt_all; ...
    tauTopt(useMask)];


tauPrev_plot = [ ...
    tauPrev_all; ...
    tauPrev(useMask)];


tauEvt_plot = [ ...
    tauEvt_all; ...
    tauEvt(useMask)];


%% ------------------------------------------------------------------------
% Error intervals
%% ------------------------------------------------------------------------

ciTopt_plot = [ ...
    ciTopt_all; ...
    ciTopt(useMask,:)];


ciPrev_plot = [ ...
    ciPrev_all; ...
    ciPrev(useMask,:)];


ciEvt_plot = [ ...
    ciEvt_all; ...
    ciEvt(useMask,:)];


%% ------------------------------------------------------------------------
% p-values
%% ------------------------------------------------------------------------

pTopt_plot = [ ...
    pTopt_all; ...
    pTopt(useMask)];


pPrev_plot = [ ...
    pPrev_all; ...
    pPrev(useMask)];


pEvt_plot = [ ...
    pEvt_all; ...
    pEvt(useMask)];


%% ------------------------------------------------------------------------
% Pair numbers
%% ------------------------------------------------------------------------

nTopt_plot = [ ...
    numel(xAllTopt); ...
    nPairsTopt(useMask)];


nPrev_plot = [ ...
    numel(xAllPrev); ...
    nPairsPrev(useMask)];


nEvt_plot = [ ...
    numel(xAllEvt); ...
    nPairsEvt(useMask)];


%% ------------------------------------------------------------------------
% N*
%% ------------------------------------------------------------------------

Nstar_plot = [ ...
    NaN; ...
    Topt(useMask)];


%% ========================================================================
% 17. THREE-BAR GROUPED PLOT
%% ========================================================================

errLabel = ...
    '\pm0.5 SE (stations), \pm1 SE (All)';


if ~isempty(labelsPlot)


    nStnPlot = ...
        numel(labelsPlot);


    x = ...
        1:nStnPlot;


    %% --------------------------------------------------------------------
    % Data matrix
    %
    % 1 = S_eff[Topt]
    % 2 = S_eff[1]
    % 3 = S_eff[0]
    %% --------------------------------------------------------------------

    Y = [ ...
        tauTopt_plot, ...
        tauPrev_plot, ...
        tauEvt_plot];


    %% ====================================================================
    % FIGURE
    %% ====================================================================

    figure( ...
        'Color','w');


    hold on;


    %% ====================================================================
    % BARS
    %% ====================================================================

    b = bar( ...
        x, ...
        Y, ...
        'grouped');


    %% --------------------------------------------------------------------
    % Colours retained from original figure
    %% --------------------------------------------------------------------

    b(1).FaceColor = ...
        colMed;


    b(1).EdgeColor = ...
        edgeCol;


    b(2).FaceColor = ...
        colPrev;


    b(2).EdgeColor = ...
        edgeCol;


    b(3).FaceColor = ...
        colEvt;


    b(3).EdgeColor = ...
        edgeCol;


    %% ====================================================================
    % 18. ERROR BARS
    %% ====================================================================

    CI = cat( ...
        3, ...
        ciTopt_plot, ...
        ciPrev_plot, ...
        ciEvt_plot);


    for j = 1:3


        xj = ...
            b(j).XEndPoints;


        yj = ...
            Y(:,j);


        lower = ...
            yj - CI(:,1,j);


        upper = ...
            CI(:,2,j) - yj;


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
    % 19. SIGNIFICANCE STARS
    %
    % ** = p <= 0.05
    %
    % *  = 0.05 < p <= 0.10
    %% ====================================================================

    Pmat = [ ...
        pTopt_plot, ...
        pPrev_plot, ...
        pEvt_plot];


    for j = 1:3


        xj = ...
            b(j).XEndPoints;


        yj = ...
            Y(:,j);


        upper = ...
            CI(:,2,j) - yj;


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


            y_top = ...
                yj(i) + upper(i);


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
    % 20. AXIS FORMATTING
    %% ====================================================================

    xlim( ...
        [0.5, ...
         nStnPlot+0.5]);


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


    ylabel( ...
        'Kendall''s \tau (LF vs S_{eff})', ...
        'FontName','Arial', ...
        'FontSize',fontLabel, ...
        'Interpreter','tex');


    title( ...
        'NEH: Kendall''s \tau (LF vs S_{eff}[T_{opt}] / S_{eff}[1] / S_{eff}[0])', ...
        'FontName','Arial', ...
        'FontSize',fontLabel, ...
        'Interpreter','tex');


    %% ====================================================================
    % 21. LEGEND
    %% ====================================================================

    legend( ...
        { ...
        'median S_{eff}[T_{opt}]', ...
        'S_{eff}[1]', ...
        'S_{eff}[0]' ...
        }, ...
        'Location','southoutside', ...
        'Orientation','horizontal', ...
        'Box','on', ...
        'Interpreter','tex');


    %% ====================================================================
    % ERROR-BAR LABEL
    %% ====================================================================

    text( ...
        0.5, ...
        ylimBars(2)-0.05, ...
        errLabel, ...
        'Units','data', ...
        'FontSize',10, ...
        'Interpreter','tex');


    set( ...
        gca, ...
        'LooseInset', ...
        max( ...
        get(gca,'TightInset'), ...
        0.02*[1 1 1 1]));


    %% ====================================================================
    % 22. SAVE FIGURES
    %% ====================================================================

    outBase = fullfile( ...
        outDir, ...
        'Step9_NEH_LF_vs_SeffTopt_Seff1_Seff0_KendallTau');


    print( ...
        gcf, ...
        [outBase '.tif'], ...
        '-dtiff', ...
        '-r300');


    print( ...
        gcf, ...
        [outBase '.png'], ...
        '-dpng', ...
        '-r300');


    savefig( ...
        gcf, ...
        [outBase '.fig']);


end


%% ========================================================================
% 23. MAIN TAU AND p-VALUE TABLE
%% ========================================================================

TauTable = table( ...
    labelsPlot, ...
    Nstar_plot, ...
    nTopt_plot, ...
    tauTopt_plot, ...
    pTopt_plot, ...
    nPrev_plot, ...
    tauPrev_plot, ...
    pPrev_plot, ...
    nEvt_plot, ...
    tauEvt_plot, ...
    pEvt_plot, ...
    'VariableNames',{ ...
    'Station', ...
    'Topt_Nstar_days', ...
    'N_LF_SeffTopt', ...
    'Tau_LF_SeffTopt', ...
    'p_LF_SeffTopt', ...
    'N_LF_Seff1', ...
    'Tau_LF_Seff1', ...
    'p_LF_Seff1', ...
    'N_LF_Seff0', ...
    'Tau_LF_Seff0', ...
    'p_LF_Seff0'});


disp(' ');


disp( ...
    '=================================================================');


disp( ...
    'Kendall tau: LF vs S_eff[Topt], S_eff[1], S_eff[0]');


disp( ...
    '=================================================================');


disp( ...
    TauTable);


%% ========================================================================
% 24. PROCESSING STATUS
%% ========================================================================

StatusTable = table( ...
    stationName, ...
    IMD_ID, ...
    Topt, ...
    nPairsTopt, ...
    nPairsPrev, ...
    nPairsEvt, ...
    Status, ...
    'VariableNames',{ ...
    'Station', ...
    'IMD_ID', ...
    'Topt_Nstar_days', ...
    'N_LF_SeffTopt', ...
    'N_LF_Seff1', ...
    'N_LF_Seff0', ...
    'Status'});


%% ========================================================================
% 25. WRITE EXCEL OUTPUT
%% ========================================================================

if isfile(xlsOut)

    delete(xlsOut);

end


writetable( ...
    TauTable, ...
    xlsOut, ...
    'Sheet','Tau_p_LF_rootzone');


writetable( ...
    YearlyAudit, ...
    xlsOut, ...
    'Sheet','Station_Year_Pairs');


writetable( ...
    StatusTable, ...
    xlsOut, ...
    'Sheet','Processing_Status');


%% ========================================================================
% 26. ANALYSIS SETTINGS
%% ========================================================================

SettingsTable = table( ...
    yr0, ...
    yr1, ...
    20, ...
    "ALLOW_OVERLAP", ...
    string(lagXlsx), ...
    string(landslideMeta), ...
    string(satDir), ...
    'VariableNames',{ ...
    'Study_Start_Year', ...
    'Study_End_Year', ...
    'Landslide_Radius_km', ...
    'Station_Overlap', ...
    'Topt_Nstar_Source', ...
    'Landslide_Source', ...
    'Seff_Source'});


writetable( ...
    SettingsTable, ...
    xlsOut, ...
    'Sheet','Analysis_Settings');


%% ========================================================================
% 27. COMPLETE
%% ========================================================================

fprintf('\n');
fprintf('=============================================================\n');
fprintf(' STEP 9 LF vs S_eff ANALYSIS COMPLETE\n');
fprintf('=============================================================\n');


fprintf( ...
    'Study period          : %d-%d\n', ...
    yr0, ...
    yr1);


fprintf( ...
    'Landslide radius      : station radius\n');


fprintf( ...
    'Station overlap       : RETAINED\n');


fprintf('\nCompared:\n');


fprintf( ...
    '1. LF vs median S_eff[Topt]\n');


fprintf( ...
    '2. LF vs S_eff[1]\n');


fprintf( ...
    '3. LF vs S_eff[0]\n');


fprintf('\nAll outputs saved in:\n%s\n', ...
    outDir);


fprintf('\nExcel:\n%s\n', ...
    xlsOut);


fprintf('\nFigure:\n%s\n', ...
    [outBase '.png']);


fprintf('=============================================================\n');


%% ========================================================================
% LOCAL FUNCTIONS
%% ========================================================================

function se = jackknife_se_kendall(x,y)


    x = ...
        x(:);


    y = ...
        y(:);


    mask = ...
        isfinite(x) & ...
        isfinite(y);


    x = ...
        x(mask);


    y = ...
        y(mask);


    n = ...
        numel(x);


    if n < 3


        se = ...
            NaN;


        return


    end


    tau_jk = ...
        nan(n,1);


    for k = 1:n


        idx = ...
            true(n,1);


        idx(k) = ...
            false;


        tau_jk(k) = corr( ...
            x(idx), ...
            y(idx), ...
            'Type','Kendall', ...
            'Rows','complete');


    end


    tau_bar = ...
        mean( ...
        tau_jk, ...
        'omitnan');


    se = sqrt( ...
        (n-1)/n * ...
        nansum( ...
        (tau_jk-tau_bar).^2));


end


%% ========================================================================
% Clamp to valid Kendall tau range [-1,+1]
%% ========================================================================

function ci = clamp_to_unit(ci)


    ci = ...
        max( ...
        min(ci,1), ...
        -1);


end


%% ========================================================================
% Pool station-year pairs
%% ========================================================================

function [xAll,yAll] = pool_pairs( ...
    Xcell, ...
    Ycell, ...
    useMask)


    xAll = ...
        [];


    yAll = ...
        [];


    for i = 1:numel(Xcell)


        if useMask(i) && ...
                ~isempty(Xcell{i}) && ...
                ~isempty(Ycell{i})


            xAll = [ ...
                xAll; ...
                Xcell{i}(:)]; %#ok<AGROW>


            yAll = [ ...
                yAll; ...
                Ycell{i}(:)]; %#ok<AGROW>


        end


    end


end


