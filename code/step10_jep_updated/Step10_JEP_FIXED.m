%% ============================================================================
% STEP 10: Joint Exceedance Probability (JEP) — FULL REBUILD
% Primary event list = TR audit (645 events, real pipeline, ground truth)
% Classification joined onto it from the 783-row classification file
% API: Crozier files (station-specific Ideal_lag) — handles BOTH column layouts
% Seff: daily time series, value at EventDate - 1 day
% Ranks/copulas built from FULL station event set (n>15 required)
% Corrected denominator: n (NOT n+1)
% Reports JEP only for LARGE / CATASTROPHIC events
% (Old_1_minus_C123 comparison columns REMOVED per request)
%% ============================================================================
clear; clc; close all;

metaFile      = fullfile(neh_root(),'all_stations_neh.xlsx');
landslideFile = fullfile(neh_root(),'step_0_landslide_filtering','Landslides_radius_Classification_OverlapAllowed.xlsx');
trAuditFile   = fullfile(neh_root(),'step6_trigging_events','step_6_triggering_event_characteristics_radius_ALLOW_OVERLAP','Triggering_Event_Characteristics_radius_Audit.xlsx');
crozierBase   = fullfile(neh_root(),'step5_crozier_outputs','K_0p90');
seffBase      = fullfile(neh_root(),'10_soil_moisture_extraction','effective_saturation_time_series_all_stations','effective_saturation_time_series_all_stations');
outPath       = fullfile(neh_root(),'step10_jep_updated');

if ~exist(outPath, 'dir')
    mkdir(outPath);
end

%% ============================================================================
% 1) Read station metadata (Slope, BuiltArea, Vegetation, Ideal_lag, IMD)
%% ============================================================================
fprintf('=== LOADING STATION METADATA ===\n');
Meta = readtable(metaFile, 'Sheet', 'Sheet1', 'VariableNamingRule', 'modify');
Meta.Properties.VariableNames = strtrim(Meta.Properties.VariableNames);
Meta.Station = string(strtrim(Meta.Station));
fprintf('Stations in metadata: %d\n\n', height(Meta));

%% ============================================================================
% 2) Read landslide classification events (783 rows — used for Classification only)
%% ============================================================================
fprintf('=== LOADING LANDSLIDE CLASSIFICATION FILE ===\n');
L = readtable(landslideFile, 'VariableNamingRule', 'preserve');
L.Station = string(L.Station);
L.Classification = string(L.Classification);
fprintf('Total classified event rows: %d\n\n', height(L));

%% ============================================================================
% 3) Read TR audit (Event_level sheet) — 645 events, ground truth event list
%% ============================================================================
fprintf('=== LOADING TR AUDIT (TriggerRainfall) ===\n');
TRAudit = readtable(trAuditFile, 'Sheet', 'Event_level', 'VariableNamingRule', 'preserve');
TRAudit.Station = string(TRAudit.Station);
TRAudit_Year  = year(TRAudit.LandslideDate);
TRAudit_Month = month(TRAudit.LandslideDate);
TRAudit_Day   = day(TRAudit.LandslideDate);
fprintf('Total TR audit event rows: %d\n\n', height(TRAudit));

%% ============================================================================
% 4) Loop over stations — TR audit (645) is the PRIMARY event list
%% ============================================================================
uniqueStations = unique(TRAudit.Station);
nStations = numel(uniqueStations);

Out = table();
Skipped_LowCount_Stations      = strings(0,1);
Skipped_NoMetaMatch_Stations   = strings(0,1);
Skipped_BadCrozierFile_Stations = strings(0,1);
No_Large_Catastrophic_Stations = strings(0,1);
Unmatched_Classification_Count = 0;

