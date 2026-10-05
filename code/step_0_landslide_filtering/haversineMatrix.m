%% ========================================================================
% FUNCTION 5 -- GREAT-CIRCLE DISTANCE
%
% Haversine distance in km.
%% ========================================================================

function D = haversineMatrix( ...
    eventLat, ...
    eventLon, ...
    stationLat, ...
    stationLon, ...
    Rearth)


    eventLat = eventLat(:);

    eventLon = eventLon(:);


    stationLat = stationLat(:)';

    stationLon = stationLon(:)';


    lat1 = deg2rad(eventLat);

    lon1 = deg2rad(eventLon);


    lat2 = deg2rad(stationLat);

    lon2 = deg2rad(stationLon);


    dLat = ...
        lat2 - lat1;


    dLon = ...
        lon2 - lon1;


    a = ...
        sin(dLat./2).^2 + ...
        cos(lat1) .* ...
        cos(lat2) .* ...
        sin(dLon./2).^2;


    a = min( ...
        1, ...
        max(0,a));


    c = ...
        2 .* atan2( ...
        sqrt(a), ...
        sqrt(1-a));


    D = ...
        Rearth .* c;

end


