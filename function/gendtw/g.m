function [model,score,bestScores,predictions] = g(model,Xc,Yc)
% Output:
%   model
%   score(default): mean overlap for the k detected gestures
% Input:
%   model: model parameters
%   Xc: data to test against (cell or whole sequence)
%   Yc: labels of X (cell or whole sequence)

if iscell(Xc)
    error('g:classErr','Input data cannot be a cell here, need to specify this functionality');
end
sw = model.sw;
if sw > length(Yc.Lfr)
    error('g:swErr','sliding window is longer than the validation sequence');
end

if sw == 0
    sw = length(Xc)-1;
    r = 1;
else
    sw = model.sw;
    r = inf;
    while any(r > length(Yc.Lfr)-sw)
        r = randperm(round(length(Yc.Lfr)),1);
    end
end

%% select sequence subset to evaluate
nm = length(model.M);
% if nm < length(unique(Y.Lfr))   % Remove iddle gesture from data
%     segsDel = find(Y.L==nm+1);
%     for i = 1:lengh(segsDel)
%         Xc(Y.seg(segsDel(i)):Y.seg(segsDel(i)+1)-1,:) = [];
%         Y.seg(segsDel(i)+1:end) = Y.seg(segsDel(i)+1:end)-Y.seg(segsDel(i)+1)+Y.seg(segsDel(i));
%         Y.seg(end) = [];
%     end
%     Y.L(nm+1) = []; Y.Lfr(nm+1) = [];
% end
seg=r:min(r+sw,length(Yc.Lfr));
X=Xc(seg,:);
Y.Lfr=Yc.Lfr(seg);
Y.L=Y.Lfr; d=diff(Y.Lfr); Y.L(d==0)=[]; Y.seg=[1 find(d~=0)+1 length(Y.Lfr)];

predictions = [];

%% begin evaluation
display(sprintf('Evaluating sequence of %d frames in %d gesture classes ...',length(Y.Lfr),nm));

%% classification
if model.classification
    Wc = zeros(length(Y.L),nm);
    for s = 1:length(Y.L)      % save each sequence vs model dtw costs
        if s < length(Y.L)
            seq = X(Y.seg(s):Y.seg(s+1)-1,:);
        else
            seq = X(Y.seg(s):Y.seg(s+1),:);
        end
        for k = 1:nm
            %% Compute the costs of the test sequence in terms of SM
            M = model.M{k};
            if ~isempty(model.D)
                KT = getUpdatedCosts(seq,model.SM);                
                if ~iscell(M)
                    W = single(dtwc(seq,M,true,Inf,model.D,model.KM{k},KT));
                else
                    if ~isempty(M{model.k})
                        W = single(dtwc(seq,M{model.k},true,Inf,model.D,model.KM{k},KT));
                    end
                end
            else
                if ~iscell(M)
                    if ~model.pdtw,
                        W = single(dtwc(seq,M,true));
                    else
                        Pql=zeros(size(seq,1),size(M,1));
                        for hh=1:size(M,1),
                            if ~isempty(model.lmodel(k,hh).obj),
                                Pql(:,hh)= mixGaussLogprob(model.lmodel(k,hh).obj,seq);
    %                             Pql(:,hh)= log(pdf(model.lmodel(k,hh).obj,seq));
                                Pql(isinf(Pql(:,hh)))=0;
                            end
                        end
                        noze = sum(Pql)~=0;
                        Pql(Pql==0) = mean(mean(Pql(:,noze)));
                        maval = max(max(abs(Pql)));
    %                     Dima  = (1-Pql)./maval;
    %                     DD=pdist2(seq,M);
    %                     DD = DD./max(max(DD));
                        Dima = (1-Pql)./maval.*pdist2(seq,M);
                        W = single(dtw3(seq,M,true,Inf,Dima));
                    end
                else
                    if ~isempty(M{model.k})
                        W = single(dtwc(seq,M{model.k},true));
                    end
                end
            end
            Wc(s,k) = W(end,end);        
        end
    end
    if ~isempty(model.bestThs)
        model.nThreshs = 1;
        thresholds(:,1) = model.bestThs;
    else
        thresholds = zeros(nm,model.nThreshs);
        for k = 1:nm     % save dtw costs of each non-iddle sequence vs its model
            interv = (max(Wc(Y.L==k,k))-min(Wc(Y.L==k,k)))/model.nThreshs;
            tMin = min(Wc(Y.L==k,k));
            if interv == 0, interv = tMin*2/model.nThreshs; end
            thresholds(k,:) = tMin + ((1:model.nThreshs)-1)*interv;
        end
    end
    scoresP = zeros(length(Y.L),model.nThreshs); scoresR = zeros(length(Y.L),model.nThreshs); scoresA = zeros(length(Y.L),model.nThreshs);
    for s = 1:length(Y.L)
        for i = 1:model.nThreshs
            TP = 0; FP = 0; FN = 0; %TN = 0;  % NO SE CONSIDERAN LOS TN, DECIDIR SI LOS USAMOS SEGUN LO HABLADO
            idxDet = Wc(s,:) < thresholds(:,i)';
            if Y.L(s) < nm+1    % iddle gesture is ignored if it wasn't learnt
                if idxDet(Y.L(s))
                    TP = TP + 1;    % DECIDISION DE LA ASIGNACION DE VERDADEROS POSITIVOS
                    if sum(idxDet) > 1, FP = FP + sum(idxDet)-1; end
                else
                    FN = FN + 1; FP = FP + sum(idxDet); 
                end
            else
                FP = FP + sum(idxDet); 
            end
