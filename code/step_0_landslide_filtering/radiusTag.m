
%% ========================================================================
% FUNCTION 9 -- RADIUS TAG FOR FOLDER/SHEET
%
% 10    -> 10km
% 12.5  -> 12p5km
%% ========================================================================

function tag = radiusTag(r)

    if abs(r-round(r)) < 1e-10

        tag = sprintf( ...
            '%dkm', ...
            round(r));

    else

        temp = sprintf('%.1f',r);

        temp = strrep( ...
            temp, ...
            '.', ...
            'p');


        tag = ...
            [temp 'km'];

    end

end
