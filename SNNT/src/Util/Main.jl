module Util

using Base.Rounding

function __init__()
	Rounding.setrounding(BigFloat,Rounding.RoundDown)
end

export round_minimize, round_maximize

@inline function round_minimize(x :: Rational{BigInt}) :: Float32
	return Float32(BigFloat(x))
end

@inline function round_maximize(x :: Rational{BigInt}) :: Float32
	return -Float32(BigFloat(-x))
end

end