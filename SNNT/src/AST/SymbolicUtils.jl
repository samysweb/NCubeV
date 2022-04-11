using Metatheory.Rewriters
using SymbolicUtils
using Metatheory

import SymbolicUtils.simplify

# Many of the rules are based on the rules provided by SymbolicUtils.simplify with adjustments for our AST types.

function not_division(x :: Term)
	@debug "not_division -", x," - ", !(x isa CompositeTerm) || operation(x) != (/)
	return !(x isa CompositeTerm) || operation(x) != (/) && (!istree(x) || all(y->not_division(y), arguments(x)))
end

function _isone(x :: Term)
	return x isa TermNumber && isone(x.value)
end

function _iszero(x :: Term)
	return x isa TermNumber && iszero(x.value)
end

function _isnotzero(x :: Term)
	return !_iszero(x)
end

function _istrue(x :: Formula)
	return x isa TrueAtom
end

function _isfalse(x :: Formula)
	return x isa FalseAtom
end

function is_literal_number(x :: Term)
	return x isa TermNumber
end

PLUS_RULES = [
	@rule(~x::SymbolicUtils.isnotflat(+) => SymbolicUtils.flatten_term(+, ~x))
	@rule(~x::SymbolicUtils.needs_sorting(+) => SymbolicUtils.sort_args(+, ~x))
	@SymbolicUtils.ordered_acrule(~a::is_literal_number + ~b::is_literal_number => ~a + ~b)

	#@acrule(*(~~x) + *(~β, ~~x) => *(1 + ~β, (~~x)...))
	#@acrule(*(~α, ~~x) + *(~β, ~~x) => *(~α + ~β, (~~x)...))
	#@acrule(*(~~x, ~α) + *(~~x, ~β) => *(~α + ~β, (~~x)...))

	#@acrule(~x + *(~β, ~x) => *(1 + ~β, ~x))
	@acrule(*(~α::is_literal_number, ~x) + ~x => *(~α + 1, ~x))
	@rule(+(~~x::SymbolicUtils.hasrepeats) => +(SymbolicUtils.merge_repeats(*, ~~x)...))

	@SymbolicUtils.ordered_acrule((~z::_iszero + ~x) => ~x)
	@rule(+(~x) => ~x)
]

TIMES_RULES = [
	@rule(~x::SymbolicUtils.isnotflat(*) => SymbolicUtils.flatten_term(*, ~x))
	@rule(~x::SymbolicUtils.needs_sorting(*) => SymbolicUtils.sort_args(*, ~x))

	@SymbolicUtils.ordered_acrule(~a::is_literal_number * ~b::is_literal_number => ~a * ~b)
	@rule(*(~~x::SymbolicUtils.hasrepeats) => *(SymbolicUtils.merge_repeats(^, ~~x)...))

	@acrule((~y)^(~n) * ~y => (~y)^(~n+1))
	@SymbolicUtils.ordered_acrule((~x)^(~n) * (~x)^(~m) => (~x)^(~n + ~m))

	@SymbolicUtils.ordered_acrule((~z::_isone  * ~x) => ~x)
	@SymbolicUtils.ordered_acrule((~z::_iszero *  ~x) => ~z)
	@rule(*(~x) => ~x)
]


POW_RULES = [
	@rule(^(*(~~x), ~y::SymbolicUtils._isinteger) => *(map(a->pow(a, ~y), ~~x)...))
	@rule((((~x)^(~p::SymbolicUtils._isinteger))^(~q::SymbolicUtils._isinteger)) => (~x)^((~p)*(~q)))
	@rule(^(~x, ~z::_iszero) => 1)
	@rule(^(~x, ~z::_isone) => ~x)
	@rule(inv(~x) => 1/(~x))
]

ASSORTED_RULES = [
	@rule(identity(~x) => ~x)
	@rule(-(~x) => -1*~x)
	@rule(-(~x, ~y) => ~x + -1(~y))
	@rule(~x::_isone \ ~y => ~y)
	@rule(~x \ ~y => ~y / (~x))
	@rule(one(~x) => one(symtype(~x)))
	@rule(zero(~x) => zero(symtype(~x)))
	@rule(conj(~x::SymbolicUtils._isreal) => ~x)
	@rule(real(~x::SymbolicUtils._isreal) => ~x)
	@rule(imag(~x::SymbolicUtils._isreal) => zero(symtype(~x)))
	@rule(ifelse(~x::is_literal_number, ~y, ~z) => ~x ? ~y : ~z)
	# DIV Rules
	@rule (~x / ~x => TermNumber(1.0))
	@rule(~x / (~y) => (~x) * (TermNumber(1.0) / ~y))
	@acrule +((~z / ~y)*~x,~~xs) => (~z / ~y)*+(~x, map(a->a*(~y/~z), ~~xs)...)
	@acrule +(~x*(~z / ~y),~~xs) => (~z / ~y)*+(~x, map(a->a*(~y/~z), ~~xs)...)
	@acrule (~a/~b)*(~c/~d) => (~a*~c)/(~b*~d)
	@acrule (~a/~b::_isone) => ~a
	@rule (~a::is_literal_number / ~b::is_literal_number => ~a / ~b)
	# TODO(steuber): Push even further outwards by multiplying other parts...
]
function number_simplifier()
	rule_tree = [If(istree, Chain(ASSORTED_RULES)),
				 If(SymbolicUtils.is_operation(+),
					Chain(PLUS_RULES)),
				 If(SymbolicUtils.is_operation(*),
					Chain(TIMES_RULES)),
				 If(SymbolicUtils.is_operation(^),
					Chain(POW_RULES))]

	return Chain(rule_tree)
