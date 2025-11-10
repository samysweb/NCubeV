%% Reachability analysis of ACC
% Load components and set reachability parameters
net = Load_nn('acc-2000000-64-64-64-64-retrain-100000-200000-0.9.mat');
reachStep = 0.1;
controlPeriod = 0.1;
output_mat = [1 0;0 1]; % feedback: relative distance, relative velocity
A=[0 1;0 0];
B=[0;1];
C=[1 0;0 1];
D=[0;0];
plant_lin = LinearODE(A,B,C,D);
plant_nonlin = NonLinearODE(2,1,@dynamicsACC, reachStep, controlPeriod, output_mat);

%% Reachability analysis
time = 0:controlPeriod:1.0;
steps = length(time);
input_ref = [];%[1;-3];
% Store all reachable sets
% Execute reachabilty analysis
% Todo: Invert sequence, i.e. first controller then plant
nncs_lin = LinearNNCS(net,plant_lin);
nncs_nonlin = NonlinearNNCS(net,plant_nonlin);
reachPRM_lin.ref_input = input_ref;
reachPRM_lin.numSteps = 1;
reachPRM_lin.numCores = 4;
reachPRM_lin.controlPeriod=0.1
reachPRM_lin.plantTimStep=0.1
reachPRM_lin.reachMethod = 'exact-star';

unsafe_mat = [1 0];
unsafe_vec = 0;
U = HalfSpace(unsafe_mat, unsafe_vec);


step_size=0.05
p_step = 0.1:step_size:100;
for i=1:length(p_step)
    % -sqrt(rPos*2*100)
    b = sqrt(p_step(i)*2*100);
    min_v = -b;
    max_v = b;
    lb = [p_step(i); min_v];
    ub = [p_step(i)+step_size; max_v];
    disp(lb);
    disp(ub);
    init_set = Star(lb,ub);
    reachPRM_lin.init_set = init_set;

    [safe, counterExamples, verifyTime] = nncs_lin.verify(reachPRM_lin, U);
    if ~isequal(safe,"SAFE")
        disp("UNSAFE");
    end
    fprintf('\nTIME: %.4f\n', verifyTime);
end



