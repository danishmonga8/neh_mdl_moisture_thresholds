
%% ========================================================================
% LOCAL FUNCTIONS
%% ========================================================================

function se = jackknife_se_kendall(x,y)


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


    n = ...
        numel(x);


    if n < 3


        se = ...
            NaN;


        return


    end


    tau_jk = ...
        nan(n,1);


    for k = 1:n


        idx = ...
            true(n,1);


        idx(k) = ...
            false;


        tau_jk(k) = corr( ...
            x(idx), ...
            y(idx), ...
            'Type','Kendall', ...
            'Rows','complete');


    end


    tau_bar = ...
        mean( ...
        tau_jk, ...
        'omitnan');


    se = sqrt( ...
        (n-1)/n * ...
        nansum( ...
        (tau_jk - tau_bar).^2));


end


