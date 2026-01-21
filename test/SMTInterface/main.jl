using NCubeV.AST
using NCubeV.SMTInterface
using NCubeV.VerifierInterface
using Satisfiability
Sat = Satisfiability


using Satisfiability

# A mapping from internal .op symbols to the actual functions in Satisfiability.jl
const SMT_OPERATOR_MAP = Dict(
    :and     => Satisfiability.and,
    :or      => Satisfiability.or,
    :not     => Satisfiability.not,
    :implies => Satisfiability.implies,
    :+       => +,
    :add     => +, # Some versions use :add
    :mul     => *,
    :div     => /,
    :leq     => <=,
    :lt      => <,
    :geq     => >=,
    :gt      => >,
    :eq      => ==,
)

"""
    reconstruct_node(op::Symbol, children)

Safe wrapper to call the correct Satisfiability constructor for a given symbol.
"""
function reconstruct_node(op::Symbol, children)
    if haskey(SMT_OPERATOR_MAP, op)
        return SMT_OPERATOR_MAP[op](children...)
    else
        # Fallback for operators that happen to match their function names
        return getfield(Satisfiability, op)(children...)
    end
end


"""
    my_expr_simplify(expr::AbstractExpr)

Recursively traverses the entire tree and flattens all nested AND (∧) and 
Addition (+) nodes, even if they are separated by other types of nodes.
"""
function my_expr_simplify(expr::AbstractExpr)
    # 1. Base Case: If it's a leaf (variable/constant), return it.
    if isempty(expr.children)
        return expr
    end

    # 2. Universal Recursion: Process all children regardless of the current op.
    # This allows the function to "skip over" nodes like <= to find targets deeper down.
    processed_children = [my_expr_simplify(c) for c in expr.children]

    # 3. Handle Associative Flattening for targets (+ and ∧)
    if expr.op == :and || expr.op == :+ || expr.op == :add
        new_children = []
        for c in processed_children
            if c.op == expr.op
                # Dissolve the child of the same type into this node
                append!(new_children, c.children)
            else
                push!(new_children, c)
            end
        end
        
        # --- NEW LOGIC TO FIX METHODERROR ---
        if length(new_children) == 1
            return new_children[1] # and(x) is just x, +(x) is just x
        end
        # ---
        # Return reconstructed target node
        expr.op == :and && return Sat.and(new_children...)
        expr.op == :+ && return +(new_children...)
        expr.op == :add && return +(new_children...)
    end

    # 4. Reconstruction for Non-Target Nodes
    if length(processed_children) == 1 && expr.op in (:and, :or, :+, :*)
        return processed_children[1]
    end

    return reconstruct_node(expr.op, processed_children)
end

@testset "helper functions" begin
    
    @satvariable(x[1:10], Real)
    
    expr = Sat.and(
        Sat.and(
            x[1] ≤ 5,
            Sat.and(
                0 + x[2] + (x[3] + x[4]) ≤ 10,
                (0 + x[5] + x[6]) + x[7] ≤ 15
            )
        ),
        Sat.and(
            x[4] ≤ x[2] + (x[3] + 0 + x[4]),
            x[5] ≤ (x[5] + x[6]) + 0 + x[7]
        )
    )

    flat_expr = my_expr_simplify(expr)
    expected_expr = Sat.and(
        x[1] ≤ 5,
        x[2] + x[3] + x[4] ≤ 10,
        x[5] + x[6] + x[7] ≤ 15,
        x[4] ≤ x[2] + x[3] + x[4],
        x[5] ≤ x[5] + x[6] + x[7]
    )
    @test isequal(flat_expr, expected_expr)
end

include("ast2smt.jl")
include("feasiblity.jl")
include("starfilter.jl")