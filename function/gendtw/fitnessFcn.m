function s = fitnessFcn(I,X,XtrainT,Xtrain_l,Ytrain,Xval_l,Xval,Yval,params)
    % Validate the data sequences by means of either k-means-DTW and mean DTW models.

    % output:
    %   s: score
    % input:
    %   I: Individual for the genetic algorithm
    %   X: whole training data    
    %   XtrainT: the training data sequence for testing (without noise)
    %   Xtrain_l: training data grouped (labeled) by classes (gestures)
    %   Ytrain: training data labels    
    %   Xval: the validation data sequence for testing (including noise)    
    %   Xval_l: validation data grouped by classes (gestures)
    %   Yval: validation data labels
    %   params: struct with the required parameters to construct the model
    %      N: Number of segments to split the training sequence
    %      N0: Number of segments to split the model sequence
    %      nmin: minimum subsequence width
    %      nmax: maximum sequence width
    %      versions: string with the versions of the kmeans DTW algorithm
    %      dist: distance metric for the k-means DTW
    %      k0: initial data clusters 
    %      M: mean sequence models
    %      bestThs: best thresholds for the k detected gestures    
    %      nThreshs: Number of thresholds for testing
    %      params.D: Dissimilarity matrix
    %      phmm: struct with the required parameters to learn hmm    
    %   state: GA state of the current generation

    global CACHE;
    global PREDICTIONS;
    global MODEL;
    
    [I2,idxUniques] = unique(I,'rows');    
    idxRepsI = ~ismember(1:size(I,1),idxUniques);
    [~,posRepsI2] = ismember(I(idxRepsI,:),I2,'rows');
    if ~isempty(idxRepsI)
        if ~all(isequal(I2(posRepsI2,:),I(idxRepsI,:)))
            error('fitnessFcn:uniqueFailed','All repeated individuals must be members of the list of unique individuals.\nCheck the use of unique');
        end
    end   
    [valid,err] = validateI(I2,params,size(X,1),X);
    % create here new random individuals for the non-valid ones & restore
    % them err = 0. Use the idea of function createInitPopul, and
    % generalize to the case of vectorized on|off (full population in I | 
    % just one individual in I)
    
    [exists,s2] = getCacheVal(int32(round(I2)),params);
    predictions = cell(1,size(I2,1));
    
    if strcmp(params.scoreMeasure,'levenshtein') && any(err)
        err(err < 0) = -err(err < 0) + 21;
    end
    s(idxUniques) = err;
    s(idxRepsI) = err(posRepsI2);
    
    if ~any(valid) || all(exists)
        if all(exists)
            s(idxUniques)=s2;
            s(idxRepsI) = s2(posRepsI2);
        end
        return;
    end
    clear s;
    
    idx = exists==0 & valid==1;
    [I2,k,seg,mk,mnsegs] = decode(I2(idx,:),params);
%     cd('results/temp/');
%     save('temp.mat','seg','X','XtrainT','Ytrain','params','k');    
    if length(idx) > 1
        sc = zeros(1,length(k));
        preds = cell(1,length(k));
        model = cell(1,length(k));
        % 1) Launch length(k) processes.
        %   Each process calls to the evaluation function for that k,seg,
        %   and it saves a file in a directory with the trained model, 
        %   scores, and predictions
        % 2) Save the results of each process in the structures model{i}, sc(i), preds{i}
        % 3) Release memory, removing the files of the evaluation
%         f = zeros(1,length(k));
%         for i = 1:length(k)
%             cmd = sprintf('#!/bin/bash\nqsub -t %i -q short.q -l mem=2G subgesture_eval.sh',i);
%             f(i) = system(cmd);
%         end
%         for i = 1:length(k)
%             waitfor(f(i));
%             if exist(strcat('eval',num2str(i),'.mat'),'file')
%                 load(strcat('eval',num2str(i),'.mat'));
%                 delete(strcat('eval',num2str(i),'.mat'));
%             else
%                 error('fitnessFcn:FileNotFound','File for the evaluation not found');
%             end            
%             model{i} = m; sc(i) = sco; preds{i} = predic; 
%             clear m sco predic;            
%         end
%         if exist('temp.mat','file'), delete('temp.mat'); end;       
        parfor i = 1:length(k)            
            if iscell(seg)
                segA = seg{i};
            else
                segA = reshape(seg(i,:,:),size(seg,2),size(seg,3));
            end
            model{i} = evalFit(X,XtrainT,Xtrain_l,Ytrain,params,k(i),segA,mnsegs(i),mk(i));
            Xv = Xval;          % Parfor doesn't accept modifying the value of Xval directly
            if ~params.phmm.hmm
                display('Optimizing model parameters over validation ...');
