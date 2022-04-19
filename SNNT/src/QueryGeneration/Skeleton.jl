#import ..AST : And, Or, Not, Implies

function transform_formula(skeleton :: BooleanSkeleton)
	variable_number_dict = Dict{Union{Atom,LinearConstraint}, Int64}()
	fun = get_skeleton_generator_function(skeleton, variable_number_dict)
	res = Postwalk(x -> if typeof(x) <: Formula fun(x) end)(skeleton.formula)
	add_clause(skeleton.sat_instance, [res.variable_number])
end

function get_skeleton_generator_function(skeleton :: BooleanSkeleton, variable_number_dict :: Dict{Union{Atom,LinearConstraint}, Int64})
	return function(formula :: Formula)
		return @match formula begin
			Atom() || LinearConstraint() => begin
				@debug "Atom or LinearConstraint => constraint variable"
				if haskey(variable_number_dict, formula)
					return SkeletonFormula(variable_number_dict[formula])
				else
					variable_number = next_var(skeleton.sat_instance)
					skeleton.variable_mapping[variable_number] = ConstraintVariable(formula)
					variable_number_dict[formula] = variable_number
					return SkeletonFormula(variable_number)
				end
			end
			CompositeFormula(c, args) => begin
				@debug "CompositeFormula => intermediate variable"
				variable_number = next_var(skeleton.sat_instance)
				skeleton.variable_mapping[variable_number] = IntermediateVariable
				@match c begin
					Or => begin
						@debug "OR"
						# variable_number => [args]
						add_clause(skeleton.sat_instance,append!([-variable_number], map(x->x.variable_number, args)))
						# args[i] => variable_number
						for arg in args
							add_clause(skeleton.sat_instance, [variable_number, -arg.variable_number])
						end
					end
					Not => begin
						@debug "NOT"
						@assert length(args) == 1
						# variable_number => -args[1]
						add_clause(skeleton.sat_instance, [-variable_number, -args[1].variable_number])
						# -args[1] => variable_number
						add_clause(skeleton.sat_instance, [variable_number, args[1].variable_number])
					end
					And => begin
						@debug "AND"
						# variable_number => args[i]
						for arg in args
							add_clause(skeleton.sat_instance, [-variable_number, arg.variable_number])
						end
						# args => variable_number
						add_clause(skeleton.sat_instance, append!(map(x->-x.variable_number, args), [variable_number]))
					end
					Implies => begin
						@debug "IMPLIES"
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
				@debug "OverApprox or UnderApprox => propagating from below"
				return @match skeleton.variable_mapping[internal_formula.variable_number] begin
					ConstraintVariable(internal) => begin
						# Set internal to what is contained in the under-approximation
						#formula.formula = internal
						new_formula = (typeof(formula))(internal)
						skeleton.variable_mapping[internal_formula.variable_number] = ConstraintVariable(new_formula)
						return internal_formula
					end
					_ => throw("ApproxNode is supposed to contain a ConstraintVariable")
				end
			end
		end
	end
end
