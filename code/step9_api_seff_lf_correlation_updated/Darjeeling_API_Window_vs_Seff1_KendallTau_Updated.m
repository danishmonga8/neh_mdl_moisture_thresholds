%% ========================================================================
% STEP 9
% DARJEELING (42295)
%
% API WINDOW-SENSITIVITY ANALYSIS
%
% Compare:
%
%   1) API(N, K=0.90) vs S_eff[1]
%
%   2) API(N, K=0.90) vs S_eff[0]
%
%
% DEFINITIONS
% -------------------------------------------------------------------------
%
% S_eff[1] =
%       root-zone effective saturation one day before landslide
%
% S_eff[0] =
%       root-zone effective saturation on landslide/event day
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
%
% API:
%       K = 0.90
%
% Candidate N:
%       [3 5 7 11 15 21 25 30] days
%
% Correlation:
%       Kendall's tau
%
%
% IMPORTANT
% -------------------------------------------------------------------------
%
% N* used in Step 7 was selected from:
%
%       API(N) vs S_eff[1]
%
% Therefore:
%
%       maximum tau for S_eff[1]
%
% is the actual lag-selection criterion.
%
% S_eff[0] is plotted only as a comparison/sensitivity curve.
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
% 2. OUTPUT FOLDER
%% ========================================================================

outDir = fullfile( ...
    revDir, ...
    'step9_api_seff_lf_correlation_updated');


if ~exist(outDir,'dir')

    mkdir(outDir);

end


%% ========================================================================
% 3. STATION
%% ========================================================================

stnID = ...
    42295;


stnStr = ...
    sprintf('%05d',stnID);


stationName = ...
    "Darjeeling";


%% ========================================================================
% 4. STUDY PERIOD
%% ========================================================================

yr0 = ...
    2007;


yr1 = ...
    2021;


%% ========================================================================
% 5. API SETTINGS
%% ========================================================================

Kvalue = ...
    0.90;


Ktag = ...
    '0p90';


%% ------------------------------------------------------------------------
% EXACT candidate windows from revised Step 7
%% ------------------------------------------------------------------------

winList = ...
    [3 5 7 11 15 21 25 30];


%% ========================================================================
% 6. STEP-7 OPTIMAL N*
%% ========================================================================

lagXlsx = fullfile( ...
    revDir, ...
    'step7_lag_selection_updated', ...
    'Step7_Optimal_Lag_Summary.xlsx');


%% ========================================================================
% 7. UPDATED station-radius LANDSLIDE METADATA
%% ========================================================================

landslideMeta = fullfile( ...
    revDir, ...
    'step_0_landslide_filtering', ...
    'Station_Landslide_Metadata_radius_ALLOW_OVERLAP.xlsx');


%% ========================================================================
% 8. UPDATED DAILY ROOT-ZONE S_eff
%
% Expected file:
%
%       42295_SMrz_Seff.txt
%
% Expected:
%
%       column 1 = year
%       column 2 = month
%       column 3 = day
%       column 5 = S_eff
%
%% ========================================================================

satDir = fullfile( ...
    baseDir, ...
    '10_soil_moisture_extraction', ...
    'effective_saturation_time_series_all_stations', ...
    'effective_saturation_time_series_all_stations');


satFile = fullfile( ...
    satDir, ...
    sprintf('%s_SMrz_Seff.txt',stnStr));


%% ========================================================================
% 9. UPDATED API / CROZIER ROOT
%% ========================================================================

criRoot1 = fullfile( ...
    revDir, ...
    'step5_crozier_outputs');


criRoot2 = fullfile( ...
    revDir, ...
    'step_5_crozier_outputs');


if exist(criRoot1,'dir')


    criRoot = ...
        criRoot1;


elseif exist(criRoot2,'dir')


    criRoot = ...
        criRoot2;


else


    error( ...
        ['Updated API folder not found.' newline ...
         newline ...
         'Checked:' newline ...
         '%s' newline ...
         newline ...
         '%s'], ...
        criRoot1, ...
        criRoot2);


