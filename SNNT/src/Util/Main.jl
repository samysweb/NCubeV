module Util

using Base.Rounding

function __init__()
	Rounding.setrounding(BigFloat,Rounding.RoundDown)
end

export round_minimize, round_maximize

function round_minimize(x :: Rational{BigInt}) :: Float32
	if iszero(x)
		return 0.0
	else
		return Float32(BigFloat(x))
	end
end

function round_maximize(x :: Rational{BigInt}) :: Float32
	if iszero(x)
		return 0.0
	else
		return -Float32(BigFloat(-x))
	end
end

end