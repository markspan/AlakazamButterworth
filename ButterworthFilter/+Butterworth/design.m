function [b, a] = design(kind, cutoff, order, srate)
%DESIGN  The Butterworth filter ERPLAB's basicfilter makes, as its
%   coefficients.
%
%   [B, A] = Butterworth.design(KIND, CUTOFF, ORDER, SRATE) is
%   butter(ORDER/2, CUTOFF/(SRATE/2)) for KIND 'low', and the same with
%   'high' for KIND 'high', exactly as ERPLAB's filter_tf designs its
%   Butterworth filters. The filter is meant to be applied forward and
%   backward (filtfilt), which doubles the order to ORDER and squares the
%   gain, so that the -3 dB of one pass becomes -6 dB, half the amplitude,
%   at CUTOFF: ERPLAB's half-amplitude cutoff. Each order of the doubled
%   filter is 6 dB per octave, so ORDER 2 is ERPLAB's 12 dB per octave.
%
%   ORDER must be even and at least 2, as ERPLAB requires; CUTOFF must lie
%   between 0 and the Nyquist frequency.
%
%   See also BUTTERWORTH.APPLY, BUTTER, FILTFILT.
    if ~isscalar(order) || order < 2 || mod(order, 2) ~= 0
        throw(MException('ButterworthFilter:order', ['I''m afraid the filter order ' ...
            'must be an even number of at least 2 (it is run forward and backward, ' ...
            'which doubles the order of a single pass), not %s.'], num2str(order)));
    end
    nyquist = srate / 2;
    if ~isscalar(cutoff) || ~(cutoff > 0 && cutoff < nyquist)
        throw(MException('ButterworthFilter:cutoff', ['I''m afraid a cutoff of %s Hz ' ...
            'is outside what a sample rate of %g Hz allows: it must lie between 0 and ' ...
            '%g Hz, the Nyquist frequency.'], num2str(cutoff), srate, nyquist));
    end
    switch kind
        case 'low'
            [b, a] = butter(order / 2, cutoff / nyquist);
        case 'high'
            [b, a] = butter(order / 2, cutoff / nyquist, 'high');
        otherwise
            throw(MException('ButterworthFilter:kind', ...
                'I''m afraid "%s" is not a kind of filter here: low or high.', kind));
    end
end
