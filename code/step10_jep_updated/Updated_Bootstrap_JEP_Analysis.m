clear; clc; close all;
basePath = fullfile(neh_root(),'step10_jep_updated');
inFile   = fullfile(basePath, 'EmpiricalProb_LargeEvents_Corrected.xlsx');
Out = readtable(inFile, 'VariableNamingRule', 'preserve');

%% -------------------------------------------------
% 0) Load REAL station metadata (Slope, Vegetation %, Built-up %)
%% -------------------------------------------------
stationMetaFile = fullfile(neh_root(),'all_stations_neh.xlsx');
StnMeta = readtable(stationMetaFile, 'Sheet', 'Sheet1', 'VariableNamingRule', 'preserve');

% Clean up column names (trailing spaces in original file)
StnMeta.Properties.VariableNames = strtrim(StnMeta.Properties.VariableNames);
StnMeta.Station = string(strtrim(StnMeta.Station));

Out.Station = string(Out.Station);

% Merge station-level Slope / Vegetation / BuiltArea onto every event row
[tf, locB] = ismember(Out.Station, StnMeta.Station);
if any(~tf)
    missingStns = unique(Out.Station(~tf));
    warning('The following stations in Out were not found in station metadata: %s', strjoin(missingStns, ', '));
end

Slope_Mean_Deg   = nan(height(Out),1);
Vegetation_pct   = nan(height(Out),1);
BuiltArea_pct    = nan(height(Out),1);

Slope_Mean_Deg(tf)  = StnMeta.Slope_Mean_Deg(locB(tf));
Vegetation_pct(tf)  = StnMeta.Vegetation_Trees_pct(locB(tf));
BuiltArea_pct(tf)   = StnMeta.BuiltArea_pct(locB(tf));

Out.Slope_Mean_Deg = Slope_Mean_Deg;
Out.Vegetation_pct = Vegetation_pct;
Out.BuiltArea_pct  = BuiltArea_pct;

%% -------------------------------------------------
% Variables used for plotting (NOW CORRECT)
%% -------------------------------------------------
x      = Out.Slope_Mean_Deg;      % was wrongly Out.Longitude
yr     = Out.Year;
bua    = Out.BuiltArea_pct;       % was wrongly Out.Latitude
veg    = Out.Vegetation_pct;      % was wrongly Out.Day
stn    = string(Out.Station);
y_tri_prob = Out.JEP_Corrected;
y_tr_prob  = Out.TR_Exceedance;
y_tri = y_tri_prob * 100;
y_tr  = y_tr_prob  * 100;