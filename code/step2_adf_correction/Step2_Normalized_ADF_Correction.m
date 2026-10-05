%% ========================================================================
% STEP2_Normalized_ADF_Final_NEH_Map.m
%
% Normalized ADF calculation after independent N* selection
%
% API and TR converted into empirical probability space:
%
% API_norm = tiedrank(API)/(n+1)
% TR_norm  = tiedrank(TR)/(n+1)
%
% ADF_norm = Number(API_norm > TR_norm)/Total events
%
% ========================================================================


clc;
clear;
close all;


%% ========================= PATHS =======================================

ROOT_A = fullfile(neh_root());

ROOT_B = fullfile(neh_root(),'2_new_stations_neh');


WORK_DIR = fullfile(ROOT_A,...
    'revision_round1',...
    'step2_normalized_adf_final');


if ~exist(WORK_DIR,'dir')
    mkdir(WORK_DIR)
end


STEP1_FILE = fullfile(ROOT_A,...
    'revision_round1',...
    'step1_lag_selection',...
    'Step1_LagSelection_Summary.xlsx');


TRIGGER_DIR = fullfile(ROOT_A,...
    '7_trigging_events');


API_ROOT_A = fullfile(ROOT_A,...
    '6_crozier_outputs');


API_ROOT_B = fullfile(ROOT_B,...
    '6_crozier_outputs');


META_FILE = fullfile(ROOT_A,...
    'all_stations_neh.xlsx');


SHAPEFILE = ...
fullfile(neh_root(),'western_himalayas_landslide','spatial_variation_map','my_study_shape','Himalayan_UP_Bihar.shp');



K = 0.9;


ADF_THRESHOLD = 0.5;



%% ========================= READ N* =====================================


Lag = readtable(STEP1_FILE,...
    'Sheet','Nstar_summary',...
    'VariableNamingRule','preserve');


Lag.Station = string(Lag.Station);

Lag.IMD_ID = normalizeID(Lag.IMD_ID);

Lag.N_star_d = double(Lag.N_star_d);


Lag = Lag(isfinite(Lag.N_star_d),:);



%% ========================= READ META ===================================

Meta = readtable(META_FILE,...
    'VariableNamingRule','preserve');


vars = string(Meta.Properties.VariableNames);


% Find station column
stationCol = find(contains(lower(vars),"station"),1);

% Find IMD column
imdCol = find(contains(lower(vars),"imd"),1);

% Latitude
latCol = find(contains(lower(vars),"lat"),1);

% Longitude
lonCol = find(contains(lower(vars),["long","lon"]),1);


if isempty(stationCol) || isempty(imdCol) || ...
        isempty(latCol) || isempty(lonCol)

    disp(Meta.Properties.VariableNames)

    error('Required columns not detected. Check Excel headers.')

end


Meta.Station = string(Meta{:,stationCol});

Meta.IMD = normalizeID(Meta{:,imdCol});

Meta.Lat = double(Meta{:,latCol});

Meta.Long = double(Meta{:,lonCol});



%% ========================= ARRAYS ======================================


nStation = height(Lag);


Station = strings(nStation,1);

IMD_ID = strings(nStation,1);

N_star = nan(nStation,1);

Events = nan(nStation,1);

API_norm_GT_TR_norm = nan(nStation,1);

ADF_norm = nan(nStation,1);



Event_Table = table();



%% ========================= MAIN LOOP ===================================


for i = 1:nStation


    id = Lag.IMD_ID(i);

    station = Lag.Station(i);

    N = Lag.N_star_d(i);



    fprintf('%s  N*=%d\n',station,N);


    Station(i)=station;

    IMD_ID(i)=id;

    N_star(i)=N;



    %% -------- Triggering rainfall ------------------

    triggerFile = fullfile( ...
        TRIGGER_DIR,...
        id+"_trigging.txt");


    if ~isfile(triggerFile)

        continue

    end



    TRdata = readmatrix(triggerFile);



    eventDate = datetime( ...
        TRdata(:,1),...
        TRdata(:,2),...
        TRdata(:,3));


    TR = TRdata(:,4);



    %% -------- API file -----------------------------


    apiName = sprintf('%s_%d_crozier_5.txt',id,N);



    file1 = fullfile( ...
        API_ROOT_A,...
        sprintf('%d_day',N),...
        apiName);


    file2 = fullfile( ...
        API_ROOT_B,...
        sprintf('%d_day',N),...
        apiName);



    if isfile(file1)

        apiFile=file1;


    elseif isfile(file2)

        apiFile=file2;


    else

        continue

    end



    APIdata = readmatrix(apiFile);



    APIdate = datetime( ...
        APIdata(:,1),...
        APIdata(:,2),...
        APIdata(:,3));


    API = APIdata(:,4);



    %% -------- Match dates ---------------------------


    [tf,loc] = ismember(eventDate,APIdate);


    API_match = nan(size(TR));


    API_match(tf)=API(loc(tf));



    valid = tf & ...
        isfinite(API_match) & ...
        isfinite(TR);



    API_match = API_match(valid);

    TR_match = TR(valid);



    if isempty(API_match)

        continue

    end



    n = length(API_match);



    %% -------- Normalization ------------------------


    API_norm = tiedrank(API_match)/(n+1);

    TR_norm = tiedrank(TR_match)/(n+1);



    flag = API_norm > TR_norm;



    Events(i)=n;

    API_norm_GT_TR_norm(i)=sum(flag);


    ADF_norm(i)=sum(flag)/n;



    %% -------- Event table --------------------------


    Temp = table( ...
        repmat(station,n,1),...
        repmat(id,n,1),...
        API_match,...
        TR_match,...
        API_norm,...
        TR_norm,...
        flag,...
        repmat(N,n,1),...
        'VariableNames',...
        {'Station',...
        'IMD_ID',...
        'API_mm',...
        'TR_mm',...
        'API_normalized',...
        'TR_normalized',...
        'API_norm_GT_TR_norm',...
        'N_star_days'});


    Event_Table=[Event_Table;Temp];


