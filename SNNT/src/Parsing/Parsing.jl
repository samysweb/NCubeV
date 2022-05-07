mutable struct TokenManager
	tokens
	TokenManager(tokens::Tokenize.Lexers.Lexer) = new(Iterators.Stateful(tokens))
end

struct SyntaxParsingException <: Exception
	message
end

# TODO(steuber): Upon initialization the first letter of tokenizer is always ' ' (i.e. a whitespace)
# This means that currently our first token *must* be a whitespace or it is accidentally skipped
function peek_token(tokenmanager :: TokenManager)
	#@debug "Peeking char"
	found_token = false
	next_token=nothing
	while !found_token
		next_token = peek(tokenmanager.tokens)
		if Tokens.kind(next_token) == Tokens.WHITESPACE
			popfirst!(tokenmanager.tokens)
			#@debug "Skipping whitespace", next_char
			#skipped = popfirst!(tokenmanager.tokens)
			#@debug "Skipped", skipped
		else
			found_token = true
		end
	end
	#@debug "Found ", next_char
	return next_token
end

function next(tokenmanager :: TokenManager)
	found_token = false
	current_token = nothing
	while !found_token
		current_token = popfirst!(tokenmanager.tokens)
		if Tokens.kind(current_token) != Tokens.WHITESPACE
			found_token = true
		#else
		#	@debug "Skipping whitespace", current_token
		end
	end
	@debug "Consuming ", current_token
	return current_token
end

function parse_constraint(filename :: String)
	open(filename, "r") do file_io
		tokens = TokenManager(tokenize(file_io))
		result = parse_composite(tokens)
		current_token = next(tokens)
		if Tokens.kind(current_token) == Tokens.ENDMARKER
			return result
		else
			throw_syntax_error("Expected end of file got "*untokenize(current_token),current_token)
		end
	end;
end

function parse_composite(tokenmanager :: TokenManager)
	@debug "Parsing composite"
	or_result = parse_or_composite(tokenmanager)
	result = parse_implies_list(tokenmanager, or_result)
	return result
end

function parse_implies_list(tokenmanager :: TokenManager, or_result :: Formula)
	@debug "Parsing implies list"
	if Tokens.exactkind(peek_token(tokenmanager)) == Tokens.ANON_FUNC
		next(tokenmanager)
		next_element = parse_composite(tokenmanager)
		overall_result = CompositeFormula(AST.Implies, Formula[or_result, next_element])
		return parse_implies_list(tokenmanager, overall_result)
	else
		return or_result
	end
end

function parse_or_composite(tokenmanager :: TokenManager)
	@debug "Parsing or composite"
	and_result = parse_and_composite(tokenmanager)
	return parse_or_list(tokenmanager, and_result)
end

function parse_or_list(tokenmanager :: TokenManager, result :: Formula)
	@debug "Parsing or list"
	resulting_or = Formula[]
	push!(resulting_or, result)
	while Tokens.exactkind(peek_token(tokenmanager)) == Tokens.OR
		next(tokenmanager)
		push!(resulting_or, parse_and_composite(tokenmanager))
	end
	if length(resulting_or) == 1
		return result
	else
		return CompositeFormula(AST.Or, resulting_or)
	end
end

function parse_and_composite(tokenmanager :: TokenManager)
	@debug "Parsing and composite"
	atom_result = parse_elementary(tokenmanager)
	return parse_and_list(tokenmanager, atom_result)
end

function parse_and_list(tokenmanager :: TokenManager, result :: Formula)
	@debug "Parsing and list"
	resulting_and = Formula[]
	push!(resulting_and, result)
	while Tokens.exactkind(peek_token(tokenmanager)) == Tokens.AND
		next(tokenmanager)
		next_element = parse_elementary(tokenmanager)
		push!(resulting_and, next_element)
	end
	if length(resulting_and) == 1
		return result
	else
		return CompositeFormula(AST.And, resulting_and)
	end
end

function parse_elementary(tokenmanager :: TokenManager)
	@debug "Parsing elementary"
	next_token = peek_token(tokenmanager)
	@debug "Next char is ", next_token
	if Tokens.exactkind(next_token) == Tokens.LPAREN
		@debug "Parsing bracket expression (start)"
		next(tokenmanager)
		result = parse_composite(tokenmanager)
		current_token = next(tokenmanager)
		if Tokens.kind(current_token) != Tokens.RPAREN
			throw_syntax_error("Expected ')'",Tokens.startpos(current_token))
		end
		@debug "Parsing bracket expression (end)"
		return result
	elseif Tokens.exactkind(next_token) == Tokens.NOT
		next(tokenmanager)
		result = parse_elementary(tokenmanager)
		return CompositeFormula(AST.Not, Formula[result])
	else
		return parse_atom(tokenmanager)
	end
end

