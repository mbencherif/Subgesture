function state = plotMeanScores(options,state,~,params,S_eu)
% plot mean scores
% S_eu: Mean score directly obtained from DTW with euclidean distance

if state.Generation < 1
    return;
end

display(sprintf('Generation %d\n\n',params.generations-options.Generations+state.Generation));

x = 1:1:params.generations-options.Generations+state.Generation;
S_eu = S_eu*ones(1,length(x));

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

if length(S) >= options.Generations
    warning('Score length is greater or equal to the total number of generations');
end

try 
    s_end = S(end);
    if s < s_end
        s = s_end;
    end
catch
end

S = [S s];

if length(S) ~= length(x)
    warning('Score length is must be equal to the x axis in order to plot');
	S(length(x)+1:end) = [];
end

plot(x,S_eu,'k');
hold on
plot(x,S,'b');
hold off
if strcmp(params.scoreMeasure,'overlap')
    title(sprintf('Mean overlaps throughout %d generations',params.generations-options.Generations+state.Generation));
elseif strcmp(params.scoreMeasure,'levenshtein')
    title(sprintf('Mean levenshtein distances throughout %d generations',params.generations-options.Generations+state.Generation));
end
% legend('Euclidean','Model');
xlabel('Generation');
if strcmp(params.scoreMeasure,'overlap')
    ylabel('Mean overlaps');
elseif strcmp(params.scoreMeasure,'levenshtein')
    ylabel('Mean levenshtein distances');
end