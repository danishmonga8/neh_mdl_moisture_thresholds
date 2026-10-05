%% ========================================================================
% STEP 2 -- CORRECTED ADF USING INDEPENDENTLY SELECTED N*
%
% Reviewer 2, Comment 11
%
% STEP 1 already completed:
%
%       N* = argmax_N Kendall tau [ API(N), S_eff(t-1) ]
%
% STEP 2:
%   - keep N* fixed for each station
%   - use API calculated at that N* with K = 0.9
%   - compare API(N*) with triggering rainfall TR
%   - calculate corrected ADF
%
%       ADF = number of landslide events where API(N*) > TR
%             ------------------------------------------------
%                        total matched events
%
% IMPORTANT:
%   N* is NOT optimized using API > TR in this script.
%
% ------------------------------------------------------------------------
% REVISION NOTES (this update)
% ------------------------------------------------------------------------
%   1. N* ("Ideal_lag") is now read directly from all_stations_neh.xlsx
%      (Sheet1), which carries the UPDATED Step 7 lag-selection result
%      (matches Step7_Optimal_Lag_Summary.xlsx -> Optimal_N -> Optimal_N_days
%      exactly). The separate Step1_LagSelection_Summary.xlsx read has
%      been removed -- that file held the earlier N* values and is no
%      longer the source of truth. Station Lat/Lon are read from the same
%      workbook/sheet, so there is now a single metadata source instead
%      of two.
%
%   2. TR and API inputs now come from the revision_round1 folder
%      structure:
%         TR  : revision_round1\step6_trigging_events\
%               step_6_triggering_event_characteristics_radius_ALLOW_OVERLAP
%         API : revision_round1\step5_crozier_outputs\K_0p90\<NN>_day\
%      The API filename pattern also changed:
%         old : <ID>_<N>_crozier_5.txt          (no zero-padding)
%         new : <ID>_<NN>d_crozier_K0p90.txt    (2-digit zero-padded N,
%                                                 K encoded in the name)
%      Both the day-folder tag and the K tag are now built from KDECAY,
%      not hard-coded, so a future change to K only requires editing
%      KDECAY. The ROOT_B fallback (2_new_stations_neh) has been removed
%      -- there is a single, current source folder.
%
%   3. Stations with fewer than MIN_EVENTS_FOR_CLASSIFICATION matched
%      landslide events are still plotted on the spatial map (so the
%      station network is shown in full) but are drawn in grey instead
%      of being coloured by ADF, and are excluded from the donut/pie
%      percentages -- ADF is not considered reliable at very small n.
%      They are still written to the Excel output (flagged in a new
%      Low_sample column) for audit purposes.
% ========================================================================

clc;
clear;
close all;


%% ========================================================================
% 1. PATHS
%% ========================================================================

ROOT_A = ...
    fullfile(neh_root());


WORK_DIR = fullfile( ...
    ROOT_A, ...
    'revision_round1', ...
    'step2_adf_correction');


TRIGGER_DIR = fullfile( ...
    ROOT_A, ...
    'revision_round1', ...
    'step6_trigging_events', ...
    'step_6_triggering_event_characteristics_radius_ALLOW_OVERLAP');


API_ROOT = fullfile( ...
    ROOT_A, ...
    'revision_round1', ...
    'step5_crozier_outputs');


META_FILE = fullfile( ...
    ROOT_A, ...
    'all_stations_neh.xlsx');


SHAPEFILE = ...
    fullfile(neh_root(),'western_himalayas_landslide','spatial_variation_map','my_study_shape','Himalayan_UP_Bihar.shp');


if ~exist(WORK_DIR,'dir')
    mkdir(WORK_DIR);
end


%% ========================================================================
% 2. CONFIGURATION
%% ========================================================================

KDECAY = 0.90;

% Folder tag e.g. 'K_0p90', filename tag e.g. '0p90' -- both derived from
% KDECAY so this is the only place K needs to change.
K_folder_tag = sprintf('K_0p%02d', round(KDECAY*100));
K_file_tag   = sprintf('0p%02d',   round(KDECAY*100));

