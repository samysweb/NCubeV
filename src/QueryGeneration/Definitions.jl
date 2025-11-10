import Base.isequal
import Base.hash
import ..AST.term_to_string

@data BooleanVariableType begin
	IntermediateVariable
	ConstraintVariable(::Union{LinearConstraint,Atom,ApproxNode})
	ApproxCase(dim,case_id)
	IsMaxCase(atoms)#id,options)
end

Base.Docs.@doc """
    BooleanVariableType

Sum type of boolean variables used in the SAT-level skeleton of a query:
- `IntermediateVariable`: Auxiliary boolean introduced during CNF transformation.
- `ConstraintVariable`: Represents a linear or atomic constraint (including approx nodes).
- `ApproxCase(dim, case_id)`: Case-split along dimension `dim` in Mosaic.
- `IsMaxCase(atoms)`: Encodes max/min disambiguation cases.

These guide the enumeration of azulejos in the boolean skeleton (Appendix B.2).
"""
BooleanVariableType

"""
    BooleanSkeleton(query, full_ctx, use_approx)

Container holding the SAT instance and mappings from constraints to boolean variables.
It incrementally enumerates satisfying assignments and cooperates with an SMT solver to
check theory satisfiability per assignment (DPLL(T)-style).

Arguments
- `query::Query`: Non-normalized open-loop NNV query.
- `full_ctx`: SMT context handle.
- `use_approx::Bool`: If true, include linearized approximations from `Approx`.

Notes
- See Appendix B.2 for the Mosaic decomposition procedure.
"""
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

"""
    IterableQuery

Tuple struct combining a `Query` with SMT solver state and a flag whether to
include approximations. Provides an `iterate` interface to enumerate normalized
linear queries per azulejo.

Contract
- Input: prepared `Query` (post Analysis/Approx), SMT state `(ctx, variables)`
- Output: Implements `Base.iterate` yielding `(OlnnvQuery, state)` like tuples
"""
struct IterableQuery
	query :: Query
	smt_state :: Any
	use_approx :: Bool
end

"""
    SkeletonFormula(variable_number)

Wrapper formula that refers to a boolean skeleton variable by ID.
Used while rewriting formulas into a boolean abstraction for SAT solving (Appendix B.2).
"""
struct SkeletonFormula <: Formula
	variable_number :: Int64
end

function term_to_string(t :: SkeletonFormula)
	return "SkeletonFormula($(t.variable_number))"
end