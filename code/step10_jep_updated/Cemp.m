%% ============================================================================
% LOCAL FUNCTION: empirical copula (denominator = n, CORRECTED)
% Cemp(u, U): fraction of rows in U that are <= u in every dimension
%% ============================================================================
function val = Cemp(u, U)
    n = size(U,1);
    val = sum(all(U <= u, 2)) / n;
end