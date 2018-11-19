%  Author : Mohammad Khayatian
%  Arizona State University

clc;
clear all;
close all;
% v = VideoWriter('mohi.avi');          % for video capturing
% open(v);                              % for video capturing
rng(4444);                                % load random number generator with seed = 4444;
% Parameters
SimulationTime = 200;       % Seconds
StepTime = 0.01;            % Seconds
flow = 0.02;                   % Car/Second/Road
SpawnThreshold = 1/flow;    % Seconds
NumberOfRoads = 4;          % DON'T CHANGE
NumberOfLanesPerRoad = 3;    % DON'T CHANGE
IMWidth = 60;
IntersectionBounds = struct;
IntersectionBounds.xb1 = -200;
IntersectionBounds.xb2 = 0;
IntersectionBounds.xb3 = IMWidth;
IntersectionBounds.xb4 = IMWidth -IntersectionBounds. xb1;
IntersectionBounds.yb1 = IntersectionBounds.xb1;
IntersectionBounds.yb2 = IntersectionBounds.xb2;
IntersectionBounds.yb3 = IntersectionBounds.xb3;
IntersectionBounds.yb4 = IntersectionBounds.xb4;

laneWidth = (IntersectionBounds.xb3-IntersectionBounds.xb2)/(NumberOfLanesPerRoad*2);
TransmitLine = 100;
TurnSpace = 2;
%% Print parameters
printStep = 20;
printLabel = 1;         %% no print = 0, print ID = 1, print Speed = 2;
print3D = 0;            %% 3D = 1, 2D = 0;
%% Car Parameters
CarLength = 6*1;
CarWidth = 2;
L = 5;
amax = 5;
amin = -8;
minSpeed = 5;
maxSpeed = 15;
CarGenerationDuration = SimulationTime - 100;
%% Network
Log = 1;            % 1 for logging all packets
%% Intersection Manager
% method = 'Crossroads';
method = 'RIM';
ComputationSpeedFactor = 10;
RequestedVehiclesList = [];
Vmax = 15;
Vmin = 2;
%% Simulation
count = 1;
WCRTD = 2; %WORST CASE ROUND-TRIP DELAY (Seconds)
WCND = 0.5; %WORST-CASE NETWORK DELAY (Seconds)
time = 0;
ID = 0;
Distancethreshold = sqrt((CarLength/2)^2 + (CarWidth/2)^2) + 0.1;
failureCheck = 1;
VehicleList = [];
Network = [];
failures = [];
c1 = 1;
GeneratedCarTimeStamp = SpawnThreshold * rand(1,NumberOfRoads * NumberOfLanesPerRoad);
while (time < SimulationTime)
    tic
    time = count * StepTime;
    %% Safety Checking
    
    if failureCheck == 1
        for i = 1 : length(VehicleList)
            First = VehicleList(i);
            for j = 1 : length(VehicleList)
                Secondnd = VehicleList(j);
                d = sqrt( (VehicleList(i).position.x - VehicleList(j).position.x)^2 + ...
                    (VehicleList(i).position.y - VehicleList(j).position.y)^2);
                if (i ~= j) && (d < Distancethreshold) % if distance is less than Distancethreshold
                    failures = [failures;VehicleList(i).ID VehicleList(j).ID d];
                end
            end
        end
    end
               
    
    %% Vehicle Generation
    
    for Lane = 1 : NumberOfRoads * NumberOfLanesPerRoad
        if (time >= GeneratedCarTimeStamp(Lane) && time < CarGenerationDuration)
            ID = ID + 1;
            VehicleList = [VehicleList; generateCar(Lane,ID,IntersectionBounds,laneWidth,minSpeed,maxSpeed,time)];
            GeneratedCarTimeStamp(Lane) = time + SpawnThreshold + rand;
        end
    end
     
    %% Vehicles
    
    if ~isempty(VehicleList)
        
        [Network, VehicleList] = SendToNetwork(VehicleList, Network, IntersectionBounds, TransmitLine,time,WCND,Log);
        
        [Network, VehicleList] = ReceiveFromNetwork(VehicleList, Network,time);
        
        VehicleList = PathPlanning(VehicleList,laneWidth,IntersectionBounds,TurnSpace,Vmax,TransmitLine,StepTime);
        
        VehicleList = ACC(VehicleList,CarLength);               % Adaptive Cruise Control
        
        VehicleList = vehicleDynamics(VehicleList,L,StepTime,amax,amin,time,method,TransmitLine,Vmax,Vmin);
        
    end
    
    %% Remove out of bound vehicles
    car = 1;
    
    while car < length(VehicleList) + 1                
        if (VehicleList(car).position.x > IntersectionBounds.xb4) || ...
           (VehicleList(car).position.x < IntersectionBounds.xb1) || ...
           (VehicleList(car).position.y < IntersectionBounds.yb1) || ...
           (VehicleList(car).position.y > IntersectionBounds.yb4)
            averageDelay(c1) = time - VehicleList(car).spawnTime;
            c1 = c1 + 1;
            VehicleList(car)=[];
            car = car - 1;
        end
        car=car+1;
    end
    
    
    %% Intersection Manager (IM)
    
    for iteration = 1 : ComputationSpeedFactor
        [Network, RequestedVehiclesListNew] = IntersectionManagement(Network, RequestedVehiclesList,...
        Vmax,Vmin,laneWidth,TransmitLine,time,CarLength,WCRTD,WCND,Log,method,IMWidth);
        RequestedVehiclesList = RequestedVehiclesListNew;
    end
    
    %% drawing
    
    if rem(count,printStep)==0
%         text(80,100,'time');text(100,100,num2str(time));
%         text(80,120,'Network');text(120,120,num2str(length(Network)));
        
        ax = gcf;
        
        if print3D == 1
            drawVehicle3D(VehicleList,CarLength,CarWidth,printLabel)
            drawIM3D(IntersectionBounds,TransmitLine,laneWidth)
            zlim([0 40]);
            view(30,85)
            ax.Position = [1 41 1920/2 963/2];
        else 
            drawVehicle(VehicleList,CarLength,CarWidth,printLabel)
            drawIM(IntersectionBounds,TransmitLine,laneWidth)
            ax.Position = [123 18 1281 963];
        end
        grid on
        axis ([IntersectionBounds.xb1 IntersectionBounds.xb4 IntersectionBounds.yb1 IntersectionBounds.yb4])
        pause(0.0001)
%         frame = getframe;         % for video capturing
%         writeVideo(v,frame);      % for video capturing
        cla
    end
    count = count + 1;
    elpsed1(count+1)=toc;
end
drawIM(IntersectionBounds,TransmitLine,laneWidth)
axis ([IntersectionBounds.xb1-10 IntersectionBounds.xb4+10 IntersectionBounds.yb1-10 IntersectionBounds.yb4+10])
disp(failures)
sum (averageDelay)
% close(v);                         % for video capturing
