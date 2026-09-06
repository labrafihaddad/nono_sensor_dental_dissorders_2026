function [ subjectIds, avgData, subjectIds_bad] = average_subject_trials(patientIds, data)
% average_subject_trials averages rows belonging to the same subject.
%
% patientIds example:
%   ["005(1)"; "005(2)"; "012(1)"]
%
% data:
%   n x m matrix, where each row matches one entry in patientIds.
%
% Output:
%   avgData    - one averaged row per subject
%   subjectIds - subject IDs without trial number, e.g. "005"

    subjectIds_bad = [];
    patientIds = string(patientIds);

    if size(data, 1) ~= numel(patientIds)
        error('Number of rows in data must match number of patientIds.');
    end

    % Extract subject ID before the parentheses
    subjectIdsPerRow = regexprep(patientIds, '\(\d+\)$', '');

    % Find unique subjects
    subjectIds = unique(subjectIdsPerRow, 'stable');

    % Preallocate output
    avgData = zeros(numel(subjectIds), size(data, 2));

    % Average all trials for each subject
    for i = 1:numel(subjectIds)
        rows = subjectIdsPerRow == subjectIds(i);
        if sum(rows) < 2
            subjectIds_bad(end+1) = i;
            avgData(i, :) = data(rows, :);
            
        else
            avgData(i, :) = mean(data(rows, :), 1, 'omitnan');
        end
    end

