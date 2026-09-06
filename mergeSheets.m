function merged_allSheets = mergeSheets(allSheets, groupLabels)
% mergeSheets - Merge sheets based on group labels
%
% INPUT:
%   allSheets    - struct array, each with field .groupMeanData (n x 8)
%   groupLabels  - array specifying group assignment per sheet
%
% OUTPUT:
%   merged_allSheets - struct array with merged .groupMeanData

    if length(allSheets) ~= length(groupLabels)
        error('Length of allSheets and groupLabels must match.');
    end

    uniqueGroups = unique(groupLabels, 'stable');
    numGroups = length(uniqueGroups);

    merged_allSheets = struct('groupMeanData', cell(1, numGroups));

    for g = 1:numGroups
        Phenotypes=[];
        groupID = uniqueGroups(g);

        % Find sheets belonging to this group
        idx = find(groupLabels == groupID);

        % Initialize empty matrix
        mergedMeanData = []; mergedMaxValueData = []; mergedMaxTimeData = [];

        for i = 1:length(idx)
            s = idx(i);

            % Extract data (support both struct and cell)
            if isstruct(allSheets)
                meanData = allSheets(s).groupMeanData;
                maxValueData = allSheets(s).groupMaxValue;
                maxTimeData = allSheets(s).groupMaxTime;
            % elseif iscell(allSheets)
            %     if isstruct(allSheets{s})
            %         meanData = [allSheets{s}.groupMeanData;
            %     else
            %         meanData = allSheets{s};
            %     end
            else
                error('Unsupported format for allSheets.');
            end

            % Concatenate rows
            mergedMeanData = [mergedMeanData; meanData];
            mergedMaxValueData = [mergedMaxValueData; maxValueData];
            mergedMaxTimeData = [mergedMaxTimeData; maxTimeData];

            Phenotypes = strcat(Phenotypes, '/', allSheets(s).phenotype);
            
        end

        merged_allSheets(g).groupMeanData = mergedMeanData;
        merged_allSheets(g).groupMaxValue = mergedMaxValueData;
        merged_allSheets(g).groupMaxTime = mergedMaxTimeData;

        merged_allSheets(g).phenotype = Phenotypes;
    end
end

