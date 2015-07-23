function state = plotMeanScores(options,state,~,params,S_base,X,Y,X_l)
% plot mean scores
% S_base: Mean score directly obtained from DTW with euclidean distance

if state.Generation < 1
    return;
end

currentGeneration = params.generations-options.Generations+state.Generation;

display(sprintf('Generation %d\n\n',currentGeneration));

x = 1:1:currentGeneration;
S_base = S_base*ones(1,length(x));

if strcmp(params.scoreMeasure,'overlap');
    s = -state.Best(end);    
    if state.Generation > 1
        if s < -state.Best(end-1)
            s = -state.Best(end-1); 
        end
    end
elseif strcmp(params.scoreMeasure,'levenshtein');
    s = state.Best(end);
    if state.Generation > 1
        if s > state.Best(end-1)
            s = state.Best(end-1);
        end
    end
end

global S;

try 
    s_end = S(end);
    if s < s_end
        s = s_end;
    end
catch
end

S = [S s];

if length(S) > length(x)
    warning('Score length is must be equal to the x axis in order to plot');
    S(length(x)) = S(end);
	S(length(x)+1:end) = [];
end
display(sprintf('Best validation score: %.4f\n',S(end)));
plot(x,S_base,'k');
hold on
plot(x,S,'b');
if ~isempty(X),
    global Stest; global BESTIND;
    if length(BESTIND) > 1
        if ~isequal(BESTIND(end).model,BESTIND(end-1).model) 
            if isempty(BESTIND(end).model)
                BESTIND(end).model = BESTIND(end-1).model;
            end
            try
                stest = testLastGen(state,BESTIND(end).model,X,Y,X_l);
            catch e
                display(e);
            end
        else
            stest = Stest(end);
        end
    else
        try
            stest = testLastGen(state,BESTIND(end).model,X,Y,X_l);
        catch e
            display(e);
        end
    end
    if length(Stest) > 1
        if stest < Stest(end), stest = Stest(end); end
    end
    Stest = [Stest stest];
    if length(Stest) > length(x)
        Stest(length(x)) = Stest(end);
        Stest(length(x)+1:end) = [];
    elseif length(Stest) < length(x)
        Stest = Stest(end)*ones(1,length(x));
    end
    display(sprintf('Best test score: %.4f\n',Stest(end)));
    plot(x,Stest,'r');    
end    
hold off
title(sprintf('Mean scores throughout %d generations',currentGeneration));
% legend('Euclidean','optModel','Test');
xlabel('Generation');
ylabel('Mean scores');
