function [accuracy, kappa, confMat, predLabels, balancedAccuracy, macroF1, metrics] = decoding_dental_issues(allSheets, sensnorIds, numPerm, classifierType)
%% Decoding category from samples in allSheets
% Assumption:
% allSheets is an array/struct/cell containing datasets/categories.
% Each dataset contains grouped features. Rows = samples, columns = features.
%
% Output:
% - accuracy: 10-fold cross-validated decoding accuracy
% - kappa: Cohen's kappa computed from cross-validated predictions
% - confMat: confusion matrix, rows=true labels, columns=predicted labels
% - predLabels: cross-validated predicted labels for all samples
% - balancedAccuracy: mean recall/per-class accuracy across classes
% - macroF1: mean F1 score across classes
% - metrics: struct containing per-class precision, recall, F1, counts,
%   permutation-test p-values, null distributions, and a per-class table
%
% Optional inputs:
% - sensnorIds: feature columns to use. Default = 1:8
% - numPerm: number of label permutations for p-values. Default = 1000.
%   Use numPerm = 0 to skip the permutation test.
% - classifierType: classifier to use. Default = 'svm'. Options:
%   'svm' or 'ecoc'          = ECOC multiclass classifier with SVM learners
%   'randomForest' or 'rf'   = bagged decision trees / random forest-like classifier
%   'lda'                    = regularized linear discriminant analysis
%
% IMPORTANT:
% Normalization is performed WITHIN EACH TRAINING FOLD and then applied to
% the held-out test fold. This avoids data leakage from test subjects into
% the training pipeline.
%
% Permutation-test logic:
% Category labels are shuffled, and the COMPLETE cross-validated decoding
% pipeline is rerun for each shuffle. P-values are one-sided: the fraction
% of shuffled-label results that are at least as large as the observed value.

clc

if nargin < 2 || isempty(sensnorIds)
    sensnorIds = 1:8;
end

if nargin < 3 || isempty(numPerm)
    numPerm = 1000;
end

if nargin < 4 || isempty(classifierType)
    classifierType = 'svm';
end

classifierType = validatestring(classifierType, ...
    {'svm', 'ecoc', 'randomForest', 'rf', 'lda'});

%% -----------------------------
% 1) Collect data from all categories
% ------------------------------
X = [];   % feature matrix
Y = [];   % category labels

numCategories = numel(allSheets);

for c = 1:numCategories
    % Case 1: allSheets is a struct array with fields containing features
    if isstruct(allSheets)
        data = [allSheets(c).groupMeanData, ...
                allSheets(c).groupMaxValue, ...
                allSheets(c).groupMaxTime];

    % Case 2: allSheets is a cell array, and each cell contains a struct
    elseif iscell(allSheets) && isstruct(allSheets{c})
        if isfield(allSheets{c}, 'groupMeanData') && ...
           isfield(allSheets{c}, 'groupMaxValue') && ...
           isfield(allSheets{c}, 'groupMaxTime')
            data = [allSheets{c}.groupMeanData, ...
                    allSheets{c}.groupMaxValue, ...
                    allSheets{c}.groupMaxTime];
        elseif isfield(allSheets{c}, 'groupMeanData')
            data = allSheets{c}.groupMeanData;
        else
            error('Cell struct must contain groupMeanData or the expected feature fields.');
        end

    % Case 3: allSheets is a cell array, and each cell is directly the matrix
    elseif iscell(allSheets) && isnumeric(allSheets{c})
        data = allSheets{c};

    else
        error('Unsupported format for allSheets.');
    end

    % Append samples
    X = [X; data(:, sensnorIds)];
    Y = [Y; repmat(c, size(data, 1), 1)];
end

%% -----------------------------
% 2) Cross-validated decoding
% ------------------------------
kFolds = 10;
classOrder = 1:numCategories;

% Run the observed decoding analysis.
predLabels = runFoldwiseDecoding(X, Y, kFolds, classifierType);

%% -----------------------------
% 3) Compute confusion matrix and metrics
% ------------------------------
confMat = confusionmat(Y, predLabels, 'Order', classOrder);
metrics = computeClassificationMetrics(confMat, Y, predLabels, numCategories);

accuracy = metrics.overallAccuracy;
kappa = metrics.kappa;
balancedAccuracy = metrics.balancedAccuracy;
macroF1 = metrics.macroF1;
metrics.classifierType = classifierType;
metrics.kFolds = kFolds;

fprintf('Classifier type: %s\n', classifierType);
fprintf('Cross-validated decoding accuracy: %.2f%%\n', accuracy * 100);
fprintf('Cohen''s kappa: %.3f\n', kappa);
fprintf('Observed agreement: %.2f%%\n', metrics.observedAgreement * 100);
fprintf('Expected chance agreement used for kappa (from true/predicted marginals): %.2f%%\n', ...
    metrics.expectedChanceAgreement * 100);
