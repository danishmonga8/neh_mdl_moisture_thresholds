%% ========================================================================
% Step2B_API_TR_OptimalLag_1to1_Tiled.m
%
% PROFESSIONAL 21-SITE 1:1 TILED PLOT
%
% For each station:
%   X = normalized API at independently selected N*
%   Y = normalized triggering rainfall (TR)
%
% N* was independently selected from:
%       max Kendall tau [API(N), S_eff(t-1)]
%
% Below 1:1 line : API > TR
% Above 1:1 line : TR > API
%
% K = 0.90
%
% OUTPUTS
%   Step2B_API_TR_OptimalLag_Summary.xlsx
%   Step2B_API_TR_OptimalLag_1to1_Tiled.png
%   Step2B_API_TR_OptimalLag_1to1_Tiled.tiff
%
% ========================================================================

clc;
clear;
close all;


%% ========================================================================
% 1. PATHS
%% ========================================================================

ROOT_A = ...
    fullfile(neh_root());

ROOT_B = ...
    fullfile(neh_root(),'2_new_stations_neh');


STEP1_FILE = fullfile( ...
    ROOT_A, ...
    'revision_round1', ...
    'step1_lag_selection', ...
    'Step1_LagSelection_Summary.xlsx');


TRIGGER_DIR = fullfile( ...
    ROOT_A, ...
    '7_trigging_events');


API_ROOT_A = fullfile( ...
    ROOT_A, ...
    '6_crozier_outputs');


API_ROOT_B = fullfile( ...
    ROOT_B, ...
    '6_crozier_outputs');


OUT_DIR = fullfile( ...
    ROOT_A, ...
    'revision_round1', ...
    'step2b_optimal_lag_1to1');


if ~exist(OUT_DIR,'dir')
    mkdir(OUT_DIR);
end


%% ========================================================================
% 2. CONFIGURATION
%% ========================================================================

KDECAY = 0.90;

YR_START = 2007;
YR_END   = 2019;

EQ_TOL = 1e-12;


%% ========================================================================
% 3. READ INDEPENDENTLY SELECTED N*
%% ========================================================================

Lag = readtable( ...
    STEP1_FILE, ...
    'Sheet','Nstar_summary', ...
    'VariableNamingRule','preserve');


Lag.Station  = strip(string(Lag.Station));
Lag.IMD_ID   = normalizeID(Lag.IMD_ID);
Lag.N_star_d = double(Lag.N_star_d);


Lag = Lag(isfinite(Lag.N_star_d),:);


% -------------------------------------------------------------------------
% INTENTIONAL:
% Keep sites ordered by independently selected N*
% -------------------------------------------------------------------------

Lag = sortrows( ...
    Lag, ...
    {'N_star_d','Station'}, ...
    {'ascend','ascend'});


nStations = height(Lag);


fprintf('\n=============================================================\n');
fprintf(' NORMALIZED API vs TR AT INDEPENDENTLY SELECTED N*\n');
fprintf(' K = %.2f | Period = %d-%d\n',KDECAY,YR_START,YR_END);
fprintf(' Stations = %d\n',nStations);
fprintf('=============================================================\n\n');


%% ========================================================================
% 4. PREALLOCATE OUTPUTS
%% ========================================================================

Station     = strings(nStations,1);
IMD_ID      = strings(nStations,1);
N_star_days = nan(nStations,1);

N_events = nan(nStations,1);

API_GT_TR_count = nan(nStations,1);
TR_GT_API_count = nan(nStations,1);
Equal_count     = nan(nStations,1);

API_GT_TR_fraction = nan(nStations,1);
TR_GT_API_fraction = nan(nStations,1);
Equal_fraction     = nan(nStations,1);

Tau_API_TR = nan(nStations,1);
P_API_TR   = nan(nStations,1);

API_source = strings(nStations,1);
Status     = strings(nStations,1);


% Store normalized values for plotting
API_norm_store = cell(nStations,1);
TR_norm_store  = cell(nStations,1);


% Event-level audit table
EventTable = table();


%% ========================================================================
% 5. MAIN LOOP
%% ========================================================================

