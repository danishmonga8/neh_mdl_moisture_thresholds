%% ========================================================================
% Step10_ED_CrossValidation_Linear_vs_PowerLaw.m
%
% PURPOSE
% -------------------------------------------------------------------------
% Compare the predictive performance of:
%
%   1. Linear quantile ED model
%
%          E_tau(D) = a_tau + b_tau*D
%
%   2. Power-law quantile ED model
%
%          E_tau(D) = alpha_tau * D^(beta_tau)
%
%
% MODEL COMPARISON
% -------------------------------------------------------------------------
% - SITE-WISE
% - Only stations having >15 valid triggering/landslide events
% - tau = 0.20
% - 5-fold cross-validation
% - SAME folds used for both models
%
%
% PERFORMANCE METRICS
% -------------------------------------------------------------------------
%
% 1. Cross-validated RMSE
%
%       RMSE = sqrt(mean((E_observed - E_predicted).^2))
%
%
% 2. Cross-validated pinball loss
%
%       rho_tau(r) = r*(tau - I(r < 0))
%
% where
%
%       r = E_observed - E_predicted
%
%
% 3. Quantile coverage
%
%       fraction of observations with E <= predicted threshold
%
% For a tau = 0.20 model, ideal coverage is approximately 0.20.
%
%
% OUTPUTS
% -------------------------------------------------------------------------
% Excel workbook:
%
%   Sheet 1 : Station_CV_Summary
%   Sheet 2 : Foldwise_CV
%   Sheet 3 : Regional_Summary
%
%
% Figures:
%
%   1. CV_RMSE_Linear_vs_PowerLaw_GT15.png
%   2. CV_Pinball_Linear_vs_PowerLaw_GT15.png
%
% ========================================================================

clc;
clear;
close all;


%% ========================================================================
% 1. PATHS
%% ========================================================================

ROOT = ...
    fullfile(neh_root());


STEP8_ROOT = fullfile( ...
    ROOT, ...
    'revision_round1', ...
    'step8_ed_threshold');


%% ------------------------------------------------------------------------
% Station-wise ED workbooks
%% ------------------------------------------------------------------------

INPUT_FOLDER = fullfile( ...
    STEP8_ROOT, ...
    'ed_threshold_updated', ...
    'Output_Triggering_Events');


%% ------------------------------------------------------------------------
% Existing linear + power-law summary workbook
%% ------------------------------------------------------------------------

SUMMARY_XLSX = fullfile( ...
    STEP8_ROOT, ...
    'ED_Linear_vs_PowerLaw_AllStations.xlsx');


%% ------------------------------------------------------------------------
% Output directory
%% ------------------------------------------------------------------------

OUTPUT_FOLDER = fullfile( ...
    STEP8_ROOT, ...
    'CV_Model_Comparison_GT15');


if ~exist(OUTPUT_FOLDER,'dir')

    mkdir(OUTPUT_FOLDER);

end


%% ------------------------------------------------------------------------
% ncquantreg.m
%% ------------------------------------------------------------------------

NCQUANTREG_FOLDER = ...
    fullfile(neh_root(),'2_new_stations_neh','9_ideal_lag');


addpath(NCQUANTREG_FOLDER);


%% ========================================================================
% 2. CHECK INPUTS
%% ========================================================================

if ~exist(INPUT_FOLDER,'dir')

    error( ...
        'ED input folder not found:\n%s', ...
        INPUT_FOLDER);

end


if ~isfile(SUMMARY_XLSX)

    error( ...
        'Summary workbook not found:\n%s', ...
        SUMMARY_XLSX);

end


if exist('ncquantreg','file') ~= 2

    error( ...
        ['ncquantreg.m not found.' newline ...
         'Check path:' newline ...
         '%s'], ...
        NCQUANTREG_FOLDER);

end


%% ========================================================================
% 3. ANALYSIS SETTINGS
%% ========================================================================

%% ------------------------------------------------------------------------
% Reviewer operating quantile
%% ------------------------------------------------------------------------

