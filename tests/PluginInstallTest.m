classdef PluginInstallTest < matlab.unittest.TestCase
%PLUGININSTALLTEST  The built zip installs through Alakazam's own installer,
%   as a user's Install would put it in, and comes out again.
%
%   Run without the plugin's source on the path: the installer refuses a
%   plugin whose name is already a function on the path. Plugins go into a
%   temporary folder (ALAKAZAM_PLUGIN_FOLDER), not the real one.
%
%   Run with: runtests('tests/PluginInstallTest.m').
%
%   See also PLUGINS (Alakazam), BUILD.

    properties (Constant)
        Root = fileparts(fileparts(mfilename('fullpath')))
    end

    properties
        Alakazam = ''
        Zip = ''
    end

    methods (TestClassSetup)
        function prepare(testCase)
            testCase.Alakazam = getenv('ALAKAZAM_ROOT');
            if isempty(testCase.Alakazam)
                testCase.Alakazam = fullfile(fileparts(PluginInstallTest.Root), 'Alakazam');
            end
            testCase.assumeTrue(isfolder(testCase.Alakazam), ...
                'Alakazam''s source is not found (set ALAKAZAM_ROOT).');
            testCase.assumeEmpty(which('ButterworthFilter'), ...
                'The plugin is on the path already, which the installer would refuse.');
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(fullfile(testCase.Alakazam, 'src')));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(PluginInstallTest.Root));
            out = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture).Folder;
            testCase.Zip = build(out);
        end
    end

    methods (TestMethodSetup)
        function ownPluginFolder(testCase)
            folder = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture).Folder;
            previous = getenv('ALAKAZAM_PLUGIN_FOLDER');
            testCase.addTeardown(@() setenv('ALAKAZAM_PLUGIN_FOLDER', previous));
            setenv('ALAKAZAM_PLUGIN_FOLDER', folder);
            before = path();
            testCase.addTeardown(@() path(before));
        end
    end

    methods (Test)
        function theInstallerFindsItAndHasNoObjection(testCase)
            candidate = Plugins.prepare(testCase.Zip, ...
                'BuiltInRoot', fullfile(testCase.Alakazam, 'src', 'Transformations'));
            testCase.addTeardown(@() Plugins.discard(candidate));
            testCase.assertNumElements(candidate.Plugins, 1);
            plugin = candidate.Plugins;
            testCase.verifyEqual(plugin.Name, 'ButterworthFilter');
            testCase.verifyEqual(plugin.Version, Butterworth_versionFromZip(testCase.Zip));
            testCase.verifyEmpty(plugin.Problems, strjoin(plugin.Problems, ' '));
            testCase.verifyEmpty(plugin.Warnings, strjoin(plugin.Warnings, ' '));
        end

        function itInstallsRunsAndUninstalls(testCase)
            candidate = Plugins.prepare(testCase.Zip, ...
                'BuiltInRoot', fullfile(testCase.Alakazam, 'src', 'Transformations'));
            names = Plugins.install(candidate);
            testCase.verifyEqual(names, {'ButterworthFilter'});
            installed = fullfile(Plugins.folder(), 'ButterworthFilter', 'ButterworthFilter.m');
            testCase.verifyEqual(which('ButterworthFilter'), installed);
            testCase.verifyNotEmpty(which('Butterworth.apply'), 'Its package comes with it.');
            listed = Plugins.installed();
            testCase.verifyTrue(any(strcmp({listed.Name}, 'ButterworthFilter')));

            Plugins.uninstall('ButterworthFilter');
            testCase.verifyEmpty(which('ButterworthFilter'));
        end
    end
end

function v = Butterworth_versionFromZip(zipFile)
%   The version the zip's own manifest gives, which the summary shows.
    [~, name] = fileparts(zipFile);
    v = regexprep(name, '^ButterworthFilter-', '');
end
