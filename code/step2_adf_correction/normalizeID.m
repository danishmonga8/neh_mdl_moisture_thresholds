%% ========================================================================
% LOCAL FUNCTION -- NORMALIZE IMD/WMO IDs
%% ========================================================================

function out = normalizeID(x)

    if isnumeric(x)

        out = string( ...
            compose('%.0f',x));

    else

        out = strip( ...
            string(x));

        out = regexprep( ...
            out, ...
            '\.0$', ...
            '');

    end

end