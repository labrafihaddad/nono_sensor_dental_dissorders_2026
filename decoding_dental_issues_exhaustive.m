function overallAccuracy = decoding_dental_issues_exhaustive(allSheets)
%% Exhaustive feature-subset decoding with nested cross-validation
% Assumptions:
% - allSheets contains 5 categories
% - each category has .groupMeanData_norm which is n x 8
% - rows = samples, columns = features


%% --------------------------------
% 1) Build dataset
% --------------------------------
X = [];
Y = [];

numCategories = numel(allSheets);

for c = 1:numCategories
    if isstruct(allSheets)
        data = allSheets(c).groupMeanData_norm;
    elseif iscell(allSheets) && isstruct(allSheets{c})
        data = allSheets{c}.groupMeanData_norm;
    elseif iscell(allSheets) && isnumeric(allSheets{c})
        data = allSheets{c};
    else
        error('Unsupported format for allSheets.');
    end

    X = [X; data];
    Y = [Y; repmat(c, size(data,1), 1)];
end

[numSamples, numFeatures] = size(X);

if numFeatures ~= 8
    warning('Expected 8 features, but found %d.', numFeatures);
end

%% --------------------------------
% 2) Create all non-empty feature subsets
% --------------------------------
allSubsets = {};
for mask = 1:(2^numFeatures - 1)
    subset = find(bitget(mask, 1:numFeatures));
    allSubsets{end+1} = subset;
end

numSubsets = numel(allSubsets);

%% --------------------------------
% 3) Outer CV: estimates generalization performance
% --------------------------------
outerKFolds = 5;
outerCV = cvpartition(Y, 'KFold', outerKFolds);

predLabels = zeros(size(Y));
chosenSubsetPerFold = cell(outerKFolds,1);
chosenSubsetIdxPerFold = zeros(outerKFolds,1);
outerFoldAcc = zeros(outerKFolds,1);

%% --------------------------------
% 4) Nested CV loop
% --------------------------------
for outerFold = 1:outerKFolds
    fprintf('\nOuter fold %d / %d\n', outerFold, outerKFolds);

    outerTrainIdx = training(outerCV, outerFold);
    outerTestIdx  = test(outerCV, outerFold);

    XtrainOuter = X(outerTrainIdx, :);
    YtrainOuter = Y(outerTrainIdx);
    XtestOuter  = X(outerTestIdx, :);
    YtestOuter  = Y(outerTestIdx);

    % --------------------------------
    % Inner CV: choose best feature subset using training data only
    % --------------------------------
    innerKFolds = 4;
    innerCV = cvpartition(YtrainOuter, 'KFold', innerKFolds);

    subsetScores = zeros(numSubsets,1);

    for s = 1:numSubsets
        cols = allSubsets{s};
        innerPred = zeros(size(YtrainOuter));

        for innerFold = 1:innerKFolds
            innerTrainIdx = training(innerCV, innerFold);
            innerValIdx   = test(innerCV, innerFold);

            XtrainInner = XtrainOuter(innerTrainIdx, cols);
            YtrainInner = YtrainOuter(innerTrainIdx);

            XvalInner = XtrainOuter(innerValIdx, cols);
            YvalInner = YtrainOuter(innerValIdx);

            % Normalize using training fold only
            mu = mean(XtrainInner, 1);
            sigma = std(XtrainInner, 0, 1);
            sigma(sigma == 0) = 1;

            XtrainInner = (XtrainInner - mu) ./ sigma;
            XvalInner   = (XvalInner - mu) ./ sigma;

            % Multiclass linear SVM via ECOC
            t = templateSVM('KernelFunction', 'linear');
            mdl = fitcecoc(XtrainInner, YtrainInner, 'Learners', t);

            innerPred(innerValIdx) = predict(mdl, XvalInner);
        end

        subsetScores(s) = mean(innerPred == YtrainOuter);
    end

    % Pick best subset on inner CV
    [~, bestSubsetIdx] = max(subsetScores);
    bestCols = allSubsets{bestSubsetIdx};

    chosenSubsetPerFold{outerFold} = bestCols;
    chosenSubsetIdxPerFold(outerFold) = bestSubsetIdx;

    fprintf('Chosen subset for fold %d: [', outerFold);
    fprintf('%d ', bestCols);
    fprintf(']\n');

    % --------------------------------
    % Retrain on all outer training data with chosen subset
    % --------------------------------
    XtrainBest = XtrainOuter(:, bestCols);
    XtestBest  = XtestOuter(:, bestCols);

    mu = mean(XtrainBest, 1);
    sigma = std(XtrainBest, 0, 1);
    sigma(sigma == 0) = 1;

    XtrainBest = (XtrainBest - mu) ./ sigma;
    XtestBest  = (XtestBest - mu) ./ sigma;

    t = templateSVM('KernelFunction', 'linear');
    mdl = fitcecoc(XtrainBest, YtrainOuter, 'Learners', t);

    predLabels(outerTestIdx) = predict(mdl, XtestBest);

    outerFoldAcc(outerFold) = mean(predLabels(outerTestIdx) == YtestOuter);
    fprintf('Outer fold accuracy: %.2f%%\n', 100 * outerFoldAcc(outerFold));
end

%% --------------------------------
% 5) Final performance
% --------------------------------
overallAccuracy = mean(predLabels == Y);
fprintf('\nOverall nested-CV decoding accuracy: %.2f%%\n', 100 * overallAccuracy);

chanceLevel = 1 / numCategories;
fprintf('Chance level: %.2f%%\n', 100 * chanceLevel);

%% --------------------------------
% 6) Confusion matrix
% --------------------------------
confMat = confusionmat(Y, predLabels);

figure;
cm = confusionchart(confMat, 1:numCategories);
cm.Normalization = 'row-normalized';
title(sprintf('Nested CV Confusion Matrix (Accuracy = %.2f%%)', 100 * overallAccuracy));

%% --------------------------------
% 7) Per-class accuracy
% --------------------------------
perClassAccuracy = diag(confMat) ./ sum(confMat, 2);

fprintf('\nPer-class accuracy:\n');
for c = 1:numCategories
    fprintf('Category %d: %.2f%%\n', c, 100 * perClassAccuracy(c));
end

%% --------------------------------
% 8) Show which subsets were chosen
% --------------------------------
fprintf('\nChosen subset in each outer fold:\n');
for outerFold = 1:outerKFolds
    fprintf('Fold %d: [', outerFold);
    fprintf('%d ', chosenSubsetPerFold{outerFold});
    fprintf(']\n');
end

%% --------------------------------
% 9) Count how often each feature was selected
% --------------------------------
featureSelectionCounts = zeros(1, numFeatures);

for outerFold = 1:outerKFolds
    featureSelectionCounts(chosenSubsetPerFold{outerFold}) = ...
        featureSelectionCounts(chosenSubsetPerFold{outerFold}) + 1;
end

fprintf('\nFeature selection counts across outer folds:\n');
for f = 1:numFeatures
    fprintf('Feature %d selected in %d/%d folds\n', ...
        f, featureSelectionCounts(f), outerKFolds);
end