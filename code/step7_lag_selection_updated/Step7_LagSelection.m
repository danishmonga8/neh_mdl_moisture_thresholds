%% ========================================================================
% STEP 7 : Independent antecedent-lag selection
%
% API(N)  vs  lag-1 S_eff
%
% UPDATED WORKFLOW:
%
% API:
%   step_5_crozier_outputs\K_0p90
%
% Triggering events:
%   step_6_triggering_events\step_6_triggering_event_characteristics_radius_ALLOW_OVERLAP
%
% Output:
%   step_7_lag_selection_updated
%
% Method:
%
%   N* = lag having maximum Kendall tau
%
%   tau(API(N), S_eff(t-1))
%
% ========================================================================


clc;
clear;
close all;


%% ========================================================================
% PATHS
%% ========================================================================


ROOT = ...
fullfile(neh_root());


% ---------------- API (K=0.90) ----------------

API_DIR = fullfile( ...
    ROOT, ...
    'step_5_crozier_outputs', ...
    'K_0p90');


% ---------------- Triggering event characteristics ----------------

TRIGGER_DIR = fullfile( ...
    ROOT, ...
    'step_6_trigging_events', ...
    'step_6_triggering_event_characteristics_radius_ALLOW_OVERLAP');


% ---------------- Effective saturation ----------------

SEFF_DIR = fullfile( ...
fullfile(neh_root()), ...
'10_soil_moisture_extraction', ...
'effective_saturation_time_series_all_stations', ...
'effective_saturation_time_series_all_stations');


% ---------------- Station file ----------------

STATION_XLSX = fullfile( ...
fullfile(neh_root()), ...
'all_stations_neh.xlsx');


% ---------------- Output ----------------

OUT_DIR = fullfile( ...
ROOT, ...
'step_7_lag_selection_updated');


if ~exist(OUT_DIR,'dir')

    mkdir(OUT_DIR);

end



%% ========================================================================
% CONFIGURATION
%% ========================================================================


LAGS = [3 5 7 11 15 21 25 30];


SEFF_LAG = 1;


YR_START = 2007;

YR_END = 2021;


K_VALUE = 0.90;



fprintf('\n');
fprintf('=============================================================\n');
fprintf(' UPDATED API - S_eff LAG SELECTION\n');
fprintf('=============================================================\n');

fprintf('API source       : K = %.2f\n',K_VALUE);

fprintf('Landslide radius : station radius overlap retained\n');

fprintf('Period           : %d-%d\n',YR_START,YR_END);

fprintf('S_eff comparison : lag-%d day\n',SEFF_LAG);

fprintf('Candidate lags   : ');

fprintf('%d ',LAGS);

fprintf('\n');

fprintf('=============================================================\n\n');



%% ========================================================================
% READ STATION LIST
%% ========================================================================


STN = readtable( ...
    STATION_XLSX, ...
    'VariableNamingRule','preserve');


stationName = string(STN{:,1});


stationID = string(STN{:,2});


stationID = erase(stationID,'.0');


nStations = numel(stationID);



fprintf('Stations found: %d\n\n',nStations);



%% ========================================================================
% PREALLOCATE
%% ========================================================================


nLag = numel(LAGS);


TAU = nan(nStations,nLag);

PVAL = nan(nStations,nLag);

NEVENT = nan(nStations,nLag);



%% ========================================================================
% MAIN LOOP
%% ========================================================================


