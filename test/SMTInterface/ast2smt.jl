
@testset "ast2smt - TermNumber" begin
    n = TermNumber(3.14)
    expr = ast2smt(n, [], [], Dict())
    @test isequal(expr, 3.14)

    n_neg = TermNumber(-2.71)
    expr_neg = ast2smt(n_neg, [], [], Dict())
    @test isequal(expr_neg, -2.71)
end

@testset "ast2smt - Variable" begin
    @satvariable(x[1:2], Real)

    variable = Variable("x2", nothing, 2)
    expr = ast2smt(variable, x, [], Dict())
    @test isequal(expr, x[2])
end

@testset "ast2smt - Atom" begin
    
    @satvariable(x[1:2], Bool)

    true_atom = TrueAtom()
    expr = ast2smt(true_atom, x, [], Dict())
    @test isequal(expr.value, true)

    false_atom = FalseAtom()
    expr = ast2smt(false_atom, x, [], Dict())
    @test isequal(expr.value, false)

    @satvariable(y[1:2], Real)
    a, b = 6//7, -3.14
    ã, b̃ = Float64(a), Float64(b)

    atom = Atom(Less, a, b)
    expr = ast2smt(atom, y, [], Dict())
    @test isequal(expr, ã < b̃)

    atom = Atom(LessEq, a, b)
    expr = ast2smt(atom, y, [], Dict())
    @test isequal(expr, ã ≤ b̃)

    atom = Atom(Greater, a, b)
    expr = ast2smt(atom, y, [], Dict())
    @test isequal(expr, ã > b̃)

    atom = Atom(GreaterEq, a, b)
    expr = ast2smt(atom, y, [], Dict())
    @test isequal(expr, ã ≥ b̃)

    atom = Atom(Eq, a, b)
    expr = ast2smt(atom, y, [], Dict())
    @test isequal(expr, ã == b̃)

    atom = Atom(Neq, a, b)
    expr = ast2smt(atom, y, [], Dict())
    @test isequal(expr, distinct(ã, b̃))

end

@testset "ast2smt — CompositeTerm" begin

    @satvariable(x[1:2], Real)
    a, b = TermNumber(2.5), TermNumber(-4.0)
    ã = ast2smt(a, x, [], Dict())
    b̃ = ast2smt(b, x, [], Dict()) 
    
    # Addition test
    ct_add = CompositeTerm(Add, [a, b])
    expr_add = ast2smt(ct_add, x, [], Dict())
    @test isequal(expr_add, ã + b̃)

    # Subtraction test
    ct_sub = CompositeTerm(Sub, [a, b])
    expr_sub = ast2smt(ct_sub, x, [], Dict())
    @test isequal(expr_sub, ã - b̃)

    # Multiplication test
    ct_mul = CompositeTerm(Mul, [a, b])
    expr_mul = ast2smt(ct_mul, x, [], Dict())
    @test isequal(expr_mul, ã * b̃)

    # Division test
    ct_div = CompositeTerm(Div, [a, b])
    expr_div = ast2smt(ct_div, x, [], Dict())
    @test isequal(expr_div, ã / b̃)

    # Negation test
    ct_neg = CompositeTerm(Neg, [a])
    expr_neg = ast2smt(ct_neg, x, [], Dict())
    @test isequal(expr_neg, -ã)
end

@testset "ast2smt — CompositeFormula" begin

    @satvariable(x[1:3], Real)
    b1 = Atom(Eq, TermNumber(1.0), TermNumber(1.0))
    b2 = Atom(Eq, TermNumber(2.0), TermNumber(2.0))
    b3 = Atom(Eq, TermNumber(3.0), TermNumber(3.0))
    # we use b1, b2, b3 instead of TrueAtom/FalseAtom to avoid automatic simplification of the expected expression

    # AND/OR test
    f = CompositeFormula(And, [b1, CompositeFormula(Or, [b2, b3])])
    expr = ast2smt(f, x, [], Dict())
    expected_expr = (1.0 == 1.0) ∧ ((2.0 == 2.0) ∨ (3.0 == 3.0))
    @test isequal(expr, expected_expr)

    # NOT test
    f₂ = CompositeFormula(Not, [b1])
    expr₂ = ast2smt(f₂, x, [], Dict())
    expected_expr₂ = ¬(1.0 == 1.0)
    @test isequal(expr₂, expected_expr₂)

    # IMPLIES test
    f₃ = CompositeFormula(Implies, [b1, b2])
    expr₃ = ast2smt(f₃, x, [], Dict())
    expected_expr₃ = (1.0 == 1.0) ⟹ (2.0 == 2.0)
    @test isequal(expr₃, expected_expr₃)

    # ITE (if-then-else) test
    f₄ = CompositeFormula(ITE, [b1, b2, b3])
    expr₄ = ast2smt(f₄, x, [], Dict())
    expected_expr₄ = ite((1.0 == 1.0), (2.0 == 2.0), (3.0 == 3.0))
    @test isequal(expr₄, expected_expr₄)