% Keep same temporal window used in Step 1.
% Change here only if advisor decides to calculate final ADF over a
% different study period.
YR_START = 2007;
YR_END   = 2019;

ADF_THRESHOLD = 0.50;

% Stations with fewer matched landslide events than this are shown in
% grey (not colour-coded by ADF) on the spatial map, and are excluded
% from the donut/pie classification counts.
MIN_EVENTS_FOR_CLASSIFICATION = 15;


%% ========================================================================
% 3. OUTPUT FILES
%% ========================================================================

OUT_XLSX = fullfile( ...
    WORK_DIR, ...
    'Step2_ADF_Corrected_Results.xlsx');


OUT_MAP_PNG = fullfile( ...
    WORK_DIR, ...
    'Step2_ADF_NEH_Map.png');

OUT_MAP_TIF = fullfile( ...
    WORK_DIR, ...
    'Step2_ADF_NEH_Map.tiff');


OUT_DONUT_PNG = fullfile( ...
    WORK_DIR, ...
    'Step2_ADF_Donut.png');

OUT_DONUT_TIF = fullfile( ...
    WORK_DIR, ...
    'Step2_ADF_Donut.tiff');


%% ========================================================================
% 4. READ STATION METADATA + UPDATED IDEAL LAG (SINGLE SOURCE)
%
% Station name, IMD/WMO ID, Lat, Long and the updated N* ("Ideal_lag")
% are all read from all_stations_neh.xlsx, Sheet1. This replaces the old
% two-file read (Step1_LagSelection_Summary.xlsx for N*, a separate
% metadata file for Lat/Lon).
%% ========================================================================

optsMeta = detectImportOptions( ...
    META_FILE, ...
    'Sheet','Sheet1', ...
    'VariableNamingRule','preserve', ...
    'TextType','string');


TM = readtable( ...
    META_FILE, ...
    optsMeta);


metaVarsRaw = string( ...
    TM.Properties.VariableNames);

metaVarsKey = lower( ...
    strtrim(metaVarsRaw));


latCol = find( ...
    contains(metaVarsKey,"lat"), ...
    1,'first');


lonCol = find( ...
    metaVarsKey == "long" | contains(metaVarsKey,"lon"), ...
    1,'first');


lagCol = find( ...
    contains(metaVarsKey,"ideal_lag") | contains(metaVarsKey,"ideal lag"), ...
    1,'first');


if isempty(latCol) || isempty(lonCol)

    error( ...
        'Latitude or longitude column not detected in all_stations_neh.xlsx');

end


if isempty(lagCol)

    error( ...
        'Ideal_lag column not detected in all_stations_neh.xlsx (Sheet1).');

end


% As used previously:
% column 1 = station
% column 2 = IMD/WMO ID

metaStation = string( ...
    TM{:,1});


metaID = normalizeID( ...
    TM{:,2});


metaLat = double( ...
    TM{:,latCol});


metaLon = double( ...
    TM{:,lonCol});


metaNstar = double( ...
    TM{:,lagCol});


TMeta = table( ...
    strip(metaStation), ...
    metaID, ...
    metaLat, ...
    metaLon, ...
    metaNstar, ...
    'VariableNames', ...
    {'Station_meta','IMD_ID','Lat','Lon','N_star_d'});


% Remove duplicated station-ID rows
[~,idxUnique] = unique( ...
    TMeta.IMD_ID, ...
    'stable');


TMeta = TMeta(idxUnique,:);


% Use only stations having a valid (finite) updated N*
TMeta = TMeta( ...
    isfinite(TMeta.N_star_d), :);


nStations = height(TMeta);


fprintf('\n=============================================================\n');
fprintf(' STEP 2 -- CORRECTED ADF\n');
fprintf(' K = %.2f  (folder %s)\n',KDECAY,K_folder_tag);
fprintf(' Period = %d-%d\n',YR_START,YR_END);
fprintf(' Stations = %d\n',nStations);
fprintf(' N* source = %s (Sheet1, updated Step 7 lag selection)\n',META_FILE);
fprintf('=============================================================\n\n');


%% ========================================================================
% 5. PREALLOCATE STATION SUMMARY
%% ========================================================================

