
%% import teethEnoseData
%plotExamples = 1;

%% Set up the Import Options and import the data

%xlsfileName = "/Users/rafihaddad/Library/CloudStorage/OneDrive-BarIlanUniversity/Code/StudentProjects/Maisa/teethEnoseData.xlsx"

xlsfileName = "/Users/rafihaddad/Library/CloudStorage/OneDrive-BarIlanUniversity/Code/StudentProjects/Maisa/14AprilcheckedteethSniffphoneData_14_4_26.xlsx"


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








%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%  
%---------- SECOND PROJECT ---------------------/
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% GC data

xlsfileName = "C:/Users/user/OneDrive - Bar Ilan University/Code/StudentProjects/Maisa/all-3exp_Aug2016_sorted_yyb.xlsx"

%% Set up the Import Options and import the data
opts = spreadsheetImportOptions("NumVariables", 537);

% Specify sheet and range
opts.Sheet = "Sheet1";
opts.DataRange = "A3:TQ36";

% Specify column names and types
opts.VariableNames = ["Bacteria", "Timeh", "Name", "DataFile", "Type", "Level", "AcqDateTime", "RT", "Area", "RT1", "Area1", "RT2", "Area2", "RT3", "Area3", "RT4", "Area4", "RT5", "Area5", "RT6", "Area6", "RT7", "Area7", "RT8", "Area8", "RT9", "Area9", "RT10", "Area10", "RT11", "Area11", "RT12", "Area12", "RT13", "Area13", "RT14", "Area14", "RT15", "Area15", "RT16", "Area16", "RT17", "Area17", "RT18", "Area18", "RT19", "Area19", "RT20", "Area20", "RT21", "Area21", "RT22", "Area22", "RT23", "Area23", "RT24", "Area24", "RT25", "Area25", "RT26", "Area26", "RT27", "Area27", "RT28", "Area28", "RT29", "Area29", "RT30", "Area30", "RT31", "Area31", "RT32", "Area32", "RT33", "Area33", "RT34", "Area34", "RT35", "Area35", "RT36", "Area36", "RT37", "Area37", "RT38", "Area38", "RT39", "Area39", "RT40", "Area40", "RT41", "Area41", "RT42", "Area42", "RT43", "Area43", "RT44", "Area44", "RT45", "Area45", "RT46", "Area46", "RT47", "Area47", "RT48", "Area48", "RT49", "Area49", "RT50", "Area50", "RT51", "Area51", "RT52", "Area52", "RT53", "Area53", "RT54", "Area54", "RT55", "Area55", "RT56", "Area56", "RT57", "Area57", "RT58", "Area58", "RT59", "Area59", "RT60", "Area60", "RT61", "Area61", "RT62", "Area62", "RT63", "Area63", "RT64", "Area64", "RT65", "Area65", "RT66", "Area66", "RT67", "Area67", "RT68", "Area68", "RT69", "Area69", "RT70", "Area70", "RT71", "Area71", "RT72", "Area72", "RT73", "Area73", "RT74", "Area74", "RT75", "Area75", "RT76", "Area76", "RT77", "Area77", "RT78", "Area78", "RT79", "Area79", "RT80", "Area80", "RT81", "Area81", "RT82", "Area82", "RT83", "Area83", "RT84", "Area84", "RT85", "Area85", "RT86", "Area86", "RT87", "Area87", "RT88", "Area88", "RT89", "Area89", "RT90", "Area90", "RT91", "Area91", "RT92", "Area92", "RT93", "Area93", "RT94", "Area94", "RT95", "Area95", "RT96", "Area96", "RT97", "Area97", "RT98", "Area98", "RT99", "Area99", "RT100", "Area100", "RT101", "Area101", "RT102", "Area102", "RT103", "Area103", "RT104", "Area104", "RT105", "Area105", "RT106", "Area106", "RT107", "Area107", "RT108", "Area108", "RT109", "Area109", "RT110", "Area110", "RT111", "Area111", "RT112", "Area112", "RT113", "Area113", "RT114", "Area114", "RT115", "Area115", "RT116", "Area116", "RT117", "Area117", "RT118", "Area118", "RT119", "Area119", "RT120", "Area120", "RT121", "Area121", "RT122", "Area122", "RT123", "Area123", "RT124", "Area124", "RT125", "Area125", "RT126", "Area126", "RT127", "Area127", "RT128", "Area128", "RT129", "Area129", "RT130", "Area130", "RT131", "Area131", "RT132", "Area132", "RT133", "Area133", "RT134", "Area134", "RT135", "Area135", "RT136", "Area136", "RT137", "Area137", "RT138", "Area138", "RT139", "Area139", "RT140", "Area140", "RT141", "Area141", "RT142", "Area142", "RT143", "Area143", "RT144", "Area144", "RT145", "Area145", "RT146", "Area146", "RT147", "Area147", "RT148", "Area148", "RT149", "Area149", "RT150", "Area150", "RT151", "Area151", "RT152", "Area152", "RT153", "Area153", "RT154", "Area154", "RT155", "Area155", "RT156", "Area156", "RT157", "Area157", "RT158", "Area158", "RT159", "Area159", "RT160", "Area160", "RT161", "Area161", "RT162", "Area162", "RT163", "Area163", "RT164", "Area164", "RT165", "Area165", "RT166", "Area166", "RT167", "Area167", "RT168", "Area168", "RT169", "Area169", "RT170", "Area170", "RT171", "Area171", "RT172", "Area172", "RT173", "Area173", "RT174", "Area174", "RT175", "Area175", "RT176", "Area176", "RT177", "Area177", "RT178", "Area178", "RT179", "Area179", "RT180", "Area180", "RT181", "Area181", "RT182", "Area182", "RT183", "Area183", "RT184", "Area184", "RT185", "Area185", "RT186", "Area186", "RT187", "Area187", "RT188", "Area188", "RT189", "Area189", "RT190", "Area190", "RT191", "Area191", "RT192", "Area192", "RT193", "Area193", "RT194", "Area194", "RT195", "Area195", "RT196", "Area196", "RT197", "Area197", "RT198", "Area198", "RT199", "Area199", "RT200", "Area200", "RT201", "Area201", "RT202", "Area202", "RT203", "Area203", "RT204", "Area204", "RT205", "Area205", "RT206", "Area206", "RT207", "Area207", "RT208", "Area208", "RT209", "Area209", "RT210", "Area210", "RT211", "Area211", "RT212", "Area212", "RT213", "Area213", "RT214", "Area214", "RT215", "Area215", "RT216", "Area216", "RT217", "Area217", "RT218", "Area218", "RT219", "Area219", "RT220", "Area220", "RT221", "Area221", "RT222", "Area222", "RT223", "Area223", "RT224", "Area224", "RT225", "Area225", "RT226", "Area226", "RT227", "Area227", "RT228", "Area228", "RT229", "Area229", "RT230", "Area230", "RT231", "Area231", "RT232", "Area232", "RT233", "Area233", "RT234", "Area234", "RT235", "Area235", "RT236", "Area236", "RT237", "Area237", "RT238", "Area238", "RT239", "Area239", "RT240", "Area240", "RT241", "Area241", "RT242", "Area242", "RT243", "Area243", "RT244", "Area244", "RT245", "Area245", "RT246", "Area246", "RT247", "Area247", "RT248", "Area248", "RT249", "Area249", "RT250", "Area250", "RT251", "Area251", "RT252", "Area252", "RT253", "Area253", "RT254", "Area254", "RT255", "Area255", "RT256", "Area256", "RT257", "Area257", "RT258", "Area258", "RT259", "Area259", "RT260", "Area260", "RT261", "Area261", "RT262", "Area262", "RT263", "Area263", "RT264", "Area264"];
opts.VariableTypes = ["categorical", "double", "string", "string", "categorical", "string", "datetime", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "string", "string", "double", "double", "double", "double", "double", "double", "double", "double", "string", "string", "string", "string", "double", "double", "double", "double", "double", "double", "double", "double", "string", "string", "string", "string", "double", "double", "double", "double", "double", "double", "string", "string", "string", "string", "string", "string", "string", "string", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "string", "string", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "string", "string", "string", "string", "string", "string", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "string", "string", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "string", "string", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "string", "string", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "string", "string", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "string", "string", "double", "double", "string", "string", "string", "string", "string", "string", "double", "double", "string", "string", "double", "double", "string", "string", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "string", "string", "string", "string", "string", "string", "string", "string", "double", "double", "double", "double", "string", "string", "double", "double", "string", "string", "double", "double", "double", "double", "string", "string", "double", "double", "double", "double", "double", "double", "string", "string"];