end


%% ========================================================================
% 10. CHECK INPUT FILES
%% ========================================================================

if ~isfile(lagXlsx)


    error( ...
        'Step-7 N* workbook missing:\n%s', ...
        lagXlsx);


end


if ~isfile(landslideMeta)


    error( ...
        'Updated landslide metadata missing:\n%s', ...
        landslideMeta);


end


if ~isfile(satFile)


    error( ...
        'Updated S_eff file missing:\n%s', ...
        satFile);


end


%% ========================================================================
% 11. DISPLAY SETTINGS
%% ========================================================================

fprintf('\n');
fprintf('=============================================================\n');
fprintf(' DARJEELING API WINDOW vs S_eff[1] AND S_eff[0]\n');
fprintf('=============================================================\n');


fprintf( ...
    'Station       : %s (%d)\n', ...
    stationName, ...
    stnID);


fprintf( ...
    'Study period  : %d-%d\n', ...
    yr0, ...
    yr1);


fprintf( ...
    'API K         : %.2f\n', ...
    Kvalue);


fprintf( ...
    'Statistic     : Kendall''s tau\n');


fprintf( ...
    'Windows       : ');


fprintf( ...
    '%d ', ...
    winList);


fprintf('\n');


fprintf('\nOutput folder:\n%s\n', ...
    outDir);


fprintf('=============================================================\n\n');


%% ========================================================================
% 12. READ STEP-7 N*
%% ========================================================================

Lag = readtable( ...
    lagXlsx, ...
    'Sheet','Optimal_N', ...
    'VariableNamingRule','preserve');


lagVars = ...
    string(Lag.Properties.VariableNames);


if ~ismember("IMD_ID",lagVars) || ...
        ~ismember("Optimal_N_days",lagVars)


    error( ...
        ['Step7 workbook must contain:' newline ...
         'IMD_ID and Optimal_N_days']);


end


%% ------------------------------------------------------------------------
% Standardize IMD IDs
%% ------------------------------------------------------------------------

if isnumeric(Lag.IMD_ID)


    lagIDs = ...
        string( ...
        compose( ...
        '%.0f', ...
        Lag.IMD_ID));


else


    lagIDs = ...
        strip( ...
        string(Lag.IMD_ID));


    lagIDs = ...
        regexprep( ...
        lagIDs, ...
        '\.0$', ...
        '');


end


idxLag = ...
    lagIDs == string(stnID);


if any(idxLag)


    Nstar_Step7 = ...
        double( ...
        Lag.Optimal_N_days( ...
        find(idxLag,1,'first')));


else


    Nstar_Step7 = ...
        NaN;


    warning( ...
        'Darjeeling was not found in Step-7 N* workbook.');


end


fprintf( ...
    'Stored Step-7 N* = %.0f days\n\n', ...
    Nstar_Step7);


%% ========================================================================
% 13. READ UPDATED LANDSLIDE METADATA
%% ========================================================================

Pairs = readtable( ...
    landslideMeta, ...
    'Sheet','Station_event_pairs', ...
    'VariableNamingRule','preserve');


pairVars = ...
    string(Pairs.Properties.VariableNames);


%% ========================================================================
% 14. IDENTIFY DARJEELING RECORDS
%
% Prefer IMD_ID where available.
%% ========================================================================

stationMask = ...
    false(height(Pairs),1);


if ismember("IMD_ID",pairVars)


    if isnumeric(Pairs.IMD_ID)


        pairIDs = ...
            string( ...
            compose( ...
            '%.0f', ...
            Pairs.IMD_ID));


    else


        pairIDs = ...
            strip( ...
            string(Pairs.IMD_ID));


        pairIDs = ...
            regexprep( ...
            pairIDs, ...
            '\.0$', ...
            '');


    end


    stationMask = ...
        pairIDs == string(stnID);


end


%% ------------------------------------------------------------------------
% Fallback to station name
%% ------------------------------------------------------------------------