Station             = strings(nStations,1);
IMD_ID              = strings(nStations,1);

N_star_days         = nan(nStations,1);

K_value             = repmat( ...
    KDECAY, ...
    nStations,1);

N_trigger_rows      = zeros(nStations,1);

N_period_rows       = zeros(nStations,1);

N_matched_events    = zeros(nStations,1);

N_API_gt_TR         = zeros(nStations,1);

ADF                 = nan(nStations,1);

Duplicate_date_rows = zeros(nStations,1);

API_source          = strings(nStations,1);

API_file_used       = strings(nStations,1);

Status              = strings(nStations,1);


%% ========================================================================
% 6. EVENT-LEVEL OUTPUT TABLE
%% ========================================================================

EventTable = table();


%% ========================================================================
% 7. MAIN STATION LOOP
%% ========================================================================

for i = 1:nStations

    station = strip( ...
        string(TMeta.Station_meta(i)));


    id = TMeta.IMD_ID(i);


    Nstar = TMeta.N_star_d(i);


    Station(i)     = station;
    IMD_ID(i)      = id;
    N_star_days(i) = Nstar;


    fprintf( ...
        '%-18s | ID %-12s | N* = %2d d ... ', ...
        station,id,Nstar);


    %% --------------------------------------------------------------------
    % 7A. TRIGGERING EVENT FILE
    %% --------------------------------------------------------------------

    triggerFile = fullfile( ...
        TRIGGER_DIR, ...
        id + "_trigging.txt");


    if ~isfile(triggerFile)

        Status(i) = "trigger file missing";

        fprintf('TRIGGER FILE MISSING\n');

        continue

    end


    TRdata = readmatrix( ...
        triggerFile, ...
        'FileType','text');


    if isempty(TRdata) || size(TRdata,2) < 4

        Status(i) = "invalid trigger file";

        fprintf('INVALID TRIGGER FILE\n');

        continue

    end


    N_trigger_rows(i) = size(TRdata,1);


    eventDate = datetime( ...
        TRdata(:,1), ...
        TRdata(:,2), ...
        TRdata(:,3));


    TR = TRdata(:,4);


    %% --------------------------------------------------------------------
    % Period restriction
    %% --------------------------------------------------------------------

    periodMask = ...
        year(eventDate) >= YR_START & ...
        year(eventDate) <= YR_END;


    eventDatePeriod = eventDate(periodMask);

    TRperiod = TR(periodMask);


    % Original row number retained for auditing
    originalRow = find(periodMask);


    N_period_rows(i) = numel( ...
        eventDatePeriod);


    %% --------------------------------------------------------------------
    % Check repeated event dates
    %
    % IMPORTANT:
    % We DO NOT remove these rows here.
    % Reviewer 2 Comment 4 requires separate event-deduplication auditing.
    %
    % This calculation preserves every input row.
    %% --------------------------------------------------------------------

    [~,~,dateGroup] = unique( ...
        eventDatePeriod);


    groupCounts = accumarray( ...
        dateGroup,1);


    duplicateFlag = ...
        groupCounts(dateGroup) > 1;


    Duplicate_date_rows(i) = ...
        sum(duplicateFlag);


    %% --------------------------------------------------------------------
    % 7B. API FILE AT FIXED N*
    %% --------------------------------------------------------------------

    apiFilename = sprintf( ...
        '%s_%02dd_crozier_K%s.txt', ...
        id,Nstar,K_file_tag);


    apiFile = fullfile( ...
        API_ROOT, ...
        K_folder_tag, ...
        sprintf('%02d_day',Nstar), ...
        apiFilename);


    if isfile(apiFile)

        API_source(i) = K_folder_tag;


    else

        Status(i) = "API file missing";

        fprintf('API FILE MISSING (%s)\n',apiFile);

        continue

    end


    API_file_used(i) = apiFile;


    APIdata = readmatrix( ...
        apiFile, ...
        'FileType','text');


    if isempty(APIdata) || size(APIdata,2) < 4

        Status(i) = "invalid API file";

        fprintf('INVALID API FILE\n');

        continue

    end


    APIdate = datetime( ...
        APIdata(:,1), ...
        APIdata(:,2), ...
        APIdata(:,3));


    APIvalue = APIdata(:,4);


    %% --------------------------------------------------------------------
    % 7C. MATCH API TO EVERY TRIGGERING EVENT
    %
    % ismember preserves repeated landslide rows.
    %
    % DO NOT use intersect() here because intersect collapses duplicate
    % dates and would reduce the number of landslide events.
    %% --------------------------------------------------------------------

    [matched,locAPI] = ismember( ...
        eventDatePeriod, ...
        APIdate);


    APImatched = nan( ...
        size(TRperiod));


    APImatched(matched) = ...
        APIvalue(locAPI(matched));


    valid = ...
        matched & ...
        isfinite(TRperiod) & ...
        isfinite(APImatched);


    N_matched_events(i) = ...
        sum(valid);


    %% --------------------------------------------------------------------
    % 7D. CORRECTED ADF
    %% --------------------------------------------------------------------

    eventDominance = false( ...
        size(TRperiod));


    eventDominance(valid) = ...
        APImatched(valid) > TRperiod(valid);


    N_API_gt_TR(i) = ...
        sum(eventDominance(valid));


    if N_matched_events(i) > 0

        ADF(i) = ...
            N_API_gt_TR(i) / ...
            N_matched_events(i);

        Status(i) = "OK";

    else

        Status(i) = "no matched events";

    end


    fprintf( ...
        'n = %d | API>TR = %d | ADF = %.3f\n', ...
        N_matched_events(i), ...
        N_API_gt_TR(i), ...
        ADF(i));


    %% --------------------------------------------------------------------
    % 7E. EVENT-LEVEL AUDIT TABLE
    %% --------------------------------------------------------------------

    nRowsThis = numel( ...
        eventDatePeriod);


    TEvent = table( ...
        repmat(station,nRowsThis,1), ...
        repmat(id,nRowsThis,1), ...
        originalRow, ...
        eventDatePeriod, ...
        TRperiod, ...
        APImatched, ...
        valid, ...
        eventDominance, ...
        duplicateFlag, ...
        repmat(Nstar,nRowsThis,1), ...
        repmat(KDECAY,nRowsThis,1), ...
        'VariableNames', ...
        { ...
        'Station', ...
        'IMD_ID', ...
        'Original_trigger_row', ...
        'Event_date', ...
        'TR_mm', ...
        'API_mm', ...
        'Matched_API', ...
        'API_greater_TR', ...
        'Duplicate_event_date', ...
        'N_star_days', ...
        'K'});


    EventTable = [EventTable; TEvent]; %#ok<AGROW>

