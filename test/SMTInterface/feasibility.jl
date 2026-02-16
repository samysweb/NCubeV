
@testset "lin_feasible tests" begin
    @satvariable(x[1:2], Real)
    conflicts = []
    # -1 ≤ x₁ ≤ 1
    lb1 = LinearConstraint([-1//1], 1//1, true)
    ub1 = LinearConstraint([1//1], 1//1, true)
    
    # 1 ≤ x₂ ≤ 2
    lb2 = LinearConstraint([0//1, -1//1], -1//1, true)
    ub2 = LinearConstraint([0//1, 1//1], 2//1, true)
    
    # x₁ + x₂ = 0
    lc1 = LinearConstraint([1//1, 1//1], 0//1, true)
    lc2 = LinearConstraint([-1//1, -1//1], 0//1, true)

    constraints = [lb1, ub1, lb2, ub2, lc1, lc2]

    @test lin_feasible(constraints, [], x, conflicts)
    @test length(conflicts) == 0

    # 0 ≤ x₁
    lc3 = LinearConstraint([-1//1], -0//1, true)
    push!(constraints, lc3)

    @test !lin_feasible(constraints, [], x, conflicts)
    @test length(conflicts) == length(constraints)
end

@testset "nl_feasible tests" begin
    @satvariable(x[1:2], Real)
    conflicts = []

    n = TermNumber(2)
    v1 = Variable("x1", nothing, 2)
    v2 = Variable("x2", nothing, 2)
    sq1 = CompositeTerm(Pow, [v1, n])
    sq2 = CompositeTerm(Pow, [v2, n])
    sum =  CompositeTerm(Add, [sq1, sq2])

    # 0 ≥ x₁² + x₂²
    atom = Atom(GreaterEq, TermNumber(0), sum)
    constraints = Formula[atom]

    @test nl_feasible(constraints, nothing, x, conflicts)
    @test length(conflicts) == 0

    # 0 < x₁
    push!(constraints, Atom(Greater, v1, TermNumber(0)))

    @test !nl_feasible(constraints, nothing, x, conflicts)
    @test length(conflicts) == length(constraints)
end