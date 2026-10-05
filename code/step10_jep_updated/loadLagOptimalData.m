%% ============================================================================
% HELPER FUNCTION: Load lag-optimal TR, API, Seff by station name match
%% ============================================================================
function [TR, API, Seff] = loadLagOptimalData(Step7Table, stnName)
    TR = []; API = []; Seff = [];
    try
        if ismember('Station', Step7Table.Properties.VariableNames)
            idx = strcmpi(string(Step7Table.Station), stnName);
            if sum(idx) > 0
                TR = Step7Table.TR(idx);
                API = Step7Table.API(idx);
                Seff = Step7Table.Seff(idx);
                return;
            end
        end
        fprintf('  NOTE: No matching Step7 data found for Station=%s\n', stnName);
    catch ME
        fprintf('  ERROR loading data: %s\n', ME.message);
    end
end