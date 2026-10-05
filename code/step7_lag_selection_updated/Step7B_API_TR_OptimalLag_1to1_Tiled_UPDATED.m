%% ========================================================================
% Step7B_API_TR_OptimalLag_1to1_Tiled_UPDATED.m
%
% UPDATED PROFESSIONAL 21-SITE 1:1 TILED PLOT
%
% Revised workflow:
%
%   Updated landslide catalogue:
%       station-radius radius
%       catalogue duplicates removed
%       station-buffer overlap retained
%
%   Optimal N*:
%       independently selected using
%       Kendall tau [API(N), S_eff(t-1)]
%
%   API:
%       updated Crozier outputs
%       K = 0.90
%
%   Triggering rainfall:
%       updated station-radius overlapping station-event catalogue
%
%
% FOR EACH STATION:
%
%       X = normalized API at independently selected N*
%       Y = normalized triggering rainfall (TR)
%
%
% INTERPRETATION:
%
%       Below 1:1 line : API > TR
%       Above 1:1 line : TR > API
%
%
% EMPIRICAL NORMALIZATION:
%
%       tiedrank(X) / (n + 1)
%
%
% OUTPUTS:
%
%   Step7B_API_TR_OptimalLag_Summary.xlsx
%   Step7B_API_TR_OptimalLag_1to1_Tiled.png
%   Step7B_API_TR_OptimalLag_1to1_Tiled.tiff
%   Step7B_API_TR_OptimalLag_1to1_Tiled.fig
%
%
% WORKING DIRECTORY:
%
% C:\lews_2022-2024\3_new_stations_neh_new\revision_round1\
% step7_lag_selection_updated
%
% ========================================================================

clc;
clear;
close all;


%% ========================================================================
% 1. ROOT PATH
%% ========================================================================

ROOT = ...
    fullfile(neh_root());


%% ========================================================================
% 2. UPDATED OPTIMAL-LAG FILE
%% ========================================================================

LAG_FILE = fullfile( ...
    ROOT, ...
    'step7_lag_selection_updated', ...
    'Step7_Optimal_Lag_Summary.xlsx');


%% ========================================================================
% 3. UPDATED TRIGGERING-EVENT DIRECTORY
%% ========================================================================

TRIGGER_DIR = fullfile( ...
    ROOT, ...
    'step6_trigging_events', ...
    'step_6_triggering_event_characteristics_radius_ALLOW_OVERLAP');


%% ========================================================================
% UPDATED API DIRECTORY -- K = 0.90
%% ========================================================================

API_ROOT_1 = fullfile( ...
    ROOT, ...
    'step5_crozier_outputs', ...
    'K_0p90');

API_ROOT_2 = fullfile( ...
    ROOT, ...
    'step_5_crozier_outputs', ...
    'K_0p90');


if exist(API_ROOT_1,'dir')

    API_ROOT = API_ROOT_1;

elseif exist(API_ROOT_2,'dir')

    API_ROOT = API_ROOT_2;

else

    error( ...
        ['API K=0.90 folder not found.\n\nChecked:\n%s\n\nand\n%s'], ...
        API_ROOT_1, ...
        API_ROOT_2);

end


fprintf('API directory found:\n%s\n\n',API_ROOT);

%% ========================================================================
% 5. OUTPUT DIRECTORY
%
% User requested continued work in the Step 7 folder.
%% ========================================================================

OUT_DIR = fullfile( ...
    ROOT, ...
    'step7_lag_selection_updated');


if ~exist(OUT_DIR,'dir')
    mkdir(OUT_DIR);
end


%% ========================================================================
% 6. CONFIGURATION
%% ========================================================================

KDECAY = 0.90;

YR_START = 2007;
YR_END   = 2021;


% Numerical tolerance for classification relative to 1:1 line
EQ_TOL = 1e-12;


fprintf('\n');
fprintf('=============================================================\n');
fprintf(' UPDATED NORMALIZED API vs TR ANALYSIS\n');
fprintf('=============================================================\n');

fprintf('Landslide radius       : station radius\n');
fprintf('Station overlap        : RETAINED\n');
fprintf('Catalogue duplicates   : previously removed\n');
fprintf('API K                  : %.2f\n',KDECAY);
fprintf('Study period           : %d-%d\n',YR_START,YR_END);

