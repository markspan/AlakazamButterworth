function presets = recommendations()
%RECOMMENDATIONS  The filter settings Zhang, Garrett and Luck (2024)
%   recommend for seven ERP components, as presets.
%
%   PRESETS is a struct array, one element per preset: .label (as the
%   dialog lists it), .component, .measure, .condition ('' for the main
%   recommendation), .highpass and .lowpass (Hz). Every preset is for this
%   filter at ERPLAB's 12 dB per octave (order 2), the filter the
%   recommendations were found with.
%
%   Zhang, G., Garrett, D. R., & Luck, S. J. (2024). Optimal filters for
%   ERP research II: Recommended settings for seven common ERP components.
%   Psychophysiology, 61, e14530. https://doi.org/10.1111/psyp.14530
%   The values are their table for neurotypical young adults, as also
%   published on erpinfo.org (4 February 2024).
%
%   A RECOMMENDATION IS SOMETIMES A RANGE, and a preset needs one number:
%     - "X or more, or none" (most low-passes for amplitude): X, the
%       strongest filter the recommendation allows;
%     - "X to Y": the middle of the range;
%     - "X or less" (the high-pass for latency): X;
%     - "0.01 or none" (the N2pc's high-pass for latency): 0.01.
%   A setting the table gives for particular data (moderate high-frequency
%   noise; moderate broadband noise where distorted onset and offset times
%   can be tolerated; to avoid distorting onset and offset times) is a
%   preset of its own, where it differs from the main one.
%
%   See also BUTTERWORTHFILTER.
    % component, measure, condition, high-pass, low-pass
    rows = {
        'N170', 'mean amplitude',   '', 0.9, 30
        'N170', 'peak amplitude',   '', 0.9, 30
        'N170', 'peak latency',     '', 0.9, 15
        'N170', '50% area latency', '', 0.9, 15
        'MMN',  'mean amplitude',   '', 0.5, 20
        'MMN',  'peak amplitude',   '', 0.5, 20
        'MMN',  'peak amplitude',   'moderate high-frequency noise', 0.5, 30
        'MMN',  'peak latency',     '', 0.5, 10
        'MMN',  'peak latency',     'moderate broadband noise', 0.5, 5
        'MMN',  '50% area latency', '', 0.5, 20
        'N2pc', 'mean amplitude',   '', 0.5, 20
        'N2pc', 'peak amplitude',   '', 0.5, 30
        'N2pc', 'peak amplitude',   'moderate high-frequency noise', 0.5, 20
        'N2pc', 'peak latency',     '', 0.01, 10
        'N2pc', '50% area latency', '', 0.01, 5
        'N2pc', '50% area latency', 'undistorted onset and offset', 0.01, 10
        'P3',   'mean amplitude',   '', 0.2, 10
        'P3',   'peak amplitude',   '', 0.2, 10
        'P3',   'peak latency',     '', 0.2, 10
        'P3',   'peak latency',     'moderate high-frequency noise', 0.2, 5
        'P3',   '50% area latency', '', 0.2, 10
        'P3',   '50% area latency', 'moderate high-frequency noise', 0.2, 5
        'N400', 'mean amplitude',   '', 0.2, 10
        'N400', 'peak amplitude',   '', 0.2, 10
        'N400', 'peak latency',     '', 0.2, 10
        'N400', 'peak latency',     'moderate high-frequency noise', 0.2, 5
        'N400', '50% area latency', '', 0.2, 10
        'N400', '50% area latency', 'moderate high-frequency noise', 0.2, 5
        'LRP',  'mean amplitude',   '', 0.3, 30
        'LRP',  'peak amplitude',   '', 0.3, 30
        'LRP',  'peak amplitude',   'moderate high-frequency noise', 0.3, 20
        'LRP',  'peak latency',     '', 0.3, 5
        'LRP',  'peak latency',     'undistorted onset and offset', 0.3, 10
        'LRP',  '50% area latency', '', 0.3, 5
        'LRP',  '50% area latency', 'undistorted onset and offset', 0.3, 10
        'ERN',  'mean amplitude',   '', 0.4, 20
        'ERN',  'peak amplitude',   '', 0.4, 20
        'ERN',  'peak latency',     '', 0.4, 10
        'ERN',  '50% area latency', '', 0.4, 10
        };
    presets = struct('label', {}, 'component', {}, 'measure', {}, 'condition', {}, ...
        'highpass', {}, 'lowpass', {});
    for r = 1:size(rows, 1)
        [component, measure, condition, highpass, lowpass] = rows{r, :};
        label = sprintf('%s, %s', component, measure);
        if ~isempty(condition)
            label = sprintf('%s (%s)', label, condition);
        end
        label = sprintf('%s: %g to %g Hz', label, highpass, lowpass);
        presets(end + 1) = struct('label', label, 'component', component, ...
            'measure', measure, 'condition', condition, ...
            'highpass', highpass, 'lowpass', lowpass); %#ok<AGROW>
    end
end
