import z3
import numpy as np

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
        # lower bound for p*a
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


s = z3.Solver()

step =  10.0
rPos = z3.Real('rPos')
rVel = z3.Real('rVel')
rAccpost = z3.Real('rAccpost')

i=0
for rPos_start in np.arange(0.1,100.0,step):
    for rVel_start in np.arange(-100.0,100.0,step):
        for rAccpost_start in np.arange(-100.0,100.0,step):
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
            else:
                print(i, " UNSAT")
            i+=1
            s.pop()