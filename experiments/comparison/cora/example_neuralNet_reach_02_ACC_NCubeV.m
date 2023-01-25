function completed = example_neuralNet_reach_02_ACC
% example_neuralNet_reach_02_ACC - example of reachability analysis for a
%    neural network adaptive cruise control
%
%
% Syntax:
%    completed = example_neuralNet_reach_02_ACC()
%
% Inputs:
%    -
%
% Outputs:
%    completed - true/false

%------------- BEGIN CODE --------------

disp("BENCHMARK: Adaptive Cruise Controller (ACC)")

% Parameters --------------------------------------------------------------

R0 = interval([0.1;-4],[0.5;0]);
%interval([90; 32; 0; 10; 30; 0], [110; 32.2; 0; 11; 30.2; 0]);

params.tFinal = 0.1;
params.R0 = polyZonotope(R0);


% Reachability Settings ---------------------------------------------------

options.timeStep = 0.1;
options.taylorTerms = 4;
options.zonotopeOrder = 20;
options.alg = 'lin';
options.tensorOrder = 2;


% Parameters for NN evaluation --------------------------------------------
evParams = struct();
evParams.bound_approx = true;
evParams.polynomial_approx = "cub";
evParams.num_generators=300;


% System Dynamics ---------------------------------------------------------

% parameter
%u_f = 0.0001;
%a_lead = -2;
%v_set = 30;
%T_gap = 1.4;
%D_default = 10;

% open-loop system
%A = [0 1; 0 0];
%B = [0;1];
%f = @(x, u) [x(2); x(3); -2 * x(3) + 2 * a_lead - u_f * x(2)^2; ...
%    x(5); x(6); -2 * x(6) + 2 * u(1) - u_f * x(4)^2];
%sys = linearSys('ACC',A,B);
f = @(x, u) [x(2); u(1)];
sys = nonlinearSys(f,2,1);

% affine map x_ = C*x + k mapping state x to input of neural network x_
C = [1 0;0 1];
k = [0; 0];

% load neural network controller
% [5, 20, 20, 20, 20, 20, 1]
load('acc-2000000-64-64-64-64-retrain-100000-200000-0.9.mat');

actFun = [{'identity'}, repmat({'ReLU'}, [1, length(W)])];
W = [{C}, W];
b = [{k}, b];

nn = neuralNetworkOld(W, b, actFun);

% construct neural network controlled system
sys = neurNetContrSys(sys, nn, 0.1);


% Simulation --------------------------------------------------------------

tic;
simOptions.points = 1000;
simRes = simulateRandom(sys, params, simOptions);
tSim = toc;
disp(['Time to compute random simulations: ', num2str(tSim)]);


% Check Violation --------------------------------------------------------

tic;
isVio = false;
for i = 1:length(simRes.x)
    % relative distance D_rel
    distance = [1, 0]*simRes.x{i}';
%    safe_distance = D_default + [0, 0, 0, 0, T_gap, 0]*simRes.x{i}';
%    % safe distance D_safe
    isVio = isVio || ~all(distance > 0);
end
tVio = toc;
disp(['Time to check violation in simulations: ', num2str(tVio)]);

if isVio
    disp("Result: VIOLATED")
    R = params.R0;
    tComp = 0;
    tVeri = 0;
end
%else
    % Reachability Analysis -----------------------------------------------

    tic;
    R = reach(sys, params, options, evParams);
    tComp = toc;
    disp(['Time to compute reachable set: ', num2str(tComp)]);

    % Verification --------------------------------------------------------

    tic;
    isVeri = true;
    for i = 1:length(R)
        for j = 1:length(R(i).timeInterval.set)
            % relative distance D_rel
            distance = interval([1, 0]*R(i).timeInterval.set{j});
            %safe_distance = D_default + interval([0, 0, 0, 0, T_gap, 0]*R(i).timeInterval.set{j});
            % safe distance D_safe
            isVeri = isVeri && (infimum(distance) > 0);
        end
    end
    tVeri = toc;
    disp(['Time to check verification: ', num2str(tVeri)]);

    disp(evParams);
    if isVeri
        disp('Result: VERIFIED');
    else
        disp('Result: UNKNOWN');
    end
%end

disp(['Total Time: ', num2str(tComp+tVeri)]);

% Visualization -----------------------------------------------------------

% disp("Plotting..")
% figure; hold on; box on;
% 
% % plot reachable sets
% for i = 1:length(R)
%     for j = 1:length(R(i).timeInterval.set)
% 
%         time = R(i).timeInterval.time{j};
% 
%         % relative distance D_rel
%         temp = interval([1, 0, 0, -1, 0, 0]*R(i).timeInterval.set{j});
%         h1 = plot(cartProd(time, temp), [1, 2], 'FaceColor', [0, .8, 0]);
% 
%         % safe distance D_safe
%         temp = D_default + interval([0, 0, 0, 0, T_gap, 0]*R(i).timeInterval.set{j});
%         h2 = plot(cartProd(time, temp), [1, 2], 'FaceColor', [0.8, 0, 0]); 
%     end
% end
% 
% % plot simulation
% for i = 1:length(simRes.x)
%     % relative distance D_rel
%     distance = [1, 0, 0, -1, 0, 0]*simRes.x{i}';
%     safe_distance = D_default + [0, 0, 0, 0, T_gap, 0]*simRes.x{i}';
%     % safe distance D_safe
%     ss = plot(simRes.t{i}, distance,'Color','k');
% end
% 
% % labels and legend
% xlabel('time');
% ylabel('distance');
% legend([h1, h2, ss], 'Distance', 'Safe Distance', 'Simulations');
% 
% % example completed
completed = true;

%------------- END OF CODE --------------
