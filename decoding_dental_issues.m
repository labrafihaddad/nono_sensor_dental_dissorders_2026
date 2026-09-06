function accuracy = decoding_dental_issues(allSheets, sensnorIds)
%% Decoding category from samples in allSheets
% Assumption:
% allSheets is an array/struct/cell containing 5 datasets.
% Each dataset has a field or variable called groupedMeanData of size n x 8.
% Rows = samples, columns = features.
%
% Output:
% - cross-validated predicted labels
% - overall decoding accuracy
% - confusion matrix

% clearvars -except allSheets
clc

if nargin < 2
    sensnorIds = 1:8;
end



%% -----------------------------
% 1) Collect data from all 5 categories
% ------------------------------
X = [];   % feature matrix
Y = [];   % category labels

numCategories = numel(allSheets);

for c = 1:numCategories
    % Case 1: allSheets is a struct array with field groupedMeanData
    if isstruct(allSheets)
        data = [allSheets(c).groupMeanData, allSheets(c).groupMaxValue , allSheets(c).groupMaxTime];

        
    % Case 2: allSheets is a cell array, and each cell contains a struct
    elseif iscell(allSheets) && isstruct(allSheets{c})
        data = allSheets{c}.groupMeanData;

    % Case 3: allSheets is a cell array, and each cell is directly the matrix
    elseif iscell(allSheets) && isnumeric(allSheets{c})
        data = allSheets{c};

    else
        error('Unsupported format for allSheets.');
    end

    % Append samples
    X = [X; data(:,sensnorIds)];
    Y = [Y; repmat(c, size(data,1), 1)];
end



%% -----------------------------
% 2) Optional: normalize features
%    Recommended for decoding
% ------------------------------

   
% X = (X - min(X)) ./ (max(X) - min(X));
% 
% X = zscore(X);

%% -----------------------------
% 3) Cross-validated decoding
% ------------------------------
% for kFold method
kFolds = 10;
cv = cvpartition(Y, 'KFold', kFolds);

% for leave one out method
% cv = cvpartition(Y, 'LeaveOut');
% kFolds = cv.NumTestSets;

predLabels = zeros(size(Y));

for fold = 1:kFolds
    trainIdx = training(cv, fold);
    testIdx  = test(cv, fold);

    Xtrain = X(trainIdx, :);
    Ytrain = Y(trainIdx);

    Xtest  = X(testIdx, :);

    % Classifier:
    % ECOC = standard way to do multiclass classification in MATLAB
    mdl = fitcecoc(Xtrain, Ytrain);

    % Predict on held-out fold
    predLabels(testIdx) = predict(mdl, Xtest);
end

%% -----------------------------
% 4) Compute accuracy
% ------------------------------
accuracy = mean(predLabels == Y);

fprintf('Cross-validated decoding accuracy: %.2f%%\n', accuracy * 100);

%% -----------------------------
% 5) Confusion matrix
% ------------------------------
confMat = confusionmat(Y, predLabels);


% -----------------------------
% Cohen's kappa
% ------------------------------
N = sum(confMat(:));

% observed agreement = accuracy
po = sum(diag(confMat)) / N;

% expected agreement by chance from row/column marginals
rowMarginals = sum(confMat, 2);   % true class counts
colMarginals = sum(confMat, 1);   % predicted class counts

pe = sum(rowMarginals .* colMarginals') / N^2;

kappa = (po - pe) / (1 - pe);

fprintf('Cohen''s kappa: %.3f\n', kappa);
fprintf('Observed accuracy: %.2f%%\n', po * 100);
fprintf('Chance agreement from marginals: %.2f%%\n', pe * 100);


figure;

cm = confusionchart(confMat, [allSheets.phenotype]);
cm.Normalization = 'row-normalized';

title(sprintf('Confusion Matrix (Accuracy = %.2f%%)', accuracy * 100));

%% -----------------------------
% 6) Chance level
% ------------------------------
chanceLevel = 1 / numCategories;
fprintf('Chance level: %.2f%%\n', chanceLevel * 100);

%% -----------------------------
% 7) Per-class accuracy
% ------------------------------
perClassAccuracy = diag(confMat) ./ sum(confMat, 2);

disp('Per-class accuracy:');
for c = 1:numCategories
    fprintf('Category %d: %.2f%%\n', c, perClassAccuracy(c) * 100);
end