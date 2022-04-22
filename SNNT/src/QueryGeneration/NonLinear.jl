
function collect_nonlinearities(b :: BoundType, f ::Term) :: Set{ApproxQuery}
	return @match f begin
		TermNumber() => return Set{ApproxQuery}()
		Variable(name, _, _) => return Set{ApproxQuery}()
		CompositeTerm(op, args) => begin
			@match op begin
				Add => begin
					res = Set{ApproxQuery}()
					for cur_arg in args
						res=union(res, collect_nonlinearities(b, cur_arg))
					end
					return res
				end
				Sub => begin
					res = collect_nonlinearities(b, args[1])
					for cur_arg in args[2:end]
						res=union(res, collect_nonlinearities(flip(b), cur_arg))
					end
					return res
				end
				Mul => begin
					if args[1] isa TermNumber && args[1].value < 0
						b = flip(b)
					end
					if length(args) == 2
						return collect_nonlinearities(b, args[2])
					else
						res = ApproxQuery(b, *(args[2:end]...))
						return Set{ApproxQuery}((res,))
					end
				end
				Div => begin
					throw("Encountered division in collect_nonlinearities; Divisions should have been eliminated by now")
				end
				Pow => begin
					@assert !(args[2] isa TermNumber) || args[2].value >= 0
					res = ApproxQuery(b, f)
					return Set{ApproxQuery}((res,))
				end
				Neg => begin
					return collect_nonlinearities(flip(b), args[1])
				end
			end
		end
	end
end