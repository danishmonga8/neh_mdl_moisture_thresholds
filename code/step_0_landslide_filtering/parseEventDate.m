

%% ========================================================================
% FUNCTION 1 -- ROBUST EVENT DATE PARSER
%% ========================================================================

function dt = parseEventDate(x)

    n = numel(x);

    dt = NaT(n,1);


    %% --------------------------------------------------------------------
    % If MATLAB already imported the column as datetime
    %% --------------------------------------------------------------------

    if isdatetime(x)

        temp = x(:);

        good = ~isnat(temp);

        dt(good) = ...
            dateshift( ...
            temp(good), ...
            'start','day');

        return

    end


    %% --------------------------------------------------------------------
    % Convert input safely to strings
    %% --------------------------------------------------------------------

    s = strip( ...
        string(x(:)));


    s(ismissing(s)) = "";


    % Remove common literal missing-value representations
    badText = ...
        s == "" | ...
        lower(s) == "nan" | ...
        lower(s) == "nat" | ...
        lower(s) == "missing" | ...
        lower(s) == "<missing>";


    s(badText) = "";


    %% --------------------------------------------------------------------
    % Parse one row at a time.
    %
    % This is intentionally conservative and avoids one malformed record
    % causing the whole datetime() call to fail.
    %% --------------------------------------------------------------------

    for i = 1:n

        if strlength(s(i)) == 0
            continue
        end


        thisDate = NaT;


        %% ----------------------------------------------------------------
        % Most important case:
        %
        % YYYY-MM-DD
        %
        % Also works for a timestamp beginning YYYY-MM-DD...
        %% ----------------------------------------------------------------

        txt = char(s(i));


        hasISOstart = ...
            ~isempty( ...
            regexp( ...
            txt, ...
            '^\d{4}-\d{2}-\d{2}', ...
            'once'));


        if hasISOstart

            datePart = string( ...
                txt(1:10));


            try

                thisDate = datetime( ...
                    datePart, ...
                    'InputFormat','yyyy-MM-dd');

            catch

                thisDate = NaT;

            end

        end


        %% ----------------------------------------------------------------
        % Other possible formats, only if necessary
        %% ----------------------------------------------------------------

        if isnat(thisDate)

            formats = [ ...
                "dd-MMM-yyyy", ...
                "dd/MM/yyyy", ...
                "MM/dd/yyyy", ...
                "yyyy/MM/dd", ...
                "dd-MM-yyyy"];


            for f = 1:numel(formats)

                try

                    testDate = datetime( ...
                        s(i), ...
                        'InputFormat',formats(f));


                    if ~isnat(testDate)

                        thisDate = testDate;
                        break

                    end

                catch
                    % Try next format
                end

            end

        end


        %% ----------------------------------------------------------------
        % Last-resort MATLAB automatic interpretation
        %% ----------------------------------------------------------------

        if isnat(thisDate)

            try

                thisDate = datetime(s(i));

            catch

                thisDate = NaT;

            end

        end


        if ~isnat(thisDate)

            dt(i) = dateshift( ...
                thisDate, ...
                'start','day');

        end

    end

end