end

function composite_formula_simplifier()
	Postwalk(
		Chain(
			[
				@acrule ((and(~x::_istrue, ~~y)) => (and_construction(convert(Vector{Formula},~~y))))
				@acrule ((and(~x::_isfalse, ~~y)) => (FalseAtom()))
				@acrule ((or(~x::_istrue, ~~y)) => (TrueAtom()))
				@acrule ((or(~x::_isfalse, ~~y)) => (or_construction(convert(Vector{Formula},~~y...))))
			]
		)
	)
end

function solve_concrete_atom(f, a :: TermNumber, b :: TermNumber)
	if f(a.value,b.value)
		return TrueAtom()
	else
		return FalseAtom()
	end
end

function atom_simplifier()
	Postwalk(
		Chain(
			[

				@rule (~a <= ~b::_isnotzero => leq(~a - ~b, TermNumber(0.0)))
				@rule (~a >= ~b => leq(~b - ~a, TermNumber(0.0)))
				@rule (~a <  ~b::_isnotzero => le(~a - ~b,  TermNumber(0.0)))
				@rule (~a >  ~b => le(~b - ~a,  TermNumber(0.0)))
				@rule (~a == ~b::_isnotzero => eq(~a - ~b, TermNumber(0.0)))
				@rule (~a != ~b::_isnotzero => neq(~a - ~b, TermNumber(0.0)))
				
				@rule (~a::is_literal_number <= ~b::is_literal_number => solve_concrete_atom(<=, ~a, ~b))
				@rule (~a::is_literal_number >= ~b::is_literal_number => solve_concrete_atom(>=, ~a, ~b))
				@rule (~a::is_literal_number < ~b::is_literal_number => solve_concrete_atom(<, ~a, ~b))
				@rule (~a::is_literal_number > ~b::is_literal_number => solve_concrete_atom(>, ~a, ~b))
				@rule (~a::is_literal_number == ~b::is_literal_number => solve_concrete_atom(==, ~a, ~b))
				@rule (~a::is_literal_number != ~b::is_literal_number => solve_concrete_atom(!=, ~a, ~b))

				# TODO(steuber): Extend matching rule for >=3 element multiplications
				@rule ( ((~x::_isone/~y)* ~z < ~a) => le(~z, ~a * ~y) )
				@rule ( (~z * (~x::_isone/~y) < ~a) => le(~z, ~a * ~y) )
				@rule ( ((~x::_isone/~y) * ~z <= ~a) => leq(~z, ~a * ~y) )
				@rule ( (~z * (~x::_isone/~y) <= ~a) => leq(~z, ~a * ~y) )
				@rule ( ((~x::_isone/~y) * ~z == ~a) => eq(~z, ~a * ~y) )
				@rule ( (~z * (~x::_isone/~y) == ~a) => eq(~z, ~a * ~y) )
				@rule ( ((~x::_isone/~y) * ~z != ~a) => neq(~z, ~a * ~y) )
				@rule ( (~z * (~x::_isone/~y) != ~a) => neq(~z, ~a * ~y) )
			]
		)
	)
end

function formula_simplifier()
	Postwalk(
		Chain([
			If(x -> typeof(x) <: Atom, atom_simplifier()),
			If(x -> typeof(x) <: CompositeFormula, composite_formula_simplifier())
		])
	)
end

function distribute_factor(x,ys)
	@debug "Distributing factor: ", x, " over ", ys
	return map(y->x*y,ys)
end

function distribution_rules()
	# TODO(steuber): Not if DIV
	Fixpoint(Chain([
			@acrule( (~x::not_division) * (+(~~y)) => +(distribute_factor(x,y)...) ),
			@acrule( (+(~~y)) * (~x::not_division) => +(distribute_factor(x,y)...) )
		]))
end

function term_simplifier()
	Postwalk(
		Chain(
			[
			distribution_rules(),
		 	number_simplifier()
			]
		)
	)
end

function simplify_node()
	Postwalk(
		Chain([
			If(x -> typeof(x) <: Term, term_simplifier()),
			If(x -> typeof(x) <: Formula, formula_simplifier())
		])
	)
end

function simplify(n :: ParsedNode)
	f = Fixpoint(simplify_node())
	return PassThrough(f)(n)
end