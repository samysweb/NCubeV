import Base.isequal
import Base.hash
import ..AST.term_to_string

@data BooleanVariableType begin
	IntermediateVariable
	ConstraintVariable(::Union{LinearConstraint,Atom,ApproxNode})
	ApproxCase(dim,case_id)
	IsMaxCase(atoms)#id,options)
end

mutable struct BooleanSkeleton
	query :: Query
	variable_mapping :: Dict{Int64, BooleanVariableType}
	sat_instance :: PicoPtr
	input_configured :: Bool
	similar_formula_cache :: Dict{Term,Vector{Tuple{Bool,TermNumber,Int}}}
	use_approx :: Bool
	function BooleanSkeleton(query :: Query, full_ctx, use_approx)
		return @timeit Config.TIMER "boolean_skeleton" begin
			variable_mapping = Dict{Int64, BooleanVariableType}()
			sat_instance :: PicoPtr = picosat_init()
			save_original_clauses(sat_instance)
			picosat_set_verbosity(sat_instance, 0)
			skeleton = new(query, variable_mapping, sat_instance, false,Dict{Term,Vector{Tuple{Bool,TermNumber}}}(), use_approx)
			finalizer(x -> picosat_reset(x.sat_instance), skeleton)
			transform_formula(skeleton)
			return skeleton
		end
	end
end

struct IterableQuery
	query :: Query
	smt_state :: Any
	use_approx :: Bool
end

struct SkeletonFormula <: Formula
	variable_number :: Int64
end

function term_to_string(t :: SkeletonFormula)
	return "SkeletonFormula($(t.variable_number))"
end