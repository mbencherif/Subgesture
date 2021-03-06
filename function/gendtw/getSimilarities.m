function S = getSimilarities(X,params)
% compute normalized similarity matrix from the distances between sequences
%   Input -
%       X: Cell with sequences to compare
%       params: set of parameters
%   Output -
%       S: Similary matrix
if params.darwin
    n = size(X,1);
else
    n = size(X,2);
end
A = zeros(n,n);
if n > 1
    for i = 1:n
        for j = 1:n
            if i < j
                if params.darwin
                    A(i,j) = pdist2(X(i,:),X(j,:));
                else
                    W = dtwc(X{i},X{j},true);
                    A(i,j) = W(end,end);
                end
            end 
        end
    end
    B = A./max(max(A));
    S = B + B';
else
    S = 0;
end


% imagesc(S)
% hold on;
% colormap(gray)
% hold off;
