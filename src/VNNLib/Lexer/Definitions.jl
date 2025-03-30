import Base.Iterators.approx_iter_type

Base.Iterators.approx_iter_type(::Type{Tokenize.Lexers.Lexer{IO_t, Tokens.Token}}) where IO_t<:IO = Tuple{Tokens.Token,Bool}

mutable struct TokenManager{IO_t <: IO}
	tokens :: Iterators.Stateful{Tokenize.Lexers.Lexer{IO_t, Tokens.Token},Tuple{Tokens.Token,Bool}}
	function TokenManager(tokens::Tokenize.Lexers.Lexer{IO_t, Tokens.Token}) where IO_t <: IO 
        return new{IO_t}(Iterators.Stateful(tokens))
    end
end