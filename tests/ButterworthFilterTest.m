classdef ButterworthFilterTest < matlab.unittest.TestCase
%BUTTERWORTHFILTERTEST  The plugin filters as ERPLAB's basicfilter does,
%   keeps Alakazam's rejected samples, and records what it did.
%
%   The comparisons call ERPLAB's own basicfilter on the same data and are
%   skipped when ERPLAB is not installed under EEGLAB's plugins folder. The
%   rest needs Alakazam's source: the folder in ALAKAZAM_ROOT, or the
%   Alakazam repository beside this one.
%
%   Run with: runtests('tests/ButterworthFilterTest.m').
%
%   See also BUTTERWORTH.APPLY, PLUGININSTALLTEST.

    properties (Constant)
        Root = fileparts(fileparts(mfilename('fullpath')))
        Srate = 250
    end

    properties
        Erplab = ''
    end

    methods (TestClassSetup)
        function addToPath(testCase)
            alakazam = ButterworthFilterTest.alakazamRoot();
            testCase.assumeTrue(isfolder(alakazam), ...
                'Alakazam''s source is not found (set ALAKAZAM_ROOT).');
            for p = {fullfile(alakazam, 'src'), fullfile(alakazam, 'src', 'Transformations'), ...
                     fullfile(alakazam, 'src', 'Support'), ...
                     fullfile(ButterworthFilterTest.Root, 'ButterworthFilter')}
                testCase.applyFixture(matlab.unittest.fixtures.PathFixture(p{1}));
            end
            testCase.Erplab = ButterworthFilterTest.erplabFunctions();
        end
    end

    methods (Static)
        function root = alakazamRoot()
            root = getenv('ALAKAZAM_ROOT');
            if isempty(root)
                root = fullfile(fileparts(ButterworthFilterTest.Root), 'Alakazam');
            end
        end

        function folder = erplabFunctions()
        %ERPLABFUNCTIONS  ERPLAB's functions folder: on the path already, or
        %   under EEGLAB's plugins in Documents/MATLAB, the newest.
            folder = '';
            onPath = which('basicfilter');
            if ~isempty(onPath)
                folder = fileparts(onPath);
                return;
            end
            home = getenv('USERPROFILE');
            if isempty(home)
                home = getenv('HOME');
            end
            found = dir(fullfile(home, 'Documents', 'MATLAB', 'eeglab', '**', 'plugins', ...
                'erplab*', 'functions', 'basicfilter.m'));
            if ~isempty(found)
                [~, newest] = max([found.datenum]);
                folder = found(newest).folder;
            end
        end
    end

    methods (Test)
        % ---- ERPLAB's filter ------------------------------------------------
        function aBandPassIsErplabsOnAContinuousRecording(testCase)
        %   0.1 to 30 Hz at 12 dB per octave, Luck's long-standing default,
        %   across a boundary event, which cuts the recording in two.
            EEG = ButterworthFilterTest.continuous();
            ours = ButterworthFilterTest.filtered(EEG, 0.1, 30, 2, false);
            theirs = testCase.erplab(EEG, 0.1, 30, 2, false);
            testCase.verifyEqual(ours.data, theirs.data, 'AbsTol', 1e-9);
        end

        function aHighPassWithDcRemovalIsErplabs(testCase)
            EEG = ButterworthFilterTest.continuous();
            EEG.data = EEG.data + 40;   % an offset for the DC removal to take off
            ours = ButterworthFilterTest.filtered(EEG, 0.5, 0, 2, true);
            theirs = testCase.erplab(EEG, 0.5, 0, 2, true);
            testCase.verifyEqual(ours.data, theirs.data, 'AbsTol', 1e-9);
        end

        function aSteeperLowPassIsErplabs(testCase)
            EEG = ButterworthFilterTest.continuous();
            ours = ButterworthFilterTest.filtered(EEG, 0, 20, 4, false);
            theirs = testCase.erplab(EEG, 0, 20, 4, false);
            testCase.verifyEqual(ours.data, theirs.data, 'AbsTol', 1e-9);
        end

        function epochsAreFilteredOneAtATimeAsErplab(testCase)
            EEG = ButterworthFilterTest.epoched();
            ours = ButterworthFilterTest.filtered(EEG, 0.9, 30, 2, false);
            theirs = testCase.erplab(EEG, 0.9, 30, 2, false);
            testCase.verifyEqual(ours.data, theirs.data, 'AbsTol', 1e-9);
        end

        % ---- Alakazam's rejected samples -------------------------------------
        function aRejectedStretchStaysRejectedAndSplitsTheFilter(testCase)
        %   ERPLAB's data have no NaN; Alakazam marks a rejection with it.
        %   The rejected samples stay NaN, the other channels are filtered as
        %   if nothing had happened, and the rejected channel is filtered on
        %   either side of the stretch separately.
            EEG = ButterworthFilterTest.continuous();
            EEG.event = struct('type', {}, 'latency', {});
            gap = 1801:1900;
            withGap = EEG;
            withGap.data(2, gap) = NaN;

            whole = ButterworthFilterTest.filtered(EEG, 0.1, 30, 2, false);
            split = ButterworthFilterTest.filtered(withGap, 0.1, 30, 2, false);

            testCase.verifyTrue(all(isnan(split.data(2, gap))), 'The rejected samples stay rejected.');
            testCase.verifyEqual(split.data([1 3 4], :), whole.data([1 3 4], :), 'AbsTol', 1e-12);
            before = EEG; before.data = EEG.data(2, 1:gap(1) - 1); before.nbchan = 1;
            before.pnts = size(before.data, 2); before.chanlocs = EEG.chanlocs(2);
            expected = ButterworthFilterTest.filtered(before, 0.1, 30, 2, false);
            testCase.verifyEqual(split.data(2, 1:gap(1) - 1), expected.data, 'AbsTol', 1e-12);
        end

        function aSegmentTooShortToFilterIsLeftAndCounted(testCase)
        %   basicfilter leaves a segment of no more than 3 x order samples as
        %   it is; so does this, and says how many.
            EEG = ButterworthFilterTest.continuous();
            EEG.event = struct('type', {'boundary', 'boundary'}, 'latency', {2000.5, 2004.5});
            out = ButterworthFilterTest.filtered(EEG, 0.1, 30, 2, false);
            testCase.verifyEqual(out.data(:, 2001:2004), EEG.data(:, 2001:2004));
            testCase.verifyEqual(out.etc.alz.butterworth.shortStretches, 1);
        end

        % ---- the filter's shape ------------------------------------------------
        function halfTheAmplitudeIsLeftAtTheCutoff(testCase)
        %   ERPLAB's cutoff: -6 dB, half the amplitude, once the filter has
        %   run forward and backward.
            for order = [2 4]
                [b, a] = Butterworth.design('high', 1, order, 250);
                h = abs(freqz(b, a, [1 1], 250)) .^ 2;
                testCase.verifyEqual(h(1), 0.5, 'AbsTol', 1e-9);
                [b, a] = Butterworth.design('low', 30, order, 250);
                h = abs(freqz(b, a, [30 30], 250)) .^ 2;
                testCase.verifyEqual(h(1), 0.5, 'AbsTol', 1e-9);
            end
        end

        function eachOrderIsSixDbPerOctave(testCase)
        %   Far below a high-pass's cutoff the gain falls by 6 dB per octave
        %   for each order of the forward-and-backward filter: 12 for ERPLAB's
        %   order 2, 24 for order 4.
            for order = [2 4]
                [b, a] = Butterworth.design('high', 2, order, 250);
                h = abs(freqz(b, a, [0.01 0.02], 250)) .^ 2;
                testCase.verifyEqual(20 * log10(h(2) / h(1)), 6 * order, 'AbsTol', 0.1);
            end
        end

        % ---- refusals ----------------------------------------------------------
        function aBandStopIsRefused(testCase)
            EEG = ButterworthFilterTest.continuous();
            testCase.verifyError(@() ButterworthFilterTest.filtered(EEG, 30, 10, 2, false), ...
                'ButterworthFilter:bandstop');
        end

        function anOddOrderAndACutoffAboveNyquistAreRefused(testCase)
            testCase.verifyError(@() Butterworth.design('low', 30, 3, 250), 'ButterworthFilter:order');
            testCase.verifyError(@() Butterworth.design('low', 125, 2, 250), 'ButterworthFilter:cutoff');
        end

        % ---- the presets --------------------------------------------------------
        function thePresetsAreThePublishedTable(testCase)
        %   A few cells of Zhang, Garrett and Luck's table, and the rules for
        %   turning a range into one number (Butterworth.recommendations).
            p = Butterworth.recommendations();
            pick = @(c, m, cond) p(strcmp({p.component}, c) & strcmp({p.measure}, m) ...
                & strcmp({p.condition}, cond));
            testCase.verifyEqual([pick('N170', 'mean amplitude', '').highpass, ...
                pick('N170', 'mean amplitude', '').lowpass], [0.9 30]);
            testCase.verifyEqual([pick('N400', 'mean amplitude', '').highpass, ...
                pick('N400', 'mean amplitude', '').lowpass], [0.2 10]);
            testCase.verifyEqual(pick('N2pc', 'peak amplitude', '').lowpass, 30, ...
                '20 to 40 Hz: the middle of the range.');
            testCase.verifyEqual(pick('N2pc', 'peak latency', '').highpass, 0.01);
            testCase.verifyEqual(pick('LRP', 'peak latency', 'undistorted onset and offset').lowpass, 10);
            testCase.verifyEqual(numel(unique({p.component})), 7);
            testCase.verifyEqual(numel(unique({p.label})), numel(p), 'Each preset has its own label.');
        end

        function aPresetSetsItsCutoffsAndTwelveDbPerOctave(testCase)
            options = ButterworthFilterTest.options(0.1, 30, 4, false);
            options.Preset = 'N400, mean amplitude: 0.2 to 10 Hz';
            options = Butterworth.fromPreset(options);
            testCase.verifyEqual([options.HighpassHz, options.LowpassHz], [0.2 10]);
            testCase.verifyEqual(options.Rolloff, '12');
            custom = Butterworth.fromPreset(ButterworthFilterTest.options(0.1, 30, 4, false));
            testCase.verifyEqual(custom.Rolloff, '24', 'Custom leaves the settings alone.');
        end

        % ---- Alakazam's contract --------------------------------------------------
        function aReplayThroughAlakazamRecordsWhatItDid(testCase)
            EEG = ButterworthFilterTest.continuous();
            options = ButterworthFilterTest.options(0.1, 30, 2, false);
            options.Channels = {'Fz', 'Pz'};
            [out, back] = TransTools.invoke('ButterworthFilter', EEG, options);
            testCase.verifyEqual(back, options);
            testCase.verifyEqual(out.data([1 3], :), EEG.data([1 3], :), 'Unchosen channels are untouched.');
            record = out.etc.alz.butterworth;
            testCase.verifyEqual([record.highpassHz, record.lowpassHz, record.order, ...
                record.rolloffDbPerOctave], [0.1 30 2 12]);
            testCase.verifyEqual(record.channels, {'Fz', 'Pz'});
            testCase.verifyEqual(record.plugin, ['ButterworthFilter ' Butterworth.version()]);
            testCase.verifyEqual(record.segments, 2, 'The boundary cuts the recording in two.');
        end

        function theManifestAndTheCodeAgreeOnTheVersion(testCase)
            manifest = jsondecode(fileread(fullfile(ButterworthFilterTest.Root, ...
                'ButterworthFilter', 'ButterworthFilter.json')));
            testCase.verifyEqual(manifest.Version, Butterworth.version());
            testCase.verifyEqual(manifest.Entry, 'ButterworthFilter.m');
        end
    end

    methods (Access = private)
        function out = erplab(testCase, EEG, highpass, lowpass, order, removeDC)
        %ERPLAB  ERPLAB's basicfilter on every channel, Butterworth design,
        %   segments cut at 'boundary' events.
            testCase.assumeNotEmpty(testCase.Erplab, 'ERPLAB is not installed.');
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(testCase.Erplab));
            [~, out] = evalc(['basicfilter(EEG, 1:EEG.nbchan, highpass, lowpass, order, ' ...
                '0, removeDC, ''boundary'')']);
        end
    end

    methods (Static, Access = private)
        function out = filtered(EEG, highpass, lowpass, order, removeDC)
            options = ButterworthFilterTest.options(highpass, lowpass, order, removeDC);
            out = ButterworthFilter(EEG, options);
        end

        function options = options(highpass, lowpass, order, removeDC)
            options = struct('Preset', 'Custom', 'Highpass', highpass > 0, ...
                'HighpassHz', max(highpass, 0.1), 'Lowpass', lowpass > 0, ...
                'LowpassHz', max(lowpass, 1), 'Rolloff', num2str(6 * order), ...
                'RemoveDC', removeDC, 'Channels', {{'Fp1', 'Fz', 'Cz', 'Pz'}});
        end

        function EEG = continuous()
        %CONTINUOUS  Four channels, 20 s at 250 Hz: a slow drift, alpha, line
        %   noise and white noise, with a boundary event 8 s in.
            rng(7, 'twister');
            srate = ButterworthFilterTest.Srate;
            t = (0:20 * srate - 1) / srate;
            data = zeros(4, numel(t));
            for c = 1:4
                data(c, :) = 30 * cumsum(randn(size(t))) / sqrt(numel(t)) ...
                    + 8 * sin(2 * pi * 10 * t + c) + 3 * sin(2 * pi * 50 * t) + 5 * randn(size(t));
            end
            EEG = struct('data', data, 'srate', srate, 'nbchan', 4, 'pnts', numel(t), ...
                'trials', 1, 'xmin', 0, 'xmax', t(end), 'times', t, 'epoch', [], ...
                'event', struct('type', {'boundary'}, 'latency', {2000.5}), ...
                'chanlocs', struct('labels', {'Fp1', 'Fz', 'Cz', 'Pz'}), ...
                'DataFormat', 'CONTINUOUS', 'etc', struct());
        end

        function EEG = epoched()
        %EPOCHED  The same signal cut into five 2-second epochs.
            EEG = ButterworthFilterTest.continuous();
            n = 2 * EEG.srate;
            EEG.data = reshape(EEG.data(:, 1:5 * n), 4, n, 5);
            EEG.pnts = n;
            EEG.trials = 5;
            EEG.times = (0:n - 1) / EEG.srate * 1000 - 200;
            EEG.xmin = -0.2;
            EEG.xmax = EEG.times(end) / 1000;
            EEG.epoch = struct('event', num2cell(1:5));
            EEG.event = struct('type', {}, 'latency', {});
            EEG.DataFormat = 'EPOCHED';
        end
    end
end
