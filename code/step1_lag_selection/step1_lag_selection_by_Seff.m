%% ========================================================================
% STEP 1 -- Independent antecedent-lag selection using root-zone wetness
%
% Reviewer 2, Comment 11
%
% For each site:
%   1. Calculate API at candidate antecedent windows N <= 30 d
%   2. Match each landslide event with S_eff one day before failure
%   3. Calculate Kendall's tau between API(N) and lag-1 S_eff
%   4. Select:
%
%          N* = argmax_N tau(API(N), S_eff[t-1])
%
% Lag selection therefore does NOT use TR or API > TR.
%
% K = 0.9 is held fixed during this step.
%
% Outputs:
%   Step1_LagSelection_Summary.xlsx
%   Step1_LagSelection.mat
%
% Figure is displayed only; it is NOT exported.
%% ========================================================================

clc;
clear;
close all;

%% ---------------------------- USER PATHS --------------------------------

ROOT_A = fullfile(neh_root());
ROOT_B = fullfile(neh_root(),'2_new_stations_neh');

API_DIR_A = fullfile(ROOT_A,'6_crozier_outputs');
API_DIR_B = fullfile(ROOT_B,'6_crozier_outputs');

SEFF_DIR = fullfile(ROOT_A, ...
    '10_soil_moisture_extraction', ...
    'effective_saturation_time_series_all_stations', ...
    'effective_saturation_time_series_all_stations');

STN_XLSX = fullfile(ROOT_A,'all_stations_neh.xlsx');

OUT_DIR = fullfile(ROOT_A, ...
    'revision_round1', ...
    'step1_lag_selection');

if ~exist(OUT_DIR,'dir')
    mkdir(OUT_DIR);
end

%% ---------------------------- CONFIG ------------------------------------

% Only candidate windows <= 30 days
LAGS = [3 5 7 11 15 21 25 30];

SEFF_LAG = 1;        % S_eff one day before landslide
YR_START = 2007;
YR_END   = 2019;

KDECAY = 0.9;

% Stored only for descriptive reporting
ALPHA = 0.10;

nL = numel(LAGS);

fprintf('\n=============================================================\n');
fprintf('Independent lag selection: API(N) vs lag-%d S_eff\n',SEFF_LAG);
fprintf('K = %.2f | Period = %d-%d\n',KDECAY,YR_START,YR_END);
fprintf('Candidate windows: ');
fprintf('%d ',LAGS);
fprintf('days\n');
fprintf('=============================================================\n\n');

%% ------------------------- STATION LIST ---------------------------------

raw = readcell(STN_XLSX,'Sheet','Sheet1');

hdr = strings(1,size(raw,2));

for c = 1:size(raw,2)
    try
        hdr(c) = string(raw{1,c});
    catch
        hdr(c) = "";
    end
end

% Previous TR-based lag retained only for comparison
colOld = find( ...
    contains(lower(hdr),'ideal') & ...
    contains(lower(hdr),'lag'),1);

stnName = strings(0,1);
stnID   = strings(0,1);
oldLag  = [];

for r = 2:size(raw,1)

    if isempty(raw{r,1})
        continue
    end

    nm = strtrim(string(raw{r,1}));

    if ismissing(nm) || strlength(nm)==0
        continue
    end

    stnName(end+1,1) = nm; %#ok<SAGROW>

    v = raw{r,2};

    if isnumeric(v)
        stnID(end+1,1) = string(sprintf('%d',v)); %#ok<SAGROW>
    else
        stnID(end+1,1) = strtrim(string(v)); %#ok<SAGROW>
    end

    if isempty(colOld) || ...
            isempty(raw{r,colOld}) || ...
            ~isnumeric(raw{r,colOld})

        oldLag(end+1,1) = NaN; %#ok<SAGROW>

    else
        oldLag(end+1,1) = raw{r,colOld}; %#ok<SAGROW>
    end
end

