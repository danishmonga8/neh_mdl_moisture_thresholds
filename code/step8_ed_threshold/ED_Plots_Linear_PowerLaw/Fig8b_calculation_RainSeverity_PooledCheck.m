clc; clear; close all;

%% ================== SETTINGS ==================
base_folder   = fullfile(neh_root());
meta_path     = fullfile(base_folder, "all_stations_neh.xlsx");
thr_path      = fullfile(base_folder, "revision_round1","step8_ed_threshold","ED_Linear_vs_PowerLaw_AllStations.xlsx");
thr_sheet     = "Linear_quantile";
ls_path       = fullfile(base_folder, "revision_round1","step_0_landslide_filtering","Station_Landslide_Metadata_radius_ALLOW_OVERLAP.xlsx");
ls_sheet      = "Station_event_pairs";
seffDir       = fullfile(base_folder, "10_soil_moisture_extraction", ...
                    "effective_saturation_time_series_all_stations", ...
                    "effective_saturation_time_series_all_stations");

start_date   = datetime(2007,1,1);
end_date     = datetime(2019,12,31);
rain_cutoff_mm = 2.5;

WET_Q      = 80;
EPS_PLOT   = 0.001;

p_edges_base = 5:5:90;
lowP  = p_edges_base(1:end-1);
highP = p_edges_base(2:end);
nBins = numel(lowP) + 1;

out_dir = fullfile(neh_root(),"step11_MDL_likelihood");
if ~exist(out_dir,"dir"), mkdir(out_dir); end
out_excel = fullfile(out_dir, "Figure8b_CALC_TABLE.xlsx");

%% ================== READ META ==================
Meta = readtable(meta_path, "VariableNamingRule","preserve");
Meta.Properties.VariableNames = matlab.lang.makeValidName(Meta.Properties.VariableNames);
if ismember("IMD", string(Meta.Properties.VariableNames))
    station_ids = string(Meta.IMD);
elseif ismember("IMD_ID", string(Meta.Properties.VariableNames))
    station_ids = string(Meta.IMD_ID);
else
    error("Station ID column not found in meta file (expected IMD or IMD_ID).");
end
station_ids = strtrim(station_ids);

%% ================== READ THRESHOLDS ==================
Thr = readtable(thr_path, "Sheet", thr_sheet, "VariableNamingRule","preserve");
Thr.Properties.VariableNames = matlab.lang.makeValidName(Thr.Properties.VariableNames);
Thr_IMD = strtrim(string(Thr.IMD_ID));

thrCols = strings(1, numel(p_edges_base));
for i = 1:numel(p_edges_base)
    thrCols(i) = sprintf("E3_P%02d", p_edges_base(i));
end
if ~all(ismember(thrCols, string(Thr.Properties.VariableNames)))
    missingCols = setdiff(thrCols, string(Thr.Properties.VariableNames));
    error("Threshold file missing columns: %s", strjoin(missingCols, ", "));
end

%% ================== READ LANDSLIDE EVENTS (once, all stations) ==================
LS = readtable(ls_path, "Sheet", ls_sheet, "VariableNamingRule","preserve");
LS_IMD = strtrim(string(LS.IMD_ID));
if isdatetime(LS.EventDate)
    LS_Date = dateshift(LS.EventDate, 'start', 'day');
else
    LS_Date = datetime(round(LS.Year), round(LS.Month), round(LS.Day));
end
LsT = table(LS_IMD, LS_Date, 'VariableNames', {'IMD','Date'});
LsT = unique(LsT, 'rows');

%% ================== ACCUMULATORS (POOLED) ==================
N_bin       = zeros(nBins,1);
N_L_bin     = zeros(nBins,1);
N_bin_wet   = zeros(nBins,1);
N_L_bin_wet = zeros(nBins,1);
usedStations    = strings(0,1);
skippedStations = strings(0,1);
skipReasons     = strings(0,1);

