using Metatheory.Rewriters
using SymbolicUtils

import SymbolicUtils.simplify

function formula_simplifier()
	PassThrough(Empty())
end

function distribute_factor(x,ys)
	return map(y->x*y,ys)
end

function distribution_rules()
	Fixpoint(
		Chain([
			@acrule( (~x) * (+(~~y)) => +(distribute_factor(x,y)...) ),
			@acrule( (+(~~y)) * (~x) => +(distribute_factor(x,y)...) )
		])
	)
end

function term_simplifier()
	Postwalk(
		Chain(
			[
				distribution_rules(),
				SymbolicUtils.default_simplifier()
			]
		)
	)
end

function simplify_node()
	Postwalk(
		Chain([
			If(x -> typeof(x) <: Formula, formula_simplifier()),
			If(x -> typeof(x) <: Term, term_simplifier())
		])
	)
end

function simplify(n :: ParsedNode)
	f = Fixpoint(simplify_node())
	return PassThrough(f)(n)
end