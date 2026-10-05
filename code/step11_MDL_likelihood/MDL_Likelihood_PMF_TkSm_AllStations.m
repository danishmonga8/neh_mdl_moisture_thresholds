clear; clc; close all;

%% -------------------------------------------------
% 0) File paths
%% -------------------------------------------------
metaFile      = fullfile(neh_root(),'all_stations_neh.xlsx');
edFile        = fullfile(neh_root(),'step8_ed_threshold','ED_Linear_vs_PowerLaw_AllStations.xlsx');
landslideFile = fullfile(neh_root(),'step_0_landslide_filtering','Station_Landslide_Metadata_radius_ALLOW_OVERLAP.xlsx');
rainDir       = fullfile(neh_root(),'3_rainfall_events_thresholds','rainfall_data_threshold_applied');
seffDir       = fullfile(neh_root(),'10_soil_moisture_extraction','effective_saturation_time_series_all_stations','effective_saturation_time_series_all_stations');

RAIN3_MIN = 2.5;

%% -------------------------------------------------
% 1) Station metadata
%% -------------------------------------------------
Meta = readtable(metaFile, 'Sheet','Sheet1', 'VariableNamingRule','modify');
Meta.Properties.VariableNames = strtrim(Meta.Properties.VariableNames);
StationName = strtrim(string(Meta.Station));
IMD_ID      = string(Meta.IMD);
nStations   = numel(StationName);

%% -------------------------------------------------
% 2) E-D threshold percentile curves — Linear_quantile sheet
%% -------------------------------------------------
ED = readtable(edFile, 'Sheet','Linear_quantile', 'VariableNamingRule','preserve');
edStation = strtrim(string(ED.Station));
edIMD     = string(ED.IMD_ID);

allVarNames = ED.Properties.VariableNames;
isPctCol = startsWith(allVarNames,'E3_P') & ~contains(allVarNames,'check');
pctCols  = allVarNames(isPctCol);
pctVals  = zeros(1,numel(pctCols));
for c = 1:numel(pctCols)
    pctVals(c) = str2double(erase(pctCols{c}, 'E3_P'));
end
[pctVals, sortOrd] = sort(pctVals);
pctCols = pctCols(sortOrd);

%% -------------------------------------------------
% 3) Landslide event dates — all sizes, radius, overlap allowed
%% -------------------------------------------------
LS = readtable(landslideFile, 'Sheet','Station_event_pairs', 'VariableNamingRule','preserve');
LS_Station = strtrim(string(LS.Station));
if isdatetime(LS.EventDate)
    LS_Date = dateshift(LS.EventDate,'start','day');
else
    LS_Date = datetime(round(LS.Year), round(LS.Month), round(LS.Day));
end
Tls = table(LS_Station, LS_Date, 'VariableNames', {'Station','Date'});
Tls = unique(Tls, 'rows');
LS_Station_u = Tls.Station;
LS_Date_u    = Tls.Date;

%% -------------------------------------------------
% 4) Sm class boundaries
%% -------------------------------------------------
smEdges = [0.65 0.75 0.85 0.95 Inf];

%% -------------------------------------------------
% 5) Pooled frequency matrices: rows = Tk (1..5), cols = Sm (1..4)
%% -------------------------------------------------
f_all = zeros(5,4);
f_mdl = zeros(5,4);

skippedStations = strings(0,1);
skipReasons      = strings(0,1);

