clear; clc; close all;

basePath  = 'C:\lews_2022-2024\3_new_stations_neh_new\figures_neh_soil_moisture\empirical_probability';
eventFile = fullfile(basePath, 'AllEvents_COOLR_UGLC.xlsx');
metaFile  = 'C:\lews_2022-2024\3_new_stations_neh_new\all_stations_neh.xlsx';

addpath(basePath);

%% ---------------------------
% 1) Read metadata
%% ---------------------------
M = readtable(metaFile, 'VariableNamingRule', 'modify');

StationID     = M.IMD;
Station       = string(M.Station);
Slope_deg     = M.Slope_Mean_Deg;
BuiltArea_pct = M.BuiltArea_pct;
Vegetation_Trees_pct = M.Vegetation_Trees_pct;

meta = table(StationID, Station, Slope_deg, BuiltArea_pct, Vegetation_Trees_pct);

%% ---------------------------
% 2) Get all sheet names
%% ---------------------------
[~, sheetNames] = xlsfinfo(eventFile);
sheetIDs = str2double(sheetNames);

use_ids = intersect(meta.StationID, sheetIDs);

%% ---------------------------
% 3) Loop over stations
%% ---------------------------
Out = table();

for k = 1:numel(use_ids)
    
    stn = use_ids(k);
    T = readtable(eventFile, 'Sheet', char(string(stn)), 'VariableNamingRule', 'modify');
    
    % required columns assumed consistent
    TR   = T.TR;
    API  = T.API;
    Seff = T.Seff;
    lsz  = string(T.landslide_size);
    dist = T.dist_km;
    yr   = T.Event_Year;
    
    n = height(T);
    
    %% -------------------------------------------------
    % Pseudo-observations / non-exceedance probabilities
    % These replace old U1, U2, U3 notation
    %% -------------------------------------------------
    TR_nonexceed_all   = tiedrank(TR)   ./ (n + 1);
    API_nonexceed_all  = tiedrank(API)  ./ (n + 1);
    Seff_nonexceed_all = tiedrank(Seff) ./ (n + 1);
    
    %% -------------------------------------------------
    % Trivariate empirical copula input
    %% -------------------------------------------------
    R3 = [TR_nonexceed_all API_nonexceed_all Seff_nonexceed_all];
    
    %% -------------------------------------------------
    % Trivariate empirical copula CDF for all rows
    %% -------------------------------------------------
    Ce = zeros(n,1);
    for i = 1:n
        Ce(i) = Cemp(R3(i,:), R3);
    end
    
    %% ---------------------------
    % Landslide size ranking
    %% ---------------------------
    sizeScore = zeros(n,1);
    sizeScore(strcmpi(strtrim(lsz), 'small'))  = 1;
    sizeScore(strcmpi(strtrim(lsz), 'medium')) = 2;
    sizeScore(strcmpi(strtrim(lsz), 'large'))  = 3;
    
    maxScore = max(sizeScore);
    cand = find(sizeScore == maxScore);
    
    if numel(cand) > 1
        [~, j] = min(dist(cand));
        selectedEventIdx = cand(j);
    else
        selectedEventIdx = cand;
    end
    
    %% -------------------------------------------------
    % Selected-event non-exceedance probabilities
    %% -------------------------------------------------
    TR_nonexceed_sel   = TR_nonexceed_all(selectedEventIdx);
    API_nonexceed_sel  = API_nonexceed_all(selectedEventIdx);
    Seff_nonexceed_sel = Seff_nonexceed_all(selectedEventIdx);
    
    %% -------------------------------------------------
    % Selected-event exceedance probabilities
    %% -------------------------------------------------
    TR_exceed_sel   = 1 - TR_nonexceed_sel;
    API_exceed_sel  = 1 - API_nonexceed_sel;
    Seff_exceed_sel = 1 - Seff_nonexceed_sel;
    
    %% -------------------------------------------------
    % Pairwise empirical copula terms: row-wise calculation
    %% -------------------------------------------------

    R_TR_API   = [TR_nonexceed_all API_nonexceed_all];
    R_TR_Seff  = [TR_nonexceed_all Seff_nonexceed_all];
    R_API_Seff = [API_nonexceed_all Seff_nonexceed_all];

    C_TR_API_all   = zeros(n,1);
    C_TR_Seff_all  = zeros(n,1);
    C_API_Seff_all = zeros(n,1);

    for ii = 1:n
        C_TR_API_all(ii)   = Cemp(R_TR_API(ii,:), R_TR_API);
        C_TR_Seff_all(ii)  = Cemp(R_TR_Seff(ii,:), R_TR_Seff);
        C_API_Seff_all(ii) = Cemp(R_API_Seff(ii,:), R_API_Seff);
    end

    C_TR_API   = C_TR_API_all(selectedEventIdx);
    C_TR_Seff  = C_TR_Seff_all(selectedEventIdx);
    C_API_Seff = C_API_Seff_all(selectedEventIdx);

    %% -------------------------------------------------
    % Trivariate empirical copula term: row-wise calculation
    %% -------------------------------------------------

    R_TR_API_Seff = [TR_nonexceed_all API_nonexceed_all Seff_nonexceed_all];

    C_TR_API_Seff_all = zeros(n,1);

    for ii = 1:n
        C_TR_API_Seff_all(ii) = Cemp(R_TR_API_Seff(ii,:), R_TR_API_Seff);
    end

    C_TR_API_Seff = C_TR_API_Seff_all(selectedEventIdx);

    %% -------------------------------------------------
    % Correct trivariate joint exceedance probability
    %
    % JEP = P(TR > tr0, API > api0, Seff > seff0)
    %
    % JEP = 1 - uTR - uAPI - uSeff
    %       + C(TR,API) + C(TR,Seff) + C(API,Seff)
    %       - C(TR,API,Seff)
    %% -------------------------------------------------
    JEP_formula = 1 ...
        - TR_nonexceed_sel ...
        - API_nonexceed_sel ...
        - Seff_nonexceed_sel ...
        + C_TR_API ...
        + C_TR_Seff ...
        + C_API_Seff ...
        - C_TR_API_Seff;

    %% -------------------------------------------------
    % Old complement value, only for comparison
    %% -------------------------------------------------
    Old_1_minus_C123 = 1 - C_TR_API_Seff;

    %% -------------------------------------------------
    % Ratio relative to TR exceedance
    %% -------------------------------------------------
    JEP_to_TR_ratio = JEP_formula ./ TR_exceed_sel;
    %% ---------------------------
    % Metadata row
    %% ---------------------------
    idx = meta.StationID == stn;
    
    newRow = table( ...
        stn, ...
        meta.Station(idx), ...
        meta.Slope_deg(idx), ...
        meta.BuiltArea_pct(idx), ...
        meta.Vegetation_Trees_pct(idx), ...
        yr(selectedEventIdx), ...
        string(lsz(selectedEventIdx)), ...
        dist(selectedEventIdx), ...
        TR(selectedEventIdx), ...
        API(selectedEventIdx), ...
        Seff(selectedEventIdx), ...
        TR_nonexceed_sel, ...
        API_nonexceed_sel, ...
        Seff_nonexceed_sel, ...
        TR_exceed_sel, ...
        API_exceed_sel, ...
        Seff_exceed_sel, ...
        C_TR_API, ...
        C_TR_Seff, ...
        C_API_Seff, ...
        C_TR_API_Seff, ...
        JEP_formula, ...
        JEP_formula*100, ...
        Old_1_minus_C123, ...
        Old_1_minus_C123*100, ...
        JEP_to_TR_ratio, ...
        'VariableNames', {'StationID','Station','Slope_deg','BuiltArea_pct','Vegetation_Trees_pct', ...
                          'Year_sel','Size_sel','Dist_sel','TR_sel','API_sel','Seff_sel', ...
                          'TR_nonexceedance','API_nonexceedance','Seff_nonexceedance', ...
                          'TR_exceedance','API_exceedance','Seff_exceedance', ...
                          'C_TR_API','C_TR_Seff','C_API_Seff','C_TR_API_Seff', ...
                          'JEP_formula','JEP_percent', ...
                          'Old_1_minus_C123','Old_1_minus_C123_percent', ...
                          'JEP_to_TR_ratio'} ...
        );
    
    Out = [Out; newRow];
    
    % clear temporary variables from current loop
    clear stn T TR API Seff lsz dist yr n ...
          TR_nonexceed_all API_nonexceed_all Seff_nonexceed_all ...
          TR_nonexceed_sel API_nonexceed_sel Seff_nonexceed_sel ...
          TR_exceed_sel API_exceed_sel Seff_exceed_sel ...
          R3 Ce i sizeScore maxScore cand j selectedEventIdx idx ...
          C_TR_API C_TR_Seff C_API_Seff C_TR_API_Seff ...
          JEP_formula Old_1_minus_C123 JEP_to_TR_ratio newRow
end

%% ---------------------------
% 4) Save output
%% ---------------------------
outFile = fullfile(basePath, 'EmpiricalProb_SelectedEvent_Stations_all_updated.xlsx');
writetable(Out, outFile);

disp('Done: corrected JEP formula and exceedance/non-exceedance columns saved.');

% Pairwise Kendall tau using RAW values