end


# negative values dont work with isequal
@testset "ast2smt — LinearConstraint" begin

    @satvariable(x[1:2], Real)

    lc = LinearConstraint([2, 3//5], 10, true)  # equality=true → ≤
    expr = ast2smt(lc, x, [], Dict())
    expected_expr = 0.0 + 2 * x[1] + Float64(3//5) * x[2] ≤ 10
    @test isequal(expr, expected_expr)

    lceq = LinearConstraint([1, 4], 7, false)  # equality=false → <
    expr = ast2smt(lceq, x, [], Dict())
    expected_expr = 0.0 + 1 * x[1] + 4 * x[2] < 7
    @test isequal(expr, expected_expr)
end

@testset "ast2smt — LinearTerm" begin

    @satvariable(x[1:2], Real)

    lt = LinearTerm([1//2, 3], 4)
    expr = ast2smt(lt, x, [], Dict())
    expected_expr = 0.0 + Float64(1//2) * x[1] + 3 * x[2] + 4.0
    @test isequal(expr, expected_expr)
end


"""
conversion into Float64 depends on the julia environment and casting to Rational{BigInt} may matter. Example:
when using NCube.AST, we get:

julia> Float64.(Rational{BigInt}[5//3])
1-element Vector{Float64}:
1.6666666666666665

julia> Float64(5//3)
1.6666666666666667

but when using only Base, we get:

julia> Float64.(Rational{BigInt}[5//3])
1-element Vector{Float64}:
1.6666666666666667

julia> Float64(5//3)
1.6666666666666667
"""

@testset "ast2smt - SemiLinearConstraint" begin
    @satvariable(x[1:3], Real)

    coeffs = Rational{BigInt}.([1//1, -2//1, 5//3])
    approx_term = Variable("x2", nothing, 2)   # irgendein gültiger Term
    q = ApproxQuery(Upper, approx_term)
    semilinears =  Dict{ApproxQuery,Rational{BigInt}}(q => 1//2)
    
    slc = SemiLinearConstraint(semilinears, coeffs, Rational{BigInt}(4,1), true)

    expr = ast2smt(slc, x, [])
    expected = (0.0 +
                1.0 * x[1] +
                -2.0 * x[2] +
                Float64(Rational{BigInt}(5//3)) * x[3] +
                0.5 * x[2]) ≤ 4.0

    @test isequal(expr, expected)
end

@testset "ast2smt - NormalizedQuery" begin
    
    # input x1, x2
    # output x3
    @satvariable(x[1:3], Real)

    
    input_bounds = [
        [-1.0, 1.0], # -1.0 ≤ x1 ≤ 1.0
        [-2.0, 2.0]  # -2.0 ≤ x2 ≤ 2.0
    ]
    output_bounds = [[-3.0, 3.0]]  # -10.0 ≤ x3 ≤ 10.0
    input_bounds_expr = Sat.and((-1.0 <= x[1]) ∧ (x[1] <= 1.0),
                                (-2.0 <= x[2]) ∧ (x[2] <= 2.0))
    output_bounds_expr = Sat.and((-3.0 <= x[3]) ∧ (x[3] <= 3.0))
    

    # PwlConjunction für Input
    input_pwl_bounds = [
        [-10.0, 10.0], # -10.0 ≤ x1 ≤ 10.0
        [-20.0, 20.0]  # -20.0 ≤ x2 ≤ 20.0
    ]
    # linear constraint für input pwl (x1 + x2 ≤ 10)
    input_pwl_lc = LinearConstraint([1//1, 1//1], 10//1, true)
    # semi-linear constraint für input pwl (2*x1 + 2*x2 + 3*x2 < 20)  
    input_pwl_term = Variable("x2", nothing, 2)
    input_pwl_approx = Dict{ApproxQuery,Rational{BigInt}}(ApproxQuery(Upper, input_pwl_term) => 3//1)
    input_pwl_coeffs = Rational{BigInt}.([2//1, 2//1])
    input_pwl_bias = Rational{BigInt}(20,1)
    input_pwl_slc = SemiLinearConstraint(input_pwl_approx, input_pwl_coeffs, input_pwl_bias, false)
    # input_constraints zusammensetzen
    input_constraints = PwlConjunction(input_pwl_bounds, [input_pwl_lc], [input_pwl_slc])

    input_constraints_expr = Sat.and(
        ( (-10.0 <= x[1]) ∧ (x[1] <= 10.0) ) ∧
        ( (-20.0 <= x[2]) ∧ (x[2] <= 20.0) ),
        ( 0.0 + 1.0*x[1] + 1.0*x[2] ≤ 10.0 ),
        ( 0.0 + 2.0*x[1] + 2.0*x[2] + 3.0*x[2] < 20.0 )
    )

    # PwlConjunction für Mixed
    mixed_pwl_bounds = [
        [-11.0, 11.0], # -11.0 ≤ x1 ≤ 11.0
        [-21.0, 21.0], # -21.0 ≤ x2 ≤ 21.0
        [-31.0, 31.0]  # -31.0 ≤ x3 ≤ 31.0
    ]
    # linear constraint für mixed pwl (x1 + x2 + x3 ≤ 11)
    mixed_pwl_lc = LinearConstraint([1//1, 1//1, 1//1], 11//1, true)
    # semi-linear constraint für mixed pwl (2*x1 + 2*x2 + 2*x3 + 3*x3 ≤ 21)  
    mixed_pwl_term = Variable("x3", nothing, 3)
    mixed_pwl_approx = Dict{ApproxQuery,Rational{BigInt}}(ApproxQuery(Upper, mixed_pwl_term) => 3//1)
    mixed_pwl_coeffs = Rational{BigInt}.([2//1, 2//1, 2//1])
    mixed_pwl_bias = Rational{BigInt}(21,1)
    mixed_pwl_slc = SemiLinearConstraint(mixed_pwl_approx, mixed_pwl_coeffs, mixed_pwl_bias, true)
    # mixed_constraints zusammensetzen
    mixed_constraints = PwlConjunction(mixed_pwl_bounds, [mixed_pwl_lc], [mixed_pwl_slc])

    mixed_constraints_expr = 
    Sat.and(
        Sat.and(
            ( (-11.0 <= x[1]) ∧ (x[1] <= 11.0) ),
            ( (-21.0 <= x[2]) ∧ (x[2] <= 21.0) ),
            ( (-31.0 <= x[3]) ∧ (x[3] <= 31.0) )
        ),
        ( 0.0 + 1.0*x[1] + 1.0*x[2] + 1.0*x[3] ≤ 11.0 ),
        ( 0.0 + 2.0*x[1] + 2.0*x[2] + 2.0*x[3] + 3.0*x[3] ≤ 21.0 )
    )

    nq = NormalizedQuery(
        input_bounds,
        output_bounds,
        input_constraints,
        [mixed_constraints],
        Dict{Term, Vector{BoundType}}()
    )
    expr = ast2smt(nq, x, [])
    expected = Sat.and(
        input_bounds_expr,
        output_bounds_expr,
        input_constraints_expr,
        mixed_constraints_expr
    )
    # TODO: write a function to canonicalize expressions for equality testing
    #@test isequal(expr, expected)
    @test (sat!(expr == expected) == :SAT)
end


@testset "ast2smt - smt_pow" begin
    @satvariable(x, Real)
    v = Variable("x", nothing, 1)

    # x⁰ = 1
    n = TermNumber(0//1)
    t = CompositeTerm(Pow, [v, n])
    expr = ast2smt(t, [x], [], Dict())
    @test isequal(expr, 1.0)
    
    # x¹ = x
    n = TermNumber(1//1)
    t = CompositeTerm(Pow, [v, n])
    expr = ast2smt(t, [x], [], Dict())
    @test isequal(expr, x)

    # x³ = x * x * x
    n = TermNumber(3//1)
    t = CompositeTerm(Pow, [v, n])
    expr = ast2smt(t, [x], [], Dict())
    @test isequal(expr, x * x * x)

    # x⁻² = 1 / (x * x)
    n = TermNumber(-2//1)
    t = CompositeTerm(Pow, [v, n])
    expr = ast2smt(t, [x], [], Dict())
    @test isequal(expr, 1.0 / (x * x))

    # non-integer exponent should throw an error
    n = TermNumber(1//2)
    t = CompositeTerm(Pow, [v, n])
    @test_throws AssertionError ast2smt(t, [x], [], Dict())
    
    # 2³ = 8
    a = TermNumber(2.0)
    n = TermNumber(3//1)
    t = CompositeTerm(Pow, [a, n])
    expr = ast2smt(t, [], [], Dict())
    expected_expr = ast2smt(TermNumber(8//1), [], [], Dict())
    @test isequal(expr, expected_expr)

    # 2⁻³ = 8
    a = TermNumber(2.0)
    n = TermNumber(-3//1)
    t = CompositeTerm(Pow, [a, n])
    expr = ast2smt(t, [], [], Dict())
    expected_expr = ast2smt(TermNumber(1//8), [], [], Dict())
    @test isequal(expr, expected_expr)
end










