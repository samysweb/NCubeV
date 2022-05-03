module NNEnum
	using PyCall

	using ....AST

	run_nnenum = nothing

	function __init__()
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
os.environ["OMP_NUM_THREADS"] = "1"
os.environ["OPENBLAS_NUM_THREADS"] = "1"

from pathlib import Path

from nnenum.enumerate import enumerate_network
from nnenum.lp_star import LpStar
from nnenum.onnx_network import load_onnx_network
from nnenum.settings import Settings
from nnenum.specification import MixedSpecification, DisjunctiveSpec

def run_nnenum(model, lb, ub, A_input, b_input, disjunction):
	Settings.UNDERFLOW_BEHAVIOR = "warn"
	# TODO(steuber): Seem to have numerical issue here?
	Settings.SKIP_CONSTRAINT_NORMALIZATION = True
	Settings.PRINT_PROGRESS = False
	Settings.PRINT_OUTPUT = True
	Settings.RESULT_SAVE_COUNTER_STARS = True
	#Settings.INPUT_SPACE_MINIMIZATION = False
	Settings.FIND_CONCRETE_COUNTEREXAMPLES = True
	Settings.BRANCH_MODE = Settings.BRANCH_EXACT
	Settings.NUM_PROCESSES = 1
	
	network = load_onnx_network(model)
	ninputs = A_input.shape[1]

	#b_output+=1e-3
	#b_input+=1e-3

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

	spec_list = []
	for (A_mixed, b_mixed) in disjunction:
		spec_list.append(MixedSpecification(A_mixed, b_mixed, ninputs))
	print("Spec list length: ", len(spec_list))
	spec = DisjunctiveSpec(spec_list)

	print("Enumeration in progress... ",end="")
	result = enumerate_network(init_star, network, spec)
	print("Enumeration finished.")
	print(result.result_str)
	cex = None
	counterex_stars = []
	if result.cinput is not None:
		cex = (
			np.array(list(result.cinput))
			.astype(np.float32)
			.reshape(network.get_input_shape())
		)
		print(f"Found counter-example stars: {len(result.stars)}")
		for star in result.stars:
			# Extract Ax <= b
			A = star.lpi.get_constraints_csr()
			b = star.lpi.get_rhs()
			# Extract M*x + c
			M = star.a_mat
			c = star.bias
			# Compute bounds
			dims = star.lpi.get_num_cols()
			should_skip = np.zeros((dims, 2), dtype=bool)
			bounds = star.update_input_box_bounds_old(None, should_skip)
			counterex_stars.append((
				A, b,
				M, c,
				bounds,
				star.counter_example
			))
		return (result.result_str, (cex, counterex_stars))
	else:
		return None
"""
		global run_nnenum = py"run_nnenum"
	end

	function verify(model, olnnv_query :: OlnnvQuery)
		@info "Running nnenum now..."
		lb = [b[1] for b in olnnv_query.bounds]
		ub = [b[2] for b in olnnv_query.bounds]
		run_nnenum(model, lb, ub, olnnv_query.input_matrix, olnnv_query.input_bias, olnnv_query.disjunction)
	end

end