% HELPER FUNCTION: Load lag-optimal TR, API, Seff with flexible matching
%% ============================================================================
function [TR, API, Seff] = loadLagOptimalData(Step7Table, stnIMDID, stnName)
    TR = [];
    API = [];
    Seff = [];

    try
        % Try exact IMD_ID match first
        idx = Step7Table.IMD_ID == stnIMDID;
        if sum(idx) > 0
            TR = Step7Table.TR(idx);
            API = Step7Table.API(idx);
            Seff = Step7Table.Seff(idx);
            return;
        end

        % If IMD_ID doesn't match, try station name match
        if ismember('Station', Step7Table.Properties.VariableNames)
            idx = strcmp(string(Step7Table.Station), stnName);
            if sum(idx) > 0
                TR = Step7Table.TR(idx);
                API = Step7Table.API(idx);
                Seff = Step7Table.Seff(idx);
                return;
            end
        end

        fprintf('  NOTE: No matching data found for IMD_ID=%d or Station=%s\n', stnIMDID, stnName);

    catch ME
        fprintf('  ERROR loading data: %s\n', ME.message);
    end
end
