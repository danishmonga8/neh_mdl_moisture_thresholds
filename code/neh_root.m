function r = neh_root()
%NEH_ROOT  Root folder holding the input data and analysis outputs.
%   Uses the environment variable NEH_ROOT when it is set; otherwise the
%   "data" folder next to the "code" folder of this repository.
r = getenv('NEH_ROOT');
if isempty(r)
    here = fileparts(mfilename('fullpath'));
    r = fullfile(fileparts(here), 'data');
end
end
