function to_expr(v :: Variable; var_map :: Union{Nothing,Dict{Variable, Expr}} = nothing) :: Union{Expr, Number, Symbol}
	if !isnothing(var_map)
		return var_map[v]
	else
		return Symbol("x"*string(v.position))
	end
end

function to_expr(n :: TermNumber; var_map :: Union{Nothing,Dict{Variable, Expr}} = nothing) :: Union{Expr, Number, Symbol}
	return n.value
end

function to_expr(t :: CompositeTerm; var_map :: Union{Nothing, Dict{Variable, Expr}} = nothing) :: Union{Expr, Number, Symbol}
	args = Vector{Union{Expr, Number, Symbol}}()
	for arg in t.args
		push!(args, to_expr(arg, var_map=var_map))
	end
	return Expr(:call, to_expr(t.operation, var_map=var_map), args...)
end

function to_expr(op :: Operation; var_map :: Union{Nothing, Dict{Variable, Expr}} = nothing) :: Union{Expr, Number, Symbol}
	@match op begin
		Add => :+
		Sub => :-
		Mul => :*
		Div => :/
		Pow => :^
		Neg => :-
	end
end

function from_expr(e :: Number) :: TermNumber
	return TermNumber(rationalize(convert(Float32,e)))
end

function from_expr(e :: Symbol) :: Variable
	name = string(e)
	m = match(r"x(\d+)", name)
	position = nothing
	if !isnothing(m)
		position = parse(Int64,m[1])
	end
	res = Variable(name, nothing, position)
	return res
end

function from_expr(e :: Expr) :: CompositeTerm
	@assert e.head == :call
	operation = op_from_expr(e.args[1])
	args = Vector{Term}()
	for arg in e.args[2:end]
		push!(args, from_expr(arg))
	end
	res =  CompositeTerm(operation, args)
	return res
end

function op_from_expr(s :: Symbol) :: Operation
	@match s begin
		:+ => Add
		:- => Sub
		:* => Mul
		:/ => Div
		:^ => Pow
		:- => Neg
		:min => Min
		:max => Max
	end
end