fprintf('\nOptimal lag file:\n%s\n',LAG_FILE);
fprintf('\nTrigger directory:\n%s\n',TRIGGER_DIR);
fprintf('\nAPI directory:\n%s\n',API_ROOT);
fprintf('\nOutput directory:\n%s\n',OUT_DIR);

fprintf('\n=============================================================\n\n');


%% ========================================================================
% 7. CHECK REQUIRED INPUTS
%% ========================================================================

if ~isfile(LAG_FILE)

    error( ...
        'Optimal lag Excel file not found:\n%s', ...
        LAG_FILE);

end


if ~exist(TRIGGER_DIR,'dir')

    error( ...
        'Triggering-event folder not found:\n%s', ...
        TRIGGER_DIR);

end


if ~exist(API_ROOT,'dir')

    error( ...
        'API K=0.90 folder not found:\n%s', ...
        API_ROOT);

end


%% ========================================================================
% 8. READ UPDATED INDEPENDENTLY SELECTED N*
%
% Step 7 output:
%
% Sheet:
%       Optimal_N
%
% Expected variables:
%
%       Station
%       IMD_ID
%       Optimal_N_days
%       Maximum_Kendall_tau
%       p_value
%       Number_of_events
%% ========================================================================

Lag = readtable( ...
    LAG_FILE, ...
    'Sheet','Optimal_N', ...
    'VariableNamingRule','preserve');


%% ------------------------------------------------------------------------
% Check expected variables
%% ------------------------------------------------------------------------

requiredLagVars = [ ...
    "Station", ...
    "IMD_ID", ...
    "Optimal_N_days"];


lagVars = string( ...
    Lag.Properties.VariableNames);


for vv = 1:numel(requiredLagVars)

    if ~ismember(requiredLagVars(vv),lagVars)

        error( ...
            'Required variable missing from lag file: %s', ...
            requiredLagVars(vv));

    end

end


%% ------------------------------------------------------------------------
% Standardize station names
%% ------------------------------------------------------------------------

Lag.Station = ...
    strip(string(Lag.Station));


%% ------------------------------------------------------------------------
% Standardize IMD IDs
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
% N* numeric
%% ------------------------------------------------------------------------

Lag.Optimal_N_days = ...
    double(Lag.Optimal_N_days);


%% ------------------------------------------------------------------------
% Remove stations without valid N*
%% ------------------------------------------------------------------------

Lag = Lag( ...
    isfinite(Lag.Optimal_N_days), ...
    :);


%% ========================================================================
% 9. SORT STATIONS BY UPDATED SELECTED N*
%
% Same logic as previous figure:
%
% ascending optimal lag first
% alphabetical order within the same optimal lag
%% ========================================================================

Lag = sortrows( ...
    Lag, ...
    {'Optimal_N_days','Station'}, ...
    {'ascend','ascend'});


nStations = ...
    height(Lag);


fprintf( ...
    'Stations with valid updated N*: %d\n\n', ...
    nStations);


if nStations ~= 21

    warning( ...
        'Expected 21 stations but found %d stations with valid N*.', ...
        nStations);

end


%% ========================================================================
% 10. PREALLOCATE STATION RESULTS
%% ========================================================================

Station = ...
    strings(nStations,1);


IMD_ID = ...
    strings(nStations,1);


N_star_days = ...
    nan(nStations,1);


N_events = ...
    nan(nStations,1);


API_GT_TR_count = ...
    nan(nStations,1);


TR_GT_API_count = ...
    nan(nStations,1);


Equal_count = ...
    nan(nStations,1);


API_GT_TR_fraction = ...
    nan(nStations,1);


TR_GT_API_fraction = ...
    nan(nStations,1);


Equal_fraction = ...
    nan(nStations,1);


Tau_API_TR = ...
    nan(nStations,1);


P_API_TR = ...
    nan(nStations,1);


API_source = ...
    strings(nStations,1);


Trigger_source = ...
    strings(nStations,1);


Status = ...
    strings(nStations,1);


