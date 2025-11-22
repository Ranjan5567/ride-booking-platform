# Quick test - 10 requests
k6 run --vus 10 --duration 15s --env RIDE_SERVICE_URL=http://localhost:8003 loadtest/ride_service_test.js
