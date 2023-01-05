#import ..AST : And, Or, Not, Implies

function transform_formula(skeleton :: BooleanSkeleton)
	variable_number_dict = Dict{Union{Atom,LinearConstraint,ApproxNode}, Int64}()
	fun = get_skeleton_generator_function(skeleton, variable_number_dict)
	res = Postwalk(x -> if typeof(x) <: Formula fun(x) end)(skeleton.query.formula)
	add_clause(skeleton.sat_instance, [res.variable_number])
	# Encode approximation cases for each dimension
	num_cases = get_num_cases(skeleton.query.bounds)
	for (dim,bound_list) in enumerate(skeleton.query.bounds)
		v1 = 0
		v2 = 0
		all_cases = []
		for i in 1:(length(bound_list)-1)
			v1 = next_var(skeleton.sat_instance)
			v2_new = next_var(skeleton.sat_instance)
			push!(all_cases, v1)
			if v2 != 0
				add_clause(skeleton.sat_instance, [-v2, -v1])
				add_clause(skeleton.sat_instance, [-v2, v2_new])
			end
			v2 = v2_new
			add_clause(skeleton.sat_instance, [-v1, v2])
			skeleton.variable_mapping[v1] = ApproxCase(dim, i)
			skeleton.variable_mapping[v2] = IntermediateVariable
		end
		if length(all_cases) > 0
			add_clause(skeleton.sat_instance, all_cases)
		end
	end
	print_msg(variable_number_dict)
end

function get_skeleton_generator_function(skeleton :: BooleanSkeleton, variable_number_dict :: Dict{Union{Atom,LinearConstraint,ApproxNode}, Int64})
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
				#@debug "Atom or LinearConstraint => constraint variable"
				return_variable = next_var(skeleton.sat_instance)
				if haskey(variable_number_dict, formula)
					return SkeletonFormula(variable_number_dict[formula])
				else
					internal = @match skeleton.variable_mapping[internal_formula.variable_number] begin
							ConstraintVariable(internal) => internal
							_ => nothing
						end
					new_formula = nothing
					new_formula_complementary = nothing
					variable_number_actual = next_var(skeleton.sat_instance)
					variable_number_complementary = next_var(skeleton.sat_instance)
					# Relation of under/over approx and real atom
					if formula isa OverApprox
						new_formula = OverApprox(internal)
						new_formula_complementary = UnderApprox(internal)
						# We want (-internal_formula.variable_number) AND (variable_number) <=> return_variable
						add_clause(skeleton.sat_instance, [-internal_formula.variable_number, -variable_number_actual, return_variable])
						add_clause(skeleton.sat_instance, [-return_variable, internal_formula.variable_number])
						add_clause(skeleton.sat_instance, [-return_variable, variable_number_actual])
						# If formula is true then so is the overapproximation:
						add_clause(skeleton.sat_instance, [-internal_formula.variable_number, variable_number_actual])
						# If underapproximation is true then so is the original formula:
						add_clause(skeleton.sat_instance, [-variable_number_complementary, internal_formula.variable_number])
					elseif formula isa UnderApprox
						new_formula = UnderApprox(internal)
						new_formula_complementary = OverApprox(internal)
						# We want (-internal_formula.variable_number) OR (variable_number) <=> return_variable
						add_clause(skeleton.sat_instance, [-internal_formula.variable_number, return_variable])
						add_clause(skeleton.sat_instance, [-variable_number_actual, return_variable])
						add_clause(skeleton.sat_instance, [-return_variable, internal_formula.variable_number, variable_number_actual])
						# If underapproximation is true then so is the original formula:
						add_clause(skeleton.sat_instance, [-variable_number_actual, internal_formula.variable_number])
						# If formula is true then so is the overapproximation:
						add_clause(skeleton.sat_instance, [-internal_formula.variable_number, variable_number_complementary])
					end
					skeleton.variable_mapping[variable_number_actual] = ConstraintVariable(new_formula)
					skeleton.variable_mapping[variable_number_complementary] = ConstraintVariable(new_formula_complementary)
					variable_number_dict[formula] = return_variable
					return SkeletonFormula(return_variable)
				end
			end
			# OverApprox(internal_formula) || UnderApprox(internal_formula) => begin
			# 	#@debug "OverApprox or UnderApprox => propagating from below"
			# 	# print("Encountered ")
			# 	# print_msg(formula)
			# 	# print_msg(internal)
			# 	if haskey(variable_number_dict, formula)
			# 		return SkeletonFormula(variable_number_dict[formula])
			# 	else
			# 		variable_number = next_var(skeleton.sat_instance)
			# 		skeleton.variable_mapping[variable_number] = formula
			# 		variable_number_dict[formula] = variable_number
			# 		return SkeletonFormula(variable_number)
			# 	end
			# 	# return @match skeleton.variable_mapping[internal_formula.variable_number] begin
			# 	# 	ConstraintVariable(internal) => begin
			# 	# 		# May have already happened at other location...
			# 	# 		if !(internal isa UnderApprox || internal isa OverApprox)
			# 	# 			new_formula = (typeof(formula))(internal)
			# 	# 			skeleton.variable_mapping[internal_formula.variable_number] = ConstraintVariable(new_formula)
			# 	# 		end
			# 	# 		return internal_formula
			# 	# 	end
			# 	# 	_ => throw("ApproxNode is supposed to contain a ConstraintVariable")
			# 	# end
			# end
			x => begin
				print(x)
				throw("Missing case!")
			end
		end
	end
end
