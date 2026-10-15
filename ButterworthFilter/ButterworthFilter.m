function [EEG, options] = ButterworthFilter(input, varargin)
%BUTTERWORTHFILTER  Butterworth high-pass, low-pass and band-pass filtering,
%   as ERPLAB's basicfilter does it. An Alakazam plugin.
%
%   The filter is ERPLAB's: a Butterworth IIR whose cutoff is the frequency
%   at which the amplitude is halved, with a roll-off of 12, 24, 36 or 48 dB
%   per octave, run forward and backward so that it shifts nothing in time
%   (Butterworth.design, Butterworth.apply). On data without rejected
%   samples the result is ERPLAB's, which ButterworthFilterTest checks
%   against basicfilter itself.
%
%   WHY IT EXISTS. Zhang, Garrett and Luck (2024) recommend filter settings
%   for seven ERP components and four ways of scoring them, and found them
%   with this filter at 12 dB per octave. Alakazam's own Filter is
%   EEGLAB's windowed-sinc FIR, whose roll-off is far steeper, and the
%   distortion a filter causes depends on its slope as well as on its
%   cutoff; so the recommendations are known to hold for this filter. They
%   are offered as presets (Butterworth.recommendations).
%
%   OPTIONS, all plain data so that a template replays them:
%     .Preset       'Custom', or the label of a recommendation; a preset's
%                   cutoffs and its 12 dB per octave are written into the
%                   fields below when it is chosen, so a replay does not
%                   depend on the table
%     .Highpass     true to apply the high-pass, at .HighpassHz
%     .Lowpass      true to apply the low-pass, at .LowpassHz
%     .Rolloff      '12', '24', '36' or '48' (dB per octave; order 2 to 8)
%     .RemoveDC     subtract each segment's mean over its first half
%                   second first, as ERPLAB's option does (high-pass only)
%     .Channels     the channels to filter, by label
%
%   EEG.etc.alz.butterworth records what was done: the cutoffs, the order
%   and roll-off, the preset, the channels, how many segments were too short
%   to filter, and this plugin's version.
%
%   Signature (Alakazam transformation contract):
%     [EEG, options] = ButterworthFilter(input)        % interactive
%     [EEG, options] = ButterworthFilter(input, opts)  % replay
%
%   See also BUTTERWORTH.APPLY, BUTTERWORTH.RECOMMENDATIONS.
[opts, interactive] = TransTools.InitGuard(nargin, 'ButterworthFilter:init', varargin{:});
if ~isfield(input, 'data') || isempty(input.data) || ~isfield(input, 'srate') || isempty(input.srate)
    throw(MException('ButterworthFilter:data', ['I''m afraid this dataset has no data, ' ...
        'or no sample rate, so there is nothing here for me to filter.']));
end
labels = channelLabels(input);

if interactive
    options = askForOptions(input, labels);
    if isempty(options)
        EEG = [];       % cancelled: no node, no compute
        options = [];
        return;
    end
    TransformSettings.set('ButterworthFilter', options);
else
    options = opts;
end

channels = TransTools.LabelsToIdx(input, cellstr(options.Channels));
if isempty(channels)
    throw(MException('ButterworthFilter:channels', ['I''m afraid none of the channels ' ...
        'to filter (%s) is in this dataset.'], strjoin(cellstr(options.Channels), ', ')));
end
settings = struct( ...
    'highpass', onOrOff(options.Highpass, options.HighpassHz), ...
    'lowpass', onOrOff(options.Lowpass, options.LowpassHz), ...
    'order', rolloffOrder(options.Rolloff), ...
    'removeDC', logical(options.RemoveDC), ...
    'channels', channels);

[EEG, record] = Butterworth.apply(input, settings);
record.preset = char(options.Preset);
record.channels = labels(channels);
record.plugin = ['ButterworthFilter ' Butterworth.version()];
EEG.etc.alz.butterworth = record;
end

