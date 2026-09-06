
%% import teethEnoseData
%plotExamples = 1;

%% Set up the Import Options and import the data


xlsfileName = "/14AprilcheckedteethSniffphoneData_14_4_26.xlsx"


sensorIds = 1:8;

p=[];
for sheetIndx = 1:5
    sheetIndx
    opts=[];
    opts = spreadsheetImportOptions("NumVariables", 10);
    
    % Specify sheet and rangex

    opts.Sheet = ['p' num2str(sheetIndx) '-checked'];
    %opts.DataRange = "A1:J14876";
    
    % Specify column names and types
    opts.VariableNames = ["Phenotype", "CARIES", "GNP1", "GNP2", "GNP3", "GNP4", "GNP5", "GNP6", "GNP7", "GNP8"];
    opts.VariableTypes = ["categorical", "categorical", "double", "double", "double", "double", "double", "double", "double", "double"];
    
    % Specify variable properties
    opts = setvaropts(opts, ["Phenotype", "CARIES"], "EmptyFieldRule", "auto");
    
    % Import the data
    teethEnoseData = readtable(xlsfileName, opts, "UseExcel", false);
    p(sheetIndx).opts=opts;
    p(sheetIndx).teethEnoseData = teethEnoseData;
    p(sheetIndx).sheetIndx = sheetIndx;
    
end

Phenotypes = ["CARIES", "GINGIVITIS", "PERIODONTITIS", "IMPLANT", "PERIIMPLANTITIS"];
%% read all  sheets and plot the heat maps

plotExamples = 0;


numOfSubjects=[0];
allSheetsConcat=[];

allSheets =[];


for sheetIndx = 1:5


    if plotExamples == 1
        figure;
    end

    pData=[];
    pData = p(sheetIndx).teethEnoseData{3:end,3:end};
    pTxt = p(sheetIndx).teethEnoseData{3:end,1};
    patientsIdsList = p(sheetIndx).teethEnoseData{3:end,2};
    patientsIds = unique(patientsIdsList);
    patientsIds = patientsIds(~isundefined(patientsIds));
    
    
    % Feature extraction
    %-------------------------



    % mean values of each sensor for each subjectx
    bsMean=[]; breathMean=[]; cleanMean=[]; breathMaxTime=[]; breathMaxValue = [];
    for patientId = 1:length(patientsIds)
        pateintId = patientsIds(patientId);
        pateintIndx = find(patientsIdsList == pateintId);
        %pateintIndx = find(pateintIndx == 1);
        
        bsIndx = find(pTxt(pateintIndx) == 'baseline');
        breathIndx = find(pTxt(pateintIndx) == 'breath');
        cleanIndx = find(pTxt(pateintIndx) == 'clean');

        % update the index relative to the subject        
        bsIndx = bsIndx + pateintIndx(1)-1;
        breathIndx = breathIndx + pateintIndx(1)-1;
        cleanIndx = cleanIndx+ pateintIndx(1)-1;

        if plotExamples == 1
            hold all
            
            % baseline
            %plot(1:length(bsIndx),pData(bsIndx, 1:8),'linewidth',2)
    
            plot((length(bsIndx)+1):length(breathIndx)+length(bsIndx)+0, pData(breathIndx, 1:8),'linewidth',2)
            title([num2str(sheetIndx) '-' num2str(patientId)])
        end

        % avearge across time and sensor responses   
        bsMean(patientId,sensorIds) = mean(pData(bsIndx, sensorIds));
        breathMean(patientId,sensorIds) = mean(pData(breathIndx, sensorIds));
        [breathMaxValue(patientId,sensorIds), breathMaxTime(patientId,sensorIds)] = max(pData(breathIndx, sensorIds));

        cleanMean(patientId,sensorIds) = mean(pData(cleanIndx, sensorIds));
        
    end

    
    % features 
    allSheets(sheetIndx).bsMean = bsMean;   %
    allSheets(sheetIndx).meanData = breathMean;   %
    allSheets(sheetIndx).maxTime = breathMaxTime;   %
    allSheets(sheetIndx).maxValue = breathMaxValue;   %


    allSheets(sheetIndx).patientsIds = patientsIds;
    numOfSubjects(end+1) = size(breathMean,1);

    % store variable name
    allSheets(sheetIndx).phenotype = Phenotypes(sheetIndx);
