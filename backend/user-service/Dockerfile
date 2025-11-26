# Dockerfile for User Service - containerized microservice for Kubernetes deployment
FROM python:3.11-slim

WORKDIR /app

# Install Python dependencies (FastAPI, psycopg2, etc.)
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY app.py .

# Expose service port - matches Kubernetes service port mapping
EXPOSE 8001

# Start FastAPI application with Uvicorn ASGI server
CMD ["uvicorn", "app:app", "--host", "0.0.0.0", "--port", "8001"]