for i = 1:nStations


    id = stationID(i);


    fprintf('\nProcessing %s (%s)\n', ...
        stationName(i),id);



    %% ---------------------------------------------------------------
    % READ S_eff
    %% ---------------------------------------------------------------


    seffFile = fullfile( ...
        SEFF_DIR, ...
        sprintf('%s_SMrz_Seff.txt',id));


    if ~isfile(seffFile)


        warning('Missing S_eff: %s',id);

        continue

    end



    S = readmatrix(seffFile);



    if size(S,2)<5

        warning('Invalid S_eff file %s',id);

        continue

    end



    seffDate = datetime( ...
        S(:,1), ...
        S(:,2), ...
        S(:,3));


    seffValue = S(:,5);



    %% ---------------------------------------------------------------
    % LOOP LAGS
    %% ---------------------------------------------------------------


    for j = 1:nLag


        lag = LAGS(j);



        %% -----------------------------------------------------------
        % API file
        %
        % Example:
        %
        % 326239204_3_crozier_5.txt
        %% -----------------------------------------------------------


    apiFile = fullfile( ...
        API_DIR, ...
        sprintf('%02d_day',lag), ...
        sprintf('%s_%02dd_crozier_K0p90.txt',id,lag));


        if ~isfile(apiFile)


            warning('API missing %s lag %d',id,lag);

            continue

        end



        %% -----------------------------------------------------------
        % Triggering event file
        %% -----------------------------------------------------------


     trigFile = fullfile( ...
    TRIGGER_DIR, ...
    sprintf('%s_trigging.txt',id));



        if ~isfile(trigFile)


            warning('Trigger file missing %s',id);

            continue

        end



        %% -----------------------------------------------------------
        % READ API
        %% -----------------------------------------------------------


        API = readmatrix(apiFile);


        if size(API,2)<4

            continue

        end


        eventDate = datetime( ...
            API(:,1), ...
            API(:,2), ...
            API(:,3));


        apiValue = API(:,4);



        %% -----------------------------------------------------------
        % PERIOD FILTER
        %% -----------------------------------------------------------


        keep = ...
            year(eventDate)>=YR_START & ...
            year(eventDate)<=YR_END;


        eventDate = eventDate(keep);

        apiValue = apiValue(keep);



        if isempty(eventDate)

            continue

        end



        %% -----------------------------------------------------------
        % MATCH S_eff lag-1
        %% -----------------------------------------------------------


        targetDate = eventDate - days(SEFF_LAG);



        [tf,loc] = ismember( ...
            targetDate, ...
            seffDate);



        matchedSeff = nan(size(apiValue));


        matchedSeff(tf)= ...
            seffValue(loc(tf));



        %% -----------------------------------------------------------
        % VALID PAIRS
        %% -----------------------------------------------------------


        valid = ...
            isfinite(apiValue) & ...
            isfinite(matchedSeff);



        NEVENT(i,j)=sum(valid);



        if sum(valid)<5

            continue

        end



        %% -----------------------------------------------------------
        % KENDALL TAU
        %% -----------------------------------------------------------


        [tau,p]=corr( ...
            apiValue(valid), ...
            matchedSeff(valid), ...
            'Type','Kendall', ...
            'Rows','complete');


        TAU(i,j)=tau;

        PVAL(i,j)=p;



    end

end

%% ========================================================================
% PART 2 / UPDATED CLEAN VERSION
% Optimal lag selection + Excel output + publication-style heatmap
%
% This part assumes Part 1 has already been run in the same script.
% If running separately, uncomment the load() line below.
% ========================================================================

% load(fullfile(OUT_DIR,'Step7_LagSelection_Matrices.mat'));

%% ========================================================================
% 1. SELECT OPTIMAL LAG (maximum Kendall tau)
%% ========================================================================

nStations = numel(stationName);
nLag      = numel(LAGS);

OptimalLag    = nan(nStations,1);
OptimalTau    = nan(nStations,1);
OptimalP      = nan(nStations,1);
OptimalEvents = nan(nStations,1);
OptimalCol    = nan(nStations,1);

for i = 1:nStations

    tauRow = TAU(i,:);

    if all(isnan(tauRow))
        continue
    end

    % choose maximum tau; if ties occur, MATLAB returns first one
    [mx, idxMax] = max(tauRow);

    OptimalLag(i)    = LAGS(idxMax);
    OptimalTau(i)    = mx;
    OptimalP(i)      = PVAL(i,idxMax);
    OptimalEvents(i) = NEVENT(i,idxMax);
    OptimalCol(i)    = idxMax;

end


%% ========================================================================
% 2. SORT STATIONS IN ASCENDING ORDER OF SELECTED LAG
%    (NaN stations go to the end)
%% ========================================================================

sortKey = OptimalLag;
sortKey(isnan(sortKey)) = inf;

[~, ord] = sort(sortKey,'ascend');

stationName_ord = stationName(ord);
stationID_ord   = stationID(ord);

TAU_ord    = TAU(ord,:);
PVAL_ord   = PVAL(ord,:);
NEVENT_ord = NEVENT(ord,:);

OptimalLag_ord    = OptimalLag(ord);
OptimalTau_ord    = OptimalTau(ord);
OptimalP_ord      = OptimalP(ord);
OptimalEvents_ord = OptimalEvents(ord);
OptimalCol_ord    = OptimalCol(ord);


%% ========================================================================
% 3. SUMMARY TABLE
%% ========================================================================

LagSelectionSummary = table( ...
    stationName, ...
    stationID, ...
    OptimalLag, ...
    OptimalTau, ...
    OptimalP, ...
    OptimalEvents, ...
    'VariableNames', ...
    {'Station','IMD_ID','Optimal_N_days','Maximum_Kendall_tau','p_value','Number_of_events'});

summaryFile = fullfile(OUT_DIR,'Step7_Optimal_Lag_Summary.xlsx');

if isfile(summaryFile)
    delete(summaryFile);
end

writetable(LagSelectionSummary, summaryFile, 'Sheet','Optimal_N');


%% ========================================================================
% 4. COMPLETE MATRICES TO EXCEL
%% ========================================================================

lagVarNames = matlab.lang.makeValidName("N_" + string(LAGS));

TauTable = table(stationName, stationID, 'VariableNames',{'Station','IMD_ID'});
PTable   = table(stationName, stationID, 'VariableNames',{'Station','IMD_ID'});
NTable   = table(stationName, stationID, 'VariableNames',{'Station','IMD_ID'});