if ~any(stationMask) && ...
        ismember("Station",pairVars)


    stationMask = ...
        strcmpi( ...
        strip(string(Pairs.Station)), ...
        stationName);


end


if ~any(stationMask)


    error( ...
        'No revised Darjeeling landslide records found.');


end


PairsD = ...
    Pairs(stationMask,:);


%% ========================================================================
% 15. EXTRACT LANDSLIDE DATES
%% ========================================================================

if ismember("EventDate",pairVars)


    LSdate = ...
        PairsD.EventDate;


    if ~isdatetime(LSdate)


        LSdate = ...
            datetime( ...
            string(LSdate));


    end


elseif all( ...
        ismember( ...
        ["Year","Month","Day"], ...
        pairVars))


    LSdate = datetime( ...
        PairsD.Year, ...
        PairsD.Month, ...
        PairsD.Day);


else


    error( ...
        ['Could not identify landslide date columns.' newline ...
         'Need EventDate OR Year/Month/Day.']);


end


%% ------------------------------------------------------------------------
% Remove invalid dates
%% ------------------------------------------------------------------------

LSdate = ...
    LSdate(~isnat(LSdate));


%% ------------------------------------------------------------------------
% Study period
%% ------------------------------------------------------------------------

keepLS = ...
    year(LSdate) >= yr0 & ...
    year(LSdate) <= yr1;


LSdate = ...
    LSdate(keepLS);


if isempty(LSdate)


    error( ...
        'No Darjeeling landslides found during %d-%d.', ...
        yr0, ...
        yr1);


end


nEvt = ...
    numel(LSdate);


fprintf( ...
    'Landslide-event records = %d\n\n', ...
    nEvt);


%% ========================================================================
% 16. READ DAILY S_eff
%% ========================================================================

S = readmatrix( ...
    satFile, ...
    'FileType','text');


if isempty(S) || ...
        size(S,2) < 5


    error( ...
        'S_eff file must contain at least five columns.');


end


%% ------------------------------------------------------------------------
% Valid rows
%% ------------------------------------------------------------------------

goodS = ...
    isfinite(S(:,1)) & ...
    isfinite(S(:,2)) & ...
    isfinite(S(:,3)) & ...
    isfinite(S(:,5));


S = ...
    S(goodS,:);


if isempty(S)


    error( ...
        'No valid daily S_eff records found.');


end


%% ========================================================================
% 17. DAILY S_eff DATES
%% ========================================================================

SeffDate = datetime( ...
    S(:,1), ...
    S(:,2), ...
    S(:,3));


Seff = ...
    double(S(:,5));


%% ========================================================================
% 18. EXTRACT S_eff[1] AND S_eff[0]
%
% S_eff[1]:
%
%       t - 1 day
%
% S_eff[0]:
%
%       event day t
%
%% ========================================================================

S1_evt = ...
    nan(nEvt,1);


S0_evt = ...
    nan(nEvt,1);


for r = 1:nEvt


    eventDate = ...
        LSdate(r);


    %% --------------------------------------------------------------------
    % S_eff[1]
    %% --------------------------------------------------------------------

    idx1 = ...
        SeffDate == ...
        (eventDate - days(1));


    if any(idx1)


        S1_evt(r) = median( ...
            Seff(idx1), ...
            'omitnan');


    end


    %% --------------------------------------------------------------------
    % S_eff[0]
    %% --------------------------------------------------------------------

    idx0 = ...
        SeffDate == ...
        eventDate;


    if any(idx0)


        S0_evt(r) = median( ...
            Seff(idx0), ...
            'omitnan');


    end


end


fprintf( ...
    'Events with valid S_eff[1] = %d/%d\n', ...
    sum(isfinite(S1_evt)), ...
    nEvt);


fprintf( ...
    'Events with valid S_eff[0] = %d/%d\n\n', ...
    sum(isfinite(S0_evt)), ...
    nEvt);


%% ========================================================================
% 19. STORAGE
%% ========================================================================

