%% ========================================================================
% Clamp interval to valid Kendall tau range [-1,+1]
%% ========================================================================

function ci = clamp_to_unit(ci)


    ci = ...
        max( ...
        min(ci,1), ...
        -1);


end


%% ========================================================================
% Pool station-specific event pairs
%% ========================================================================

function [xAll,yAll] = pool_pairs( ...
    Xcell, ...
    Ycell, ...
    useMask)


    xAll = ...
        [];


    yAll = ...
        [];


    for i = 1:numel(Xcell)


        if useMask(i) && ...
                ~isempty(Xcell{i}) && ...
                ~isempty(Ycell{i})


            xAll = [ ...
                xAll; ...
                Xcell{i}(:)]; %#ok<AGROW>


            yAll = [ ...
                yAll; ...
                Ycell{i}(:)]; %#ok<AGROW>


        end


    end


end


