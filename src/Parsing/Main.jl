"""
Parsing
=======

Lightweight parser for formal specifications/constraints built on Tokenize.jl.
This module exports `parse_constraint` and includes the implementation from
`Parsing.jl`.

Supported constructs (informal):
- Arithmetic terms: addition, subtraction, multiplication, division,
  (polynomial) exponentiation, parentheses, unary minus
- Comparison operators: `> >= < <= == !=`
- Boolean logic: `!` (not), `&&` (and), `||` (or), `->` (implies)
- Predicates: e.g., `isMax(t1, t2, ...)`

Example
```julia
spec = parse_constraint("spec.txt")
```
"""
module Parsing
	using Tokenize
	using ..AST

	export parse_constraint

	include("Parsing.jl")
end