%             if sum(~idxDet)       % DECISION PARA ASIGNACION DE VERDADEROS NEGATIVOS
%                 if ~idxDet(Y.L(s))
%                     TN = TN + sum(~idxDet)-1;
%                 else
%                     TN = TN + sum(~idxDet);
%                 end
%             end
            scoresP(s,i) = TP./(TP+FP);
            scoresR(s,i) = TP./(TP+FN);
            scoresA(s,i) = (TP)./(TP+FN+FP);    %%% (TP/(TP+FN) + TN/(TN+FP))/2   % METRICA PARA EL BALANCEO ENTRE CLASES
            if isnan(scoresP(s,i)), scoresP(s,i) = 0; end
            if isnan(scoresR(s,i)), scoresR(s,i) = 0; end
            if isnan(scoresA(s,i)), scoresA(s,i) = 0; end
        end
    end
    [bestScores(1),bestThsPos(1)] = max(mean(scoresP));
    [bestScores(2),bestThsPos(2)] = max(mean(scoresR));
    [bestScores(3),bestThsPos(3)] = max(mean(scoresA));
    score = bestScores(model.score2optim);
    model.bestThs = zeros(1,k);
    for i = 1:k
        model.bestThs(i) = thresholds(i,bestThsPos(model.score2optim));
    end
else
    %% Spotting
    global DATATYPE; global NAT;
    %% Compute the costs of the test sequence in terms of SM 
    if ~isempty(model.D)
        display('Computing the costs of the test sequence in terms of SM ...');
        model.KT = getUpdatedCosts(X,model.SM);
    end
        
    %% Learn threshold cost parameters for each gesture
    thresholds = cell(1,nm);
    scoresO = cell(1,nm); 
    scoresP = cell(1,nm); scoresR = cell(1,nm); scoresA = cell(1,nm);
    bestScores = zeros(nm,4); bestThsPos = zeros(nm,1);
    for k = 1:nm
        GTtestk = Y.L == k; GTtestkFr = Y.Lfr == k;
        if ~any(GTtestkFr)
            warning('g:missedLabel','Label %d is missing in the test sequence',k);
        end
        W = [];
        if ~isempty(model.D)
            if ~iscell(model.M{k})
                W = single(dtwc(X,model.M{k},false,Inf,model.D,model.KM{k},model.KT));
            else
                if ~isempty(model.M{k}{model.k})
                    W = single(dtwc(X,model.M{k}{model.k},false,Inf,model.D,model.KM{k},model.KT));
                end
            end
            TOL_THRESH = 0.001;
        else
            if ~iscell(model.M{k})
                if ~model.pdtw,
                    W = single(dtwc(X,model.M{k},false));
                else
                    Pql=zeros(size(X,1),size(model.M{k},1));
                    for hh=1:size(model.M{k},1),
                        if ~isempty(model.lmodel(k,hh).obj),
                            Pql(:,hh)= mixGaussLogprob(model.lmodel(k,hh).obj,X);
