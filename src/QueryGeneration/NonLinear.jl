"""
	handle_nonlinearity(b::BoundType, f::Term) -> (Set{ApproxQuery}, Term)

Walk a term and replace nonlinear subterms with `NonLinearSubstitution`
placeholders, collecting `ApproxQuery` descriptors. Flips bound types when
multiplying/dividing by negative scalars.
"""
function handle_nonlinearity(b :: BoundType, f :: Term) :: Tuple{Set{ApproxQuery}, Term}
	queries, formula = handle_nonlinearity_internal(b, f)
	return queries, simplify(formula)
end

"""
	handle_nonlinearity_internal(b::BoundType, f::Term)

Internal recursive helper implementing the substitution logic for nonlinear
operations (Mul/Div/Pow). See `handle_nonlinearity`.
"""
function handle_nonlinearity_internal(b :: BoundType, f ::Term) :: Tuple{Set{ApproxQuery}, Term}
	@match f begin
		CompositeTerm(op, args,_) => begin
			@match op begin
				Add => begin
					res = Set{ApproxQuery}()
					new_args = Vector{Term}()
					for arg in args
						new_res, new_arg = handle_nonlinearity_internal(b, arg)
						res = union(res, new_res)
						push!(new_args,new_arg)
					end
					return res, CompositeTerm(AST.Add, new_args)
				end
				Mul => begin
					if args[1] isa TermNumber
						if args[1].value < 0
							b = flip(b)
						end
						if length(args) == 2
							res, new_arg = handle_nonlinearity_internal(b, args[2])
							return res, CompositeTerm(AST.Mul, [args[1], new_arg])
						else
							res = ApproxQuery(b, *(args[2:end]...))
							return Set{ApproxQuery}((res,)), CompositeTerm(AST.Mul, [args[1], NonLinearSubstitution(res)])
						end
					else
						res = ApproxQuery(b, f)
						return Set{ApproxQuery}((res,)), NonLinearSubstitution(res)
					end
				end
				Pow => begin
					@assert !(args[2] isa TermNumber) || args[2].value >= 0
					res = ApproxQuery(b, f)
					return Set{ApproxQuery}((res,)), NonLinearSubstitution(res)
				end
				Div => begin
					if args[2] isa TermNumber
						if args[2].value < 0
							b = flip(b)
						end
						@assert length(args) == 2
						res, new_arg = handle_nonlinearity_internal(b, args[1])
						return res, CompositeTerm(AST.Mul,[TermNumber(1/args[2].value), new_arg])
					else
						res = ApproxQuery(b, f)
						return Set{ApproxQuery}((res,)), NonLinearSubstitution(res)
					end
				end
			end
		end
		Variable() => (Set{ApproxQuery}(), f)
		TermNumber() => (Set{ApproxQuery}(), f)
	end
end