TAU = ...
    0.20;


%% ------------------------------------------------------------------------
% Advisor's sample-size screening rule
%
% Site must have MORE THAN 15 triggering/landslide events.
%% ------------------------------------------------------------------------

MIN_TRIGGERING_EVENTS = ...
    15;


%% ------------------------------------------------------------------------
% Cross-validation
%% ------------------------------------------------------------------------

K_FOLDS = ...
    5;


%% ------------------------------------------------------------------------
% Fixed random seed for reproducibility
%% ------------------------------------------------------------------------

RANDOM_SEED = ...
    42;


rng(RANDOM_SEED);


%% ========================================================================
% 4. READ STATION INFORMATION
%% ========================================================================

Tsummary = readtable( ...
    SUMMARY_XLSX, ...
    'Sheet','Linear_quantile', ...
    'VariableNamingRule','preserve');


nStations = ...
    height(Tsummary);


%% ========================================================================
% 5. STANDARDIZE IMD IDs
%% ========================================================================

if isnumeric(Tsummary.IMD_ID)

    stationIDs = ...
        string(compose('%.0f',Tsummary.IMD_ID));

else

    stationIDs = ...
        strip(string(Tsummary.IMD_ID));


    stationIDs = ...
        regexprep( ...
        stationIDs, ...
        '\.0$', ...
        '');

end


stationNames = ...
    string(Tsummary.Station);


%% ========================================================================
% 6. PREALLOCATE SITE-WISE OUTPUTS
%% ========================================================================

N_AP = ...
    nan(nStations,1);


N_TRIGGERING = ...
    nan(nStations,1);


N_TOTAL = ...
    nan(nStations,1);


Included = ...
    false(nStations,1);


CV_RMSE_Linear = ...
    nan(nStations,1);


CV_RMSE_Power = ...
    nan(nStations,1);


CV_Pinball_Linear = ...
    nan(nStations,1);


CV_Pinball_Power = ...
    nan(nStations,1);


Coverage_Linear = ...
    nan(nStations,1);


Coverage_Power = ...
    nan(nStations,1);


NegativePred_Linear = ...
    nan(nStations,1);


Preferred_RMSE = ...
    strings(nStations,1);


Preferred_Pinball = ...
    strings(nStations,1);


Status = ...
    strings(nStations,1);


%% ========================================================================
% 7. FOLD-WISE OUTPUT CONTAINER
%% ========================================================================

foldStation = ...
    strings(0,1);


foldIMD = ...
    strings(0,1);


foldNumber = ...
    zeros(0,1);


foldNTest = ...
    zeros(0,1);


foldRMSELinear = ...
    zeros(0,1);


foldRMSEPower = ...
    zeros(0,1);


foldPinballLinear = ...
    zeros(0,1);


foldPinballPower = ...
    zeros(0,1);


%% ========================================================================
% 8. DISPLAY HEADER
%% ========================================================================

fprintf('\n');
fprintf('=============================================================\n');
fprintf(' ED MODEL CROSS-VALIDATION\n');
fprintf('=============================================================\n');

fprintf( ...
    'Operating quantile        : %.2f\n', ...
    TAU);


fprintf( ...
    'Cross-validation folds    : %d\n', ...
    K_FOLDS);


fprintf( ...
    'Site inclusion criterion  : > %d triggering events\n', ...
    MIN_TRIGGERING_EVENTS);


fprintf('=============================================================\n\n');


%% ========================================================================
% 9. LOOP THROUGH ALL STATIONS
%% ========================================================================

