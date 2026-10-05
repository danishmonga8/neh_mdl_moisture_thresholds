%% ========================================================================
% FUNCTION 6 -- ANALYSE ONE SEARCH RADIUS
%% ========================================================================

function R = analyseRadius( ...
    D, ...
    Draw, ...
    radiusKm)


    nStations = size(D,2);


    %% --------------------------------------------------------------------
    % Candidate unique events in every station radius
    %% --------------------------------------------------------------------

    candidate = ...
        D <= radiusKm;


    %% --------------------------------------------------------------------
    % Raw records prior to catalogue deduplication
    %% --------------------------------------------------------------------

    rawCandidate = ...
        Draw <= radiusKm;


    %% --------------------------------------------------------------------
    % Number of station buffers containing each unique event
    %% --------------------------------------------------------------------

    candidateStationN = ...
        sum(candidate,2);


    %% --------------------------------------------------------------------
    % Nearest station
    %% --------------------------------------------------------------------

    [nearestDistance,nearestStation] = ...
        min(D,[],2);


    %% --------------------------------------------------------------------
    % Unique nearest-station assignment
    %% --------------------------------------------------------------------

    finalStationIndex = ...
        zeros(size(nearestStation));


    insideAnyBuffer = ...
        nearestDistance <= radiusKm;


    finalStationIndex(insideAnyBuffer) = ...
        nearestStation(insideAnyBuffer);


    %% --------------------------------------------------------------------
    % Station-wise audit
    %% --------------------------------------------------------------------

    rawCount = ...
        zeros(nStations,1);


    uniqueCandidateCount = ...
        zeros(nStations,1);


    catalogueDuplicateRows = ...
        zeros(nStations,1);


    overlapCandidateCount = ...
        zeros(nStations,1);


    finalAssignedCount = ...
        zeros(nStations,1);


    for s = 1:nStations


        rawCount(s) = ...
            sum(rawCandidate(:,s));


        uniqueCandidateCount(s) = ...
            sum(candidate(:,s));


        catalogueDuplicateRows(s) = ...
            max( ...
            0, ...
            rawCount(s) - ...
            uniqueCandidateCount(s));


        overlapCandidateCount(s) = ...
            sum( ...
            candidate(:,s) & ...
            candidateStationN > 1);


        finalAssignedCount(s) = ...
            sum( ...
            finalStationIndex == s);

    end


    %% --------------------------------------------------------------------
    % Return structure
    %% --------------------------------------------------------------------

    R.radiusKm = ...
        radiusKm;


    R.candidate = ...
        candidate;


    R.candidateStationN = ...
        candidateStationN;


    R.nearestDistance = ...
        nearestDistance;


    R.nearestStation = ...
        nearestStation;


    R.finalStationIndex = ...
        finalStationIndex;


    R.rawCount = ...
        rawCount;


    R.uniqueCandidateCount = ...
        uniqueCandidateCount;


    R.catalogueDuplicateRows = ...
        catalogueDuplicateRows;


    R.overlapCandidateCount = ...
        overlapCandidateCount;


    R.finalAssignedCount = ...
        finalAssignedCount;

end