for j = 1:nLag
    TauTable.(lagVarNames{j}) = TAU(:,j);
    PTable.(lagVarNames{j})   = PVAL(:,j);
    NTable.(lagVarNames{j})   = NEVENT(:,j);
end

writetable(TauTable, summaryFile, 'Sheet','Kendall_tau');
writetable(PTable,   summaryFile, 'Sheet','p_value');
writetable(NTable,   summaryFile, 'Sheet','Event_count');


%% ========================================================================
% 5. SAVE MATLAB RESULTS
%% ========================================================================

save(fullfile(OUT_DIR,'Step7_Final_Lag_Selection.mat'), ...
    'LagSelectionSummary', ...
    'TAU','PVAL','NEVENT','LAGS', ...
    'OptimalLag','OptimalTau','OptimalP','OptimalEvents', ...
    'ord','stationName_ord','stationID_ord', ...
    'TAU_ord','PVAL_ord','NEVENT_ord', ...
    'OptimalLag_ord','OptimalTau_ord','OptimalP_ord','OptimalEvents_ord','OptimalCol_ord');


%% ========================================================================
% 6. PUBLICATION-STYLE HEATMAP
%    - no title
%    - rows sorted by selected lag
%    - outlined selected lag
%    - selected cell text bold
%    - annotation includes significance
%    - colour bar style similar to manuscript figure
%% ========================================================================

fig = figure('Color','w','Units','centimeters','Position',[2 2 30 18]);
ax  = axes(fig);
hold(ax,'on');

imagesc(ax, TAU_ord);

set(ax,'YDir','reverse');

% symmetric limits around zero
cmax = max(abs(TAU_ord(:)),[],'omitnan');
if ~isfinite(cmax) || cmax == 0
    cmax = 0.5;
end
set(ax,'CLim',[-cmax cmax]);

% custom blue-white-red style colormap
m = 256;
h = floor(m/2);

blue_to_white = [ ...
    linspace(0.12,1,h)' ...
    linspace(0.32,1,h)' ...
    linspace(0.72,1,h)'];

white_to_red = [ ...
    linspace(1,0.88,h)' ...
    linspace(1,0.20,h)' ...
    linspace(1,0.20,h)'];

cmap = [blue_to_white; white_to_red];
colormap(ax,cmap);

% axis labels
set(ax, ...
    'XTick',1:nLag, ...
    'XTickLabel',string(LAGS), ...
    'YTick',1:nStations, ...
    'YTickLabel',stationName_ord, ...
    'FontSize',14, ...
    'FontWeight','bold', ...
    'TickLength',[0 0], ...
    'Box','on', ...
    'Layer','top', ...
    'LineWidth',1.0);

xlabel(ax,'Antecedent window, N (days)','FontSize',16,'FontWeight','bold');
ylabel(ax,'','FontSize',16,'FontWeight','bold');

xlim(ax,[0.5 nLag+0.5]);
ylim(ax,[0.5 nStations+0.5]);

% annotate every cell
for r = 1:nStations
    for c = 1:nLag

        if ~isfinite(TAU_ord(r,c))
            continue
        end

        val = TAU_ord(r,c);
        p   = PVAL_ord(r,c);

        lbl = sprintf('%.2f',val);

        if isfinite(p)
            if p < 0.05
                lbl = [lbl '**'];
            elseif p < 0.10
                lbl = [lbl '*'];
            end
        end

        % selected lag cell => bold
        if isfinite(OptimalCol_ord(r)) && c == OptimalCol_ord(r)
            fw = 'bold';
            fs = 13;
        else
            fw = 'normal';
            fs = 11;
        end

        % adaptive text colour for dark cells
        if abs(val) > 0.55*cmax
            txtColor = [1 1 1];
        else
            txtColor = [0 0 0];
        end

        text(ax, c, r, lbl, ...
            'HorizontalAlignment','center', ...
            'VerticalAlignment','middle', ...
            'FontSize',fs, ...
            'FontWeight',fw, ...
            'Color',txtColor);
    end
end

% draw black box around selected lag only
for r = 1:nStations
    if ~isfinite(OptimalCol_ord(r))
        continue
    end

    c = OptimalCol_ord(r);

    rectangle(ax, ...
        'Position',[c-0.5, r-0.5, 1, 1], ...
        'EdgeColor','k', ...
        'LineWidth',2.4);
end

% colour bar
cb = colorbar(ax);
cb.Label.String   = 'Kendall''s \tau';
cb.Label.FontSize = 14;
cb.Label.FontWeight = 'bold';
cb.FontSize       = 12;
cb.LineWidth      = 0.8;


%% ========================================================================
% 7. FINAL MESSAGE
%% ========================================================================

fprintf('\n=============================================================\n');
fprintf('STEP 7 COMPLETE\n');
fprintf('Summary file:\n%s\n', summaryFile);
fprintf('Figure saved:\n%s\n', pngFile);
fprintf('=============================================================\n');