for i = 1:nStations


    station = ...
        stationNames(i);


    id = ...
        stationIDs(i);


    %% --------------------------------------------------------------------
    % Input workbook
    %% --------------------------------------------------------------------

    filePath = fullfile( ...
        INPUT_FOLDER, ...
        sprintf( ...
        '%s_triggering_output.xlsx', ...
        char(id)));


    fprintf( ...
        '%-22s | %-12s | ', ...
        station, ...
        id);


    %% ====================================================================
    % FILE CHECK
    %% ====================================================================

    if ~isfile(filePath)


        Status(i) = ...
            "Input file missing";


        fprintf('FILE MISSING\n');


        continue

    end


    try


        %% =================================================================
        % 10. READ ANTECEDENT / AP EVENTS
        %% =================================================================

        AP = readmatrix( ...
            filePath, ...
            'Sheet','ap');


        %% =================================================================
        % 11. READ TRIGGERING EVENTS
        %% =================================================================

        TRIG = readmatrix( ...
            filePath, ...
            'Sheet','trigging');


        %% ----------------------------------------------------------------
        % Empty sheet protection
        %% ----------------------------------------------------------------

        if isempty(AP)

            AP = ...
                zeros(0,2);

        end


        if isempty(TRIG)

            TRIG = ...
                zeros(0,2);

        end


        %% ----------------------------------------------------------------
        % Require two columns:
        %
        % column 1 = E
        % column 2 = D
        %% ----------------------------------------------------------------

        if size(AP,2) < 2

            AP = ...
                zeros(0,2);

        else

            AP = ...
                AP(:,1:2);

        end


        if size(TRIG,2) < 2

            TRIG = ...
                zeros(0,2);

        else

            TRIG = ...
                TRIG(:,1:2);

        end


        %% =================================================================
        % 12. REMOVE INVALID OBSERVATIONS
        %
        % Power-law model requires:
        %
        %       E > 0
        %       D > 0
        %
        % SAME observations are used for both models.
        %% =================================================================

        validAP = ...
            isfinite(AP(:,1)) & ...
            isfinite(AP(:,2)) & ...
            AP(:,1) > 0 & ...
            AP(:,2) > 0;


        AP = ...
            AP(validAP,:);


        validTRIG = ...
            isfinite(TRIG(:,1)) & ...
            isfinite(TRIG(:,2)) & ...
            TRIG(:,1) > 0 & ...
            TRIG(:,2) > 0;


        TRIG = ...
            TRIG(validTRIG,:);


        %% =================================================================
        % 13. SAMPLE COUNTS
        %% =================================================================

        N_AP(i) = ...
            size(AP,1);


        N_TRIGGERING(i) = ...
            size(TRIG,1);


        %% ----------------------------------------------------------------
        % IMPORTANT:
        %
        % Station inclusion is determined by triggering/landslide count.
        %% ----------------------------------------------------------------

        if N_TRIGGERING(i) <= MIN_TRIGGERING_EVENTS


            Status(i) = ...
                "Excluded: triggering n <= 15";


            fprintf( ...
                'TRIG n = %d | EXCLUDED\n', ...
                N_TRIGGERING(i));


            continue

        end


        Included(i) = ...
            true;


        %% =================================================================
        % 14. COMBINE AP + TRIGGERING EVENTS
        %
        % This is the SAME dataset used in the existing ED threshold fit.
        %% =================================================================

        DATA = [ ...
            AP; ...
            TRIG];


        %% ----------------------------------------------------------------
        % E = cumulative event rainfall
        % D = event duration
        %% ----------------------------------------------------------------

        E = ...
            double(DATA(:,1));


        D = ...
            double(DATA(:,2));


        n = ...
            numel(E);


        N_TOTAL(i) = ...
            n;


        fprintf( ...
            'TRIG n = %3d | total n = %3d | ', ...
            N_TRIGGERING(i), ...
            n);


        %% =================================================================
        % 15. BASIC VARIATION CHECK
        %% =================================================================

        if n < K_FOLDS || ...
                numel(unique(D)) < 2


            Status(i) = ...
                "Insufficient data variation";


            fprintf('INSUFFICIENT VARIATION\n');


            continue

        end


        %% =================================================================
        % 16. CREATE REPRODUCIBLE 5-FOLD PARTITION
        %
        % SAME FOLD ASSIGNMENT IS USED FOR BOTH MODELS.
        %% =================================================================

        rng( ...
            RANDOM_SEED + i);


        randomOrder = ...
            randperm(n);


        foldID = ...
            zeros(n,1);


        for j = 1:n


            foldID(randomOrder(j)) = ...
                mod(j-1,K_FOLDS) + 1;


        end


        %% =================================================================
        % 17. STORE OUT-OF-FOLD PREDICTIONS
        %% =================================================================

        predLinear = ...
            nan(n,1);


        predPower = ...
            nan(n,1);


        %% =================================================================
        % 18. CROSS-VALIDATION LOOP
        %% =================================================================

        stationFoldOK = ...
            true;


        for f = 1:K_FOLDS


            testIndex = ...
                foldID == f;


            trainIndex = ...
                ~testIndex;


            Dtrain = ...
                D(trainIndex);


            Etrain = ...
                E(trainIndex);


            Dtest = ...
                D(testIndex);


            Etest = ...
                E(testIndex);


            %% -------------------------------------------------------------
            % Check training duration variation
            %% -------------------------------------------------------------

            if numel(unique(Dtrain)) < 2


                stationFoldOK = ...
                    false;


                break

            end


            %% =============================================================
            % 18A. LINEAR QUANTILE REGRESSION
            %
            % Fit:
            %
            %       E_tau(D) = a_tau + b_tau D
            %% =============================================================

            bLinear = ncquantreg( ...
                Dtrain, ...
                Etrain, ...
                1, ...
                TAU);


            a_tau = ...
                bLinear(1);


            b_tau = ...
                bLinear(2);


            %% -------------------------------------------------------------
            % Predict held-out rainfall
            %% -------------------------------------------------------------

            EpredLinear = ...
                a_tau + ...
                b_tau .* Dtest;


            predLinear(testIndex) = ...
                EpredLinear;


            %% =============================================================
            % 18B. POWER-LAW QUANTILE REGRESSION
            %
            % Fit in log-log space:
            %
            %       log(E_tau) =
            %           c_tau + beta_tau log(D)
            %
            %
            % Back-transform:
            %
            %       alpha_tau = exp(c_tau)
            %
            %       E_tau(D) =
            %           alpha_tau D^(beta_tau)
            %% =============================================================

            logDtrain = ...
                log(Dtrain);


            logEtrain = ...
                log(Etrain);


            bPower = ncquantreg( ...
                logDtrain, ...
                logEtrain, ...
                1, ...
                TAU);


            c_tau = ...
                bPower(1);


            beta_tau = ...
                bPower(2);


            alpha_tau = ...
                exp(c_tau);


            %% -------------------------------------------------------------
            % Predict held-out rainfall on ORIGINAL mm scale
            %% -------------------------------------------------------------

            EpredPower = ...
                alpha_tau .* ...
                (Dtest .^ beta_tau);


            predPower(testIndex) = ...
                EpredPower;


            %% =============================================================
            % 18C. FOLD RMSE
            %% =============================================================

            RMSE_lin_fold = sqrt( ...
                mean( ...
                (Etest - EpredLinear).^2));


            RMSE_pow_fold = sqrt( ...
                mean( ...
                (Etest - EpredPower).^2));


            %% =============================================================
            % 18D. FOLD PINBALL LOSS
            %% =============================================================

            residualLinear = ...
                Etest - EpredLinear;


            residualPower = ...
                Etest - EpredPower;


            lossLinear = ...
                residualLinear .* ...
                (TAU - (residualLinear < 0));


            lossPower = ...
                residualPower .* ...
                (TAU - (residualPower < 0));


            pinball_lin_fold = ...
                mean(lossLinear);


            pinball_pow_fold = ...
                mean(lossPower);


            %% =============================================================
            % SAVE FOLD RESULTS
            %% =============================================================

            foldStation(end+1,1) = ...
                station;


            foldIMD(end+1,1) = ...
                id;


            foldNumber(end+1,1) = ...
                f;


            foldNTest(end+1,1) = ...
                sum(testIndex);


            foldRMSELinear(end+1,1) = ...
                RMSE_lin_fold;


            foldRMSEPower(end+1,1) = ...
                RMSE_pow_fold;


            foldPinballLinear(end+1,1) = ...
                pinball_lin_fold;


            foldPinballPower(end+1,1) = ...
                pinball_pow_fold;


        end


        %% =================================================================
        % 19. CHECK ALL FOLDS SUCCESSFUL
        %% =================================================================

        if ~stationFoldOK || ...
                any(~isfinite(predLinear)) || ...
                any(~isfinite(predPower))


            Status(i) = ...
                "CV fitting failed";


            fprintf('CV FAILED\n');


            continue

        end


        %% =================================================================
        % 20. OVERALL OUT-OF-FOLD CV RMSE
        %
        %       RMSE =
        %
        % sqrt(mean((E_observed - E_predicted).^2))
        %% =================================================================

        CV_RMSE_Linear(i) = sqrt( ...
            mean( ...
            (E - predLinear).^2));


        CV_RMSE_Power(i) = sqrt( ...
            mean( ...
            (E - predPower).^2));


        %% =================================================================
        % 21. OVERALL CV PINBALL LOSS
        %% =================================================================

        residualLinear = ...
            E - predLinear;


        residualPower = ...
            E - predPower;


        pinballLinear = ...
            residualLinear .* ...
            (TAU - (residualLinear < 0));


        pinballPower = ...
            residualPower .* ...
            (TAU - (residualPower < 0));


        CV_Pinball_Linear(i) = ...
            mean(pinballLinear);


        CV_Pinball_Power(i) = ...
            mean(pinballPower);


        %% =================================================================
        % 22. QUANTILE COVERAGE
        %
        % For tau = 0.20, approximately 20% of observed E values should
        % lie below the predicted threshold.
        %% =================================================================

        Coverage_Linear(i) = ...
            mean(E <= predLinear);


        Coverage_Power(i) = ...
            mean(E <= predPower);


        %% =================================================================
        % 23. COUNT PHYSICALLY IMPOSSIBLE NEGATIVE LINEAR PREDICTIONS
        %% =================================================================

        NegativePred_Linear(i) = ...
            sum(predLinear < 0);


        %% =================================================================
        % 24. PREFERRED MODEL BY CV RMSE
        %% =================================================================

        if CV_RMSE_Linear(i) < CV_RMSE_Power(i)


            Preferred_RMSE(i) = ...
                "Linear";


        elseif CV_RMSE_Power(i) < CV_RMSE_Linear(i)


            Preferred_RMSE(i) = ...
                "Power-law";


        else


            Preferred_RMSE(i) = ...
                "Tie";

        end


        %% =================================================================
        % 25. PREFERRED MODEL BY PINBALL LOSS
        %% =================================================================

        if CV_Pinball_Linear(i) < CV_Pinball_Power(i)


            Preferred_Pinball(i) = ...
                "Linear";


        elseif CV_Pinball_Power(i) < CV_Pinball_Linear(i)


            Preferred_Pinball(i) = ...
                "Power-law";


        else


            Preferred_Pinball(i) = ...
                "Tie";

        end


        Status(i) = ...
            "OK";


        fprintf( ...
            'RMSE L=%.2f | P=%.2f | %s\n', ...
            CV_RMSE_Linear(i), ...
            CV_RMSE_Power(i), ...
            Preferred_RMSE(i));


    catch ME


        Status(i) = ...
            "Error: " + string(ME.message);


        fprintf( ...
            'ERROR: %s\n', ...
            ME.message);


    end


