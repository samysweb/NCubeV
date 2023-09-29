import onnx

# Load the model
model = onnx.load("networks/VertCAS_pra02_v4_45HU_200-converted.onnx")

# Check that the IR is well formed
onnx.checker.check_model(model)

from onnx import version_converter

# Convert to version 8
converted_model = version_converter.convert_version(model, 13)

# Save model
onnx.save(converted_model, "networks/VertCAS_pra02_v4_45HU_200-converted.onnx")