%% ------------------------------------------------------------------------
% Storage for final tiled plot
%% ------------------------------------------------------------------------

API_norm_store = ...
    cell(nStations,1);


TR_norm_store = ...
    cell(nStations,1);


%% ------------------------------------------------------------------------
% Event-level audit
%% ------------------------------------------------------------------------

EventTable = ...
    table();


%% ========================================================================
% 11. MAIN STATION LOOP
%% ========================================================================

for i = 1:nStations


    station = ...
        Lag.Station(i);


    id = ...
        Lag.IMD_ID(i);


    Nstar = ...
        Lag.Optimal_N_days(i);


    Station(i) = ...
        station;


    IMD_ID(i) = ...
        id;


    N_star_days(i) = ...
        Nstar;


    fprintf( ...
        '%-18s | %-12s | N*=%2d d ... ', ...
        station, ...
        id, ...
        round(Nstar));


    %% ====================================================================
    % 11A. UPDATED TRIGGERING RAINFALL FILE
    %
    % Example:
    %
    %       326259402_trigging.txt
    %
    % File format:
    %
    %       Col 1 = landslide year
    %       Col 2 = landslide month
    %       Col 3 = landslide day
    %       Col 4 = triggering rainfall
    %       Col 5 = lag
    %       Col 6 = event duration
    %% ====================================================================

    triggerFile = fullfile( ...
        TRIGGER_DIR, ...
        sprintf( ...
        '%s_trigging.txt', ...
        char(id)));


    if ~isfile(triggerFile)

        Status(i) = ...
            "Trigger file missing";


        fprintf('TRIGGER FILE MISSING\n');

        continue

    end


    Trigger_source(i) = ...
        string(triggerFile);


    %% --------------------------------------------------------------------
    % Read triggering event file
    %% --------------------------------------------------------------------

    TRdata = readmatrix( ...
        triggerFile, ...
        'FileType','text');


    if isempty(TRdata) || ...
            size(TRdata,2) < 4


        Status(i) = ...
            "Invalid trigger file";


        fprintf('INVALID TRIGGER FILE\n');

        continue

    end


    %% --------------------------------------------------------------------
    % Remove invalid date/TR rows
    %% --------------------------------------------------------------------

    validTRrow = ...
        isfinite(TRdata(:,1)) & ...
        isfinite(TRdata(:,2)) & ...
        isfinite(TRdata(:,3)) & ...
        isfinite(TRdata(:,4));


    TRdata = ...
        TRdata(validTRrow,:);


    if isempty(TRdata)

        Status(i) = ...
            "No valid trigger rows";


        fprintf('NO VALID TRIGGER ROWS\n');

        continue

    end


    %% --------------------------------------------------------------------
    % Landslide event date
    %% --------------------------------------------------------------------

    eventDate = datetime( ...
        TRdata(:,1), ...
        TRdata(:,2), ...
        TRdata(:,3));


    %% --------------------------------------------------------------------
    % Triggering rainfall amount
    %% --------------------------------------------------------------------

    TR = ...
        TRdata(:,4);


    %% --------------------------------------------------------------------
    % Optional trigger characteristics for event audit
    %% --------------------------------------------------------------------

    if size(TRdata,2) >= 5

        TriggerLag_days = ...
            TRdata(:,5);

    else

        TriggerLag_days = ...
            nan(size(TR));

    end


    if size(TRdata,2) >= 6

        TriggerDuration_days = ...
            TRdata(:,6);

    else

        TriggerDuration_days = ...
            nan(size(TR));

    end


    %% ====================================================================
    % 11B. ANALYSIS PERIOD
    %% ====================================================================

    keep = ...
        year(eventDate) >= YR_START & ...
        year(eventDate) <= YR_END;


    eventDate = ...
        eventDate(keep);


    TR = ...
        TR(keep);


    TriggerLag_days = ...
        TriggerLag_days(keep);


    TriggerDuration_days = ...
        TriggerDuration_days(keep);


    if isempty(eventDate)


        Status(i) = ...
            "No events in period";


        fprintf('NO EVENTS IN PERIOD\n');

        continue

    end


    %% ====================================================================
    % 11C. UPDATED API FILE FOR ONLY SELECTED N*
    %
    % Example:
    %
    % API_ROOT:
    %
    %   K_0p90
    %       03_day
    %           42516_03d_crozier_K0p90.txt
    %
    %% ====================================================================

    lagFolder = sprintf( ...
        '%02d_day', ...
        round(Nstar));


    apiFilename = sprintf( ...
        '%s_%02dd_crozier_K0p90.txt', ...
        char(id), ...
        round(Nstar));


    apiFile = fullfile( ...
        API_ROOT, ...
        lagFolder, ...
        apiFilename);


    if ~isfile(apiFile)


        Status(i) = ...
            "API file missing";


        fprintf( ...
            'API FILE MISSING: %s\n', ...
            apiFilename);


        continue

    end


    API_source(i) = ...
        string(apiFile);


    %% --------------------------------------------------------------------
    % Read API
    %% --------------------------------------------------------------------

    APIdata = readmatrix( ...
        apiFile, ...
        'FileType','text');


    if isempty(APIdata) || ...
            size(APIdata,2) < 4


        Status(i) = ...
            "Invalid API file";


        fprintf('INVALID API FILE\n');

        continue

    end


    %% --------------------------------------------------------------------
    % Remove invalid rows
    %% --------------------------------------------------------------------

    validAPIrow = ...
        isfinite(APIdata(:,1)) & ...
        isfinite(APIdata(:,2)) & ...
        isfinite(APIdata(:,3)) & ...
        isfinite(APIdata(:,4));


    APIdata = ...
        APIdata(validAPIrow,:);


    %% --------------------------------------------------------------------
    % API event dates
    %% --------------------------------------------------------------------

    APIdate = datetime( ...
        APIdata(:,1), ...
        APIdata(:,2), ...
        APIdata(:,3));


    API = ...
        APIdata(:,4);


    %% ====================================================================
    % 11D. MATCH UPDATED API WITH UPDATED TR EVENTS
    %
    % IMPORTANT:
    %
    % API and triggering-event files were generated from the same updated
    % station-radius station landslide datasets.
    %
    % First preference:
    %
    %       direct row alignment
    %
    % when the two files have exactly the same event dates and row counts.
    %
    % Otherwise:
    %
    %       date-based matching is used as fallback.
    %% ====================================================================

    directMatch = ...
        numel(eventDate) == numel(APIdate);


    if directMatch

        directMatch = ...
            all(eventDate == APIdate);

    end


    %% --------------------------------------------------------------------
    % DIRECT ROW-ALIGNED MATCH
    %% --------------------------------------------------------------------

    if directMatch


        API_match = ...
            API;


        TR_match = ...
            TR;


        matchedDate = ...
            eventDate;


        TriggerLag_match = ...
            TriggerLag_days;


        TriggerDuration_match = ...
            TriggerDuration_days;


        matchMethod = ...
            repmat( ...
            "Direct row alignment", ...
            numel(API_match), ...
            1);


    else


        %% ----------------------------------------------------------------
        % FALLBACK: DATE MATCHING
        %
        % Same approach as previous analysis.
        %% ----------------------------------------------------------------

        [matched,locAPI] = ismember( ...
            eventDate, ...
            APIdate);


        API_match_temp = ...
            nan(size(TR));


        API_match_temp(matched) = ...
            API(locAPI(matched));


        valid = ...
            matched & ...
            isfinite(API_match_temp) & ...
            isfinite(TR);


        API_match = ...
            API_match_temp(valid);


        TR_match = ...
            TR(valid);


        matchedDate = ...
            eventDate(valid);


        TriggerLag_match = ...
            TriggerLag_days(valid);


        TriggerDuration_match = ...
            TriggerDuration_days(valid);


        matchMethod = ...
            repmat( ...
            "Date matching", ...
            numel(API_match), ...
            1);


        warning( ...
            ['%s (%s): API and trigger rows were not perfectly aligned. ' ...
             'Date matching was used.'], ...
            station, ...
            id);

    end


    %% --------------------------------------------------------------------
    % Final finite-value check
    %% --------------------------------------------------------------------

    validFinal = ...
        isfinite(API_match) & ...
        isfinite(TR_match);


    API_match = ...
        API_match(validFinal);


    TR_match = ...
        TR_match(validFinal);


    matchedDate = ...
        matchedDate(validFinal);


    TriggerLag_match = ...
        TriggerLag_match(validFinal);


    TriggerDuration_match = ...
        TriggerDuration_match(validFinal);


    matchMethod = ...
        matchMethod(validFinal);


    n = ...
        numel(API_match);


    %% --------------------------------------------------------------------
    % Minimum sample check
    %% --------------------------------------------------------------------

    if n < 3


        Status(i) = ...
            "Too few matched events";


        fprintf('TOO FEW MATCHED EVENTS\n');

        continue

    end


    %% ====================================================================
    % 11E. EMPIRICAL NORMALIZATION
    %
    % EXACT SAME NORMALIZATION AS PREVIOUS CODE:
    %
    %       tiedrank(value) / (n + 1)
    %% ====================================================================

    API_norm = ...
        tiedrank(API_match) ./ ...
        (n + 1);


    TR_norm = ...
        tiedrank(TR_match) ./ ...
        (n + 1);


    %% ====================================================================
    % 11F. POSITION RELATIVE TO 1:1 LINE
    %% ====================================================================

    difference = ...
        TR_norm - API_norm;


    %% --------------------------------------------------------------------
    % BELOW LINE:
    %
    % API > TR
    %% --------------------------------------------------------------------

    API_GT_TR = ...
        difference < -EQ_TOL;


    %% --------------------------------------------------------------------
    % ABOVE LINE:
    %
    % TR > API
    %% --------------------------------------------------------------------

    TR_GT_API = ...
        difference > EQ_TOL;


    %% --------------------------------------------------------------------
    % Approximately equal
    %% --------------------------------------------------------------------

    Equal = ...
        abs(difference) <= EQ_TOL;


    %% ====================================================================
    % 11G. COUNTS AND FRACTIONS
    %% ====================================================================

    N_events(i) = ...
        n;


    API_GT_TR_count(i) = ...
        sum(API_GT_TR);


    TR_GT_API_count(i) = ...
        sum(TR_GT_API);


    Equal_count(i) = ...
        sum(Equal);


    API_GT_TR_fraction(i) = ...
        API_GT_TR_count(i) / n;


    TR_GT_API_fraction(i) = ...
        TR_GT_API_count(i) / n;


    Equal_fraction(i) = ...
        Equal_count(i) / n;


    %% ====================================================================
    % 11H. KENDALL CORRELATION BETWEEN API AND TR
    %% ====================================================================

    [tauVal,pVal] = corr( ...
        API_norm, ...
        TR_norm, ...
        'Type','Kendall', ...
        'Rows','complete');


    Tau_API_TR(i) = ...
        tauVal;


    P_API_TR(i) = ...
        pVal;


    %% --------------------------------------------------------------------
    % Store normalized vectors for figure
    %% --------------------------------------------------------------------

    API_norm_store{i} = ...
        API_norm;


    TR_norm_store{i} = ...
        TR_norm;


    Status(i) = ...
        "OK";


    fprintf( ...
        ['n=%d | API>TR=%.0f%% | TR>API=%.0f%% ' ...
         '| tau=%+.2f\n'], ...
        n, ...
        100*API_GT_TR_fraction(i), ...
        100*TR_GT_API_fraction(i), ...
        tauVal);


    %% ====================================================================
    % 11I. EVENT-LEVEL AUDIT TABLE
    %% ====================================================================

    TEvent = table( ...
        repmat(station,n,1), ...
        repmat(id,n,1), ...
        repmat(Nstar,n,1), ...
        matchedDate, ...
        API_match, ...
        TR_match, ...
        API_norm, ...
        TR_norm, ...
        API_GT_TR, ...
        TR_GT_API, ...
        Equal, ...
        TriggerLag_match, ...
        TriggerDuration_match, ...
        matchMethod, ...
        'VariableNames',{ ...
        'Station', ...
        'IMD_ID', ...
        'N_star_days', ...
        'Event_date', ...
        'API_mm', ...
        'TR_mm', ...
        'API_normalized', ...
        'TR_normalized', ...
        'API_GT_TR', ...
        'TR_GT_API', ...
        'Equal_1to1', ...
        'Trigger_lag_days', ...
        'Trigger_duration_days', ...
        'Matching_method'});


    EventTable = [ ...
        EventTable; ...
        TEvent]; %#ok<AGROW>