end



%% ========================= SUMMARY ================================


Summary = table( ...
    Station,...
    IMD_ID,...
    N_star,...
    repmat(K,nStation,1),...
    Events,...
    API_norm_GT_TR_norm,...
    ADF_norm,...
    'VariableNames',...
    {'Station',...
    'IMD_ID',...
    'N_star_days',...
    'K',...
    'Total_events',...
    'API_norm_GT_TR_norm_events',...
    'ADF_normalized'});



Summary = Summary(isfinite(Summary.ADF_normalized),:);



%% ========================= SPATIAL DATA ============================


Spatial = innerjoin( ...
    Summary,...
    Meta(:,{'IMD','Lat','Long'}),...
    'LeftKeys','IMD_ID',...
    'RightKeys','IMD');



%% ========================= SAVE EXCEL ==============================


outfile = fullfile(WORK_DIR,...
    'Step2_Normalized_ADF_Final_Results.xlsx');


writetable(Summary,outfile,...
    'Sheet','ADF_summary');


writetable(Event_Table,outfile,...
    'Sheet','Event_level');


writetable(Spatial,outfile,...
    'Sheet','Spatial_map_data');



%% ========================= READ SHAPEFILE ===========================


S = shaperead(SHAPEFILE,...
    'UseGeoCoords',true);



%% ========================= NEH CROPPING =============================


lat_min = min(Spatial.Lat)-1;

lat_max = max(Spatial.Lat)+1;

lon_min = min(Spatial.Long)-1;

lon_max = max(Spatial.Long)+1;



keep = false(length(S),1);


for i=1:length(S)

    x=S(i).Lon;

    y=S(i).Lat;


    keep(i)= ...
        any(x>=lon_min & x<=lon_max & ...
            y>=lat_min & y<=lat_max);

end


S=S(keep);



%% ========================= COLOUR MAP ===============================


cmap=[
252 253 191
251 191 115
239 104 102
175 54 160
66 15 112]/255;


cmap=interp1( ...
    linspace(0,1,size(cmap,1)),...
    cmap,...
    linspace(0,1,256));



%% ========================= SPATIAL MAP ==============================


figure('Color','w',...
    'Position',[100 100 900 700]);


hold on



for i=1:length(S)

    plot(S(i).Lon,...
        S(i).Lat,...
        'Color',[0.4 0.4 0.4],...
        'LineWidth',1);

end



scatter(Spatial.Long,...
        Spatial.Lat,...
        180,...
        Spatial.ADF_normalized,...
        'filled',...
        'MarkerEdgeColor','k',...
        'LineWidth',1);



colormap(cmap)

clim([0 1])


cb=colorbar;

cb.Label.String='Normalized ADF';

cb.FontSize=12;



xlabel('Longitude',...
    'FontSize',14,...
    'FontWeight','bold');


ylabel('Latitude',...
    'FontSize',14,...
    'FontWeight','bold');



set(gca,...
    'FontSize',12,...
    'LineWidth',1,...
    'Box','on');


grid on

axis equal



exportgraphics(gcf,...
    fullfile(WORK_DIR,...
    'Step2_Normalized_ADF_NEH_Map.png'),...
    'Resolution',600);



%% ========================= DONUT ================================


high=sum(Spatial.ADF_normalized>=ADF_THRESHOLD);

low=sum(Spatial.ADF_normalized<ADF_THRESHOLD);



figure('Color','w',...
    'Position',[200 200 600 500]);



p=pie([high low]);


colors=[
0.90 0.20 0.20
0.10 0.40 0.85];



patches=findobj(gca,'Type','Patch');


for i=1:length(patches)

    patches(i).FaceColor=colors(i,:);

end



axis equal

axis off



legend({'ADF >= 0.5',...
        'ADF < 0.5'},...
        'Location','eastoutside',...
        'FontSize',12,...
        'Box','off');



exportgraphics(gcf,...
    fullfile(WORK_DIR,...
    'Step2_Normalized_ADF_Donut.png'),...
    'Resolution',600);



fprintf('\nNORMALIZED ADF STEP COMPLETED\n');



%% ========================= FUNCTION ================================