end


%% ========================================================================
% 26. SITE-WISE SUMMARY TABLE
%% ========================================================================

ResultTable = table( ...
    stationNames, ...
    stationIDs, ...
    N_AP, ...
    N_TRIGGERING, ...
    N_TOTAL, ...
    Included, ...
    CV_RMSE_Linear, ...
    CV_RMSE_Power, ...
    CV_Pinball_Linear, ...
    CV_Pinball_Power, ...
    Coverage_Linear, ...
    Coverage_Power, ...
    NegativePred_Linear, ...
    Preferred_RMSE, ...
    Preferred_Pinball, ...
    Status, ...
    'VariableNames',{ ...
    'Station', ...
    'IMD_ID', ...
    'N_AP', ...
    'N_Triggering', ...
    'N_Total_ED', ...
    'Included_GT15', ...
    'CV_RMSE_Linear_mm', ...
    'CV_RMSE_PowerLaw_mm', ...
    'CV_Pinball_Linear', ...
    'CV_Pinball_PowerLaw', ...
    'Coverage_Linear', ...
    'Coverage_PowerLaw', ...
    'Negative_Predictions_Linear', ...
    'Preferred_by_RMSE', ...
    'Preferred_by_Pinball', ...
    'Status'});


%% ========================================================================
% 27. FOLD-WISE TABLE
%% ========================================================================

