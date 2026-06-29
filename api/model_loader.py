import joblib
import os

# MODEL_PATH = os.path.join(os.path.dirname(__file__), "..", "model", "rf_model.joblib")
MODEL_PATH = os.path.join(os.path.dirname(__file__), "..", "model", "rf_model.joblib")
MODEL_PATH = os.path.abspath(MODEL_PATH)  # Convert to absolute path

model = None
if os.path.exists(MODEL_PATH):
	model = joblib.load(MODEL_PATH)
	print("Model loaded successfully from:", MODEL_PATH)
else:
	# Placeholder if model not yet trained
	model = None
	print("Model file not found at:", MODEL_PATH)
