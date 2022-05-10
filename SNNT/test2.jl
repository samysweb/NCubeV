#using Revise
using SNNT
fixed_vars=Dict{String,Union{String,Number}}("T"=>0.1,"cpost"=>0.0,"A"=>100,"B"=>100,"rVelpost"=>"rVel","rPospost"=>"rPos")
mapping=Dict{String,Tuple{SNNT.AST.VariableType,Int64}}("rPos"=>(SNNT.AST.Input,1),"rVel"=>(SNNT.AST.Input,2),"rAccpost"=>(SNNT.AST.Output,1))
test=load_query("test/parsing/examples/example3",fixed_vars,mapping)
test2=prepare_for_olnnv(test)

results = []
SNNT.Z3Interface.z3_context(test2.num_input_vars+test2.num_output_vars;timeout=0) do (ctx, variables)
	Z3Filter = SNNT.Z3Interface.get_star_filter(ctx, variables, test2.formula)
	@time run_query(test2) do linear_term
		#println("Generated terms")
		res = ( SNNT.Verifiers.NNEnum.verify(
					"../../jsc/ppo_acc_bigger_200000_steps.onnx",
					linear_term) |>
				Z3Filter )
		push!(results, res)
	end
end