FoldTable = table( ...
    foldStation, ...
    foldIMD, ...
    foldNumber, ...
    foldNTest, ...
    foldRMSELinear, ...
    foldRMSEPower, ...
    foldPinballLinear, ...
    foldPinballPower, ...
    'VariableNames',{ ...
    'Station', ...
    'IMD_ID', ...
    'Fold', ...
    'N_Test', ...
    'RMSE_Linear_mm', ...
    'RMSE_PowerLaw_mm', ...
    'Pinball_Linear', ...
    'Pinball_PowerLaw'});


%% ========================================================================
% 28. VALID STATIONS FOR REGIONAL SUMMARY
%% ========================================================================

validResult = ...
    Status == "OK";


nValid = ...
    sum(validResult);


if nValid == 0

    error('No stations completed cross-validation successfully.');

end


%% ========================================================================
% 29. REGIONAL SUMMARY OF SITE-WISE RESULTS
%
% IMPORTANT:
%
% This is NOT a pooled regional ED model.
%
% It is only a summary of SITE-WISE cross-validation results.
%% ========================================================================

meanRMSELinear = ...
    mean(CV_RMSE_Linear(validResult));


meanRMSEPower = ...
    mean(CV_RMSE_Power(validResult));


medianRMSELinear = ...
    median(CV_RMSE_Linear(validResult));


