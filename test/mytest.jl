using NCubeV.AST
using NCubeV.SMTInterface
using Satisfiability

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
    @test isequal(expr, true)

    false_atom = FalseAtom()
    expr = ast2smt(false_atom, x, [], Dict())
    @test isequal(expr, false)

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
    a, b = TermNumber(2.5), TermNumber(4.0)
    ã, b̃ = Float64(a.value), Float64(b.value)

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

    @satvariable(x[1:3], Bool)
    T = TrueAtom()
    F = FalseAtom()

    # AND/OR test
    f = CompositeFormula(And, [T, CompositeFormula(Or, [F, T])])
    expr = ast2smt(f, x, [], Dict())
    expected_expr = true ∧ (false ∨ true)
    @test isequal(expr, expected_expr)

    # NOT test
    f₂ = CompositeFormula(Not, [F])
    expr₂ = ast2smt(f₂, x, [], Dict())
    expected_expr₂ = ¬false
    @test isequal(expr₂, expected_expr₂)

    # IMPLIES test
    f₃ = CompositeFormula(Implies, [T, F])
    expr₃ = ast2smt(f₃, x, [], Dict())
    expected_expr₃ = true ⟹ false
    @test isequal(expr₃, expected_expr₃)

    # ITE (if-then-else) test
    f₄ = CompositeFormula(ITE, [T, F, T])
    expr₄ = ast2smt(f₄, x, [], Dict())
    expected_expr₄ = ite(true, false, true)
    @test isequal(expr₄, expected_expr₄)
end


# negative values dont work with isequal
@testset "ast2smt — LinearConstraint" begin

    @satvariable(x[1:2], Real)

    lc = LinearConstraint([2, 3//5], 10, true)  # equality=true → ≤
    expr = ast2smt(lc, x, [], Dict())
    @test isequal(expr, 2 * x[1] + Float64(3//5) * x[2] ≤ 10)

    lceq = LinearConstraint([1, 4], 7, false)  # equality=false → <
    expr = ast2smt(lceq, x, [], Dict())
    @test isequal(expr, 1 * x[1] + 4 * x[2] < 7)
end

@testset "ast2smt — LinearTerm" begin

    @satvariable(x[1:2], Real)

    lt = LinearTerm([1//2, 3], 4)
    expr = ast2smt(lt, x, [], Dict())
    @test isequal(expr, Float64(1//2) * x[1] + 3 * x[2] ≤ 4)
end

@testset "ast2smt - SemiLinearConstraint" begin
    @satvariable(x[1:3], Real)

    coeffs = Rational{BigInt}.([1//1, -2//1, 5//3])
    approx_term = Variable("x2", nothing, 2)   # irgendein gültiger Term
    q = ApproxQuery(Upper, approx_term)
    semilinears =  Dict{ApproxQuery,Rational{BigInt}}(q => 1//2)
    
    slc = SemiLinearConstraint(semilinears)(coeffs, Rational{BigInt}(4,1), true)

    expr = ast2smt(slc, x, [])
    expected = (1.0 * x[1] +
                -2.0 * x[2] +
                Float64(5//3) * x[3] +
                0.5 * x[2]) ≤ 4.0

    #@test isequal(expr, expected)
end

@testset "ast2smt - NormalizedQuery" begin
    
    # input x1, x2
    # output x3
    @satvariable(x[1:3], Real)

    input_bounds = [[-5.0, 5.0], [-5.0, 5.0]]
    output_bounds = [[-10.0, 10.0]]

    pwl_bounds = [[-3.0, 3.0], [-3.0, 3.0]]

    # Lineare Constraints für Input/Output
    lc_input = LinearConstraint([1//1, 1//1], 12//1, true)  # Input constraint
    lc_output = LinearConstraint([1], 20//1, false)  # Output constraint

    # SemiLinearConstraint für Input
    term_var_in = Variable("x2", nothing, 2)
    semilinears_in = Dict{ApproxQuery,Rational{BigInt}}(ApproxQuery(Upper, term_var_in) => 1//2)
    coeffs_in = Rational{BigInt}.([1//1])
    slc_in = SemiLinearConstraint(semilinears_in, coeffs_in, Rational{BigInt}(4,1), false)
    
    # SemiLinearConstraint für Output
    term_var_mixed = Variable("x3", nothing, 3)
    semilinears_mixed = Dict{ApproxQuery,Rational{BigInt}}(ApproxQuery(Upper, term_var_mixed) => 3//4)
    coeffs_mixed = Rational{BigInt}.([2//1])
    slc_mixed = SemiLinearConstraint(semilinears_mixed, coeffs_mixed, Rational{BigInt}(15,1), true)

    
    input_constraints = PwlConjunction(pwl_bounds, [lc_input], [slc_in])
    mixed_constraints = [PwlConjunction(pwl_bounds, [lc_output], [slc_mixed]),
                            PwlConjunction(pwl_bounds, [lc_output], [slc_mixed])]
    
    # Konstruktion der NormalizedQuery
    nq = NormalizedQuery(input_bounds, output_bounds, input_constraints, mixed_constraints, Dict{Term, Vector{BoundType}}())

    expr = ast2smt(nq, x, [])
    expected = (  
        (-5.0 ≤ x[1]) ∧ (x[1] ≤ 5.0) ∧
        (-5.0 ≤ x[2]) ∧ (x[2] ≤ 5.0) ∧
        (x[1] + x[2] ≤ 12.0) ∧
        (1.0 * x[1] + 0.5 * x[2] < 4.0) ∧
        (-10.0 ≤ x[3]) ∧ (x[3] ≤ 10.0) ∧
        (
            ((x[3] < 20.0) ∧ (2.0 * x[3] + 0.75 * x[3] ≤ 15.0)) ∨
            ((x[3] < 20.0) ∧ (2.0 * x[3] + 0.75 * x[3] ≤ 15.0))
        ) 
        )
    @test isequal(expr, expected)
end












