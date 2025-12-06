"""
Cmd
===

Command-line interface wiring NCubeV’s pipeline end-to-end. Parses arguments,
configures approximation density and SMT/verifier backends, loads files, and
invokes `Control.run_query` and the selected verifier.
"""
module Cmd
	using ArgParse
	using JLD
	using TimerOutputs

	using ..Approx
	using ..Util
	using ..Config
	using ..AST
	using ..SMTInterface
	using ..Control
	using ..Verifiers
	using ..VerifierInterface

	import ..AST.Input
	import ..AST.Output

	export run_cmd

	"""
		parse_commandline(cmd_args)

	Parse arguments for the NCubeV CLI, including files (formula/fixed variables/variable mapping/network/output files location), verifier and SMT backend,
	and flags like `--linear`, `--rigorous`, `--approx`, core usage, and normalization.
	"""
	function parse_commandline(cmd_args)
		s = ArgParseSettings()
		@add_arg_table s begin
			"formula"
				help = "File containing the formula to verify"
				required = true
			"fixed"
				help = "File containing the fixed variables"
				required = true
			"mapping"
				help = "File containing the mapping from variables to their types and indices"
				required = true
			"network"
				help = "File containing the network to use"
				required = true
			"output"
				help = "File to write the results to"
				required = true
			"--verifier"
				help = "Verifier to use (currently only supports NNEnum)"
				arg_type = String
				default = "NNEnum"
			"--smt"
				help = "SMT solver to use (currently only supports Z3 and CVC5)"
				arg_type = String
				default = "Z3"
			"--smtfilter-timeout"
				help = "Timeout for SMT filter in seconds (unsolved SMT queries will be considered as possibly sat)"
				arg_type = Int
				default = 10
			"--linear"
				help = "Calls OLNNV tool without any non-linear constraint approximations"
				action = :store_true
			"--rigorous"
				help = "Prove that approximation is correct using SMT Solver"
				action = :store_true
			"--approx"
				help = "Number of approximation points to use"
				arg_type = Int
				default = 1
			"--no-cores"
				help = "Do not use cores for SMT queries (this allows another SMT solver which may be faster for higher-order polynomials)"
				action = :store_true
			"--no-normalization"
				help = "Do not normalize atoms (this may throw errors when formulas contain large numbers)"
				action = :store_true
		end
		return parse_args(cmd_args,s)
	end
	
	"""
		run_internal(args)

	Execute a verification run using the parsed arguments. Prepares the query,
	sets SMT and approximation configs, and uses `Control.run_query` plus a
	selected verifier from `Verifiers.VERIFIER_CALLBACKS`.
	"""
	function run_internal(args)
		if args["linear"]
			println("[CMD] Running without any non-linear constraint approximations")
			Config.set_include_approximations(false)
		end
		if args["rigorous"]
			print_msg("[CMD] Running in rigorous mode")
			Config.set_rigorous_approximations(true)
		end
		if args["no-cores"]
			print_msg("[CMD] Not using cores for SMT queries")
			SMTInterface.USE_CORES = false
		else
			SMTInterface.USE_CORES = true
		end
		if args["no-normalization"]
			print_msg("[CMD] Not normalizing atoms")
			Config.NORMALIZE_ATOMS = false
		else
			Config.NORMALIZE_ATOMS = true
		end
		set_approx_density(args["approx"])
		print_msg("[CMD] Using SMT solver: ", args["smt"])
		print_msg("[CMD] Using verifier: ", args["verifier"])
		Config.set_smt_solver(args["smt"])
		# Load fixed variables
		fixed_vars_content = open(args["fixed"], "r") do f
			return read(f, String)
		end
		fixed_parsed = Meta.parse(fixed_vars_content)
		fixed_vars = Dict{String,Union{String,Number}}(eval(fixed_parsed))
		# Load mapping
		mapping_content = open(args["mapping"], "r") do f
			return read(f, String)
		end
		mapping_parsed = Meta.parse(mapping_content)
		mapping = Dict{String,Tuple{VariableType,Int64}}(eval(mapping_parsed))
		# Load formula
		initial_query=load_query(args["formula"],fixed_vars,mapping)
		print_msg("[CMD] Parsed initial query: ",initial_query)
		prepared_query=prepare_for_olnnv(initial_query)
		smt_timeout = convert(Int32,args["smtfilter-timeout"])
		print_msg("[CMD] SMT Timeout: ", smt_timeout, "s")
		result = (SMTInterface.smt_context(prepared_query.num_input_vars+prepared_query.num_output_vars;timeout=smt_timeout*1000) do (ctx, variables)
			return Control.run_query(prepared_query, ctx, smt_timeout, variables, backup=args["output"],backup_meta=args) do (linear_term,SMTFilter)
				#print_msg("Generated terms")
				@timeit Config.TIMER "nnv" begin
					return Verifiers.VERIFIER_CALLBACKS[args["verifier"]](
							args["network"],
							SMTFilter,
							linear_term)
				end
			end
		end)# |> VerifierInterface.reduce_results
		return result
	end

	"""
		run_cmd(cmd_args)

	Entry point used by the CLI script. Parses args, runs a verification, saves
	results (JLD), prints timing info, and returns a process exit code
	(non-zero if any unsafe stars were found).
	"""
	function run_cmd(cmd_args)
		Config.reset_timer()
		args = parse_commandline(cmd_args)
		
		@time result, cex_count = run_internal(args)
		

		print_msg("----------------------------------------------------------")
		#print_msg("Status: "*string(result.status))
		print_msg("# Unsafe Stars: "*string(cex_count))
		print_msg("Saving final results in "*string(args["output"])*"...")
		if cex_count > 0
			print_msg("Found "*string(cex_count)*" counterexample regions")
		else
			print_msg("No counterexamples found -> SAFE")
		end
		save(args["output"]*"-final.jld","result",result,"args",args)
		show(Config.TIMER)
		print_msg(" Done")
		return (cex_count > 0) ? 1 : 0
	end
end
