function applyFigureTitleIfPresentLocal(ax, opts)
% applyFigureTitleIfPresentLocal  Plot title above axes when opts.figureTitle is set.

if nargin < 2 || isempty(opts) || ~isgraphics(ax)
    return;
end
if ~isfield(opts, 'figureTitle') || strlength(string(opts.figureTitle)) == 0
    return;
end
fontSize = 13;
if isfield(opts, 'titleFontSize') && isfinite(opts.titleFontSize)
    fontSize = double(opts.titleFontSize);
end
title(ax, char(string(opts.figureTitle)), ...
    'FontSize', fontSize, 'FontName', 'Times New Roman');
end