for i = 1:nStations

    station = Lag.Station(i);
    id      = Lag.IMD_ID(i);
    Nstar   = Lag.N_star_d(i);

    Station(i)     = station;
    IMD_ID(i)      = id;
    N_star_days(i) = Nstar;


    fprintf( ...
        '%-18s | %-12s | N*=%2d d ... ', ...
        station,id,Nstar);


    %% --------------------------------------------------------------------
    % 5A. Triggering rainfall
    %% --------------------------------------------------------------------

    triggerFile = fullfile( ...
        TRIGGER_DIR, ...
        id + "_trigging.txt");


    if ~isfile(triggerFile)

        Status(i) = "Trigger file missing";
        fprintf('TRIGGER FILE MISSING\n');
        continue

    end


    TRdata = readmatrix( ...
        triggerFile, ...
        'FileType','text');


    if isempty(TRdata) || size(TRdata,2) < 4

        Status(i) = "Invalid trigger file";
        fprintf('INVALID TRIGGER FILE\n');
        continue

    end


    eventDate = datetime( ...
        TRdata(:,1), ...
        TRdata(:,2), ...
        TRdata(:,3));


    TR = TRdata(:,4);


    %% --------------------------------------------------------------------
    % Analysis period
    %% --------------------------------------------------------------------

    keep = ...
        year(eventDate) >= YR_START & ...
        year(eventDate) <= YR_END;


    eventDate = eventDate(keep);
    TR        = TR(keep);


    if isempty(eventDate)

        Status(i) = "No events in period";
        fprintf('NO EVENTS\n');
        continue

    end


    %% --------------------------------------------------------------------
    % 5B. API corresponding ONLY to selected N*
    %% --------------------------------------------------------------------

    apiFilename = sprintf( ...
        '%s_%d_crozier_5.txt', ...
        id,Nstar);


    apiFileA = fullfile( ...
        API_ROOT_A, ...
        sprintf('%d_day',Nstar), ...
        apiFilename);


    apiFileB = fullfile( ...
        API_ROOT_B, ...
        sprintf('%d_day',Nstar), ...
        apiFilename);


    if isfile(apiFileA)

        apiFile = apiFileA;
        API_source(i) = "ROOT_A";

    elseif isfile(apiFileB)

        apiFile = apiFileB;
        API_source(i) = "ROOT_B";

    else

        Status(i) = "API file missing";
        fprintf('API FILE MISSING\n');
        continue

    end


    APIdata = readmatrix( ...
        apiFile, ...
        'FileType','text');


    if isempty(APIdata) || size(APIdata,2) < 4

        Status(i) = "Invalid API file";
        fprintf('INVALID API FILE\n');
        continue

    end


    APIdate = datetime( ...
        APIdata(:,1), ...
        APIdata(:,2), ...
        APIdata(:,3));


    API = APIdata(:,4);


    %% --------------------------------------------------------------------
    % 5C. Match API with every triggering event
    %
    % ismember is deliberately used instead of intersect()
    % so repeated landslide-event dates are retained.
    %% --------------------------------------------------------------------

    [matched,locAPI] = ismember( ...
        eventDate, ...
        APIdate);


    API_match = nan(size(TR));


    API_match(matched) = ...
        API(locAPI(matched));


    valid = ...
        matched & ...
        isfinite(API_match) & ...
        isfinite(TR);


    API_match   = API_match(valid);
    TR_match    = TR(valid);
    matchedDate = eventDate(valid);


    n = numel(API_match);


    if n < 3

        Status(i) = "Too few matched events";
        fprintf('TOO FEW EVENTS\n');
        continue

    end


    %% --------------------------------------------------------------------
    % 5D. Empirical normalization
    %% --------------------------------------------------------------------

    API_norm = tiedrank(API_match) ./ (n + 1);

    TR_norm = tiedrank(TR_match) ./ (n + 1);


    %% --------------------------------------------------------------------
    % 5E. Position relative to 1:1 line
    %% --------------------------------------------------------------------

    d = TR_norm - API_norm;


    % Below line => API > TR
    API_GT_TR = d < -EQ_TOL;

    % Above line => TR > API
    TR_GT_API = d > EQ_TOL;

    Equal = abs(d) <= EQ_TOL;


    N_events(i) = n;


    API_GT_TR_count(i) = sum(API_GT_TR);
    TR_GT_API_count(i) = sum(TR_GT_API);
    Equal_count(i)     = sum(Equal);


    API_GT_TR_fraction(i) = ...
        API_GT_TR_count(i) / n;


    TR_GT_API_fraction(i) = ...
        TR_GT_API_count(i) / n;


    Equal_fraction(i) = ...
        Equal_count(i) / n;


    %% --------------------------------------------------------------------
    % 5F. Kendall tau between API and TR
    %% --------------------------------------------------------------------

    [tauVal,pVal] = corr( ...
        API_norm, ...
        TR_norm, ...
        'Type','Kendall', ...
        'Rows','complete');


    Tau_API_TR(i) = tauVal;
    P_API_TR(i)   = pVal;


    API_norm_store{i} = API_norm;
    TR_norm_store{i}  = TR_norm;


    Status(i) = "OK";


    fprintf( ...
        'n=%d | API>TR=%.2f | TR>API=%.2f | tau=%+.2f\n', ...
        n, ...
        API_GT_TR_fraction(i), ...
        TR_GT_API_fraction(i), ...
        tauVal);


    %% --------------------------------------------------------------------
    % Event-level table
    %% --------------------------------------------------------------------

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
        'Equal_1to1'});


    EventTable = [EventTable; TEvent]; %#ok<AGROW>

