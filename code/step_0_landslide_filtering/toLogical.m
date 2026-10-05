
%% ========================================================================
% FUNCTION 4 -- FLEXIBLE LOGICAL CONVERSION
%% ========================================================================

function tf = toLogical(x)

    if islogical(x)

        tf = x(:);
        return

    end


    if isnumeric(x)

        x = x(:);

        tf = ...
            isfinite(x) & ...
            x ~= 0;

        return

    end


    s = lower( ...
        strip(string(x(:))));


    tf = ...
        s == "true" | ...
        s == "1" | ...
        s == "yes" | ...
        s == "y";

end