end


%% ========================================================================
% 8. STATION SUMMARY TABLE
%% ========================================================================

Summary = table( ...
    Station, ...
    IMD_ID, ...
    N_star_days, ...
    K_value, ...
    N_trigger_rows, ...
    N_period_rows, ...
    N_matched_events, ...
    N_API_gt_TR, ...
    ADF, ...
    Duplicate_date_rows, ...
    API_source, ...
    API_file_used, ...
    Status, ...
    'VariableNames', ...
    { ...
    'Station', ...
    'IMD_ID', ...
    'N_star_days', ...
    'K', ...
    'Trigger_rows_all_years', ...
    'Trigger_rows_analysis_period', ...
    'Matched_events', ...
    'API_greater_TR_events', ...
    'ADF', ...
    'Rows_with_duplicate_date', ...
    'API_source', ...
    'API_file_used', ...
    'Status'});


%% ========================================================================
% 9. ADD LATITUDE / LONGITUDE
%% ========================================================================

Spatial = innerjoin( ...
    Summary, ...
    TMeta(:,{'IMD_ID','Lat','Lon'}), ...
    'Keys','IMD_ID');


Spatial = Spatial( ...
    Spatial.Status == "OK" & ...
    isfinite(Spatial.ADF) & ...
    isfinite(Spatial.Lat) & ...
    isfinite(Spatial.Lon), :);


%% ========================================================================
% 10. CLASSIFY ADF
%% ========================================================================

