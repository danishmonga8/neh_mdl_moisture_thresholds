%% ========================================================================
% Step8_ED_Linear_vs_PowerLaw_AllStations.m
%
% REVIEWER 2 COMMENT 8
%
% Fit BOTH ED threshold formulations for ALL stations:
%
%   1) Linear quantile regression
%
%          E_tau(D) = a_tau + b_tau*D
%
%   2) Log-log power-law quantile regression
%
%          log(E_tau) = c_tau + beta_tau*log(D)
%
%      therefore:
%
%          E_tau(D) = alpha_tau * D^(beta_tau)
%
%          alpha_tau = exp(c_tau)
%
%
% IMPORTANT
% -------------------------------------------------------------------------
% - ALL stations are retained irrespective of sample size.
% - No n > 15 filtering is done here.
% - Sample counts are reported for later filtering / validation.
% - Quantiles are fitted ONE AT A TIME.
%
% WHY ONE AT A TIME?
% -------------------------------------------------------------------------
% ncquantreg uses fmincon when multiple quantiles are supplied together.
% fmincon requires Optimization Toolbox.
%
% When only one tau is supplied, ncquantreg uses fminsearch instead.
% Therefore this implementation does NOT require fmincon.
%
%
% INPUT
% -------------------------------------------------------------------------
% xxxxx_triggering_output.xlsx
%
% Sheet "ap":
%      column 1 = rainfall amount E
%      column 2 = duration D
%
% Sheet "trigging":
%      column 1 = triggering rainfall amount E
%      column 2 = triggering-event duration D
%
%
% OUTPUT
% -------------------------------------------------------------------------
% ONE Excel workbook with TWO sheets:
%
%   Linear_quantile
%   PowerLaw_loglog
%
%
% For every tau:
%
%   Linear:
%       E3_tau = a_tau + b_tau*3
%
%   Power law:
%       E3_tau = alpha_tau * 3^(beta_tau)
%
%
% Tau = 0.20 equation is also explicitly reported.
%
% ========================================================================

clc;
clear;
close all;


%% ========================================================================
% 1. PATHS
%% ========================================================================

input_folder = ...
    fullfile(neh_root(),'step8_ed_threshold','ed_threshold_updated','Output_Triggering_Events');


station_meta_path = ...
    fullfile(neh_root(),'all_stations_neh.xlsx');


output_file = ...
    fullfile(neh_root(),'step8_ed_threshold','ED_Linear_vs_PowerLaw_AllStations.xlsx');


%% ========================================================================
% 2. ncquantreg.m LOCATION
%% ========================================================================

ncquantreg_folder = ...
    fullfile(neh_root(),'2_new_stations_neh','9_ideal_lag');


addpath(ncquantreg_folder);


%% ========================================================================
% 3. CHECK REQUIRED FILES / FOLDERS
%% ========================================================================

if ~exist(input_folder,'dir')

    error( ...
        'ED input folder not found:\n%s', ...
        input_folder);

end


if ~isfile(station_meta_path)

    error( ...
        'Station metadata file not found:\n%s', ...
        station_meta_path);

end


if exist('ncquantreg','file') ~= 2

    error( ...
        ['ncquantreg.m was not found.' newline ...
         'Checked MATLAB path after adding:' newline ...
         '%s'], ...
        ncquantreg_folder);

end


%% ========================================================================
% 4. READ STATION METADATA
%% ========================================================================

meta_data = readtable( ...
    station_meta_path, ...
    'VariableNamingRule','preserve');


nStations = ...
    height(meta_data);


%% ========================================================================
% 5. STANDARDIZE STATION IDs
%% ========================================================================

if isnumeric(meta_data.IMD)

    station_ids = ...
        string(compose('%.0f',meta_data.IMD));

else

    station_ids = ...
        strip(string(meta_data.IMD));


    station_ids = ...
        regexprep( ...
        station_ids, ...
        '\.0$', ...
        '');

end


%% ========================================================================
% 6. STATION NAMES
%% ========================================================================

station_names = ...
    string(meta_data.Station);


%% ========================================================================
% 7. LATITUDE / LONGITUDE
%% ========================================================================

station_lat = ...
    double(meta_data.Lat);


station_lon = ...
    double(meta_data.Long);


%% ========================================================================
% 8. QUANTILES
%
% CURRENT RANGE:
%
%       0.05, 0.06, 0.07, ... , 0.98
%
% This is a 1-percentile interval.
%
% If later you want exactly 2-percentile intervals:
%
%       taus = 0.05:0.02:0.97;
%% ========================================================================

taus = ...
    0.05 : 0.01 : 0.98;


