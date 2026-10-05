function [xAll, yAll] = pool_pairs(px, py, mask)
% Concatenate pairs across stations where mask==true
    xAll = []; yAll = [];
    for i = find(mask(:).')
        xi = px{i}; yi = py{i};
        if ~isempty(xi) && ~isempty(yi)
            good = isfinite(xi) & isfinite(yi);
            xAll = [xAll; xi(good)]; %#ok<AGROW>
            yAll = [yAll; yi(good)]; %#ok<AGROW>
        end
    end
end
