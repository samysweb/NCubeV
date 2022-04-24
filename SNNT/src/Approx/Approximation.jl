# For variable with index i=1
#x  Find all linear min/max expressions only involving variable i
#   For each such expression
#     Find splitting point of expression along i
#     Introduce new splitting point in bounds array at sorted position k
#     Duplicate term at position k-1 and insert at position k
#     For all terms j < k: Substitute with term1
#y     For all terms j >= k: Substitute with term2
# N = length of term vector

# For variables with index i=2...n
#   Duplicate terms array (deep copy)
#   Find all linear min/max expressions only involving variable i
#   For each such expression
#     Find splitting point of expression along i
#     Introduce new splitting point in bounds array at sorted position k
#     For all h=0... with h*N < length of term vector
#       Duplicate term at position h*N+k-1 and insert at position h*N+k
#       For all terms h*N<=j<h*N+k: Substitute with term1
#       For all terms h*N+k<=j<h*N+k+1: Substitute with term2
#       N++

# For each set of intervals I_0, I_1, ..., I_n
# Overapproximate the corresponding term and safe it as array of coefficients