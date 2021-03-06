using Metatheory.Rewriters

function map_variables(x :: ParsedNode, mapping::Dict{String, Tuple{VariableType, Int64}})
	variable_set = Set{Variable}()
	input_var_count = 0
	output_var_count = 0
	for (k, v) in mapping
		if v[1] == AST.Input
			input_var_count += 1
		else
			output_var_count += 1
		end
	end
	f = map_variables_internal(variable_set, mapping, input_var_count)
	result = Postwalk(f)(x)
	return variable_set, result
end

function map_variables_internal(variable_set :: Set{Variable}, mapping::Dict{String, Tuple{VariableType, Int64}}, input_var_count :: Int64)
	return x -> begin
		return @match x begin
			Variable(name,_,_) => begin
				var_map = mapping[name]
				position = nothing
				if var_map == nothing
					throw("Unmapped variable "*name)
				elseif var_map[1] == AST.Input
					position = var_map[2]
				elseif var_map[1] == AST.Output
					position = var_map[2] + input_var_count
				end
				new_var = Variable(name, var_map, position)
				push!(variable_set,new_var)
				return new_var
			end

			_ => x
		end
	end
end

function fix_variables(f :: Formula, mapping::Dict{String, Union{String, Number}})
	replacement_map = Dict{Variable, Term}()
	for (k, v) in mapping
		if v isa String
			content_io = IOBuffer(v)
			parsed :: Term = Parsing.parse_constraint_from_io(content_io;parse_entry=Parsing.parse_term)
			replacement_map[Variable(k)] = parsed
		else
			replacement_map[Variable(k)] = TermNumber(v)
		end
	end
	return simplify(substitute(f, replacement_map, fold=false))
end

function translate_constraints(f :: Formula, variable_set :: Set{Variable})
	var_number = length(variable_set)
	return Postwalk(translate_constraints_internal(var_number))(f)
end

function make_linear(left :: T1, right :: T2, comp :: Comparator, var_number :: Int64) where {T1 <: Term, T2 <: Term}
	# @assert AST.is_linear(left) && right isa TermNumber
	constraint_row = zeros(Rational{BigInt}, var_number)
	bias = right.value
	semilinears = Dict{ApproxQuery, Rational{BigInt}}()
	@match left begin
		TermNumber(value) => begin end
		Variable(name, _, position) => begin
			constraint_row[position]+=1.0
		end
		NonLinearSubstitution(query) => begin
			if haskey(semilinears, query)
				semilinears[query] += 1.0
			else
				semilinears[query] = 1.0
			end
		end
		LinearTerm(c, b) => begin
			@assert length(c) == var_number
			constraint_row[:] .+= c
			bias -= b
		end
		CompositeTerm(op, args,_) => begin
			if op == AST.Mul
				@assert length(args) == 2
				if !(args[1] isa TermNumber)
					@assert args[2] isa TermNumber
					args = [args[2], args[1]]
				end
				if args[2] isa Variable
					constraint_row[args[2].position]+=args[1].value
				elseif args[2] isa NonLinearSubstitution
					if haskey(semilinears, args[2])
						semilinears[args[2].query] += args[1].value
					else
						semilinears[args[2].query] = args[1].value
					end
				elseif args[2] isa LinearTerm
					@assert length(args[2].coefficients) == var_number
					constraint_row .+=  args[1].value.*args[2].coefficients
					bias -=  args[1].value*args[2].bias
				else
					throw("Constraint "*string(left)*" "*string(comp)*" "*string(right)*" should have been simplified already")
				end
			elseif op == AST.Add
				for cur_arg in left.args
					if cur_arg isa Variable
						constraint_row[cur_arg.position] += 1
					elseif cur_arg isa TermNumber
						bias -= cur_arg.value
					elseif cur_arg isa NonLinearSubstitution
						if haskey(semilinears, cur_arg)
							semilinears[cur_arg.query] += 1.0
						else
							semilinears[cur_arg.query] = 1.0
						end
					elseif cur_arg isa LinearTerm
						@assert length(cur_arg.coefficients) == var_number
						constraint_row .+= cur_arg.coefficients
						bias -= cur_arg.bias
					elseif cur_arg.operation == AST.Mul
						@assert length(cur_arg.args) == 2
						if !(cur_arg.args[1] isa TermNumber)
							@assert cur_arg.args[2] isa TermNumber
							args = [cur_arg.args[2], cur_arg.args[1]]
						else 
							args = cur_arg.args
						end
						if args[2] isa Variable
							constraint_row[args[2].position]+=args[1].value
						elseif args[2] isa NonLinearSubstitution
							if haskey(semilinears, args[2])
								semilinears[args[2].query] += args[1].value
							else
								semilinears[args[2].query] = args[1].value
							end
						elseif args[2] isa LinearTerm
							@assert length(args[2].coefficients) == var_number
							constraint_row .+=  args[1].value.*args[2].coefficients
							bias -=  args[1].value*args[2].bias
						else
							throw("Constraint "*string(left)*" "*string(comp)*" "*string(right)*" should have been simplified already")
						end
					else
						throw("Unsupported term in make_linear: "*string(cur_arg))
					end
				end
			end
		end
		_ => throw("Unsupported term in make_linear: "*string(left))
	end
	# TODO(steuber): Possible optimization: Include side-constraint for Eq/Neq that one of the two formulas always has to be true/false
	if length(semilinears)>0
		#@debug "Generating semilinear constraint..."
		C = SemiLinearConstraint(semilinears)
	else
		C = LinearConstraint
	end
	if comp == AST.LessEq
		return C(constraint_row, bias, true)
	elseif comp == AST.Less
		return C(constraint_row, bias, false)
	elseif comp == AST.Eq
		@assert length(semilinears) == 0
		return AST.and_construction(Formula[
			C(constraint_row, bias, true),
			C(-constraint_row, -bias, true)
		])
	elseif comp == AST.Neq
		@assert length(semilinears) == 0
		return AST.or_construction(Formula[
			C(constraint_row, bias, false),
			C(-constraint_row, -bias, false)
		])
	else
		throw("Unsupported comparator in make_linear: "*string(comp))
	end
end

function translate_constraints_internal(var_number :: Int64)
	return x -> begin
		return @match x begin
			Atom(op, left, right) && GuardBy(AST.is_linear) => make_linear(left, right, op, var_number)
			Atom(op,left,right) => x # TODO(steuber): Non linear constraints
			_ => x
		end
	end
end

function get_overapprox(f :: ParsedNode)
	return @match f begin
		Atom() => OverApprox(f)
		CompositeFormula(c, args,_) => begin
			return @match c begin
				Not => CompositeFormula(c, [get_underapprox(args[1])])
				Implies => begin
					res = CompositeFormula(c, [get_underapprox(args[1]), get_overapprox(args[2])])
					return res
				end
				_ => begin
					return CompositeFormula(c, map(get_overapprox, args))
				end
			end
		end
		_ => f
	end
end

function get_underapprox(f :: ParsedNode)
	return @match f begin
		Atom() => UnderApprox(f)
		CompositeFormula(c, args,_) => begin
			return @match c begin
				Not => CompositeFormula(c, [get_overapprox(args[1])])
				Implies => CompositeFormula(c, [get_overapprox(args[1]), get_underapprox(args[2])])
				_ => CompositeFormula(c, map(get_underapprox, args))
			end
		end
		_ => f
	end
end