nWin = ...
    numel(winList);


TauS1 = ...
    nan(nWin,1);


TauS0 = ...
    nan(nWin,1);


PS1 = ...
    nan(nWin,1);


PS0 = ...
    nan(nWin,1);


NS1 = ...
    nan(nWin,1);


NS0 = ...
    nan(nWin,1);


%% ========================================================================
% 20. LOOP THROUGH API WINDOWS
%% ========================================================================

for iw = 1:nWin


    L = ...
        winList(iw);


    fprintf( ...
        'Window %2d days ... ', ...
        L);


    %% ====================================================================
    % POSSIBLE API FILE LOCATIONS
    %% ====================================================================

    folder1 = fullfile( ...
        criRoot, ...
        ['K_' Ktag], ...
        sprintf('%02d_day',L));


    folder2 = fullfile( ...
        criRoot, ...
        ['K_' Ktag], ...
        sprintf('%d_day',L));


    fileName1 = sprintf( ...
        '%s_%02dd_crozier_K%s.txt', ...
        stnStr, ...
        L, ...
        Ktag);


    fileName2 = sprintf( ...
        '%s_%dd_crozier_K%s.txt', ...
        stnStr, ...
        L, ...
        Ktag);


    candidateFiles = { ...
        fullfile(folder1,fileName1), ...
        fullfile(folder1,fileName2), ...
        fullfile(folder2,fileName1), ...
        fullfile(folder2,fileName2) ...
        };


    criFile = ...
        "";


    for ff = 1:numel(candidateFiles)


        if isfile(candidateFiles{ff})


            criFile = ...
                string(candidateFiles{ff});


            break


        end


    end


    if strlength(criFile) == 0


        fprintf('API FILE MISSING\n');


        continue


    end


    %% ====================================================================
    % READ API
    %% ====================================================================

    C = readmatrix( ...
        criFile, ...
        'FileType','text');


    if isempty(C) || ...
            size(C,2) < 4


        fprintf('INVALID FILE\n');


        continue


    end


    %% --------------------------------------------------------------------
    % Valid rows
    %% --------------------------------------------------------------------

    goodC = ...
        isfinite(C(:,1)) & ...
        isfinite(C(:,2)) & ...
        isfinite(C(:,3)) & ...
        isfinite(C(:,4));


    C = ...
        C(goodC,:);


    if isempty(C)


        fprintf('NO VALID API\n');


        continue


    end


    %% ====================================================================
    % API DATES
    %% ====================================================================

    APIDate = datetime( ...
        C(:,1), ...
        C(:,2), ...
        C(:,3));


    API = ...
        double(C(:,4));


    %% ====================================================================
    % API VALUE FOR EACH LANDSLIDE
    %% ====================================================================

    API_evt = ...
        nan(nEvt,1);


    for r = 1:nEvt


        idxAPI = ...
            APIDate == ...
            LSdate(r);


        if any(idxAPI)


            API_evt(r) = median( ...
                API(idxAPI), ...
                'omitnan');


        end


    end


    %% ====================================================================
    % API vs S_eff[1]
    %% ====================================================================

    mask1 = ...
        isfinite(API_evt) & ...
        isfinite(S1_evt);


    if sum(mask1) >= 3


        [TauS1(iw),PS1(iw)] = corr( ...
            API_evt(mask1), ...
            S1_evt(mask1), ...
            'Type','Kendall', ...
            'Rows','complete');


        NS1(iw) = ...
            sum(mask1);


    end


    %% ====================================================================
    % API vs S_eff[0]
    %% ====================================================================

    mask0 = ...
        isfinite(API_evt) & ...
        isfinite(S0_evt);


    if sum(mask0) >= 3


        [TauS0(iw),PS0(iw)] = corr( ...
            API_evt(mask0), ...
            S0_evt(mask0), ...
            'Type','Kendall', ...
            'Rows','complete');


        NS0(iw) = ...
            sum(mask0);


    end


    fprintf( ...
        'tau1=%+.3f | tau0=%+.3f | N1=%d | N0=%d\n', ...
        TauS1(iw), ...
        TauS0(iw), ...
        NS1(iw), ...
        NS0(iw));


