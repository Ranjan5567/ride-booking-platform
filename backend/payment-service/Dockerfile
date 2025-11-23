# Dockerfile for Payment Service - stateless microservice called by Ride Service
FROM python:3.11-slim

WORKDIR /app

# Install dependencies (minimal - only FastAPI needed)
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY app.py .

# Expose service port
EXPOSE 8004

# Start FastAPI application
CMD ["uvicorn", "app:app", "--host", "0.0.0.0", "--port", "8004"]

