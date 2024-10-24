module NNEnum
	using PyCall

	using ....Util
	using ....AST
	using ....VerifierInterface

	using ..Registry

	run_nnenum = nothing

	function __init__()
		# Register Verifiers
		register_verifier("NNEnum",verify_enumerative_filtered)
		register_verifier("NNEnumSimple",verify_iterative_filtered)

		# Python Setup
		nnenum_path = joinpath(@__DIR__, "../../deps/nnenum/src")
		py"""
		import sys
		def append_python_path(path):
			sys.path.append(path)
		"""
		append_python_path = py"append_python_path"
		append_python_path(string(nnenum_path))
py"""
import argparse
import numpy as np
import pickle
import os
import sys
os.environ["OMP_NUM_THREADS"] = "1"
os.environ["OPENBLAS_NUM_THREADS"] = "1"

from pathlib import Path

from nnenum.enumerate import enumerate_network
from nnenum.lp_star import LpStar
from nnenum.onnx_network import load_onnx_network
from nnenum.settings import Settings
from nnenum.specification import MixedSpecification, DisjunctiveSpec

def prepare_star(star):
	# Extract Ax <= b
	A = star.lpi.get_constraints_csr().todense()
	b = star.lpi.get_rhs()
	# Extract M*x + c
	M = star.a_mat
	c = star.bias
	# Compute bounds
	dims = star.lpi.get_num_cols()
	should_skip = np.zeros((dims, 2), dtype=bool)
	bounds = None
	try:
		bounds = star.update_input_box_bounds_old(None, should_skip)
	except:
		bounds_lp = star.lpi._get_col_bounds()
		bounds = []
		for (i,cur_bound) in enumerate(bounds_lp):
			bounds.append([i,cur_bound[0],cur_bound[1]])
		print("[NNENUM] Substitute bounds due to unsat lp:", bounds)
	result = (
		A, b,
		M, c,
		bounds,
		star.counter_example
	)
	return result

def run_nnenum(model, lb, ub, A_input, b_input, disjunction, iterative):
	Settings.UNDERFLOW_BEHAVIOR = "warn"
	# TODO(steuber): Seem to have numerical issue here?
	Settings.SKIP_CONSTRAINT_NORMALIZATION = False
	Settings.PRINT_PROGRESS = True
	Settings.PRINT_OUTPUT = False
	Settings.RESULT_SAVE_COUNTER_STARS = True
	#Settings.INPUT_SPACE_MINIMIZATION = False
	Settings.FIND_CONCRETE_COUNTEREXAMPLES = True
	Settings.BRANCH_MODE = Settings.BRANCH_OVERAPPROX
	Settings.NUM_PROCESSES = 1
	Settings.ITERATE_COUNTEREXAMPLES = iterative
	Settings.GLPK_TIMEOUT=15
	
	network = load_onnx_network(model)
	ninputs = A_input.shape[1]

	#b_output+=1e-3
	#b_input+=1e-3

	print("[NNENUM] Creating LP Star...")
	init_box = np.array(
		list(zip(lb.flatten(), ub.flatten())),
		dtype=np.float32,
	)
	init_star = LpStar(
		np.eye(ninputs, dtype=np.float32), np.zeros(ninputs, dtype=np.float32), init_box
	)
	for a, b in zip(A_input, b_input):
		a_ = a.reshape(network.get_input_shape()).flatten("F")
		init_star.lpi.add_dense_row(a_, b)
	
	print("[NNENUM] Checking feasibility")
	if not init_star.lpi.is_feasible():
		print("[NNENUM] Region is safe as initial LP is unsatisfiable; stopping run")
		sys.stdout.flush()
		yield ("safe", 0, (None, []))
		return

	print("[NNENUM] Generating output Spec...")
	spec_list = []
	for (A_mixed, b_mixed) in disjunction:
		spec_list.append(MixedSpecification(A_mixed, b_mixed, ninputs))
	print("[NNENUM] Spec list length: ", len(spec_list))
	spec = DisjunctiveSpec(spec_list)

	if iterative:
		print("[NNENUM] Iterative mode")
		for star in enumerate_network(init_star, network, spec):
			yield prepare_star(star)
	else:
		print("[NNENUM] Enumeration in progress... ")
		result = next(enumerate_network(init_star, network, spec))
		print("\n[NNENUM] Result: ")
		print(result)
		print("[NNENUM] Enumeration finished.")
		print(result.result_str)
		cex = None
		counterex_stars = []
		if result.cinput is not None:
			cex = (
				np.array(list(result.cinput))
				.astype(np.float32)
				.reshape(network.get_input_shape())
			)
			print(f"[NNENUM] Found counter-example stars: {len(result.stars)}")
			for star in result.stars:
				counterex_stars.append(prepare_star(star))
			sys.stdout.flush()
			yield (result.result_str, result.total_stars, (cex, counterex_stars))
		else:
			sys.stdout.flush()
			yield (result.result_str, result.total_stars, (None, []))
"""
		global run_nnenum = py"run_nnenum"
	end

	function to_status(status :: String)
		if status == "safe"
			return Safe
		elseif startswith(status,"unsafe")
			return Unsafe
		else
			return Unknown
		end
	end

	function verify_enumerative(model, olnnv_query :: OlnnvQuery)
		print_msg("[NNENUM] Running nnenum now...")
		lb = [b[1] for b in olnnv_query.bounds]
		ub = [b[2] for b in olnnv_query.bounds]
		print_msg("[NNENUM] lb: ", lb)
		print_msg("[NNENUM] ub: ", ub)
		res, _ = iterate(run_nnenum(model, lb, ub, olnnv_query.input_matrix, olnnv_query.input_bias, olnnv_query.disjunction, false))
		if isnothing(res)
			return OlnnvResult()
		else
			return OlnnvResult(to_status(res[1]),res[2],map(Star,res[3][2]))
		end
	end

	function verify_enumerative_filtered(model, SMTFilter, olnnv_query :: OlnnvQuery)
		res = verify_enumerative(model, olnnv_query)
		print_msg("[NNENUM] Filtering result using SMT solver...")
		return SMTFilter(res)
	end

	function verify_iterative_filtered(model, SMTFilter, olnnv_query :: OlnnvQuery)
		print_msg("[NNENUM] Running iterative nnenum...")
		lb = [b[1] for b in olnnv_query.bounds]
		ub = [b[2] for b in olnnv_query.bounds]
		print_msg("[NNENUM] lb: ", lb)
		print_msg("[NNENUM] ub: ", ub)
		uncertain_stars = Star[]
		for star in run_nnenum(model, lb, ub, olnnv_query.input_matrix, olnnv_query.input_bias, olnnv_query.disjunction, true)
			res = SMTFilter(OlnnvResult(Unsafe, nothing, [Star(star)]))
			if res.status != Safe
				filtered_star = res.stars[1]
				if filtered_star.certain
					print_msg("[SMT] Query returned UNSAFE: Found SMT checked counter-example.")
					A = olnnv_query.input_matrix
					b = olnnv_query.input_bias
					M = Matrix{Float32}(undef,0,0)
					c = Vector{Float32}(undef,0)
					num_inputs = size(A)[2]
					bounds = Matrix{Real}(undef,num_inputs,3)
					for (i,b) in enumerate(olnnv_query.bounds[1:(num_inputs)])
						bounds[i,1] = i-1
						bounds[i,2] = b[1]
						bounds[i,3] = b[2]
					end
					counter_example = (Vector{Float32}(undef,0),Vector{Float32}(undef,0))
					counter_star = Star((A,b,M,c,bounds,counter_example))
					return OlnnvResult(res.status, res.metadata, Star[uncertain_stars;Star(counter_star, true)])
				else
					push!(uncertain_stars,filtered_star)
				end
			end
		end
		if isempty(uncertain_stars)
			return OlnnvResult(Safe, nothing, [])
		else
			return OlnnvResult(Unknown, nothing, uncertain_stars)
		end
	end

end