end


%% ========================================================================
% 21. FIND MAXIMUM FOR S_eff[1]
%% ========================================================================

valid1 = ...
    isfinite(TauS1);


if any(valid1)


    windows1 = ...
        winList(valid1);


    tau1 = ...
        TauS1(valid1);


    p1 = ...
        PS1(valid1);


    n1 = ...
        NS1(valid1);


    [maxTau1,idxMax1] = ...
        max(tau1);


    Lmax1 = ...
        windows1(idxMax1);


    Pmax1 = ...
        p1(idxMax1);


    Nmax1 = ...
        n1(idxMax1);


else


    maxTau1 = ...
        NaN;


    Lmax1 = ...
        NaN;


    Pmax1 = ...
        NaN;


    Nmax1 = ...
        NaN;


end


%% ========================================================================
% 22. FIND MAXIMUM FOR S_eff[0]
%% ========================================================================

valid0 = ...
    isfinite(TauS0);


if any(valid0)


    windows0 = ...
        winList(valid0);


    tau0 = ...
        TauS0(valid0);


    p0 = ...
        PS0(valid0);


    n0 = ...
        NS0(valid0);


    [maxTau0,idxMax0] = ...
        max(tau0);


    Lmax0 = ...
        windows0(idxMax0);


    Pmax0 = ...
        p0(idxMax0);


    Nmax0 = ...
        n0(idxMax0);


else


    maxTau0 = ...
        NaN;


    Lmax0 = ...
        NaN;


    Pmax0 = ...
        NaN;


    Nmax0 = ...
        NaN;


end


%% ========================================================================
% 23. DISPLAY MAXIMUM RESULTS
%% ========================================================================

fprintf('\n');
fprintf('=============================================================\n');
fprintf(' DARJEELING WINDOW-SENSITIVITY RESULTS\n');
fprintf('=============================================================\n');


fprintf( ...
    'S_eff[1]: max tau = %.4f at %d days | p=%.4f | n=%d\n', ...
    maxTau1, ...
    Lmax1, ...
    Pmax1, ...
    Nmax1);


fprintf( ...
    'S_eff[0]: max tau = %.4f at %d days | p=%.4f | n=%d\n', ...
    maxTau0, ...
    Lmax0, ...
    Pmax0, ...
    Nmax0);


fprintf( ...
    'Step-7 selected N* = %.0f days\n', ...
    Nstar_Step7);


%% ========================================================================
% 24. CROSS-CHECK STEP-7 N*
%
% ONLY S_eff[1] determines updated N*
%% ========================================================================

if isfinite(Nstar_Step7) && ...
        isfinite(Lmax1)


    if Lmax1 == Nstar_Step7


        fprintf( ...
            'Step-7 cross-check = MATCH\n');


    else


        fprintf( ...
            'Step-7 cross-check = DOES NOT MATCH\n');


        warning( ...
            ['Maximum API vs S_eff[1] tau occurs at %d days, ' ...
             'but Step-7 stores N* = %.0f days.'], ...
            Lmax1, ...
            Nstar_Step7);


    end


end


fprintf('=============================================================\n\n');


%% ========================================================================
% 25. FIGURE SETTINGS
%% ========================================================================

% Blue
colS1 = ...
    [0.15 0.45 0.85];


% Purple
colS0 = ...
    [0.55 0.34 0.69];


% Dark red
colMax1 = ...
    [0.80 0.15 0.12];


% Orange
colMax0 = ...
    [0.95 0.50 0.10];


fontTick = ...
    13;


fontLabel = ...
    16;


fontTitle = ...
    17;


%% ========================================================================
% 26. CREATE PUBLICATION-QUALITY FIGURE
%% ========================================================================

fig = figure( ...
    'Color','w', ...
    'Units','pixels', ...
    'Position',[120 100 1180 740]);


