%% ============================================================
%  Helper function: resolve station-specific file path
%% ============================================================

function fpath = resolveWmoFile(baseDir, wmoIn, ext, prefix, optimalLag)

    if nargin < 5
        optimalLag = [];
    end

    wmo = cleanWMO(wmoIn);

    if strcmp(prefix, "_trigging")
        fileName = @(id) sprintf("%s%s%s", id, prefix, ext);

    elseif isempty(optimalLag)
        fileName = @(id) sprintf("%s%s%s", prefix, id, ext);

    else
        fileName = @(id) sprintf("%s%s_%d_crozier_5%s", ...
            prefix, id, optimalLag, ext);
    end

    fpath = fullfile(baseDir, fileName(wmo));

end