end


%% ========================================================================
% 12. STATION SUMMARY TABLE
%% ========================================================================

Summary = table( ...
    Station, ...
    IMD_ID, ...
    N_star_days, ...
    repmat(KDECAY,nStations,1), ...
    N_events, ...
    API_GT_TR_count, ...
    TR_GT_API_count, ...
    Equal_count, ...
    API_GT_TR_fraction, ...
    TR_GT_API_fraction, ...
    Equal_fraction, ...
    Tau_API_TR, ...
    P_API_TR, ...
    API_source, ...
    Trigger_source, ...
    Status, ...
    'VariableNames',{ ...
    'Station', ...
    'IMD_ID', ...
    'N_star_days', ...
    'K', ...
    'N_events', ...
    'API_GT_TR_count', ...
    'TR_GT_API_count', ...
    'Equal_count', ...
    'API_GT_TR_fraction', ...
    'TR_GT_API_fraction', ...
    'Equal_fraction', ...
    'Kendall_tau_API_TR', ...
    'p_value_API_TR', ...
    'API_source', ...
    'Trigger_source', ...
    'Status'});


%% ========================================================================
% 13. WRITE UPDATED EXCEL OUTPUT
%% ========================================================================

outExcel = fullfile( ...
    OUT_DIR, ...
    'Step7B_API_TR_OptimalLag_Summary.xlsx');