ax = axes(fig);


hold(ax,'on');


box(ax,'on');


grid(ax,'on');


ax.GridAlpha = ...
    0.13;


ax.MinorGridAlpha = ...
    0.06;


%% ========================================================================
% 27. ZERO REFERENCE LINE
%% ========================================================================

yline( ...
    ax, ...
    0, ...
    '-', ...
    'Color',[0.55 0.55 0.55], ...
    'LineWidth',1.0, ...
    'HandleVisibility','off');


%% ========================================================================
% 28. API vs S_eff[1]
%% ========================================================================

h1 = plot( ...
    ax, ...
    winList, ...
    TauS1, ...
    '-o', ...
    'Color',colS1, ...
    'LineWidth',2.3, ...
    'MarkerSize',7.5, ...
    'MarkerFaceColor','w', ...
    'MarkerEdgeColor',colS1);


%% ========================================================================
% 29. API vs S_eff[0]
%% ========================================================================

h2 = plot( ...
    ax, ...
    winList, ...
    TauS0, ...
    '-s', ...
    'Color',colS0, ...
    'LineWidth',2.3, ...
    'MarkerSize',7.5, ...
    'MarkerFaceColor','w', ...
    'MarkerEdgeColor',colS0);


%% ========================================================================
% 30. MARK MAXIMUM S_eff[1]
%% ========================================================================

if isfinite(Lmax1)


    h3 = plot( ...
        ax, ...
        Lmax1, ...
        maxTau1, ...
        'o', ...
        'MarkerFaceColor',colMax1, ...
        'MarkerEdgeColor',colMax1, ...
        'MarkerSize',11, ...
        'LineWidth',1.5);


    xline( ...
        ax, ...
        Lmax1, ...
        '--', ...
        'Color',colS1, ...
        'LineWidth',1.4, ...
        'HandleVisibility','off');


else


    h3 = ...
        gobjects(0);


end


%% ========================================================================
% 31. MARK MAXIMUM S_eff[0]
%% ========================================================================

if isfinite(Lmax0)


    h4 = plot( ...
        ax, ...
        Lmax0, ...
        maxTau0, ...
        's', ...
        'MarkerFaceColor',colMax0, ...
        'MarkerEdgeColor',colMax0, ...
        'MarkerSize',10, ...
        'LineWidth',1.5);


    xline( ...
        ax, ...
        Lmax0, ...
        ':', ...
        'Color',colS0, ...
        'LineWidth',1.5, ...
        'HandleVisibility','off');


else


    h4 = ...
        gobjects(0);


end


%% ========================================================================
% 32. ANNOTATE S_eff[1] MAXIMUM
%% ========================================================================

if isfinite(Lmax1)


    txt1 = sprintf( ...
        ['S_{eff}[1]\n' ...
         'N^* = %d d\n' ...
         '\\tau = %.2f'], ...
        Lmax1, ...
        maxTau1);


    text( ...
        ax, ...
        Lmax1 + 0.8, ...
        maxTau1 + 0.055, ...
        txt1, ...
        'FontName','Arial', ...
        'FontSize',11, ...
        'BackgroundColor','w', ...
        'EdgeColor',[0.78 0.78 0.78], ...
        'Margin',5, ...
        'Interpreter','tex');


end


%% ========================================================================
% 33. ANNOTATE S_eff[0] MAXIMUM
%% ========================================================================

if isfinite(Lmax0)


    txt0 = sprintf( ...
        ['S_{eff}[0]\n' ...
         'N = %d d\n' ...
         '\\tau = %.2f'], ...
        Lmax0, ...
        maxTau0);


    %% --------------------------------------------------------------------
    % Offset annotation slightly to avoid overlap
    %% --------------------------------------------------------------------

    text( ...
        ax, ...
        Lmax0 + 0.8, ...
        maxTau0 - 0.08, ...
        txt0, ...
        'FontName','Arial', ...
        'FontSize',11, ...
        'BackgroundColor','w', ...
        'EdgeColor',[0.78 0.78 0.78], ...
        'Margin',5, ...
        'Interpreter','tex');