for k = 1:nStations
    stnName = uniqueStations(k);

    % PRIMARY event list = TR audit (645 total, ground truth)
    stnTRMask   = (TRAudit.Station == stnName);
    stnTR_Year  = TRAudit_Year(stnTRMask);
    stnTR_Month = TRAudit_Month(stnTRMask);
    stnTR_Day   = TRAudit_Day(stnTRMask);
    stnTR_Val   = TRAudit.TriggerRainfall(stnTRMask);
    stnTR_Dist  = TRAudit.Distance_km(stnTRMask);
    nRaw = numel(stnTR_Val);

    idxMeta = find(Meta.Station == stnName, 1);
    if isempty(idxMeta)
        Skipped_NoMetaMatch_Stations(end+1,1) = stnName; %#ok<AGROW>
        fprintf('--- %s: SKIPPED (not found in station metadata) ---\n\n', stnName);
        continue
    end
    stnIMD = Meta.IMD(idxMeta);
    stnLag = Meta.Ideal_lag(idxMeta);
    slope_val = Meta.Slope_Mean_Deg(idxMeta);
    built_val = Meta.BuiltArea_pct(idxMeta);
    veg_val   = Meta.Vegetation_Trees_pct(idxMeta);

    fprintf('--- %s (IMD=%d, lag=%d days): %d TR-audit events ---\n', stnName, stnIMD, stnLag, nRaw);

    %% Load Crozier API file (station-specific lag) — handles BOTH column layouts
    crozierFile = fullfile(crozierBase, sprintf('%02d_day', stnLag), ...
        sprintf('%d_%02dd_crozier_K0p90.txt', stnIMD, stnLag));
    if ~isfile(crozierFile)
        warning('Crozier API file not found: %s', crozierFile);
        Skipped_BadCrozierFile_Stations(end+1,1) = stnName; %#ok<AGROW>
        continue
    end
    Apix = readmatrix(crozierFile, 'FileType','text');
    nCols = size(Apix,2);

    if nCols == 5
        % Format: idx, Year, Month, Day, API
        Api_Year = Apix(:,2); Api_Month = Apix(:,3); Api_Day = Apix(:,4); Api_Val = Apix(:,5);
    elseif nCols == 4
        % Format: Year, Month, Day, API (no index column)
        Api_Year = Apix(:,1); Api_Month = Apix(:,2); Api_Day = Apix(:,3); Api_Val = Apix(:,4);
    else
        warning('Unexpected column count (%d) in %s — skipping station %s', nCols, crozierFile, stnName);
        Skipped_BadCrozierFile_Stations(end+1,1) = stnName; %#ok<AGROW>
        continue
    end

    %% Load Seff daily time series
    seffFile = fullfile(seffBase, sprintf('%d_SMrz_Seff.txt', stnIMD));
    if ~isfile(seffFile)
        warning('Seff file not found: %s', seffFile);
        continue
    end
    SeffT = readtable(seffFile, 'FileType','text', 'Delimiter','\t', 'VariableNamingRule','preserve');
    SeffDate = datetime(SeffT.year, SeffT.month, SeffT.day);

    %% Classification lookup table for this station (from the 783-row file)
    Lstn = L(L.Station == stnName, :);
    classUsed = false(height(Lstn),1);

    %% Build per-event table: TR(from audit) + API(crozier) + Seff(t-1) + Classification(joined)
    TR   = stnTR_Val;
    API  = nan(nRaw,1);
    Seff = nan(nRaw,1);
    Classification = strings(nRaw,1);
    matched = false(nRaw,1);

    for e = 1:nRaw
        ey = stnTR_Year(e); em = stnTR_Month(e); ed = stnTR_Day(e);

        % API match
        candAPI = find(Api_Year==ey & Api_Month==em & Api_Day==ed, 1, 'first');
        if isempty(candAPI); continue; end
        API(e) = Api_Val(candAPI);

        % Seff match (t-1 day)
        lookupDate = datetime(ey, em, ed) - days(1);
        candSeff = find(SeffDate == lookupDate, 1, 'first');
        if isempty(candSeff); continue; end
        Seff(e) = SeffT.S_eff(candSeff);

        % Classification match (first unused, same date)
        candClass = find(Lstn.Year==ey & Lstn.Month==em & Lstn.Day==ed & ~classUsed, 1, 'first');
        if isempty(candClass)
            Classification(e) = "Unclassified";
            Unmatched_Classification_Count = Unmatched_Classification_Count + 1;
        else
            classUsed(candClass) = true;
            Classification(e) = Lstn.Classification(candClass);
        end

        matched(e) = true;
    end

    TR = TR(matched); API = API(matched); Seff = Seff(matched);
    Classification = Classification(matched);
    Dist_sel_all = stnTR_Dist(matched);
    Year_all = stnTR_Year(matched); Month_all = stnTR_Month(matched); Day_all = stnTR_Day(matched);
    n = sum(matched);

    fprintf('  Matched API+Seff for %d / %d TR-audit events (%d missing classification)\n', ...
        n, nRaw, sum(Classification=="Unclassified"));

    %% Station-level filter: only stations with >15 TOTAL matched events (of the 645)
    if n <= 15
        Skipped_LowCount_Stations(end+1,1) = stnName; %#ok<AGROW>
        fprintf('  Skipped: matched n=%d <= 15\n\n', n);
        continue
    end

    TR(TR <= 0) = 0.1;
    API(API <= 0) = 0.1;
    Seff(Seff < 0) = 0.05;
    Seff(Seff > 1) = 0.95;

    %% Non-exceedance probabilities — CORRECTED denominator (n, not n+1)
    TR_nonexceed_all   = tiedrank(TR)   ./ n;
    API_nonexceed_all  = tiedrank(API)  ./ n;
    Seff_nonexceed_all = tiedrank(Seff) ./ n;

    %% Select LARGE / CATASTROPHIC events
    lsz_clean = lower(strtrim(Classification));
    selectedEventIdx = find( ...
        strcmpi(lsz_clean, "large") | ...
        strcmpi(lsz_clean, "very_large") | ...
        strcmpi(lsz_clean, "catastrophic") | ...
        strcmpi(lsz_clean, "catastropic") | ...
        contains(lsz_clean, "large") );

    if isempty(selectedEventIdx)
        No_Large_Catastrophic_Stations(end+1,1) = stnName; %#ok<AGROW>
        fprintf('  No large/catastrophic events among matched events. Skipped.\n\n');
        continue
    end
    numSel = numel(selectedEventIdx);

    TR_nonexceed_sel   = TR_nonexceed_all(selectedEventIdx);
    API_nonexceed_sel  = API_nonexceed_all(selectedEventIdx);
    Seff_nonexceed_sel = Seff_nonexceed_all(selectedEventIdx);
    TR_exceed_sel   = 1 - TR_nonexceed_sel;
    API_exceed_sel  = 1 - API_nonexceed_sel;
    Seff_exceed_sel = 1 - Seff_nonexceed_sel;

    %% Pairwise + trivariate empirical copulas (built from FULL n)
    R_TR_API   = [TR_nonexceed_all API_nonexceed_all];
    R_TR_Seff  = [TR_nonexceed_all Seff_nonexceed_all];
    R_API_Seff = [API_nonexceed_all Seff_nonexceed_all];
    R_TR_API_Seff = [TR_nonexceed_all API_nonexceed_all Seff_nonexceed_all];

    C_TR_API_all = zeros(n,1); C_TR_Seff_all = zeros(n,1);
    C_API_Seff_all = zeros(n,1); C_TR_API_Seff_all = zeros(n,1);
    for ii = 1:n
        C_TR_API_all(ii)   = Cemp(R_TR_API(ii,:), R_TR_API);
        C_TR_Seff_all(ii)  = Cemp(R_TR_Seff(ii,:), R_TR_Seff);
        C_API_Seff_all(ii) = Cemp(R_API_Seff(ii,:), R_API_Seff);
        C_TR_API_Seff_all(ii) = Cemp(R_TR_API_Seff(ii,:), R_TR_API_Seff);
    end

    C_TR_API   = C_TR_API_all(selectedEventIdx);
    C_TR_Seff  = C_TR_Seff_all(selectedEventIdx);
    C_API_Seff = C_API_Seff_all(selectedEventIdx);
    C_TR_API_Seff = C_TR_API_Seff_all(selectedEventIdx);

    %% Corrected trivariate joint exceedance probability
    JEP_formula = 1 - TR_nonexceed_sel - API_nonexceed_sel - Seff_nonexceed_sel ...
        + C_TR_API + C_TR_Seff + C_API_Seff - C_TR_API_Seff;
    JEP_to_TR_ratio = JEP_formula ./ TR_exceed_sel;
    constraintViolation = JEP_formula > TR_exceed_sel;

    if any(constraintViolation)
        fprintf('  WARNING: %d/%d large events violate JEP <= TR_exceedance\n', sum(constraintViolation), numSel);
    else
        fprintf('  ✓ All %d large events satisfy JEP <= TR_exceedance\n', numSel);
    end

    %% Build output rows for this station (Old_1_minus_C123 columns REMOVED)
    newRow = table( ...
        repmat(stnIMD, numSel, 1), repmat(stnName, numSel, 1), ...
        repmat(slope_val, numSel, 1), repmat(built_val, numSel, 1), repmat(veg_val, numSel, 1), ...
        Year_all(selectedEventIdx), Month_all(selectedEventIdx), Day_all(selectedEventIdx), ...
        Classification(selectedEventIdx), Dist_sel_all(selectedEventIdx), ...
        TR(selectedEventIdx), API(selectedEventIdx), Seff(selectedEventIdx), ...
        TR_nonexceed_sel, API_nonexceed_sel, Seff_nonexceed_sel, ...
        TR_exceed_sel, API_exceed_sel, Seff_exceed_sel, ...
        C_TR_API, C_TR_Seff, C_API_Seff, C_TR_API_Seff, ...
        JEP_formula, JEP_formula*100, ...
        JEP_to_TR_ratio, constraintViolation, ...
        'VariableNames', {'StationID','Station','Slope_deg','BuiltArea_pct','Vegetation_Trees_pct', ...
                          'Year_sel','Month_sel','Day_sel','Size_sel','Dist_sel','TR_sel','API_sel','Seff_sel', ...
                          'TR_nonexceedance','API_nonexceedance','Seff_nonexceedance', ...
                          'TR_exceedance','API_exceedance','Seff_exceedance', ...
                          'C_TR_API','C_TR_Seff','C_API_Seff','C_TR_API_Seff', ...
                          'JEP_formula','JEP_percent', ...
                          'JEP_to_TR_ratio','ConstraintViolation'} );

    Out = [Out; newRow];
    fprintf('  ✓ %d large/catastrophic events output (JEP from full n=%d distribution)\n\n', numSel, n);

    clear stnTRMask stnTR_Year stnTR_Month stnTR_Day stnTR_Val stnTR_Dist nRaw ...
          Apix nCols Api_Year Api_Month Api_Day Api_Val SeffT SeffDate Lstn classUsed ...
          TR API Seff Classification matched Dist_sel_all Year_all Month_all Day_all n ...
          TR_nonexceed_all API_nonexceed_all Seff_nonexceed_all lsz_clean selectedEventIdx numSel ...
          TR_nonexceed_sel API_nonexceed_sel Seff_nonexceed_sel TR_exceed_sel API_exceed_sel Seff_exceed_sel ...
          R_TR_API R_TR_Seff R_API_Seff R_TR_API_Seff C_TR_API_all C_TR_Seff_all C_API_Seff_all C_TR_API_Seff_all ...
          C_TR_API C_TR_Seff C_API_Seff C_TR_API_Seff JEP_formula JEP_to_TR_ratio constraintViolation newRow ...
          crozierFile seffFile
