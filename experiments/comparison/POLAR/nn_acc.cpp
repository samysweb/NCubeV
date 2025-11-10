#include "../../POLAR/NeuralNetwork.h"
//#include "../NNTaylor.h"
//#include "../domain_computation.h"
//#include "../dynamics_linearization.h"

using namespace std;
using namespace flowstar;

int main(int argc, char *argv[])
{
//	intervalNumPrecision = 600;

	// ./nn_acc order bernstein_order partition_num neuron_approx symb_rem
	// order: Taylor Order
	// bernstein_order: Bernstein Order
	// partition_num: Partition Number
	// neuron_approx: Taylor | Berns | Mix
	// symb_rem: Concrete | Symbolic
	if (argc < 4)
	{
		cout << "Usage: ./nn_acc <order> <bernstein_order> <partition_num>" << endl;
		cout << "order: Taylor Order" << endl;
		cout << "bernstein_order: Bernstein Order > 2" << endl;
		cout << "partition_num: Partition Number" << endl;
		cout << "neuron_approx: Taylor | Berns | Mix" << endl;
		cout << "symb_rem: Concrete | Symbolic" << endl;
		return 1;
	}
	
	/*
	// Declaration of the state variables.
	unsigned int numVars = 7;
	
	// intput format (\omega_1, \psis_1, \omega_2, \psi_2, \omega_3, \psi_3)
	int x0_id = stateVars.declareVar("x0"); // x_lead
	int x1_id = stateVars.declareVar("x1");	// v_lead
	int x2_id = stateVars.declareVar("x2");	// gamma_lead
	int x3_id = stateVars.declareVar("x3");	// x_ego
	int x4_id = stateVars.declareVar("x4");	// v_ego
	int x5_id = stateVars.declareVar("x5"); // gamma_ego
	int u0_id = stateVars.declareVar("u0");
	 
	int domainDim = numVars + 1;
	 
	// Define the continuous dynamics.
	Expression<Real> deriv_x0("x1"); // theta_r = 0
	Expression<Real> deriv_x1("x2"); 
	Expression<Real> deriv_x2("-2 * 2 - 2 * x2 - 0.0001 * x1^2 ");
	Expression<Real> deriv_x2("x3");
	Expression<Real> deriv_x3("x4");
	Expression<Real> deriv_x4("2 * u0 - 2 * x4 - 0.0001 * x3^2");
	Expression<Real> deriv_u0("0");
	 
	// Define the continuous dynamics according to 
	

	vector<Expression<Real>> ode_rhs(numVars);
	ode_rhs[x0_id] = deriv_x0;
	ode_rhs[x1_id] = deriv_x1;
	ode_rhs[x2_id] = deriv_x2;
	ode_rhs[x3_id] = deriv_x3;
	ode_rhs[x4_id] = deriv_x4;
	ode_rhs[x5_id] = deriv_x5;
	ode_rhs[u0_id] = deriv_u0;
	*/

	Interval box;
	
	// Check 'ARCH-COMP20_Category_Report_Artificial_Intelligence_and_Neural_Network_Control_Systems_-AINNCS-_for_Continuous_and_Hybrid_Systems_Plants.pdf'
	// Declaration of the state variables.
    unsigned int numVars = 4;
    Variables vars;
    // intput format (\omega_1, \psi_1, \omega_2, \psi_2, \omega_3, \psi_3)
    int x0_id = vars.declareVar("x0"); // v_set
    int x1_id = vars.declareVar("x1");    // T_gap
    int t_id = vars.declareVar("t");    // time t
    int u0_id = vars.declareVar("u0");    // a_ego
	
    int domainDim = numVars + 1;
	

    ODE<Real> dynamics({"x1","u0","1","0"}, vars);


	// Specify the parameters for reachability computation.
	Computational_Setting setting(vars);

	unsigned int order = atoi(argv[1]);

	// stepsize and order for reachability analysis
	setting.setFixedStepsize(0.1, 5); // order = 4/5
	//setting.setFixedStepsize(0.005, order); // order = 4/5

	// time horizon for a single control step
	//setting.setTime(0.1);

	// cutoff threshold
	setting.setCutoffThreshold(1e-6); //core dumped
	//setting.setCutoffThreshold(1e-7);

	// queue size for the symbolic remainder
	// Not in the newest version??
	//setting.setQueueSize(2000); //200
	// symbolic remainder object (, 2000)

	// print out the steps
	// setting.printOn();

	// remainder estimation
	Interval I(-0.1, 0.1);
	vector<Interval> remainder_estimation(numVars, I);
	setting.setRemainderEstimation(remainder_estimation);

	//setting.printOn();

//	setting.prepare();

	/*
	 * Initial set can be a box which is represented by a vector of intervals.
	 * The i-th component denotes the initial set of the i-th state variable.
	 */
	double w = 0; // 0.5
	int steps = 1; // should be 50
    Interval init_x0(0.1,0.5), init_x1(-4.0,0.0), init_t(0);
	//Interval init_x0(0.1,0.2), init_x1(-4.0,-4.0), init_t(0);
	Interval init_u0(0);
    vector<Interval> X0;
    X0.push_back(init_x0);
	X0.push_back(init_x1);
	X0.push_back(init_t);
	X0.push_back(init_u0);

	// translate the initial set to a flowpipe
	Flowpipe initial_set(X0);
	Symbolic_Remainder symbolic_remainder(initial_set, 50);

	vector<Constraint> safeSet;
	Constraint c1("-x0", vars);			// x0 >= 0
	safeSet.push_back(c1);

	// result of the reachability computation
	Result_of_Reachability result;

	// define the neural network controller
	string nn_name = "acc-2000000-64-64-64-64-retrain-100000-200000-0.9.txt";
	//string nn_name = "controller_5_20_POLAR";
 
	NeuralNetwork nn(nn_name);

	/* Not in the newest version???
	unsigned int maxOrder = 15;
	Global_Computation_Setting g_setting;
	g_setting.prepareForReachability(maxOrder);
	*/
	// no less than 2, otherwise the obtained Bernstein approximation may be wrong
	unsigned int bernstein_order = atoi(argv[2]);
	unsigned int partition_num = atoi(argv[3]);

	unsigned int if_symbo = 1;
 
	double err_max = 0;
	time_t start_timer;
	time_t end_timer;
	double seconds;
	time(&start_timer);
	
	if (if_symbo == 0)
	{
		cout << "High order abstraction starts." << endl;
	}
	else
	{
		cout << "High order abstraction with symbolic remainder starts." << endl;
	}


	clock_t begin, end;
	begin = clock();


	for (int iter = 0; iter < steps; ++iter)
	{
		cout << "Step " << iter << " starts.      " << endl;
		//vector<Interval> box;
		//initial_set.intEval(box, order, setting.tm_setting.cutoff_threshold);
		
     	 
		
		TaylorModelVec<Real> tmv_input;
		//TaylorModelVec<Real> tmv_temp;
		//initial_set.compose(tmv_temp, order, cutoff_threshold);
		/*
		
		*/
		for (int i = 0; i < 2; i++)
		{
			tmv_input.tms.push_back(initial_set.tmvPre.tms[i]);
			//tmv_input.tms.push_back(tmv_temp.tms[i]);
	 
		}

		// taylor propagation (new)
        PolarSetting polar_setting(order, bernstein_order, partition_num, "Taylor", "Concrete");
		//polar_setting.set_num_threads(1);
		TaylorModelVec<Real> tmv_output;
		//tmv_output.tms.push_back(TaylorModel<Real>(-1.7690021, 1));
		tmv_input.tms[0].output(cout,vars);
		cout << "\n";
		tmv_input.tms[1].output(cout,vars);

        if(if_symbo == 0){
            // not using symbolic remainder
            nn.get_output_tmv(tmv_output, tmv_input, initial_set.domain, polar_setting, setting);
        }
        else{
            // using symbolic remainder
            nn.get_output_tmv_symbolic(tmv_output, tmv_input, initial_set.domain, polar_setting, setting);
        }

		initial_set.tmvPre.tms[u0_id] = tmv_output.tms[0];

		//Matrix<Interval> rm1(nn.get_num_of_outputs(), 1);
		cout << "\nOutput: ";
		initial_set.tmvPre.tms[u0_id].output(cout,vars);
		cout << "\n";
		//.Remainder(rm1);
		//cout << "Neural network taylor remainder: " << rm1 << endl;
			
//		cout << "TM -- Propagation" << endl;

		dynamics.reach(result, initial_set, 0.1, setting, safeSet, symbolic_remainder);

		if (result.status == COMPLETED_SAFE || result.status == COMPLETED_UNSAFE || result.status == COMPLETED_UNKNOWN)
		{
			initial_set = result.fp_end_of_time;
//			cout << "Flowpipe taylor remainders: " << endl;
//			for (int i = 0; i < 6; i++) {
//				cout << initial_set.tmv.tms[i].remainder << endl;
//			}
		}
		else
		{
			printf("Terminated due to too large overestimation.\n");
			break;
		}
	}

	end = clock();
	printf("time cost: %lf\n", (double)(end - begin) / CLOCKS_PER_SEC);
	printf("Result: ");
	if (result.status == COMPLETED_SAFE) {
		printf("Safe.\n");
	} else if (result.status == COMPLETED_UNSAFE) {
		printf("Unsafe.\n");
		initial_set.tmvPre.tms[x0_id].intEval(box, initial_set.domain);
		cout << scientific << box.inf() << " " << scientific << box.sup() << endl;
		initial_set.tmvPre.tms[x1_id].intEval(box, initial_set.domain);
		cout << scientific << box.inf() << " " << scientific << box.sup() << endl;	
		initial_set.tmvPre.tms[u0_id].intEval(box, initial_set.domain);
		cout << scientific << box.inf() << " " << scientific << box.sup() << endl;
		initial_set.tmvPre.tms[t_id].intEval(box, initial_set.domain);
		cout << scientific << box.inf() << " " << scientific << box.sup() << endl;	
	} else if (result.status == COMPLETED_UNKNOWN) {
		printf("Unknown.\n");
	} else {
		printf("Error.\n");
	}

	// plot the flowpipes in the x-y plane
	// result.transformToTaylorModels(setting);

	// Plot_Setting plot_setting(vars);
	// plot_setting.setOutputDims("t", "x1");

	// int mkres = mkdir("./outputs", S_IRWXU | S_IRGRP | S_IXGRP | S_IROTH | S_IXOTH);
	// if (mkres < 0 && errno != EEXIST)
	// {
	// 	printf("Can not create the directory for images.\n");
	// 	exit(1);
	// }

	// // you need to create a subdir named outputs
	// // the file name is example.m and it is put in the subdir outputs
	// plot_setting.plot_2D_octagon_GNUPLOT("./outputs/", "acc_"  + to_string(steps) + "_"  + to_string(if_symbo), result.tmv_flowpipes, setting);

 

	return 0;
}
