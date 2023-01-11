import Base.isequal
import Base.hash
import ..AST.term_to_string

@data BooleanVariableType begin
	IntermediateVariable
	ConstraintVariable(::Union{LinearConstraint,Atom,ApproxNode})
	ApproxCase(dim,case_id)
end

mutable struct BooleanSkeleton
	query :: Query
	variable_mapping :: Dict{Int64, BooleanVariableType}
	sat_instance :: PicoPtr
	smt_feasibility :: Any
	function BooleanSkeleton(query :: Query, full_ctx)
		return @timeit Config.TIMER "boolean_skeleton" begin
			variable_mapping = Dict{Int64, BooleanVariableType}()
			sat_instance :: PicoPtr = picosat_init()
			skeleton = new(query, variable_mapping, sat_instance, nl_feasible_init(full_ctx))
			finalizer(x -> picosat_reset(x.sat_instance), skeleton)
			transform_formula(skeleton)
			return skeleton
		end
	end
end

struct IterableQuery
	query :: Query
	smt_state :: Any
end

struct SkeletonFormula <: Formula
	variable_number :: Int64
end

function term_to_string(t :: SkeletonFormula)
	return "SkeletonFormula($(t.variable_number))"
end