end

%% ============================================================================
% 5) Save output + diagnostics
%% ============================================================================
if height(Out) == 0
    fprintf('\n*** 0 events output. Diagnostics: ***\n');
    fprintf('Skipped (n<=15 after matching): %d\n', numel(Skipped_LowCount_Stations));
    fprintf('Skipped (no station-metadata match): %d\n', numel(Skipped_NoMetaMatch_Stations));
    fprintf('Skipped (bad/missing Crozier file): %d\n', numel(Skipped_BadCrozierFile_Stations));
    fprintf('No large/catastrophic events: %d\n', numel(No_Large_Catastrophic_Stations));
    error('Stopping: 0 output rows.');
end

outFile = fullfile(outPath, 'EmpiricalProb_All_Large_Events_Corrected.xlsx');
writetable(Out, outFile);

fprintf('\n=== SUMMARY ===\n');
fprintf('Total large/catastrophic events output: %d\n', height(Out));
fprintf('Total events where Classification could not be matched (marked "Unclassified"): %d out of 645\n', Unmatched_Classification_Count);
fprintf('JEP values exactly zero: %d (%.1f%%)\n', sum(Out.JEP_formula==0), 100*sum(Out.JEP_formula==0)/height(Out));
fprintf('Constraint violations: %d (%.1f%%)\n', sum(Out.ConstraintViolation), 100*sum(Out.ConstraintViolation)/height(Out));
fprintf('Output file: %s\n\n', outFile);

if ~isempty(Skipped_LowCount_Stations)
    disp('Stations skipped (matched n <= 15):'); disp(Skipped_LowCount_Stations);
end
if ~isempty(Skipped_NoMetaMatch_Stations)
    disp('Stations skipped (no metadata match):'); disp(Skipped_NoMetaMatch_Stations);
end
if ~isempty(Skipped_BadCrozierFile_Stations)
    disp('Stations skipped (bad/missing Crozier file):'); disp(Skipped_BadCrozierFile_Stations);
end
if ~isempty(No_Large_Catastrophic_Stations)
    disp('Stations with no large/catastrophic events:'); disp(No_Large_Catastrophic_Stations);
end

fprintf('\nDone!\n');

