@testset verbose = true "Parsing Tests" begin
	@test SNNT.Parsing.term_to_string(SNNT.Parsing.parse_constraint("parsing/examples/example0")) == "(a>=b->((a=c|(d=e&c=d))->(a=c&!((d<=e|(e!=f&k=w))))))"
	@test SNNT.Parsing.term_to_string(SNNT.Parsing.parse_constraint("parsing/examples/example1")) == "(((rPos+(rVel*T))>((rVel^2.0)/(2.0*A))&!(0.0<=T)&-cpost=0.0&rAccpost=0.0&rPospost=rPos)->rVelpost!=rVel)"
end;