%                 model{i}.sw = 0;           % Evaluate the whole validation sequence 
                [model{i},sc(i),preds{i}] = g(model{i},Xv,Yval);    % learn&optimize over validation
            else
                if ~strcmp(params.phmm.clustType,'none')
                    display('Discretizing validation sequence in Key Poses ...');
                    Xv = discretizeSequence(model{i}.Ctrain,Xv);      
                end
                %% Discretize validation sequence
                Dval = cell(1,length(Xv));
                if iscell(Xv)
                    for sample = 1:length(Xv)
                        KT = getUpdatedCosts(Xv{sample},model{i}.SM);
                        [~,Dval{sample}] = min(KT);
                    end
                else
                    KT = getUpdatedCosts(Xv,model{i}.SM);
                    [~,Dval] = min(KT);
                end
                display(sprintf('Evaluating the validation sequence ...'));
                sc(i) = evaluateHMM(Dval, model{i}.phmm.hmmTR, model{i}.phmm.hmmE);
                preds{i} = 0;
            end
        end
        s2(idx) = sc;
        predictions(idx) = preds;
        clear preds;
    else
        predictions = cell(1);
        model = cell(1);        
        if iscell(seg)            
            model{1} = evalFit(X,XtrainT,Xtrain_l,Ytrain,params,k,cell2mat(seg),mnsegs,mk);            
        else
            model{1} = evalFit(X,XtrainT,Xtrain_l,Ytrain,params,k,reshape(seg,size(seg,2),size(seg,3)),mnsegs,mk);
        end
        if ~params.phmm.hmm
            display('Validating the model ...');
%             model{1}.sw = 0;           % Evaluate the whole validation sequence 
            [model{1},s2,predictions{1}] = g(model{1},Xval,Yval);   % learn&optimize over validation
        else            
            if ~strcmp(params.phmm.clustType,'none')
                display('Discretizing validation sequence in Key Poses ...');
                Xval = discretizeSequence(model{1}.Ctrain,Xval);
            end
            %% Discretize validation sequence
            Dval = cell(1,length(Xval));
            if iscell(Xval)
                for sample = 1:length(Xval)
                    KT = getUpdatedCosts(Xval{sample},model{1}.SM);
                    [~,Dval{sample}] = min(KT);
                end
            else
                KT = getUpdatedCosts(Xval,model{1}.SM);
                [~,Dval] = min(KT);
            end
            display(sprintf('Evaluating the validation sequence ...'));
            s2 = evaluateHMM(Dval, model{1}.phmm.hmmTR, model{1}.phmm.hmmE);
            predictions{1} = 0;
        end
%         toc;
    end

    % Save current best model
    [bestScore,best] = max(s2(idx));
    if bestScore > max(CACHE.eval)
        MODEL = model{best};
    end
    %%%% if want to plot the performance of the best solution so far
%     plotmistakes(predictions{best}, Yval,0)

     % Add to cache (FILO stack mode avoiding to overwrite the highest value)
    pos = CACHE.pos;
    posEnd = pos+sum(idx)-1;
    remain = 0;
    if posEnd >= pos
        if length(CACHE.eval) < posEnd
            remain = posEnd - length(CACHE.eval);
            posEnd = length(CACHE.eval);
        end
        idxEnd = posEnd-pos+1;
        idxC = pos:posEnd;
        [maxSC,i] = max(CACHE.eval);
        if maxSC > 0
            [~,loc] = ismember(i,idxC);
            if any(loc)
                idxC(loc:end) = idxC(loc:end) + 1;
                addRemain = idxC > length(CACHE.eval);
                if any(addRemain)
                    idxC(addRemain) = 1:sum(addRemain);
                end
            end
        end        
        CACHE.ind(idxC,:) = I2(1:idxEnd,:); 
        s3 = s2(idx);
        CACHE.eval(idxC) = s3(1:idxEnd);
        if remain
            pos = 1;
            posEnd = pos+remain-1;
            idxC = pos:posEnd;
            [maxSC,i] = max(CACHE.eval);
            if maxSC > 0
                [~,loc] = ismember(i,idxC);
                if any(loc)
                    idxC(loc:end) = idxC(loc:end) + 1;
                    addRemain = idxC > length(CACHE.eval);
                    if any(addRemain)
                        idxC(addRemain) = 1:sum(addRemain);
                    end
                end
            end            
            CACHE.ind(idxC,:) = I2(idxEnd+1:end,:); 
            CACHE.eval(idxC) = s3(idxEnd+1:end);
        end
        CACHE.pos = posEnd + 1;
    end
        
    % Return all final scores    
    s(idxUniques) = s2;
    s(idxRepsI) = s2(posRepsI2);
    preds(idxUniques) = predictions;
    preds(idxRepsI) = predictions(posRepsI2);    
    [~,bestPos] = max(s);
    PREDICTIONS = preds{bestPos};
