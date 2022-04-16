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
			replacement_map[Variable(k)] = Variable(v)
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

function make_linear(left :: Term, right :: Term, comp :: Comparator, var_number :: Int64)
	@assert AST.is_linear(left) && right isa TermNumber
	constraint_row = zeros(Float64, var_number)
	bias = right.value
	@match left begin
		TermNumber(value) => throw("Constraint "*string(left)*" "*string(comp)*" "*string(right)*" should have been simplified already")
		Variable(name, _, position) => begin
			constraint_row[position]+=1.0
		end
		CompositeTerm(op, args) => begin
			if op == AST.Mul
				@assert length(args) == 2
				@assert args[1] isa TermNumber
				@assert args[2] isa Variable
				constraint_row[args[2].position]+=args[1].value
			elseif op == AST.Add
				for cur_arg in left.args
					if cur_arg isa Variable
						constraint_row[cur_arg.position] += 1
					elseif cur_arg isa TermNumber
						bias -= cur_arg.value
					elseif cur_arg.operation == AST.Mul
						@assert length(cur_arg.args) == 2
						if cur_arg.args[1] isa TermNumber
							constraint_row[cur_arg.args[2].position] += cur_arg.args[1].value
						else
							constraint_row[cur_arg.args[1].position] += cur_arg.args[2].value
						end
					else
						throw("Unsupported term in make_linear: "*string(cur_arg))
					end
				end
			end
		end
		_ => throw("Unsupported term in make_linear: "*string(left))
	end
	if comp == AST.LessEq
		return LinearConstraint(constraint_row, bias, true)
	elseif comp == AST.Less
		return LinearConstraint(constraint_row, bias, false)
	elseif comp == AST.Eq
		return AST.and_construction(Formula[
			LinearConstraint(constraint_row, bias, true),
			LinearConstraint(-constraint_row, -bias, true)
		])
	elseif comp == AST.Neq
		return AST.or_construction(Formula[
			LinearConstraint(constraint_row, bias, false),
			LinearConstraint(-constraint_row, -bias, false)
		])
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

function overapprox(f :: ParsedNode)
	return @match f begin
		Atom() => OverApprox(f)
		CompositeFormula(c, args) => begin
			print(c)
			return @match c begin
				Not => CompositeFormula(c, [underapprox(args[1])])
				Implies => begin
					res = CompositeFormula(c, [underapprox(args[1]), overapprox(args[2])])
					print(res)
					return res
				end
				_ => begin
					print(c)
					println("fallback")
					return CompositeFormula(c, map(overapprox, args))
				end
			end
		end
		_ => f
	end
end

function underapprox(f :: ParsedNode)
	return @match f begin
		Atom() => UnderApprox(f)
		CompositeFormula(c, args) => begin
			return @match c begin
				Not => CompositeFormula(c, [overapprox(args[1])])
				Implies => CompositeFormula(c, [overapprox(args[1]), underapprox(args[2])])
				_ => CompositeFormula(c, map(underapprox, args))
			end
		end
		_ => f
	end
end