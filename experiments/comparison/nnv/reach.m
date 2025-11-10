%% Reachability analysis of ACC
% Load components and set reachability parameters
net = Load_nn('acc-2000000-64-64-64-64-retrain-100000-200000-0.9.mat');
%net = Load_nn('acc-200000-64-64-64-64-dumb_but_safe.mat');
reachStep = 0.1;
controlPeriod = 0.1;
output_mat = [1 0;0 1]; % feedback: relative distance, relative velocity
A=[0 1;0 0];
B=[0;1];
C=[1 0;0 1];
D=[0;0];
plant = LinearODE(A,B,C,D);
%plant = NonLinearODE(2,1,@dynamicsACC, reachStep, controlPeriod, output_mat);

%% Reachability analysis
tF = 5; % seconds
time = 0:controlPeriod:1.0;
steps = length(time);
input_ref = [];%[1;-3];
% Initial set
lb = [0.1; -4];
ub = [0.5; 0];
init_set = Star(lb,ub);
% Store all reachable sets
% Execute reachabilty analysis
% Todo: Invert sequence, i.e. first controller then plant
nncs = LinearNNCS(net,plant);
%nncs = NonlinearNNCS(net,plant);
reachPRM.ref_input = input_ref;
reachPRM.numSteps = 1;%2;
reachPRM.init_set = init_set;
reachPRM.numCores = 1;
reachPRM.controlPeriod=0.1
reachPRM.plantTimStep=0.1
reachPRM.reachMethod = 'exact-star';
%reachPRM.reachMethod = 'approx-star';

unsafe_mat = [1 0];
unsafe_vec = 0;
U = HalfSpace(unsafe_mat, unsafe_vec);

[safe, counterExamples, verifyTime] = nncs.verify(reachPRM, U);
disp(verifyTime)

% [R,rT] = nncs.reach(reachPRM);
% disp("Time to compute ACC reach sets: " +string(rT));

%% Visualize results
% t_gap = 1.4;
% D_default = 10;
% outAll = [];
% safe_dis = [];
% for i=1:length(plant.intermediate_reachSet)
%     outAll = [outAll plant.intermediate_reachSet(i).affineMap(output_mat,[])];
%     %safe_dis = [safe_dis plant.intermediate_reachSet(i).affineMap([0 0 0 0 t_gap 0], D_default)];
% end
% times = 0.02:0.02:0.2;
% Star.plotRanges_2D(outAll,1,times,'b');
% hold on;
% 


