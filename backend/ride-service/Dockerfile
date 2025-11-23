# Dockerfile for Ride Service - main orchestration service with HPA auto-scaling
# This service integrates with Payment Service, Lambda, and GCP Pub/Sub
FROM python:3.11-slim

WORKDIR /app

# Install dependencies including Google Cloud Pub/Sub and Firestore clients
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY app.py .

# Expose service port - HPA monitors CPU usage on this service
EXPOSE 8003

# Start FastAPI application
CMD ["uvicorn", "app:app", "--host", "0.0.0.0", "--port", "8003"]

