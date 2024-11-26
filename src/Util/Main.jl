module Util

using Base.Rounding

using ..Config

function __init__()
	Rounding.setrounding(BigFloat,Rounding.RoundDown)
end

export round_minimize, round_maximize, print_msg

@inline function round_minimize(x :: Rational{BigInt}) :: Float32
	return Float32(BigFloat(x))
end

@inline function round_maximize(x :: Rational{BigInt}) :: Float32
	return -Float32(BigFloat(-x))
end

@inline function print_msg(args :: Vararg{Any})
	if Config.OUTPUT
		println(args...)
		flush(stdout)
	end
end

end