% Specify variable properties
opts = setvaropts(opts, ["Name", "DataFile", "Level", "RT18", "Area18", "RT23", "Area23", "RT24", "Area24", "RT29", "Area29", "RT30", "Area30", "RT34", "Area34", "RT35", "Area35", "RT36", "Area36", "RT37", "Area37", "RT43", "Area43", "RT51", "Area51", "RT52", "Area52", "RT53", "Area53", "RT66", "Area66", "RT86", "Area86", "RT118", "Area118", "RT125", "Area125", "RT235", "Area235", "RT237", "Area237", "RT238", "Area238", "RT239", "Area239", "RT241", "Area241", "RT243", "Area243", "RT249", "Area249", "RT250", "Area250", "RT251", "Area251", "RT252", "Area252", "RT255", "Area255", "RT257", "Area257", "RT260", "Area260", "RT264", "Area264"], "WhitespaceRule", "preserve");
opts = setvaropts(opts, ["Bacteria", "Name", "DataFile", "Type", "Level", "RT18", "Area18", "RT23", "Area23", "RT24", "Area24", "RT29", "Area29", "RT30", "Area30", "RT34", "Area34", "RT35", "Area35", "RT36", "Area36", "RT37", "Area37", "RT43", "Area43", "RT51", "Area51", "RT52", "Area52", "RT53", "Area53", "RT66", "Area66", "RT86", "Area86", "RT118", "Area118", "RT125", "Area125", "RT235", "Area235", "RT237", "Area237", "RT238", "Area238", "RT239", "Area239", "RT241", "Area241", "RT243", "Area243", "RT249", "Area249", "RT250", "Area250", "RT251", "Area251", "RT252", "Area252", "RT255", "Area255", "RT257", "Area257", "RT260", "Area260", "RT264", "Area264"], "EmptyFieldRule", "auto");
opts = setvaropts(opts, "AcqDateTime", "InputFormat", "");

