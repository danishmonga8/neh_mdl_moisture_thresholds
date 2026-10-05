clc; clear; close all;
%% ============================================================
%  Moisture-compounding Amplification Index (AR) across stations
%  AR = P(MDL | R_high, S_prev1d >= q80) / P(MDL | R_high)
%  R_high: 3-day E3 rainfall exceeds this station's own ~20th-percentile
%          threshold (Linear_quantile E-D curve).
%  S_high: lag-1 root-zone Seff is in this station's own top 20% (q80).
%  Laplace/Haldane-Anscombe smoothing: p = (L + 0.5) / (N + 1)
%% ============================================================

%% ================== USER SETTINGS ==================
base_folder  = fullfile(neh_root());
meta_path    = fullfile(base_folder, "all_stations_neh.xlsx");
thr_path     = fullfile(base_folder, "revision_round1","step8_ed_threshold","ED_Linear_vs_PowerLaw_AllStations.xlsx");
thr_sheet    = "Linear_quantile";
ls_path      = fullfile(base_folder, "revision_round1","step_0_landslide_filtering","Station_Landslide_Metadata_radius_ALLOW_OVERLAP.xlsx");
ls_sheet     = "Station_event_pairs";
seffDir      = fullfile(base_folder, "10_soil_moisture_extraction", ...
                  "effective_saturation_time_series_all_stations", ...
                  "effective_saturation_time_series_all_stations");

out_dir   = fullfile(neh_root(),"step11_MDL_likelihood");
if ~exist(out_dir,"dir"), mkdir(out_dir); end
out_excel = fullfile(out_dir, "AR_Compounding_Index_SM_q80_AllStations.xlsx");

start_date = datetime(2007,1,1);
end_date   = datetime(2019,12,31);

eval_rain_threshold_mm = 0.0;
minN_RS = 5;
alpha   = 0.5;
WET_Q   = 80;

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

allVars = Thr.Properties.VariableNames;
isE3col = startsWith(allVars, "E3_P") & ~contains(allVars,"check");
ED_col_names = allVars(isE3col);
if isempty(ED_col_names)
    error('No E3_P* columns found in %s (sheet %s)', thr_path, thr_sheet);
end

pvals = nan(size(ED_col_names));
for i = 1:numel(ED_col_names)
    tok = regexp(ED_col_names{i}, 'E3_P(\d+(\.\d+)?)', 'tokens', 'once');
    if ~isempty(tok)
        pvals(i) = str2double(tok{1});
    end
end
if all(isnan(pvals))
    error('Could not parse percentile values from E3_P column names.');
end
if max(pvals) <= 1.0
    pvals = pvals * 100;
end

[~, idx20] = min(abs(pvals - 20));
ED20_name  = ED_col_names{idx20};
fprintf('Using tau~0.20 E3 threshold column: %s (parsed ~%.2f%%)\n', ED20_name, pvals(idx20));

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

%% ================== INIT OUTPUT TABLE ==================
Summary = table();
Summary.StationID    = strings(0,1);
Summary.ED20_name    = strings(0,1);
Summary.ED20_val_mm  = zeros(0,1);
Summary.NR_eval_days = zeros(0,1);
Summary.NL_mdl_days  = zeros(0,1);
Summary.P_L_prior    = zeros(0,1);
Summary.N_Rhigh      = zeros(0,1);
Summary.L_Rhigh      = zeros(0,1);
Summary.p_Rhigh      = zeros(0,1);
Summary.S_q80_val    = zeros(0,1);
Summary.N_RSq80      = zeros(0,1);
Summary.L_RSq80      = zeros(0,1);
Summary.p_RSq80      = zeros(0,1);
Summary.AR_q80       = nan(0,1);

