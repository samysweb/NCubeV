	using ArgParse
	using JLD
	using TimerOutputs

	using SNNT.Approx
	using SNNT.Util
	using SNNT.Config
	using SNNT.AST
	using SNNT.SMTInterface
	using SNNT.Control
	using SNNT.Verifiers
	using SNNT.VerifierInterface

	import SNNT.AST.Input
	import SNNT.AST.Output

	export run_cmd

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
		end
		return parse_args(cmd_args,s)
	end
	
	function run_internal(args)
		if args["linear"]
			println("[CMD] Running without any non-linear constraint approximations")
			Config.set_include_approximations(false)
		end
		if args["rigorous"]
			print_msg("[CMD] Running in rigorous mode")
			Config.set_rigorous_approximations(true)
		end
		set_approx_density(args["approx"])
		print_msg("[CMD] Using SMT solver: ", args["smt"])
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
        num_queries_feasibility_check = 0
        num_queries_feasibility_check_no_disjunction = 0
		SNNT.Config.QUERY_GEN_DO_INFEASIBILITY_CHECK = false
		SNNT.Config.QUERY_GEN_SAVE_SAT = "./sat.dimacs"
        result = (SMTInterface.smt_context(prepared_query.num_input_vars+prepared_query.num_output_vars;timeout=smt_timeout*1000) do (ctx, variables)
			Control.run_query(prepared_query, ctx, smt_timeout, variables, backup=args["output"],backup_meta=args) do (linear_term,SMTFilter)
                num_queries_feasibility_check += 1
                num_queries_feasibility_check_no_disjunction += length(linear_term.disjunction)
                return SNNT.VerifierInterface.OlnnvResult()
			end
		end)
        print_msg("[CMD] Number of queries with feasibility check: ", num_queries_feasibility_check)
        print_msg("[CMD] Number of queries with feasibility check w/o disjunctions: ", num_queries_feasibility_check_no_disjunction)
		return result
	end

	function run_cmd(cmd_args)
		Config.reset_timer()
		args = parse_commandline(cmd_args)
		
		run_internal(args)

		print_msg("----------------------------------------------------------")
		show(Config.TIMER)
		print_msg(" Done")
	end