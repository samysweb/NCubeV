runlim -r 250  julia --project=. ./experiments/dnnv_comp/example.jl test/parsing/examples/acc/formula-fallback test/parsing/examples/acc/fixed test/parsing/examples/acc/mapping ./test/networks/acc-improved-2000000-64-64.onnx experiments/dnnv_comp/acc-fallback

# DND
runlim -r 250  julia --project=. ./experiments/dnnv_comp/example.jl test/parsing/examples/acas/property-dnd-compressed test/parsing/examples/acas/fixed test/parsing/examples/acas/mapping ./test/networks/VertCAS_pra03_v4_45HU_200.onnx experiments/dnnv_comp/acas-dnd

# DES1500
runlim -r 250  julia --project=. ./experiments/dnnv_comp/example.jl test/parsing/examples/acas/property-des1500-compressed test/parsing/examples/acas/fixed test/parsing/examples/acas/mapping ./test/networks/VertCAS_pra04_v4_45HU_200.onnx experiments/dnnv_comp/acas-des1500

# CL1500
runlim -r 250  julia --project=. ./experiments/dnnv_comp/example.jl test/parsing/examples/acas/property-cl1500-compressed test/parsing/examples/acas/fixed test/parsing/examples/acas/mapping ./test/networks/VertCAS_pra05_v4_45HU_200.onnx experiments/dnnv_comp/acas-cl1500

# SDES1500
runlim -r 250  julia --project=. ./experiments/dnnv_comp/example.jl test/parsing/examples/acas/property-sdes1500-compressed test/parsing/examples/acas/fixed test/parsing/examples/acas/mapping ./test/networks/VertCAS_pra06_v4_45HU_200.onnx experiments/dnnv_comp/acas-sdes1500

# SCL1500
runlim -r 250  julia --project=. ./experiments/dnnv_comp/example.jl test/parsing/examples/acas/property-scl1500-compressed test/parsing/examples/acas/fixed test/parsing/examples/acas/mapping ./test/networks/VertCAS_pra07_v4_45HU_200.onnx experiments/dnnv_comp/acas-scl1500

# SDES2500
runlim -r 250  julia --project=. ./experiments/dnnv_comp/example.jl test/parsing/examples/acas/property-sdes2500-compressed test/parsing/examples/acas/fixed test/parsing/examples/acas/mapping ./test/networks/VertCAS_pra08_v4_45HU_200.onnx experiments/dnnv_comp/acas-sdes2500

# SCL2500
runlim -r 250  julia --project=. ./experiments/dnnv_comp/example.jl test/parsing/examples/acas/property-scl2500-compressed test/parsing/examples/acas/fixed test/parsing/examples/acas/mapping ./test/networks/VertCAS_pra09_v4_45HU_200.onnx experiments/dnnv_comp/acas-scl2500