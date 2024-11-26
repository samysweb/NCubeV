using SNNT.VerifierInterface

function test_star_filter_concrete()
    smt_context(3) do (ctx)
        test_star = Star((
            [1.0 0.0; -1.0 0.0; 0.0 1.0; 0.0 -1.0],
            [1.0, 1.0, 1.0, 1.0],
            [0.5 0.5;],
            [1.0],
            Any[0  0.0  2.0; 1 0.0 2.0; 2 0.0 2.0],
            ([0.0, 0.0], [1.0])
        ))
        result = OlnnvResult(
            Unsafe,
            nothing,
            [test_star]
        )
        nl_fml = Atom(Eq, Variable("y",nothing,3), CompositeTerm(Pow, [
            LinearTerm([1//2, 1//2], 1//1),
            TermNumber(2//1)
        ]))
        fml = [(TrueAtom(), nl_fml)]
        filter = get_star_filter(ctx, fml)
        final_result = filter(result)
        @test final_result.status == Unsafe
        @test length(final_result.stars) == 1
        @test final_result.stars[1].certain == true
        @test final_result.stars[1].counter_example[1] == [0.0, 0.0]
        @test final_result.stars[1].counter_example[2] == [1.0]
    end
end

function test_star_filter_not_concrete()
    smt_context(3) do (ctx)
        test_star = Star((
            [1.0 0.0; -1.0 0.0; 0.0 1.0; 0.0 -1.0],
            [1.0, 1.0, 1.0, 1.0],
            [0.5 0.5;],
            [1.0],
            Any[0  0.0  2.0; 1 0.0 2.0; 2 0.0 2.0],
            ([1.0, 1.0], [2.0])
        ))
        result = OlnnvResult(
            Unsafe,
            nothing,
            [test_star]
        )
        nl_fml = Atom(Eq, Variable("y",nothing,3), CompositeTerm(Pow, [
            LinearTerm([1//2, 1//2], 1//1),
            TermNumber(2//1)
        ]))
        fml = [(TrueAtom(), nl_fml)]
        filter = get_star_filter(ctx, fml)
        final_result = filter(result)
        @test final_result.status == Unsafe
        @test length(final_result.stars) == 1
        @test final_result.stars[1].certain == true
        @test final_result.stars[1].counter_example[1] == [0.0, 0.0]
        @test final_result.stars[1].counter_example[2] == [1.0]
    end
end

function test_star_filter_safe()
    smt_context(3) do (ctx)
        test_star = Star((
            [1.0 0.0; -1.0 0.0; 0.0 1.0; 0.0 -1.0],
            [1.0, 1.0, 1.0, 1.0],
            [0.5 0.5;],
            [1.0],
            Any[0  0.1  2.0; 1 0.1 2.0; 2 0.0 2.0],
            ([1.0, 1.0], [2.0])
        ))
        result = OlnnvResult(
            Unsafe,
            nothing,
            [test_star]
        )
        nl_fml = Atom(Eq, Variable("y",nothing,3), CompositeTerm(Pow, [
            LinearTerm([1//2, 1//2], 1//1),
            TermNumber(2//1)
        ]))
        fml = [(TrueAtom(), nl_fml)]
        filter = get_star_filter(ctx, fml)
        final_result = filter(result)
        @test final_result.status == Safe
        @test length(final_result.stars) == 0
    end
end

function test_star_filter()
    Config.SMT_SOLVER = "Z3"
    test_star_filter_concrete()
    test_star_filter_not_concrete()
    test_star_filter_safe()
end

@testset "StarFilter" begin
    test_star_filter()
end