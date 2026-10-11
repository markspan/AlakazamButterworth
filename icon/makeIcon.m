function makeIcon(out)
%MAKEICON  Draw the plugin's ribbon icon, ButterworthFilter.png: the paths of
%   ButterworthFilter.svg (beside this file), drawn at eight times the size,
%   each stroke as the pixels within half its width of the path, and averaged
%   down to 24 x 24, in Alakazam's icon blue on a transparent ground.
%
%   makeIcon()      writes ../ButterworthFilter/ButterworthFilter.png
%   makeIcon(OUT)   writes OUT
%
%   Drawn here rather than with Alakazam's rasterize.mjs so that nothing but
%   MATLAB is needed to rebuild the plugin.
    if nargin < 1
        out = fullfile(fileparts(fileparts(mfilename('fullpath'))), ...
            'ButterworthFilter', 'ButterworthFilter.png');
    end
    scale = 8;
    n = 24 * scale;
    [x, y] = meshgrid(((1:n) - 0.5) / scale, ((1:n) - 0.5) / scale);
    % The filter's amplitude response: flat, then rolling off.
    response = [polyline([2.5 6; 11 6]), ...
        cubic([11 6], [14.5 6], [15.5 9], [17 13]), ...
        cubic([17 13], [18.5 17], [19.5 19.5], [21.5 20])];
    axes = [polyline([2.5 21.5; 21.5 21.5]), polyline([2.5 21.5; 2.5 2.5])];
    halfLevel = dashes([2.5 9.6], [14.6 9.6], 1.2);
    alpha = max(cat(3, ...
        stroke(x, y, response, 1.8), ...
        0.6 * stroke(x, y, axes, 1.1), ...
        0.6 * stroke(x, y, halfLevel, 0.9)), [], 3);
    alpha = squeeze(mean(mean(reshape(alpha, scale, 24, scale, 24), 1), 3));
    blue = [0x4a 0x7f 0xc9];
    rgb = repmat(reshape(uint8(blue), 1, 1, 3), 24, 24);
    imwrite(rgb, out, 'Alpha', alpha);
end

function segments = polyline(points)
%POLYLINE  Consecutive points as segments, one per row: [x1 y1 x2 y2].
    segments = [points(1:end - 1, :), points(2:end, :)].';
end

function segments = cubic(p0, p1, p2, p3)
%CUBIC  A cubic Bezier curve, as short segments.
    t = linspace(0, 1, 40).';
    points = (1 - t) .^ 3 .* p0 + 3 * (1 - t) .^ 2 .* t .* p1 + 3 * (1 - t) .* t .^ 2 .* p2 + t .^ 3 .* p3;
    segments = polyline(points);
end

function segments = dashes(from, to, length)
%DASHES  A dashed line from FROM to TO: dashes and gaps of LENGTH.
    total = norm(to - from);
    direction = (to - from) / total;
    starts = 0:2 * length:total;
    segments = zeros(4, 0);
    for s = starts
        e = min(s + length, total);
        segments(:, end + 1) = [from + s * direction, from + e * direction].'; %#ok<AGROW>
    end
end

function a = stroke(x, y, segments, width)
%STROKE  1 within half WIDTH of any segment, 0 elsewhere (round caps).
    d = inf(size(x));
    for k = 1:size(segments, 2)
        p = segments(1:2, k).';
        q = segments(3:4, k).';
        v = q - p;
        t = ((x - p(1)) * v(1) + (y - p(2)) * v(2)) / max(sum(v .^ 2), eps);
        t = min(max(t, 0), 1);
        d = min(d, hypot(x - (p(1) + t * v(1)), y - (p(2) + t * v(2))));
    end
    a = double(d <= width / 2);
end
