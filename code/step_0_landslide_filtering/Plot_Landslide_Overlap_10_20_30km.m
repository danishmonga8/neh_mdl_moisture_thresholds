%% ========================================================================
% Plot_Landslide_Overlap_10_20_30km.m
%
% PURPOSE
% -------------------------------------------------------------------------
% Publication-quality comparison of station-wise landslide overlap for:
%
%       (a) 10 km
%       (b) 20 km
%       (c) 30 km
%
% Each stacked horizontal bar contains:
%
%   Blue = landslides unique to that station buffer
%   Red  = landslides also falling within >=1 other station buffer
%
% IMPORTANT
% -------------------------------------------------------------------------
% Catalogue-level duplicates must already have been removed.
%
% Cross-station overlap is intentionally retained.
%
% SAME station order is used in ALL THREE panels.
% Order is based on total landslide count at 20 km.
%
% Only the LEFT panel shows station labels.
% One common X-axis label and one common legend are used.
%
% ========================================================================

clc;
clear;
close all;


%% ========================================================================
% 1. ROOT DIRECTORY
%% ========================================================================

ROOT = ...
    fullfile(neh_root(),'step_0_landslide_filtering');


OUT_DIR = fullfile( ...
    ROOT, ...
    'radius_overlap_figures');


if ~exist(OUT_DIR,'dir')
    mkdir(OUT_DIR);
end


%% ========================================================================
% 2. INPUT FILES
%
% These three files should be generated using the SAME overlap-retaining
% analysis, changing only the radius to 10, 20 and 30 km.
%% ========================================================================

FILE10 = fullfile( ...
    ROOT, ...
    'Station_Landslide_Counts_10km_ALLOW_OVERLAP.xlsx');


FILE20 = fullfile( ...
    ROOT, ...
    'Station_Landslide_Counts_20km_ALLOW_OVERLAP.xlsx');


FILE30 = fullfile( ...
    ROOT, ...
    'Station_Landslide_Counts_30km_ALLOW_OVERLAP.xlsx');


%% ========================================================================
% 3. CHECK INPUT FILES
%% ========================================================================

if ~isfile(FILE10)
    error('10-km count file not found:\n%s',FILE10);
end


if ~isfile(FILE20)
    error('20-km count file not found:\n%s',FILE20);
end


if ~isfile(FILE30)
    error('30-km count file not found:\n%s',FILE30);
end


%% ========================================================================
% 4. READ STATION COUNT TABLES
%% ========================================================================

T10 = readtable( ...
    FILE10, ...
    'Sheet','Station_counts', ...
    'VariableNamingRule','preserve');


T20 = readtable( ...
    FILE20, ...
    'Sheet','Station_counts', ...
    'VariableNamingRule','preserve');


T30 = readtable( ...
    FILE30, ...
    'Sheet','Station_counts', ...
    'VariableNamingRule','preserve');


%% ========================================================================
% 5. EXTRACT VARIABLES ROBUSTLY
%% ========================================================================

D10 = extractRadiusCounts(T10,10);

D20 = extractRadiusCounts(T20,20);

D30 = extractRadiusCounts(T30,30);


%% ========================================================================
% 6. CHECK THAT SAME 21 STATIONS EXIST
%% ========================================================================

Station20 = string(D20.Station);


if height(D10) ~= height(D20) || ...
        height(D30) ~= height(D20)

    error('Station counts differ among the three radius datasets.');

end


%% ------------------------------------------------------------------------
% Reorder 10-km and 30-km tables to exactly match 20-km station names
%% ------------------------------------------------------------------------

[tf10,loc10] = ismember( ...
    Station20, ...
    string(D10.Station));


[tf30,loc30] = ismember( ...
    Station20, ...
    string(D30.Station));


if ~all(tf10) || ~all(tf30)

    error( ...
        'Station names do not match among 10-, 20-, and 30-km files.');

end


D10 = D10(loc10,:);

D30 = D30(loc30,:);


%% ========================================================================
% 7. COMMON STATION ORDER
%
% Sort ONLY ONCE using the 20-km total event count.
%% ========================================================================

[~,ord] = sort( ...
    D20.Total, ...
    'descend');


StationSort = ...
    string(D20.Station(ord));


%% ------------------------------------------------------------------------
% 10 km
%% ------------------------------------------------------------------------

U10 = D10.Unique(ord);

S10 = D10.Shared(ord);

N10 = D10.Total(ord);


%% ------------------------------------------------------------------------
% 20 km
%% ------------------------------------------------------------------------

U20 = D20.Unique(ord);

S20 = D20.Shared(ord);

N20 = D20.Total(ord);


%% ------------------------------------------------------------------------
% 30 km
%% ------------------------------------------------------------------------

U30 = D30.Unique(ord);

S30 = D30.Shared(ord);

N30 = D30.Total(ord);


nStations = ...
    numel(StationSort);


%% ========================================================================
% 8. QUALITY CONTROL
%% ========================================================================

if any(U10 + S10 ~= N10)

    error('10-km QC failed: Unique + Shared ~= Total.');

end


if any(U20 + S20 ~= N20)

    error('20-km QC failed: Unique + Shared ~= Total.');

