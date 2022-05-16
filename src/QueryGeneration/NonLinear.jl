function handle_nonlinearity(b :: BoundType, f :: Term) :: Tuple{Set{ApproxQuery}, Term}
	queries, formula = handle_nonlinearity_internal(b, f)
	return queries, simplify(formula)
end

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

# function collect_nonlinearities(b :: BoundType, f ::Term) :: Set{ApproxQuery}
# 	return @match f begin
# 		TermNumber() => return Set{ApproxQuery}()
# 		Variable(name, _, _) => return Set{ApproxQuery}()
# 		CompositeTerm(op, args) => begin
# 			@match op begin
# 				Add => begin
# 					res = Set{ApproxQuery}()
# 					for cur_arg in args
# 						res=union(res, collect_nonlinearities(b, cur_arg))
# 					end
# 					return res
# 				end
# 				Sub => begin
# 					res = collect_nonlinearities(b, args[1])
# 					for cur_arg in args[2:end]
# 						res=union(res, collect_nonlinearities(flip(b), cur_arg))
# 					end
# 					return res
# 				end
# 				Mul => begin
# 					if args[1] isa TermNumber && args[1].value < 0
# 						b = flip(b)
# 					end
# 					if length(args) == 2
# 						return collect_nonlinearities(b, args[2])
# 					else
# 						res = ApproxQuery(b, *(args[2:end]...))
# 						return Set{ApproxQuery}((res,))
# 					end
# 				end
# 				Div => begin
# 					throw("Encountered division in collect_nonlinearities; Divisions should have been eliminated by now")
# 				end
# 				Pow => begin
# 					@assert !(args[2] isa TermNumber) || args[2].value >= 0
# 					res = ApproxQuery(b, f)
# 					return Set{ApproxQuery}((res,))
# 				end
# 				Neg => begin
# 					return collect_nonlinearities(flip(b), args[1])
# 				end
# 			end
# 		end
# 	end
# end