module Cmd
	using ArgParse
	using JLD

	using ..Config
	using ..AST
	using ..SMTInterface
	using ..Control
	using ..Verifiers
	using ..VerifierInterface

	import ..AST.Input
	import ..AST.Output

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
			"--linear"
				help = "Calls OLNNV tool without any non-linear constraint approximations"
				action = :store_true
			"--rigorous"
				help = "Prove that approximation is correct using SMT Solver"
				action = :store_true
		end
		return parse_args(cmd_args,s)
	end
	
	function run_internal(args)
		if args["linear"]
			@info "Running without any non-linear constraint approximations"
			Config.set_include_approximations(false)
		end
		if args["rigorous"]
			@info "Running in rigorous mode"
			Config.set_rigorous_approximations(true)
		end
		@info "Using SMT solver: ", args["smt"]
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
		@info "Parsed initial query: ",initial_query
		prepared_query=prepare_for_olnnv(initial_query)
		result = (SMTInterface.smt_context(prepared_query.num_input_vars+prepared_query.num_output_vars;timeout=100000) do (ctx, variables)
			Z3Filter = SMTInterface.get_star_filter(ctx, variables, prepared_query.formula)
			return @time Control.run_query(prepared_query) do linear_term
				#println("Generated terms")
				( Verifiers.VERIFIER_CALLBACKS[args["verifier"]](
						args["network"],
						linear_term) |>
					Z3Filter )
			end
		end) |> VerifierInterface.reduce_results
		return result
	end

	function run_cmd(cmd_args)
		args = parse_commandline(cmd_args)
		
		@time result = run_internal(args)

		println("----------------------------------------------------------")
		println("Status: "*string(result.status))
		print("Saving result in "*string(args["output"])*"...")
		save(args["output"],"result",result)
		println(" Done")
	end
end