nS = numel(stnID);

fprintf('Stations read: %d\n\n',nS);

%% ------------------------- PREALLOCATE ----------------------------------

TAU = nan(nS,nL);
PVL = nan(nS,nL);
NEV = nan(nS,nL);

SRC = strings(nS,nL);

%% ------------------------- MAIN LOOP ------------------------------------

for i = 1:nS

    id = stnID(i);

    %% ---- Read daily S_eff ----

    fS = fullfile(SEFF_DIR, ...
        sprintf('%s_SMrz_Seff.txt',id));

    if ~isfile(fS)

        warning('S_eff missing: %s (%s)', ...
            stnName(i),id);

        continue
    end

    S = readmatrix( ...
        fS, ...
        'FileType','text', ...
        'NumHeaderLines',1);

    if isempty(S) || size(S,2) < 5
        warning('Invalid S_eff file: %s',id);
        continue
    end

    seffDate = datetime( ...
        S(:,1), ...
        S(:,2), ...
        S(:,3));

    seffVal = S(:,5);

    %% ---- API windows ----

    for j = 1:nL

        L = LAGS(j);

        fn = sprintf('%s_%d_crozier_5.txt',id,L);

        fA = fullfile( ...
            API_DIR_A, ...
            sprintf('%d_day',L), ...
            fn);

        fB = fullfile( ...
            API_DIR_B, ...
            sprintf('%d_day',L), ...
            fn);

        if isfile(fA)

            fAPI = fA;
            SRC(i,j) = "A";

        elseif isfile(fB)

            fAPI = fB;
            SRC(i,j) = "B";

        else

            SRC(i,j) = "-";
            continue

        end

        %% ---- Read API ----

        Araw = readmatrix( ...
            fAPI, ...
            'FileType','text');

        if isempty(Araw) || size(Araw,2) < 4
            continue
        end

        evDate = datetime( ...
            Araw(:,1), ...
            Araw(:,2), ...
            Araw(:,3));

        apiVal = Araw(:,4);

        %% ---- Restrict analysis period ----

        keep = ...
            year(evDate) >= YR_START & ...
            year(evDate) <= YR_END;

        evDate = evDate(keep);
        apiVal = apiVal(keep);

        if isempty(evDate)
            continue
        end

        %% ---- Match lag-1 S_eff ----

        targetDate = evDate - days(SEFF_LAG);

        [tf,loc] = ismember(targetDate,seffDate);

        sVal = nan(size(apiVal));

        sVal(tf) = seffVal(loc(tf));

        %% ---- Valid paired observations ----

        ok = ...
            isfinite(apiVal) & ...
            isfinite(sVal);

        NEV(i,j) = sum(ok);

        % Do not calculate correlation with extremely few observations
        if sum(ok) < 5
            continue
        end

        %% ---- Kendall correlation ----

        [tauVal,pVal] = corr( ...
            apiVal(ok), ...
            sVal(ok), ...
            'Type','Kendall', ...
            'Rows','complete');

        TAU(i,j) = tauVal;
        PVL(i,j) = pVal;

    end
end

%% ------------------------ SELECT N* -------------------------------------

Nstar   = nan(nS,1);
TauStar = nan(nS,1);
PStar   = nan(nS,1);
NStar_n = nan(nS,1);

for i = 1:nS

    tv = TAU(i,:);

    if all(isnan(tv))
        continue
    end

    % IMPORTANT:
    % Ignore unavailable windows rather than allowing NaN to invalidate N*
    [TauStar(i),k] = max(tv,[],'omitnan');

    Nstar(i)   = LAGS(k);
    PStar(i)   = PVL(i,k);
    NStar_n(i) = NEV(i,k);

end

%% ----------------------- CONSOLE SUMMARY --------------------------------

fprintf('\n%-18s %-10s %6s %9s %9s %7s %9s\n', ...
    'Station','IMD_ID','N*','tau*','p','n','old lag');