Spatial.ADF_class = strings( ...
    height(Spatial),1);


Spatial.ADF_class( ...
    Spatial.ADF >= ADF_THRESHOLD) = ...
    "AMC-dominant";


Spatial.ADF_class( ...
    Spatial.ADF < ADF_THRESHOLD) = ...
    "TR-dominant";


%% ========================================================================
% 11. FLAG LOW-SAMPLE STATIONS
%
% Stations with fewer than MIN_EVENTS_FOR_CLASSIFICATION matched events
% are still plotted (in grey, see Section 19) but are excluded from the
% donut/pie counts in Section 20.
%% ========================================================================

Spatial.Low_sample = ...
    Spatial.Matched_events < MIN_EVENTS_FOR_CLASSIFICATION;


%% ========================================================================
% 12. WRITE EXCEL OUTPUT
%% ========================================================================

if isfile(OUT_XLSX)
    delete(OUT_XLSX);
end


writetable( ...
    Summary, ...
    OUT_XLSX, ...
    'Sheet','ADF_summary');


writetable( ...
    EventTable, ...
    OUT_XLSX, ...
    'Sheet','Event_level');


writetable( ...
    Spatial, ...
    OUT_XLSX, ...
    'Sheet','Spatial_map_data');


fprintf('\nWritten:\n%s\n',OUT_XLSX);


%% ========================================================================
% 13. CONSOLE SUMMARY
%% ========================================================================

validADF = Summary.ADF( ...
    isfinite(Summary.ADF));


fprintf('\n=============================================================\n');
fprintf(' STEP 2 SUMMARY\n');
fprintf('=============================================================\n');

fprintf( ...
    'Valid stations      : %d / %d\n', ...
    numel(validADF), ...
    nStations);


fprintf( ...
    'ADF median          : %.3f\n', ...
    median(validADF,'omitnan'));


fprintf( ...
    'ADF range           : %.3f - %.3f\n', ...
    min(validADF,[],'omitnan'), ...
    max(validADF,[],'omitnan'));


fprintf( ...
    'ADF >= %.2f          : %d stations\n', ...
    ADF_THRESHOLD, ...
    sum(validADF >= ADF_THRESHOLD));


fprintf( ...
    'ADF < %.2f           : %d stations\n', ...
    ADF_THRESHOLD, ...
    sum(validADF < ADF_THRESHOLD));


fprintf( ...
    'Repeated-date rows  : %d\n', ...
    sum(Summary.Rows_with_duplicate_date));


fprintf( ...
    'Low-sample stations (< %d matched events, greyed/excluded from donut) : %d / %d\n', ...
    MIN_EVENTS_FOR_CLASSIFICATION, ...
    sum(Spatial.Low_sample), ...
    height(Spatial));


fprintf('=============================================================\n\n');


%% ========================================================================
% 14. SAME PROFESSIONAL COLORMAP AS GINI FIGURE
%% ========================================================================

anchor = [ ...
    252 253 191
    251 191 115
    239 104 102
    175  54 160
     66  15 112
      0   0   4] / 255;


xi = linspace( ...
    0,1,size(anchor,1));


xq = linspace( ...
    0,1,256);


cmap = interp1( ...
    xi, ...
    anchor, ...
    xq, ...
    'pchip');


%% ========================================================================
% 15. READ SHAPEFILE
%% ========================================================================

Sall = shaperead( ...
    SHAPEFILE, ...
    'UseGeoCoords',true);


%% ========================================================================
% 16. KEEP ONLY POLYGONS INTERSECTING NEH STATIONS
%
% Same logic used in the Gini-map script.
%
% This prevents the complete Himalayan / Indian shapefile from being drawn.
%% ========================================================================

nehStationMask = ...
    isfinite(TMeta.Lat) & ...
    isfinite(TMeta.Lon) & ...
    TMeta.Lat >= 21.5 & ...
    TMeta.Lat <= 30.0 & ...
    TMeta.Lon >= 87.0 & ...
    TMeta.Lon <= 98.0;


allMetaLat = ...
    TMeta.Lat(nehStationMask);


allMetaLon = ...
    TMeta.Lon(nehStationMask);


