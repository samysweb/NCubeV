module ACC

using ClosedLoopReachability, LaTeXStrings, MAT
using ClosedLoopReachability: FunctionPreprocessing
import DifferentialEquations
#import Plots, DifferentialEquations
#using Plots: plot, plot!, lens!, bbox, savefig, font, Measures.mm, annotations
using Polyhedra
using CDDLib

# problem

# @taylorize function ACC!(dx, x, p, t)
#     dx[1] = x[2]
#     dx[2] = x[3]
#     return dx
# end

controller = read_nnet(@modelpath "" "acc-2000000-64-64-64-64-retrain-100000-200000-0.9.nnet")
#controller = read_nnet_mat(@modelpath("", "acc-2000000-64-64-64-64-retrain-100000-200000-0.9.mat");
#                           act_key="act_fcns");

X₀ = Hyperrectangle(low= [ 0.1, -4],
                    high=[0.2, -3.9])
U₀ = ZeroSet(1)
vars_idx = Dict(:states=>1:2, :controls=>3)
sys = @system(x' = [0 1 0; 0 0 1; 0 0 0] * x);
ivp = @ivp(sys, x(0) ∈ X₀ × U₀)
#@ivp(x' = ACC!(x), dim: 3, x(0) ∈ X₀ × U₀)

period = 0.1
k = 1
T = k * period
T_warmup = 2 * period

prob = ControlledPlant(ivp, controller, vars_idx, period)
warmup_prob = deepcopy(prob)
# simulation

#println("simulation")
#res = @timed simulate(prob, T=T, trajectories=10, include_vertices=true)
#sim = res.value
#print_timed(res)

## Safety specification
T = 5.0  # time horizon

d_rel = [1.0, 0, 0]
safe_states = ClosedLoopReachability.HalfSpace(-d_rel, 0.0)
predicate = X -> X ⊆ safe_states;

# reachability analysis

alg = TMJets(abstol=1e-6, orderT=6, orderQ=1)
alg_nn = SampledApprox()
#VertexSolver()
#BoxSolver()
#ClosedLoopReachability.ConcreteReLU(true,false)
#DeepZ()

function benchmark(prob; T=T, silent::Bool=false)
    silent || println("flowpipe construction")
    res = @timed solve(prob, T=T, alg_nn=alg_nn, alg=alg)
    sol = res.value
    silent || print_timed(res)
    res_pred = @timed predicate(sol)
    if res_pred.value
        silent || println("The property is satisfied.")
    else
        silent || println("The property may be violated.")
    end

    ## Next we check the property for an overapproximated flowpipe:
    silent || println("property checking")
    solz = overapproximate(sol, Zonotope)
    res_pred = @timed predicate(solz)
    silent || print_timed(res_pred)
    if res_pred.value
        silent || println("The property is satisfied.")
    else
        silent || println("The property may be violated.")
    end
    return sol, solz
end

benchmark(warmup_prob;T=T_warmup, silent=true)
res = @timed benchmark(prob)
sol = res.value

end
nothing
