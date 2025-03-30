module Lexer

using Tokenize
using Mmap

include("Definitions.jl")
include("TokenManager.jl")

TOKENS = Tokenize.Tokens

"""
    get_lexer(f, filename :: String)

Get a lexer for the given file.

## Arguments
- `f`: A function that takes an argument of type `TokenManager`.
- `filename`: The name of the file to be lexed.

## Returns
The method returns the output of the function `f` applied to the `TokenManager`.

## Example
```julia
get_lexer("example.vnnlib") do (token_mgr :: TokenManager)
    # ...
end
```

## Notes
The function `get_lexer` opens the file specified by `filename` and creates a memory-mapped IO buffer.
"""
function get_lexer(f, filename :: String)
    return open(filename) do file_io
        file_io = IOBuffer(Mmap.mmap(file_io))
        lexer = tokenize(file_io)
        return f(TokenManager(lexer))
    end
end

export get_lexer
export TokenManager
export TOKENS

export peek_token, next

end # module Lexer