keepShape = false( ...
    numel(Sall),1);


for i = 1:numel(Sall)

    Xall = Sall(i).Lon(:);
    Yall = Sall(i).Lat(:);


    if isempty(Xall) || isempty(Yall)

        continue

    end


    nanBreaks = find( ...
        isnan(Xall) | isnan(Yall));


    segStart = [1; nanBreaks+1];

    segEnd = [nanBreaks-1; numel(Xall)];


    insideThisShape = false;


    for s = 1:numel(segStart)

        i1 = segStart(s);
        i2 = segEnd(s);


        if i2 <= i1
            continue
        end


        xs = Xall(i1:i2);
        ys = Yall(i1:i2);


        good = ...
            isfinite(xs) & ...
            isfinite(ys);


        xs = xs(good);
        ys = ys(good);


        if numel(xs) < 3
            continue
        end


        inside = inpolygon( ...
            allMetaLon, ...
            allMetaLat, ...
            xs, ...
            ys);


        if any(inside)

            insideThisShape = true;

            break

        end

    end


    keepShape(i) = ...
        insideThisShape;

end


S = Sall(keepShape);


if isempty(S)

    error( ...
        'No NEH polygons were retained. Check shapefile and coordinates.');

end


%% ========================================================================
% 17. MAP BOUNDING BOX
%% ========================================================================

allLonShape = [];
allLatShape = [];


for i = 1:numel(S)

    allLonShape = [ ...
        allLonShape; ...
        S(i).Lon(:)]; %#ok<AGROW>


    allLatShape = [ ...
        allLatShape; ...
        S(i).Lat(:)]; %#ok<AGROW>

end


allLonShape = ...
    allLonShape(isfinite(allLonShape));


allLatShape = ...
    allLatShape(isfinite(allLatShape));


bbXmin = min(allLonShape);
bbXmax = max(allLonShape);

bbYmin = min(allLatShape);
bbYmax = max(allLatShape);


padX = ...
    0.03*(bbXmax-bbXmin);


padY = ...
    0.03*(bbYmax-bbYmin);


xlimMap = [ ...
    bbXmin-padX, ...
    bbXmax+padX];


ylimMap = [ ...
    bbYmin-padY, ...
    bbYmax+padY];


lonMajor = ...
    floor(xlimMap(1)):1:ceil(xlimMap(2));


latMajor = ...
    floor(ylimMap(1)):1:ceil(ylimMap(2));


%% ========================================================================
% 18. MAP STYLE -- SAME AS GINI FIGURE
%% ========================================================================

axisTitleSize = 26;
axisTextSize  = 20;

cbarTitleSize = 22;
cbarTextSize  = 18;

markerSize  = 220;
markerAlpha = 0.68;

shapeEdgeLW  = 1.10;
shapeEdgeCol = [0.22 0.22 0.22];

gridColor = [0.80 0.80 0.80];
gridLW    = 0.40;

lowSampleColor = [0.65 0.65 0.65];


%% ========================================================================
% 19. ADF SPATIAL MAP
%% ========================================================================

fig = figure( ...
    'Color','w', ...
    'Units','inches', ...
    'Position',[1 1 12 8]);


ax = axes( ...
    'Parent',fig, ...
    'Position',[0.08 0.27 0.84 0.66]);


hold(ax,'on');


%% ------------------------------------------------------------------------
% Polygon background
%% ------------------------------------------------------------------------

for i = 1:numel(S)

    patch( ...
        ax, ...
        S(i).Lon, ...
        S(i).Lat, ...
        [0.96 0.96 0.96], ...
        'EdgeColor',shapeEdgeCol, ...
        'LineWidth',shapeEdgeLW);

end


%% ------------------------------------------------------------------------
% Gridlines
%% ------------------------------------------------------------------------

for xg = lonMajor

    plot( ...
        ax, ...
        [xg xg], ...
        [ylimMap(1) ylimMap(2)], ...
        '--', ...
        'Color',gridColor, ...
        'LineWidth',gridLW);

end


for yg = latMajor

    plot( ...
        ax, ...
        [xlimMap(1) xlimMap(2)], ...
        [yg yg], ...
        '--', ...
        'Color',gridColor, ...
        'LineWidth',gridLW);

