function [h] = showSkeleton(skeleton,image,nSkeleton,lHandColor,rHandColor)

if ~exist('lHandColor','var')
    lHandColor = 'r';
end
if ~exist('rHandColor','var')
    rHandColor = 'r';
end

h=figure('visible','off');
%This is the order of the joints returned by the Kinect adaptor:

   Hip_Center = 1;
   Spine = 2;
   Shoulder_Center = 3;
   Head = 4;
   Shoulder_Left = 5;
   Elbow_Left = 6;
   Wrist_Left = 7;
   Hand_Left = 8;
   Shoulder_Right = 9;
   Elbow_Right = 10;
   Wrist_Right = 11;
   Hand_Right = 12;
   Hip_Left = 13;
   Knee_Left = 14;
   Ankle_Left = 15;
   Foot_Left = 16; 
   Hip_Right = 17;
   Knee_Right = 18;
   Ankle_Right = 19;
   Foot_Right = 20;

%Show the RGB image.

imshow(image);

%Create a skeleton connection map to link the joints.

SkeletonConnectionMap = [[1 2]; % Spine
                         [2 3];
                         [3 4];
                         [3 5]; %Left Hand
                         [5 6];
                         [6 7];
                         [7 8];
                         [3 9]; %Right Hand
                         [9 10];
                         [10 11];
                         [11 12];
                         [1 17]; % Right Leg
                         [17 18];
                         [18 19];
                         [19 20];
                         [1 13]; % Left Leg
                         [13 14];
                         [14 15];
                         [15 16]];

%Draw the skeletons on the RGB image.

for i = 1:19
     
     if nSkeleton > 0
         X1 = [skeleton(SkeletonConnectionMap(i,1),1,1) skeleton(SkeletonConnectionMap(i,2),1,1)];
         Y1 = [skeleton(SkeletonConnectionMap(i,1),2,1) skeleton(SkeletonConnectionMap(i,2),2,1)];
         if ismember(i,6:7)
            line(X1,Y1, 'LineWidth', 4, 'LineStyle', '-', 'Marker', '+', 'Color', lHandColor);
         elseif ismember(i,10:11)
            line(X1,Y1, 'LineWidth', 4, 'LineStyle', '-', 'Marker', '+', 'Color', rHandColor); 
         else
            line(X1,Y1, 'LineWidth', 1.5, 'LineStyle', '-', 'Marker', '+', 'Color', 'r');
         end
         hold on;
         plot(X1,Y1,'bo','LineWidth',5);
     end
     if nSkeleton > 1
         X2 = [skeleton(SkeletonConnectionMap(i,1),1,2) skeleton(SkeletonConnectionMap(i,2),1,2)];
         Y2 = [skeleton(SkeletonConnectionMap(i,1),2,2) skeleton(SkeletonConnectionMap(i,2),2,2)];     
         if ismember(i,6:7)
            line(X2,Y2, 'LineWidth', 4, 'LineStyle', '-', 'Marker', '+', 'Color', lHandColor);
         elseif ismember(i,10:11)
            line(X2,Y2, 'LineWidth', 4, 'LineStyle', '-', 'Marker', '+', 'Color', rHandColor); 
         else
            line(X2,Y2, 'LineWidth', 1.5, 'LineStyle', '-', 'Marker', '+', 'Color', 'g');
         end
            
     end
    hold on;
 end
 hold off;