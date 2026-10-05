%% ========================================================================
% Kendall tau + jackknife error interval
%% ========================================================================

function [tauVal,ciVal,pVal] = tau_and_SE( ...
    x, ...
    y, ...
    seScale)


    x = ...
        x(:);


    y = ...
        y(:);


    mask = ...
        isfinite(x) & ...
        isfinite(y);


    x = ...
        x(mask);


    y = ...
        y(mask);


    tauVal = ...
        NaN;


    pVal = ...
        NaN;


    ciVal = ...
        [NaN NaN];


    if numel(x) < 2


        return


    end


    [tauVal,pVal] = corr( ...
        x, ...
        y, ...
        'Type','Kendall', ...
        'Rows','complete');


    if numel(x) >= 3


        se = ...
            jackknife_se_kendall( ...
            x, ...
            y);


        half = ...
            seScale * se;


        ciVal = ...
            clamp_to_unit( ...
            [ ...
            tauVal-half, ...
            tauVal+half ...
            ]);


    end


end