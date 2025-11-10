#!/usr/bin/env python3

# Copyright 2020 The Johns Hopkins University Applied Physics Laboratory LLC
# All rights reserved.
#
# Licensed under the 3-Clause BSD License (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# https://opensource.org/licenses/BSD-3-Clause
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

import sys

import torch
import torch.nn as nn
import lantern
import z3
import numpy as np

def modelplex(rPos, rVel, rAccpost):
    A=100.0
    B=100.0
    T=0.1
    return (
            (0<= rPos and rPos <= 100 and -200 <= rVel and rVel <= 200 and -A-0.001 <= rAccpost and rAccpost <= A+0.001) and \
            (rPos > 0 and rPos >= rVel**2/(2*A))
        ) and not (
            rAccpost >= A or
            (rAccpost >= -B and
            rAccpost  <  A and
            rAccpost != 0 and
            (
            ((-rVel/rAccpost  > T or -rVel/rAccpost  <  0) and
            rPos + rVel * T + rAccpost * T**2 / 2 > (rVel + rAccpost * T)**2 / (2 * A)) or
            (rPos + rVel * T + rAccpost * T**2 / 2 > (rVel + rAccpost * T)**2 / (2 * A) and
            rPos*rAccpost - rVel**2 + rVel**2 / (2) > 0)
            ) 
            ) or
            rPos + rVel * T > rVel**2 / (2 * A)
        )

def ubound_pow2(x, bounds):
    return max(bounds[x][1]**2, bounds[x][0]**2)

def lbound_pow2(x, bounds):
    if bounds[x][0] <= 0 and bounds[x][1] >= 0:
        return 0
    else:
        return min(bounds[x][1]**2, bounds[x][0]**2)
    
def ubound_f2(v, a, T, bounds):
    # upper bound for (v + a*T)**2 = v**2 + 2*a*T*v + a**2*T**2
    return max(
        bounds[v][0]**2 + 2*bounds[a][0]*T*bounds[v][0] + bounds[a][0]**2*T**2,
        bounds[v][1]**2 + 2*bounds[a][1]*T*bounds[v][1] + bounds[a][1]**2*T**2,
        bounds[v][0]**2 + 2*bounds[a][1]*T*bounds[v][0] + bounds[a][1]**2*T**2,
        bounds[v][1]**2 + 2*bounds[a][0]*T*bounds[v][1] + bounds[a][0]**2*T**2
    )

def lbound_f3(p,a, bounds):
    if (bounds[p][0] <= 0 and bounds[p][1] >= 0) or (bounds[a][0] <= 0 and bounds[a][1] >= 0):
        return min(
            bounds[p][0]*bounds[a][0],
            bounds[p][1]*bounds[a][1],
            bounds[p][0]*bounds[a][1],
            bounds[p][1]*bounds[a][0],
            0.0
        )
    else:
        # upper bound for p*a
        return min(
            bounds[p][0]*bounds[a][0],
            bounds[p][1]*bounds[a][1],
            bounds[p][0]*bounds[a][1],
            bounds[p][1]*bounds[a][0]
        )

def get_constraints(rPos, rVel, rAccpost, bounds):
    A=100.0
    B=100.0
    T=0.1
    
    return z3.And(
        z3.And(rPos >= 0, rPos - 1/(2*A)*lbound_pow2(rVel, bounds) >= 0),
        z3.Not(
            z3.Or(
                rAccpost >= A,
                z3.And(
                    rAccpost >= -B,
                    rAccpost < A,
                    rAccpost != 0,
                    z3.Or(
                        z3.And(
                            z3.Or(-rVel > T*rAccpost, -rVel < 0.0),
                            rPos + T*rVel + T**2*rAccpost/2.0 - 1/(2*A)*ubound_f2(rVel, rAccpost, T, bounds) >0.0
                        ),
                        z3.And(
                            rPos + T*rVel + T**2*rAccpost/2.0 - 1/(2*A)*ubound_f2(rVel, rAccpost, T, bounds) >0.0,
                            z3.BoolVal(lbound_f3(rVel, rAccpost, bounds) - 0.5 * ubound_pow2(rVel, bounds) > 0.0)
                        )
                    )
                ),
                    rPos + T*rVel - 1/(2*A)*ubound_pow2(rVel, bounds) > 0.0
            )
        )
    )


def main():
    """Lantern demo"""

    # Initialize a PyTorch network
    # Lantern currently supports: Linear, ReLU, Hardtanh, Dropout, Identity
    net = nn.Sequential(
               nn.Linear(2, 5),
               nn.ReLU(),
               nn.Linear(5, 1),
               nn.ReLU())
    net = torch.load('../NCubeV/test/networks/acc-2000000-64-64-64-64.torch')

    print("A PyTorch network:")
    print(net)
    print()

    # Normally, we would train this network to compute some function. However,
    # for this demo, we'll just use the initialized weights.
    #print("Network parameters:")
    #print(list(net.parameters()))
    #print()

    # lantern.as_z3(model) returns a triple of z3 constraints, input variables,
    # and output variables that directly correspond to the behavior of the 
    # given PyTorch network. By default, latnern assumes Real-sorted variables.
    constraints, in_vars, out_vars = lantern.as_z3(net)

    # print("Z3 constraints, input variables, output variables (Real-sorted):")
    # print(constraints)
    # print(in_vars)
    # print(out_vars)
    # print()

    # The 'payoff' is that we can prove theorems about our network with z3.
    # Trivially, we can ask for a satisfying assignment of variables
    print("A satisfying assignment to the variables in this network:")
    #z3.solve(constraints)
    s = z3.Tactic("qflra").solver()
    #z3.Solver("QF_LRA")
    s.add(constraints)
    #z3.solve_using(z3.SolverFor("QF_LRA"), *constraints)
    #print()

    step =  10.0
    print("Step size: ", step)
    rPos = in_vars[0]
    rVel = in_vars[1]
    rAccpost = out_vars[0]

    i=0
    print("Trying to check constraints...")
    for rPos_start in np.arange(0.1,100.0,step):
        for rVel_start in np.arange(-100.0,100.0,step):
            for rAccpost_start in np.arange(-100.0,100.0,step):
                sys.stdout.flush()
                bounds = {
                    rPos: (rPos_start, rPos_start + step),
                    rVel: (rVel_start, rVel_start + step),
                    rAccpost: (rAccpost_start, rAccpost_start + step)
                }
                s.push()
                for k in bounds.keys():
                    s.add(k >= bounds[k][0], k <= bounds[k][1])
                s.add(get_constraints(rPos, rVel, rAccpost, bounds))
                if s.check() == z3.sat:
                    print(i, " SAT")
                    m = s.model()
                    p = m[rPos].as_fraction()
                    print("rPos: ", float(p.numerator)/float(p.denominator))
                    v = m[rVel].as_fraction()
                    print("rVel: ", float(v.numerator)/float(v.denominator))
                    a = m[rAccpost].as_fraction()
                    print("rAccpost: ", float(a.numerator)/float(a.denominator))
                    print("Concrete: ", modelplex(p, v, a))
                elif s.check() == z3.unsat:
                    #print(i, " UNSAT")
                    pass
                else:
                    print(i, " UNKNOWN")
                i+=1
                s.pop()
                if i%100 == 0:
                    print(i, " checked")


if __name__ == "__main__":
    main()