taus = ...
    round(taus,2);


nTau = ...
    numel(taus);


%% ========================================================================
% 9. MAIN OPERATING QUANTILE
%
% Reviewer specifically refers to the current tau = 0.20 threshold.
%% ========================================================================

tau_eqn = ...
    0.20;


idx20 = find( ...
    abs(taus - tau_eqn) < 1e-12, ...
    1);


if isempty(idx20)

    error('tau = 0.20 is not present in taus.');

end


%% ========================================================================
% 10. DURATION AT WHICH THRESHOLD IS REPORTED
%
% Same as original workflow:
%
%       D = 3 days
%% ========================================================================

D_eval = ...
    3;


%% ========================================================================
% 11. PREALLOCATE RESULTS
%
% ALL stations are retained.
%% ========================================================================

N_samples = ...
    zeros(nStations,1);


N_unique_duration = ...
    zeros(nStations,1);


Status = ...
    strings(nStations,1);


%% ------------------------------------------------------------------------
% Linear results
%% ------------------------------------------------------------------------

Linear_E3 = ...
    nan(nStations,nTau);


Linear_A = ...
    nan(nStations,nTau);


Linear_B = ...
    nan(nStations,nTau);


Linear_Eqn_P20 = ...
    strings(nStations,1);


%% ------------------------------------------------------------------------
% Power-law results
%% ------------------------------------------------------------------------

Power_E3 = ...
    nan(nStations,nTau);


Power_Alpha = ...
    nan(nStations,nTau);


Power_Beta = ...
    nan(nStations,nTau);


Power_Eqn_P20 = ...
    strings(nStations,1);


%% ========================================================================
% 12. DISPLAY SETTINGS
%% ========================================================================

fprintf('\n');
fprintf('=============================================================\n');
fprintf(' ED LINEAR + POWER-LAW QUANTILE THRESHOLDS\n');
fprintf('=============================================================\n');

fprintf( ...
    'Stations in metadata : %d\n', ...
    nStations);


fprintf( ...
    'Tau range            : %.2f to %.2f\n', ...
    min(taus), ...
    max(taus));


fprintf( ...
    'Number of taus       : %d\n', ...
    nTau);


fprintf( ...
    'Threshold duration   : %d days\n', ...
    D_eval);


fprintf('No sample-size filtering is applied.\n');
fprintf('=============================================================\n\n');


%% ========================================================================
% 13. MAIN STATION LOOP
%% ========================================================================