end

function [I2,k,seg,mk,mnsegs] = decode(I,params)
    k = round(I(:,1));
    I2 = zeros(size(I));
    I2(:,1) = k(:);     % get k
    if params.probSeg > 0
        seg = cell(1,size(I,1));
    end
    for i = 1:size(I,1)
        Iseg = round(I(i,2:params.N*2+1));
        I2(i,2:params.N*2+1) = Iseg;
        Iseg = Iseg(Iseg < inf);    % choose non-infinity segments
        if params.probSeg > 0
            seg{i} = round(reshape(Iseg,[2 size(Iseg,2)/2]));        
        end
    end
    if params.probSeg == 0
        seg = round(reshape(I(:,2:params.N*2+1),[size(I,1) 2 (params.N*2)/2]));
    end
    
    mnsegs = zeros(1,size(I,1)); mk = zeros(1,size(I,1));
    % get model segments and k
    if strcmp(params.msmType,'fix')
        mnsegs = round(I(:,end-1));
        mk = round(I(:,end));
        I2(:,end-1) = mnsegs;
        I2(:,end) = mk;
    end
end

function [valid,err] = validateI(I,params,maxSeg,X)
    global BASELINE;
    [I2,k,seg,mk,mnsegs] = decode(I,params);
    valid = ones(1,length(k)); 
    
    %% check k for subgestures
    nsegs = sum(transpose(I2(:,2:params.N*2+1) < inf));
    nsegs(mod(nsegs,2) > 0) = nsegs(mod(nsegs,2) > 0) - 1;
    nsegs = nsegs/2;
    kBad = k < params.k0 | k > params.N | k(:) >= nsegs(:);
    e0 = zeros(1,length(k));
    if ~isempty(k(kBad))
        e0(kBad) = abs(max(k(kBad)-params.k0,params.N-k(kBad)))/10000;
        valid(kBad) = 0;
    end
    
    %% Check subgesture segments
    e1 = zeros(1,size(I2,1)); e2 = zeros(1,size(I2,1));
    e3 = zeros(1,size(I2,1)); e4 = zeros(1,size(I2,1));
    for i = 1:size(I2,1)
        if iscell(seg)
            e1(i) = sum(seg{i}(1,:) < 1);
        else
            e1(i) = sum(seg(i,1,:) < 1);
        end
        if strcmp(params.Baseline,BASELINE{1})
            if iscell(seg)
                e2(i) = sum(seg{i}(1,:) > maxSeg-params.nmax);
                e3(i) = sum(seg{i}(2,:) < params.nmin);
                e4(i) = sum(seg{i}(2,:) > params.nmax+1);
            else
                e2(i) = sum(seg(i,1,:) > maxSeg-params.nmax);
                e3(i) = sum(seg(i,2,:) < params.nmin);
                e4(i) = sum(seg(i,2,:) > params.nmax+1);
            end
        else
            e2(i) = 0;
            if iscell(seg)
                e3(i) = sum(seg{i}(2,:) < 2);
                e4(i) = sum(seg{i}(1,:)+seg{i}(2,:)-1 > maxSeg);
            else
                e3(i) = sum(seg(i,2,:) < 2);
                e4(i) = sum(seg(i,1,:)+seg{i}(2,:)-1 > maxSeg);
            end
        end            
    end

    % check non-zero segments
    for i = 1:size(I2,1)
        if iscell(seg)
            l = length(seg{i})-1;
        else
            l = params.N-1;
        end
        for j = 1:l
            if ~any([e1(i) e2(i) e3(i) e4(i)])
                if iscell(seg)
                    in = seg{i}(1,j);
                    fi = in + seg{i}(2,j) - 1;
                else
                    in = seg(i,1,j);
                    fi = in + seg(i,2,j) - 1;
                end
                if ~any(any(X(in:fi,:)))
                    e1(i) = size(I2,1);
                end
            end
        end
    end
        
    %% check number of segments and k for the models    
    e5 = zeros(1,size(I2,1)); 
    e6 = zeros(1,size(I2,1));
    if strcmp(params.msmType,'fix')
        nsBad = mnsegs < params.k0 | mnsegs > params.N0;
        if ~isempty(nsegs(nsBad))
            e5(nsBad) = abs(max(mnsegs(nsBad)-params.k0,params.N0-mnsegs(nsBad)))/100;
            valid(nsBad) = 0;
        end
        kBad = mk < params.k0-1 | mk > params.N0 | mk(:) >= mnsegs(:);
        if ~isempty(mk(kBad))
            e6(kBad) = abs(max(mk(kBad)-params.k0-1,params.N0-mk(kBad)))/100;
            valid(kBad) = 0;
        end
    end
    
    %% calculate final error
    e = e1+e2+e3+e4+e5;
    if any(e)
        valid(e~=0) = 0;
        % If there is more than the half population invalid, create new
        % random initial population.
    end
    err = - (0.25*e0 + 0.5*e/length(I2(:,2:end))/2 + 0.25*e6);
