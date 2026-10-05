%% ========================================================================
% FUNCTION 3 -- SAFE NUMERIC CONVERSION
%% ========================================================================

function out = toNumeric(x)

    if isnumeric(x)

        out = double(x(:));

    else

        out = str2double( ...
            string(x(:)));

    end

end

