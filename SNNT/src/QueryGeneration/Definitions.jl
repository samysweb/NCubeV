@data BooleanVariableType begin
	IntermediateVariable
	ConstraintVariable(::Union{LinearConstraint,Atom,ApproxNode})
end

mutable struct BooleanSkeleton
	formula :: Formula
	variable_mapping :: Dict{Int64, BooleanVariableType}
	sat_instance :: PicoPtr
	function BooleanSkeleton(formula :: F) where {F <: Formula}
		variable_mapping = Dict{Int64, BooleanVariableType}()
		sat_instance :: PicoPtr = picosat_init()
		skeleton = new(formula, variable_mapping, sat_instance)
		finalizer(x -> picosat_reset(x.sat_instance), skeleton)
		transform_formula(skeleton)
		return skeleton
	end
end

struct SkeletonFormula <: Formula
	variable_number :: Int64
end