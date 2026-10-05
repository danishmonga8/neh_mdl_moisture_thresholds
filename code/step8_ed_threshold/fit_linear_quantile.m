
%% ==============================================================
%  LOCAL FUNCTION : Linear quantile fit using ncquantreg if available,
%  otherwise fallback to fminsearch on pinball loss.
% ==============================================================
function [a, b] = fit_linear_quantile(x, y, tau)

    x = x(:);
    y = y(:);

    good = isfinite(x) & isfinite(y);
    x = x(good);
    y = y(good);

    if numel(x) < 2
        a = NaN; b = NaN;
        return
    end

    if exist('ncquantreg', 'file') == 2
        try
            coeff = ncquantreg(x, y, 1, tau);  % [a; b]
            a = coeff(1);
            b = coeff(2);
            return
        catch
            % fallback below
        end
    end

    % fallback quantile regression via fminsearch
    p0 = [median(y); 0];
    obj = @(p) sum((tau - (y - (p(1) + p(2).*x) < 0)) .* (y - (p(1) + p(2).*x)));
    opts = optimset('Display','off', 'MaxFunEvals', 1e5, 'MaxIter', 1e5);
    p = fminsearch(obj, p0, opts);

    a = p(1);
    b = p(2);
end