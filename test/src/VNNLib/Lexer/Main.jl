using NCubeV.VNNLib.Lexer

function test_next_token_is(token_mgr, expected_token)
    token = peek_token(token_mgr)
    @test TOKENS.kind(token) == expected_token
    token = next(token_mgr)
    @test TOKENS.kind(token) == expected_token
    return token
end

@testset "Lexer" begin
    get_lexer(joinpath(RESOURCE_DIR,"VNNLib/Lexer/test1.vnnlib")) do (token_mgr)
        @test !isnothing(token_mgr)
        @test isa(token_mgr, TokenManager)

        test_next_token_is(token_mgr, TOKENS.LPAREN)
        id = test_next_token_is(token_mgr, TOKENS.IDENTIFIER)
        @test TOKENS.untokenize(id) == "and"
        test_next_token_is(token_mgr, TOKENS.LPAREN)
        id = test_next_token_is(token_mgr, TOKENS.IDENTIFIER)
        @test TOKENS.untokenize(id) == "or"
        test_next_token_is(token_mgr, TOKENS.LPAREN)
        id = test_next_token_is(token_mgr, TOKENS.OP)
        @test TOKENS.untokenize(id) == "<="

        test_next_token_is(token_mgr, TOKENS.LPAREN)
        id = test_next_token_is(token_mgr, TOKENS.OP)
        @test TOKENS.untokenize(id) == "+"

        id = test_next_token_is(token_mgr, TOKENS.IDENTIFIER)
        @test TOKENS.untokenize(id) == "X_1"

        id = test_next_token_is(token_mgr, TOKENS.IDENTIFIER)
        @test TOKENS.untokenize(id) == "X_2"

        test_next_token_is(token_mgr, TOKENS.RPAREN)

        test_next_token_is(token_mgr, TOKENS.LPAREN)

        id = test_next_token_is(token_mgr, TOKENS.OP)
        @test TOKENS.untokenize(id) == "+"

        id = test_next_token_is(token_mgr, TOKENS.IDENTIFIER)
        @test TOKENS.untokenize(id) == "X_3"

        id = test_next_token_is(token_mgr, TOKENS.IDENTIFIER)
        @test TOKENS.untokenize(id) == "X_4"
        test_next_token_is(token_mgr, TOKENS.RPAREN)
        test_next_token_is(token_mgr, TOKENS.RPAREN)
        
        test_next_token_is(token_mgr, TOKENS.LPAREN)
        
        id = test_next_token_is(token_mgr, TOKENS.OP)
        @test TOKENS.untokenize(id) == "="

        id = test_next_token_is(token_mgr, TOKENS.IDENTIFIER)
        @test TOKENS.untokenize(id) == "X_1"
        id = test_next_token_is(token_mgr, TOKENS.IDENTIFIER)
        @test TOKENS.untokenize(id) == "X_2"

        test_next_token_is(token_mgr, TOKENS.RPAREN)
        test_next_token_is(token_mgr, TOKENS.RPAREN)

        test_next_token_is(token_mgr, TOKENS.LPAREN)
        id = test_next_token_is(token_mgr, TOKENS.OP)
        @test TOKENS.untokenize(id) == ">="
        id = test_next_token_is(token_mgr, TOKENS.IDENTIFIER)
        @test TOKENS.untokenize(id) == "X_1"

        id = test_next_token_is(token_mgr, TOKENS.IDENTIFIER)
        @test TOKENS.untokenize(id) == "X_2"

        test_next_token_is(token_mgr, TOKENS.RPAREN)
        test_next_token_is(token_mgr, TOKENS.RPAREN)
    end
end