medianRMSEPower = ...
    median(CV_RMSE_Power(validResult));


meanPinballLinear = ...
    mean(CV_Pinball_Linear(validResult));


meanPinballPower = ...
    mean(CV_Pinball_Power(validResult));


medianPinballLinear = ...
    median(CV_Pinball_Linear(validResult));


medianPinballPower = ...
    median(CV_Pinball_Power(validResult));


nLinearBetterRMSE = ...
    sum(Preferred_RMSE(validResult) == "Linear");


nPowerBetterRMSE = ...
    sum(Preferred_RMSE(validResult) == "Power-law");


nLinearBetterPinball = ...
    sum(Preferred_Pinball(validResult) == "Linear");


nPowerBetterPinball = ...
    sum(Preferred_Pinball(validResult) == "Power-law");


RegionalSummary = table( ...
    nValid, ...
    meanRMSELinear, ...
    meanRMSEPower, ...
    medianRMSELinear, ...
    medianRMSEPower, ...
    meanPinballLinear, ...
    meanPinballPower, ...
    medianPinballLinear, ...
    medianPinballPower, ...
    nLinearBetterRMSE, ...
    nPowerBetterRMSE, ...
    nLinearBetterPinball, ...
    nPowerBetterPinball, ...
    'VariableNames',{ ...
    'N_Stations', ...
    'Mean_CV_RMSE_Linear', ...
    'Mean_CV_RMSE_PowerLaw', ...
    'Median_CV_RMSE_Linear', ...
    'Median_CV_RMSE_PowerLaw', ...
    'Mean_CV_Pinball_Linear', ...
    'Mean_CV_Pinball_PowerLaw', ...
    'Median_CV_Pinball_Linear', ...
    'Median_CV_Pinball_PowerLaw', ...
    'Stations_Linear_Better_RMSE', ...
    'Stations_PowerLaw_Better_RMSE', ...
    'Stations_Linear_Better_Pinball', ...
    'Stations_PowerLaw_Better_Pinball'});