end

function segs = getDataPartitions(data,partitions)
    segs = cell(1,size(partitions,1));
    for i = 1:length(segs)
        segs{i} = data(partitions(i,1):partitions(i,1)+partitions(i,2)-1,:);
    end
end

function [exists,s] = getCacheVal(I,params)
    global CACHE;
    
    if strcmp(params.scoreMeasure,'overlap')
        s=-1*ones(1,size(I,1));
    elseif strcmp(params.scoreMeasure,'levenshtein')
        s=inf*ones(1,size(I,1));
    end
    exists = zeros(1,size(I,1));        
    if ~isempty(CACHE.ind)
%         tic;
        [members,loc] = ismember(I,CACHE.ind,'rows');
%         toc;
        if any(members)
            exists(members) = 1;             
            s(members) = CACHE.eval(loc(loc > 0));
            if strcmp(params.scoreMeasure,'overlap') && ...
                    ~ismember(max(CACHE.eval),s) && length(s) > 1 || ...
                    strcmp(params.scoreMeasure,'levenshtein') && ...
                    ~ismember(min(CACHE.eval),s) && length(s) > 1
                warning('fitnessFcn:ElitismError','Elitist members not found within the population.\nCurrent position: %d\nBest in cache: %.4f\nBest in s (elitist): %.4f',CACHE.pos,max(CACHE.eval),max(s));
            end
        end
    end
end

