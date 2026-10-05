%% ========================================================================
% LANDSLIDE FILTERING: radius RADIUS + CLASSIFICATION (OVERLAP ALLOWED) - FIXED
%% ========================================================================
clear; clc; close all;

%% INPUT PATHS
LANDSLIDE_CSV = fullfile(neh_root(),'danish','regional_lhasa_data','processed','landslides','final','Himalaya_NEH_NWH_landslide_master_FINAL.csv');
STATION_XLSX  = fullfile(neh_root(),'all_stations_neh.xlsx');
OUT_PATH      = fullfile(neh_root(),'step_0_landslide_filtering');

if ~exist(OUT_PATH,'dir')
    mkdir(OUT_PATH);
end

fprintf('=== LANDSLIDE radius FILTERING & CLASSIFICATION (OVERLAP ALLOWED) ===\n\n');

%% READ STATION DATA
fprintf('Reading station metadata...\n');
Stations = readtable(STATION_XLSX, 'VariableNamingRule','preserve');
StationName = string(Stations{:,1});
StationLat  = Stations{:,find(contains(lower(Stations.Properties.VariableNames),'lat'),1)};
StationLon  = Stations{:,find(contains(lower(Stations.Properties.VariableNames),'lon'),1)};
nStations   = numel(StationName);
fprintf('Found %d stations\n\n', nStations);

%% READ LANDSLIDE MASTER CSV
fprintf('Reading landslide master catalogue...\n');
L = readtable(LANDSLIDE_CSV, 'VariableNamingRule','preserve', 'TextType','string');
N_original = height(L);
fprintf('Original records: %d\n', N_original);

%% EXTRACT COORDINATES
Lat = str2double(string(L.latitude));
Lon = str2double(string(L.longitude));
validCoord = isfinite(Lat) & isfinite(Lon);
L   = L(validCoord,:);
Lat = Lat(validCoord);
Lon = Lon(validCoord);
fprintf('Valid coordinates: %d\n', numel(Lat));

%% PARSE EVENT DATES SAFELY (row-by-row, handles mixed formats)
rawDates    = L.final_event_date;
EventDateAll = NaT(height(L),1);
for i = 1:height(L)
    try
        if isdatetime(rawDates)
            EventDateAll(i) = rawDates(i);
        else
            EventDateAll(i) = datetime(string(rawDates(i)), 'InputFormat','yyyy-MM-dd');
        end
    catch
        try
            EventDateAll(i) = datetime(string(rawDates(i)));
        catch
            EventDateAll(i) = NaT;
        end
    end
end

%% CLASSIFICATION SOURCE
ClassificationAll = string(L.landslide_size);
ClassificationAll(ismissing(ClassificationAll) | ClassificationAll=="") = "Unclassified";

%% CALCULATE DISTANCES TO ALL STATIONS (VECTORIZED HAVERSINE)
EARTH_RADIUS_KM = 6371.0088;
R_radius = 20;

fprintf('\nCalculating distances to stations...\n');

lat1 = deg2rad(Lat);            % N x 1
lon1 = deg2rad(Lon);            % N x 1
lat2 = deg2rad(StationLat(:))'; % 1 x M
lon2 = deg2rad(StationLon(:))'; % 1 x M

dlat = lat2 - lat1;
dlon = lon2 - lon1;
a = sin(dlat/2).^2 + cos(lat1).*cos(lat2).*sin(dlon/2).^2;
D = EARTH_RADIUS_KM * 2 * asin(sqrt(a));   % N x M distance matrix

%% FILTER FOR LANDSLIDES WITHIN radius OF ANY STATION (OVERLAP ALLOWED)
withinradius_any = any(D <= R_radius, 2);
idx_keep = find(withinradius_any);
fprintf('Landslides within radius of any station: %d\n\n', numel(idx_keep));

%% BUILD OUTPUT — PREALLOCATED (no growing-table warnings)
[lsRow, stnCol] = find(D(idx_keep,:) <= R_radius);
nRows = numel(lsRow);

Landslide_ID = idx_keep(lsRow);
Station      = StationName(stnCol);
Lat_out      = Lat(Landslide_ID);
Lon_out      = Lon(Landslide_ID);

Dist_out = zeros(nRows,1);
for k = 1:nRows
    Dist_out(k) = D(Landslide_ID(k), stnCol(k));
end

Classification = ClassificationAll(Landslide_ID);
EventDate      = EventDateAll(Landslide_ID);
Year_out       = year(EventDate);
Month_out      = month(EventDate);
Day_out        = day(EventDate);

Output = table(Landslide_ID, Station, Lat_out, Lon_out, Dist_out, Classification, ...
    Year_out, Month_out, Day_out, EventDate, ...
    'VariableNames', {'Landslide_ID','Station','Latitude','Longitude','Distance_km', ...
    'Classification','Year','Month','Day','EventDate'});

%% SAVE EXCEL FILE
outFile = fullfile(OUT_PATH, 'Landslides_radius_Classification_OverlapAllowed.xlsx');
writetable(Output, outFile);
fprintf('✓ Output file created: %s\n', outFile);
fprintf('✓ Total rows (landslides × stations within radius): %d\n', height(Output));

%% SUMMARY BY STATION (FIXED — no method arg needed for plain counts)
fprintf('\n=== LANDSLIDES BY STATION (radius, Overlap Allowed) ===\n');
stationCount = groupsummary(Output, 'Station');
disp(stationCount);

%% SUMMARY BY CLASSIFICATION (FIXED)
fprintf('\n=== LANDSLIDES BY CLASSIFICATION ===\n');
classCount = groupsummary(Output, 'Classification');
disp(classCount);

fprintf('\nDone!\n');