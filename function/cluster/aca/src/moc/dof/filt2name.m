function names = filt2name(filt)
% Obtain the joint names corresponding to the specific filtering method.
%
% Input
%   filt    -  filtering method, 'barbic' | 'arm' | 'kitchen'
%                'barbic'   -  14 joints, See: http://graphics.cs.cmu.edu/projects/segmentation
%                'arm'      -  right arm
%                'kitchen'  -  arm+leg+torso
%
% Output
%   names   -  joint names, 1 x nJ
%
% History
%   create  -  Feng Zhou (zhfe99@gmail.com), 03-31-2009
%   modify  -  Feng Zhou (zhfe99@gmail.com), 09-11-2009

if strcmpi(filt, 'barbic')
    names = {'lowerback', ...
             'upperback', ...
             'thorax', ...
             'lowerneck', ...
             'upperneck', ...
             'head', ...
             'rhumerus', ...
             'rradius', ...
             'lhumerus', ...
             'lradius', ...
             'rfemur', ...
             'rtibia', ...
             'lfemur', ...
             'ltibia'};

elseif strcmp(filt, 'leg')
    names = {'lhumerus', 'rhumerus', ...,
             'lwrist', 'rwrist', ...
             'lfemur', 'rfemur', ...
             'ltibia', 'rtibia'};

elseif strcmp(filt, 'hand')
    names = {'lowerback', 'upperback', ...
             'lhand', 'rhand', ...
             'lradius', 'rradius'};         

elseif strcmpi(filt, 'all')
%     names = {};
    names = {'lowerback', ...
             'upperback', ...
             'thorax', ...
             'lowerneck', ...
             'upperneck', ...
             'head', ...
             'rclavicle', ...
             'rhumerus', ...
             'rradius', ...
             'rwrist', ...
             'rhand', ...
             'rfingers', ...
             'rthumb', ...
             'lclavicle', ...
             'lhumerus', ...
             'lradius', ...
             'lwrist', ...
             'lhand', ...
             'lfingers', ...
             'lthumb', ...
             'rfemur', ...
             'rtibia', ...
             'rfoot', ...
             'rtoes', ...
             'lfemur', ...
             'ltibia', ...
             'lfoot', ...
             'ltoes'};
      
elseif strcmp(filt, 'all2')
      names = {'pelvis', ...
               'lfemur', ...
               'ltibia', ...
               'lfoot', ...
               'ltoes', ...
               'rfemur', ...
               'rtibia', ...
               'rfoot', ...
               'rtoes', ...
               'lowerback', ...
               'upperback', ...
               'lclavicle', ...
               'lhumerus', ...
               'lradius', ...
               'lhand', ...
               'rclavicle', ...
               'rhumerus', ...
               'rradius', ...
               'rhand', ...
               'neck'};

elseif strcmpi(filt, 'kitchen')
    names = {'lowerback', ...
            'lhumerus', ...
            'lradius', ...
            'lfemur', ...
            'rhumerus', ...
            'rfemur', ...
            'rradius'};
        
elseif strcmpi(filt, 'arm')
    names = {'rhumerus', ...
            'rradius'};%, ...
            % 'lhumerus', 'lradius'
            %'rhand', 'lhand', ...};

else
    error('unknown filtering method');
end
