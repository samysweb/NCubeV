"""
Util
====

Small utility helpers for rounding rationals in a sound direction and
flushing print output during long runs.
"""
module Util

using Base.Rounding

function __init__()
	Rounding.setrounding(BigFloat,Rounding.RoundDown)
end

export round_minimize, round_maximize, print_msg

"""
	round_minimize(x::Rational{BigInt}) -> Float32

Round downward to avoid violating `<=` constraints when converting rationals
to floats.
"""
@inline function round_minimize(x :: Rational{BigInt}) :: Float32
	return Float32(BigFloat(x))
end

"""
	round_maximize(x::Rational{BigInt}) -> Float32

Round upward (via negation trick) to preserve `>=` style bounds when converting
to floats.
"""
@inline function round_maximize(x :: Rational{BigInt}) :: Float32
	return -Float32(BigFloat(-x))
end

"""
	print_msg(args...)

Print and immediately flush stdout to keep logs responsive.
"""
@inline function print_msg(args :: Vararg{Any})
	println(args...)
	flush(stdout)
end

end