fprintf('This is different from naive chance when class counts or prediction counts are imbalanced.\n');
fprintf('Balanced accuracy: %.2f%%\n', balancedAccuracy * 100);
fprintf('Macro-averaged F1: %.3f\n', macroF1);

%% -----------------------------
% 4) Permutation test for performance above chance
% ------------------------------
metrics.numPermutations = numPerm;
metrics.permutationTestDescription = ['Labels were randomly shuffled and the complete ', ...
    'fold-wise-normalized cross-validated decoding pipeline was rerun using the same classifier type. ', ...
    'P-values are one-sided: fraction of permutations with metric >= observed metric.'];

if numPerm > 0
    fprintf('\nRunning %d label permutations for chance-level p-values...\n', numPerm);

    permAccuracy = zeros(numPerm, 1);
    permBalancedAccuracy = zeros(numPerm, 1);
    permKappa = zeros(numPerm, 1);
    permMacroF1 = zeros(numPerm, 1);

    for p = 1:numPerm
        Yperm = Y(randperm(numel(Y)));

        predPerm = runFoldwiseDecoding(X, Yperm, kFolds, classifierType);
        confPerm = confusionmat(Yperm, predPerm, 'Order', classOrder);
        permMetrics = computeClassificationMetrics(confPerm, Yperm, predPerm, numCategories);

        permAccuracy(p) = permMetrics.overallAccuracy;
        permBalancedAccuracy(p) = permMetrics.balancedAccuracy;
        permKappa(p) = permMetrics.kappa;
        permMacroF1(p) = permMetrics.macroF1;
    end

    % One-sided p-values: how often random-label decoding is at least as good.
    % The +1 correction prevents a p-value of exactly zero.
    pAccuracy = (sum(permAccuracy >= accuracy) + 1) / (numPerm + 1);
    pBalancedAccuracy = (sum(permBalancedAccuracy >= balancedAccuracy) + 1) / (numPerm + 1);
    pKappa = (sum(permKappa >= kappa) + 1) / (numPerm + 1);
    pMacroF1 = (sum(permMacroF1 >= macroF1) + 1) / (numPerm + 1);

    fprintf('\nPermutation p-values, random labels vs observed result:\n');
    fprintf('Accuracy p-value: %.4f\n', pAccuracy);
    fprintf('Balanced accuracy p-value: %.4f\n', pBalancedAccuracy);
    fprintf('Kappa p-value: %.4f\n', pKappa);
    fprintf('Macro-F1 p-value: %.4f\n', pMacroF1);

    metrics.permutationAccuracy = permAccuracy;
    metrics.permutationBalancedAccuracy = permBalancedAccuracy;
    metrics.permutationKappa = permKappa;
    metrics.permutationMacroF1 = permMacroF1;
    metrics.pAccuracy = pAccuracy;
    metrics.pBalancedAccuracy = pBalancedAccuracy;
    metrics.pKappa = pKappa;
    metrics.pMacroF1 = pMacroF1;
else
    fprintf('\nPermutation test skipped because numPerm = 0.\n');

    metrics.permutationAccuracy = [];
    metrics.permutationBalancedAccuracy = [];
    metrics.permutationKappa = [];
    metrics.permutationMacroF1 = [];
    metrics.pAccuracy = NaN;
    metrics.pBalancedAccuracy = NaN;
    metrics.pKappa = NaN;
    metrics.pMacroF1 = NaN;
end

%% -----------------------------
% 5) Plot confusion matrix
% ------------------------------
figure;

% Create display labels if phenotype names are available
if isstruct(allSheets) && isfield(allSheets, 'phenotype')
    labelNames = cellstr(string({allSheets.phenotype}));
elseif iscell(allSheets) && all(cellfun(@(s) isstruct(s) && isfield(s, 'phenotype'), allSheets))
    labelNames = cellfun(@(s) s.phenotype, allSheets, 'UniformOutput', false);
else
    labelNames = cellstr("Category " + string(1:numCategories));
end

cm = confusionchart(confMat, labelNames);
cm.Normalization = 'row-normalized';

title(sprintf('Confusion Matrix - %s (Acc = %.2f%%, BalAcc = %.2f%%, Kappa = %.3f, Macro-F1 = %.3f)', ...
    classifierType, accuracy * 100, balancedAccuracy * 100, kappa, macroF1));

%% -----------------------------
% 6) Chance level
% ------------------------------
chanceLevel = 1 / numCategories;
fprintf('\nNaive chance level: %.2f%%\n', chanceLevel * 100);
metrics.naiveChanceLevel = chanceLevel;

%% -----------------------------
% 7) Per-class metrics
% ------------------------------
disp('Per-class metrics table:');
disp(metrics.perClassTable);

disp('Per-class metrics summary:');
for c = 1:numCategories
    fprintf('Category %d: recall/per-class accuracy = %.2f%%, precision = %.2f%%, F1 = %.3f\n', ...
        c, metrics.perClassAccuracy(c) * 100, metrics.precision(c) * 100, metrics.F1(c));
end

end