end


%% ========================================================================
% 34. AXIS LABELS
%% ========================================================================

xlabel( ...
    ax, ...
    'Antecedent API window, N (days)', ...
    'FontName','Arial', ...
    'FontSize',fontLabel, ...
    'FontWeight','bold');


ylabel( ...
    ax, ...
    'Kendall''s \tau', ...
    'FontName','Arial', ...
    'FontSize',fontLabel, ...
    'FontWeight','bold');


%% ========================================================================
% 35. TITLE
%% ========================================================================

title( ...
    ax, ...
    sprintf( ...
    '%s (IMD %d): API-window sensitivity to root-zone wetness', ...
    stationName, ...
    stnID), ...
    'FontName','Arial', ...
    'FontSize',fontTitle, ...
    'FontWeight','bold');


%% ========================================================================
% 36. AXIS LIMITS
%% ========================================================================

xlim( ...
    ax, ...
    [2 31]);


ylim( ...
    ax, ...
    [-1 1]);


xticks( ...
    ax, ...
    winList);


yticks( ...
    ax, ...
    -1:0.2:1);


%% ========================================================================
% 37. AXIS FORMATTING
%% ========================================================================

set( ...
    ax, ...
    'FontName','Arial', ...
    'FontSize',fontTick, ...
    'LineWidth',1.15, ...
    'TickDir','out', ...
    'TickLength',[0.007 0.007]);


%% ========================================================================
% 38. LEGEND
%% ========================================================================

legendHandles = ...
    [h1 h2];


legendLabels = ...
    { ...
    'API vs S_{eff}[1]', ...
    'API vs S_{eff}[0]' ...
    };


if ~isempty(h3)


    legendHandles = ...
        [legendHandles h3];


    legendLabels = ...
        [ ...
        legendLabels, ...
        {'Maximum \tau: S_{eff}[1]'} ...
        ];


end


if ~isempty(h4)


    legendHandles = ...
        [legendHandles h4];


    legendLabels = ...
        [ ...
        legendLabels, ...
        {'Maximum \tau: S_{eff}[0]'} ...
        ];


end


legend( ...
    ax, ...
    legendHandles, ...
    legendLabels, ...
    'Location','southoutside', ...
    'Orientation','horizontal', ...
    'NumColumns',2, ...
    'Box','on', ...
    'FontName','Arial', ...
    'FontSize',11.5, ...
    'Interpreter','tex');


%% ========================================================================
% 39. FIGURE MARGINS
%% ========================================================================

set( ...
    ax, ...
    'LooseInset', ...
    max( ...
    get(ax,'TightInset'), ...
    [0.04 0.05 0.03 0.04]));


%% ========================================================================
% 40. SAVE FIGURE
%% ========================================================================

outBase = fullfile( ...
    outDir, ...
    sprintf( ...
    'Step9_Darjeeling_%d_API_vs_Seff1_Seff0_WindowSensitivity', ...
    stnID));


%% ------------------------------------------------------------------------
% TIFF
%% ------------------------------------------------------------------------

print( ...
    fig, ...
    [outBase '.tif'], ...
    '-dtiff', ...
    '-r600');


%% ------------------------------------------------------------------------
% PNG
%% ------------------------------------------------------------------------

print( ...
    fig, ...
    [outBase '.png'], ...
    '-dpng', ...
    '-r600');


%% ------------------------------------------------------------------------
% MATLAB FIG
%% ------------------------------------------------------------------------

savefig( ...
    fig, ...
    [outBase '.fig']);


%% ========================================================================
% 41. RESULTS TABLE
%% ========================================================================

Is_Nstar_S1 = ...
    winList(:) == Lmax1;


Is_Max_Seff0 = ...
    winList(:) == Lmax0;