for i = 1:nStations


    id = ...
        station_ids(i);


    station = ...
        station_names(i);


    %% --------------------------------------------------------------------
    % Expected input filename
    %% --------------------------------------------------------------------

    file_name = sprintf( ...
        '%s_triggering_output.xlsx', ...
        char(id));


    file_path = fullfile( ...
        input_folder, ...
        file_name);


    fprintf( ...
        '%-18s | %-12s | ', ...
        station, ...
        id);


    %% ====================================================================
    % 13A. FILE CHECK
    %
    % Station is NOT deleted from output if file is missing.
    %% ====================================================================

    if ~isfile(file_path)


        Status(i) = ...
            "Input file missing";


        fprintf('INPUT FILE MISSING\n');


        continue

    end


    try


        %% =================================================================
        % 13B. READ ANTECEDENT / AP EVENTS
        %% =================================================================

        data_ap = readmatrix( ...
            file_path, ...
            'Sheet','ap');


        %% =================================================================
        % 13C. READ TRIGGERING EVENTS
        %% =================================================================

        data_trig = readmatrix( ...
            file_path, ...
            'Sheet','trigging');


        %% ----------------------------------------------------------------
        % Protect against empty sheets
        %% ----------------------------------------------------------------

        if isempty(data_ap)

            data_ap = ...
                zeros(0,2);

        end


        if isempty(data_trig)

            data_trig = ...
                zeros(0,2);

        end


        %% ----------------------------------------------------------------
        % Confirm two columns
        %% ----------------------------------------------------------------

        if size(data_ap,2) < 2 && ~isempty(data_ap)

            Status(i) = ...
                "Invalid ap sheet";


            fprintf('INVALID AP SHEET\n');


            continue

        end


        if size(data_trig,2) < 2 && ~isempty(data_trig)

            Status(i) = ...
                "Invalid triggering sheet";


            fprintf('INVALID TRIGGERING SHEET\n');


            continue

        end


        %% =================================================================
        % 13D. COMBINE AP + TRIGGERING
        %
        % EXACT SAME INPUT CONCEPT AS ORIGINAL ED CODE.
        %% =================================================================

        data_combined = [ ...
            data_ap(:,1:2); ...
            data_trig(:,1:2)];


        %% =================================================================
        % 13E. COMMON VALID-DATA FILTER
        %
        % E > 0 and D > 0 are necessary for log-log power-law fitting.
        %
        % The SAME observations are used for linear and power-law models
        % so that later model comparisons are fair.
        %% =================================================================

        valid = ...
            isfinite(data_combined(:,1)) & ...
            isfinite(data_combined(:,2)) & ...
            data_combined(:,1) > 0 & ...
            data_combined(:,2) > 0;


        data_combined = ...
            data_combined(valid,:);


        %% =================================================================
        % 13F. E AND D
        %% =================================================================

        E = ...
            double(data_combined(:,1));


        D = ...
            double(data_combined(:,2));


        N_samples(i) = ...
            numel(E);


        N_unique_duration(i) = ...
            numel(unique(D));


        %% ----------------------------------------------------------------
        % Keep small-sample sites.
        %
        % Only completely unusable stations are flagged.
        %% ----------------------------------------------------------------

        if isempty(E)


            Status(i) = ...
                "No valid positive ED observations";


            fprintf('n = 0 | NO VALID DATA\n');


            continue

        end


        if numel(E) < 2 || ...
                numel(unique(D)) < 2


            Status(i) = ...
                "Insufficient variation for regression";


            fprintf( ...
                'n = %d | INSUFFICIENT DURATION VARIATION\n', ...
                numel(E));


            continue

        end


        fprintf( ...
            'n = %3d | ', ...
            N_samples(i));


        %% =================================================================
        % 14. FIT EVERY TAU SEPARATELY
        %
        % CRITICAL FIX:
        %
        % We DO NOT send the entire taus vector to ncquantreg.
        %
        % Single-tau ncquantreg uses fminsearch.
        % Therefore fmincon is NOT called.
        %% =================================================================

        for k = 1:nTau


            tau = ...
                taus(k);


            %% =============================================================
            % 14A. LINEAR QUANTILE ED
            %
            % Q_tau(E | D):
            %
            %       E_tau(D) = a_tau + b_tau*D
            %% =============================================================

            [bLinear,~] = ncquantreg( ...
                D, ...
                E, ...
                1, ...
                tau);


            a_tau = ...
                bLinear(1);


            b_tau = ...
                bLinear(2);


            Linear_A(i,k) = ...
                a_tau;


            Linear_B(i,k) = ...
                b_tau;


            %% -------------------------------------------------------------
            % 3-day linear threshold
            %
            %       E3 = a_tau + b_tau*3
            %% -------------------------------------------------------------

            Linear_E3(i,k) = ...
                a_tau + ...
                b_tau * D_eval;


            %% =============================================================
            % 14B. LOG-LOG POWER-LAW QUANTILE ED
            %
            % Fit:
            %
            %       log(E_tau) =
            %           c_tau + beta_tau*log(D)
            %
            % Back-transform:
            %
            %       alpha_tau = exp(c_tau)
            %
            % Therefore:
            %
            %       E_tau(D) =
            %           alpha_tau * D^(beta_tau)
            %% =============================================================

            logD = ...
                log(D);


            logE = ...
                log(E);


            [bPower,~] = ncquantreg( ...
                logD, ...
                logE, ...
                1, ...
                tau);


            c_tau = ...
                bPower(1);


            beta_tau = ...
                bPower(2);


            alpha_tau = ...
                exp(c_tau);


            Power_Alpha(i,k) = ...
                alpha_tau;


            Power_Beta(i,k) = ...
                beta_tau;


            %% -------------------------------------------------------------
            % 3-day power-law threshold
            %
            %       E3 = alpha_tau * 3^(beta_tau)
            %% -------------------------------------------------------------

            Power_E3(i,k) = ...
                alpha_tau * ...
                (D_eval ^ beta_tau);


        end


        %% =================================================================
        % 15. TAU = 0.20 EQUATIONS
        %% =================================================================

        a20 = ...
            Linear_A(i,idx20);


        b20 = ...
            Linear_B(i,idx20);


        alpha20 = ...
            Power_Alpha(i,idx20);


        beta20 = ...
            Power_Beta(i,idx20);


        %% ----------------------------------------------------------------
        % Linear equation
        %% ----------------------------------------------------------------

        Linear_Eqn_P20(i) = sprintf( ...
            'E = %.4f %+.4f D', ...
            a20, ...
            b20);


        %% ----------------------------------------------------------------
        % Power-law equation
        %% ----------------------------------------------------------------

        Power_Eqn_P20(i) = sprintf( ...
            'E = %.4f D^(%.4f)', ...
            alpha20, ...
            beta20);


        Status(i) = ...
            "OK";


        fprintf( ...
            'Linear E3(P20)=%.2f | Power E3(P20)=%.2f\n', ...
            Linear_E3(i,idx20), ...
            Power_E3(i,idx20));


    catch ME


        Status(i) = ...
            "Processing error: " + string(ME.message);


        fprintf( ...
            'ERROR: %s\n', ...
            ME.message);


    end


