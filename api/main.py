# api/main.py
from fastapi import FastAPI, HTTPException, Request
import numpy as np
from api.model_loader import model
from api.schema import ImageInput
import logging
import json
import time
from datetime import datetime
import uuid

# Prometheus imports
from prometheus_client import Counter, Histogram, generate_latest
from starlette.responses import Response

# Set up structured JSON logging
class CustomJsonFormatter(logging.Formatter):
    def format(self, record):
        log_record = {
            "timestamp": datetime.utcnow().isoformat(),
            "level": record.levelname,
            "service": "ml-api",
            "trace_id": getattr(record, "trace_id", str(uuid.uuid4())),
            "logger": record.name,
            "message": record.getMessage(),
        }
        
        if hasattr(record, "request_path"):
            log_record["request_path"] = record.request_path
        if hasattr(record, "method"):
            log_record["method"] = record.method
        if hasattr(record, "status_code"):
            log_record["status_code"] = record.status_code
        if hasattr(record, "duration_ms"):
            log_record["duration_ms"] = record.duration_ms
            
        if record.exc_info and record.exc_info[0]:
            log_record["exception"] = self.formatException(record.exc_info)
            
        return json.dumps(log_record)

# Configure logging
logger = logging.getLogger("ml-api")
logger.setLevel(logging.INFO)

# Console handler with JSON formatter
console_handler = logging.StreamHandler()
console_handler.setFormatter(CustomJsonFormatter())
logger.addHandler(console_handler)

app = FastAPI()

# Metrics
REQUEST_COUNT = Counter("api_requests_total", "Total API Requests")
PREDICT_COUNT = Counter("predict_requests_total", "Total predictions made")
REQUEST_LATENCY = Histogram("request_latency_seconds", "Request latency")
ERROR_COUNT = Counter("api_errors_total", "Total errors", ["error_type"])

# Middleware for request logging
@app.middleware("http")
async def log_requests(request: Request, call_next):
    trace_id = request.headers.get("X-Trace-ID", str(uuid.uuid4()))
    start_time = time.time()
    
    # Log incoming request
    logger.info(
        f"Incoming request: {request.method} {request.url.path}",
        extra={
            "trace_id": trace_id,
            "request_path": request.url.path,
            "method": request.method,
        }
    )
    
    try:
        response = await call_next(request)
        duration = (time.time() - start_time) * 1000
        
        # Log successful response
        logger.info(
            f"Request completed: {response.status_code}",
            extra={
                "trace_id": trace_id,
                "request_path": request.url.path,
                "method": request.method,
                "status_code": response.status_code,
                "duration_ms": round(duration, 2),
            }
        )
        
        response.headers["X-Trace-ID"] = trace_id
        return response
        
    except Exception as e:
        duration = (time.time() - start_time) * 1000
        logger.error(
            f"Request failed: {str(e)}",
            exc_info=True,
            extra={
                "trace_id": trace_id,
                "request_path": request.url.path,
                "method": request.method,
                "status_code": 500,
                "duration_ms": round(duration, 2),
            }
        )
        raise

@app.get("/")
def home():
    logger.info("Home endpoint accessed")
    REQUEST_COUNT.inc()
    return {"message": "Model API running", "version": "2.0"}

@app.post("/predict")
def predict(data: ImageInput):
    REQUEST_COUNT.inc()
    start_time = time.time()
    
    logger.info(f"Prediction request received with {len(data.pixels)} pixels")

    if model is None:
        ERROR_COUNT.labels(error_type="model_unavailable").inc()
        logger.error("Model not available")
        raise HTTPException(status_code=503, detail="Model not available")

    pixels = np.array(data.pixels)

    if pixels.ndim != 1:
        ERROR_COUNT.labels(error_type="invalid_dimensions").inc()
        logger.warning(f"Invalid input dimensions: {pixels.ndim}")
        raise HTTPException(status_code=400, detail="`pixels` must be a flat list of numbers")

    if pixels.size != 64:
        ERROR_COUNT.labels(error_type="invalid_pixel_count").inc()
        logger.warning(f"Invalid pixel count: {pixels.size}")
        raise HTTPException(status_code=400, detail="Expected 64 pixels for 8x8 image")

    try:
        X = pixels.reshape(1, -1)
        pred = int(model.predict(X)[0])
        
        PREDICT_COUNT.inc()
        duration = time.time() - start_time
        REQUEST_LATENCY.observe(duration)
        
        logger.info(f"Prediction completed: {pred}, duration: {duration*1000:.2f}ms")
        
        return {"prediction": pred}
        
    except Exception as e:
        ERROR_COUNT.labels(error_type="prediction_error").inc()
        logger.error(f"Prediction failed: {str(e)}", exc_info=True)
        raise HTTPException(status_code=500, detail="Prediction failed")

@app.get("/metrics")
def metrics():
    logger.debug("Metrics endpoint accessed")
    return Response(generate_latest(), media_type="text/plain")