end


if any(U30 + S30 ~= N30)

    error('30-km QC failed: Unique + Shared ~= Total.');

end


%% ========================================================================
% 9. CONSOLE SUMMARY
%% ========================================================================

fprintf('\n');
fprintf('=============================================================\n');
fprintf(' LANDSLIDE BUFFER-OVERLAP SUMMARY\n');
fprintf('=============================================================\n');


fprintf( ...
    '%-10s %-15s %-15s %-15s\n', ...
    'Radius', ...
    'Assignments', ...
    'Shared', ...
    'Sites shared');


fprintf( ...
    '%-10s %-15d %-15d %d/%d\n', ...
    '10 km', ...
    sum(N10), ...
    sum(S10), ...
    sum(S10 > 0), ...
    nStations);


fprintf( ...
    '%-10s %-15d %-15d %d/%d\n', ...
    '20 km', ...
    sum(N20), ...
    sum(S20), ...
    sum(S20 > 0), ...
    nStations);


fprintf( ...
    '%-10s %-15d %-15d %d/%d\n', ...
    '30 km', ...
    sum(N30), ...
    sum(S30), ...
    sum(S30 > 0), ...
    nStations);


fprintf('=============================================================\n\n');


%% ========================================================================
% 10. COMMON AXIS SCALE
%
% All panels use identical X limits for direct comparison.
%% ========================================================================

maxTotal = max( ...
    [N10; N20; N30]);


xMax = ceil( ...
    maxTotal * 1.12);


%% ========================================================================
% 11. PROFESSIONAL 3-PANEL FIGURE
%% ========================================================================

fig = figure( ...
    'Color','w', ...
    'Units','centimeters', ...
    'Position',[1 1 42 22], ...
    'Renderer','painters');


tl = tiledlayout( ...
    fig, ...
    1,3, ...
    'TileSpacing','compact', ...
    'Padding','compact');


%% ========================================================================
% PROFESSIONAL COLOURS
%% ========================================================================

uniqueColor = [ ...
    0.70 0.81 0.90];


sharedColor = [ ...
    0.80 0.31 0.27];


edgeColor = [ ...
    0.15 0.15 0.15];


%% ========================================================================
% 12. PANEL A -- 10 km
%% ========================================================================

ax1 = nexttile(tl,1);


plotRadiusPanel( ...
    ax1, ...
    U10, ...
    S10, ...
    N10, ...
    StationSort, ...
    uniqueColor, ...
    sharedColor, ...
    edgeColor, ...
    xMax, ...
    true);


title( ...
    ax1, ...
    '(a) 10 km', ...
    'FontSize',15, ...
    'FontWeight','bold', ...
    'Color','k');


%% ========================================================================
% 13. PANEL B -- 20 km
%% ========================================================================

ax2 = nexttile(tl,2);


plotRadiusPanel( ...
    ax2, ...
    U20, ...
    S20, ...
    N20, ...
    StationSort, ...
    uniqueColor, ...
    sharedColor, ...
    edgeColor, ...
    xMax, ...
    false);


title( ...
    ax2, ...
    '(b) 20 km', ...
    'FontSize',15, ...
    'FontWeight','bold', ...
    'Color','k');


%% ========================================================================
% 14. PANEL C -- 30 km
%% ========================================================================

ax3 = nexttile(tl,3);


plotRadiusPanel( ...
    ax3, ...
    U30, ...
    S30, ...
    N30, ...
    StationSort, ...
    uniqueColor, ...
    sharedColor, ...
    edgeColor, ...
    xMax, ...
    false);


title( ...
    ax3, ...
    '(c) 30 km', ...
    'FontSize',15, ...
    'FontWeight','bold', ...
    'Color','k');


%% ========================================================================
% 15. COMMON X LABEL
%% ========================================================================

xlabel( ...
    tl, ...
    'Number of landslide events', ...
    'FontSize',16, ...
    'FontWeight','bold', ...
    'Color','k');


%% ========================================================================
% 16. COMMON LEGEND
%
% Make invisible dummy graphics so only ONE legend is needed.
%% ========================================================================

hold(ax2,'on');


hUnique = patch( ...
    ax2, ...
    NaN,NaN, ...
    uniqueColor, ...
    'EdgeColor',edgeColor);


hShared = patch( ...
    ax2, ...
    NaN,NaN, ...
    sharedColor, ...
    'EdgeColor',edgeColor);


lgd = legend( ...
    ax2, ...
    [hUnique hShared], ...
    { ...
    'Unique to station buffer', ...
    'Shared with other station buffer(s)'}, ...
    'Orientation','horizontal', ...
    'Location','southoutside');


lgd.FontSize = 12;

lgd.FontWeight = 'bold';

lgd.Box = 'off';


%% ------------------------------------------------------------------------
% Move legend further below middle panel
%% ------------------------------------------------------------------------

lgd.Layout.Tile = 'south';


%% ========================================================================
% 17. KEEP ALL THREE AXES ALIGNED
%% ========================================================================

linkaxes( ...
    [ax1 ax2 ax3], ...
    'xy');


ylim( ...
    ax1, ...
    [0.3 nStations+0.7]);