%                             Pql(:,hh)= log(pdf(model.lmodel(k,hh).obj,X));
                            Pql(isinf(Pql(:,hh)))=0;
                        end
                    end
                    noze= sum(Pql)~=0;
                    Pql(Pql==0)=mean(mean(Pql(:,noze)));
                    maval=max(max(abs(Pql)));
%                     Dima  = (1-Pql)./maval;
%                     DD=pdist2(X,model.M{k});
%                     DD = DD./max(max(DD));
                    Dima  = (1-Pql)./maval.*pdist2(X,model.M{k});
                    W=single(dtw3(X,model.M{k},false,Inf,Dima));
                end
            else
                if ~isempty(model.M{k}{model.k})
                    W = single(dtwc(X,model.M{k}{model.k},false));
                end
            end        
            TOL_THRESH = 0.01;
        end
        if ~isempty(model.bestThs)
            model.nThreshs = 1; nThs = 1;
        else
            if ~isempty(W)
                nThs = model.nThreshs;
                interv = (max(W(end,2:end))-min(W(end,2:end)))/nThs;
                tMin = min(W(end,2:end));
                if interv == 0, interv = tMin*2/nThs; end
                while interv < TOL_THRESH && nThs > 1
                    nThs = round(nThs/2); interv = interv*2;
                    display(sprintf('Decreasing number of test thresholds to %d',nThs));
                end
            end
        end
        ovs = zeros(1,nThs); precs = zeros(1,nThs); recs = zeros(1,nThs); accs = zeros(1,nThs);
        detSeqLog = false(nThs,length(GTtestkFr));
        if ~isempty(W)
%             detSeqLog3 = false(1,length(X));
            idxEval = [];
            if isempty(model.bestThs)
                swthreshs = tMin + ((1:model.nThreshs)-1)*interv;
            else
                swthreshs = model.bestThs;
            end
            for i = 1:nThs                
                idx = find(W(end,:) <= swthreshs(i));
                idx(ismember(idx,idxEval)) = [];
                %% Old, much slower
%                 tic;
%                 toc;
%                 tic;
%                 for j = 1:length(idx)
%     %                 if detSeqLog(idx(j)-1)==0
%         %                 fprintf('%d ',idx(j)-1);
%     %                     fprintf('testing with threshold %.2f\n',idx(j));
%     %                     [in,fi,~] = aligngesture([],W(:,1:idx(j)));
%                         [in,fi] = detectSeqC(W(:,1:idx(j)));
%     %                     [~,in3,fi3] = getDTWcseq(W(:,1:idx(j)));
%                         if ~isequal(in,in2,in3) || ~isequal(fi,fi2,fi3)
%                             disp('');
%                         end
%                         if length(in) > 1 || length(fi) > 1
%                             error('Start and end of the gesture must be scalars');
%                         end
%                         detSeqLog3(in:fi) = 1;
%     %                 end
%                 end
%                 toc;
                %% This is much faster
                detSeqLog(i,:) = getDetectedSeqs_c(W,int32(idx),detSeqLog(i,:),model.maxWlen);
                %%
                % to compensate for the offset of deep-features
                if strcmp(DATATYPE,'chalearn2014') && NAT == 3
                    detSeqLog(i,:)=([detSeqLog(i,6:end),0,0,0,0,0]);    % correct offset of deep features
                end
                idxEval = unique([idxEval idx(detSeqLog(i,idx-1)==true)]);