fprintf('%s\n',repmat('-',1,82));

for i = 1:nS

    fprintf('%-18s %-10s %6g %9.3f %9.3f %7g %9g\n', ...
        stnName(i), ...
        stnID(i), ...
        Nstar(i), ...
        TauStar(i), ...
        PStar(i), ...
        NStar_n(i), ...
        oldLag(i));

end

fprintf('%s\n',repmat('-',1,82));

fprintf('Median N*      : %.1f days\n', ...
    median(Nstar,'omitnan'));

fprintf('Range N*       : %.0f - %.0f days\n', ...
    min(Nstar,[],'omitnan'), ...
    max(Nstar,[],'omitnan'));

fprintf('Median tau*    : %.3f\n', ...
    median(TauStar,'omitnan'));

fprintf('tau* > 0       : %d / %d sites\n', ...
    sum(TauStar > 0), ...
    sum(isfinite(TauStar)));

fprintf('p < %.2f        : %d / %d sites\n', ...
    ALPHA, ...
    sum(PStar < ALPHA), ...
    sum(isfinite(PStar)));

validCompare = ...
    isfinite(Nstar) & ...
    isfinite(oldLag);

if sum(validCompare) > 2

    tauOldNew = corr( ...
        oldLag(validCompare), ...
        Nstar(validCompare), ...
        'Type','Kendall');

    fprintf('Old lag vs N* Kendall tau: %.3f\n',tauOldNew);

end

fprintf('\n');

%% -------------------------- WRITE OUTPUTS -------------------------------

Summary = table( ...
    stnName, ...
    stnID, ...
    Nstar, ...
    TauStar, ...
    PStar, ...
    NStar_n, ...
    oldLag, ...
    'VariableNames',{ ...
    'Station', ...
    'IMD_ID', ...
    'N_star_d', ...
    'Tau_star', ...
    'p_value', ...
    'n_events', ...
    'Ideal_lag_old'});

xlsOut = fullfile( ...
    OUT_DIR, ...
    'Step1_LagSelection_Summary.xlsx');

writetable( ...
    Summary, ...
    xlsOut, ...
    'Sheet','Nstar_summary');

lagHdr = "L" + string(LAGS) + "d";

TauTable = [ ...
    table(stnName,'VariableNames',{'Station'}) ...
    array2table(TAU,'VariableNames',lagHdr)];

PTable = [ ...
    table(stnName,'VariableNames',{'Station'}) ...
    array2table(PVL,'VariableNames',lagHdr)];

NTable = [ ...
    table(stnName,'VariableNames',{'Station'}) ...
    array2table(NEV,'VariableNames',lagHdr)];

writetable(TauTable,xlsOut,'Sheet','Kendall_tau');
writetable(PTable,xlsOut,'Sheet','p_value');
writetable(NTable,xlsOut,'Sheet','n_events');

save( ...
    fullfile(OUT_DIR,'Step1_LagSelection.mat'), ...
    'TAU', ...
    'PVL', ...
    'NEV', ...
    'Nstar', ...
    'TauStar', ...
    'PStar', ...
    'NStar_n', ...
    'oldLag', ...
    'stnName', ...
    'stnID', ...
    'LAGS', ...
    'SRC', ...
    'KDECAY', ...
    'SEFF_LAG');

fprintf('Written: %s\n',xlsOut);

%% ============================ HEATMAP ===================================
% Sites are intentionally sorted by independently selected N*
% from smallest to largest.
%
% Significance notation:
%   *   p < 0.10
%   **  p < 0.05
%
% Threshold definitions are NOT written on the figure.
% Selected N* is indicated only by the black box.
% Figure is displayed only and is NOT exported.

%% ---- Sort stations by selected N* ----
[~,ord] = sort( ...
    Nstar, ...
    'ascend', ...
    'MissingPlacement','last');

%% ---- Figure ----
fig = figure( ...
    'Color','w', ...
    'Units','centimeters', ...
    'Position',[2 2 30 18]);

