function plotSubjectEvokedResponse(p, sheetIndx, sensorIds, subjectIdTrial)

% p is the xls data
% sheetIndx should be 1,2,...5
% subjectIdTrial = "005(1)"
box off
figure;     hold on;

colors = lines(8);
colors(8,:) = [0.5 0.5 0.5];

colororder(colors)


for ii=1:size(subjectIdTrial,2)

    % get the data
    pData=[];
    pData = p(sheetIndx).teethEnoseData{3:end,3:end};
    pTxt = p(sheetIndx).teethEnoseData{3:end,1};
    patientsIdsList = p(sheetIndx).teethEnoseData{3:end,2};
    patientsIds = unique(patientsIdsList);
    patientsIds = patientsIds(~isundefined(patientsIds));


    pateintIndx = find(patientsIdsList == subjectIdTrial{ii});

    bsIndx = find(pTxt(pateintIndx) == 'baseline');
    breathIndx = find(pTxt(pateintIndx) == 'breath');
    cleanIndx = find(pTxt(pateintIndx) == 'clean');

    % update the index relative to the subject
    bsIndx = bsIndx + pateintIndx(1)-1;
    breathIndx = breathIndx + pateintIndx(1)-1;
    cleanIndx = cleanIndx+ pateintIndx(1)-1;

    for jj=sensorIds
        if ii==1

            plot(0:length(pData(breathIndx, jj))-1, pData(breathIndx, jj), 'linewidth',2, 'Color', colors(jj,:))


               
            plot(-length(pData(bsIndx, jj))+1:0, pData(bsIndx, jj), 'linewidth',2, 'Color', colors(jj,:))
        else
            plot(1:length(pData(breathIndx, jj)), pData(breathIndx, jj), ':', 'linewidth',2, 'Color', colors(jj,:))
        end
    end


end
legend(string(1:8))
legend boxoff