end


%% ========================================================================
% 16. QUANTILE COLUMN NAMES
%% ========================================================================

tauLabels = ...
    strings(1,nTau);


for k = 1:nTau


    tauLabels(k) = sprintf( ...
        'E3_P%02d', ...
        round(100*taus(k)));


end


tauLabels = ...
    matlab.lang.makeValidName(tauLabels);


%% ========================================================================
% 17. LINEAR OUTPUT TABLE
%% ========================================================================

LinearTable = table( ...
    station_names, ...
    station_ids, ...
    station_lat, ...
    station_lon, ...
    N_samples, ...
    N_unique_duration, ...
    Status, ...
    'VariableNames',{ ...
    'Station', ...
    'IMD_ID', ...
    'Lat', ...
    'Long', ...
    'N_samples', ...
    'N_unique_duration', ...
    'Status'});


%% ------------------------------------------------------------------------
% Add E3 at every tau
%% ------------------------------------------------------------------------

for k = 1:nTau


    LinearTable.(tauLabels{k}) = ...
        Linear_E3(:,k);


end


%% ------------------------------------------------------------------------
% Add tau=0.20 model details
%% ------------------------------------------------------------------------

LinearTable.Intercept_P20 = ...
    Linear_A(:,idx20);


LinearTable.Slope_P20 = ...
    Linear_B(:,idx20);


LinearTable.E3_P20_check = ...
    Linear_E3(:,idx20);


LinearTable.Equation_P20 = ...
    Linear_Eqn_P20;


%% ========================================================================
% 18. POWER-LAW OUTPUT TABLE
%% ========================================================================

PowerTable = table( ...
    station_names, ...
    station_ids, ...
    station_lat, ...
    station_lon, ...
    N_samples, ...
    N_unique_duration, ...
    Status, ...
    'VariableNames',{ ...
    'Station', ...
    'IMD_ID', ...
    'Lat', ...
    'Long', ...
    'N_samples', ...
    'N_unique_duration', ...
    'Status'});


%% ------------------------------------------------------------------------
% Add E3 at every tau
%% ------------------------------------------------------------------------

for k = 1:nTau


    PowerTable.(tauLabels{k}) = ...
        Power_E3(:,k);


end


%% ------------------------------------------------------------------------
% Add tau=0.20 model details
%% ------------------------------------------------------------------------

PowerTable.Alpha_P20 = ...
    Power_Alpha(:,idx20);


PowerTable.Beta_P20 = ...
    Power_Beta(:,idx20);


PowerTable.E3_P20_check = ...
    Power_E3(:,idx20);


PowerTable.Equation_P20 = ...
    Power_Eqn_P20;


%% ========================================================================
% 19. WRITE EXCEL WORKBOOK
%
% EXACTLY TWO SHEETS.
%% ========================================================================

if isfile(output_file)

    delete(output_file);

end


writetable( ...
    LinearTable, ...
    output_file, ...
    'Sheet','Linear_quantile');


writetable( ...
    PowerTable, ...
    output_file, ...
    'Sheet','PowerLaw_loglog');


%% ========================================================================
% 20. FINAL SUMMARY
%% ========================================================================

fprintf('\n');
fprintf('=============================================================\n');
fprintf(' ED THRESHOLD CALCULATION COMPLETE\n');
fprintf('=============================================================\n');


fprintf( ...
    'Total stations retained : %d\n', ...
    nStations);


fprintf( ...
    'Stations successfully fit: %d\n', ...
    sum(Status == "OK"));


fprintf( ...
    'Stations not fit        : %d\n', ...
    sum(Status ~= "OK"));


fprintf('\nWorkbook:\n%s\n', ...
    output_file);


fprintf('\nSheet 1: Linear_quantile\n');

fprintf( ...
    'E_tau(D) = a_tau + b_tau D\n');


fprintf('\nSheet 2: PowerLaw_loglog\n');

fprintf( ...
    'E_tau(D) = alpha_tau D^(beta_tau)\n');


fprintf('\n');
fprintf('NO sample-size screening was applied.\n');
fprintf('All stations remain in the workbook.\n');

fprintf('=============================================================\n');