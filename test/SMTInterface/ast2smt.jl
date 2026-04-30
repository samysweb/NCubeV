@testset "ast2smt - TermNumber" begin
    # Loop 1: ± xxx_xxx.xxx_xxx
    for _ in 1:10
        # generate n number with at most 6 digits left and right from the decimal point 
        x = rand([+1,-1])*rand(1:1_000_000_000_000)/1_000_000
        # introduce rounding used in the Z3 implementation
        x̃ = rationalize(Int32, Float32(x))
        # convert to Satisfiability constant
        n = Sat.to_real(x̃)
        additional = []
        expected_expr = Sat.to_real(n)
        expr = ast2smt(TermNumber(n), [], [], Dict())
        test_expr = (expr == n)
        isa(test_expr, Bool) && (test_expr = Sat.__wrap_const(test_expr)) 
		!isempty(additional) && (test_expr = test_expr ∧ Sat.and(additional...)) 
        @test (sat!(test_expr) == :SAT)
    end
    #=
    # Loop 2: ± xxx_xxy_yyy_yyy.0
    for _ in 1:10
        n = rand([+1,-1])*rand(10^7:10^11)
        additional = []
        expr = ast2smt(TermNumber(n), [], additional, Dict())
        test_expr = (expr/100_000 == Sat.to_real(n/100_000))
        !isempty(additional) && (test_expr = test_expr ∧ Sat.and(additional...)) 
        @test (sat!(test_expr) == :SAT)
    end
    # Loop 3: ± 0.yyy_yyy_yxx_xxx
    for _ in 1:10
        n = rand([+1,-1])*rand(10.0^-8:10.0^-7)
        additional = []
        expr = ast2smt(TermNumber(n), [], additional, Dict())
        test_expr = (expr*1_000_000 == Sat.to_real(n*1_000_000))
        !isempty(additional) && (test_expr = test_expr ∧ Sat.and(additional...)) 
        @show test_expr
        @test (sat!(test_expr) == :SAT)
    end
    =#
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

    ops = [Less, LessEq, Greater, GreaterEq]
    fs = [
        (e1, e2) -> e1 < e2,
        (e1, e2) -> e1 ≤ e2,
        (e1, e2) -> e1 > e2,
        (e1, e2) -> e1 ≥ e2
    ]

    # testing: (a < b), (a ≤ b), (a > b), (a ≥ b)
    for _ in 1:10
        # generate numbers with at most 6 digits left and right from the decimal point 
        a = rand([+1,-1])*rand(1:1_000_000_000_000)/1_000_000
        b = rand([+1,-1])*rand(1:1_000_000_000_000)/1_000_000
        
        for (op, f) in zip(ops, fs)
            additional = []
            atom_expr = ast2smt(Atom(op, a, b), [], additional, Dict())
            test_expr = (atom_expr == f(Sat.to_real(a), Sat.to_real(b)))
            isa(test_expr, Bool) && (test_expr = Sat.__wrap_const(test_expr)) 
            !isempty(additional) && (test_expr = test_expr ∧ Sat.and(additional...)) 
            @test (sat!(test_expr) == :SAT)
        end 
    end

    #=
        # a = b
    additional = []
    atom_expr = ast2smt(Atom(Eq, a, b), [], additional, Dict())
    test_expr = (atom_expr == (Sat.to_real(a) == Sat.to_real(b)))
    isa(test_expr, Bool) && (test_expr = Sat.__wrap_const(test_expr)) 
    !isempty(additional) && (test_expr = test_expr ∧ Sat.and(additional...)) 
    @test (sat!(test_expr) == :SAT)

    # a ≠ b
    additional = []
    atom_expr = ast2smt(Atom(Neq, a, b), [], additional, Dict())
    test_expr = (atom_expr == (distinct(Sat.to_real(a), Sat.to_real(b))))
    isa(test_expr, Bool) && (test_expr = Sat.__wrap_const(test_expr))  
    !isempty(additional) && (test_expr = test_expr ∧ Sat.and(additional...)) 
    @test (sat!(test_expr) == :SAT)
    =#
end

@testset "ast2smt — CompositeTerm" begin

    ops = [Add, Sub, Mul, Div]
    fs = [
        (e1, e2) -> e1 + e2,
        (e1, e2) -> e1 - e2,
        (e1, e2) -> e1 * e2,
        (e1, e2) -> e1 / e2,
    ]

    for _ in 1:10
        # generate numbers of thr form  ±xxx.xxx
        a = rand([+1,-1])*rand(1:1_000_000_000_000)/1_000_000
        b = rand([+1,-1])*rand(1:1_000_000_000_000)/1_000_000
        a_term = TermNumber(a)
        b_term = TermNumber(b)
        a_expr = ast2smt(a_term, [], [], Dict())
        b_expr = ast2smt(b_term, [], [], Dict())

        # testing: (a + b), (a - b), (a * b), (a / b)
        for (op, f) in zip(ops, fs)
            additional = []
            atom_expr = ast2smt(CompositeTerm(op, [a_term, b_term]), [], additional, Dict())
            test_expr = (atom_expr == f(a_expr, b_expr))
            isa(test_expr, Bool) && (test_expr = Sat.__wrap_const(test_expr)) 
            !isempty(additional) && (test_expr = test_expr ∧ Sat.and(additional...)) 
            @test (sat!(test_expr) == :SAT)
        end
        
        # testing -a
        additional = []
        atom_expr = ast2smt(CompositeTerm(Neg, [a_term]), [], additional, Dict())
        test_expr = (atom_expr == (-a_expr))
        isa(test_expr, Bool) && (test_expr = Sat.__wrap_const(test_expr)) 
		!isempty(additional) && (test_expr = test_expr ∧ Sat.and(additional...)) 
        @test (sat!(test_expr) == :SAT)
    end