if isfile(outExcel)

    delete(outExcel);

end


writetable( ...
    Summary, ...
    outExcel, ...
    'Sheet','Station_summary');


if ~isempty(EventTable)

    writetable( ...
        EventTable, ...
        outExcel, ...
        'Sheet','Event_level');

end


fprintf('\nWritten:\n%s\n',outExcel);


%% ========================================================================
% 14. ITANAGAR CHECK
%% ========================================================================

idxItanagar = contains( ...
    lower(Summary.Station), ...
    'itanagar');


if any(idxItanagar)


    fprintf('\n');
    fprintf('=============================================================\n');
    fprintf(' ITANAGAR UPDATED API-TR CHECK\n');
    fprintf('=============================================================\n');


    fprintf( ...
        'N*                   = %.0f d\n', ...
        Summary.N_star_days(idxItanagar));


    fprintf( ...
        'N events             = %.0f\n', ...
        Summary.N_events(idxItanagar));


    fprintf( ...
        'Kendall tau API-TR   = %.3f\n', ...
        Summary.Kendall_tau_API_TR(idxItanagar));


    fprintf( ...
        'p-value              = %.4f\n', ...
        Summary.p_value_API_TR(idxItanagar));


    fprintf( ...
        'API > TR fraction    = %.3f\n', ...
        Summary.API_GT_TR_fraction(idxItanagar));


    fprintf( ...
        'TR > API fraction    = %.3f\n', ...
        Summary.TR_GT_API_fraction(idxItanagar));


    fprintf('=============================================================\n\n');

