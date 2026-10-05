%% ========================================================================
% FUNCTION 1
% FIND RAINFALL FILE CORRESPONDING TO STATION
%% ========================================================================

function rainFile = findRainFile( ...
    RainFolder, ...
    stationID, ...
    stationName)


    F = dir( ...
        fullfile(RainFolder,'*.txt'));


    names = string( ...
        {F.name})';


    if isempty(names)

        error( ...
            'No rainfall TXT files found in:\n%s', ...
            RainFolder);

    end


    %% --------------------------------------------------------------------
    % FIRST: exact filename based on ID
    %% --------------------------------------------------------------------

    exact1 = ...
        lower(names) == ...
        lower(stationID + ".txt");


    if sum(exact1) == 1

        rainFile = ...
            names(exact1);

        return

    end


    %% --------------------------------------------------------------------
    % SECOND: station ID as a numeric token
    %% --------------------------------------------------------------------

    escapedID = ...
        regexptranslate( ...
        'escape', ...
        char(stationID));


    pattern = ...
        ['(^|[^0-9])' ...
         escapedID ...
         '([^0-9]|$)'];


    matchID = false( ...
        numel(names),1);


    for i = 1:numel(names)

        matchID(i) = ...
            ~isempty( ...
            regexp( ...
            char(names(i)), ...
            pattern, ...
            'once'));

    end


    if sum(matchID) == 1

        rainFile = ...
            names(matchID);

        return

    end


    %% --------------------------------------------------------------------
    % THIRD: match using cleaned station name
    %% --------------------------------------------------------------------

    cleanStation = lower( ...
        regexprep( ...
        char(stationName), ...
        '[^a-zA-Z0-9]', ...
        ''));


    matchName = false( ...
        numel(names),1);


    for i = 1:numel(names)


        cleanFile = lower( ...
            regexprep( ...
            char(names(i)), ...
            '[^a-zA-Z0-9]', ...
            ''));


        matchName(i) = ...
            contains( ...
            cleanFile, ...
            cleanStation);

    end


    if sum(matchName) == 1

        rainFile = ...
            names(matchName);

        return

    end


    %% --------------------------------------------------------------------
    % FOURTH: broad ID match
    %% --------------------------------------------------------------------

    broadID = ...
        contains( ...
        lower(names), ...
        lower(stationID));


    if sum(broadID) == 1

        rainFile = ...
            names(broadID);

        return

    end


    %% --------------------------------------------------------------------
    % No unique match
    %% --------------------------------------------------------------------

    if sum(matchID) > 1 || ...
            sum(matchName) > 1 || ...
            sum(broadID) > 1


        warning( ...
            ['Multiple possible rainfall files found for ' ...
             '%s (%s). File skipped to avoid incorrect pairing.'], ...
            stationName,stationID);

    end


    rainFile = "";

end