% Import the data
teethGCData = readtable("C:/Users/user/OneDrive - Bar Ilan University/Code/StudentProjects/Maisa/all-3exp_Aug2016_sorted_yyb.xlsx", opts, "UseExcel", false);


%%
% extrac tthe Respons Time (RT) and Area data points
pData=[];
pData = teethGCData{1:end,8:end};
timeh = teethGCData{:,2};
pDataRt = str2double(pData(:,1:2:end));
pDataArea = str2double(pData(:,2:2:end));
bacteriaNames = teethGCData{:,1}
id=1;

% remove nans
[a]=isnan(pDataRt);
nonNanIndx = find(sum(a)==0);
pDataRtc = pDataRt(:,nonNanIndx);

[a]=isnan(pDataArea);
nonNanIndx = find(sum(a)==0);
pDataAreac = pDataArea(:,nonNanIndx);



% convert the bacteria names to ids
bacteriaNamesIndx(1) = id;

for patientId=1:size(bacteriaNames)-1
    if strcmp(string(bacteriaNames(patientId)), string(bacteriaNames(patientId+1))) == 1
        bacteriaNamesIndx(patientId+1) = id;
    else
        id=id+1;
        bacteriaNamesIndx(patientId+1) = id;
    end
end

%% plot the data in PCA spcae

removeIndx=  [1:7 11 12 17 18 23 24 29 30] ;
bacteriaNamesIndx(removeIndx)=[];
pDataRtc(removeIndx,:) =[];

[pc,sc,lam]=pca(pDataRtc);

figure; hold all
strclr='rgbkmcyk';
cc=1; indxSum=[];

for patientId=1:size(pDataRtc,1)
    
    indx = find(bacteriaNamesIndx == patientId)
    if isempty(indx) continue; end
    scatter(sc(indx,1),sc(indx,2),strclr(patientId),'fill','SizeData', 200)
    indxSum = [indxSum indx];
    
%         for jj=1:length(indx)
%         scatter(sc(indx(jj),1),sc(indx(jj),2),strclr(ii),'fill',  'SizeData', 100*jj)
%     end

end

legend(    ['Empty' num2str(length(find(bacteriaNamesIndx==3)))],...
    ['F.nucleatum' num2str(length(find(bacteriaNamesIndx==4)))],...
    ['P.gingivalis' num2str(length(find(bacteriaNamesIndx==5)))],...
    ['S.mutans' num2str(length(find(bacteriaNamesIndx==6)))],...
    ['S.sanguis' num2str(length(find(bacteriaNamesIndx==7)))])
xlabel('PC1'); ylabel('PC2');
title('All subject in PCA space')
