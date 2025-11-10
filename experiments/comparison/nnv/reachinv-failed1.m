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

start_p=10.1;
end_p=10.15;

epsilon=0.1


step_size=0.05;
inv_step_size=2;%0.1;
p_step = start_p:step_size:end_p;
for i=1:length(p_step)
    % -sqrt(rPos*2*100)
    b = sqrt(p_step(i)*2*100);
    min_v = -b;
    % pold >= pold + T*vold + 0.5*T^2*Amax = pold + T*vold + 0.5*T^2*100
    % <-> -T*Amax / 2 = -0.1*(-100)/2 = 5 >= vold
    max_v = 5;
    lb = [p_step(i); min_v];
    ub = [p_step(i)+step_size; max_v];
    max_reach=p_step(i) + 0.1*min_v - 0.5;
    disp(lb);
    disp(ub);
    % Underapproximate invariant bound
    p_inv_step = max_reach:inv_step_size:(p_step(i)+step_size);
    %unsafe_mat = zeros(0,2);
    %unsafe_vec = zeros(0,1);
    % This is wrong because what we need is the disjunction of these constraints...
    for j=1:length(p_inv_step)
        p1 = p_inv_step(j);
        p2 = p_inv_step(j)+inv_step_size;
        v1 = sqrt(p1*2*100);
        v2 = sqrt(p2*2*100);
        unsafe_mat = [unsafe_mat;((v2-v1)/(p2-p1)) 1];
        unsafe_vec = [unsafe_vec;-(v1-((v2-v1)/(p2-p1))*p1)];
    end
    
    U = HalfSpace(unsafe_mat, unsafe_vec);
    init_set = Star(lb,ub);
    reachPRM_lin.init_set = init_set;

    [safe, counterExamples, verifyTime] = nncs_lin.verify(reachPRM_lin, U);
    if ~isequal(safe,"SAFE")
        disp("UNSAFE");
    end
    fprintf('\nTIME: %.4f\n', verifyTime);
end



% This approach does not work because the unsafe region is not convex.