ResultTable = table( ...
    winList(:), ...
    TauS1(:), ...
    PS1(:), ...
    NS1(:), ...
    TauS0(:), ...
    PS0(:), ...
    NS0(:), ...
    Is_Nstar_S1, ...
    Is_Max_Seff0, ...
    'VariableNames',{ ...
    'Window_days', ...
    'Tau_API_Seff1', ...
    'p_API_Seff1', ...
    'N_API_Seff1', ...
    'Tau_API_Seff0', ...
    'p_API_Seff0', ...
    'N_API_Seff0', ...
    'Is_Nstar_Seff1', ...
    'Is_Max_Seff0'});


%% ========================================================================
% 42. SUMMARY TABLE
%% ========================================================================

SummaryTable = table( ...
    stationName, ...
    stnID, ...
    yr0, ...
    yr1, ...
    Kvalue, ...
    Lmax1, ...
    maxTau1, ...
    Pmax1, ...
    Nmax1, ...
    Lmax0, ...
    maxTau0, ...
    Pmax0, ...
    Nmax0, ...
    Nstar_Step7, ...
    'VariableNames',{ ...
    'Station', ...
    'IMD_ID', ...
    'Study_Start', ...
    'Study_End', ...
    'API_K', ...
    'Nstar_Seff1_days', ...
    'MaxTau_API_Seff1', ...
    'p_at_Nstar_Seff1', ...
    'Npairs_at_Nstar_Seff1', ...
    'MaxWindow_Seff0_days', ...
    'MaxTau_API_Seff0', ...
    'p_at_Max_Seff0', ...
    'Npairs_at_Max_Seff0', ...
    'Step7_Nstar_days'});


%% ========================================================================
% 43. DISPLAY TABLE
%% ========================================================================

disp(' ');


disp( ...
    '=============================================================');


disp( ...
    'DARJEELING: API WINDOW vs S_eff[1] AND S_eff[0]');


disp( ...
    '=============================================================');


disp( ...
    ResultTable);


%% ========================================================================
% 44. WRITE EXCEL
%% ========================================================================

xlsOut = fullfile( ...
    outDir, ...
    'Step9_Darjeeling_API_vs_Seff1_Seff0_WindowSensitivity.xlsx');


if isfile(xlsOut)


    delete(xlsOut);


end


writetable( ...
    ResultTable, ...
    xlsOut, ...
    'Sheet','Window_Sensitivity');


writetable( ...
    SummaryTable, ...
    xlsOut, ...
    'Sheet','Summary');


%% ========================================================================
% 45. COMPLETE
%% ========================================================================

fprintf('\n');
fprintf('=============================================================\n');
fprintf(' STEP 9 ANALYSIS COMPLETE\n');
fprintf('=============================================================\n');


fprintf( ...
    'Station              : %s (%d)\n', ...
    stationName, ...
    stnID);


fprintf( ...
    'Study period         : %d-%d\n', ...
    yr0, ...
    yr1);


fprintf( ...
    'API K                : %.2f\n', ...
    Kvalue);


fprintf( ...
    'Correlation          : Kendall''s tau\n');


fprintf('\n');


fprintf( ...
    'S_eff[1] optimum     : %d days\n', ...
    Lmax1);


fprintf( ...
    'S_eff[1] max tau     : %.4f\n', ...
    maxTau1);


fprintf('\n');


fprintf( ...
    'S_eff[0] max window  : %d days\n', ...
    Lmax0);


fprintf( ...
    'S_eff[0] max tau     : %.4f\n', ...
    maxTau0);


fprintf('\n');


fprintf( ...
    'Step-7 N*            : %.0f days\n', ...
    Nstar_Step7);


fprintf('\nAll files saved in:\n%s\n', ...
    outDir);


fprintf('\nExcel:\n%s\n', ...
    xlsOut);


fprintf('\nPNG:\n%s\n', ...
    [outBase '.png']);


fprintf('\nTIFF:\n%s\n', ...
    [outBase '.tif']);


fprintf('\nFIG:\n%s\n', ...
    [outBase '.fig']);


fprintf('=============================================================\n');