for s = 1:nStations
    stn = StationName(s);
    imd = IMD_ID(s);

    try
        rainFile = fullfile(rainDir, sprintf('%s.txt', imd));
        seffFile = fullfile(seffDir, sprintf('%s_SMrz_Seff.txt', imd));
        edRow = find(edStation == stn | edIMD == imd, 1);

        if ~isfile(rainFile), error('rainfall file not found: %s', rainFile); end
        if ~isfile(seffFile), error('Seff file not found: %s', seffFile); end
        if isempty(edRow), error('no matching row in ED threshold table'); end

        Rraw = readmatrix(rainFile);
        nColsR = size(Rraw,2);
        if nColsR == 5
            yCol=2; mCol=3; dCol=4; vCol=5;
        elseif nColsR == 4
            yCol=1; mCol=2; dCol=3; vCol=4;
        else
            error('unexpected rainfall file column count = %d (expected 4 or 5)', nColsR);
        end
        rYear  = round(Rraw(:,yCol));
        rMonth = round(Rraw(:,mCol));
        rDay   = round(Rraw(:,dCol));
        rVal   = Rraw(:,vCol);

        badRow = rMonth < 1 | rMonth > 12 | rDay < 1 | rDay > 31 | isnan(rYear);
        if any(badRow)
            fprintf('  [%s / %s] dropping %d malformed rainfall rows\n', stn, imd, sum(badRow));
            rYear(badRow) = []; rMonth(badRow) = []; rDay(badRow) = []; rVal(badRow) = [];
        end
        rDate = datetime(rYear, rMonth, rDay);
        [rDate, ord] = sort(rDate);
        rVal  = rVal(ord);
        n = numel(rDate);

        Sraw = readtable(seffFile, 'FileType','text', 'VariableNamingRule','preserve');
        svn = lower(strtrim(Sraw.Properties.VariableNames));
        yIdx = find(strcmp(svn,'year'),1);
        mIdx = find(strcmp(svn,'month'),1);
        dIdx = find(strcmp(svn,'day'),1);
        seIdx = find(strcmp(svn,'s_eff'),1);
        if isempty(yIdx) || isempty(mIdx) || isempty(dIdx) || isempty(seIdx)
            error('Seff file missing expected columns (year/month/day/S_eff)');
        end
        sYear  = round(Sraw{:,yIdx});
        sMonth = round(Sraw{:,mIdx});
        sDay   = round(Sraw{:,dIdx});
        sVal   = Sraw{:,seIdx};
        sDate  = datetime(sYear, sMonth, sDay);
        [sDate, ord2] = sort(sDate);
        sVal   = sVal(ord2);

        curveVals = table2array(ED(edRow, pctCols));

        E3 = nan(n,1);
        for d = 3:n
            if rDate(d) - rDate(d-2) == days(2)
                E3(d) = rVal(d-2) + rVal(d-1) + rVal(d);
            end
        end

        lagDate = rDate - days(1);
        [isInS1, locS1] = ismember(lagDate, sDate);
        Seff_lag1 = nan(n,1);
        Seff_lag1(isInS1) = sVal(locS1(isInS1));

        qualify = ~isnan(E3) & E3 >= RAIN3_MIN & ~isnan(Seff_lag1);

        pctRank = nan(n,1);
        pctRank(qualify) = interp1(curveVals, pctVals, E3(qualify), 'linear', 'extrap');

        Tk = nan(n,1);
        inBand = qualify & pctRank >= 5;
        Tk(inBand & pctRank < 25)                 = 1;
        Tk(inBand & pctRank >= 25 & pctRank < 50) = 2;
        Tk(inBand & pctRank >= 50 & pctRank < 75) = 3;
        Tk(inBand & pctRank >= 75 & pctRank < 90) = 4;
        Tk(inBand & pctRank >= 90)                = 5;

        smBin = discretize(Seff_lag1, smEdges);
        Sm = nan(n,1);
        validSm = qualify & Seff_lag1 >= 0.65;
        Sm(validSm) = smBin(validSm);

        keep = ~isnan(Tk) & ~isnan(Sm);

        for k = 1:5
            for m = 1:4
                f_all(k,m) = f_all(k,m) + sum(keep & Tk==k & Sm==m);
            end
        end

        lsDatesThisStn = LS_Date_u(LS_Station_u == stn);
        if ~isempty(lsDatesThisStn)
            isLsDay = ismember(rDate, lsDatesThisStn);
            mdlRows = find(isLsDay & keep);
            for k = 1:5
                for m = 1:4
                    f_mdl(k,m) = f_mdl(k,m) + sum(Tk(mdlRows)==k & Sm(mdlRows)==m);
                end
            end
        end

    catch ME
        skippedStations(end+1) = stn; %#ok<AGROW>
        skipReasons(end+1)     = string(ME.message); %#ok<AGROW>
        fprintf('SKIPPED %s (%s): %s\n', stn, imd, ME.message);
        continue;
    end