%                 if ~isequal(detSeqLog3,detSeqLog)
%                     find(detSeqLog3~=detSeqLog)
%                     if sum(detSeqLog3~=detSeqLog) > 1
%                         error();
%                     end
%                 end
                ovs(i) = sum(GTtestkFr & detSeqLog(i,:))./sum(GTtestkFr | detSeqLog(i,:));     % overlap (Jaccard Index)
                % recognition from spotting
                detSw = getActivations(detSeqLog(i,:), GTtestkFr, Y.seg, model);
                % only for MADX database (recognition)
                if strcmp(DATATYPE,'mad1') || strcmp(DATATYPE,'mad2') ...
                        || strcmp(DATATYPE,'mad3') || strcmp(DATATYPE,'mad4') ...
                        || strcmp(DATATYPE,'mad5') 
                    [~,~,R] = estimate_overlap_mad(GTtestk, detSeqLog(i,:), model.minOverlap);
                    precs(i) = R.prec2;  % Precision
                    recs(i) = R.rec2;    % Recall
                else
                    precs(i) = sum(GTtestk & detSw)./sum(GTtestk & detSw | ~GTtestk & detSw);  % Precision
                    recs(i) = sum(GTtestk & detSw)./sum(GTtestk & detSw | GTtestk & ~detSw);  % Recall
                end
                accs(i) = sum(GTtestk & detSw | ~GTtestk & ~detSw)./sum(GTtestk & detSw | GTtestk & ~detSw | ~GTtestk & detSw | ~GTtestk & ~detSw);   % Accuracy
                if isnan(ovs(i)), ovs(i) = 0; end                
                if isnan(recs(i)), recs(i) = 0; end
                if isnan(precs(i)), precs(i) = 0; end
                if isnan(accs(i)), accs(i) = 0; end
            end
        end
        thresholds{k} = swthreshs;
        scoresO{k} = ovs;
        scoresP{k} = precs; scoresR{k} = recs; scoresA{k} = accs;            
        [bestScores(k,1),bestThsPos(k,1)] = max(scoresO{k});
        [bestScores(k,2),bestThsPos(k,2)] = max(scoresP{k});
        [bestScores(k,3),bestThsPos(k,3)] = max(scoresR{k});
        [bestScores(k,4),bestThsPos(k,4)] = max(scoresA{k});        
        
%         gtF = Y.Lfr;
%         save('predictions.mat','predictionsF','gtF');
%         imagesc(confusionmat(predictionsF,gtF)); colormap(hot);
    
        if strcmp(model.scoreMeasure,'levenshtein')
            [~,pos] = max(scoresO{k});
            idx = find(detSeqLog(pos,:) == 1);
            if ~isempty(idx)
                inF = idx(1);
                for i = 2:length(idx)
                    if idx(i)-idx(i-1) > 1
                        endF = idx(i-1);
                        predictions = [predictions inF endF k];
                        inF = idx(i);
                    end
                    if i == length(idx)
                        endF = idx(i);
                        predictions = [predictions inF endF k];
                        % Last ones when inF == endF will be also added.
                    end
                end
            else
                predictions = 0;
            end
            predLabels = []; lints = [];
        end
    end   
    
    %% save mean scores and learnt thresholds
    score = mean(bestScores(:,model.score2optim));
    bestScores = mean(bestScores);
    model.bestThs = zeros(1,k);
    for i = 1:k
        model.bestThs(i) = thresholds{i}(bestThsPos(i,model.score2optim));
    end
    
    if ~isempty(predictions), plotmistakes(predictions,Y,1); display(e.message); end
    if strcmp(model.scoreMeasure,'levenshtein') && ~isempty(predictions)
        for i = 1:size(X,1)
            l = find(predictions(1:3:end) == i);
            while ~isempty(l) && ~any(ismember(l,lints))
                [minFi,pos] = min(predictions(3*(l-1)+2));
                predLabels = [predLabels predictions(3*l(pos))];
                l(pos) = [];
                lint = find(predictions(1:3:end) > i & predictions(2:3:end) < minFi);
                lint(ismember(lint,lints)) = [];
                lints = [lints lint];
                while ~isempty(lint)
                    [~,posInt] = min(predictions(3*(lint-1)+1));
                    predLabels = [predLabels predictions(3*lint(posInt))];
                    lint(posInt) = [];
                end
            end
        end
        score = levenshtein(predLabels,Y.L);
    end
end