end


%% ------------------------------------------------------------------------
% Station points -- colour = corrected ADF
%
% Stations below MIN_EVENTS_FOR_CLASSIFICATION are drawn in grey instead
% of being colour-mapped, so the full station network is still visible.
%% ------------------------------------------------------------------------

isLow = Spatial.Low_sample;


scatter( ...
    ax, ...
    Spatial.Lon(isLow), ...
    Spatial.Lat(isLow), ...
    markerSize, ...
    lowSampleColor, ...
    'filled', ...
    'MarkerFaceAlpha',markerAlpha, ...
    'MarkerEdgeColor','k', ...
    'LineWidth',1.05);


scatter( ...
    ax, ...
    Spatial.Lon(~isLow), ...
    Spatial.Lat(~isLow), ...
    markerSize, ...
    Spatial.ADF(~isLow), ...
    'filled', ...
    'MarkerFaceAlpha',markerAlpha, ...
    'MarkerEdgeColor','k', ...
    'LineWidth',1.05);


colormap(ax,cmap);


clim(ax,[0 1]);


axis(ax,'equal');


xlim(ax,xlimMap);
ylim(ax,ylimMap);


set( ...
    ax, ...
    'FontSize',axisTextSize, ...
    'XColor','k', ...
    'YColor','k', ...
    'LineWidth',0.9, ...
    'Layer','top', ...
    'Box','off', ...
    'TickDir','out');


xlabel( ...
    ax, ...
    'Longitude', ...
    'FontSize',axisTitleSize, ...
    'FontWeight','bold');


ylabel( ...
    ax, ...
    'Latitude', ...
    'FontSize',axisTitleSize, ...
    'FontWeight','bold');


%% ------------------------------------------------------------------------
% Degree-formatted axis ticks
%% ------------------------------------------------------------------------

xTicksMap = ...
    ceil(xlimMap(1)):2:floor(xlimMap(2));


yTicksMap = ...
    ceil(ylimMap(1)):1:floor(ylimMap(2));


xticks(ax,xTicksMap);

xticklabels( ...
    ax, ...
    compose('%d°E',xTicksMap));


yticks(ax,yTicksMap);

yticklabels( ...
    ax, ...
    compose('%d°N',yTicksMap));


%% ------------------------------------------------------------------------
% Low-sample legend (grey markers)
%% ------------------------------------------------------------------------

hLowSample = scatter( ...
    ax, ...
    NaN,NaN, ...
    markerSize, ...
    lowSampleColor, ...
    'filled', ...
    'MarkerEdgeColor','k', ...
    'LineWidth',1.05);


legend( ...
    ax, ...
    hLowSample, ...
    sprintf('n < %d matched events (not classified)',MIN_EVENTS_FOR_CLASSIFICATION), ...
    'Location','northwest', ...
    'Box','off', ...
    'FontSize',14);


%% ------------------------------------------------------------------------
% Horizontal ADF colourbar
%% ------------------------------------------------------------------------

cb = colorbar( ...
    ax, ...
    'southoutside');


cb.Position = ...
    [0.16 0.105 0.68 0.032];


cb.FontSize = ...
    cbarTextSize;


cb.LineWidth = 0.8;

cb.Color = 'k';


cb.Ticks = ...
    [0 0.25 0.50 0.75 1.00];


cb.TickLabels = ...
    {'0','0.25','0.50','0.75','1'};


cb.Label.String = ...
    'ADF';


cb.Label.FontSize = ...
    cbarTitleSize;


cb.Label.FontWeight = ...
    'bold';


%% ------------------------------------------------------------------------
% Save map
%% ------------------------------------------------------------------------

exportgraphics( ...
    fig, ...
    OUT_MAP_PNG, ...
    'Resolution',600);


exportgraphics( ...
    fig, ...
    OUT_MAP_TIF, ...
    'Resolution',600);


%% ========================================================================
% 20. SEPARATE DONUT FIGURE
%
% Only classified stations (n >= MIN_EVENTS_FOR_CLASSIFICATION) count
% toward the donut percentages.
%% ========================================================================