end


%% ========================================================================
% 6. SUMMARY TABLE
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
    'Status'});


%% ========================================================================
% 7. WRITE EXCEL OUTPUT
%% ========================================================================

outExcel = fullfile( ...
    OUT_DIR, ...
    'Step2B_API_TR_OptimalLag_Summary.xlsx');


if isfile(outExcel)
    delete(outExcel);
end


writetable( ...
    Summary, ...
    outExcel, ...
    'Sheet','Station_summary');


writetable( ...
    EventTable, ...
    outExcel, ...
    'Sheet','Event_level');


fprintf('\nWritten: %s\n',outExcel);


%% ========================================================================
% 8. ITANAGAR CHECK
%% ========================================================================

idxItanagar = contains( ...
    lower(Summary.Station), ...
    'itanagar');


if any(idxItanagar)

    fprintf('\n=============================================================\n');
    fprintf(' ITANAGAR API-TR CHECK\n');
    fprintf('=============================================================\n');

    fprintf( ...
        'N*                   = %.0f d\n', ...
        Summary.N_star_days(idxItanagar));

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
% PROFESSIONAL TILED FIGURE -- REVISED
%
% Changes:
%   - 3 x 7 tiled layout
%   - No Kendall tau displayed
%   - API > TR and TR > API reported as percentages
%   - Larger bold annotation text
%   - Larger panel titles
% ========================================================================

validSites = find(Status == "OK");
nValid = numel(validSites);

if nValid <= 21
    nRows = 3;
    nCols = 7;
else
    nCols = 7;
    nRows = ceil(nValid/nCols);
end

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


%% ------------------------- STYLE ----------------------------------------

pointFace = [0.68 0.82 0.95];
pointEdge = [0.08 0.30 0.55];

oneLineColor = [0.30 0.30 0.30];

markerSize = 38;

tickFont  = 11.5;
titleFont = 13.0;
infoFont  = 11.5;

axisLabelFont = 17;


%% ========================================================================
% DRAW TILES
%% ========================================================================

for q = 1:nValid

    i = validSites(q);

    ax = nexttile(tl,q);
    hold(ax,'on');

    x = API_norm_store{i};
    y = TR_norm_store{i};


    %% ------------------------ SCATTER -----------------------------------

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


    %% ------------------------- 1:1 LINE ---------------------------------

    plot( ...
        ax, ...
        [0 1], ...
        [0 1], ...
        '--', ...
        'Color',oneLineColor, ...
        'LineWidth',1.25);


    %% ------------------------- AXES -------------------------------------

    xlim(ax,[0 1]);
    ylim(ax,[0 1]);

    xticks(ax,[0 0.5 1]);
    yticks(ax,[0 0.5 1]);

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


    %% ------------------------- TITLE ------------------------------------

    titleText = sprintf( ...
        '%s  (N^* = %d d)', ...
        Station(i), ...
        N_star_days(i));

    title( ...
        ax, ...
        titleText, ...
        'FontSize',titleFont, ...
        'FontWeight','bold', ...
        'Color','k', ...
        'Interpreter','tex');


    %% ---------------------- PERCENTAGES ---------------------------------

    pct_API_GT_TR = 100 * API_GT_TR_fraction(i);

    pct_TR_GT_API = 100 * TR_GT_API_fraction(i);


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


    %% -------------------- AXIS LABEL CLEANUP ----------------------------

    rowNum = ceil(q/nCols);

    colNum = mod(q-1,nCols) + 1;


    % Y tick labels only in first column
    if colNum ~= 1
        ax.YTickLabel = [];
    end


    % X tick labels only in bottom row
    if rowNum ~= nRows
        ax.XTickLabel = [];
    end

end


%% ========================================================================
% SHARED AXIS LABELS
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




