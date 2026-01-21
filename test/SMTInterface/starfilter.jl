@testset "ast2smt - Star" begin

    # input x₁, x₂
    # output x₃, x₄
    @satvariable(x[1:4], Real)

    # define Star
    constraint_matrix = Float32[11.0 12.0; 21.0 22.0]
    constraint_bias   = Float32[1.0, 2.0]
    output_map_matrix = Float32[1.0 2.0; 3.0 4.0]
    output_map_bias   = Float32[5.0, 6.0]
    bounds            = [0 -1 1; 1 -2 2]
    counter_example   = [1.0, 0.0], [0.0, 1.0]
    tuple = constraint_matrix, constraint_bias, output_map_matrix, output_map_bias, bounds, counter_example 

    star = Star(tuple)

    expr = ast2smt(star, x, [], Dict())
    expected_expr = Sat.and(
        11.0*x[1] + 12.0*x[2] ≤ 1.0,
        21.0*x[1] + 22.0*x[2] ≤ 2.0,
        -1.0 ≤ x[1],
        x[1] ≤ 1.0,
        -2.0 ≤ x[2],
        x[2] ≤ 2.0,
        x[3] == 1.0*x[1] + 2.0*x[2] + 5.0,
        x[4] == 3.0*x[1] + 4.0*x[2] + 6.0
    )
    
    #TODO: write a function to canonicalize expressions for equality testing
    #expr = my_expr_simplify(expr)
    #expected_expr = my_expr_simplify(expected_expr)
    #@test isequal(expr, expected_expr)
    @test (sat!(expr == expected_expr) == :SAT)
end


@testset "check_star tests" begin
    # input x₁, x₂
    # output x₃, x₄
    @satvariable(x[1:4], Real)

    # define Star with expr:
    # -1 ≤ x₁ ≤ 1
    # -1 ≤ x₂ ≤ 1,
    # x₃ = x₁
    # x₄ = x₂   
    constraint_matrix = Float32[1.0 0.0; 0.0 1.0]
    constraint_bias   = Float32[1.0, 1.0]
    output_map_matrix = Float32[1.0 0.0; 0.0 1.0]
    output_map_bias   = Float32[0.0, 0.0]
    bounds            = [0 -1 1; 1 -1 1]
    counter_example   = [1.0, 0.0], [0.0, 1.0]
    tuple = constraint_matrix, constraint_bias, output_map_matrix, output_map_bias, bounds, counter_example 
    star = Star(tuple)

    v1, v3 = Variable("x1", nothing, 1), Variable("x3", nothing, 3)

    # unsat: (x₃ < -1) ∧ (true)
    disj₁ = [
        (Atom(Less, v3, TermNumber(-1//1)), TrueAtom())
        ]

    # sat: (x₃ ≤ -1) ∧ (true) 
    disj₂ = [
        (Atom(LessEq, v3, TermNumber(-1//1)), TrueAtom())
        ]
    
    # unsat: (x₃ ≤ -1) ∧ (x₃x₁ < 1)
    disj₃ = [
        (Atom(LessEq, v3, TermNumber(-1//1)), Atom(Less, CompositeTerm(Mul, [v3, v1]), TermNumber(1//1)))
        ]
    
    # sat: (x₃ ≤ -1) ∧ (x₃x₁ ≤ 1)
    disj₄ = [
        (Atom(LessEq, v3, TermNumber(-1//1)), Atom(LessEq, CompositeTerm(Mul, [v3, v1]), TermNumber(1//1)))
        ]

    # unsat: (false ∧ false) ∨ ((x₃ < -1) ∧ true)
    disj₅ = [
        (FalseAtom(), FalseAtom()), 
        (Atom(Less, v3, TermNumber(-1//1)), TrueAtom())
        ]

    # sat: (false ∧ false) ∨ ((x₃ ≤ -1) ∧ true)
    disj₆ = [
        (FalseAtom(), FalseAtom()), 
        (Atom(LessEq, v3, TermNumber(-1//1)), TrueAtom())
    ]

    @test check_star(nothing, x, disj₁, star, Dict())[1] == 0
    @test check_star(nothing, x, disj₂, star, Dict())[1] == 1
    @test check_star(nothing, x, disj₃, star, Dict())[1] == 0
    @test check_star(nothing, x, disj₄, star, Dict())[1] == 1
    @test check_star(nothing, x, disj₅, star, Dict())[1] == 0
    @test check_star(nothing, x, disj₆, star, Dict())[1] == 1
end