SpatialClassified = Spatial( ...
    ~Spatial.Low_sample, :);


count_AMC = sum( ...
    SpatialClassified.ADF >= ADF_THRESHOLD);


count_TR = sum( ...
    SpatialClassified.ADF < ADF_THRESHOLD);


counts = [ ...
    count_AMC, ...
    count_TR];


nTotal = sum(counts);


pct = round( ...
    100*counts/nTotal);


plotCounts = counts;

plotCounts(plotCounts==0) = eps;


donutLabels = { ...
    sprintf('%d%%',pct(1)), ...
    sprintf('%d%%',pct(2))};


% Same colours as previous Gini figure:
%
% red  = AMC dominant
% blue = TR dominant

donutColors = [ ...
    0.92 0.22 0.18
    0.10 0.40 0.85];


figD = figure( ...
    'Color','w', ...
    'Units','inches', ...
    'Position',[1 1 5.8 5.2]);


axD = axes( ...
    'Parent',figD, ...
    'Position',[0.05 0.08 0.68 0.84]);


hold(axD,'on');


p = pie( ...
    axD, ...
    plotCounts, ...
    donutLabels);


patchHandles = ...
    p(1:2:end);


textHandles = ...
    p(2:2:end);


for k = 1:numel(patchHandles)

    set( ...
        patchHandles(k), ...
        'FaceColor',donutColors(k,:), ...
        'EdgeColor','w', ...
        'LineWidth',1.2, ...
        'FaceAlpha',0.97);

end


for k = 1:numel(textHandles)

    set( ...
        textHandles(k), ...
        'FontSize',13, ...
        'FontWeight','bold', ...
        'Color','k');

end


%% ------------------------------------------------------------------------
% Donut hole
%% ------------------------------------------------------------------------

rectangle( ...
    axD, ...
    'Position',[-0.34 -0.34 0.68 0.68], ...
    'Curvature',[1 1], ...
    'FaceColor','w', ...
    'EdgeColor','w');


axis(axD,'equal');

axis(axD,'off');


%% ------------------------------------------------------------------------
% Donut legend
%% ------------------------------------------------------------------------

hAMC = patch( ...
    axD, ...
    NaN,NaN, ...
    donutColors(1,:), ...
    'EdgeColor','none');


hTR = patch( ...
    axD, ...
    NaN,NaN, ...
    donutColors(2,:), ...
    'EdgeColor','none');


legend( ...
    axD, ...
    [hAMC hTR], ...
    { ...
    'AMC-dominant', ...
    'TR-dominant'}, ...
    'Location','eastoutside', ...
    'Box','off', ...
    'FontSize',12);


% No title intentionally


%% ------------------------------------------------------------------------
% Save donut
%% ------------------------------------------------------------------------

exportgraphics( ...
    figD, ...
    OUT_DONUT_PNG, ...
    'Resolution',600);


exportgraphics( ...
    figD, ...
    OUT_DONUT_TIF, ...
    'Resolution',600);


%% ========================================================================
% 21. FINAL MESSAGE
%% ========================================================================

fprintf('\n=============================================================\n');
fprintf(' STEP 2 COMPLETED\n');
fprintf('=============================================================\n');

fprintf( ...
    'Excel : %s\n', ...
    OUT_XLSX);

fprintf( ...
    'Map   : %s\n', ...
    OUT_MAP_PNG);

fprintf( ...
    'Donut : %s\n', ...
    OUT_DONUT_PNG);

fprintf( ...
    'Classified stations in donut : %d (of %d plotted; %d excluded as low-sample)\n', ...
    nTotal, ...
    height(Spatial), ...
    sum(Spatial.Low_sample));

fprintf('=============================================================\n');


%% ========================================================================
% LOCAL FUNCTION -- NORMALIZE IMD/WMO IDs
%% ========================================================================

function out = normalizeID(x)

    if isnumeric(x)

        out = string( ...
            compose('%.0f',x));

    else

        out = strip( ...
            string(x));

        out = regexprep( ...
            out, ...
            '\.0$', ...
            '');

    end

end