%% ================== LOOP OVER ALL STATIONS ==================
for k = 1:numel(station_ids)
    sid_str = station_ids(k);
    fprintf('\n========== STATION %s (%d/%d) ==========\n', sid_str, k, numel(station_ids));

    rain_path   = fullfile(base_folder, ...
        "3_rainfall_events_thresholds","rainfall_data_threshold_applied", sid_str + ".txt");
    sat_ts_path = fullfile(seffDir, sid_str + "_SMrz_Seff.txt");

    try
        %% ---------- 1) EXTRACT ED20 THRESHOLD (string-matched IMD_ID) ----------
        thrRow = find(Thr_IMD == sid_str, 1);
        if isempty(thrRow)
            warning('Thresholds missing for %s. Skipping.', sid_str);
            continue;
        end
        ED20_val = Thr{thrRow, ED20_name};
        if isempty(ED20_val) || isnan(ED20_val)
            warning('ED20 value missing/NaN for %s. Skipping.', sid_str);
            continue;
        end

        %% ---------- 2) READ RAINFALL ----------
        if ~isfile(rain_path)
            warning('No rainfall file for %s. Skipping.', sid_str);
            continue;
        end
        Rain = readtable(rain_path, 'FileType','text');
        Rain.Properties.VariableNames = {'Y','M','D','P_mm'};
        Rain.Date = datetime(Rain.Y, Rain.M, Rain.D);
        Rain.E3 = movsum(Rain.P_mm, [2 0]);
        Rain.E3(1:2) = NaN;
        Rain = Rain(Rain.Date>=start_date & Rain.Date<=end_date,:);

        %% ---------- 3) READ Seff (by column name), station-wise q80 cutoff ----------
        if ~isfile(sat_ts_path)
            warning('No saturation TS for %s. Skipping.', sid_str);
            continue;
        end
        SatTS = readtable(sat_ts_path,'FileType','text');
        svn = lower(strtrim(string(SatTS.Properties.VariableNames)));
        yIdx  = find(svn=="year"  | svn=="y", 1);
        mIdx  = find(svn=="month" | svn=="m", 1);
        dIdx  = find(svn=="day"   | svn=="d", 1);
        seIdx = find(svn=="s_eff" | svn=="seff", 1);
        if isempty(yIdx) || isempty(mIdx) || isempty(dIdx) || isempty(seIdx)
            warning('Seff file missing expected columns for %s. Skipping.', sid_str);
            continue;
        end
        seffRaw = SatTS{:,seIdx};
        if ~isnumeric(seffRaw)
            seffRaw = str2double(string(seffRaw));
        end
        SatTS = table(datetime(round(SatTS{:,yIdx}), round(SatTS{:,mIdx}), round(SatTS{:,dIdx})), seffRaw, ...
            'VariableNames', {'Date','Seff'});
        SatTS = SatTS(isfinite(SatTS.Seff), :);
        SatTS = SatTS(SatTS.Date >= start_date-days(1) & SatTS.Date <= end_date, :);
        if isempty(SatTS)
            warning('No usable Seff rows for %s. Skipping.', sid_str);
            continue;
        end

        S_q80 = prctile(SatTS.Seff, WET_Q);          % station's own top-20% wetness cutoff
        SatTS.DateForJoin = SatTS.Date + days(1);     % lag-1: attach to the NEXT day's rain

        %% ---------- 4) LANDSLIDE DATES FOR THIS STATION (shared metadata table) ----------
        lsDatesThisStn = LsT.Date(LsT.IMD == sid_str);

        %% ---------- 5) MERGE (date-matched lag-1) & DEFINE EVALUATION SET ----------
        T = innerjoin(Rain(:,{'Date','P_mm','E3'}), SatTS(:,{'DateForJoin','Seff'}), ...
            'LeftKeys','Date', 'RightKeys','DateForJoin');
        T.Properties.VariableNames{strcmp(T.Properties.VariableNames,'Seff')} = 'S_prev1d';
        T = T(~isnan(T.E3) & ~isnan(T.S_prev1d), :);
        T.L = ismember(T.Date, lsDatesThisStn);

        Teval = T(T.P_mm > eval_rain_threshold_mm & isfinite(T.P_mm), :);
        NR = height(Teval);
        NL = sum(Teval.L);
        if NR == 0
            warning('No evaluation days for %s. Skipping.', sid_str);
            continue;
        end
        P_L = NL / NR;
        fprintf('NR=%d (eval rainy days)  NL=%d  P(L)=%.4f\n', NR, NL, P_L);

        %% ---------- 6) DEFINE R_high AND S_high ----------
        maskR    = (Teval.E3 > ED20_val);
        maskSq80 = (Teval.S_prev1d >= S_q80);

        N_Rhigh = sum(maskR);
        L_Rhigh = sum(Teval.L(maskR));
        if N_Rhigh == 0
            warning('No R_high cases for %s (E3>ED20 never occurs). Skipping.', sid_str);
            continue;
        end
        p_Rhigh = (L_Rhigh + alpha) / (N_Rhigh + 2*alpha);

        maskRSq80 = maskR & maskSq80;
        N_RSq80 = sum(maskRSq80);
        L_RSq80 = sum(Teval.L(maskRSq80));
        p_RSq80 = (L_RSq80 + alpha) / (N_RSq80 + 2*alpha);

        AR_q80 = NaN;
        if N_RSq80 >= minN_RS
            AR_q80 = p_RSq80 / p_Rhigh;
        end

        fprintf('R_high: N=%d L=%d p=%.4f\n', N_Rhigh, L_Rhigh, p_Rhigh);
        fprintf('R_high & S_q80(>=%.4f): N=%d L=%d p=%.4f AR=%.3f\n', S_q80, N_RSq80, L_RSq80, p_RSq80, AR_q80);

        %% ---------- 7) APPEND SUMMARY ----------
        newRow = table( ...
            sid_str, string(ED20_name), ED20_val, ...
            NR, NL, P_L, ...
            N_Rhigh, L_Rhigh, p_Rhigh, ...
            S_q80, N_RSq80, L_RSq80, p_RSq80, AR_q80, ...
            'VariableNames', Summary.Properties.VariableNames);
        Summary = [Summary; newRow]; %#ok<AGROW>

    catch ME
        warning('Station %s skipped: %s', sid_str, ME.message);
        continue;
    end
end

%% ================== WRITE OUTPUT ==================
writetable(Summary, out_excel, 'Sheet', 'AR_summary', 'WriteMode', 'overwritesheet');
fprintf('\nAR summary saved:\n%s\n', out_excel);