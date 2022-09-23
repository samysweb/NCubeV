
def quantitative_modelplex(x1, x2, c, w, y1post, y2post, T, p, r):
    c1 = c
    c2 = c
    tpost=0.0
    t=0.0
    x1post=x1
    x2post=x2
    z1post=0.0
    z2post=0.0
    z1=0.0
    z2=0.0
    return 0.0-max(
        max(
        
            y1post**2.0 + y2post**2.0 - 1.0,
            min(
            
                min(
                
                    x2 - (-c2 - T * (p + r)),
                    min(
                    
                        c2 + w / (p - r) * c1 + T * (p + r + w) - x2,
                        min(
                        
                            (p - r) / w * (c2 - (x2 - T * (r + p + w))) +
                            c1 -
                            (x1 + T * (p + r)) * (-1.0),
                            (p - r) / w * (c2 - (x2 - T * (r + p + w))) +
                            c1 -
                            -(x1 - T * (p + r)) * (-1.0)
                            
                        )
                        
                    )
                    
                ),
                min(
                
                    max(x2 - -c2,x2 + T * p * y2post - T * w + T * r - -c2),
                    min(
                    
                        max(
                        
                            c2 + w / (p - r) * c1 - x2,
                            c2 + w / (p - r) * c1 -
                            (x2 + T * p * y2post - T * w - T * r)
                            
                        ),
                        min(
                        
                            max(
                            
                                (p - r) / w * (c2 - x2) + c1 - x1 * (-1.0),
                                (p - r) / w *
                                (
                                c2 -
                                (
                                    x2 + T * p * y2post - T * w +
                                    T * r *
                                    (-(p - r) / (w**2.0 + (p - r)**2.0)**(1.0 / 2.0))
                                )
                                ) +
                                c1 -
                                (
                                x1 + T * p * y1post +
                                T * r * (w / (w**2.0 + (p - r)**2.0)**(1.0 / 2.0))
                                ) *
                                (-1.0)
                                
                            ),
                            max(
                            
                                (p - r) / w * (c2 - x2) + c1 - -x1 * (-1.0),
                                (p - r) / w *
                                (
                                c2 -
                                (
                                    x2 + T * p * y2post - T * w +
                                    T * r *
                                    (-(p - r) / (w**2.0 + (p - r)**2.0)**(1.0 / 2.0))
                                )
                                ) +
                                c1 -
                                -(
                                x1 + T * p * y1post +
                                T * r * (-w / (w**2.0 + (p - r)**2.0)**(1.0 / 2.0))
                                ) *
                                (-1.0)
                                
                            )
                            
                        )
                        
                    )
                    
                )
                
            )
            
        ),
        max(
        
            max(tpost - t,t - tpost),
            max(
            
                max(x1post - x1,x1 - x1post),
                max(
                
                    max(x2post - x2,x2 - x2post),
                    max(
                    
                        max(z1post - z1,z1 - z1post),
                        max(z2post - z2,z2 - z2post)
                        
                    )
                    
                )
                
            )
            
        )
        
    )