end

%% figure 1 - plot several sensor responses
plotSubjectEvokedResponse(p, 1,1:8, {"014(1)", "014(2)"})

%%
plotSubjectEvokedResponse(p, 2,1:8, {"007(1)", "007(2)"})


%% plot all 5 disorders multiple samples (two samples per subject)

figure
for sheetIndx=1:5
    subplot(1,5,sheetIndx)

    meanData = allSheets(sheetIndx).meanData;
    patientsIds = allSheets(sheetIndx).patientsIds;
    imagesc(meanData);
    colorbar

    yticks(1:length(patientsIds))           % one tick per row
    yticklabels(string(patientsIds))  % convert to string if needed


    title(['disease #' num2str(sheetIndx) ' #trials=' num2str(size(meanData,1))])
    xlabel('Sensors')
    ylabel('Subjects')

end



% %% cheack how similar a  subjects are to themself
% figure
% for sheetIndx  =1:5
% 
%     R = corr(allSheets(sheetIndx).meanData');
%     subplot(1,5,sheetIndx); 
%     imagesc(R)
%     colorbar
% end


%% Feature extraction

allSheetsConcat=[];  numOfSubjects = 0;
clc
for sheetIndx = 1:size(allSheets,2)

    groupMeanData=[];  groupBsMean=[];

    % average all subjects with the same id
    patientsIds = allSheets(sheetIndx).patientsIds;

    bsMean = allSheets(sheetIndx).bsMean;
    meanData = allSheets(sheetIndx).meanData;
    maxTime = allSheets(sheetIndx).maxTime;
    maxValue = allSheets(sheetIndx).maxValue;


    % avearge feature values
    [patientsIds_clean ,groupBsMean, subjectIds_bad] = average_subject_trials((patientsIds), bsMean);
    [patientsIds_clean ,groupMeanData, subjectIds_bad] = average_subject_trials((patientsIds), meanData);
    [patientsIds_clean ,groupMaxTime, subjectIds_bad] = average_subject_trials((patientsIds), maxTime);
    [patientsIds_clean ,groupMaxValue, subjectIds_bad] = average_subject_trials((patientsIds), maxValue);


    % how many participent has only one trial

    disp(['subject ids in sheet: ' num2str(sheetIndx) ' that has less than 2 trials'])
    disp([ subjectIds_bad ])
    disp([patientsIds_clean(subjectIds_bad)])
        

    % uncomment the below two lines if you want to remove the subjects with only one trials
    % patientsIds_clean(subjectIds_bad) =[];
    % groupMeanData(subjectIds_bad,:)=[];


    allSheets(sheetIndx).groupBsData = groupBsMean - groupBsMean;
    allSheets(sheetIndx).groupMeanData = groupMeanData  ;

    allSheets(sheetIndx).groupMaxTime = groupMaxTime ;
    allSheets(sheetIndx).groupMaxValue = groupMaxValue - groupBsMean;

    %convert patient ids to numbers
    patientsIds = categorical(patientsIds_clean); %allSheets(sheetIndx).patientsIds(1:2:end);
    patientsIdsClean = str2double(patientsIds_clean);
    
    allSheets(sheetIndx).patientsIdsClean = patientsIdsClean;
    allSheetsConcat = [allSheetsConcat; groupMeanData];

    numOfSubjects(end+1) = length(patientsIdsClean);
end


% end of Feature extraction

%% compare subject similarity
[S, Xz, groupId, groupNames] = plotSubjectSimilarityMatrix(allSheets, 1:8, 'correlation')

%% avearge every two samples because they represent the same subject measured twice 
% plot all subjects avearged across trials\
figure
for sheetId=1:size(allSheets,2)
    subplot(1,5,sheetId)
    imagesc(allSheets(sheetId).groupMeanData)
    colorbar
    title(Phenotypes(sheetId))
    xlabel(['subjects:' num2str(numOfSubjects(sheetId+1))])
end

disp('all sheets were read from the xls file and ready for analysis')

%% normalize the data
for sheetIndx = 1:size(allSheets,2)


    A = allSheets(sheetIndx).groupMeanData;
    groupMeanData_norm = (A - min(A)) ./ (max(A) - min(A));


    % replace zero or close to zero values to nan
    % groupMeanData_norm(groupMeanData_norm< 0.01) = nan;

    allSheets(sheetIndx).groupMeanData_norm = groupMeanData_norm;

    subplot(1,5,sheetIndx)
    imagesc(allSheets(sheetIndx).groupMeanData_norm)
    colorbar
    title(['# of subjects:' num2str(numOfSubjects(sheetIndx+1))])

end
   

%% plot the experiment timing for all diseases and patients
figure
hold all
clrstr = 'rgbmckyr';
for sheetIndx=1:length(allSheets)
    patientsIdsClean = allSheets(sheetIndx).patientsIdsClean;
    scatter(patientsIdsClean, sheetIndx*ones(1,length(patientsIdsClean)),clrstr(sheetIndx),'fill')
end

xlabel('Patient id')
ylabel('hseet index (disese type)')
legend(Phenotypes)


%%


X = [];
labels = [];

numDisorders = numel(allSheets);

for ii = 1:numDisorders

    currentData = [ ...
        allSheets(ii).groupMeanData ...
        allSheets(ii).groupMaxTime ...
        allSheets(ii).groupMaxValue];

    X = [X; currentData];

    % One label per patient
    labels = [labels; ii*ones(size(currentData,1),1)];
end


% X = zscore(X);
[coeff, score, latent, tsquared, explained] = pca(X);

figure;
hold on;

colors = lines(numDisorders);

for ii = 1:numDisorders
    idx = labels == ii;

    scatter(score(idx,1), score(idx,2), ...
        60, colors(ii,:), 'filled', ...
        'DisplayName', allSheets(ii).phenotype);
end

xlabel(sprintf('PC1 (%.1f%%)', explained(1)));
ylabel(sprintf('PC2 (%.1f%%)', explained(2)));
legend('Location','best');
grid on;
title('PCA of disorders');















%---------------------------------------------


%% PCA
allSheetsConcat=[];
for ii=1:5
    allSheetsConcat = [allSheetsConcat; [allSheets(ii).groupMeanData allSheets(ii).groupMaxTime allSheets(ii).groupMaxValue]];
end

[pc,sc,lam]=pca(allSheetsConcat);
figure; hold all
strclr='rgbkmcyr';
for patientId=1:length(numOfSubjects)-1
    scatter(sc(sum(numOfSubjects(1:patientId))+1:sum(numOfSubjects(1:patientId+1)),1), sc(sum(numOfSubjects(1:patientId))+1:sum(numOfSubjects(1:patientId+1)),2),strclr(patientId),'fill')
end
legend('Caries','Gingivitis','Perio','Implant','PeriImplan','Car+Imp','Car+Per','Imp+Per')
xlabel('PC1'); ylabel('PC2');
title('All subject in PCA space')

%% Decoding

algoType = 'svm';  % use: 'randomForest' or 'svm'
permutationNum = 0;
metrics = decoding_dental_issues_7(allSheets(1:5),[1:8],permutationNum,algoType)


%% merge sheets caries+gingi vs the rest
merged_allSheets = mergeSheets(allSheets(1:5), [1 1 2 2 2])
decoding_dental_issues_7(merged_allSheets,[1:8],permutationNum,algoType);

%% merge sheets
merged_allSheets = mergeSheets(allSheets([1:3 5]), [1 1 2 2])
decoding_dental_issues_7(merged_allSheets,[1:8], permutationNum,algoType);

% %% merge sheets
% merged_allSheets = mergeSheets(allSheets([1:5]), [1 2 3 4 4])
% decoding_dental_issues_7(merged_allSheets,[1:8],permutationNum,algoType);


%% contribution of each sensor
accuracy=[];
for ii=1:8
    accuracy(ii) = decoding_dental_issues(allSheets(1:5),[ii]);
end
accuracy

%% decoding analysis of the features
decoding_dental_issues_exhaustive(allSheets)

%% plot  patient data
sheetIndx=4;
pData = p(sheetIndx).teethEnoseData{3:end,3:end};
figure
hold on;
clrstr = 'rrbbggkkccmmyyrrbbggkkccmmyyrrbbggkkccmmyy';
for patientId=1:14
    pateintId = patientsIds(patientId);
    pateintIndx = (patientsIdsList == pateintId);
    pateintIndx = find(pateintIndx == 1);
    
    plot(pData(pateintIndx,1),clrstr(patientId), 'LINEWIDTH',2)
end