end

if ~isempty(skippedStations)
    fprintf('\n=== Skipped stations summary ===\n');
    for i = 1:numel(skippedStations)
        fprintf('  %s: %s\n', skippedStations(i), skipReasons(i));
    end
end

%% -------------------------------------------------
% 6) Conditional MDL likelihood — Abraham et al. (2021), eq. 8
%% -------------------------------------------------
P_MDL = f_mdl ./ f_all;
P_MDL(f_all == 0) = NaN;

rowNames = {'T1','T2','T3','T4','T5'};
colNames = {'S1','S2','S3','S4'};

fprintf('\nPooled frequency of all qualifying rainfall events, f_{k,m}:\n');
disp(array2table(f_all, 'VariableNames', colNames, 'RowNames', rowNames));
fprintf('\nPooled frequency of MDL-associated events, f_{k,m}^{MDL}:\n');
disp(array2table(f_mdl, 'VariableNames', colNames, 'RowNames', rowNames));
fprintf('\nP(MDL | Tk, Sm):\n');
disp(array2table(P_MDL, 'VariableNames', colNames, 'RowNames', rowNames));

%% -------------------------------------------------
% 7) 3D bar plot — cleaned formatting, no colorbar, no star
%% -------------------------------------------------
Z = P_MDL;
Z_plot = Z;
Z_plot(isnan(Z_plot)) = 0;

fig = figure('Color','w','Position',[80 60 1100 800]);
ax = axes(fig); hold(ax,'on');

hB = bar3(ax, Z_plot);      % rows(Tk)->y-axis(1:5), cols(Sm)->x-axis(1:4)
for k = 1:numel(hB)
    zdata = hB(k).ZData;
    hB(k).CData = zdata;
    hB(k).FaceColor = 'interp';
    hB(k).EdgeColor = [0.15 0.15 0.15];
    hB(k).LineWidth = 0.75;
end
colormap(ax, jet(256));

ax.XTick = 1:4;
ax.XTickLabel = "S" + (1:4);
ax.YTick = 1:5;
ax.YTickLabel = "T" + (1:5);
ax.XLim = [0.4 4.6];
ax.YLim = [0.4 5.6];
ax.FontSize = 14;
ax.LineWidth = 1.1;
ax.Box = 'on';
ax.BoxStyle = 'back';      % <-- fixes the doubled tick-label rows
ax.GridAlpha = 0.25;
grid(ax,'on');

xlabel(ax,'Lag-1 root-zone wetness (S_m)','FontSize',16,'FontWeight','bold');
ylabel(ax,'Rainfall intensity category (T_k)','FontSize',16,'FontWeight','bold');
zlabel(ax,'P(MDL | T_k, S_m)','FontSize',16,'FontWeight','bold');
view(ax, -37.5, 30);

% ---- number of rainy days per Tk category — clean side panel, no colorbar ----
Ncol = sum(f_all, 2);
axSide = axes('Parent',fig, 'Units','normalized', 'Position',[0.80 0.30 0.18 0.45]);
axis(axSide,'off');
text(axSide, 0, 1.00, 'Number of rainy days', 'FontSize',13,'FontWeight','bold', 'VerticalAlignment','top');
text(axSide, 0, 0.90, 'in each threshold category', 'FontSize',12, 'VerticalAlignment','top');
for k = 1:5
    text(axSide, 0, 0.75 - (k-1)*0.13, sprintf('T%d:  N = %d', k, Ncol(k)), ...
        'FontSize',13, 'FontWeight','bold', 'VerticalAlignment','top');
end
xlim(axSide,[0 1]); ylim(axSide,[0 1]);