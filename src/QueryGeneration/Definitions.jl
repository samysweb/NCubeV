import Base.isequal
import Base.hash

@data BooleanVariableType begin
	IntermediateVariable
	ConstraintVariable(::Union{LinearConstraint,Atom,ApproxNode})
	ApproxCase(case_id)
end

mutable struct BooleanSkeleton
	query :: Query
	variable_mapping :: Dict{Int64, BooleanVariableType}
	sat_instance :: PicoPtr
	function BooleanSkeleton(query :: Query)
		variable_mapping = Dict{Int64, BooleanVariableType}()
		sat_instance :: PicoPtr = picosat_init()
		skeleton = new(query, variable_mapping, sat_instance)
		finalizer(x -> picosat_reset(x.sat_instance), skeleton)
		transform_formula(skeleton)
		return skeleton
	end
end

struct SkeletonFormula <: Formula
	variable_number :: Int64
end