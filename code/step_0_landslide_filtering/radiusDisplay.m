%% ========================================================================
% FUNCTION 11 -- DISPLAY RADIUS
%% ========================================================================

function txt = radiusDisplay(r)

    if abs(r-round(r)) < 1e-10

        txt = sprintf( ...
            '%d km', ...
            round(r));

    else

        txt = sprintf( ...
            '%.1f km', ...
            r);

    end

end