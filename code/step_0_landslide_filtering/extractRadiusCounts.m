%% ========================================================================
%% LOCAL FUNCTIONS
%% ========================================================================


%% ========================================================================
% FUNCTION 1
% EXTRACT TOTAL / UNIQUE / SHARED COUNTS
%% ========================================================================

function D = extractRadiusCounts(T,radiusKm)


    vars = string( ...
        T.Properties.VariableNames);


    varsLow = lower(vars);


    %% --------------------------------------------------------------------
    % Station
    %% --------------------------------------------------------------------

    stCol = find( ...
        varsLow == "station", ...
        1);


    if isempty(stCol)

        error( ...
            'Station column not found for %g-km file.', ...
            radiusKm);

    end


    Station = ...
        string(T{:,stCol});


    %% --------------------------------------------------------------------
    % TOTAL
    %
    % Find variable such as:
    %
    % Events_within_20km
    %% --------------------------------------------------------------------

    radiusText = ...
        sprintf('%gkm',radiusKm);


    totalCol = find( ...
        contains(varsLow,'events_within') & ...
        contains(varsLow,lower(radiusText)), ...
        1);


    % Fallback if generic total variable is used
    if isempty(totalCol)

        totalCol = find( ...
            contains(varsLow,'events_within'), ...
            1);

    end


    %% --------------------------------------------------------------------
    % UNIQUE
    %% --------------------------------------------------------------------

    uniqueCol = find( ...
        contains(varsLow,'unique_to_this_station_buffer'), ...
        1);


    %% --------------------------------------------------------------------
    % SHARED
    %% --------------------------------------------------------------------

    sharedCol = find( ...
        contains(varsLow,'also_within_other_station_buffers'), ...
        1);


    if isempty(totalCol) || ...
            isempty(uniqueCol) || ...
            isempty(sharedCol)

        error( ...
            ['Required count columns could not be identified ' ...
             'for %g-km data.'], ...
            radiusKm);

    end


    Total = ...
        double(T{:,totalCol});


    Unique = ...
        double(T{:,uniqueCol});


    Shared = ...
        double(T{:,sharedCol});


    D = table( ...
        Station, ...
        Total, ...
        Unique, ...
        Shared);

end


%% ========================================================================
% FUNCTION 2
% PLOT ONE RADIUS PANEL
%% ========================================================================

function plotRadiusPanel( ...
    ax, ...
    UniqueData, ...
    SharedData, ...
    TotalData, ...
    StationLabels, ...
    uniqueColor, ...
    sharedColor, ...
    edgeColor, ...
    xMax, ...
    showStationLabels)


    n = ...
        numel(TotalData);


    hold(ax,'on');


    %% --------------------------------------------------------------------
    % STACKED DATA
    %% --------------------------------------------------------------------

    Y = [ ...
        UniqueData ...
        SharedData];


    b = barh( ...
        ax, ...
        Y, ...
        'stacked', ...
        'BarWidth',0.70);


    %% --------------------------------------------------------------------
    % Colours
    %% --------------------------------------------------------------------

    b(1).FaceColor = ...
        uniqueColor;


    b(1).EdgeColor = ...
        edgeColor;


    b(1).LineWidth = ...
        0.65;


    b(2).FaceColor = ...
        sharedColor;


    b(2).EdgeColor = ...
        edgeColor;


    b(2).LineWidth = ...
        0.65;


    %% --------------------------------------------------------------------
    % TOTAL COUNTS
    %% --------------------------------------------------------------------

    offset = ...
        max(0.5,0.008*xMax);


    for i = 1:n


        text( ...
            ax, ...
            TotalData(i)+offset, ...
            i, ...
            sprintf('%d',TotalData(i)), ...
            'HorizontalAlignment','left', ...
            'VerticalAlignment','middle', ...
            'FontSize',10.5, ...
            'FontWeight','bold', ...
            'Color','k');


        %% ----------------------------------------------------------------
        % Shared-event COUNT inside red segment
        %
        % This directly answers reviewer concern.
        %% ----------------------------------------------------------------

        if SharedData(i) >= 4


            xShared = ...
                UniqueData(i) + ...
                SharedData(i)/2;


            text( ...
                ax, ...
                xShared, ...
                i, ...
                sprintf('%d',SharedData(i)), ...
                'HorizontalAlignment','center', ...
                'VerticalAlignment','middle', ...
                'FontSize',9.5, ...
                'FontWeight','bold', ...
                'Color','w');

        end

    end


    %% --------------------------------------------------------------------
    % Axis
    %% --------------------------------------------------------------------

    set( ...
        ax, ...
        'YDir','reverse', ...
        'YTick',1:n, ...
        'FontSize',11, ...
        'FontWeight','bold', ...
        'LineWidth',0.9, ...
        'TickDir','out', ...
        'Box','off', ...
        'XColor','k', ...
        'YColor','k', ...
        'Layer','top');


    %% --------------------------------------------------------------------
    % Only first panel gets station names
    %% --------------------------------------------------------------------

    if showStationLabels

        ax.YTickLabel = ...
            StationLabels;

    else

        ax.YTickLabel = ...
            [];

    end


    xlim( ...
        ax, ...
        [0 xMax]);


    ylim( ...
        ax, ...
        [0.3 n+0.7]);


    %% --------------------------------------------------------------------
    % Grid
    %% --------------------------------------------------------------------

    grid(ax,'on');


    ax.XGrid = 'on';

    ax.YGrid = 'off';


    ax.GridLineStyle = ':';

    ax.GridAlpha = 0.16;

end