end


%% ========================================================================
% 15. REGIONAL SUMMARY
%% ========================================================================

validSummary = ...
    Summary.Status == "OK";


fprintf('\n');
fprintf('=============================================================\n');
fprintf(' REGIONAL SUMMARY\n');
fprintf('=============================================================\n');


fprintf( ...
    'Stations successfully analysed : %d/%d\n', ...
    sum(validSummary), ...
    nStations);


fprintf( ...
    'Total station-event records    : %.0f\n', ...
    sum(Summary.N_events(validSummary),'omitnan'));


fprintf( ...
    'Sites with API > TR >= 50%%     : %d/%d\n', ...
    sum( ...
    Summary.API_GT_TR_fraction(validSummary) >= 0.50), ...
    sum(validSummary));


fprintf( ...
    'Sites with API > TR < 50%%      : %d/%d\n', ...
    sum( ...
    Summary.API_GT_TR_fraction(validSummary) < 0.50), ...
    sum(validSummary));


fprintf('=============================================================\n');


%% ========================================================================
% 16. PROFESSIONAL 21-SITE TILED FIGURE
%
% EXACT STYLE INTENT OF PREVIOUS PLOT:
%
%   - 3 x 7 tiled layout
%   - station order follows ascending updated N*
%   - pale-blue points
%   - blue marker border
%   - dashed 1:1 line
%   - bold station titles
%   - N* shown in each panel
%   - no Kendall tau text
%   - API > TR and TR > API as percentages
%   - large bold percentage labels
%   - repeated axis tick labels removed
%   - shared X/Y labels
%   - NO overall title
%% ========================================================================