%% ================== LOOP OVER STATIONS ==================
for k = 1:numel(station_ids)
    sid_str = station_ids(k);

    try
        rain_path   = fullfile(base_folder, ...
            "3_rainfall_events_thresholds","rainfall_data_threshold_applied", sid_str + ".txt");
        sat_ts_path = fullfile(seffDir, sid_str + "_SMrz_Seff.txt");

        if ~isfile(rain_path), error("rainfall file not found: %s", rain_path); end
        if ~isfile(sat_ts_path), error("Seff file not found: %s", sat_ts_path); end

        %% ----- 1) Rainfall + E3 -----
        Rain = readtable(rain_path,'FileType','text');
        Rain.Properties.VariableNames = {'Y','M','D','P_mm'};
        Rain.Date = datetime(Rain.Y,Rain.M,Rain.D);
        Rain = Rain(isfinite(Rain.P_mm) & Rain.P_mm>=0, :);
        Rain.E3 = movsum(Rain.P_mm,[2 0]);
        Rain.E3(1:2) = NaN;
        Rain = Rain(Rain.Date>=start_date & Rain.Date<=end_date, :);

        %% ----- 2) Saturation TS — select columns BY NAME, force numeric -----
        SatTS = readtable(sat_ts_path,'FileType','text');
        svn = lower(strtrim(string(SatTS.Properties.VariableNames)));
        yIdx  = find(svn=="year"  | svn=="y", 1);
        mIdx  = find(svn=="month" | svn=="m", 1);
        dIdx  = find(svn=="day"   | svn=="d", 1);
        seIdx = find(svn=="s_eff" | svn=="seff", 1);
        if isempty(yIdx) || isempty(mIdx) || isempty(dIdx) || isempty(seIdx)
            error("Seff file missing expected columns (year/month/day/S_eff). Found: %s", ...
                strjoin(cellstr(SatTS.Properties.VariableNames), ", "));
        end
        sYear  = round(SatTS{:,yIdx});
        sMonth = round(SatTS{:,mIdx});
        sDay   = round(SatTS{:,dIdx});
        seffRaw = SatTS{:,seIdx};
        if ~isnumeric(seffRaw)
            seffRaw = str2double(string(seffRaw));   % force numeric if it came in as text
        end
        SatTS = table(datetime(sYear,sMonth,sDay), seffRaw, 'VariableNames', {'Date','Seff'});
        SatTS = SatTS(isfinite(SatTS.Seff), :);       % drop any rows that still failed to convert
        SatTS = SatTS(SatTS.Date >= start_date-days(1) & SatTS.Date <= end_date, :);

        if isempty(SatTS)
            error("no usable numeric Seff rows after cleaning");
        end

        stnQ80 = prctile(SatTS.Seff, WET_Q);
        SatTS.DateForJoin = SatTS.Date + days(1);

        %% ----- 3) Landslide dates for this station -----
        lsDatesThisStn = LsT.Date(LsT.IMD == sid_str);

        %% ----- 4) Merge: rain day <- lag-1 Seff, then rainy-day filter -----
        T = innerjoin(Rain(:,{'Date','P_mm','E3'}), SatTS(:,{'DateForJoin','Seff'}), ...
            'LeftKeys','Date', 'RightKeys','DateForJoin');
        T = T(isfinite(T.P_mm) & isfinite(T.E3), :);
        T = T(T.P_mm >= rain_cutoff_mm, :);
        if isempty(T)
            error("no qualifying rainy days after merge/filter");
        end
        T.L   = ismember(T.Date, lsDatesThisStn);
        T.Wet = T.Seff >= stnQ80;

        %% ----- 5) Station thresholds -----
        thrRow = find(Thr_IMD == sid_str, 1);
        if isempty(thrRow)
            error("no matching row in ED threshold table");
        end
        thrVals = double(Thr{thrRow, thrCols});
        if any(~isfinite(thrVals)) || any(diff(thrVals) <= 0)
            thrVals = prctile(T.E3, p_edges_base);
        end
        if any(~isfinite(thrVals)) || any(diff(thrVals) <= 0)
            error("invalid/non-increasing thresholds");
        end

        %% ----- 6) Bin assignment -----
        edges = [thrVals, inf];
        b = discretize(T.E3, edges);
        ok = isfinite(b) & b>=1 & b<=nBins;
        if ~any(ok)
            error("no rows fell inside the classified severity range");
        end
        b   = b(ok);
        L   = T.L(ok);
        Wet = T.Wet(ok);

        %% ----- 7) Update pooled counts -----
        N_bin       = N_bin       + accumarray(b, 1,                  [nBins 1], @sum, 0);
        N_L_bin     = N_L_bin     + accumarray(b, double(L),          [nBins 1], @sum, 0);
        N_bin_wet   = N_bin_wet   + accumarray(b(Wet), 1,             [nBins 1], @sum, 0);
        N_L_bin_wet = N_L_bin_wet + accumarray(b(Wet), double(L(Wet)),[nBins 1], @sum, 0);

        usedStations(end+1,1) = sid_str; %#ok<AGROW>

    catch ME
        skippedStations(end+1,1) = sid_str; %#ok<AGROW>
        skipReasons(end+1,1)     = string(ME.message); %#ok<AGROW>
        fprintf("SKIPPED %s: %s\n", sid_str, ME.message);
        continue;
    end
end

if isempty(usedStations)
    error("No stations processed. Check paths/data.");
end
nStationsUsed = numel(usedStations);

if ~isempty(skippedStations)
    fprintf("\n=== Skipped stations summary ===\n");
    for i = 1:numel(skippedStations)
        fprintf("  %s: %s\n", skippedStations(i), skipReasons(i));
    end
end

%% ================== BUILD OUTPUT TABLE ==================
Class = strcat(string(lowP(:)),"-",string(highP(:)));
Class = [Class; ">90"];

P_rainonly = nan(nBins,1);
mask = N_bin > 0;
P_rainonly(mask) = N_L_bin(mask) ./ N_bin(mask);

P_joint_raw = nan(nBins,1);
maskWet = N_bin_wet > 0;
P_joint_raw(maskWet) = N_L_bin_wet(maskWet) ./ N_bin_wet(maskWet);
P_joint_plot = P_joint_raw + EPS_PLOT;

wetness_def = repmat("stationwise_q80_of_Seff_m1", nBins, 1);
wet_q       = repmat(WET_Q, nBins, 1);
eps_col     = repmat(EPS_PLOT, nBins, 1);
nStn_col    = repmat(nStationsUsed, nBins, 1);

Out = table(Class, N_bin, N_L_bin, P_rainonly, N_bin_wet, N_L_bin_wet, ...
    P_joint_raw, P_joint_plot, wetness_def, wet_q, eps_col, nStn_col, ...
    'VariableNames', {'Class','N_bin','N_L_bin','P_rainonly','N_bin_wet','N_L_bin_wet', ...
        'P_joint_raw','P_joint_plot','wetness_def','wet_q','eps_added_for_plot','nStationsUsed'});

writetable(Out, out_excel, "Sheet","Figure8b_CALC_TABLE");
writetable(table(usedStations), out_excel, "Sheet","UsedStations");
writetable(table(skippedStations, skipReasons), out_excel, "Sheet","SkippedStations");
fprintf("\nSaved: %s\n", out_excel);
disp(Out);