function parse_atom(tokenmanager :: TokenManager)
	@debug "Parsing atom"
	term1 = parse_term(tokenmanager)
	current_token = next(tokenmanager)
	operator :: Union{Comparator,Nothing} = nothing
	if Tokens.kind(current_token) == Tokens.OP
		if Tokens.exactkind(current_token) == Tokens.GREATER
			operator = AST.Greater
		elseif Tokens.exactkind(current_token) == Tokens.GREATER_EQ
			operator = AST.GreaterEq
		elseif Tokens.exactkind(current_token) == Tokens.LESS
			operator = AST.Less
		elseif Tokens.exactkind(current_token) == Tokens.LESS_EQ
			operator = AST.LessEq
		elseif Tokens.exactkind(current_token) == Tokens.EQ
			operator = AST.Eq
		elseif Tokens.exactkind(current_token) == Tokens.NOT_EQ
			operator = AST.Neq
		else
			throw_syntax_error("Expected comparison operator",Tokens.startpos(current_token))
		end
	else
		throw_syntax_error("Expected comparison operator",Tokens.startpos(current_token))
	end
	term2 = parse_term(tokenmanager)
	return Atom(operator, term1, term2)
end

function parse_term(tokenmanager :: TokenManager)
	@debug "Parsing term"
	multiply_result = parse_multiply_composite(tokenmanager)
	return parse_term_list(tokenmanager, multiply_result)
end

function parse_term_list(tokenmanager :: TokenManager, result :: Term)
	@debug "Parsing term list"
	if Tokens.exactkind(peek_token(tokenmanager)) == Tokens.PLUS
		next(tokenmanager)
		next_element = parse_multiply_composite(tokenmanager)
		overall_result = CompositeTerm(AST.Add, Term[result, next_element])
		return parse_term_list(tokenmanager, overall_result)
	elseif Tokens.exactkind(peek_token(tokenmanager)) == Tokens.MINUS
		next(tokenmanager)
		next_element = parse_multiply_composite(tokenmanager)
		overall_result = CompositeTerm(AST.Sub, Term[result, next_element])
		return parse_term_list(tokenmanager, overall_result)
	else
		return result
	end
end

function parse_multiply_composite(tokenmanager :: TokenManager)
	@debug "Parsing multiply composite"
	result = parse_power_composite(tokenmanager)
	return parse_multiply_list(tokenmanager, result)
end

function parse_multiply_list(tokenmanager :: TokenManager, result :: Term)
	@debug "Parsing multiply list"
	if Tokens.exactkind(peek_token(tokenmanager)) == Tokens.STAR
		next(tokenmanager)
		next_element = parse_power_composite(tokenmanager)
		overall_result = CompositeTerm(AST.Mul, Term[result, next_element])
		return parse_multiply_list(tokenmanager, overall_result)
	elseif Tokens.exactkind(peek_token(tokenmanager)) == Tokens.FWD_SLASH
		next(tokenmanager)
		next_element = parse_power_composite(tokenmanager)
		overall_result = CompositeTerm(AST.Div, Term[result, next_element])
		return parse_multiply_list(tokenmanager, overall_result)
	else
		return result
	end
end

function parse_power_composite(tokenmanager :: TokenManager)
	@debug "Parsing power composite"
	result = parse_factor(tokenmanager)
	return parse_power_list(tokenmanager, result)
end

function parse_power_list(tokenmanager :: TokenManager, result :: Term)
	@debug "Parsing power list"
	if Tokens.exactkind(peek_token(tokenmanager)) == Tokens.CIRCUMFLEX_ACCENT
		next(tokenmanager)
		exponent = parse_factor(tokenmanager)
		return parse_power_list(tokenmanager, CompositeTerm(AST.Pow, Term[result, exponent]))
	else
		return result
	end
end

function parse_factor(tokenmanager :: TokenManager)
	@debug "Parsing factor"
	current_token = peek_token(tokenmanager)
	if Tokens.kind(current_token) == Tokens.LPAREN
		@debug "Parsing bracket expression (start)"
		next(tokenmanager)
		result = parse_term(tokenmanager)
		current_token = next(tokenmanager)
		if Tokens.kind(current_token) != Tokens.RPAREN
			throw_syntax_error("Expected ')'",Tokens.startpos(current_token))
		end
		@debug "Parsing bracket expression (end)"
		return result
	elseif Tokens.exactkind(current_token) == Tokens.MINUS
		@debug "Parsing unary minus"
		next(tokenmanager)
		return CompositeTerm(AST.Neg, [parse_factor(tokenmanager)])
	elseif Tokens.kind(current_token) == Tokens.INTEGER || Tokens.kind(current_token) == Tokens.FLOAT
		@debug "Parsing number"
		current_token = next(tokenmanager)
		#TODO(steuber): FLOAT INCORRECTNESS
		return TermNumber(parse(BigFloat, untokenize(current_token)))
	elseif Tokens.kind(current_token) == Tokens.IDENTIFIER
		@debug "Parsing variable"
		current_token = next(tokenmanager)
		return Variable(untokenize(current_token))
	else
		throw_syntax_error("Expected factor got "*untokenize(current_token),Tokens.startpos(current_token))
	end
end


function throw_syntax_error(message :: String, position)
	throw(SyntaxParsingException(message*string(position)))
end