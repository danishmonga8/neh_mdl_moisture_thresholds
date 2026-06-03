%% ============================================================
%  Local function: Lorenz curve and Gini coefficient
%% ============================================================

function [p, L, G] = lorenzGini(x)

    x = x(:);
    x(isnan(x)) = 0;
    x(x < 0) = 0;

    x = sort(x, "ascend");

    n = numel(x);

    p = (0:n)' / n;

    if sum(x) == 0
        L = zeros(n+1,1);
        G = NaN;
        return;
    end

    L = [0; cumsum(x) / sum(x)];

    % Gini coefficient = area between equality line and Lorenz curve
    G = 1 - 2 * trapz(p, L);

end