ax = axes(fig);

imagesc(ax,TAU(ord,:));

set(ax,'YDir','reverse');

hold(ax,'on');

%% ---- Symmetric colour limits around zero ----
cmax = max(abs(TAU(:)),[],'omitnan');

if ~isfinite(cmax) || cmax == 0
    cmax = 0.5;
end

clim(ax,[-cmax cmax]);

%% ---- Diverging blue-white-red colormap ----
m = 256;
h = floor(m/2);

cmap = [ ...
    linspace(0.019,1,h)' ...
    linspace(0.188,1,h)' ...
    linspace(0.380,1,h)' ; ...
    ones(h,1) ...
    linspace(1,0.192,h)' ...
    linspace(1,0.152,h)' ];

colormap(ax,cmap);

%% ------------------------------------------------------------------------
% Cell annotations
%
%   tau value only        : p >= 0.10
%   tau*                  : p < 0.10
%   tau**                 : p < 0.05
%
% All text kept BLACK as requested.
%% ------------------------------------------------------------------------

for r = 1:nS

    siteIdx = ord(r);

    for c = 1:nL

        tauVal = TAU(siteIdx,c);
        pVal   = PVL(siteIdx,c);

        if ~isfinite(tauVal)
            continue
        end

        %% ---- Significance symbol ----
        sig = '';

        if isfinite(pVal)

            if pVal < 0.05
                sig = '**';

            elseif pVal < 0.10
                sig = '*';

            end
        end

        %% ---- Cell text ----
        lbl = sprintf('%.2f%s',tauVal,sig);

        text( ...
            ax,c,r,lbl, ...
            'HorizontalAlignment','center', ...
            'VerticalAlignment','middle', ...
            'FontSize',10.5, ...
            'FontWeight','bold', ...
            'Color','k');

    end
end

%% ------------------------------------------------------------------------
% Black box around independently selected N*
%% ------------------------------------------------------------------------

for r = 1:nS

    siteIdx = ord(r);

    if ~isfinite(Nstar(siteIdx))
        continue
    end

    c = find(LAGS == Nstar(siteIdx),1);

    if isempty(c)
        continue
    end

    rectangle( ...
        ax, ...
        'Position',[c-0.5 r-0.5 1 1], ...
        'EdgeColor','k', ...
        'LineWidth',2.4);

end

%% ------------------------------------------------------------------------
% Y-axis labels
% Only station names -- N* removed because black box already marks it
%% ------------------------------------------------------------------------

yLbl = stnName(ord);

%% ------------------------------------------------------------------------
% Axis formatting
%% ------------------------------------------------------------------------

set( ...
    ax, ...
    'XTick',1:nL, ...
    'XTickLabel',string(LAGS), ...
    'YTick',1:nS, ...
    'YTickLabel',yLbl, ...
    'FontSize',12.5, ...
    'FontWeight','bold', ...
    'TickLength',[0 0], ...
    'Box','on', ...
    'Layer','top', ...
    'XColor','k', ...
    'YColor','k', ...
    'LineWidth',1.2);

xlim(ax,[0.5 nL+0.5]);
ylim(ax,[0.5 nS+0.5]);

%% ---- Axis label ----
xlabel( ...
    ax, ...
    'Antecedent window, N (days)', ...
    'FontSize',15, ...
    'FontWeight','bold', ...
    'Color','k');

%% ---- No title / no heading ----

%% ------------------------------------------------------------------------
% Colorbar
%% ------------------------------------------------------------------------

cb = colorbar(ax);

cb.Label.String = 'Kendall''s \tau';
cb.Label.FontSize = 14;
cb.Label.FontWeight = 'bold';
cb.Label.Color = 'k';

cb.FontSize = 12;
cb.FontWeight = 'bold';
cb.Color = 'k';

%% ---- Figure intentionally NOT exported ----