%% ========================================================================
% Local helper functions
% ========================================================================

function predLabels = runFoldwiseDecoding(X, Y, kFolds, classifierType)
% Run stratified k-fold decoding with normalization inside each fold.
% Only the classifier is changed by classifierType; the folds, normalization,
% predictions, and performance metrics are kept the same.

cv = cvpartition(Y, 'KFold', kFolds);
predLabels = zeros(size(Y));

for fold = 1:kFolds
    trainIdx = training(cv, fold);
    testIdx  = test(cv, fold);

    XtrainRaw = X(trainIdx, :);
    Ytrain    = Y(trainIdx);
    XtestRaw  = X(testIdx, :);

    % Normalize using TRAINING DATA ONLY.
    % Step 1: min-max scaling, parameters estimated only from training fold.
    trainMin = min(XtrainRaw, [], 1);
    trainMax = max(XtrainRaw, [], 1);
    trainRange = trainMax - trainMin;
    trainRange(trainRange == 0) = 1;  % avoid division by zero

    XtrainScaled = (XtrainRaw - trainMin) ./ trainRange;
    XtestScaled  = (XtestRaw  - trainMin) ./ trainRange;

    % Step 2: z-score, parameters estimated only from training fold.
    mu = mean(XtrainScaled, 1);
    sigma = std(XtrainScaled, 0, 1);
    sigma(sigma == 0) = 1;  % avoid division by zero

    Xtrain = (XtrainScaled - mu) ./ sigma;
    Xtest  = (XtestScaled  - mu) ./ sigma;

    % Train requested classifier.
    switch classifierType
        case {'svm', 'ecoc'}
            % ECOC is MATLAB's standard multiclass classification framework.
            % By default, fitcecoc uses binary SVM learners in a one-vs-one design.
            mdl = fitcecoc(Xtrain, Ytrain);

        case {'randomForest', 'rf'}
            % Random-forest-like classifier: bagged decision trees with random
            % feature subsampling at each split. This provides a nonlinear
            % comparison to the SVM/ECOC classifier.
            numPredictorsToSample = max(1, round(sqrt(size(Xtrain, 2))));
            treeTemplate = templateTree('NumVariablesToSample', numPredictorsToSample);
            mdl = fitcensemble(Xtrain, Ytrain, ...
                'Method', 'Bag', ...
                'NumLearningCycles', 200, ...
                'Learners', treeTemplate);

        case 'lda'
            % Regularized linear discriminant analysis as a simple linear baseline.
            mdl = fitcdiscr(Xtrain, Ytrain, ...
                'DiscrimType', 'linear', ...
                'Gamma', 0.1);

        otherwise
            error('Unsupported classifierType: %s', classifierType);
    end

    predLabels(testIdx) = predict(mdl, Xtest);
end

end

function metrics = computeClassificationMetrics(confMat, Y, predLabels, numCategories)
% Compute accuracy, kappa, balanced accuracy, precision, recall, and F1.
% Rows are true classes and columns are predicted classes.

N = sum(confMat(:));

overallAccuracy = mean(predLabels == Y);
observedAgreement = sum(diag(confMat)) / N;

rowMarginals = sum(confMat, 2);   % true class counts
colMarginals = sum(confMat, 1);   % predicted class counts
expectedChanceAgreement = sum(rowMarginals .* colMarginals') / N^2;

kappa = (observedAgreement - expectedChanceAgreement) / (1 - expectedChanceAgreement);

trueCounts = sum(confMat, 2);
predCounts = sum(confMat, 1)';

recall = diag(confMat) ./ trueCounts;
precision = diag(confMat) ./ predCounts;

% Avoid NaN values if a class was never predicted or absent.
recall(trueCounts == 0) = NaN;
precision(predCounts == 0) = NaN;

F1 = 2 * (precision .* recall) ./ (precision + recall);
F1((precision + recall) == 0) = NaN;

perClassAccuracy = recall;
balancedAccuracy = mean(perClassAccuracy, 'omitnan');
macroF1 = mean(F1, 'omitnan');

metrics = struct();
metrics.overallAccuracy = overallAccuracy;
metrics.observedAgreement = observedAgreement;
metrics.kappa = kappa;
metrics.expectedChanceAgreement = expectedChanceAgreement;
metrics.balancedAccuracy = balancedAccuracy;
metrics.macroF1 = macroF1;
metrics.perClassAccuracy = perClassAccuracy;
metrics.recall = recall;
metrics.precision = precision;
metrics.F1 = F1;
metrics.trueCounts = trueCounts;
metrics.predictedCounts = predCounts;
metrics.confusionMatrix = confMat;
metrics.predictedLabels = predLabels;
metrics.trueLabels = Y;

metrics.perClassTable = table((1:numCategories)', trueCounts, predCounts, ...
    perClassAccuracy, precision, F1, ...
    'VariableNames', {'Category', 'TrueCount', 'PredictedCount', ...
    'Recall_PerClassAccuracy', 'Precision', 'F1'});

end
