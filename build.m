function zipFile = build(outFolder)
%BUILD  The plugin as Alakazam's installer takes it: a zip holding the
%   ButterworthFilter folder, named after its version.
%
%   ZIPFILE = build() writes dist/ButterworthFilter-<version>.zip beside
%   this file; build(FOLDER) writes it into FOLDER. Install it in Alakazam
%   with Install on the Alakazam tab, or attach it to a GitHub release, from
%   which a link to the repository installs it.
%
%   The tests, the icon's source and this file stay out of the zip: only
%   the folder Alakazam runs is in it.
    root = fileparts(mfilename('fullpath'));
    if nargin < 1 || isempty(outFolder)
        outFolder = fullfile(root, 'dist');
    end
    if ~isfolder(outFolder)
        mkdir(outFolder);
    end
    manifest = jsondecode(fileread(fullfile(root, 'ButterworthFilter', 'ButterworthFilter.json')));
    zipFile = fullfile(outFolder, sprintf('ButterworthFilter-%s.zip', manifest.Version));
    if isfile(zipFile)
        delete(zipFile);
    end
    zip(zipFile, 'ButterworthFilter', root);
end
