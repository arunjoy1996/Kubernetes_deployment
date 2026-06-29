FROM python:3.10

WORKDIR /app

COPY api/requirements.txt .

# Ensure Python output is unbuffered so build logs appear promptly
ENV PYTHONUNBUFFERED=1

# Use the Python interpreter's -u flag when invoking pip to avoid an invalid pip option
RUN python -u -m pip install --no-cache-dir -r requirements.txt

COPY . .

COPY model /app/model

CMD ["uvicorn", "api.main:app", "--host", "0.0.0.0", "--port", "8000"]