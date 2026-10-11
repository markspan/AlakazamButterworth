function options = fromPreset(options, presets)
%FROMPRESET  The settings a preset decides, written into OPTIONS.
%
%   OPTIONS = Butterworth.fromPreset(OPTIONS) gives OPTIONS the cutoffs of
%   the recommendation OPTIONS.Preset names (Butterworth.recommendations),
%   both filters on, and 12 dB per octave, the roll-off the recommendations
%   were found with. 'Custom', or a label the table does not hold, leaves
%   OPTIONS as it is. PRESETS, when given, is the table to look in.
%
%   The dialog does this on OK, so a stored run carries its cutoffs and
%   replays the same whatever a later version's table says.
%
%   See also BUTTERWORTH.RECOMMENDATIONS, BUTTERWORTHFILTER.
    if nargin < 2
        presets = Butterworth.recommendations();
    end
    if ~isfield(options, 'Preset') || strcmp(options.Preset, 'Custom')
        return;
    end
    p = presets(strcmp({presets.label}, options.Preset));
    if isempty(p)
        return;
    end
    options.Highpass = true;
    options.HighpassHz = p(1).highpass;
    options.Lowpass = true;
    options.LowpassHz = p(1).lowpass;
    options.Rolloff = '12';
end
