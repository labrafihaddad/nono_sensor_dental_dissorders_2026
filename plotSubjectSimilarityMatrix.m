function [S, Xz, groupId, groupNames] = plotSubjectSimilarityMatrix(allSession, sensorIds, similarityType)
% plotSubjectSimilarityMatrix
%
% Plots a subject-by-subject similarity matrix across all groups.
%
% Each subject is represented by the concatenated features:
%   [groupMeanData, groupMaxValue, groupMaxTime]
%
% INPUTS:
%   allSession      - struct array or cell array with 5 groups
%   sensorIds       - optional, sensors to include. Default: all sensors
%   similarityType  - optional:
%                       'correlation'  default
%                       'cosine'
%
% OUTPUTS:
%   S          - subject-by-subject similarity matrix
%   Xz         - normalized subject feature matrix
%   groupId    - group label for each subject
%   groupNames - group names used in the plot
%
% Example:
%   plotSubjectSimilarityMatrix(allSession, 1:8, 'correlation');

    if nargin < 2
        sensorIds = [];
    end

    if nargin < 3 || isempty(similarityType)
        similarityType = 'correlation';
    end

    similarityType = lower(char(similarityType));

    numGroups = numel(allSession);

    X = [];
    groupId = [];
    groupNames = cell(numGroups, 1);
    subjectsPerGroup = zeros(numGroups, 1);

    for g = 1:numGroups

        currentGroup = getGroup(allSession, g);

        meanData = currentGroup.groupMeanData;
        maxValue = currentGroup.groupMaxValue;
        maxTime  = currentGroup.groupMaxTime;

        if isempty(sensorIds)
            sensorIdsToUse = 1:size(meanData, 2);
        else
            sensorIdsToUse = sensorIds;
        end

        % Check dimensions
        nSubjects = size(meanData, 1);

        if size(maxValue, 1) ~= nSubjects || size(maxTime, 1) ~= nSubjects
            error('Group %d has inconsistent number of subjects across fields.', g);
        end

        if max(sensorIdsToUse) > size(meanData, 2) || ...
           max(sensorIdsToUse) > size(maxValue, 2) || ...
           max(sensorIdsToUse) > size(maxTime, 2)
            error('sensorIds exceed the number of columns in one of the data fields.');
        end

        % ------------------------------------------------------------
        % Subject representation:
        % full sensor pattern from all 3 feature types
        % ------------------------------------------------------------
        Xg = [
            meanData(:, sensorIdsToUse), ...
            maxValue(:, sensorIdsToUse), ...
            maxTime(:, sensorIdsToUse)
        ];

        % If instead you want ONLY 3 scalar values per subject,
        % replace Xg above with this:
        %
        % Xg = [
        %     mean(meanData(:, sensorIdsToUse), 2, 'omitnan'), ...
        %     mean(maxValue(:, sensorIdsToUse), 2, 'omitnan'), ...
        %     mean(maxTime(:, sensorIdsToUse), 2, 'omitnan')
        % ];

        X = [X; Xg];
        groupId = [groupId; g * ones(nSubjects, 1)];
        subjectsPerGroup(g) = nSubjects;

        if isfield(currentGroup, 'phenotype')
            groupNames{g} = char(string(currentGroup.phenotype));
        else
            groupNames{g} = sprintf('Group %d', g);
        end
    end

    % ------------------------------------------------------------
    % Normalize features across subjects
    % Important because mean, max value, and max time may have
    % different numerical scales.
    % ------------------------------------------------------------
    mu = mean(X, 1, 'omitnan');
    sigma = std(X, 0, 1, 'omitnan');

    sigma(sigma == 0) = 1;

    Xz = (X - mu) ./ sigma;

    % Replace missing values after normalization with 0,
    % meaning "average value" after z-scoring.
    Xz(isnan(Xz)) = 0;

    % ------------------------------------------------------------
    % Compute subject-by-subject similarity
    % ------------------------------------------------------------
    switch similarityType

        case 'correlation'
            S = corr(Xz', 'Rows', 'pairwise');

        case 'cosine'
            norms = sqrt(sum(Xz.^2, 2));
            norms(norms == 0) = 1;
            S = (Xz * Xz') ./ (norms * norms');

        otherwise
            error('Unknown similarityType. Use ''correlation'' or ''cosine''.');
    end

    % ------------------------------------------------------------
    % Plot matrix
    % ------------------------------------------------------------
    figure('Color', 'w');

    imagesc(S);
    axis image;
    colormap(parula);
    colorbar;

    if strcmp(similarityType, 'correlation') || strcmp(similarityType, 'cosine')
        caxis([-1 1]);
    end

    title(sprintf('Subject similarity matrix using mean, max value, and max time (%s)', similarityType), ...
        'Interpreter', 'none');

    xlabel('Subjects grouped by phenotype');
    ylabel('Subjects grouped by phenotype');

    hold on;

    % Draw group boundaries
    boundaries = cumsum(subjectsPerGroup);

    for i = 1:numGroups-1
        xline(boundaries(i) + 0.5, 'k-', 'LineWidth', 1.5);
        yline(boundaries(i) + 0.5, 'k-', 'LineWidth', 1.5);
    end

    % Group tick labels at group centers
    starts = [1; boundaries(1:end-1) + 1];
    ends = boundaries;
    centers = (starts + ends) / 2;

    xticks(centers);
    yticks(centers);
    xticklabels(groupNames);
    yticklabels(groupNames);
    xtickangle(45);

    set(gca, 'FontSize', 11);

end

function currentGroup = getGroup(allSession, g)
    if iscell(allSession)
        currentGroup = allSession{g};
    else
        currentGroup = allSession(g);
    end
end