%% ========================================================================
% 30. WRITE EXCEL OUTPUT
%% ========================================================================

outputExcel = fullfile( ...
    OUTPUT_FOLDER, ...
    'ED_CV_Linear_vs_PowerLaw_GT15.xlsx');


if isfile(outputExcel)

    delete(outputExcel);

end


writetable( ...
    ResultTable, ...
    outputExcel, ...
    'Sheet','Station_CV_Summary');


writetable( ...
    FoldTable, ...
    outputExcel, ...
    'Sheet','Foldwise_CV');


writetable( ...
    RegionalSummary, ...
    outputExcel, ...
    'Sheet','Regional_Summary');


%% ========================================================================
% 31. PREPARE DATA FOR FIGURES
%% ========================================================================

PlotTable = ...
    ResultTable(validResult,:);


%% ------------------------------------------------------------------------
% Sort by lower of the two RMSE values
%% ------------------------------------------------------------------------

bestRMSE = min( ...
    PlotTable.CV_RMSE_Linear_mm, ...
    PlotTable.CV_RMSE_PowerLaw_mm);


[~,sortOrder] = ...
    sort(bestRMSE,'ascend');


PlotTable = ...
    PlotTable(sortOrder,:);


%% ========================================================================
% 32. FIGURE 1: SITE-WISE CV RMSE
%
% Horizontal grouped bar chart is preferred because station names remain
% readable even when several stations are included.
%% ========================================================================

fig1 = figure( ...
    'Color','w', ...
    'Units','centimeters', ...
    'Position',[2 2 25 19]);


Y = [ ...
    PlotTable.CV_RMSE_Linear_mm, ...
    PlotTable.CV_RMSE_PowerLaw_mm];


barh( ...
    Y, ...
    'grouped');


ax = ...
    gca;


ax.YTick = ...
    1:height(PlotTable);


ax.YTickLabel = ...
    PlotTable.Station;


ax.YDir = ...
    'reverse';


ax.FontSize = ...
    11;


ax.FontWeight = ...
    'bold';


ax.LineWidth = ...
    1.1;


ax.TickDir = ...
    'out';


box on;


grid on;


ax.XGrid = ...
    'on';


ax.YGrid = ...
    'off';


xlabel( ...
    '5-fold cross-validated RMSE (mm)', ...
    'FontSize',15, ...
    'FontWeight','bold');


ylabel( ...
    'Station', ...
    'FontSize',15, ...
    'FontWeight','bold');


legend( ...
    {'Linear quantile','Power-law quantile'}, ...
    'Location','best', ...
    'Box','off', ...
    'FontSize',11);


title( ...
    sprintf( ...
    'ED model comparison at \\tau = %.2f', ...
    TAU), ...
    'FontSize',14, ...
    'FontWeight','bold');


%% ------------------------------------------------------------------------
% Export
%% ------------------------------------------------------------------------

RMSE_PNG = fullfile( ...
    OUTPUT_FOLDER, ...
    'CV_RMSE_Linear_vs_PowerLaw_GT15.png');


RMSE_TIFF = fullfile( ...
    OUTPUT_FOLDER, ...
    'CV_RMSE_Linear_vs_PowerLaw_GT15.tiff');


RMSE_FIG = fullfile( ...
    OUTPUT_FOLDER, ...
    'CV_RMSE_Linear_vs_PowerLaw_GT15.fig');


exportgraphics( ...
    fig1, ...
    RMSE_PNG, ...
    'Resolution',600);


