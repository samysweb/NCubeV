#import ..AST : And, Or, Not, Implies

function transform_formula(skeleton :: BooleanSkeleton)
	variable_number_dict = Dict{Union{Atom,Predicate,LinearConstraint,ApproxNode}, Int64}()
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
end

function get_skeleton_generator_function(skeleton :: BooleanSkeleton, variable_number_dict :: Dict{Union{Atom,Predicate,LinearConstraint,ApproxNode}, Int64})
	return function(formula :: Formula)
		return @match formula begin
			TrueAtom() => begin
				variable_number = next_var(skeleton.sat_instance)
				add_clause(skeleton.sat_instance, [variable_number])
				return SkeletonFormula(variable_number)
			end
			FalseAtom() => begin
				variable_number = next_var(skeleton.sat_instance)
				add_clause(skeleton.sat_instance, [-variable_number])
				return SkeletonFormula(variable_number)
			end
			Atom() => begin
				#@debug "Atom or LinearConstraint => constraint variable"
				if haskey(variable_number_dict, formula)
					return SkeletonFormula(variable_number_dict[formula])
				else
					variable_number = next_var(skeleton.sat_instance)
					skeleton.variable_mapping[variable_number] = ConstraintVariable(formula)
					variable_number_dict[formula] = variable_number
					search_term = simplify(formula.left)
					#print_msg("[SKELETON] Searching $(search_term)")
					if is_literal_number(formula.right)
						@assert formula.comparator == AST.Less || formula.comparator == AST.LessEq
						if !haskey(skeleton.similar_formula_cache, search_term)
							skeleton.similar_formula_cache[search_term] = Tuple{Bool,TermNumber,Int}[(formula.comparator == AST.Less, formula.right, variable_number)]
						else
							for (strict, constant, other_var) in skeleton.similar_formula_cache[search_term]
								print_msg("[SKELETON] Adding atom dependency constraint:")
								if (strict && formula.right.value < constant.value) || (!strict && formula.right.value <= constant.value)
									print_msg(formula," -> ",search_term,ifelse(strict,"<","<="),constant)
									add_clause(skeleton.sat_instance, [-variable_number, other_var])
								else
									print_msg(search_term,ifelse(strict,"<","<="),constant," -> ",formula)
									add_clause(skeleton.sat_instance, [-other_var, variable_number])
								end
							end
							search_term2 = simplify(-1.0*formula.left)
							if haskey(skeleton.similar_formula_cache,search_term2)
								for (strict, constant, other_var) in skeleton.similar_formula_cache[search_term2]
									if (!strict && -constant.value > formula.right.value) || (strict && constant.value >= formula.right.value)
										print_msg("[SKELETON] Adding negated atom dependency constraint:")
										print_msg("!",formula," | !",search_term2,ifelse(strict,"<","<="),constant_value)
										add_clause(skeleton.sat_instance, [-variable_number, -other_var])
									end
								end
							end
							push!(
								skeleton.similar_formula_cache[search_term],
								(formula.comparator == AST.Less, formula.right, variable_number)
							)
						end
					end
					return SkeletonFormula(variable_number)
				end
			end
			LinearConstraint() => begin
				#@debug "Atom or LinearConstraint => constraint variable"
				if haskey(variable_number_dict, formula)
					return SkeletonFormula(variable_number_dict[formula])
				else
					factor=1/norm(formula.coefficients)
					variable_number = next_var(skeleton.sat_instance)
					skeleton.variable_mapping[variable_number] = ConstraintVariable(formula)
					variable_number_dict[formula] = variable_number
					search_term = LinearTerm(factor.*formula.coefficients,0//1)
					#print_msg("[SKELETON] Searching $(search_term)")
					if !haskey(skeleton.similar_formula_cache, search_term)
						#print_msg("[SKELETON] NO KEY")
						skeleton.similar_formula_cache[search_term] = Tuple{Bool,TermNumber,Int}[(!formula.equality, TermNumber(factor*formula.bias), variable_number)]
					else
						for (strict, constant, other_var) in skeleton.similar_formula_cache[search_term]
							print_msg("[SKELETON] Adding linear dependency constraint")
							if (strict && factor*formula.bias < constant.value) || (!strict && factor*formula.bias <= constant.value)
								print_msg(formula," -> ",search_term,ifelse(strict,"<","<="),constant)
								print_msg(formula.bias*factor)
								add_clause(skeleton.sat_instance, [-variable_number, other_var])
							else
								print_msg(search_term,ifelse(strict,"<","<="),constant," -> ",formula)
								print_msg(formula.bias*factor)
								add_clause(skeleton.sat_instance, [-other_var, variable_number])
							end
						end
						search_term2 = LinearTerm(-factor.*formula.coefficients,0//1)
						if haskey(skeleton.similar_formula_cache,search_term2)
							for (strict, constant, other_var) in skeleton.similar_formula_cache[search_term2]
								if (!strict && -constant.value > factor*formula.bias) || (strict && constant.value >= factor*formula.bias)
									print_msg("[SKELETON] Adding negated linear dependency constraint")
									print_msg("!",formula," | !",search_term2,ifelse(strict,"<","<="),constant)
									add_clause(skeleton.sat_instance, [-variable_number, -other_var])
								end
							end
						end
						push!(
							skeleton.similar_formula_cache[search_term],
							(!formula.equality, TermNumber(factor*formula.bias), variable_number)
						)
					end
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
			OverApprox(internal_formula, under_approx, over_approx) || UnderApprox(internal_formula, under_approx, over_approx) => begin
				#@debug "Atom or LinearConstraint => constraint variable"
				@assert !isnothing(under_approx) && !isnothing(over_approx) ("Under/over approx must be defined for " * term_to_string(formula) * " ("* string(skeleton.variable_mapping[internal_formula.variable_number]) *")")
				#return_variable = next_var(skeleton.sat_instance)
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
						new_formula = OverApprox(internal, under_approx, over_approx)
						new_formula_complementary = UnderApprox(internal, under_approx, over_approx)
						# We want (-internal_formula.variable_number) AND (variable_number) <=> return_variable
						#add_clause(skeleton.sat_instance, [-internal_formula.variable_number, -variable_number_actual, return_variable])
						#add_clause(skeleton.sat_instance, [-return_variable, internal_formula.variable_number])
						#add_clause(skeleton.sat_instance, [-return_variable, variable_number_actual])
						# If formula is true then so is the overapproximation:
						add_clause(skeleton.sat_instance, [-internal_formula.variable_number, variable_number_actual])
						# If underapproximation is true then so is the original formula:
						add_clause(skeleton.sat_instance, [-variable_number_complementary, internal_formula.variable_number])
					elseif formula isa UnderApprox
						new_formula = UnderApprox(internal, under_approx, over_approx)
						new_formula_complementary = OverApprox(internal, under_approx, over_approx)
						# We want (-internal_formula.variable_number) OR (variable_number) <=> return_variable
						#add_clause(skeleton.sat_instance, [-internal_formula.variable_number, return_variable])
						#add_clause(skeleton.sat_instance, [-variable_number_actual, return_variable])
						#add_clause(skeleton.sat_instance, [-return_variable, internal_formula.variable_number, variable_number_actual])
						# If underapproximation is true then so is the original formula:
						add_clause(skeleton.sat_instance, [-variable_number_actual, internal_formula.variable_number])
						# If formula is true then so is the overapproximation:
						add_clause(skeleton.sat_instance, [-internal_formula.variable_number, variable_number_complementary])
					end
					skeleton.variable_mapping[variable_number_actual] = ConstraintVariable(new_formula)
					skeleton.variable_mapping[variable_number_complementary] = ConstraintVariable(new_formula_complementary)
					variable_number_dict[formula] = internal_formula.variable_number
					return SkeletonFormula(internal_formula.variable_number)
				end
			end
			Predicate("isMax", parameters) => begin
				@assert length(parameters) >= 3
				cur_max = parameters[1]
				options = @view parameters[2:end]
				@warn "Beware: Use of isMax assumes that there always exists a *unique* maximum!"
				if !(cur_max in options)
					raise("isMax requires that first argument is also one of the remaining arguments!")
				end
				if !(allunique(options))
					raise("All options must be unique")
				end
				# Identical ordering of options
				option_order = sortperm(term_to_string.(options))
				options = options[option_order]
				normalized_predicate = Predicate("isMax", [cur_max; options[option_order]])
				if !haskey(variable_number_dict, normalized_predicate)
					option_variables = []
					# Exactly 1 encoding
					last_counter_var = nothing
					current_counter_var = nothing
					for i in 1:length(options)
						option_atoms = Formula[]
						for (j,cur_option) in enumerate(options)
							if i!=j
								cur_atom = simplify(Atom(AST.Greater, options[i], cur_option))
								if is_linear(cur_atom)
									var_number = skeleton.query.num_input_vars + skeleton.query.num_output_vars
									cur_atom = make_linear(cur_atom.left,cur_atom.right,cur_atom.comparator,var_number)
								end
								push!(option_atoms, cur_atom)
							end
						end
						last_counter_var = current_counter_var
						current_counter_var = next_var(skeleton.sat_instance)
						skeleton.variable_mapping[current_counter_var] = IntermediateVariable
						option_var = next_var(skeleton.sat_instance)
						skeleton.variable_mapping[option_var] = IsMaxCase(option_atoms)
						push!(option_variables, option_var)
						if !isnothing(last_counter_var)
							add_clause(skeleton.sat_instance, [-last_counter_var, -option_var])
							add_clause(skeleton.sat_instance, [-last_counter_var, current_counter_var])
						end
						add_clause(skeleton.sat_instance, [-option_var, current_counter_var])
						variable_number_dict[Predicate("isMax", [options[i]; options[option_order]])] = option_var
					end
					add_clause(skeleton.sat_instance, option_variables)
				end
				return SkeletonFormula(variable_number_dict[normalized_predicate])
			end
			SemiLinearConstraint() => formula
			x => begin
				print(x)
				throw("Missing case!")
			end
		end
	end
end