% ======================================================================= %
function options = askForOptions(input, labels)
%ASKFOROPTIONS  The dialog, seeded from the last run's settings. A preset
%   greys out the settings it decides, and its values are written into
%   them on OK.
    stored = TransformSettings.get('ButterworthFilter');
    if isempty(stored) || ~isstruct(stored)
        stored = struct();
    end
    d = @(f, v) TransTools.FieldOr(stored, f, v);
    presets = Butterworth.recommendations();
    custom = @(v) strcmp(v.Preset, 'Custom');
    srate = double(input.srate);
    options = TransformOptionsDialog( ...
        'title', 'Butterworth filter options', ...
        'Description', ['A Butterworth filter as ERPLAB''s: the cutoff is where the ' ...
            'amplitude is halved, and the filter runs forward and backward, so nothing ' ...
            'shifts in time. A recommendation of Zhang, Garrett and Luck (2024) sets the ' ...
            'cutoffs and 12 dB per octave, the filter it was found with. Filter the ' ...
            'continuous recording, before epoching.'], ...
        'separator', 'Settings:', ...
        {'Recommended for'; 'Preset'}, DialogFields.Choice([{'Custom'}, {presets.label}], ...
            d('Preset', 'Custom')), ...
        {'High-pass'; 'Highpass'}, DialogFields.Checkbox(logical(d('Highpass', true)), ...
            'EnabledWhen', custom), ...
        {'High-pass cutoff (Hz)'; 'HighpassHz'}, DialogFields.Number(d('HighpassHz', 0.1), ...
            'Limits', [0 Inf], 'EnabledWhen', @(v) custom(v) && v.Highpass), ...
        {'Low-pass'; 'Lowpass'}, DialogFields.Checkbox(logical(d('Lowpass', true)), ...
            'EnabledWhen', custom), ...
        {'Low-pass cutoff (Hz)'; 'LowpassHz'}, DialogFields.Number(d('LowpassHz', 30), ...
            'Limits', [0 Inf], 'EnabledWhen', @(v) custom(v) && v.Lowpass), ...
        {'Roll-off'; 'Rolloff'}, DialogFields.Choice( ...
            {'12 dB per octave', '24 dB per octave', '36 dB per octave', '48 dB per octave'}, ...
            d('Rolloff', '12'), 'Values', {'12', '24', '36', '48'}, 'EnabledWhen', custom), ...
        {'Remove the DC offset first'; 'RemoveDC'}, DialogFields.Checkbox(logical(d('RemoveDC', false))), ...
        'separator', 'Channels:', ...
        {'Channels'; 'Channels'}, DialogFields.Channels(input, d('Channels', labels), ...
            'Required', true), ...
        {'Amplitude response, forward and backward'; 'Response'}, DialogFields.FrequencyResponse( ...
            @(v) response(Butterworth.fromPreset(v, presets), srate)));
    if ~isempty(options)
        options = Butterworth.fromPreset(options, presets);
    end
end

function [f, gain, cutoffs] = response(v, srate)
%RESPONSE  The amplitude response of the filter as it will be applied
%   (forward and backward, so the gain of one pass squared) and its
%   cutoffs, for Alakazam's DialogFields.FrequencyResponse to draw. A
%   setting the filter would refuse is refused here, and the plot shows why.
    highpass = onOrOff(v.Highpass, v.HighpassHz);
    lowpass = onOrOff(v.Lowpass, v.LowpassHz);
    order = rolloffOrder(v.Rolloff);
    if highpass > 0 && lowpass > 0 && lowpass <= highpass
        error('ButterworthFilter:bandstop', 'The low-pass must lie above the high-pass.');
    end
    f = logspace(log10(0.01), log10(0.999 * srate / 2), 600);
    gain = ones(size(f));
    if lowpass > 0
        [b, a] = Butterworth.design('low', lowpass, order, srate);
        gain = gain .* abs(freqz(b, a, f, srate)) .^ 2;
    end
    if highpass > 0
        [b, a] = Butterworth.design('high', highpass, order, srate);
        gain = gain .* abs(freqz(b, a, f, srate)) .^ 2;
    end
    cutoffs = [highpass, lowpass];
end

function hz = onOrOff(enabled, value)
    hz = 0;
    if logical(enabled)
        hz = double(value);
    end
end

function order = rolloffOrder(rolloff)
%ROLLOFFORDER  ERPLAB's order for a roll-off: 6 dB per octave per order.
    order = str2double(char(string(rolloff))) / 6;
    if ~ismember(order, [2 4 6 8])
        throw(MException('ButterworthFilter:rolloff', ['I''m afraid a roll-off of %s dB ' ...
            'per octave is not one offered here: 12, 24, 36 or 48.'], char(string(rolloff))));
    end
end

function labels = channelLabels(EEG)
    if isfield(EEG, 'chanlocs') && ~isempty(EEG.chanlocs) && isfield(EEG.chanlocs, 'labels')
        labels = {EEG.chanlocs.labels};
    else
        labels = arrayfun(@(i) sprintf('ch%d', i), 1:size(EEG.data, 1), 'UniformOutput', false);
    end
end