validSites = find( ...
    Status == "OK");


nValid = ...
    numel(validSites);


if nValid == 0

    error( ...
        'No valid stations available for plotting.');

end


%% ------------------------------------------------------------------------
% Layout
%% ------------------------------------------------------------------------

if nValid <= 21

    nRows = 3;
    nCols = 7;

else

    nCols = 7;
    nRows = ceil(nValid/nCols);

end


%% ========================================================================
% 17. FIGURE
%% ========================================================================

fig = figure( ...
    'Color','w', ...
    'Units','centimeters', ...
    'Position',[1 1 42 20], ...
    'Renderer','painters');


tl = tiledlayout( ...
    fig, ...
    nRows, ...
    nCols, ...
    'TileSpacing','compact', ...
    'Padding','compact');


%% ========================================================================
% 18. EXACT FIGURE STYLE
%% ========================================================================

pointFace = [ ...
    0.68 0.82 0.95];


pointEdge = [ ...
    0.08 0.30 0.55];


oneLineColor = [ ...
    0.30 0.30 0.30];


markerSize = ...
    38;


tickFont = ...
    11.5;


titleFont = ...
    13.0;


infoFont = ...
    11.5;


axisLabelFont = ...
    17;


%% ========================================================================
% 19. DRAW EACH STATION TILE
%% ========================================================================

for q = 1:nValid


    i = ...
        validSites(q);


    ax = ...
        nexttile(tl,q);


    hold(ax,'on');


    x = ...
        API_norm_store{i};


    y = ...
        TR_norm_store{i};


    %% --------------------------------------------------------------------
    % Scatter
    %% --------------------------------------------------------------------

    scatter( ...
        ax, ...
        x, ...
        y, ...
        markerSize, ...
        'o', ...
        'filled', ...
        'MarkerFaceColor',pointFace, ...
        'MarkerEdgeColor',pointEdge, ...
        'MarkerFaceAlpha',0.72, ...
        'MarkerEdgeAlpha',0.95, ...
        'LineWidth',0.9);


    %% --------------------------------------------------------------------
    % 1:1 reference line
    %% --------------------------------------------------------------------

    plot( ...
        ax, ...
        [0 1], ...
        [0 1], ...
        '--', ...
        'Color',oneLineColor, ...
        'LineWidth',1.25);


    %% ====================================================================
    % AXES
    %% ====================================================================

    xlim(ax,[0 1]);

    ylim(ax,[0 1]);


    xticks( ...
        ax, ...
        [0 0.5 1]);


    yticks( ...
        ax, ...
        [0 0.5 1]);


    axis(ax,'square');


    set( ...
        ax, ...
        'FontSize',tickFont, ...
        'FontWeight','bold', ...
        'XColor','k', ...
        'YColor','k', ...
        'LineWidth',1.0, ...
        'TickDir','out', ...
        'TickLength',[0.025 0.025], ...
        'Box','on', ...
        'Layer','top');


    %% ====================================================================
    % PANEL TITLE
    %% ====================================================================

    titleText = sprintf( ...
        '%s  (N^* = %d d)', ...
        char(Station(i)), ...
        round(N_star_days(i)));


    title( ...
        ax, ...
        titleText, ...
        'FontSize',titleFont, ...
        'FontWeight','bold', ...
        'Color','k', ...
        'Interpreter','tex');


    %% ====================================================================
    % API > TR / TR > API PERCENTAGES
    %% ====================================================================

    pct_API_GT_TR = ...
        100 * ...
        API_GT_TR_fraction(i);


    pct_TR_GT_API = ...
        100 * ...
        TR_GT_API_fraction(i);


    info = sprintf( ...
        ['API > TR: %.0f%%\n' ...
         'TR > API: %.0f%%'], ...
        pct_API_GT_TR, ...
        pct_TR_GT_API);


    text( ...
        ax, ...
        0.045, ...
        0.955, ...
        info, ...
        'Units','normalized', ...
        'HorizontalAlignment','left', ...
        'VerticalAlignment','top', ...
        'FontSize',infoFont, ...
        'FontWeight','bold', ...
        'Color','k');


    %% ====================================================================
    % REMOVE REPEATED AXIS TICK LABELS
    %% ====================================================================

    rowNum = ...
        ceil(q/nCols);


    colNum = ...
        mod(q-1,nCols) + 1;


    %% --------------------------------------------------------------------
    % Y ticks only in first column
    %% --------------------------------------------------------------------

    if colNum ~= 1

        ax.YTickLabel = [];

    end


    %% --------------------------------------------------------------------
    % X ticks only on bottom row
    %% --------------------------------------------------------------------

    if rowNum ~= nRows

        ax.XTickLabel = [];

    end