exportgraphics( ...
    fig1, ...
    RMSE_TIFF, ...
    'Resolution',600);


savefig( ...
    fig1, ...
    RMSE_FIG);


%% ========================================================================
% 33. FIGURE 2: SITE-WISE CV PINBALL LOSS
%% ========================================================================

fig2 = figure( ...
    'Color','w', ...
    'Units','centimeters', ...
    'Position',[2 2 25 19]);


Y2 = [ ...
    PlotTable.CV_Pinball_Linear, ...
    PlotTable.CV_Pinball_PowerLaw];


barh( ...
    Y2, ...
    'grouped');


ax2 = ...
    gca;


ax2.YTick = ...
    1:height(PlotTable);


ax2.YTickLabel = ...
    PlotTable.Station;


ax2.YDir = ...
    'reverse';


ax2.FontSize = ...
    11;


ax2.FontWeight = ...
    'bold';


ax2.LineWidth = ...
    1.1;


ax2.TickDir = ...
    'out';


box on;


grid on;


ax2.XGrid = ...
    'on';


ax2.YGrid = ...
    'off';


xlabel( ...
    sprintf( ...
    '5-fold CV pinball loss (\\tau = %.2f)', ...
    TAU), ...
    'FontSize',15, ...
    'FontWeight','bold');


ylabel( ...
    'Station', ...
    'FontSize',15, ...
    'FontWeight','bold');


legend( ...
    {'Linear quantile','Power-law quantile'}, ...
    'Location','best', ...
    'Box','off', ...
    'FontSize',11);


title( ...
    'Quantile-model cross-validation performance', ...
    'FontSize',14, ...
    'FontWeight','bold');


%% ------------------------------------------------------------------------
% Export
%% ------------------------------------------------------------------------

Pinball_PNG = fullfile( ...
    OUTPUT_FOLDER, ...
    'CV_Pinball_Linear_vs_PowerLaw_GT15.png');


Pinball_TIFF = fullfile( ...
    OUTPUT_FOLDER, ...
    'CV_Pinball_Linear_vs_PowerLaw_GT15.tiff');


Pinball_FIG = fullfile( ...
    OUTPUT_FOLDER, ...
    'CV_Pinball_Linear_vs_PowerLaw_GT15.fig');


exportgraphics( ...
    fig2, ...
    Pinball_PNG, ...
    'Resolution',600);


exportgraphics( ...
    fig2, ...
    Pinball_TIFF, ...
    'Resolution',600);


savefig( ...
    fig2, ...
    Pinball_FIG);


%% ========================================================================
% 34. FINAL CONSOLE SUMMARY
%% ========================================================================

fprintf('\n');
fprintf('=============================================================\n');
fprintf(' CROSS-VALIDATION COMPLETE\n');
fprintf('=============================================================\n');


fprintf( ...
    'Eligible stations successfully analysed: %d\n', ...
    nValid);


fprintf('\nMedian CV RMSE:\n');


fprintf( ...
    '   Linear    = %.3f mm\n', ...
    medianRMSELinear);


fprintf( ...
    '   Power-law = %.3f mm\n', ...
    medianRMSEPower);


fprintf('\nRMSE preference:\n');


fprintf( ...
    '   Linear better    = %d stations\n', ...
    nLinearBetterRMSE);


fprintf( ...
    '   Power-law better = %d stations\n', ...
    nPowerBetterRMSE);


fprintf('\nMedian CV pinball loss:\n');


fprintf( ...
    '   Linear    = %.3f\n', ...
    medianPinballLinear);


fprintf( ...
    '   Power-law = %.3f\n', ...
    medianPinballPower);


fprintf('\nOutputs:\n%s\n', ...
    OUTPUT_FOLDER);


fprintf('\nExcel:\n%s\n', ...
    outputExcel);


fprintf('\nRMSE figure:\n%s\n', ...
    RMSE_PNG);


fprintf('\n=============================================================\n');