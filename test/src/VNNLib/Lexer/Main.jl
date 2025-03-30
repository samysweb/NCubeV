using NCubeV.VNNLib.Lexer

function test_next_token_is(token_mgr, expected_token; peek = true)
    if peek
        token = peek_token(token_mgr)
        @test TOKENS.kind(token) == expected_token
    end
    token = next(token_mgr)
    @test TOKENS.kind(token) == expected_token
    return token
end

function test_token_mgr(token_mgr, peek)
    test_next_token_is(token_mgr, TOKENS.LPAREN;peek=peek)
        id = test_next_token_is(token_mgr, TOKENS.IDENTIFIER;peek=peek)
        @test TOKENS.untokenize(id) == "and"
        test_next_token_is(token_mgr, TOKENS.LPAREN;peek=peek)
        id = test_next_token_is(token_mgr, TOKENS.IDENTIFIER;peek=peek)
        @test TOKENS.untokenize(id) == "or"
        test_next_token_is(token_mgr, TOKENS.LPAREN;peek=peek)
        id = test_next_token_is(token_mgr, TOKENS.OP;peek=peek)
        @test TOKENS.untokenize(id) == "<="

        test_next_token_is(token_mgr, TOKENS.LPAREN;peek=peek)
        id = test_next_token_is(token_mgr, TOKENS.OP;peek=peek)
        @test TOKENS.untokenize(id) == "+"

        id = test_next_token_is(token_mgr, TOKENS.IDENTIFIER;peek=peek)
        @test TOKENS.untokenize(id) == "X_1"

        id = test_next_token_is(token_mgr, TOKENS.IDENTIFIER;peek=peek)
        @test TOKENS.untokenize(id) == "X_2"

        test_next_token_is(token_mgr, TOKENS.RPAREN;peek=peek)

        test_next_token_is(token_mgr, TOKENS.LPAREN;peek=peek)

        id = test_next_token_is(token_mgr, TOKENS.OP;peek=peek)
        @test TOKENS.untokenize(id) == "+"

        id = test_next_token_is(token_mgr, TOKENS.IDENTIFIER;peek=peek)
        @test TOKENS.untokenize(id) == "X_3"

        id = test_next_token_is(token_mgr, TOKENS.IDENTIFIER;peek=peek)
        @test TOKENS.untokenize(id) == "X_4"
        test_next_token_is(token_mgr, TOKENS.RPAREN;peek=peek)
        test_next_token_is(token_mgr, TOKENS.RPAREN;peek=peek)
        
        test_next_token_is(token_mgr, TOKENS.LPAREN;peek=peek)
        
        id = test_next_token_is(token_mgr, TOKENS.OP;peek=peek)
        @test TOKENS.untokenize(id) == "="

        id = test_next_token_is(token_mgr, TOKENS.IDENTIFIER;peek=peek)
        @test TOKENS.untokenize(id) == "X_1"
        id = test_next_token_is(token_mgr, TOKENS.IDENTIFIER;peek=peek)
        @test TOKENS.untokenize(id) == "X_2"

        test_next_token_is(token_mgr, TOKENS.RPAREN;peek=peek)
        test_next_token_is(token_mgr, TOKENS.RPAREN;peek=peek)

        test_next_token_is(token_mgr, TOKENS.LPAREN;peek=peek)
        id = test_next_token_is(token_mgr, TOKENS.OP;peek=peek)
        @test TOKENS.untokenize(id) == ">="
        id = test_next_token_is(token_mgr, TOKENS.IDENTIFIER;peek=peek)
        @test TOKENS.untokenize(id) == "X_1"

        id = test_next_token_is(token_mgr, TOKENS.IDENTIFIER;peek=peek)
        @test TOKENS.untokenize(id) == "X_2"

        test_next_token_is(token_mgr, TOKENS.RPAREN;peek=peek)
        test_next_token_is(token_mgr, TOKENS.RPAREN;peek=peek)

        test_next_token_is(token_mgr, TOKENS.ENDMARKER;peek=peek)
end

@testset "Lexer" begin
    get_lexer(joinpath(RESOURCE_DIR,"VNNLib/Lexer/test1.vnnlib")) do (token_mgr)
        @test !isnothing(token_mgr)
        @test isa(token_mgr, TokenManager)
        test_token_mgr(token_mgr, true)
    end
    get_lexer(joinpath(RESOURCE_DIR,"VNNLib/Lexer/test1.vnnlib")) do (token_mgr)
        @test !isnothing(token_mgr)
        @test isa(token_mgr, TokenManager)
        test_token_mgr(token_mgr, false)
    end
    get_lexer(joinpath(RESOURCE_DIR,"VNNLib/Lexer/test2.vnnlib")) do (token_mgr)
        @test !isnothing(token_mgr)
        @test isa(token_mgr, TokenManager)
        test_next_token_is(token_mgr, TOKENS.ENDMARKER;peek=true)
    end
    get_lexer(joinpath(RESOURCE_DIR,"VNNLib/Lexer/test2.vnnlib")) do (token_mgr)
        @test !isnothing(token_mgr)
        @test isa(token_mgr, TokenManager)
        test_next_token_is(token_mgr, TOKENS.ENDMARKER;peek=false)
    end
end