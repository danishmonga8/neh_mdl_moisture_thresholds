%% ============================================================
%  Helper function: clean WMO / station ID
%% ============================================================

function s = cleanWMO(x)

    if isnumeric(x)
        s = string(num2str(x));
    else
        s = string(x);
    end

    s = strtrim(s);
    s = regexprep(s, "\.0+$", "");
    s = regexprep(s, "[^\w]", "");

end

