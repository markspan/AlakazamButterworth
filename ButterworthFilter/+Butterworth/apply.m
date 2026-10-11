function [EEG, record] = apply(EEG, settings)
%APPLY  Filter a dataset with ERPLAB's Butterworth filter, as ERPLAB's
%   basicfilter does it.
%
%   [EEG, RECORD] = Butterworth.apply(EEG, SETTINGS) filters the channels
%   SETTINGS.channels (indices) of EEG with a high-pass at SETTINGS.highpass
%   Hz and a low-pass at SETTINGS.lowpass Hz (0 leaves either out), of
%   order SETTINGS.order (Butterworth.design), each run forward and
%   backward with filtfilt. RECORD says what was done.
%
%   WHAT IS ERPLAB'S, kept exactly, so that the result is ERPLAB's
%   (ButterworthFilterTest holds it to basicfilter):
%     - with both, a band-pass: the low-pass first, then the high-pass,
%       each forward and backward;
%     - a continuous recording is filtered in the segments its boundary
%       events mark off, each event's latency less half a sample rounded
%       to a sample, as basicfilter cuts them; an epoched dataset and an
%       average are filtered one trial, or one bin, at a time;
%     - a segment of no more than 3 x ORDER samples is left as it is, as
%       basicfilter leaves it, and counted in RECORD.shortStretches;
%     - SETTINGS.removeDC, with a high-pass only, first subtracts from each
%       segment, per channel, the mean of its first half second
%       (round(srate/2) samples), as basicfilter's removedc does.
%   ERPLAB refuses a low-pass at or below the high-pass, where it would
%   make a band-stop; so does this.
%
%   WHAT IS ALAKAZAM'S. A rejected sample is NaN in Alakazam, where ERPLAB's
%   data have none, and filtfilt would spread one NaN over the whole
%   segment. Within a segment, a channel's finite runs are therefore
%   filtered one at a time, as Alakazam's own Filter does with a designed
%   IIR filter; a run of no more than 3 x ORDER samples is left as it is,
%   by ERPLAB's rule for a short segment, and counted. The mean removedc
%   subtracts leaves NaN out. On data without NaN this changes nothing.
%
%   See also BUTTERWORTH.DESIGN, BUTTERWORTHFILTER.
    srate = double(EEG.srate);
    highpass = double(settings.highpass);
    lowpass = double(settings.lowpass);
    order = double(settings.order);
    if highpass <= 0 && lowpass <= 0
        throw(MException('ButterworthFilter:nothing', ['I''m afraid there is nothing ' ...
            'to filter with: neither a high-pass nor a low-pass is set.']));
    end
    if highpass > 0 && lowpass > 0 && lowpass <= highpass
        throw(MException('ButterworthFilter:bandstop', ['I''m afraid a low-pass at %g Hz ' ...
            'and a high-pass at %g Hz leave no band to pass: the low-pass must lie above ' ...
            'the high-pass. (ERPLAB makes a band-stop of this; this filter does not.)'], ...
            lowpass, highpass));
    end

    % ERPLAB's filter_tf order: the low-pass first, then the high-pass.
    filters = {};
    if lowpass > 0
        [b, a] = Butterworth.design('low', lowpass, order, srate);
        filters{end + 1} = {b, a};
    end
    if highpass > 0
        [b, a] = Butterworth.design('high', highpass, order, srate);
        filters{end + 1} = {b, a};
    end

    data = double(EEG.data);
    [~, nPnts, nPages] = size(data);
    edges = segmentEdges(EEG, nPnts, nPages);
    channels = reshape(settings.channels, 1, []);
    minimum = 3 * order;               % basicfilter's: more samples than this
    dcWindow = round(srate / 2);       % basicfilter's removedc window
    removeDC = logical(settings.removeDC) && highpass > 0;

    shortStretches = 0;
    for page = 1:nPages
        for q = 1:numel(edges) - 1
            span = edges(q) + 1:edges(q + 1);
            if numel(span) <= minimum
                shortStretches = shortStretches + 1;
                continue;
            end
            block = data(channels, span, page);
            if removeDC
                block = removeDcAsErplab(block, dcWindow);
            end
            if all(isfinite(block(:)))
                block = filterBlock(block, filters);
            else
                [block, short] = filterRuns(block, filters, minimum);
                shortStretches = shortStretches + short;
            end
            data(channels, span, page) = block;
        end
    end
    EEG.data = data;

    record = struct( ...
        'highpassHz', highpass, ...
        'lowpassHz', lowpass, ...
        'order', order, ...
        'rolloffDbPerOctave', 6 * order, ...
        'cutoff', 'half amplitude (-6 dB), the filter run forward and backward', ...
        'design', 'butter(order/2) applied forward and backward with filtfilt, as ERPLAB''s basicfilter', ...
        'removeDC', removeDC, ...
        'segments', (numel(edges) - 1) * nPages, ...
        'shortStretches', shortStretches);
end

% ======================================================================= %
function edges = segmentEdges(EEG, nPnts, nPages)
%SEGMENTEDGES  Where basicfilter cuts the data: at each boundary event of a
%   continuous recording, the latency less half a sample, rounded; an
%   epoched dataset or an average whole, one trial or bin at a time. The
%   segments are edges(q)+1:edges(q+1).
    edges = [0, nPnts];
    if nPages > 1 || ~strcmpi(char(string(fieldOr(EEG, 'DataFormat', 'CONTINUOUS'))), 'CONTINUOUS') ...
            || ~isempty(fieldOr(EEG, 'epoch', []))
        return;
    end
    events = fieldOr(EEG, 'event', struct([]));
    if isempty(events) || ~isfield(events, 'type') || ~isfield(events, 'latency')
        return;
    end
    isBoundary = arrayfun(@(e) ischar(e.type) && strcmp(e.type, 'boundary'), events);
    if ~any(isBoundary)
        return;
    end
    latencies = sort([events(isBoundary).latency]);
    edges = round([0, latencies - 0.5, nPnts]);
    edges = [0, edges(edges > 2)];
end

function block = removeDcAsErplab(block, window)
%REMOVEDCASERPLAB  removedc(data, round(srate/2)): each channel less its
%   mean over the first WINDOW samples, or over all of them when the
%   segment is shorter, NaN left out.
    n = size(block, 2);
    if window - 1 > n
        window = n;
    end
    window = min(window, n);
    block = block - mean(block(:, 1:window), 2, 'omitnan');
end

function block = filterBlock(block, filters)
%FILTERBLOCK  Each filter in turn, forward and backward, over the channels
%   of BLOCK (channels x samples), as basicfilter calls filtfilt.
    for k = 1:numel(filters)
        block = filtfilt(filters{k}{1}, filters{k}{2}, block.').';
    end
end

function [block, short] = filterRuns(block, filters, minimum)
%FILTERRUNS  A block holding rejected (NaN) samples: each channel's finite
%   runs filtered one at a time, a run too short for basicfilter left as it
%   is and counted.
    short = 0;
    for c = 1:size(block, 1)
        x = block(c, :);
        finite = isfinite(x);
        starts = find(diff([false, finite]) == 1);
        stops = find(diff([finite, false]) == -1);
        for r = 1:numel(starts)
            run = starts(r):stops(r);
            if numel(run) <= minimum
                short = short + 1;
            else
                x(run) = filterBlock(x(run), filters);
            end
        end
        block(c, :) = x;
    end
end

function value = fieldOr(s, name, default)
    if isstruct(s) && isfield(s, name) && ~isempty(s.(name))
        value = s.(name);
    else
        value = default;
    end
end
