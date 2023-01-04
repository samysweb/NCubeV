#import ..AST : And, Or, Not, Implies

function transform_formula(skeleton :: BooleanSkeleton)
	variable_number_dict = Dict{Union{Atom,LinearConstraint}, Int64}()
	fun = get_skeleton_generator_function(skeleton, variable_number_dict)
	res = Postwalk(x -> if typeof(x) <: Formula fun(x) end)(skeleton.query.formula)
	add_clause(skeleton.sat_instance, [res.variable_number])
	# Encode approximation cases
	num_cases = get_num_cases(skeleton.query.bounds)
	v1 = 0
	v2 = 0
	all_cases = []
	for i in 1:num_cases
		v1 = next_var(skeleton.sat_instance)
		v2_new = next_var(skeleton.sat_instance)
		push!(all_cases, v1)
		if v2 != 0
			add_clause(skeleton.sat_instance, [-v2, -v1])
			add_clause(skeleton.sat_instance, [-v2, v2_new])
		end
		v2 = v2_new
		add_clause(skeleton.sat_instance, [-v1, v2])
		skeleton.variable_mapping[v1] = ApproxCase(i)
		skeleton.variable_mapping[v2] = IntermediateVariable
	end
	if length(all_cases) > 0
		add_clause(skeleton.sat_instance, all_cases)
	end
end

function get_skeleton_generator_function(skeleton :: BooleanSkeleton, variable_number_dict :: Dict{Union{Atom,LinearConstraint}, Int64})
	return function(formula :: Formula)
		return @match formula begin
			Atom() || LinearConstraint() => begin
				#@debug "Atom or LinearConstraint => constraint variable"
				if haskey(variable_number_dict, formula)
					return SkeletonFormula(variable_number_dict[formula])
				else
					variable_number = next_var(skeleton.sat_instance)
					skeleton.variable_mapping[variable_number] = ConstraintVariable(formula)
					variable_number_dict[formula] = variable_number
					return SkeletonFormula(variable_number)
				end
			end
			CompositeFormula(c, args,_) => begin
				#@debug "CompositeFormula => intermediate variable"
				variable_number = next_var(skeleton.sat_instance)
				skeleton.variable_mapping[variable_number] = IntermediateVariable
				@match c begin
					Or => begin
						#@debug "OR"
						# variable_number => [args]
						add_clause(skeleton.sat_instance,append!([-variable_number], map(x->x.variable_number, args)))
						# args[i] => variable_number
						for arg in args
							add_clause(skeleton.sat_instance, [variable_number, -arg.variable_number])
						end
					end
					Not => begin
						#@debug "NOT"
						@assert length(args) == 1
						# variable_number => -args[1]
						add_clause(skeleton.sat_instance, [-variable_number, -args[1].variable_number])
						# -args[1] => variable_number
						add_clause(skeleton.sat_instance, [variable_number, args[1].variable_number])
					end
					And => begin
						#@debug "AND"
						# variable_number => args[i]
						for arg in args
							add_clause(skeleton.sat_instance, [-variable_number, arg.variable_number])
						end
						# args => variable_number
						add_clause(skeleton.sat_instance, append!(map(x->-x.variable_number, args), [variable_number]))
					end
					Implies => begin
						#@debug "IMPLIES"
						@assert length(args) == 2
						# variable_number => -args[1] | args[2]
						add_clause(skeleton.sat_instance, [-variable_number, -args[1].variable_number, args[2].variable_number])
						# -args[1] => variable_number
						add_clause(skeleton.sat_instance, [variable_number, args[1].variable_number])
						# args[2] => variable_number
						add_clause(skeleton.sat_instance, [variable_number, -args[2].variable_number])
					end
				end
				return SkeletonFormula(variable_number)
			end
			OverApprox(internal_formula) || UnderApprox(internal_formula) => begin
				#@debug "OverApprox or UnderApprox => propagating from below"
				# print("Encountered ")
				# print_msg(formula)
				# print_msg(internal)
				return @match skeleton.variable_mapping[internal_formula.variable_number] begin
					ConstraintVariable(internal) => begin
						# May have already happened at other location...
						if !(internal isa UnderApprox || internal isa OverApprox)
							new_formula = (typeof(formula))(internal)
							skeleton.variable_mapping[internal_formula.variable_number] = ConstraintVariable(new_formula)
						end
						return internal_formula
					end
					_ => throw("ApproxNode is supposed to contain a ConstraintVariable")
				end
			end
			x => begin
				print(x)
				throw("Missing case!")
			end
		end
	end
end
