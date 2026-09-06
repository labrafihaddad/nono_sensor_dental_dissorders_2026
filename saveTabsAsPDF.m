

function saveAllOpenFiguresAsPDF(outDir, filePrefix)
% Saves all currently open MATLAB figures as separate PDF files.
%
% Example:
%   saveAllOpenFiguresAsPDF('my_saved_figures', 'analysis')

if nargin < 1 || isempty(outDir)
    outDir = 'saved_figures';
end

if nargin < 2 || isempty(filePrefix)
    filePrefix = 'figure';
end

if ~exist(outDir, 'dir')
    mkdir(outDir);
end

figs = findall(groot, 'Type', 'figure');

if isempty(figs)
    error('No open figures found.');
end

% Sort by figure number when possible
figNums = arrayfun(@(f) f.Number, figs);
[~, order] = sort(figNums);
figs = figs(order);

for k = 1:numel(figs)
    fig = figs(k);

    figure(fig);
    drawnow;

    figName = fig.Name;

    if isempty(figName)
        figName = sprintf('Figure_%d', fig.Number);
    end

    safeName = regexprep(figName, '[^\w\d-]', '_');

    fileName = sprintf('%s_%02d_%s.pdf', filePrefix, k, safeName);
    fullPath = fullfile(outDir, fileName);

    exportgraphics(fig, fullPath, 'ContentType', 'vector');

    fprintf('Saved: %s\n', fullPath);
end
end