end

@testset "ast2smt — CompositeFormula" begin
    @satvariable(x[1:3], Real)
    v1 = Variable("x1", nothing, 1)
    v2 = Variable("x2", nothing, 2)
    v3 = Variable("x3", nothing, 3)
    a1 = Atom(Eq, v1, v2)
    a2 = Atom(Eq, v2, v3)
    a3 = Atom(Eq, v3, v1)
    a1_expr = ast2smt(a1, x, [], Dict())
    a2_expr = ast2smt(a2, x, [], Dict()) 
    a3_expr = ast2smt(a3, x, [], Dict()) 
    ops = [Not, And, Or, Implies, ITE]
    atoms = [
        [a1], 
        [a1, a2], 
        [a1, a2], 
        [a1, a2], 
        [a1, a2, a3]
    ]
    fs = [
        (e1, e2, e3) -> ¬e1
        (e1, e2, e3) -> e1 ∧ e2
        (e1, e2, e3) -> e1 ∨ e2
        (e1, e2, e3) -> e1 ⟹ e2
        (e1, e2, e3) -> ite(e1, e2, e3)
    ]

    for (op, atom, f) in zip(ops, atoms, fs)
        formula = CompositeFormula(op, atom)
        expr = ast2smt(formula, x, [], Dict())
        expected_expr = f(a1_expr, a2_expr, a3_expr)
        @test isequal(expr, expected_expr)
    end
end


# negative values dont work with isequal
@testset "ast2smt — LinearConstraint" begin
    @satvariable(x[1:2], Real)
    
    lc = LinearConstraint([1, 2], 3, true)  # equality=true → ≤
    expr = ast2smt(lc, x, [], Dict())
    expected_expr = 1 * x[1] + 2 * x[2] ≤ 3
    @test isequal(expr, expected_expr)

    lceq = LinearConstraint([1, 4], 7, false)  # equality=false → <
    expr = ast2smt(lceq, x, [], Dict())
    expected_expr = 1 * x[1] + 4 * x[2] < 7
    @test isequal(expr, expected_expr)
end

@testset "ast2smt — LinearTerm" begin
    @satvariable(x[1:2], Real)

    lt = LinearTerm([1, 2], 3)
    expr = ast2smt(lt, x, [], Dict())
    expected_expr = 1.0 * x[1] + 2.0 * x[2] + 3.0
    @test isequal(expr, expected_expr)
end


@testset "ast2smt - SemiLinearConstraint" begin
    @satvariable(x[1:3], Real)

    coeffs = Rational{BigInt}.([1, 2, 3])
    approx_term = Variable("x2", nothing, 2)   # irgendein gültiger Term
    q = ApproxQuery(Upper, approx_term)
    semilinears =  Dict{ApproxQuery,Rational{BigInt}}(q => 10)
    
    slc = SemiLinearConstraint(semilinears, coeffs, Rational{BigInt}(4,1), true)

    expr = ast2smt(slc, x, [])
    expected = (0.0 +
                1.0 * x[1] +
                2.0 * x[2] +
                3.0 * x[3] +
                10.0 * x[2]) ≤ 4.0

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
    # testing whether they can be different
    test_expr = expr ≠ expected
    @test (sat!(test_expr) == :UNSAT)
end

@testset "ast2smt - smt_pow" begin
    @satvariable(x, Real)
    v = Variable("x", nothing, 1)

    # x⁰ = 1
    n = TermNumber(0)
    t = CompositeTerm(Pow, [v, n])
    expr = ast2smt(t, [x], [], Dict())
    @test isequal(expr, 1.0)
    
    # x¹ = x
    n = TermNumber(1)
    t = CompositeTerm(Pow, [v, n])
    expr = ast2smt(t, [x], [], Dict())
    @test isequal(expr, x)

    # x³ = x * x * x
    n = TermNumber(3)
    t = CompositeTerm(Pow, [v, n])
    expr = ast2smt(t, [x], [], Dict())
    @test isequal(expr, x * x * x)

    # x⁻² = 1 / (x * x)
    n = TermNumber(-2)
    t = CompositeTerm(Pow, [v, n])
    expr = ast2smt(t, [x], [], Dict())
    @test isequal(expr, 1.0 / (x * x))

    # non-integer exponent should throw an error
    n = TermNumber(1//2)
    t = CompositeTerm(Pow, [v, n])
    @test_throws AssertionError ast2smt(t, [x], [], Dict())
    
    # 2³ = 8
    a = TermNumber(2)
    n = TermNumber(3)
    t = CompositeTerm(Pow, [a, n])
    expr = ast2smt(t, [], [], Dict())
    expected_expr = ast2smt(TermNumber(8), [], [], Dict())
    test_expr = (expr == expected_expr)
    isa(test_expr, Bool) && (test_expr = Sat.__wrap_const(test_expr))
    @test (sat!(test_expr) == :SAT)
    #@test isequal(expr, expected_expr)

    # 2⁻³ = 8
    a = TermNumber(2.0)
    n = TermNumber(-3//1)
    t = CompositeTerm(Pow, [a, n])
    additional = []
    expr = ast2smt(t, [], [], Dict())
    expected_expr = ast2smt(TermNumber(1//8), [], [], Dict())
    test_expr = (expr == expected_expr)
    isa(test_expr, Bool) && (test_expr = Sat.__wrap_const(test_expr))
    !isempty(additional) && (test_expr = test_expr ∧ Sat.and(additional...)) 
    @test (sat!(test_expr) == :SAT)
    #isequal(expr, expected_expr)
end