end


%% ========================================================================
% 20. SHARED AXIS LABELS
%
% NO overall title.
%% ========================================================================

xlabel( ...
    tl, ...
    'Normalized API at independently selected N^*', ...
    'FontSize',axisLabelFont, ...
    'FontWeight','bold', ...
    'Color','k', ...
    'Interpreter','tex');


ylabel( ...
    tl, ...
    'Normalized triggering rainfall (TR)', ...
    'FontSize',axisLabelFont, ...
    'FontWeight','bold', ...
    'Color','k');


%% ========================================================================
% 21. EXPORT PUBLICATION FIGURE
%% ========================================================================

outPNG = fullfile( ...
    OUT_DIR, ...
    'Step7B_API_TR_OptimalLag_1to1_Tiled.png');


outTIF = fullfile( ...
    OUT_DIR, ...
    'Step7B_API_TR_OptimalLag_1to1_Tiled.tiff');


outFIG = fullfile( ...
    OUT_DIR, ...
    'Step7B_API_TR_OptimalLag_1to1_Tiled.fig');


exportgraphics( ...
    fig, ...
    outPNG, ...
    'Resolution',600);


exportgraphics( ...
    fig, ...
    outTIF, ...
    'Resolution',600);


savefig( ...
    fig, ...
    outFIG);


%% ========================================================================
% 22. SAVE MATLAB RESULTS
%% ========================================================================

outMAT = fullfile( ...
    OUT_DIR, ...
    'Step7B_API_TR_OptimalLag_Results.mat');


save( ...
    outMAT, ...
    'Summary', ...
    'EventTable', ...
    'API_norm_store', ...
    'TR_norm_store', ...
    'Station', ...
    'IMD_ID', ...
    'N_star_days', ...
    'N_events', ...
    'API_GT_TR_count', ...
    'TR_GT_API_count', ...
    'Equal_count', ...
    'API_GT_TR_fraction', ...
    'TR_GT_API_fraction', ...
    'Equal_fraction', ...
    'Tau_API_TR', ...
    'P_API_TR', ...
    'KDECAY', ...
    'YR_START', ...
    'YR_END');


%% ========================================================================
% 23. FINAL MESSAGE
%% ========================================================================

fprintf('\n');
fprintf('=============================================================\n');
fprintf(' UPDATED API vs TR ANALYSIS COMPLETE\n');
fprintf('=============================================================\n');


fprintf( ...
    'Stations analysed : %d/%d\n', ...
    nValid, ...
    nStations);


fprintf('\nExcel:\n%s\n', ...
    outExcel);


fprintf('\nPNG:\n%s\n', ...
    outPNG);


fprintf('\nTIFF:\n%s\n', ...
    outTIF);


fprintf('\nMATLAB figure:\n%s\n', ...
    outFIG);


fprintf('\nMAT results:\n%s\n', ...
    outMAT);


fprintf('\n=============================================================\n');