function model = evalFit(X,XtrainT,Xtrain_l,Ytrain,params,k,seg,mnseg,mk)
% Output:
%   s: scores
%   model: model structure
%      SM: Subgesture models (centroid sequences) for the k gestures
%      C: cluster indices for each sample
%      D: Dissimilarity matrix between subgesture models SM
%      M: mean sequence models
%      KM: Cost matrix of the mean sequence models in terms of SM
%      KT: Cost matrix of the test sequence in terms of SM    
%      bestThs: best thresholds for the k detected gestures    
%      nThreshs: Number of thresholds for testing

    X_I = getDataPartitions(X,seg');
    
    model = params;
    
%     if isempty(params.D)
        %% Temporal Clustering
        % Obtain subsets using the k-means DTW algorithm    
        if any(k > size(seg,2))
            error('fitnessFcn:k','k cannot be greater than the number of segments');
        end
        [CsTrain,~,mErrsV,~,timeV,~,Z] = runKMeansDTW(params,[],[],[],Ytrain,[],X_I,[]);

        %% Get clustered training/learning data structures
        [~,kV] = min(mErrsV);
        model.C = CsTrain{kV}{timeV(kV)};

        %% Obtain Subgesture Model for training/learning data
        model.SM = Z{kV}{timeV}; emptyCells = cellfun(@isempty,model.SM); model.SM(emptyCells) = [];
                
%     else
%         model.C = params.C;
%         model.SM = params.SM;
%         model.D = params.D;
%         model.KM = params.KM;
%     end
    
    if ~params.phmm.hmm
        %% compute Similarity matrix
        model.D = getSimilarities(model.SM);
        if sum(~any(model.D))
            error('fitnessFcn:D','Some elements of the dissimilarity matrix are wrong');
        end
        
        %% Compute Median (SubGesture) Models for each gesture 
        if ~strcmp(params.msmType,'fix') && mnseg > 0 && mk > 0
            model.M = getMSM(params,Xtrain_l,model,mnseg,mk);
        elseif strcmp(params.msmType,'evoSegs')
            model.M = getMSM(params,Xtrain_l,model);
        elseif strcmp(params.msmType,'none')
            model.M = params.M;
        else
            error('fitnessFcn:optError','Option chosen for the Subgesture Models is not correct. Check params.msmType variable');
        end

        %% Compute costs of representing (Subgesture) Models 'M' in terms of Subgesture Models 'SM'
        model.KM = cell(1,length(model.M));
%         if ~strcmp(params.msmType,'none')
            display('Computing the costs of the training sequences in terms of SM and mean align to the minimum cost ... ');
            for l = 1:length(model.KM)
                model.KM{l} = cell(1,length(Xtrain_l{l}));
                for sample = 1:length(model.KM{l})
                    KM = getUpdatedCosts(Xtrain_l{l}{sample},model.SM);
                    model.KM{l}{sample} = KM';
%                     model.KM{l}{sample} = min(KM)';
                end
            end
            model.KM = getModels(model.KM,length(model.KM),params);
            for l = 1:length(model.KM)
                model.KM{l} = model.KM{l}';                
            end
%         else
% %             tic;
%             display('Computing the costs of the models M in terms of SM ...');
%             for i = 1:length(model.KM)            
%                 if params.k > 0
%                     model.KM{i} = getUpdatedCosts(model.M{i}{params.k},model.SM);
%                 else
%                     model.KM{i} = getUpdatedCosts(model.M{i},model.SM);
%                 end
%             end
% %             toc;
%         end
    
        %% Test the subsequence model
%         model.bestThs = params.bestThs;
%         model.nThreshs = params.nThreshs;
%         model.scoreMeasure = params.scoreMeasure;
%         model.maxWlen = params.maxWlen;
%         model.k = params.k;
        
%         display('Training the model parameters ...');
%         [model,s,~] = g(model,XtrainT,Ytrain);
    else
        if ~strcmp(params.phmm.clustType,'none')
            %% Discretize X
            model.Ctrain = performClustering(X_I,Ytrain,params.phmm.clustType,params.phmm.kD,params.phmm.cIters);
            X_I = discretizeSequence(model.Ctrain,X_I);            
        end
        if iscell(X_I)
            Dtrain = cell(1,length(X_I));
            for sample = 1:length(X_I)
                KM = getUpdatedCosts(X_I{sample},model.SM);
                [~,Dtrain{sample}] = min(KM);
            end
            Dtrain = cell2mat(Dtrain);
        else
            KM = getUpdatedCosts(X_I,SM);
            [~,Dtrain] = min(KM);
        end
        
        %% train HMM for this data partitions and clusters
        display('Learning the HMM Model ...');
        [model.phmm.hmmTR, model.phmm.hmmE]=learnHMM(params.phmm.states,Dtrain,params.phmm.it);
%         %% Discretize and evaluate training sequence
%         if ~strcmp(params.phmm.clustType,'none')
%             XtrainT = discretizeSequence(model.Ctrain,XtrainT);
%         end
%         Dseq = cell(1,length(XtrainT));
%         if iscell(XtrainT)
%             for sample = 1:length(XtrainT)
%                 KT = getUpdatedCosts(XtrainT{sample},model.SM);
%                 [~,Dseq{sample}] = min(KT);
%             end
%         else
%             KT = getUpdatedCosts(XtrainT,model.SM);
%             [~,Dseq] = min(KT);
%         end
%         display(sprintf('Evaluating training sequence ...'));
%         s = evaluateHMM(Dseq, model.phmm.hmmTR, model.phmm.hmmE);
    end
end