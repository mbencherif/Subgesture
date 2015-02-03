function runGenDTW(measure,lastGen)

close all
addPath

%% Generate global variables, cache and parameters
varload
if nargin == 0
    measure = 'overlap';
    lastGen = 0;
end
params.scoreMeasure = measure;  % Score Measure: 'overlap' or 'levenshtein'
if strcmp(measure,'overlap')
    CACHE.eval = zeros(...      % Cache with the scores of each individual
        params.population*100,1);
elseif strcmp(measure,'levenshtein')
    CACHE.eval = inf*ones(...   % Cache with the scores of each individual
        params.population*100,1);
end

%% Prepare training data depending on the chosen option and parameters
% Load data:5
%     if nframesSeg is 0, then initial segmentation is generated from the skeleton labels
[X,Y,Xtest,Ytest] = prepareData(nrsamples,nseqs,nframesSeg,params.k0);
% display('Press a key to continue...');
% pause();

%% Compute initial segmentation from motion
% [seg0,fr_fixed,params] = computeMagnitudes(X{1},params);
% [~,~,Xtrain,I,~,segTrain,~] = getDataSegments(X,Y,params.N,params.k0,params.nmin,params.nmax);

%% Prepare training data depending on the chosen option and parameters
% DATATYPE = 'chalearn2014';
% NORMTYPE = 'none';
% COORDS = 'world';
% NAT = 3;
% Load data:
%     if nframesSeg is 0, then initial segmentation is generated from the skeleton labels
% [X,Y,Xtest,Ytest] = prepareData(nrsamples,nseqs,nframesSeg,params.k0);
% X = setDerivatives(X);
% display('Press a key to continue...');
% pause();

%% Obtain all samples grouped (labeled) by gestures
Xtrain_l = getGroupedGestures(X,Y,1);
% Xval_l = getGroupedGestures(X,Y,2);
%Xtrain_l = getGroupedGestures(X,Y,0);

%% Compute median models from training/learning data
% profile -memory on
params.M = getMedianModels(Xtrain_l,length(Xtrain_l)-1,params.mType,false,params.usemax_l);
% profreport

%% Generate development sequences
% l = [24 78 150];    % 78 (more samples for each gesture when k=3);
l = [];
[Xdev,Ydev] = getDevSequences(X,Y,l,noise,secsBatch,nSampGest);

%% Baseline 
% First evaluation with euclidean distance
% profile -memory on
% params.bestThs = [785 650 617 705 442 680 849 873 847 668 501 788 631 884 482 841 670 714 809 497];
% [~,S_eu,~] = g(params,Xdev{2},Ydev{2});
% S_eu
% params.bestThs = [];
% profreport

%% Genetic algorithm optimization
% Evaluation function
if strcmp(params.scoreMeasure,'overlap')    % CHECK X{1} y Xdev{1}
    fEval = @(I) -fitnessFcn(I,X{1},Xdev{1},Xtrain_l,Ydev{1},Xdev{2},Ydev{2},params);    
elseif strcmp(params.scoreMeasure,'levenshtein')
    fEval = @(I) fitnessFcn(I,X{1},Xdev{1},Xtrain_l,Ydev{1},Xdev{2},Ydev{2},params);
end

% Display functions
fPlotComp = @(options,state,flag)plotMeanScores(options,state,flag,params,S_eu);
fPlotSI = @(options,state,flag)plotScoresPopul(options,state,flag,params);
fPlotSG = @(options,state,flag)plotScoreSegs(options,state,flag,params);

% Create function
fCreate = @(GenomeLength,FitnessFcn,options)createIniPopul(GenomeLength,FitnessFcn,options,X{1},params);

% Mutation function
fMutation = @(parents,options,nvars,FitnessFcn,state,thisScore,...
    thisPopulation)mutationFcn(parents,options,nvars,FitnessFcn,...
    state,thisScore,thisPopulation,params,seg0,X{1});

% Crossover function
fCrossOver = @(parents,options,nvars,FitnessFcn,unused,thisPopulation)...
    crossOverFcn(parents,options,nvars,FitnessFcn,unused,thisPopulation,params);

% Options GA
%lastGen = 4;
if exist(strcat('results/',DATATYPE,'/validation/Exp3/',params.Baseline,'Results',num2str(lastGen),'_',num2str(length(JOINTS)),COORDS,num2str(PERCENTDATA),'%_',num2str(NAT),'.mat'),'file')
    if strcmp(params.scoreMeasure,'overlap')
        load(strcat('results/',DATATYPE,'/validation/Exp3/',params.Baseline,'Results',num2str(lastGen),'_',num2str(length(JOINTS)),COORDS,num2str(PERCENTDATA),'%_',num2str(NAT),'.mat'));
    end   
    S = [];
    STATE = state;
    problem.nvars=size(state.Population,2);
    options = gaoptimset(options,'Generations',params.generations-lastGen);
    options = gaoptimset(options,'StallGenLimit',options.StallGenLimit+1);
else
    options = gaoptimset(@ga);
    options = gaoptimset(options,'PopulationSize',params.population);
    options = gaoptimset(options,'Generations',params.generations);
    options = gaoptimset(options,'TolCon',eps);
    options = gaoptimset(options,'StallGenLimit',params.generations);
    options = gaoptimset(options,'EliteCount',2);
    options = gaoptimset(options,'PlotFcns',{@gaplotscorediversity,@gaplotbestf,@gaplotrange,@gaplotdistance,fPlotComp,fPlotSI,fPlotSG});
    % options = gaoptimset(options,'PopInitRange',[params.k0 params.nmin*ones(1,100);params.N params.nmax*ones(1,100)]);
    options = gaoptimset(options,'CreationFcn',fCreate);
    options = gaoptimset(options,'MutationFcn',fMutation);
    options = gaoptimset(options,'CrossoverFcn',fCrossOver);
    options = gaoptimset(options,'Vectorized',params.vectorized);   
    problem.nvars=1+params.N*2;
    if strcmp(params.msmType,'fix'), problem.nvars = problem.nvars+2; end
    
    % Cache with the populations
    CACHE.ind = int32(zeros(params.population*100,problem.nvars,'int32'));

end
% Problem GA
problem.fitnessfcn=fEval;
problem.options=options;

% Run GA
tic;
if strcmp(params.vectorized,'on')
    if matlabpool('size') > 0
        matlabpool close force;
    end    
    pool(2);         % Cache with the populations
end
[x,finalOverlap,exitFlag,output,population,scores] = ga(problem);
if strcmp(params.vectorized,'on')
    matlabpool close;        % Cache with the populations
end
toc;
